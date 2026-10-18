import 'dart:async';
import 'package:flutter/widgets.dart';
import 'mobile_account.dart';

/// Reconnect after a pause or a failed startup without racing Google sign-in.
class MobileConnection with WidgetsBindingObserver {
  MobileConnection({
    required this.account,
    required this.synchronize,
    this.retryDelay = const Duration(seconds: 5),
  });

  final MobileAccount account;
  final Future<void> Function() synchronize;
  final Duration retryDelay;
  Timer? _retry;
  Future<void>? _inFlight;
  bool _foreground = true;
  bool _needsSync = false;
  bool _wasBusy = false;
  bool _started = false;
  bool _disposed = false;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _wasBusy = account.busy || account.googleStage != null;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    account.addListener(_accountChanged);
    unawaited(reconnect());
  }

  void _accountChanged() {
    final finished = _wasBusy && !account.busy && account.googleStage == null;
    _wasBusy = account.busy || account.googleStage != null;
    if (finished && _needsSync) unawaited(reconnect());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(reconnect());
    } else {
      _retry?.cancel();
      _retry = null;
    }
  }

  Future<void> reconnect() {
    _needsSync = true;
    if (_disposed || !_foreground) return Future.value();
    if (_inFlight != null) return _inFlight!;
    // Returning from the native Google window resumes Flutter before the
    // Google request finishes. Wait for its final profile rather than racing it.
    if (account.busy || account.googleStage != null) return Future.value();
    _needsSync = false;
    _retry?.cancel();
    _retry = null;
    final task = _run();
    _inFlight = task;
    return task.whenComplete(() {
      _inFlight = null;
      if (_needsSync && !_disposed && _foreground) {
        unawaited(reconnect());
      }
    });
  }

  Future<void> _run() async {
    try {
      await synchronize();
      debugPrint('Mobile connection: synchronized');
    } catch (_) {
      debugPrint('Mobile connection: retry pending');
      if (!_disposed && _foreground) {
        _retry = Timer(retryDelay, () {
          _retry = null;
          unawaited(reconnect());
        });
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retry?.cancel();
    if (_started) {
      account.removeListener(_accountChanged);
      WidgetsBinding.instance.removeObserver(this);
    }
  }
}
