import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UpdatePhase {
  unavailable,
  available,
  downloading,
  ready,
  installing,
  failed,
}

enum UpdatePrompt { available, ready, failed }

class PlayUpdateInfo {
  const PlayUpdateInfo({
    this.supported = true,
    this.installedVersion = 0,
    this.availableVersion = 0,
    this.available = false,
    this.flexibleAllowed = false,
    this.installStatus = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorCode = 0,
    this.accepted = false,
    this.canceled = false,
    this.failed = false,
  });
  factory PlayUpdateInfo.fromMap(Map<dynamic, dynamic> map) => PlayUpdateInfo(
    supported: map['supported'] == true,
    installedVersion: (map['installedVersion'] as num?)?.toInt() ?? 0,
    availableVersion: (map['availableVersion'] as num?)?.toInt() ?? 0,
    available: map['available'] == true,
    flexibleAllowed: map['flexibleAllowed'] == true,
    installStatus: (map['installStatus'] as num?)?.toInt() ?? 0,
    downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
    totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
    errorCode: (map['errorCode'] as num?)?.toInt() ?? 0,
    accepted: map['accepted'] == true,
    canceled: map['canceled'] == true,
    failed: map['failed'] == true,
  );
  final bool supported, available, flexibleAllowed, accepted, canceled, failed;
  final int installedVersion, availableVersion, installStatus;
  final int downloadedBytes, totalBytes, errorCode;
}

abstract interface class PlayUpdateSource {
  Stream<PlayUpdateInfo> get events;
  Future<PlayUpdateInfo> check();
  Future<PlayUpdateInfo> startFlexible();
  Future<void> complete();
}

class NativePlayUpdateSource implements PlayUpdateSource {
  const NativePlayUpdateSource();
  static const methods = MethodChannel('untouch/updates');
  static const updates = EventChannel('untouch/updates/events');
  @override
  Stream<PlayUpdateInfo> get events => updates.receiveBroadcastStream().map(
    (event) => PlayUpdateInfo.fromMap(event as Map),
  );
  Future<PlayUpdateInfo> _invoke(String method) async => PlayUpdateInfo.fromMap(
    await methods.invokeMapMethod<dynamic, dynamic>(method) ?? {},
  );
  @override
  Future<PlayUpdateInfo> check() =>
      _invoke('check').timeout(const Duration(seconds: 12));
  @override
  Future<PlayUpdateInfo> startFlexible() => _invoke('startFlexible');
  @override
  Future<void> complete() => methods.invokeMethod<void>('complete');
}

/// Owns only Play state and device-local deferrals. No account/economy requests.
class AndroidUpdates extends ChangeNotifier {
  AndroidUpdates({
    required this.source,
    required this.preferences,
    required this.prepareForRestart,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final PlayUpdateSource source;
  final SharedPreferences preferences;
  final Future<void> Function() prepareForRestart;
  final DateTime Function() _now;
  static const _prefix = 'play_flexible_update_v1_';
  StreamSubscription<PlayUpdateInfo>? _subscription;
  PlayUpdateInfo info = const PlayUpdateInfo(supported: false);
  UpdatePhase phase = UpdatePhase.unavailable;
  bool busy = false;
  bool _disposed = false, _started = false, _checking = false;
  bool _userRequested = false, _errorAcknowledged = false;
  bool successNotice = false;
  int _revision = 0;
  DateTime? _lastCheck;
  final Set<String> _shown = {};
  String? get _versionKey =>
      info.availableVersion > 0 ? '${info.availableVersion}' : null;
  double? get progress => info.totalBytes > 0
      ? (info.downloadedBytes / info.totalBytes).clamp(0.0, 1.0)
      : null;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _subscription = source.events.listen(
      _apply,
      onError: (Object _) {
        // A missing Play service/event channel must not block the game.
      },
    );
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    if (_disposed || _checking || busy) return;
    if (!force &&
        _lastCheck != null &&
        _now().difference(_lastCheck!) < const Duration(minutes: 10) &&
        phase != UpdatePhase.downloading &&
        phase != UpdatePhase.ready) {
      return;
    }
    _checking = true;
    _lastCheck = _now();
    final before = _revision;
    try {
      final result = await source.check();
      // Progress events received during the check are newer than its snapshot.
      if (!_disposed && before == _revision) _apply(result);
    } catch (_) {
      // An automatic availability check is always silent, preserving a known download.
    } finally {
      _checking = false;
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _apply(PlayUpdateInfo next) {
    if (_disposed) return;
    _revision++;
    info = next;
    final installingVersion = preferences.getInt(
      '${_prefix}installing_version',
    );
    if (next.supported &&
        installingVersion != null &&
        next.installedVersion >= installingVersion) {
      successNotice = true;
      unawaited(
        preferences
            .remove('${_prefix}installing_version')
            .catchError((Object _) => false),
      );
    }
    if (!next.supported) {
      phase = UpdatePhase.unavailable;
    } else if (next.failed || next.installStatus == 5) {
      phase = _userRequested ? UpdatePhase.failed : UpdatePhase.unavailable;
    } else if (next.installStatus == 11) {
      phase = UpdatePhase.ready;
      _userRequested = true;
    } else if (next.installStatus == 3) {
      phase = UpdatePhase.installing;
    } else if (next.installStatus == 4) {
      phase = UpdatePhase.unavailable;
    } else if (next.installStatus == 1 || next.installStatus == 2) {
      phase = UpdatePhase.downloading;
      _userRequested = true;
    } else if (next.available &&
        next.flexibleAllowed &&
        next.availableVersion > next.installedVersion) {
      phase = UpdatePhase.available;
    } else {
      phase = UpdatePhase.unavailable;
    }
    _emit();
  }

  UpdatePrompt? get prompt {
    if (busy || _disposed) return null;
    if (phase == UpdatePhase.failed && !_errorAcknowledged) {
      return UpdatePrompt.failed;
    }
    final version = _versionKey;
    if (version == null) return null;
    if (phase == UpdatePhase.ready &&
        preferences.getInt('${_prefix}ready_later') != info.availableVersion &&
        !_shown.contains('ready:$version')) {
      return UpdatePrompt.ready;
    }
    if (phase == UpdatePhase.available &&
        !_shown.contains('available:$version')) {
      final laterVersion = preferences.getInt('${_prefix}later_version');
      final laterUntil = preferences.getInt('${_prefix}later_until') ?? 0;
      if (laterVersion != info.availableVersion ||
          _now().millisecondsSinceEpoch >= laterUntil) {
        return UpdatePrompt.available;
      }
    }
    return null;
  }

  void markPromptShown(UpdatePrompt prompt) {
    if (prompt == UpdatePrompt.failed) {
      _errorAcknowledged = true;
    } else {
      _shown.add('${prompt.name}:${info.availableVersion}');
    }
  }

  Future<void> defer(UpdatePrompt prompt) async {
    markPromptShown(prompt);
    try {
      if (prompt == UpdatePrompt.ready) {
        await preferences.setInt(
          '${_prefix}ready_later',
          info.availableVersion,
        );
      } else if (prompt == UpdatePrompt.available) {
        await preferences.setInt(
          '${_prefix}later_version',
          info.availableVersion,
        );
        await preferences.setInt(
          '${_prefix}later_until',
          _now().add(const Duration(days: 1)).millisecondsSinceEpoch,
        );
      }
    } catch (_) {
      /* In-memory deferral still works when device storage fails. */
    }
    _emit();
  }

  Future<void> download() async {
    if (busy || _disposed) return;
    busy = true;
    _userRequested = true;
    _errorAcknowledged = false;
    _emit();
    final before = _revision;
    try {
      final result = await source.startFlexible();
      if (_disposed) return;
      if (result.canceled) {
        if (before == _revision) _apply(result);
        await defer(UpdatePrompt.available);
      } else if (before == _revision) {
        _apply(result);
        // Acceptance precedes the first download event. Keep input usable once consent closes.
        if (result.accepted && phase == UpdatePhase.available) {
          phase = UpdatePhase.downloading;
        }
      }
    } catch (_) {
      if (!_disposed) phase = UpdatePhase.failed;
    } finally {
      busy = false;
      _emit();
    }
    // Native consent return/resume may precede the status event.
    if (phase != UpdatePhase.failed) await refresh(force: true);
  }

  Future<void> install({required bool Function() isSafe}) async {
    if (busy || _disposed || phase != UpdatePhase.ready || !isSafe()) return;
    busy = true;
    _errorAcknowledged = false;
    _emit();
    try {
      // Do not restart while the latest result/wallet is still being committed locally.
      await prepareForRestart().timeout(const Duration(seconds: 15));
      if (_disposed || !isSafe()) return;
      final latest = await source.check();
      if (_disposed) return;
      _apply(latest);
      if (!isSafe() || phase != UpdatePhase.ready) return;
      if (info.availableVersion <= info.installedVersion) {
        throw StateError('invalid_update_version');
      }
      if (!await preferences.setInt(
        '${_prefix}installing_version',
        info.availableVersion,
      )) {
        throw StateError('update_storage_failed');
      }
      if (_disposed || !isSafe()) return;
      await source.complete();
      if (!_disposed) phase = UpdatePhase.installing;
    } catch (_) {
      if (!_disposed) {
        phase = UpdatePhase.failed;
        _userRequested = true;
      }
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> retry() async {
    if (busy || _disposed) return;
    await refresh(force: true);
    if (phase == UpdatePhase.ready) {
      try {
        await preferences.remove('${_prefix}ready_later');
      } catch (_) {
        /* Manual ready action remains available in the banner. */
      }
      _shown.remove('ready:${info.availableVersion}');
      _emit();
    } else {
      await download();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
