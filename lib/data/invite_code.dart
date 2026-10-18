/// Public invitation input only. Never accepts an account credential or arbitrary URL.
class InviteCode {
  static const firebaseHost = 'untouch-android-game-box-b30d4.web.app';
  static final _code = RegExp(
    r'^(?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}|[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12})$',
  );
  static final _path = RegExp(
    r'^/a/((?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghjklmnpqrstuvwxyz]{6}|[ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghjklmnpqrstuvwxyz]{12}))/?$',
  );

  static String? normalize(Object? value) {
    if (value is! String || value.length > 64) return null;
    final trimmed = value.trim();
    if (!RegExp(r'^(?:[A-Za-z2-9]{6}|[A-Za-z2-9]{12})$').hasMatch(trimmed)) {
      return null;
    }
    final result = trimmed.toUpperCase();
    return _code.hasMatch(result) ? result : null;
  }

  static String url(String code) => 'https://untouch.fun/a/$code';
  static String firebaseUrl(String code) => 'https://$firebaseHost/a/$code';

  static String? fromAppLink(Object? value) {
    if (value is! String ||
        value.length > 2048 ||
        value.contains('%') ||
        !(value.startsWith('https://untouch.fun/') ||
            value.startsWith('https://$firebaseHost/'))) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !{'untouch.fun', firebaseHost}.contains(uri.host) ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final match = _path.firstMatch(uri.path);
    return match == null ? null : normalize(match.group(1));
  }

  static String? fromReferrer(Object? value) {
    if (value is! String || value.length > 4096 || value.contains('#')) {
      return null;
    }
    try {
      String? found;
      var count = 0;
      for (final part in value.split('&')) {
        final separator = part.indexOf('=');
        final key = Uri.decodeQueryComponent(
          separator < 0 ? part : part.substring(0, separator),
        );
        if (key != 'invite') continue;
        count++;
        found = normalize(
          separator < 0
              ? ''
              : Uri.decodeQueryComponent(part.substring(separator + 1)),
        );
      }
      return count == 1 ? found : null;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}
