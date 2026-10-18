/// Android's isolated energy economy. All dates are server milliseconds.
/// A cycle freezes its capacity and duration, so editing configuration never
/// changes already earned energy.
class EnergyBattery {
  const EnergyBattery({
    required this.id,
    required this.startedAtMs,
    required this.capacity,
    required this.durationMs,
    this.initialUnits = 0,
    this.revision = '',
    this.activeUntilMs,
  });
  final String id;
  final int startedAtMs, capacity, durationMs, initialUnits;
  final String revision;
  final int? activeUntilMs;
  factory EnergyBattery.fromJson(Map<String, dynamic> json) => EnergyBattery(
    id: '${json['id'] ?? 'free'}',
    startedAtMs: _integer(json['startedAt'], 0),
    capacity: _integer(json['capacity'], 20).clamp(1, 100000),
    durationMs: _integer(json['durationMs'], 28800000).clamp(1, 31536000000),
    initialUnits: _integer(json['initialUnits'], 0).clamp(0, 100000),
    revision: '${json['revision'] ?? ''}',
    activeUntilMs: json['activeUntil'] is num
        ? (json['activeUntil'] as num).toInt()
        : null,
  );
  int _elapsed(DateTime now) {
    final stamp =
        activeUntilMs != null && now.millisecondsSinceEpoch > activeUntilMs!
        ? activeUntilMs!
        : now.millisecondsSinceEpoch;
    return (stamp - startedAtMs).clamp(0, durationMs);
  }

  double progressAt(DateTime now) =>
      (initialUnits / capacity + _elapsed(now) / durationMs).clamp(0.0, 1.0);
  int unitsAt(DateTime now) =>
      (initialUnits + (_elapsed(now) * capacity ~/ durationMs)).clamp(
        0,
        capacity,
      );
  int percentAt(DateTime now) => (progressAt(now) * 100).floor();
  Duration remainingAt(DateTime now) => Duration(
    milliseconds:
        (durationMs * (capacity - initialUnits) ~/ capacity - _elapsed(now))
            .clamp(0, durationMs),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAtMs,
    'capacity': capacity,
    'durationMs': durationMs,
    'initialUnits': initialUnits,
    'revision': revision,
    'activeUntil': ?activeUntilMs,
  };
}

class EnergyPackage {
  const EnergyPackage(this.id, this.amount);
  final String id;
  final int amount;
  Map<String, dynamic> toJson() => {'id': id, 'amount': amount};
}

class EnergySubscriptionOffer {
  const EnergySubscriptionOffer(
    this.id,
    this.additionalBatteries, {
    this.basePlanId = 'weekly',
    this.batteryCapacity = 20,
    this.chargeHours = 8,
    this.periodDays = 7,
  });
  final String id, basePlanId;
  final int additionalBatteries, batteryCapacity, periodDays;
  final double chargeHours;
  int get totalBatteries => additionalBatteries + 1;
  Map<String, dynamic> toJson() => {
    'id': id,
    'additionalBatteries': additionalBatteries,
    'basePlanId': basePlanId,
    'batteryCount': totalBatteries,
    'batteryCapacity': batteryCapacity,
    'chargeHours': chargeHours,
    'periodDays': periodDays,
  };
}

/// Product contents are immutable by SKU, including when remote config changes.
/// New quantities require a new prepared SKU version and server catalog entry.
class AndroidEnergyConfig {
  const AndroidEnergyConfig({
    this.enabled = false,
    this.revision = 'energy-v1',
    this.initialEnergy = 20,
    this.batteryCapacity = 20,
    this.chargeHours = 8,
    this.baseAttemptCost = 1,
    this.helmetExtraCost = 1,
    this.jumpExtraCost = 1,
    this.watchAdCooldownSec = 120,
    this.rewards = const {
      'achievement': 10,
      'ad': 20,
      'google': 10,
      'age': 10,
      'feedback': 50,
      'invite': 20,
    },
    this.packages = defaultPackages,
    this.subscriptions = defaultSubscriptions,
  });
  static const defaultPackages = [
    EnergyPackage('energy_100_v1', 100),
    EnergyPackage('energy_250_v1', 250),
    EnergyPackage('energy_500_v1', 500),
    EnergyPackage('energy_1000_v1', 1000),
  ];
  static const defaultSubscriptions = [
    EnergySubscriptionOffer('energy_batteries_2_v1', 1),
    EnergySubscriptionOffer('energy_batteries_5_v1', 4),
  ];
  final bool enabled;
  final String revision;
  final int initialEnergy,
      batteryCapacity,
      baseAttemptCost,
      helmetExtraCost,
      jumpExtraCost,
      watchAdCooldownSec;
  final double chargeHours;
  final Map<String, int> rewards;
  final List<EnergyPackage> packages;
  final List<EnergySubscriptionOffer> subscriptions;
  int get durationMs => (chargeHours * 3600000).round();
  int reward(String id) =>
      rewards[id == 'watch_ad' ? 'ad' : id] ?? rewards['achievement'] ?? 10;
  factory AndroidEnergyConfig.fromJson(Map<String, dynamic> json) {
    const fallback = AndroidEnergyConfig();
    final rawRewards = json['rewards'];
    return AndroidEnergyConfig(
      enabled: json['enabled'] == true,
      revision: '${json['revision'] ?? fallback.revision}',
      initialEnergy: _integer(json['initialEnergy'], 20).clamp(0, 100000),
      batteryCapacity: _integer(json['batteryCapacity'], 20).clamp(1, 100000),
      chargeHours:
          (json['chargeHours'] is num
                  ? (json['chargeHours'] as num).toDouble()
                  : fallback.chargeHours)
              .clamp(0.01, 8760.0)
              .toDouble(),
      baseAttemptCost: _integer(json['baseAttemptCost'], 1).clamp(1, 1000),
      helmetExtraCost: _integer(json['helmetExtraCost'], 1).clamp(0, 1000),
      jumpExtraCost: _integer(json['jumpExtraCost'], 1).clamp(0, 1000),
      watchAdCooldownSec: _integer(
        json['watchAdCooldownSec'],
        120,
      ).clamp(0, 86400),
      rewards: {
        for (final entry in fallback.rewards.entries)
          entry.key: _integer(
            rawRewards is Map ? rawRewards[entry.key] : null,
            entry.value,
          ).clamp(0, 100000),
      },
      packages: _packages(json['packages']),
      subscriptions: _subscriptions(
        json['subscriptions'],
        capacity: _integer(json['batteryCapacity'], 20).clamp(1, 100000),
        hours:
            (json['chargeHours'] is num
                    ? (json['chargeHours'] as num).toDouble()
                    : fallback.chargeHours)
                .clamp(0.01, 8760.0),
      ),
    );
  }
  static List<EnergyPackage> _packages(dynamic raw) {
    if (raw is! List) return defaultPackages;
    final selected = <EnergyPackage>[];
    final ids = <String>{};
    for (final item in raw.whereType<Map>()) {
      final id = '${item['id'] ?? item['productId'] ?? ''}';
      final match = RegExp(
        r'^energy_([1-9][0-9]{0,6})_v([1-9][0-9]{0,3})$',
      ).firstMatch(id);
      if (match == null || !ids.add(id)) continue;
      final amount = _integer(item['amount'] ?? item['energy'], -1);
      if (amount != int.parse(match.group(1)!)) continue;
      selected.add(EnergyPackage(id, amount));
    }
    return List.unmodifiable(selected);
  }

  static List<EnergySubscriptionOffer> _subscriptions(
    dynamic raw, {
    required int capacity,
    required double hours,
  }) {
    if (raw is! List) {
      return defaultSubscriptions
          .map(
            (offer) => EnergySubscriptionOffer(
              offer.id,
              offer.additionalBatteries,
              batteryCapacity: capacity,
              chargeHours: hours,
            ),
          )
          .toList();
    }
    final selected = <EnergySubscriptionOffer>[];
    final ids = <String>{};
    for (final item in raw.whereType<Map>()) {
      final id = '${item['id'] ?? item['productId'] ?? ''}';
      final match = RegExp(
        r'^energy_batteries_([25])_v([1-9][0-9]{0,3})$',
      ).firstMatch(id);
      if (match == null || !ids.add(id)) continue;
      final count = _integer(
        item['batteryCount'],
        _integer(item['additionalBatteries'], -2) + 1,
      );
      final basePlan = '${item['basePlanId'] ?? 'weekly'}';
      if (count != int.parse(match.group(1)!) ||
          basePlan != 'weekly' ||
          _integer(item['periodDays'], 7) != 7) {
        continue;
      }
      selected.add(
        EnergySubscriptionOffer(
          id,
          count - 1,
          basePlanId: basePlan,
          batteryCapacity: _integer(
            item['batteryCapacity'] ?? item['capacity'],
            capacity,
          ).clamp(1, 100000),
          chargeHours:
              (item['chargeHours'] is num
                      ? (item['chargeHours'] as num).toDouble()
                      : hours)
                  .clamp(0.01, 8760.0),
        ),
      );
    }
    return List.unmodifiable(selected);
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'revision': revision,
    'initialEnergy': initialEnergy,
    'batteryCapacity': batteryCapacity,
    'chargeHours': chargeHours,
    'baseAttemptCost': baseAttemptCost,
    'helmetExtraCost': helmetExtraCost,
    'jumpExtraCost': jumpExtraCost,
    'watchAdCooldownSec': watchAdCooldownSec,
    'rewards': rewards,
    'packages': packages.map((e) => e.toJson()).toList(),
    'subscriptions': subscriptions.map((e) => e.toJson()).toList(),
  };
}

int _integer(dynamic value, int fallback) =>
    value is num ? value.toInt() : fallback;

/// Contract 3: one indivisible server reward. The current period is frozen on
/// claim, while entitlement and reward come from the last server policy.
class SimpleEnergyBonus {
  SimpleEnergyBonus.fromJson(Map<String, dynamic> data)
    : nextAtMs = _integer(data['nextAt'], 0),
      durationMs = _integer(
        data['durationMs'],
        28800000,
      ).clamp(1000, 2592000000),
      reward = _integer(data['reward'], 30).clamp(1, 100000),
      tier = const [1, 2, 5].contains(data['tier']) ? data['tier'] as int : 1,
      policy = Map<String, dynamic>.unmodifiable(
        data['policy'] is Map ? data['policy'] as Map : const {},
      );
  final int nextAtMs, durationMs, reward, tier;
  final Map<String, dynamic> policy;
  int rewardFor(int multiplier) => _integer(
    policy[multiplier == 5
        ? 'tier5Reward'
        : multiplier == 2
        ? 'tier2Reward'
        : 'reward'],
    multiplier * 30,
  ).clamp(1, 100000);
  int get periodSec => _integer(policy['periodSec'], 28800).clamp(1, 2592000);
  Duration remainingAt(DateTime now) => Duration(
    milliseconds: (nextAtMs - now.millisecondsSinceEpoch).clamp(0, durationMs),
  );
  double remainingFraction(DateTime now) =>
      remainingAt(now).inMilliseconds / durationMs;
}
