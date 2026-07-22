import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/economy_config.dart';

class EconomyStore extends ChangeNotifier {
  EconomyStore({EconomyConfig? config})
      : config = config ?? const EconomyConfig();

  EconomyConfig config;

  static const _kLives = 'lives';
  static const _kTokens = 'tokens';
  static const _kStreak = 'daily_streak';
  static const _kLastDaily = 'last_daily_claim';
  static const _kNextBonus = 'next_token_bonus';
  static const _kDisplayName = 'display_name';
  static const _kBestTime = 'best_time_ms';
  static const _kPremium = 'has_premium';
  static const _kEarnClaimed = 'earn_claimed_ids';

  late SharedPreferences _prefs;

  int lives = 0;
  int tokens = 0;
  int dailyStreak = 0;
  DateTime? lastDailyClaimAt;
  DateTime? nextTokenBonusAt;
  String? displayName;
  int bestTimeMs = 0;
  bool hasPremium = false;
  final Set<String> claimedEarnIds = {};

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final hasProfile = _prefs.containsKey(_kLives);

    if (!hasProfile) {
      lives = config.initialLives;
      tokens = 0;
      dailyStreak = 0;
      await _persist();
      return;
    }

    lives = _prefs.getInt(_kLives) ?? config.initialLives;
    tokens = _prefs.getInt(_kTokens) ?? 0;
    dailyStreak = _prefs.getInt(_kStreak) ?? 0;
    bestTimeMs = _prefs.getInt(_kBestTime) ?? 0;
    displayName = _prefs.getString(_kDisplayName);
    hasPremium = _prefs.getBool(_kPremium) ?? false;
    claimedEarnIds
      ..clear()
      ..addAll(_prefs.getStringList(_kEarnClaimed) ?? const []);

    final dailyRaw = _prefs.getString(_kLastDaily);
    if (dailyRaw != null) {
      lastDailyClaimAt = DateTime.tryParse(dailyRaw);
    }
    final bonusRaw = _prefs.getString(_kNextBonus);
    if (bonusRaw != null) {
      nextTokenBonusAt = DateTime.tryParse(bonusRaw);
    }
    notifyListeners();
  }

  void applyConfig(EconomyConfig next) {
    config = next;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs.setInt(_kLives, lives);
    await _prefs.setInt(_kTokens, tokens);
    await _prefs.setInt(_kStreak, dailyStreak);
    await _prefs.setInt(_kBestTime, bestTimeMs);
    await _prefs.setBool(_kPremium, hasPremium);
    await _prefs.setStringList(_kEarnClaimed, claimedEarnIds.toList());
    if (displayName != null) {
      await _prefs.setString(_kDisplayName, displayName!);
    }
    if (lastDailyClaimAt != null) {
      await _prefs.setString(_kLastDaily, lastDailyClaimAt!.toIso8601String());
    }
    if (nextTokenBonusAt != null) {
      await _prefs.setString(_kNextBonus, nextTokenBonusAt!.toIso8601String());
    }
    notifyListeners();
  }

  bool get canPlay => lives > 0;

  bool tryStartGame() {
    if (lives <= 0) return false;
    lives -= 1;
    _persist();
    return true;
  }

  bool get canClaimDaily {
    final last = lastDailyClaimAt;
    if (last == null) return true;
    final now = DateTime.now();
    return !_isSameCalendarDay(last, now);
  }

  int get upcomingDailyTokens {
    final last = lastDailyClaimAt;
    final now = DateTime.now();
    if (last == null) {
      return config.dailyTokensForStreak(0, premium: hasPremium);
    }
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final lastDay = DateTime(last.year, last.month, last.day);
    final nextStreak = lastDay == yesterday ? dailyStreak : 0;
    return config.dailyTokensForStreak(nextStreak, premium: hasPremium);
  }

  /// День streak, который будет засчитан при следующем claim (1-based).
  int get upcomingStreakDay {
    final last = lastDailyClaimAt;
    final now = DateTime.now();
    if (last == null) return 1;
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final lastDay = DateTime(last.year, last.month, last.day);
    if (lastDay == yesterday) return dailyStreak + 1;
    if (_isSameCalendarDay(last, now)) return dailyStreak;
    return 1;
  }

  int _withPremium(int base) {
    if (!hasPremium || base <= 0) return base;
    return (base * config.premiumDailyMultiplier).round().clamp(base, 99999);
  }

  /// Возвращает начисленные кристалы или null, если нельзя.
  int? claimDaily() {
    if (!canClaimDaily) return null;
    final last = lastDailyClaimAt;
    final now = DateTime.now();
    if (last != null) {
      final yesterday = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
      final lastDay = DateTime(last.year, last.month, last.day);
      dailyStreak = lastDay == yesterday ? dailyStreak + 1 : 1;
    } else {
      dailyStreak = 1;
    }
    final amount = config.dailyTokensForStreak(
      dailyStreak - 1,
      premium: hasPremium,
    );
    tokens += amount;
    lastDailyClaimAt = now;
    _persist();
    return amount;
  }

  /// До полуночи (когда Daily уже взят сегодня).
  Duration get untilMidnight {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    return next.difference(now);
  }

  bool get canClaimTimedBonus {
    final next = nextTokenBonusAt;
    if (next == null) return true;
    return !DateTime.now().isBefore(next);
  }

  Duration? get timedBonusRemaining {
    final next = nextTokenBonusAt;
    if (next == null) return null;
    final left = next.difference(DateTime.now());
    if (left.isNegative) return null;
    return left;
  }

  int? claimTimedBonus() {
    if (!canClaimTimedBonus) return null;
    final amount = _withPremium(config.timedBonusTokens);
    tokens += amount;
    nextTokenBonusAt =
        DateTime.now().add(Duration(hours: config.timedBonusHours));
    _persist();
    return amount;
  }

  bool get canBuyLifePack =>
      canBuyLifePackOffer(config.resolvedLifePacks.first);

  bool canBuyLifePackOffer(LifePackOffer offer) =>
      tokens >= offer.costTokens;

  bool buyLifePack() => buyLifePackOffer(config.resolvedLifePacks.first);

  bool buyLifePackOffer(LifePackOffer offer) {
    if (!canBuyLifePackOffer(offer)) return false;
    tokens -= offer.costTokens;
    lives += offer.lives;
    _persist();
    return true;
  }

  /// Локальный preview покупки пака (до Google Play Billing).
  /// Plus удваивает начисление.
  int grantCrystals(int amount) {
    final granted = _withPremium(amount);
    tokens += granted;
    _persist();
    return granted;
  }

  /// Локальный preview подписки.
  void activatePremiumPreview() {
    hasPremium = true;
    _persist();
  }

  /// Preview: награда за действие (реклама / соцсеть / …).
  int? claimEarnAction(String id) {
    if (claimedEarnIds.contains(id)) return null;
    EarnAction? action;
    for (final a in config.earnActions) {
      if (a.id == id) {
        action = a;
        break;
      }
    }
    if (action == null) return null;
    claimedEarnIds.add(id);
    final granted = _withPremium(action.reward);
    tokens += granted;
    _persist();
    return granted;
  }

  /// Реклама из магазина (FREE). Работает даже если watch_ad нет в earnActions.
  int? claimWatchAd({int fallbackReward = 5}) {
    const id = 'watch_ad';
    if (claimedEarnIds.contains(id)) return null;
    var reward = fallbackReward;
    for (final a in config.earnActions) {
      if (a.id == id) {
        reward = a.reward;
        break;
      }
    }
    claimedEarnIds.add(id);
    final granted = _withPremium(reward);
    tokens += granted;
    _persist();
    return granted;
  }

  bool isEarnClaimed(String id) => claimedEarnIds.contains(id);

  Future<void> setDisplayName(String name) async {
    displayName = name.trim();
    await _persist();
  }

  Future<void> recordBestTime(int timeMs) async {
    if (timeMs > bestTimeMs) {
      bestTimeMs = timeMs;
      await _persist();
    }
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
