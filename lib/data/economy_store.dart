import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/economy_config.dart';

class EconomyStore extends ChangeNotifier {
  EconomyStore({EconomyConfig? config}) : config = config ?? const EconomyConfig();

  final EconomyConfig config;

  static const _kLives = 'lives';
  static const _kTokens = 'tokens';
  static const _kStreak = 'daily_streak';
  static const _kLastDaily = 'last_daily_claim';
  static const _kNextBonus = 'next_token_bonus';
  static const _kDisplayName = 'display_name';
  static const _kBestTime = 'best_time_ms';

  late SharedPreferences _prefs;

  int lives = 0;
  int tokens = 0;
  int dailyStreak = 0;
  DateTime? lastDailyClaimAt;
  DateTime? nextTokenBonusAt;
  String? displayName;
  int bestTimeMs = 0;

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

  Future<void> _persist() async {
    await _prefs.setInt(_kLives, lives);
    await _prefs.setInt(_kTokens, tokens);
    await _prefs.setInt(_kStreak, dailyStreak);
    await _prefs.setInt(_kBestTime, bestTimeMs);
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
    if (last == null) return config.dailyTokensForStreak(0);
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final lastDay = DateTime(last.year, last.month, last.day);
    final nextStreak = lastDay == yesterday ? dailyStreak : 0;
    return config.dailyTokensForStreak(nextStreak);
  }

  /// Возвращает начисленные жетоны или null, если нельзя.
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
    final amount = config.dailyTokensForStreak(dailyStreak - 1);
    tokens += amount;
    lastDailyClaimAt = now;
    _persist();
    return amount;
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
    final amount = config.timedBonusTokens;
    tokens += amount;
    nextTokenBonusAt =
        DateTime.now().add(Duration(hours: config.timedBonusHours));
    _persist();
    return amount;
  }

  bool get canBuyLifePack => tokens >= config.lifePackCostTokens;

  bool buyLifePack() {
    if (!canBuyLifePack) return false;
    tokens -= config.lifePackCostTokens;
    lives += config.lifePackSize;
    _persist();
    return true;
  }

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
