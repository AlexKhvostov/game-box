import 'dart:math' as math;

/// Cosmetic observer of actual cooldown/flight and the existing simulation clock.
/// It never grants a jump or advances gameplay, and starts without a flash.
class JumpReadySignal {
  static const flashDurationMs = 420.0;
  bool ready = false;
  bool _observed = false;
  double _lastNow = 0, _lastRemaining = 0;
  double? _readyAt;

  double? get ageMs => _readyAt == null ? null : _lastNow - _readyAt!;

  void reset() {
    ready = false;
    _observed = false;
    _readyAt = null;
    _lastNow = _lastRemaining = 0;
  }

  void observe({
    required bool enabled,
    required double remainingMs,
    required double nowMs,
  }) {
    if (!enabled ||
        !remainingMs.isFinite ||
        remainingMs < 0 ||
        !nowMs.isFinite ||
        nowMs < 0) {
      reset();
      return;
    }
    if (_observed && nowMs < _lastNow) reset();
    final nextReady = remainingMs == 0;
    if (!nextReady) {
      _readyAt = null;
    } else if (_observed && !ready) {
      // Preserve the boundary inside a long simulation step, as in H02.B.
      _readyAt = math.min(nowMs, _lastNow + _lastRemaining);
    }
    ready = nextReady;
    _observed = true;
    _lastNow = nowMs;
    _lastRemaining = remainingMs;
  }

  static double flash(double? ageMs, {bool reducedMotion = false}) {
    if (reducedMotion ||
        ageMs == null ||
        !ageMs.isFinite ||
        ageMs < 0 ||
        ageMs >= flashDurationMs) {
      return 0;
    }
    return math.sin(math.pi * ageMs / flashDurationMs);
  }
}
