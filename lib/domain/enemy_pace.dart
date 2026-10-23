// Shared curve and rewind clock. Units: hero steps/second, seconds of active play.
import 'dart:math' as math;

class EnemyPaceSettings {
  const EnemyPaceSettings({
    this.initialSpeed = 0,
    this.growthMultiplier = 70,
    this.growthExponent = .2,
    this.startSmoothingSec = 3,
    this.initialCompensation = 1,
    this.brakeCooldownSec = 6,
    this.brakeFirstReadySec = 6,
    this.brakeRewindSec = 6,
    this.brakeEnabled = true,
    this.speedBarEnabled = true,
  });
  final double initialSpeed,
      growthMultiplier,
      growthExponent,
      startSmoothingSec,
      initialCompensation,
      brakeCooldownSec,
      brakeFirstReadySec,
      brakeRewindSec;
  final bool brakeEnabled, speedBarEnabled;
  factory EnemyPaceSettings.fromJson(dynamic raw) {
    final p = EnemyPace(raw);
    return EnemyPaceSettings(
      initialSpeed: p.initial,
      growthMultiplier: p.multiplier,
      growthExponent: p.exponent,
      startSmoothingSec: p.smoothing,
      initialCompensation: p.compensation,
      brakeCooldownSec: p.cooldown,
      brakeFirstReadySec: p.firstReady,
      brakeRewindSec: p.rewind,
      brakeEnabled: p.brakeEnabled,
      speedBarEnabled: p.speedBarEnabled,
    );
  }
  Map<String, dynamic> toJson() => {
    'initialSpeed': initialSpeed,
    'growthMultiplier': growthMultiplier,
    'growthExponent': growthExponent,
    'startSmoothingSec': startSmoothingSec,
    'initialCompensation': initialCompensation,
    'brakeCooldownSec': brakeCooldownSec,
    'brakeFirstReadySec': brakeFirstReadySec,
    'brakeRewindSec': brakeRewindSec,
    'brakeEnabled': brakeEnabled,
    'speedBarEnabled': speedBarEnabled,
  };
}

class EnemyPace {
  EnemyPace(dynamic raw) {
    final m = raw is EnemyPaceSettings
        ? raw.toJson()
        : raw is Map
        ? raw
        : const {};
    double value(String key, double fallback, double lo, double hi) {
      final v = m[key] ?? fallback;
      if (v is! num || !v.isFinite || v < lo || v > hi) {
        throw FormatException('enemy_pace_$key');
      }
      return v.toDouble();
    }

    bool flag(String key) {
      final v = m.containsKey(key) ? m[key] : true;
      if (v is! bool) throw FormatException('enemy_pace_$key');
      return v;
    }

    brakeEnabled = flag('brakeEnabled');
    speedBarEnabled = flag('speedBarEnabled');
    initial = value('initialSpeed', 0, 0, 150);
    multiplier = value('growthMultiplier', 70, 0, 200);
    exponent = value('growthExponent', .2, .01, 1);
    smoothing = value('startSmoothingSec', 3, .01, 60);
    compensation = value('initialCompensation', 1, 0, 10);
    cooldown = value('brakeCooldownSec', 6, .1, 120);
    firstReady = value('brakeFirstReadySec', 6, .1, 120);
    rewind = value('brakeRewindSec', 6, 0, 120);
    readyAt = firstReady;
  }
  late final bool brakeEnabled, speedBarEnabled;
  late final double initial,
      multiplier,
      exponent,
      smoothing,
      compensation,
      cooldown,
      firstReady,
      rewind;
  double elapsed = 0,
      effective = 0,
      readyAt = 0,
      lastPress = -100,
      lastReady = 0;
  double loss = 0, before = 0, after = 0;
  int presses = 0;
  static const settleSec = .18;
  double speedAt(double x) => math.max(
    0,
    initial +
        multiplier *
            (math.pow(math.max(0, x) + smoothing, exponent) - compensation),
  );
  double get target => speedAt(effective);
  double get speed =>
      target + loss * (1 - (elapsed - lastPress) / settleSec).clamp(0, 1);
  bool get ready => brakeEnabled && elapsed + 1e-9 >= readyAt;
  double get charge => !brakeEnabled
      ? 0
      : ready
      ? 1
      : ((elapsed - (presses == 0 ? 0 : lastPress)) /
                (presses == 0 ? firstReady : cooldown))
            .clamp(0, 1);
  void advance(double dt) {
    elapsed += dt;
    effective += dt;
  }

  bool press() {
    if (!ready) return false;
    before = speed;
    effective = math.max(0, effective - rewind);
    after = target;
    loss = math.max(0, before - after);
    lastPress = elapsed;
    readyAt = elapsed + cooldown;
    presses++;
    return true;
  }

  bool pressOnFloor({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    required double playerSize,
    required bool grounded,
  }) {
    if (!brakeEnabled || !ready || !grounded) return false;
    final half = playerSize / 2;
    var lo = 0.0, hi = 1.0;
    for (final axis in [
      [fromX + half, toX + half],
      [fromY + half, toY + half],
    ]) {
      final d = axis[1] - axis[0];
      if (d.abs() < 1e-9) {
        if (axis[0] <= 190 - playerSize || axis[0] >= 190 + playerSize) {
          return false;
        }
      } else {
        var a = (190 - playerSize - axis[0]) / d,
            b = (190 + playerSize - axis[0]) / d;
        if (a > b) {
          final tmp = a;
          a = b;
          b = tmp;
        }
        lo = math.max(lo, a);
        hi = math.min(hi, b);
      }
    }
    return lo <= hi && press();
  }

  Map<String, dynamic> get snapshot => {
    'enabled': brakeEnabled,
    'speedBarEnabled': speedBarEnabled,
    'effectiveSec': effective,
    'speed': speed,
    'targetSpeed': target,
    'charge': charge,
    'ready': ready,
    'presses': presses,
    'pressAgeMs': presses == 0 ? -1 : (elapsed - lastPress) * 1000,
    'readyAgeMs': ready ? (elapsed - readyAt) * 1000 : -1,
    'beforeSpeed': before,
    'afterSpeed': after,
  };
}
