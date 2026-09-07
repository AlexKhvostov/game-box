/// Действие для заработка кристалов (реклама / соцсеть / и т.д.).
class EarnAction {
  const EarnAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.reward,
  });

  final String id;
  final String title;
  final String subtitle;
  final int reward;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'reward': reward,
      };

  factory EarnAction.fromJson(Map<String, dynamic> json) {
    return EarnAction(
      id: json['id'] as String? ?? 'unknown',
      title: json['title'] as String? ?? 'Reward',
      subtitle: json['subtitle'] as String? ?? '',
      reward: (json['reward'] as num?)?.toInt() ?? 5,
    );
  }
}

/// Пак конвертации кристалов → жизни.
class LifePackOffer {
  const LifePackOffer({
    required this.lives,
    required this.costTokens,
  });

  final int lives;
  final int costTokens;

  Map<String, dynamic> toJson() => {
        'lives': lives,
        'costTokens': costTokens,
      };

  factory LifePackOffer.fromJson(Map<String, dynamic> json) {
    return LifePackOffer(
      lives: EconomyConfig._asInt(json['lives'], 10),
      costTokens: EconomyConfig._asInt(
        json['costTokens'] ?? json['cost'],
        5,
      ),
    );
  }
}

/// Конфиг экономики. Значения можно обновлять из Firebase Remote Config.
class EconomyConfig {
  static const List<LifePackOffer> defaultLifePacks = [
    LifePackOffer(lives: 5, costTokens: 5),
    LifePackOffer(lives: 15, costTokens: 12),
    LifePackOffer(lives: 50, costTokens: 30),
    LifePackOffer(lives: 250, costTokens: 99),
  ];

  /// Id действия «бонус за установку» в earnActions.
  static const installBonusId = 'install_bonus';
  static const survive10Id = 'survive_10s';
  static const record20Id = 'record_20s';
  static const risks5Id = 'risks_5';

  /// Earn-бонусы, которые открываются геймплеем (не по тапу-заглушке).
  static const Set<String> gameplayEarnIds = {
    survive10Id,
    record20Id,
    risks5Id,
  };

  const EconomyConfig({
    this.initialLives = 10,
    this.initialTokens = 40,
    this.installBonusAutoClaim = true,
    this.earnSurviveSeconds = 10,
    this.earnRecordSeconds = 20,
    this.earnRisksInRun = 5,
    this.lifePackSize = 5,
    this.lifePackCostTokens = 5,
    this.lifePacks = defaultLifePacks,
    this.dailyRewardTokens = const [2, 4, 9, 16, 32, 64, 81],
    this.timedBonusTokens = 22,
    this.timedBonusHours = 1,
    this.watchAdCooldownSec = 60,
    this.premiumDailyMultiplier = 2.0,
    this.jumpRentalCost = 20,
    this.jumpRentalMinutes = 10,
    this.jumpRentalHourCost = 60,
    this.jumpRentalHourMinutes = 60,
    this.helmetRentalCost = 40,
    this.helmetRentalMinutes = 10,
    this.helmetRentalHourCost = 120,
    this.helmetRentalHourMinutes = 60,
    this.riskRewardEvery = 5,
    this.riskRewardTokens = 1,
    this.runRewardEvery = 200,
    this.runRewardTokens = 1,
    this.earnActions = const [
      EarnAction(
        id: installBonusId,
        title: 'Install bonus',
        subtitle: 'Welcome gift for installing',
        reward: 40,
      ),
      EarnAction(
        id: survive10Id,
        title: 'Survive 10 seconds',
        subtitle: 'Stay alive for 10s in one run',
        reward: 5,
      ),
      EarnAction(
        id: record20Id,
        title: '20 second record',
        subtitle: 'Reach a 20s personal best',
        reward: 10,
      ),
      EarnAction(
        id: risks5Id,
        title: '5 risks in one run',
        subtitle: 'Score 5 risks in a single game',
        reward: 5,
      ),
      EarnAction(
        id: 'watch_ad',
        title: 'Watch an ad',
        subtitle: 'Short video',
        reward: 5,
      ),
      EarnAction(
        id: 'social_post',
        title: 'Social post',
        subtitle: 'Tell your friends',
        reward: 10,
      ),
      EarnAction(
        id: 'enable_notifications',
        title: 'Notifications',
        subtitle: 'Allow push alerts',
        reward: 5,
      ),
      EarnAction(
        id: 'rate_app',
        title: 'Rate the game',
        subtitle: 'Stars in the store',
        reward: 5,
      ),
      EarnAction(
        id: 'invite_friend',
        title: 'Invite a friend',
        subtitle: 'Share a link',
        reward: 10,
      ),
    ],
  });

  final int initialLives;

  /// Стартовые кристалы при первой установке (приз; в Earn — install_bonus).
  final int initialTokens;

  /// Если true — бонус за установку выдаётся сразу и отмечается выполненным в Earn.
  /// Если false — игрок забирает сам во вкладке Earn.
  final bool installBonusAutoClaim;

  /// Порог Earn `survive_10s` (секунды в одной партии).
  final int earnSurviveSeconds;

  /// Порог Earn `record_20s` (личный рекорд, секунды).
  final int earnRecordSeconds;

  /// Порог Earn `risks_5` (рисков в одной партии).
  final int earnRisksInRun;

  /// Legacy: первый пак (для старых клиентов / RC без lifePacks).
  final int lifePackSize;
  final int lifePackCostTokens;

  /// Пакеты обмена кристалов на жизни.
  final List<LifePackOffer> lifePacks;

  final List<int> dailyRewardTokens;
  final int timedBonusTokens;
  final int timedBonusHours;
  /// Кулдаун кнопки «смотреть рекламу» в секундах (0 = без фриза).
  final int watchAdCooldownSec;
  final double premiumDailyMultiplier;

  /// Аренда прыжка (короткая). Вкл/выкл фичи — в `game.jumpEnabled`.
  final int jumpRentalCost;
  final int jumpRentalMinutes;

  /// Аренда прыжка на час (со скидкой относительно 6× короткой).
  final int jumpRentalHourCost;
  final int jumpRentalHourMinutes;

  /// Аренда шлема (короткая). Вкл/выкл — `game.helmetEnabled`.
  final int helmetRentalCost;
  final int helmetRentalMinutes;

  /// Аренда шлема на час (со скидкой).
  final int helmetRentalHourCost;
  final int helmetRentalHourMinutes;

  /// За каждые [riskRewardEvery] рисков в раунде — [riskRewardTokens] кристалов.
  final int riskRewardEvery;
  final int riskRewardTokens;

  /// За каждые [runRewardEvery] шагов пробега — [runRewardTokens] кристалов.
  /// 1 шаг = 0.1 × ширина героя.
  final int runRewardEvery;
  final int runRewardTokens;

  final List<EarnAction> earnActions;

  /// «Полная» цена часа без скидки (как если купить короткими слотами).
  int get jumpRentalHourListPrice {
    final short = jumpRentalMinutes.clamp(1, 24 * 60);
    final hour = jumpRentalHourMinutes.clamp(1, 24 * 60);
    return ((jumpRentalCost * hour) / short).round().clamp(1, 99999);
  }

  int get helmetRentalHourListPrice {
    final short = helmetRentalMinutes.clamp(1, 24 * 60);
    final hour = helmetRentalHourMinutes.clamp(1, 24 * 60);
    return ((helmetRentalCost * hour) / short).round().clamp(1, 99999);
  }

  int get jumpRentalHourDiscountPercent {
    final list = jumpRentalHourListPrice;
    if (list <= 0 || jumpRentalHourCost >= list) return 0;
    return (((list - jumpRentalHourCost) / list) * 100).round().clamp(0, 99);
  }

  int get helmetRentalHourDiscountPercent {
    final list = helmetRentalHourListPrice;
    if (list <= 0 || helmetRentalHourCost >= list) return 0;
    return (((list - helmetRentalHourCost) / list) * 100).round().clamp(0, 99);
  }

  /// Актуальный список паков (из RC или fallback на legacy поля).
  List<LifePackOffer> get resolvedLifePacks {
    if (lifePacks.isNotEmpty) return lifePacks;
    return [LifePackOffer(lives: lifePackSize, costTokens: lifePackCostTokens)];
  }

  /// Награда за установку: reward из earn `install_bonus`, иначе [initialTokens].
  int get resolvedInstallBonusTokens {
    for (final a in earnActions) {
      if (a.id == installBonusId) return a.reward.clamp(0, 99999);
    }
    return initialTokens.clamp(0, 99999);
  }

  int dailyTokensForStreak(int streak, {bool premium = false}) {
    if (dailyRewardTokens.isEmpty) return premium ? 8 : 4;
    final index = streak.clamp(0, dailyRewardTokens.length - 1);
    final base = dailyRewardTokens[index];
    if (!premium) return base;
    return (base * premiumDailyMultiplier).round().clamp(base, 99999);
  }

  EconomyConfig copyWith({
    int? initialLives,
    int? initialTokens,
    bool? installBonusAutoClaim,
    int? earnSurviveSeconds,
    int? earnRecordSeconds,
    int? earnRisksInRun,
    int? lifePackSize,
    int? lifePackCostTokens,
    List<LifePackOffer>? lifePacks,
    List<int>? dailyRewardTokens,
    int? timedBonusTokens,
    int? timedBonusHours,
    int? watchAdCooldownSec,
    double? premiumDailyMultiplier,
    int? jumpRentalCost,
    int? jumpRentalMinutes,
    int? jumpRentalHourCost,
    int? jumpRentalHourMinutes,
    int? helmetRentalCost,
    int? helmetRentalMinutes,
    int? helmetRentalHourCost,
    int? helmetRentalHourMinutes,
    int? riskRewardEvery,
    int? riskRewardTokens,
    int? runRewardEvery,
    int? runRewardTokens,
    List<EarnAction>? earnActions,
  }) {
    return EconomyConfig(
      initialLives: initialLives ?? this.initialLives,
      initialTokens: initialTokens ?? this.initialTokens,
      installBonusAutoClaim:
          installBonusAutoClaim ?? this.installBonusAutoClaim,
      earnSurviveSeconds: earnSurviveSeconds ?? this.earnSurviveSeconds,
      earnRecordSeconds: earnRecordSeconds ?? this.earnRecordSeconds,
      earnRisksInRun: earnRisksInRun ?? this.earnRisksInRun,
      lifePackSize: lifePackSize ?? this.lifePackSize,
      lifePackCostTokens: lifePackCostTokens ?? this.lifePackCostTokens,
      lifePacks: lifePacks ?? this.lifePacks,
      dailyRewardTokens: dailyRewardTokens ?? this.dailyRewardTokens,
      timedBonusTokens: timedBonusTokens ?? this.timedBonusTokens,
      timedBonusHours: timedBonusHours ?? this.timedBonusHours,
      watchAdCooldownSec: watchAdCooldownSec ?? this.watchAdCooldownSec,
      premiumDailyMultiplier:
          premiumDailyMultiplier ?? this.premiumDailyMultiplier,
      jumpRentalCost: jumpRentalCost ?? this.jumpRentalCost,
      jumpRentalMinutes: jumpRentalMinutes ?? this.jumpRentalMinutes,
      jumpRentalHourCost: jumpRentalHourCost ?? this.jumpRentalHourCost,
      jumpRentalHourMinutes:
          jumpRentalHourMinutes ?? this.jumpRentalHourMinutes,
      helmetRentalCost: helmetRentalCost ?? this.helmetRentalCost,
      helmetRentalMinutes: helmetRentalMinutes ?? this.helmetRentalMinutes,
      helmetRentalHourCost: helmetRentalHourCost ?? this.helmetRentalHourCost,
      helmetRentalHourMinutes:
          helmetRentalHourMinutes ?? this.helmetRentalHourMinutes,
      riskRewardEvery: riskRewardEvery ?? this.riskRewardEvery,
      riskRewardTokens: riskRewardTokens ?? this.riskRewardTokens,
      runRewardEvery: runRewardEvery ?? this.runRewardEvery,
      runRewardTokens: runRewardTokens ?? this.runRewardTokens,
      earnActions: earnActions ?? this.earnActions,
    );
  }

  Map<String, dynamic> toJson() => {
        'initialLives': initialLives,
        'initialTokens': initialTokens,
        'installBonusAutoClaim': installBonusAutoClaim,
        'earnSurviveSeconds': earnSurviveSeconds,
        'earnRecordSeconds': earnRecordSeconds,
        'earnRisksInRun': earnRisksInRun,
        'lifePackSize': lifePackSize,
        'lifePackCostTokens': lifePackCostTokens,
        'lifePacks': lifePacks.map((e) => e.toJson()).toList(),
        'dailyRewardTokens': dailyRewardTokens,
        'timedBonusTokens': timedBonusTokens,
        'timedBonusHours': timedBonusHours,
        'watchAdCooldownSec': watchAdCooldownSec,
        'premiumDailyMultiplier': premiumDailyMultiplier,
        'jumpRentalCost': jumpRentalCost,
        'jumpRentalMinutes': jumpRentalMinutes,
        'jumpRentalHourCost': jumpRentalHourCost,
        'jumpRentalHourMinutes': jumpRentalHourMinutes,
        'helmetRentalCost': helmetRentalCost,
        'helmetRentalMinutes': helmetRentalMinutes,
        'helmetRentalHourCost': helmetRentalHourCost,
        'helmetRentalHourMinutes': helmetRentalHourMinutes,
        'riskRewardEvery': riskRewardEvery,
        'riskRewardTokens': riskRewardTokens,
        'runRewardEvery': runRewardEvery,
        'runRewardTokens': runRewardTokens,
        'earnActions': earnActions.map((e) => e.toJson()).toList(),
      };

  factory EconomyConfig.fromJson(Map<String, dynamic> json) {
    final rewards = json['dailyRewardTokens'];
    final earnRaw = json['earnActions'];
    final packsRaw = json['lifePacks'];
    final legacySize = _asInt(json['lifePackSize'], 5);
    final legacyCost = _asInt(json['lifePackCostTokens'], 5);

    // lifePacks из RC — источник истины (без дописки дефолтов из APK).
    // Иначе удалённо нельзя убрать/заменить пак: клиент снова подмешает 10/20/…
    List<LifePackOffer> packs;
    if (packsRaw is List && packsRaw.isNotEmpty) {
      packs = packsRaw
          .map((e) => LifePackOffer.fromJson(e as Map<String, dynamic>))
          .where((p) => p.lives > 0 && p.costTokens > 0)
          .toList();
    } else {
      // Старый RC без lifePacks: первый пак из legacy-полей + остальные дефолты.
      packs = [
        LifePackOffer(lives: legacySize, costTokens: legacyCost),
        ...defaultLifePacks.skip(1),
      ];
      packs = _fillMissingDefaultLifePacks(packs);
    }
    if (packs.isEmpty) packs = List.of(defaultLifePacks);

    return EconomyConfig(
      initialLives: _asInt(json['initialLives'], 10),
      initialTokens: _asInt(json['initialTokens'], 40),
      installBonusAutoClaim: _asBool(json['installBonusAutoClaim'], true),
      earnSurviveSeconds: _asInt(json['earnSurviveSeconds'], 10),
      earnRecordSeconds: _asInt(json['earnRecordSeconds'], 20),
      earnRisksInRun: _asInt(json['earnRisksInRun'], 5),
      lifePackSize: packs.first.lives,
      lifePackCostTokens: packs.first.costTokens,
      lifePacks: packs,
      dailyRewardTokens: rewards is List
          ? rewards.map((e) => _asInt(e, 0)).where((e) => e > 0).toList()
          : const [2, 4, 9, 16, 32, 64, 81],
      timedBonusTokens: _asInt(
        json['timedBonusTokens'] ?? json['timedBonusToken'],
        22,
      ),
      timedBonusHours: _asInt(json['timedBonusHours'], 1),
      watchAdCooldownSec: _asInt(
        json['watchAdCooldownSec'] ?? json['adCooldownSec'],
        60,
      ),
      premiumDailyMultiplier: _asDouble(json['premiumDailyMultiplier'], 2.0),
      jumpRentalCost: _asInt(json['jumpRentalCost'], 20),
      jumpRentalMinutes: _asInt(json['jumpRentalMinutes'], 10),
      jumpRentalHourCost: _asInt(json['jumpRentalHourCost'], 60),
      jumpRentalHourMinutes: _asInt(json['jumpRentalHourMinutes'], 60),
      helmetRentalCost: _asInt(json['helmetRentalCost'], 40),
      helmetRentalMinutes: _asInt(json['helmetRentalMinutes'], 10),
      helmetRentalHourCost: _asInt(json['helmetRentalHourCost'], 120),
      helmetRentalHourMinutes: _asInt(json['helmetRentalHourMinutes'], 60),
      riskRewardEvery: _asInt(json['riskRewardEvery'], 5),
      riskRewardTokens: _asInt(json['riskRewardTokens'], 1),
      runRewardEvery: _asInt(json['runRewardEvery'], 200),
      runRewardTokens: _asInt(json['runRewardTokens'], 1),
      earnActions: _mergeEarnActions(
        earnRaw is List && earnRaw.isNotEmpty
            ? earnRaw
                .map((e) => EarnAction.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
      ),
    );
  }

  /// Только для legacy-RC без `lifePacks`: дописать дефолтные размеры, которых нет.
  static List<LifePackOffer> _fillMissingDefaultLifePacks(
    List<LifePackOffer> packs,
  ) {
    final seen = <int>{for (final p in packs) p.lives};
    final ordered = List<LifePackOffer>.of(packs);
    for (final p in defaultLifePacks) {
      if (seen.add(p.lives)) ordered.add(p);
    }
    return ordered;
  }

  /// RC может содержать устаревший список — недостающие дефолтные id
  /// (install / 10с / 20с / 5 рисков / …) подмешиваем из клиента.
  /// Совпадающие id: приоритет у RC (reward и т.д.).
  static List<EarnAction> _mergeEarnActions(List<EarnAction>? fromRc) {
    final defaults = const EconomyConfig().earnActions;
    if (fromRc == null || fromRc.isEmpty) return List.of(defaults);

    final byId = <String, EarnAction>{
      for (final a in defaults) a.id: a,
    };
    for (final a in fromRc) {
      byId[a.id] = a;
    }

    final result = <EarnAction>[];
    final seen = <String>{};
    for (final a in defaults) {
      result.add(byId[a.id]!);
      seen.add(a.id);
    }
    for (final a in fromRc) {
      if (seen.add(a.id)) result.add(a);
    }
    return result;
  }

  static int _asInt(Object? value, int fallback) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static double _asDouble(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static bool _asBool(Object? value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return fallback;
  }
}
