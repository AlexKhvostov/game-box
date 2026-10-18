import 'dart:math' as math;
import 'gameplay_config.dart';

/// Keep in parity with server android-constraints.mjs. Only Android's fixed
/// world uses this contract; historical floors and Telegram remain independent.
abstract final class AndroidGameConstraints {
  static bool playable(GameplayConfig config) {
    final hero = config.playerSize * 1.2;
    if (!hero.isFinite || hero / 380 < .03 || hero / 380 > .25) return false;
    final aspects = config.enemyAspects;
    if (aspects.length != 4 ||
        aspects.any((a) => !a.isFinite || a <= .05 || a >= 50)) {
      return false;
    }
    final border = config.borderWidth;
    final inset = (border / 2 + .5).clamp(.5, 12) + border / 2;
    final pad = math.max(8.0, inset + 2), quadrant = 190 - 2 * pad;
    final area = hero * hero * config.enemyAreaMultiplier.clamp(.2, 20);
    final spinning = config.enemySpinDegPerSec.abs() > .01;
    return aspects.every((aspect) {
      final w = math.sqrt(area * aspect), h = math.sqrt(area / aspect);
      return (w + h).isFinite &&
          (spinning
              ? math.sqrt(w * w + h * h) <= quadrant
              : w <= quadrant && h <= quadrant);
    });
  }
}
