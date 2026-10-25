import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Small durable handoff until the native SDK accepts a UI summary.
/// Native SDK handles subsequent network retries. Process death at the exact
/// SDK/storage boundary may replay a summary_id; exports can deduplicate it.
class UiSummaryOutbox {
  UiSummaryOutbox(this.prefs, this.send);
  final SharedPreferences prefs;
  final Future<void> Function(Map<String, Object>) send;
  static const storageKey = 'analytics_ui_outbox_v2';
  static const maxPending = 16;
  final List<Map<String, Object>> _pending = [];
  Future<void> _tail = Future.value();
  bool _discarded = false;

  Future<void> discard() {
    _discarded = true;
    _pending.clear();
    return _tail.then((_) async {
      await prefs.remove(storageKey);
    });
  }

  void restore() {
    for (final value in prefs.getStringList(storageKey) ?? <String>[]) {
      try {
        _pending.add(Map<String, Object>.from(jsonDecode(value) as Map));
      } catch (_) {
        /* Ignore a corrupt local packet, never block app startup. */
      }
    }
    if (_pending.length > maxPending) {
      _pending.removeRange(0, _pending.length - maxPending);
    }
  }

  Future<void> _save() =>
      prefs.setStringList(storageKey, _pending.map(jsonEncode).toList());
  Future<void> push(Map<String, Object> packet) => _schedule(packet);
  Future<void> retry() => _schedule(null);
  Future<void> _schedule(Map<String, Object>? packet) {
    final job = _tail.then((_) async {
      if (_discarded) return;
      if (packet != null) {
        _pending.add(Map.of(packet));
        if (_pending.length > maxPending) {
          if (_discarded) return;
          _pending.removeAt(0);
          _pending.last['ui_outbox_overflow'] = true;
        }
        await _save();
      }
      while (_pending.isNotEmpty) {
        try {
          await send(_pending.first);
        } catch (_) {
          return;
        }
        if (_discarded) return;
        _pending.removeAt(0);
        await _save();
      }
    });
    _tail = job.catchError((Object _) {});
    return _tail;
  }
}
