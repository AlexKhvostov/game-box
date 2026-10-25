import 'dart:math' as math;

/// One round's shield and simulation clock. Zero means one use, never instant
/// regeneration. Shared verbatim with the version-three server replay.
class HelmetCharge {
  HelmetCharge({required this.equipped, required double cooldownSec})
    : cooldownMs = cooldownSec.isFinite && cooldownSec > 0
          ? cooldownSec.clamp(0.0, 3600.0) * 1000
          : 0,
      ready = equipped;

  final bool equipped;
  final double cooldownMs;
  bool ready;
  double _nowMs = 0;
  double? _readyAtMs;

  bool advanceTo(double nowMs) {
    if (!nowMs.isFinite || nowMs < _nowMs) {
      throw ArgumentError.value(nowMs, 'nowMs');
    }
    _nowMs = nowMs;
    if (!ready && equipped && _readyAtMs != null && nowMs >= _readyAtMs!) {
      ready = true;
      _readyAtMs = null;
      return true;
    }
    return false;
  }

  bool consume() {
    if (!ready) return false;
    ready = false;
    _readyAtMs = cooldownMs > 0 ? _nowMs + cooldownMs : null;
    return true;
  }

  double get remainingMs =>
      _readyAtMs == null ? 0 : math.max(0.0, _readyAtMs! - _nowMs);
  double get progress => ready
      ? 1
      : cooldownMs > 0 && _readyAtMs != null
      ? (1 - remainingMs / cooldownMs).clamp(0.0, 1.0)
      : 0;
  bool get cooling => equipped && !ready && _readyAtMs != null;
}
