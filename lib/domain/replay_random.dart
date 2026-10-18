import 'dart:math';

/// Explicit portable PRNG: Dart VM and compiled server JS produce the same run.
class ReplayRandom implements Random {
  ReplayRandom(String requestId) : _state = seedFor(requestId);
  int _state;
  static int seedFor(String value) {
    var result = 2166136261;
    for (final unit in value.codeUnits) {
      result ^= unit;
      result = (result * 403 + ((result & 255) << 24)) & 0xffffffff;
    }
    return result == 0 ? 1 : result;
  }

  int _next() {
    var x = _state;
    x = (x ^ (x << 13)) & 0xffffffff;
    x = (x ^ (x >> 17)) & 0xffffffff;
    x = (x ^ (x << 5)) & 0xffffffff;
    return _state = x;
  }

  @override
  double nextDouble() => _next() / 4294967296;
  @override
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max);
    return (nextDouble() * max).floor();
  }

  @override
  bool nextBool() => (_next() & 1) != 0;
}
