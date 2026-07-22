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
  static const _kLastTimedBonus = 'last_timed_bonus_claim';
  static const _kDisplayName = 'display_name';
  static const _kBestTime = 'best_time_ms';
  static const _kPremium = 'has_premium';
  static const _kEarnClaimed = 'earn_claimed_ids';

  late SharedPreferences _prefs;

  int lives = 0;
  int tokens = 0;
  int dailyStreak = 0;
  DateTime? lastDailyClaimAt;
  /// Момент последнего забора подарка; готовность = last + timedBonusHours из RC.
  DateTime? lastTimedBonusClaimAt;
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
    // Реклама всегда многоразовая — убираем старый one-shot флаг.
    claimedEarnIds.remove('watch_ad');

    final dailyRaw = _prefs.getString(_kLastDaily);
    if (dailyRaw != null) {
      lastDailyClaimAt = DateTime.tryParse(dailyRaw);
    }

    final lastBonusRaw = _prefs.getString(_kLastTimedBonus);
    if (lastBonusRaw != null) {
      lastTimedBonusClaimAt = DateTime.tryParse(lastBonusRaw);
    } else {
      // Миграция со старого абсолютного next + кап по текущему RC.
      final bonusRaw = _prefs.getString(_kNextBonus);
      final next = bonusRaw != null ? DateTime.tryParse(bonusRaw) : null;
      if (next != null) {
        lastTimedBonusClaimAt = _inferLastClaimFromNext(next);
        await _prefs.remove(_kNextBonus);
        if (lastTimedBonusClaimAt != null) {
          await _prefs.setString(
            _kLastTimedBonus,
            lastTimedBonusClaimAt!.toIso8601String(),
          );
        }
      }
    }
    notifyListeners();
  }

  /// Из абсолютного «готово в» восстанавливаем lastClaim с учётом текущего интервала RC.
  DateTime? _inferLastClaimFromNext(DateTime next) {
    final now = DateTime.now();
    final remaining = next.difference(now);
    if (remaining.isNegative) {
      // Уже пора — можно забирать.
      return null;
    }
    final maxWait = _timedBonusInterval;
    final capped = remaining > maxWait ? maxWait : remaining;
    return now.add(capped).subtract(maxWait);
  }

  Duration get _timedBonusInterval =>
      Duration(hours: config.timedBonusHours.clamp(0, 24 * 30));

  DateTime? get _timedBonusReadyAt {
    final last = lastTimedBonusClaimAt;
    if (last == null) return null;
    return last.add(_timedBonusInterval);
  }

  void applyConfig(EconomyConfig next) {
    config = next;
    // Интервал берётся из RC → таймер пересчитывается от lastTimedBonusClaimAt.
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
    if (lastTimedBonusClaimAt != null) {
      await _prefs.setString(
        _kLastTimedBonus,
        lastTimedBonusClaimAt!.toIso8601String(),
      );
    } else {
      await _prefs.remove(_kLastTimedBonus);
    }
    // Старый ключ больше не пишем.
    await _prefs.remove(_kNextBonus);
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
    final ready = _timedBonusReadyAt;
    if (ready == null) return true;
    return !DateTime.now().isBefore(ready);
  }

  Duration? get timedBonusRemaining {
    final ready = _timedBonusReadyAt;
    if (ready == null) return null;
    final left = ready.difference(DateTime.now());
    if (left.isNegative) return null;
    return left;
  }

  /// 0 = только что забрали (полностью «лёд»), 1 = готово.
  double get timedBonusUnlockProgress {
    if (canClaimTimedBonus) return 1;
    final last = lastTimedBonusClaimAt;
    if (last == null) return 1;
    final totalMs = _timedBonusInterval.inMilliseconds;
    if (totalMs <= 0) return 1;
    final elapsed = DateTime.now().difference(last).inMilliseconds;
    return (elapsed / totalMs).clamp(0.0, 1.0);
  }

  int? claimTimedBonus() {
    if (!canClaimTimedBonus) return null;
    final amount = config.timedBonusTokens;
    tokens += amount;
    lastTimedBonusClaimAt = DateTime.now();
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
  int grantCrystals(int amount) {
    tokens += amount;
    _persist();
    return amount;
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
    tokens += action.reward;
    _persist();
    return action.reward;
  }

  /// Реклама из магазина (FREE) — многоразовая, без «claimed».
  int claimWatchAd({int fallbackReward = 5}) {
    const id = 'watch_ad';
    var reward = fallbackReward;
    for (final a in config.earnActions) {
      if (a.id == id) {
        reward = a.reward;
        break;
      }
    }
    tokens += reward;
    // Не пишем в claimedEarnIds — рекламу можно смотреть снова.
    claimedEarnIds.remove(id);
    _persist();
    return reward;
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
