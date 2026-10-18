import 'dart:math';

import 'economy_config.dart';

/// The currently published Mini App rules (telegram-web/js/util.js).
abstract final class ArcadeRules {
  static double wallInset(double borderWidth) =>
      (borderWidth / 2 + 0.5).clamp(0.5, 12) + borderWidth / 2;

  static double stepLength(double playerSize) =>
      max(1e-6, (playerSize == 0 ? 36 : playerSize) * 0.1);

  static int runSteps(double distancePx, double playerSize) =>
      max(0.0, distancePx / stepLength(playerSize)).round();

  static int score(int timeMs, int steps, int risks) =>
      (max(0, timeMs) / 1000 * max(0, steps) * (1 + max(0, risks))).round();

  static int riskReward(EconomyConfig config, int risks) =>
      max(0, risks) ~/
      max(1, config.riskRewardEvery) *
      max(0, config.riskRewardTokens);

  static int runReward(EconomyConfig config, int steps) =>
      max(0, steps) ~/
      max(1, config.runRewardEvery) *
      max(0, config.runRewardTokens);

  /// V2 changes the currency and keeps published thresholds unchanged.
  static int energyRoundReward(EconomyConfig config, int steps, int risks) =>
      max(0, risks) ~/ max(1, config.riskRewardEvery) +
      max(0, steps) ~/ max(1, config.runRewardEvery);

  static int roundReward(EconomyConfig config, int steps, int risks) =>
      riskReward(config, risks) + runReward(config, steps);
}
