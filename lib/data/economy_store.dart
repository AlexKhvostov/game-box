import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/economy_config.dart';
import '../domain/android_energy.dart';
import '../domain/arcade_rules.dart';
import 'energy_presentation.dart';

class EconomyStore extends ChangeNotifier {
  final energyPresentation = EnergyPresentation();
  int get presentedEnergy => energyPresentation.balance;
  void presentEnergyCredit(String key, int amount, {bool animate = true}) {
    energyPresentation.wallet(energyOwner, energy);
    if (energyPresentation.begin(key, amount, animate: animate)) {
      notifyListeners();
    }
  }

  void settleEnergyCredit(String key, {bool rejected = false, int? amount}) {
    energyPresentation.wallet(energyOwner, energy);
    energyPresentation.settle(key, rejected: rejected, amount: amount);
    notifyListeners();
  }

  @override
  void notifyListeners() {
    energyPresentation.wallet(energyOwner, energy);
    super.notifyListeners();
  }

  EconomyStore({
    EconomyConfig? config,
    DateTime Function()? now,
    int Function()? monotonicMilliseconds,
    this.storagePrefix = '',
    this.serverEnergyRequired = false,
  }) : config = config ?? const EconomyConfig(),
       _now = now ?? DateTime.now,
       _fixtureWallClock = now != null && monotonicMilliseconds == null,
       // Public named injection keeps production independent of device wall time.
       // ignore: prefer_initializing_formals
       _monotonicMilliseconds = monotonicMilliseconds,
       _sessionStartedAt = (now ?? DateTime.now)();

  final DateTime Function() _now;
  final bool _fixtureWallClock;
  final int Function()? _monotonicMilliseconds;
  final Stopwatch _monotonicClock = Stopwatch()..start();
  int get _elapsedMilliseconds =>
      _monotonicMilliseconds?.call() ?? _monotonicClock.elapsedMilliseconds;
  final String storagePrefix;
  final bool serverEnergyRequired;
  final DateTime _sessionStartedAt;
  int _sessionCompletedRounds = 0;

  void recordCompletedRound() => _sessionCompletedRounds++;

  EconomyConfig config;
  void Function(String kind, Map<String, dynamic> args)? sendOperation;
  Future<void> Function(String kind, Map<String, dynamic> args)?
  sendEnergyOperation;
  Map<String, dynamic>? _energyWallet;
  AndroidEnergyConfig _energyConfig = const AndroidEnergyConfig();
  bool _energyEnabled = false;
  bool get energyEnabled => _energyEnabled;
  AndroidEnergyConfig get energyConfig => _energyConfig;
  SimpleEnergyBonus? get simpleEnergyBonus {
    final raw = _energyWallet?['simpleBonus'];
    return raw is Map && raw['contract'] == 3
        ? SimpleEnergyBonus.fromJson(Map<String, dynamic>.from(raw))
        : null;
  }

  int get energyTier => energySubscribed
      ? ((energySubscription?['batteryCount'] as num?)?.toInt() ?? 1)
      : 1;
  bool get simpleBonusReady =>
      simpleEnergyBonus != null &&
      energyClockSynchronized &&
      !energySubscriptionPending &&
      simpleEnergyBonus!.remainingAt(energyNow) == Duration.zero;
  Future<void> claimHiddenEnergy() =>
      performEnergyOperation('energy_hidden_tap', const {});
  Future<void> claimSimpleEnergyBonus() =>
      performEnergyOperation('energy_bonus_claim', const {});
  int _confirmedEnergy = 0;
  int? _practiceEnergy;
  final Map<String, int> _pendingRunCosts = {};
  int get energy =>
      ((_practiceEnergy ?? _confirmedEnergy) -
              _pendingRunCosts.values.fold<int>(0, (a, b) => a + b))
          .clamp(0, 1000000000);
  void setPendingRunCosts(
    String owner,
    Map<String, int> costs, {
    bool notify = true,
  }) {
    if (_energyOwner != owner) return;
    for (final entry in costs.entries) {
      if (!_pendingRunCosts.containsKey(entry.key)) {
        energyPresentation.debit(entry.key, entry.value);
      }
    }
    _pendingRunCosts
      ..clear()
      ..addAll(costs);
    if (notify) notifyListeners();
  }

  int get confirmedEnergy => _confirmedEnergy;
  List<EnergyBattery> energyBatteries = const [];
  int? _energyServerAnchor;
  int _energyElapsedAnchor = 0;
  int _energyFixtureAnchor = 0;
  bool _energyClockLive = false;
  bool get energyClockSynchronized => _energyClockLive;
  String? _energyOwner;
  String? get energyOwner => _energyOwner;
  Map<String, dynamic>? _cachedEnergySnapshot;
  DateTime get energyNow {
    final anchor = _energyServerAnchor;
    if (anchor == null) return _now();
    final elapsed = !_energyClockLive
        ? 0
        : (_fixtureWallClock
              ? _now().millisecondsSinceEpoch - _energyFixtureAnchor
              : _elapsedMilliseconds - _energyElapsedAnchor);
    return DateTime.fromMillisecondsSinceEpoch(
      anchor + elapsed.clamp(0, 315360000000),
    );
  }

  Map<String, dynamic>? energySubscription;
  bool get energySubscriptionPending =>
      energySubscription?['awaitingReconciliation'] == true;
  bool get energySubscribed {
    final subscription = energySubscription;
    if (!energyEnabled || subscription == null) return false;
    if (energySubscriptionPending) {
      return true; // Do not show ads while paid rights reconcile.
    }
    final until = subscription['expiresAt'] ?? subscription['until'];
    return until is num && until > energyNow.millisecondsSinceEpoch;
  }

  bool helmetSelected = false, jumpSelected = false;
  bool energyBusy = false;
  int _energyInFlight = 0;
  String? energyError;
  int get attemptEnergyCost =>
      _energyConfig.baseAttemptCost +
      (helmetSelected ? _energyConfig.helmetExtraCost : 0) +
      (jumpSelected ? _energyConfig.jumpExtraCost : 0);
  int get accumulatedEnergy => energyBatteries.fold(
    0,
    (sum, battery) => sum + battery.unitsAt(energyNow),
  );
  int get energyCapacity =>
      energyBatteries.fold(0, (sum, battery) => sum + battery.capacity);
  Duration get energyUntilFull => Duration(
    milliseconds: energyBatteries.fold(0, (longest, battery) {
      final left = battery.remainingAt(energyNow).inMilliseconds;
      return left > longest ? left : longest;
    }),
  );
  void setHelmetSelected(bool value) {
    helmetSelected = value;
    _persist();
  }

  void setJumpSelected(bool value) {
    jumpSelected = value;
    _persist();
  }

  void _applyEnergyWallet(
    Map<String, dynamic> wallet, {
    int? serverNow,
    String? owner,
    bool fromCache = false,
  }) {
    _energyEnabled = wallet['energyVersion'] == 2;
    if (_energyOwner != owner) _pendingRunCosts.clear();
    _energyOwner = owner;
    if (!fromCache) _cachedEnergySnapshot = null;
    _practiceEnergy = null;
    if (!_energyEnabled) {
      _energyWallet = null;
      energyBatteries = const [];
      energySubscription = null;
      return;
    }
    _energyWallet = Map<String, dynamic>.from(wallet);
    _confirmedEnergy = (wallet['energy'] as num?)?.toInt() ?? 0;
    _energyConfig = AndroidEnergyConfig.fromJson(
      Map<String, dynamic>.from(
        wallet['energyConfig'] is Map
            ? wallet['energyConfig'] as Map
            : const {},
      ),
    );
    final paidUntil = wallet['energySubscription'] is Map
        ? (wallet['energySubscription'] as Map)['expiresAt']
        : null;
    energyBatteries = List.unmodifiable(
      (wallet['batteries'] as List? ?? []).whereType<Map>().map(
        (raw) => EnergyBattery.fromJson({
          ...Map<String, dynamic>.from(raw),
          if (raw['id'] != 'free' && paidUntil is num)
            'activeUntil': paidUntil.toInt(),
        }),
      ),
    );
    energySubscription = wallet['energySubscription'] is Map
        ? Map<String, dynamic>.from(wallet['energySubscription'] as Map)
        : null;
    _energyServerAnchor =
        serverNow ?? _energyServerAnchor ?? _now().millisecondsSinceEpoch;
    _energyElapsedAnchor = _elapsedMilliseconds;
    _energyFixtureAnchor = _now().millisecondsSinceEpoch;
    _energyClockLive = serverNow != null && !fromCache;
  }

  void _loadEnergyCache() {
    helmetSelected =
        _prefs.getBool('${storagePrefix}energy_helmet_selected') ?? false;
    jumpSelected =
        _prefs.getBool('${storagePrefix}energy_jump_selected') ?? false;
    try {
      final raw = _prefs.getString('${storagePrefix}energy_v2_snapshot');
      if (raw != null) {
        _cachedEnergySnapshot = Map<String, dynamic>.from(
          jsonDecode(raw) as Map,
        );
      }
    } catch (_) {
      _cachedEnergySnapshot = null;
    }
    // No V2 cache is displayed until secure credentials independently confirm
    // its owner. The old unowned energy_v2_wallet format is never trusted.
  }

  Future<void> restoreEnergyCacheForOwner(String? owner) async {
    final cached = _cachedEnergySnapshot;
    if (owner == null ||
        cached == null ||
        cached['owner'] != owner ||
        cached['wallet'] is! Map ||
        cached['serverNow'] is! int) {
      return;
    }
    await applyServerWallet(
      Map<String, dynamic>.from(cached['wallet'] as Map),
      owner: owner,
      serverNow: cached['serverNow'] as int,
      fromCache: true,
    );
  }

  /// Cached energy is a disposable practice budget, never uploaded or rewarded.
  bool spendEnergyForPractice({int? cost}) {
    final effectiveCost = cost ?? attemptEnergyCost;
    if (!energyEnabled || effectiveCost <= 0 || energy < effectiveCost) {
      return false;
    }
    _practiceEnergy = energy - effectiveCost;
    gamesStartedCount++;
    notifyListeners();
    return true;
  }

  void endEnergyPractice() {
    _practiceEnergy = null;
    notifyListeners();
  }

  bool energyRewardClaimed(String id) =>
      claimedEarnIds.contains(id) || claimedEarnIds.contains('energy_$id');
  int get feedbackSpentEnergy =>
      (_energyWallet?['feedbackSpentEnergy'] as num?)?.toInt() ?? 0;
  int get feedbackMinimumSpend =>
      (_energyWallet?['feedbackMinimumSpend'] as num?)?.toInt() ?? 100;
  bool get canSendEnergyFeedback =>
      energyEnabled && feedbackSpentEnergy >= feedbackMinimumSpend;
  bool energyRewardReady(String id) {
    if (energyRewardClaimed(id)) return false;
    if (id == 'google') {
      return _energyWallet?['energyGoogleReady'] == true ||
          _energyWallet?['googleReady'] == true;
    }
    if (id == 'age') {
      return _energyWallet?['energyAgeCompleted'] == true ||
          _energyWallet?['ageCompleted'] == true;
    }
    return unlockedEarnIds.contains(id);
  }

  Future<void> performEnergyOperation(
    String kind,
    Map<String, dynamic> args,
  ) async {
    if (!energyEnabled) throw StateError('energy_unavailable');
    final send = sendEnergyOperation;
    if (send == null) throw StateError('energy_server_unavailable');
    _energyInFlight++;
    energyBusy = true;
    energyError = null;
    notifyListeners();
    try {
      await send(kind, args);
    } catch (error) {
      energyError = '$error';
      rethrow;
    } finally {
      _energyInFlight--;
      energyBusy = _energyInFlight > 0;
      notifyListeners();
    }
  }

  int expectedEnergyCredit(String kind, Map<String, dynamic> args) {
    if (kind == 'energy_bonus_claim' && simpleBonusReady) {
      return simpleEnergyBonus!.reward;
    }
    if (kind == 'energy_claim') return accumulatedEnergy;
    if (kind == 'energy_hidden_tap') return 20;
    if (kind == 'watch_ad') return energyConfig.rewards['ad'] ?? 0;
    if (kind == 'energy_feedback' &&
        canSendEnergyFeedback &&
        !energyRewardClaimed('feedback')) {
      return energyConfig.rewards['feedback'] ?? 0;
    }
    final id = args['id'];
    if (kind == 'energy_reward' &&
        id is String &&
        energyRewardReady(id) &&
        !energyRewardClaimed(id)) {
      return energyConfig.rewards[id] ??
          energyConfig.rewards['achievement'] ??
          0;
    }
    return 0;
  }

  Future<void> claimEnergy() async {
    if (accumulatedEnergy <= 0) return;
    await performEnergyOperation('energy_claim', const {});
  }

  Future<void> claimEnergyReward(String id) => performEnergyOperation(
    id == 'watch_ad' ? 'watch_ad' : 'energy_reward',
    id == 'watch_ad' ? const {} : {'id': id},
  );

  Future<void> completeEnergyAge() =>
      performEnergyOperation('energy_age_completed', const {});
  Future<void> sendEnergyFeedback(String comment, {int? rating}) async {
    if (!canSendEnergyFeedback && !energyRewardClaimed('feedback')) {
      throw StateError('feedback_locked');
    }
    final trimmed = comment.trim();
    if (trimmed.runes.length < 20 || trimmed.runes.length > 1000) {
      throw ArgumentError('feedback_length');
    }
    if (rating != null && (rating < 1 || rating > 5)) {
      throw ArgumentError('feedback_rating');
    }
    await performEnergyOperation('energy_feedback', {
      'comment': trimmed,
      'rating': ?rating,
    });
  }

  /// Only isolated test packages can render arbitrary V2 fixture states.
  Future<void> enableEnergyPreview({
    int balance = 47,
    int batteryCount = 1,
    int initialUnits = 19,
  }) async {
    if (storagePrefix.isEmpty) {
      throw StateError('preview_requires_isolated_storage');
    }
    final now = _now().millisecondsSinceEpoch;
    final preview = AndroidEnergyConfig.fromJson({'enabled': true});
    await applyServerWallet(
      {
        'energyVersion': 2,
        'energy': balance,
        'energyConfig': preview.toJson(),
        'batteries': List.generate(
          batteryCount.clamp(1, 5),
          (i) => {
            'id': i == 0 ? 'free' : 'extra_$i',
            'startedAt': now,
            'capacity': 20,
            'durationMs': preview.durationMs,
            'initialUnits': initialUnits,
            'revision': preview.revision,
          },
        ),
        if (batteryCount > 1)
          'energySubscription': {
            'expiresAt': now + const Duration(days: 7).inMilliseconds,
            'productId': batteryCount == 2
                ? 'energy_batteries_2_v1'
                : 'energy_batteries_5_v1',
          },
        'claimed': const <String>[],
        'unlocked': const <String>[],
        'energyGoogleReady': true,
        'energyAgeCompleted': true,
      },
      serverNow: now,
      owner: 'preview:$storagePrefix',
    );
  }

  Future<void> applyServerWallet(
    Map<String, dynamic> wallet, {
    bool preserveBest = false,
    int? serverNow,
    String? owner,
    bool fromCache = false,
  }) async {
    int amount(String key) => (wallet[key] as num?)?.toInt() ?? 0;
    DateTime? at(String key) => amount(key) > 0
        ? DateTime.fromMillisecondsSinceEpoch(amount(key))
        : null;
    _applyEnergyWallet(
      wallet,
      serverNow: serverNow,
      owner: owner,
      fromCache: fromCache,
    );
    lives = amount('lives');
    tokens = amount('tokens');
    dailyStreak = amount('dailyStreak');
    lastDailyClaimAt = at('lastDailyAt');
    lastTimedBonusClaimAt = at('lastTimedAt');
    lastWatchAdClaimAt = at('lastAdAt');
    jumpRentalUntil = at('jumpUntil');
    helmetRentalUntil = at('helmetUntil');
    final serverBest = amount('bestTimeMs');
    bestTimeMs = preserveBest && bestTimeMs > serverBest
        ? bestTimeMs
        : serverBest;
    gamesStartedCount = amount('gamesStarted');
    premiumNextChargeAt = at('plusUntil');
    hasPremium = (premiumNextChargeAt?.isAfter(_now()) ?? false);
    claimedEarnIds
      ..clear()
      ..addAll((wallet['claimed'] as List? ?? []).cast<String>());
    unlockedEarnIds
      ..clear()
      ..addAll((wallet['unlocked'] as List? ?? []).cast<String>());
    interstitialArmedAt ??= lastDailyClaimAt;
    if (fromCache) {
      notifyListeners();
    } else {
      // Render the received wallet before local cache I/O finishes.
      notifyListeners();
      await _persist();
    }
  }

  String get _kLives => '${storagePrefix}lives';
  String get _kTokens => '${storagePrefix}tokens';
  String get _kStreak => '${storagePrefix}daily_streak';
  String get _kLastDaily => '${storagePrefix}last_daily_claim';
  String get _kNextBonus => '${storagePrefix}next_token_bonus';
  String get _kLastTimedBonus => '${storagePrefix}last_timed_bonus_claim';
  String get _kDisplayName => '${storagePrefix}display_name';
  String get _kBestTime => '${storagePrefix}best_time_ms';
  String get _kPremium => '${storagePrefix}has_premium';
  String get _kPremiumNextCharge => '${storagePrefix}premium_next_charge';
  String get _kEarnClaimed => '${storagePrefix}earn_claimed_ids';
  String get _kEarnUnlocked => '${storagePrefix}earn_unlocked_ids';
  String get _kGamesStarted => '${storagePrefix}games_started_count';
  String get _kAdArmed => '${storagePrefix}interstitial_armed_at';
  String get _kLastInterstitial => '${storagePrefix}last_interstitial_at';
  DateTime? interstitialArmedAt;
  DateTime? lastInterstitialAt;

  String get _kLastWatchAd => '${storagePrefix}last_watch_ad_claim';
  String get _kJumpRentalUntil => '${storagePrefix}jump_rental_until';
  String get _kHelmetRentalUntil => '${storagePrefix}helmet_rental_until';
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
  bool _hasPremium = false;
  bool get hasPremium =>
      _hasPremium &&
      (premiumNextChargeAt == null || premiumNextChargeAt!.isAfter(_now()));
  set hasPremium(bool value) => _hasPremium = value;

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
    if (serverEnergyRequired) {
      // Show the existing energy UI while offline, with no fabricated startup
      // credit. Only an owner-confirmed cache or server response sets balance.
      _energyEnabled = true;
      _energyConfig = config.androidEnergyV2;
    }
    _loadEnergyCache();
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
      premiumNextChargeAt = _now().add(const Duration(days: 7));
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
      unlockedEarnIds.add(EconomyConfig.installBonusId);
      claimedDirty = true;
    }
    // Рекорд уже есть — открываем time-бонусы без тоста.
    final unlockedBefore = unlockedEarnIds.length;
    syncGameplayEarnUnlocks(aliveMs: 0, riskCount: 0, persist: false);
    final unlockedDirty = unlockedEarnIds.length != unlockedBefore;

    interstitialArmedAt = DateTime.tryParse(_prefs.getString(_kAdArmed) ?? '');
    lastInterstitialAt = DateTime.tryParse(
      _prefs.getString(_kLastInterstitial) ?? '',
    );
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
    final now = _now();
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

  Future<void> _persistJob = Future.value();

  /// Commit the latest snapshot before a user-approved application restart.
  Future<void> prepareForAppRestart() => _persist();

  Future<void> _persist() {
    final values = <String, Object?>{
      // A parsed snapshot awaiting credential verification must survive a
      // partially persisted legacy/fresh profile. Only a confirmed owner may
      // replace or invalidate this atomic monetary envelope.
      if (_energyOwner != null)
        '${storagePrefix}energy_v2_snapshot': _energyWallet == null
            ? null
            : jsonEncode({
                'owner': _energyOwner,
                'wallet': _energyWallet,
                'serverNow': energyNow.millisecondsSinceEpoch,
              }),
      '${storagePrefix}energy_helmet_selected': helmetSelected,
      '${storagePrefix}energy_jump_selected': jumpSelected,
      _kLives: lives,
      _kTokens: tokens,
      _kStreak: dailyStreak,
      _kBestTime: bestTimeMs,
      _kPremium: hasPremium,
      _kGamesStarted: gamesStartedCount,
      _kPremiumNextCharge: premiumNextChargeAt?.toIso8601String(),
      _kEarnClaimed: claimedEarnIds.toList(),
      _kEarnUnlocked: unlockedEarnIds.toList(),
      _kLastTimedBonus: lastTimedBonusClaimAt?.toIso8601String(),
      _kLastWatchAd: lastWatchAdClaimAt?.toIso8601String(),
      _kJumpRentalUntil: jumpRentalUntil?.toIso8601String(),
      _kHelmetRentalUntil: helmetRentalUntil?.toIso8601String(),
      _kDisplayName: ?displayName,
      if (interstitialArmedAt != null)
        _kAdArmed: interstitialArmedAt!.toIso8601String(),
      if (lastInterstitialAt != null)
        _kLastInterstitial: lastInterstitialAt!.toIso8601String(),
      if (lastDailyClaimAt != null)
        _kLastDaily: lastDailyClaimAt!.toIso8601String(),
      _kNextBonus: null,
    };
    final job = _persistJob.then((_) async {
      final writes = <Future<bool>>[];
      for (final entry in values.entries) {
        final before = _prefs.get(entry.key);
        final value = entry.value;
        if (!entry.key.endsWith('energy_v2_snapshot') &&
            (value is List<String>
                ? before is List<String> && listEquals(value, before)
                : before == value)) {
          continue;
        }
        writes.add(switch (value) {
          int v => _prefs.setInt(entry.key, v),
          bool v => _prefs.setBool(entry.key, v),
          String v => _prefs.setString(entry.key, v),
          List<String> v => _prefs.setStringList(entry.key, v),
          _ => _prefs.remove(entry.key),
        });
      }
      final results = await Future.wait(writes);
      if (results.any((ok) => !ok)) throw StateError('wallet_storage_failed');
      notifyListeners();
    });
    _persistJob = job.catchError((Object _) {});
    return job;
  }

  bool get canShowResultInterstitial {
    if (hasPremium ||
        energySubscribed ||
        (energyEnabled ? energy : lives) <
            config.interstitialMinLives.clamp(0, 99)) {
      return false;
    }
    final armed = interstitialArmedAt;
    if (armed == null) return false;
    final now = _now();
    if (_sessionCompletedRounds <=
            config.interstitialSessionFreeRounds.clamp(10, 1000) ||
        now.isBefore(
          _sessionStartedAt.add(
            Duration(
              seconds: config.interstitialSessionGraceSec.clamp(180, 86400),
            ),
          ),
        )) {
      return false;
    }
    if (now.isBefore(
      armed.add(Duration(seconds: config.interstitialGraceSec.clamp(0, 86400))),
    )) {
      return false;
    }
    final last = lastInterstitialAt;
    return last == null ||
        !now.isBefore(
          last.add(
            Duration(seconds: config.interstitialCooldownSec.clamp(0, 86400)),
          ),
        );
  }

  void markInterstitialShown() {
    lastInterstitialAt = _now();
    _persist();
  }

  bool get canPlay => energyEnabled ? energy >= attemptEnergyCost : lives > 0;

  /// Палец-подсказка только пока сыграно меньше 5 партий (5 жизней).
  bool get showSwipeHint => gamesStartedCount < swipeHintMaxGames;

  bool tryStartGame() {
    if (energyEnabled) return spendEnergyForPractice();
    if (lives <= 0) return false;
    lives -= 1;
    gamesStartedCount += 1;
    _persist();
    return true;
  }

  bool get canClaimDaily {
    final last = lastDailyClaimAt;
    if (last == null) return true;
    final now = _now();
    return DateTime(
      last.year,
      last.month,
      last.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }

  int get upcomingDailyTokens =>
      config.dailyTokensForStreak(upcomingStreakDay - 1, premium: hasPremium);

  /// День streak, который будет засчитан при следующем claim (1-based).
  int get upcomingStreakDay {
    final last = lastDailyClaimAt;
    final now = _now();
    if (last == null) return 1;
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final lastDay = DateTime(last.year, last.month, last.day);
    if (!canClaimDaily) return dailyStreak;
    if (lastDay == yesterday) {
      return (dailyStreak + 1).clamp(
        1,
        config.dailyRewardTokens.isEmpty ? 7 : config.dailyRewardTokens.length,
      );
    }
    if (_isSameCalendarDay(last, now)) return dailyStreak;
    return 1;
  }

  /// Возвращает начисленные кристалы или null, если нельзя.
  int? claimDaily() {
    if (!canClaimDaily) return null;
    final last = lastDailyClaimAt;
    final now = _now();
    if (last != null) {
      final yesterday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
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
    interstitialArmedAt ??= now;
    sendOperation?.call('daily', {});
    _persist();
    return amount;
  }

  /// До полуночи (когда Daily уже взят сегодня).
  Duration get untilMidnight {
    final now = _now();
    final next = DateTime(now.year, now.month, now.day + 1);
    return next.difference(now);
  }

  bool get canClaimTimedBonus {
    final ready = _timedBonusReadyAt;
    if (ready == null) return true;
    return !_now().isBefore(ready);
  }

  Duration? get timedBonusRemaining {
    final ready = _timedBonusReadyAt;
    if (ready == null) return null;
    final left = ready.difference(_now());
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
    final elapsed = _now().difference(last).inMilliseconds;
    return (elapsed / totalMs).clamp(0.0, 1.0);
  }

  int? claimTimedBonus() {
    if (!canClaimTimedBonus) return null;
    final amount = config.timedBonusTokens;
    tokens += amount;
    lastTimedBonusClaimAt = _now();
    sendOperation?.call('timed', {});
    _persist();
    return amount;
  }

  bool get canBuyLifePack =>
      canBuyLifePackOffer(config.resolvedLifePacks.first);

  bool canBuyLifePackOffer(LifePackOffer offer) => tokens >= offer.costTokens;

  bool buyLifePack() => buyLifePackOffer(config.resolvedLifePacks.first);

  bool buyLifePackOffer(LifePackOffer offer) {
    if (!canBuyLifePackOffer(offer)) return false;
    tokens -= offer.costTokens;
    lives += offer.lives;
    sendOperation?.call('lives', {'lives': offer.lives});
    _persist();
    return true;
  }

  /// Local credit, including round rewards. Purchase verification belongs to AP6.
  int grantCrystals(int amount) {
    if (energyEnabled) return 0; // V2 round rewards belong to server finish.
    if (amount <= 0) return 0;
    tokens += amount;
    _persist();
    notifyListeners();
    return amount;
  }

  bool get hasJumpRental {
    if (energyEnabled) return jumpSelected;
    final until = jumpRentalUntil;
    return until != null && until.isAfter(_now());
  }

  bool get hasHelmetRental {
    if (energyEnabled) return helmetSelected;
    final until = helmetRentalUntil;
    return until != null && until.isAfter(_now());
  }

  Duration? get jumpRentalRemaining {
    final until = jumpRentalUntil;
    if (until == null) return null;
    final left = until.difference(_now());
    if (left.isNegative || left.inMilliseconds <= 0) return null;
    return left;
  }

  Duration? get helmetRentalRemaining {
    final until = helmetRentalUntil;
    if (until == null) return null;
    final left = until.difference(_now());
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
    final minutes =
        (hour ? config.jumpRentalHourMinutes : config.jumpRentalMinutes).clamp(
          1,
          24 * 60,
        );
    if (tokens < cost) return false;
    tokens -= cost;
    final now = _now();
    final base = jumpRentalUntil != null && jumpRentalUntil!.isAfter(now)
        ? jumpRentalUntil!
        : now;
    jumpRentalUntil = base.add(Duration(minutes: minutes));
    sendOperation?.call('rent_jump', {'hour': hour});
    _persist();
    return true;
  }

  /// Аренда шлема: 1 касание без смерти за партию, пока аренда активна.
  bool rentHelmet({bool hour = false}) {
    final cost = hour ? config.helmetRentalHourCost : config.helmetRentalCost;
    final minutes =
        (hour ? config.helmetRentalHourMinutes : config.helmetRentalMinutes)
            .clamp(1, 24 * 60);
    if (tokens < cost) return false;
    tokens -= cost;
    final now = _now();
    final base = helmetRentalUntil != null && helmetRentalUntil!.isAfter(now)
        ? helmetRentalUntil!
        : now;
    helmetRentalUntil = base.add(Duration(minutes: minutes));
    sendOperation?.call('rent_helmet', {'hour': hour});
    _persist();
    return true;
  }

  /// Kept for old development screens; a local click cannot activate Plus.
  void activatePremiumPreview() {
    // AP6: only a verified Google Play purchase may set the entitlement.
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
    interstitialArmedAt = null;
    lastInterstitialAt = null;
    await _prefs.remove(_kAdArmed);
    await _prefs.remove(_kLastInterstitial);
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
    tokens = config.initialTokens;
    if (config.installBonusAutoClaim) {
      claimedEarnIds.add(EconomyConfig.installBonusId);
      unlockedEarnIds.add(EconomyConfig.installBonusId);
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
    if (energyEnabled) {
      return const []; // Only a confirmed finish unlocks V2 tasks.
    }
    final newly = <String>[];
    void tryUnlock(String id, bool condition) {
      if (!condition) return;
      if (claimedEarnIds.contains(id) || unlockedEarnIds.contains(id)) return;
      if (_earnActionById(id) == null) return;
      unlockedEarnIds.add(id);
      newly.add(id);
    }

    final surviveMs = (config.earnSurviveSeconds.clamp(1, 3600) * 1000);
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
    if (energyEnabled) return null;
    // Social actions cannot be credited by clicking a local preview button.
    if (id != EconomyConfig.installBonusId &&
        !EconomyConfig.gameplayEarnIds.contains(id)) {
      return null;
    }
    if (claimedEarnIds.contains(id)) return null;
    if (!isEarnUnlocked(id)) return null;
    final action = _earnActionById(id);
    if (action == null) return null;
    claimedEarnIds.add(id);
    unlockedEarnIds.add(id);
    tokens += action.reward;
    sendOperation?.call('earn', {'id': id});
    _persist();
    return action.reward;
  }

  /// Реклама из магазина (FREE) — многоразовая, с кулдауном из RC.
  int? claimWatchAd({int fallbackReward = 5}) {
    if (energyEnabled) return null; // AdsService awaits confirmed V2 credit.
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
    lastWatchAdClaimAt = _now();
    sendOperation?.call('watch_ad', {});
    // Не пишем в claimedEarnIds — рекламу можно смотреть снова после кулдауна.
    claimedEarnIds.remove(id);
    _persist();
    return reward;
  }

  Duration get _watchAdCooldown => Duration(
    seconds:
        (energyEnabled
                ? energyConfig.watchAdCooldownSec
                : config.watchAdCooldownSec)
            .clamp(0, 24 * 3600),
  );

  DateTime get _watchAdNow => energyEnabled ? energyNow : _now();

  DateTime? get _watchAdReadyAt {
    DateTime? last = lastWatchAdClaimAt;
    if (energyEnabled) {
      final testStamp =
          (_energyWallet?['lastTestVideoAt'] as num?)?.toInt() ?? 0;
      final realStamp = last?.millisecondsSinceEpoch ?? 0;
      if (testStamp > realStamp) {
        last = DateTime.fromMillisecondsSinceEpoch(testStamp);
      }
    }
    if (last == null) return null;
    final cd = _watchAdCooldown;
    if (cd.inSeconds <= 0) return null;
    return last.add(cd);
  }

  bool get canClaimWatchAd {
    if (watchAdDailyLimitReached) return false;
    final ready = _watchAdReadyAt;
    if (ready == null) return true;
    return !_watchAdNow.isBefore(ready);
  }

  int get watchAdDailyLimit => energyConfig.watchAdDailyLimit;
  int get watchAdsToday {
    final quota = _energyWallet?['adQuota'];
    if (!energyEnabled || quota is! Map) return 0;
    final reset = (quota['resetAt'] as num?)?.toInt();
    if (reset != null && energyNow.millisecondsSinceEpoch >= reset) return 0;
    return ((quota['used'] as num?)?.toInt() ?? 0).clamp(0, 100000);
  }

  bool get watchAdDailyLimitReached =>
      energyEnabled && watchAdsToday >= watchAdDailyLimit;

  Duration? get watchAdCooldownRemaining {
    final ready = _watchAdReadyAt;
    if (ready == null) return null;
    final left = ready.difference(_watchAdNow);
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

  /// One local transaction for defeat; rewards and thresholds match Mini App.
  List<String> completeRound({
    required int timeMs,
    required int runDistance,
    required int riskCount,
    bool grantReward = true,
  }) {
    recordCompletedRound();
    if (timeMs > bestTimeMs) bestTimeMs = timeMs;
    if (grantReward && !energyEnabled) {
      tokens += ArcadeRules.roundReward(config, runDistance, riskCount);
    }
    final newly = syncGameplayEarnUnlocks(
      aliveMs: timeMs,
      riskCount: riskCount,
      persist: false,
    );
    _persist();
    return newly;
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
