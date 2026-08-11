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
  static const _kPremiumNextCharge = 'premium_next_charge';
  static const _kEarnClaimed = 'earn_claimed_ids';
  static const _kEarnUnlocked = 'earn_unlocked_ids';
  static const _kGamesStarted = 'games_started_count';
  static const _kLastWatchAd = 'last_watch_ad_claim';
  static const _kJumpRentalUntil = 'jump_rental_until';
  static const _kHelmetRentalUntil = 'helmet_rental_until';
  static const swipeHintMaxGames = 5;

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
  /// Preview: следующее списание Boost (после реального Billing заменится).
  DateTime? premiumNextChargeAt;
  /// Сколько раз уже тратили жизнь на старт партии (для подсказки пальца).
  int gamesStartedCount = 0;
  /// Последний забор кристалов за рекламу (для кулдауна).
  DateTime? lastWatchAdClaimAt;
  /// Аренда прыжка действует до этого момента.
  DateTime? jumpRentalUntil;
  /// Аренда шлема действует до этого момента.
  DateTime? helmetRentalUntil;
  final Set<String> claimedEarnIds = {};
  /// Геймплей-бонусы Earn, которые уже открыты (можно забрать).
  final Set<String> unlockedEarnIds = {};

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final hasProfile = _prefs.containsKey(_kLives);

    if (!hasProfile) {
      lives = config.initialLives;
      dailyStreak = 0;
      _seedInstallBonusOnFreshStart();
      await _persist();
      return;
    }

    lives = _prefs.getInt(_kLives) ?? config.initialLives;
    tokens = _prefs.getInt(_kTokens) ?? 0;
    dailyStreak = _prefs.getInt(_kStreak) ?? 0;
    bestTimeMs = _prefs.getInt(_kBestTime) ?? 0;
    displayName = _prefs.getString(_kDisplayName);
    hasPremium = _prefs.getBool(_kPremium) ?? false;
    gamesStartedCount = _prefs.getInt(_kGamesStarted) ?? 0;
    final nextChargeRaw = _prefs.getString(_kPremiumNextCharge);
    if (nextChargeRaw != null) {
      premiumNextChargeAt = DateTime.tryParse(nextChargeRaw);
    }
    if (hasPremium && premiumNextChargeAt == null) {
      premiumNextChargeAt = DateTime.now().add(const Duration(days: 7));
    }
    claimedEarnIds
      ..clear()
      ..addAll(_prefs.getStringList(_kEarnClaimed) ?? const []);
    unlockedEarnIds
      ..clear()
      ..addAll(_prefs.getStringList(_kEarnUnlocked) ?? const []);
    // Реклама всегда многоразовая — убираем старый one-shot флаг.
    claimedEarnIds.remove('watch_ad');
    // Старые профили при авто-бонусе: уже «прошли» установку — без повторной выдачи.
    var claimedDirty = false;
    if (config.installBonusAutoClaim &&
        !claimedEarnIds.contains(EconomyConfig.installBonusId)) {
      claimedEarnIds.add(EconomyConfig.installBonusId);
      claimedDirty = true;
    }
    // Рекорд уже есть — открываем time-бонусы без тоста.
    final unlockedBefore = unlockedEarnIds.length;
    syncGameplayEarnUnlocks(aliveMs: 0, riskCount: 0, persist: false);
    final unlockedDirty = unlockedEarnIds.length != unlockedBefore;

    final lastWatchRaw = _prefs.getString(_kLastWatchAd);
    if (lastWatchRaw != null) {
      lastWatchAdClaimAt = DateTime.tryParse(lastWatchRaw);
    }

    final jumpUntilRaw = _prefs.getString(_kJumpRentalUntil);
    if (jumpUntilRaw != null) {
      jumpRentalUntil = DateTime.tryParse(jumpUntilRaw);
    }
    final helmetUntilRaw = _prefs.getString(_kHelmetRentalUntil);
    if (helmetUntilRaw != null) {
      helmetRentalUntil = DateTime.tryParse(helmetUntilRaw);
    }

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
    if (claimedDirty) {
      await _prefs.setStringList(_kEarnClaimed, claimedEarnIds.toList());
    }
    if (unlockedDirty) {
      await _prefs.setStringList(_kEarnUnlocked, unlockedEarnIds.toList());
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
    await _prefs.setInt(_kGamesStarted, gamesStartedCount);
    if (premiumNextChargeAt != null) {
      await _prefs.setString(
        _kPremiumNextCharge,
        premiumNextChargeAt!.toIso8601String(),
      );
    } else {
      await _prefs.remove(_kPremiumNextCharge);
    }
    await _prefs.setStringList(_kEarnClaimed, claimedEarnIds.toList());
    await _prefs.setStringList(_kEarnUnlocked, unlockedEarnIds.toList());
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
    if (lastWatchAdClaimAt != null) {
      await _prefs.setString(
        _kLastWatchAd,
        lastWatchAdClaimAt!.toIso8601String(),
      );
    } else {
      await _prefs.remove(_kLastWatchAd);
    }
    if (jumpRentalUntil != null) {
      await _prefs.setString(
        _kJumpRentalUntil,
        jumpRentalUntil!.toIso8601String(),
      );
    } else {
      await _prefs.remove(_kJumpRentalUntil);
    }
    if (helmetRentalUntil != null) {
      await _prefs.setString(
        _kHelmetRentalUntil,
        helmetRentalUntil!.toIso8601String(),
      );
    } else {
      await _prefs.remove(_kHelmetRentalUntil);
    }
    // Старый ключ больше не пишем.
    await _prefs.remove(_kNextBonus);
    notifyListeners();
  }

  bool get canPlay => lives > 0;

  /// Палец-подсказка только пока сыграно меньше 5 партий (5 жизней).
  bool get showSwipeHint => gamesStartedCount < swipeHintMaxGames;

  bool tryStartGame() {
    if (lives <= 0) return false;
    lives -= 1;
    gamesStartedCount += 1;
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
    notifyListeners();
    return amount;
  }

  bool get hasJumpRental {
    final until = jumpRentalUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  bool get hasHelmetRental {
    final until = helmetRentalUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  Duration? get jumpRentalRemaining {
    final until = jumpRentalUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    if (left.isNegative || left.inMilliseconds <= 0) return null;
    return left;
  }

  Duration? get helmetRentalRemaining {
    final until = helmetRentalUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    if (left.isNegative || left.inMilliseconds <= 0) return null;
    return left;
  }

  bool canRentJump({bool hour = false}) {
    final cost = hour ? config.jumpRentalHourCost : config.jumpRentalCost;
    return tokens >= cost;
  }

  bool canRentHelmet({bool hour = false}) {
    final cost = hour ? config.helmetRentalHourCost : config.helmetRentalCost;
    return tokens >= cost;
  }

  /// Аренда прыжка: продлевает от max(now, текущий until).
  bool rentJump({bool hour = false}) {
    final cost = hour ? config.jumpRentalHourCost : config.jumpRentalCost;
    final minutes = (hour
            ? config.jumpRentalHourMinutes
            : config.jumpRentalMinutes)
        .clamp(1, 24 * 60);
    if (tokens < cost) return false;
    tokens -= cost;
    final now = DateTime.now();
    final base =
        jumpRentalUntil != null && jumpRentalUntil!.isAfter(now)
            ? jumpRentalUntil!
            : now;
    jumpRentalUntil = base.add(Duration(minutes: minutes));
    _persist();
    return true;
  }

  /// Аренда шлема: 1 касание без смерти за партию, пока аренда активна.
  bool rentHelmet({bool hour = false}) {
    final cost = hour ? config.helmetRentalHourCost : config.helmetRentalCost;
    final minutes = (hour
            ? config.helmetRentalHourMinutes
            : config.helmetRentalMinutes)
        .clamp(1, 24 * 60);
    if (tokens < cost) return false;
    tokens -= cost;
    final now = DateTime.now();
    final base =
        helmetRentalUntil != null && helmetRentalUntil!.isAfter(now)
            ? helmetRentalUntil!
            : now;
    helmetRentalUntil = base.add(Duration(minutes: minutes));
    _persist();
    return true;
  }

  /// Локальный preview подписки Boost (еженедельно).
  void activatePremiumPreview() {
    hasPremium = true;
    premiumNextChargeAt = DateTime.now().add(const Duration(days: 7));
    _persist();
  }

  /// Локальная отмена подписки (preview до Billing).
  void cancelPremium() {
    if (!hasPremium) return;
    hasPremium = false;
    premiumNextChargeAt = null;
    _persist();
  }

  /// Полный сброс локального прогресса — как после первой установки.
  Future<void> resetToFreshInstall() async {
    lives = config.initialLives;
    dailyStreak = 0;
    lastDailyClaimAt = null;
    lastTimedBonusClaimAt = null;
    displayName = null;
    bestTimeMs = 0;
    hasPremium = false;
    premiumNextChargeAt = null;
    gamesStartedCount = 0;
    lastWatchAdClaimAt = null;
    jumpRentalUntil = null;
    helmetRentalUntil = null;
    _seedInstallBonusOnFreshStart();

    await _prefs.remove(_kLives);
    await _prefs.remove(_kTokens);
    await _prefs.remove(_kStreak);
    await _prefs.remove(_kLastDaily);
    await _prefs.remove(_kNextBonus);
    await _prefs.remove(_kLastTimedBonus);
    await _prefs.remove(_kDisplayName);
    await _prefs.remove(_kBestTime);
    await _prefs.remove(_kPremium);
    await _prefs.remove(_kPremiumNextCharge);
    await _prefs.remove(_kEarnClaimed);
    await _prefs.remove(_kEarnUnlocked);
    await _prefs.remove(_kGamesStarted);
    await _prefs.remove(_kLastWatchAd);
    await _prefs.remove(_kJumpRentalUntil);
    await _prefs.remove(_kHelmetRentalUntil);

    await _persist();
  }

  /// Стартовый бонус за установку: авто-выдача или ожидание клика в Earn.
  void _seedInstallBonusOnFreshStart() {
    claimedEarnIds.clear();
    unlockedEarnIds.clear();
    if (config.installBonusAutoClaim) {
      tokens = config.resolvedInstallBonusTokens;
      claimedEarnIds.add(EconomyConfig.installBonusId);
    } else {
      tokens = 0;
    }
  }

  EarnAction? _earnActionById(String id) {
    for (final a in config.earnActions) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Геймплей-бонус можно забирать только после разблокировки.
  bool isEarnUnlocked(String id) {
    if (!EconomyConfig.gameplayEarnIds.contains(id)) return true;
    return unlockedEarnIds.contains(id) || claimedEarnIds.contains(id);
  }

  /// Открывает Earn-бонусы по времени / рискам. Возвращает только новые id.
  List<String> syncGameplayEarnUnlocks({
    required int aliveMs,
    required int riskCount,
    bool persist = true,
  }) {
    final newly = <String>[];
    void tryUnlock(String id, bool condition) {
      if (!condition) return;
      if (claimedEarnIds.contains(id) || unlockedEarnIds.contains(id)) return;
      if (_earnActionById(id) == null) return;
      unlockedEarnIds.add(id);
      newly.add(id);
    }

    final surviveMs =
        (config.earnSurviveSeconds.clamp(1, 3600) * 1000);
    final recordMs = (config.earnRecordSeconds.clamp(1, 3600) * 1000);
    final risksTarget = config.earnRisksInRun.clamp(1, 999);
    final bestOrRun = aliveMs > bestTimeMs ? aliveMs : bestTimeMs;

    tryUnlock(EconomyConfig.survive10Id, bestOrRun >= surviveMs);
    tryUnlock(EconomyConfig.record20Id, bestOrRun >= recordMs);
    tryUnlock(EconomyConfig.risks5Id, riskCount >= risksTarget);

    if (newly.isNotEmpty && persist) {
      _persist();
    }
    return newly;
  }

  /// Preview: награда за действие (реклама / соцсеть / …).
  int? claimEarnAction(String id) {
    if (claimedEarnIds.contains(id)) return null;
    if (!isEarnUnlocked(id)) return null;
    final action = _earnActionById(id);
    if (action == null) return null;
    claimedEarnIds.add(id);
    unlockedEarnIds.add(id);
    tokens += action.reward;
    _persist();
    return action.reward;
  }

  /// Реклама из магазина (FREE) — многоразовая, с кулдауном из RC.
  int? claimWatchAd({int fallbackReward = 5}) {
    if (!canClaimWatchAd) return null;
    const id = 'watch_ad';
    var reward = fallbackReward;
    for (final a in config.earnActions) {
      if (a.id == id) {
        reward = a.reward;
        break;
      }
    }
    tokens += reward;
    lastWatchAdClaimAt = DateTime.now();
    // Не пишем в claimedEarnIds — рекламу можно смотреть снова после кулдауна.
    claimedEarnIds.remove(id);
    _persist();
    return reward;
  }

  Duration get _watchAdCooldown =>
      Duration(seconds: config.watchAdCooldownSec.clamp(0, 24 * 3600));

  DateTime? get _watchAdReadyAt {
    final last = lastWatchAdClaimAt;
    if (last == null) return null;
    final cd = _watchAdCooldown;
    if (cd.inSeconds <= 0) return null;
    return last.add(cd);
  }

  bool get canClaimWatchAd {
    final ready = _watchAdReadyAt;
    if (ready == null) return true;
    return !DateTime.now().isBefore(ready);
  }

  Duration? get watchAdCooldownRemaining {
    final ready = _watchAdReadyAt;
    if (ready == null) return null;
    final left = ready.difference(DateTime.now());
    if (left.isNegative || left.inMilliseconds <= 0) return null;
    return left;
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
