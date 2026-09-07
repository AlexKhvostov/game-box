import 'package:flutter/material.dart';

import 'telegram_bridge_stub.dart'
    if (dart.library.js_interop) 'telegram_bridge_web.dart' as impl;

/// Мост к Telegram Mini Apps SDK.
abstract final class TelegramBridge {
  static bool get isInsideTelegram => impl.isInsideTelegram;

  static int? get userId => impl.userId;

  static String? get username => impl.username;

  static String? get firstName => impl.firstName;

  /// Имя для рейтинга: @username → first_name → null.
  static String? get displayName {
    final u = username?.trim();
    if (u != null && u.isNotEmpty) return u.startsWith('@') ? u : '@$u';
    final f = firstName?.trim();
    if (f != null && f.isNotEmpty) return f;
    return null;
  }

  /// Отступы под статус-бар / шапку Telegram (обновляются при смене viewport).
  static ValueNotifier<EdgeInsets> get viewPadding => impl.viewPadding;

  /// ready + expand + fullscreen + подписка на safe area.
  static void bootstrapFullscreen() => impl.bootstrapFullscreen();
}
