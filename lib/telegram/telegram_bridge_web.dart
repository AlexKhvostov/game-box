import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:flutter/material.dart';

@JS('Telegram.WebApp')
external JSObject? get _webApp;

bool get isInsideTelegram => _webApp != null;

final ValueNotifier<EdgeInsets> viewPadding =
    ValueNotifier<EdgeInsets>(EdgeInsets.zero);

bool _listening = false;

int? get userId {
  final user = _user();
  if (user == null) return null;
  final id = user.getProperty('id'.toJS);
  if (id == null || !id.isA<JSNumber>()) return null;
  return (id as JSNumber).toDartInt;
}

String? get username {
  final user = _user();
  if (user == null) return null;
  final v = user.getProperty('username'.toJS);
  if (v == null || !v.isA<JSString>()) return null;
  final s = (v as JSString).toDart;
  return s.isEmpty ? null : s;
}

String? get firstName {
  final user = _user();
  if (user == null) return null;
  final v = user.getProperty('first_name'.toJS);
  if (v == null || !v.isA<JSString>()) return null;
  final s = (v as JSString).toDart;
  return s.isEmpty ? null : s;
}

JSObject? _user() {
  final wa = _webApp;
  if (wa == null) return null;
  final init = wa.getProperty('initDataUnsafe'.toJS);
  if (init == null || !init.isA<JSObject>()) return null;
  final user = (init as JSObject).getProperty('user'.toJS);
  if (user == null || !user.isA<JSObject>()) return null;
  return user as JSObject;
}

void bootstrapFullscreen() {
  final wa = _webApp;
  if (wa == null) {
    debugPrint('Telegram WebApp: not inside Telegram');
    return;
  }
  try {
    _call(wa, 'ready');
    _call(wa, 'expand');
    _call(wa, 'disableVerticalSwipes');
    _call(wa, 'requestFullscreen');
    _call(wa, 'lockOrientation');
    _call1(wa, 'setHeaderColor', '#0E1419');
    _call1(wa, 'setBackgroundColor', '#0E1419');
    _call(wa, 'requestSafeArea');
    try {
      _call(wa, 'requestContentSafeArea');
    } catch (_) {}

    _refreshInsets();
    if (!_listening) {
      _listening = true;
      _onEvent(wa, 'safeAreaChanged', _refreshInsets);
      _onEvent(wa, 'contentSafeAreaChanged', _refreshInsets);
      _onEvent(wa, 'fullscreenChanged', _refreshInsets);
      _onEvent(wa, 'viewportChanged', _refreshInsets);
    }
    debugPrint(
      'Telegram WebApp: fullscreen ok, padding=${viewPadding.value}',
    );
  } catch (e, st) {
    debugPrint('Telegram WebApp bootstrap error: $e\n$st');
  }
}

void _refreshInsets() {
  final wa = _webApp;
  if (wa == null) return;

  final safe = _insetBox(wa.getProperty('safeAreaInset'.toJS));
  final content = _insetBox(wa.getProperty('contentSafeAreaInset'.toJS));

  var top = safe.top + content.top;
  var bottom = safe.bottom + content.bottom;
  var left = math.max(safe.left, content.left);
  var right = math.max(safe.right, content.right);

  final fullscreen = _boolProp(wa, 'isFullscreen') ?? false;
  if (top < 1) {
    top = fullscreen ? 54 : 28;
  }
  if (bottom < 0) bottom = 0;

  final next = EdgeInsets.fromLTRB(left, top, right, bottom);
  if (next != viewPadding.value) {
    viewPadding.value = next;
    debugPrint('Telegram insets: $next (fullscreen=$fullscreen)');
  }
}

({double top, double bottom, double left, double right}) _insetBox(
  JSAny? raw,
) {
  if (raw == null || !raw.isA<JSObject>()) {
    return (top: 0, bottom: 0, left: 0, right: 0);
  }
  final o = raw as JSObject;
  return (
    top: _numProp(o, 'top'),
    bottom: _numProp(o, 'bottom'),
    left: _numProp(o, 'left'),
    right: _numProp(o, 'right'),
  );
}

double _numProp(JSObject o, String key) {
  final v = o.getProperty(key.toJS);
  if (v == null || !v.isA<JSNumber>()) return 0;
  return (v as JSNumber).toDartDouble;
}

bool? _boolProp(JSObject o, String key) {
  final v = o.getProperty(key.toJS);
  if (v == null || !v.isA<JSBoolean>()) return null;
  return (v as JSBoolean).toDart;
}

void _call(JSObject wa, String method) {
  final fn = wa.getProperty(method.toJS);
  if (fn == null || !fn.isA<JSFunction>()) return;
  (fn as JSFunction).callAsFunction(wa);
}

void _call1(JSObject wa, String method, String arg) {
  final fn = wa.getProperty(method.toJS);
  if (fn == null || !fn.isA<JSFunction>()) return;
  (fn as JSFunction).callAsFunction(wa, arg.toJS);
}

void _onEvent(JSObject wa, String event, void Function() handler) {
  final fn = wa.getProperty('onEvent'.toJS);
  if (fn == null || !fn.isA<JSFunction>()) return;
  (fn as JSFunction).callAsFunction(wa, event.toJS, handler.toJS);
}
