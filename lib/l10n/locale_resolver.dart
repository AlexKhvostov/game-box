import 'package:flutter/material.dart';

/// Выбор языка: устройство → fallback EN; Remote Config может форсировать.
abstract final class LocaleResolver {
  static const supported = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  static const fallback = Locale('en');

  /// `forceLocale` из RC: `en` | `ru` | пусто = язык устройства.
  static Locale? parseForce(String? raw) {
    final code = raw?.trim().toLowerCase();
    if (code == null || code.isEmpty || code == 'system' || code == 'auto') {
      return null;
    }
    for (final l in supported) {
      if (l.languageCode == code) return l;
    }
    return null;
  }

  static Locale resolve({
    required Locale? device,
    String? forceLocale,
  }) {
    final forced = parseForce(forceLocale);
    if (forced != null) return forced;
    if (device == null) return fallback;
    for (final l in supported) {
      if (l.languageCode == device.languageCode) return l;
    }
    return fallback;
  }
}
