import 'dart:convert';
import 'dart:js_interop';
import 'session.dart';

@JS('globalThis.untouchReplay')
external set verifier(JSFunction function);
void main() {
  verifier = ((JSString input) {
    try {
      return jsonEncode({'ok': true, ...replay(jsonDecode(input.toDart))}).toJS;
    } catch (_) {
      return '{"ok":false}'.toJS;
    }
  }).toJS;
}
