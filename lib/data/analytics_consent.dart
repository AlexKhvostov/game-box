import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audience_policy.dart';

/// Device-only permission. Age, advertising and Google authentication never
/// grant analytics. No data from this model is itself reported as telemetry.
class AnalyticsConsent extends ChangeNotifier {
  AnalyticsConsent(this.audience, {required this.applyRuntime}) {
    audience.addListener(_ageChanged);
  }
  final AudiencePolicy audience;
  final Future<void> Function(bool) applyRuntime;
  static const permissionKey = 'analytics_consent_granted_v1';
  static const promptKey = 'analytics_consent_prompt_seen_v1';
  SharedPreferences? _prefs;
  bool _granted = false, _seen = false, _busy = false, _disposed = false;
  int _revision = 0;
  bool get eligible => switch (audience.band) {
    AgeBand.age18to20 || AgeBand.age21plus || AgeBand.adult18plus => true,
    _ => false,
  };
  bool get enabled => _prefs != null && eligible && _granted;
  bool get promptSeen => _seen;
  bool get needsPrompt => _prefs != null && eligible && !_seen;
  bool get busy => _busy;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _seen = prefs.getBool(promptKey) ?? false;
    _granted = eligible && (prefs.getBool(permissionKey) ?? false);
    if (!eligible) await prefs.setBool(permissionKey, false);
    await applyRuntime(enabled);
    if (!_disposed) notifyListeners();
  }

  Future<void> markPromptSeen() async {
    final prefs = _prefs;
    if (prefs == null) throw StateError('Load analytics consent first');
    if (!await prefs.setBool(promptKey, true)) {
      throw StateError('Could not save analytics prompt');
    }
    _seen = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_busy) return;
    final prefs = _prefs;
    if (prefs == null) throw StateError('Load analytics consent first');
    if (value && !eligible) throw StateError('Analytics requires age 18+');
    final revision = ++_revision;
    _busy = true;
    if (!value) {
      _granted = false;
      // Stop the runtime synchronously, before awaiting any storage operation.
      unawaited(applyRuntime(false));
    }
    notifyListeners();
    try {
      if (!await prefs.setBool(permissionKey, value)) {
        throw StateError('Could not save analytics permission');
      }
      if (!await prefs.setBool(promptKey, true)) {
        await prefs.setBool(permissionKey, false);
        throw StateError('Could not save analytics prompt');
      }
      if (revision != _revision || (value && !eligible)) {
        await prefs.setBool(permissionKey, false);
        return;
      }
      _seen = true;
      _granted = value;
      if (value) unawaited(applyRuntime(enabled));
    } catch (_) {
      _granted = false;
      await applyRuntime(false);
      rethrow;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _ageChanged() {
    if (_disposed) return;
    if (!eligible) {
      _revision++;
      _granted = false;
      unawaited(applyRuntime(false));
      final prefs = _prefs;
      if (prefs != null) unawaited(prefs.setBool(permissionKey, false));
    }
    // Becoming adult does not restore a previous permission automatically.
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    audience.removeListener(_ageChanged);
    super.dispose();
  }
}
