import 'package:flutter/material.dart';

/// Якоря HUD для анимации «улетело в кристалы / жизни».
enum ToastFlyTarget { none, crystals, lives }

class HudFlyTargets {
  HudFlyTargets._();

  static final GlobalKey livesKey = GlobalKey(debugLabel: 'hud_lives');
  static final GlobalKey crystalsKey = GlobalKey(debugLabel: 'hud_crystals');

  static Offset? centerOf(ToastFlyTarget target) {
    final key = switch (target) {
      ToastFlyTarget.lives => livesKey,
      ToastFlyTarget.crystals => crystalsKey,
      ToastFlyTarget.none => null,
    };
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  /// Fallback в угол экрана, если ключ ещё не смонтирован.
  static Offset fallbackOf(ToastFlyTarget target, Size screen) {
    final top = 28.0;
    return switch (target) {
      ToastFlyTarget.lives => Offset(36, top + 24),
      ToastFlyTarget.crystals => Offset(96, top + 24),
      ToastFlyTarget.none => Offset(screen.width / 2, screen.height * 0.22),
    };
  }
}
