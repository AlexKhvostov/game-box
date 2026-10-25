/// Bounded counters for instrumented UI actions, never a list of gestures.
class UiSummary {
  UiSummary({required this.nowMs, required this.wallMs, required this.nextId});
  final int Function() nowMs, wallMs;
  final String Function() nextId;
  final Map<String, Object> _values = {};
  int? _startedWall;
  int? _activeAt;
  int _foregroundMs = 0;
  bool foreground = true;
  static const intervalMs = 300000;
  static const maxCounters = 180;
  static const aggregatedEvents = {
    'screen_view',
    'window_opened',
    'window_closed',
    'window_time',
    'page_selected',
    'feature_shown',
    'feature_clicked',
    'setting_changed',
    'ability_configured',
    'reward_available',
    'tap_lives',
    'tap_crystals',
    'tap_record',
    'open_daily',
    'open_shop',
    'open_rent',
    'open_earn',
    'tap_plus',
    'plus_activate',
    'plus_cancel',
    'share_open',
    'share_social',
  };
  static final _token = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');
  String _id(Object? value) =>
      value is String && _token.hasMatch(value) ? value : 'other';
  bool get hasData => _values.isNotEmpty;
  int get foregroundMs =>
      _foregroundMs + (_activeAt == null ? 0 : nowMs() - _activeAt!);
  bool get due => hasData && foregroundMs >= intervalMs;

  void _touch() {
    _startedWall ??= wallMs();
    if (foreground) _activeAt ??= nowMs();
  }

  // An open window continues into the next packet even without new gestures.
  void continueInterval() => _touch();

  void _set(String key, Object value) {
    _touch();
    if (!_values.containsKey(key) && _values.length >= maxCounters) {
      _values['counters_truncated'] = true;
      return;
    }
    _values[key] = value;
  }

  void _add(String key, [int count = 1]) {
    if (count < 0) return;
    _set(key, (_values[key] as int? ?? 0) + count);
  }

  void setForeground(bool value) {
    if (foreground == value) return;
    if (_activeAt != null) {
      _foregroundMs += nowMs() - _activeAt!;
      _activeAt = null;
    }
    foreground = value;
    if (foreground && hasData) _activeAt = nowMs();
  }

  bool record(String event, Map<String, Object> p) {
    if (!aggregatedEvents.contains(event)) return false;
    switch (event) {
      case 'screen_view':
        final screen = _id(p['screen']);
        // Gameplay visits are already counted by game_start/game_finish.
        if (screen != 'playing') _add('screen_${screen}_view_count');
      case 'window_opened':
        final window = _id(p['window']);
        _add('window_${window}_open_count');
        _set('${window}_opened', true);
      case 'window_closed':
        _add('window_${_id(p['window'])}_close_count');
      case 'window_time':
        _add('window_${_id(p['window'])}_active_ms', p['active_ms'] as int);
      case 'feature_shown':
        _add(
          'feature_${_id(p['placement'])}_${_id(p['feature'])}_shown_${p['enabled'] == true ? 'enabled' : 'disabled'}_count',
        );
      case 'feature_clicked':
        _add('feature_${_id(p['placement'])}_${_id(p['feature'])}_click_count');
      case 'page_selected':
        _add('page_${_id(p['container'])}_${_id(p['page'])}_select_count');
      case 'setting_changed':
        final setting = _id(p['setting']);
        _add('setting_${setting}_change_count');
        if (p['value'] is bool) {
          _set('setting_${setting}_last_value', p['value']!);
        }
      case 'ability_configured':
        final ability = _id(p['ability']);
        _add('ability_${ability}_configure_count');
        if (p['value'] is bool) {
          _set('ability_${ability}_last_selected', p['value']!);
        }
      case 'reward_available':
        _add(
          'reward_${_id(p['placement'])}_${_id(p['reward_type'])}_available_count',
        );
      default:
        _add('legacy_${event}_count');
    }
    return true;
  }

  void clear() {
    _values.clear();
    _startedWall = _activeAt = null;
    _foregroundMs = 0;
  }

  Map<String, Object>? take(String reason) {
    if (!hasData) return null;
    final result = <String, Object>{
      'summary_id': nextId(),
      'interval_started_at_ms': _startedWall!,
      'interval_ended_at_ms': wallMs(),
      'foreground_ms': foregroundMs,
      'flush_reason': reason,
      ..._values,
    };
    _values.clear();
    _startedWall = _activeAt = null;
    _foregroundMs = 0;
    return result;
  }
}
