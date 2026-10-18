import 'dart:ui' show ViewFocusEvent, ViewFocusState;
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';

/// A lost native callback must neither lock the caller forever nor authorize a
/// reward/closing somebody else's window. After the deadline release the caller,
/// but retain the native lease until dismissal or a confirmed return to Flutter.
class AdPresentationLease<T> with WidgetsBindingObserver {
  AdPresentationLease({
    required this.fallback,
    Duration deadline = const Duration(minutes: 3),
    this.returnGrace = const Duration(seconds: 2),
  }) {
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_flutterPointer);
    _deadline = Timer(deadline, () {
      _fallback();
    });
  }
  final T fallback;
  final Duration returnGrace;
  final _result = Completer<T>(), _released = Completer<void>();
  late Timer _deadline;
  Timer? _return;
  AppLifecycleState? _lifecycle;
  bool _left = false, _lostFocus = false, _focused = true;
  bool _recoveryArmed = false;
  void _fallback() {
    _recoveryArmed = true;
    if (!_result.isCompleted) _result.complete(fallback);
  }

  void _flutterPointer(PointerEvent event) {
    // Lifecycle/focus can return while a native overlay is still visible.
    // Only an actual pointer delivered to Flutter confirms interactive game UI.
    if (event is PointerDownEvent &&
        _recoveryArmed &&
        _focused &&
        _lifecycle == AppLifecycleState.resumed) {
      finish(fallback);
    }
  }

  Future<T> get result => _result.future;
  Future<void> get released => _released.future;
  bool get safeToDispose => _released.isCompleted;
  void finish(T outcome) {
    if (safeToDispose) return;
    _deadline.cancel();
    _return?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_flutterPointer);
    if (!_result.isCompleted) _result.complete(outcome);
    _released.complete();
  }

  void _returned() {
    if (safeToDispose || !_focused || _lifecycle != AppLifecycleState.resumed) {
      return;
    }
    _return?.cancel();
    _return = Timer(returnGrace, _fallback);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state != AppLifecycleState.resumed) {
      _left = true;
      _return?.cancel();
    } else if (_left) {
      _returned();
    }
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    _focused = event.state == ViewFocusState.focused;
    if (!_focused) {
      _lostFocus = true;
      _return?.cancel();
    } else if (_lostFocus) {
      _returned();
    }
  }
}
