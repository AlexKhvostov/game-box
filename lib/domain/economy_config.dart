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
    LifePackOffer(lives: 10, costTokens: 5),
    LifePackOffer(lives: 12, costTokens: 10),
    LifePackOffer(lives: 20, costTokens: 15),
  ];

  const EconomyConfig({
    this.initialLives = 10,
    this.lifePackSize = 10,
    this.lifePackCostTokens = 5,
    this.lifePacks = defaultLifePacks,
    this.dailyRewardTokens = const [2, 4, 9, 16, 32, 64, 81],
    this.timedBonusTokens = 22,
    this.timedBonusHours = 1,
    this.premiumDailyMultiplier = 2.0,
    this.earnActions = const [
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

  /// Legacy: первый пак (для старых клиентов / RC без lifePacks).
  final int lifePackSize;
  final int lifePackCostTokens;

  /// Пакеты обмена кристалов на жизни.
  final List<LifePackOffer> lifePacks;

  final List<int> dailyRewardTokens;
  final int timedBonusTokens;
  final int timedBonusHours;
  final double premiumDailyMultiplier;
  final List<EarnAction> earnActions;

  /// Актуальный список паков (из RC или fallback на legacy поля).
  List<LifePackOffer> get resolvedLifePacks {
    if (lifePacks.isNotEmpty) return lifePacks;
    return [LifePackOffer(lives: lifePackSize, costTokens: lifePackCostTokens)];
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
    int? lifePackSize,
    int? lifePackCostTokens,
    List<LifePackOffer>? lifePacks,
    List<int>? dailyRewardTokens,
    int? timedBonusTokens,
    int? timedBonusHours,
    double? premiumDailyMultiplier,
    List<EarnAction>? earnActions,
  }) {
    return EconomyConfig(
      initialLives: initialLives ?? this.initialLives,
      lifePackSize: lifePackSize ?? this.lifePackSize,
      lifePackCostTokens: lifePackCostTokens ?? this.lifePackCostTokens,
      lifePacks: lifePacks ?? this.lifePacks,
      dailyRewardTokens: dailyRewardTokens ?? this.dailyRewardTokens,
      timedBonusTokens: timedBonusTokens ?? this.timedBonusTokens,
      timedBonusHours: timedBonusHours ?? this.timedBonusHours,
      premiumDailyMultiplier:
          premiumDailyMultiplier ?? this.premiumDailyMultiplier,
      earnActions: earnActions ?? this.earnActions,
    );
  }

  Map<String, dynamic> toJson() => {
        'initialLives': initialLives,
        'lifePackSize': lifePackSize,
        'lifePackCostTokens': lifePackCostTokens,
        'lifePacks': lifePacks.map((e) => e.toJson()).toList(),
        'dailyRewardTokens': dailyRewardTokens,
        'timedBonusTokens': timedBonusTokens,
        'timedBonusHours': timedBonusHours,
        'premiumDailyMultiplier': premiumDailyMultiplier,
        'earnActions': earnActions.map((e) => e.toJson()).toList(),
      };

  factory EconomyConfig.fromJson(Map<String, dynamic> json) {
    final rewards = json['dailyRewardTokens'];
    final earnRaw = json['earnActions'];
    final packsRaw = json['lifePacks'];
    final legacySize = _asInt(json['lifePackSize'], 10);
    final legacyCost = _asInt(json['lifePackCostTokens'], 5);

    List<LifePackOffer> packs;
    if (packsRaw is List && packsRaw.isNotEmpty) {
      packs = packsRaw
          .map((e) => LifePackOffer.fromJson(e as Map<String, dynamic>))
          .where((p) => p.lives > 0 && p.costTokens > 0)
          .toList();
    } else {
      packs = [
        LifePackOffer(lives: legacySize, costTokens: legacyCost),
        ...defaultLifePacks.skip(1),
      ];
    }
    if (packs.isEmpty) packs = List.of(defaultLifePacks);

    return EconomyConfig(
      initialLives: _asInt(json['initialLives'], 10),
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
      premiumDailyMultiplier: _asDouble(json['premiumDailyMultiplier'], 2.0),
      earnActions: earnRaw is List && earnRaw.isNotEmpty
          ? earnRaw
              .map((e) => EarnAction.fromJson(e as Map<String, dynamic>))
              .toList()
          : const EconomyConfig().earnActions,
    );
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
}
