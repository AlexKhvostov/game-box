import '../domain/enemy_pace.dart';
import 'app_analytics.dart';

/// Simulation-time counters. Frequent gameplay actions never enter the SDK.
class RoundAnalytics {
  String? _runId;
  int _privacyEpoch = 0;
  int _readyCount = 0, _uses = 0, _sumMs = 0;
  int? _minMs, _maxMs, _firstMs;
  String? _firstBucket;
  bool _ready = false, _helmet = false, _jump = false;
  final Map<String, int> _abilities = {};
  final Map<String, int> _buckets = {};
  Map<String, Object> _context = {};
  bool get active => _runId != null;
  static const waitBuckets = [
    'under_1s',
    '1_3s',
    '3_5s',
    '5_10s',
    '10s_or_more',
  ];
  static String waitBucket(double seconds) => switch (seconds) {
    < 1 => 'under_1s',
    < 3 => '1_3s',
    < 5 => '3_5s',
    < 10 => '5_10s',
    _ => '10s_or_more',
  };
  void start({required bool helmet, required bool jump}) {
    AppAnalytics.screen = 'playing';
    _privacyEpoch = AppAnalytics.privacyEpoch;
    if (AppAnalytics.sink == null) {
      _runId = null;
      return;
    }
    _runId = AppAnalytics.nextId();
    _readyCount = _uses = _sumMs = 0;
    _minMs = _maxMs = _firstMs = null;
    _firstBucket = null;
    _ready = false;
    _helmet = helmet;
    _jump = jump;
    _abilities.clear();
    _buckets.clear();
    _context = Map.of(AppAnalytics.context);
    AppAnalytics.event('game_start', {
      ..._context,
      'run_id': _runId!,
      'helmet': helmet,
      'jump': jump,
    });
    AppAnalytics.screen = 'playing';
  }

  void observeBrake(EnemyPace? pace) {
    if (!active || pace == null || !pace.brakeEnabled) return;
    if (pace.ready && !_ready) {
      _ready = true;
      _readyCount++;
    }
  }

  void brakeUsed(EnemyPace pace, {required double readyWaitSec}) {
    if (!active || !readyWaitSec.isFinite) return;
    final seconds = readyWaitSec.clamp(0.0, double.infinity);
    final ms = (seconds * 1000).round();
    final bucket = waitBucket(seconds);
    _uses++;
    _sumMs += ms;
    _minMs = _minMs == null || ms < _minMs! ? ms : _minMs;
    _maxMs = _maxMs == null || ms > _maxMs! ? ms : _maxMs;
    _firstMs ??= ms;
    _firstBucket ??= bucket;
    _buckets.update(bucket, (n) => n + 1, ifAbsent: () => 1);
    _ready = false;
  }

  void abilityUsed(String ability, {required int timeMs}) {
    if (!active || (ability != 'jump' && ability != 'helmet')) return;
    _abilities.update(ability, (n) => n + 1, ifAbsent: () => 1);
  }

  void finish({
    String reason = 'collision',
    int? timeMs,
    int riskCount = 0,
    int runDistance = 0,
    EnemyPace? pace,
  }) {
    if (!active) return;
    if (_privacyEpoch != AppAnalytics.privacyEpoch ||
        AppAnalytics.sink == null) {
      _runId = null;
      return;
    }
    // Process loss, navigation and abandoned runs are deliberately not recovered.
    if (reason != 'collision') {
      _runId = null;
      return;
    }
    observeBrake(pace);
    final enabled = pace?.brakeEnabled == true;
    final unused = enabled && _ready && pace!.ready;
    AppAnalytics.event('game_finish', {
      ..._context,
      'run_id': _runId!,
      'finish_reason': reason,
      'time_ms': ?timeMs,
      if (timeMs != null)
        'duration_bucket': switch (timeMs) {
          < 10000 => 'under_10s',
          < 15000 => '10_15s',
          < 30000 => '15_30s',
          < 60000 => '30_60s',
          _ => '60s_or_more',
        },
      'risk_count': riskCount,
      'run_distance': runDistance,
      'jump_equipped': _jump,
      'helmet_equipped': _helmet,
      'jump_use_count': _abilities['jump'] ?? 0,
      'helmet_use_count': _abilities['helmet'] ?? 0,
      'brake_enabled': enabled,
      'brake_ready_count': _readyCount,
      'brake_use_count': _uses,
      'brake_wait_count': _uses,
      'brake_wait_sum_ms': _sumMs,
      'brake_wait_min_ms': ?_minMs,
      'brake_wait_max_ms': ?_maxMs,
      'brake_first_wait_ms': ?_firstMs,
      'brake_first_wait_bucket': _firstBucket ?? 'no_use',
      for (final bucket in waitBuckets)
        'brake_wait_${bucket}_count': _buckets[bucket] ?? 0,
      'brake_ready_unused_at_finish': unused,
      if (unused)
        'brake_ready_unused_ms':
            ((pace.elapsed - pace.readyAt).clamp(0.0, double.infinity) * 1000)
                .round(),
      'brake_usage_state': !enabled
          ? 'disabled'
          : _uses > 0
          ? 'used'
          : _readyCount > 0
          ? 'ready_unused'
          : 'never_ready',
    });
    _runId = null;
  }
}
