import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../ui/game_viewport.dart';
import 'game_world.dart';

/// Preflight for the arcade only. World coordinates stay at 380 on every screen.
/// Compare proportions, not the phone's resolution or absolute widget pixels.
abstract final class GameStartGuard {
  static const tolerance = .03;
  static bool _positive(double v) => v.isFinite && v > 0;
  static bool _near(double actual, double expected) =>
      _positive(actual) &&
      _positive(expected) &&
      (actual / expected - 1).abs() <= tolerance + 1e-9;
  static bool _size(Size s) => _positive(s.width) && _positive(s.height);
  static bool _offset(Offset p) => p.dx.isFinite && p.dy.isFinite;

  /// A short diagnostic code, or null when the rendered field can start.
  static String? check({
    required GameWorld world,
    required Size paintedSize,
    required Rect displayedField,
    required Rect visibleScreen,
    required double devicePixelRatio,
  }) {
    try {
      if (!_size(paintedSize) ||
          !_size(displayedField.size) ||
          !_size(visibleScreen.size) ||
          !_positive(devicePixelRatio)) {
        return 'field_not_ready';
      }
      if (!_offset(displayedField.topLeft) || !_offset(visibleScreen.topLeft)) {
        return 'field_position';
      }
      if (!_near(world.field.width, GameViewport.referenceFieldSide) ||
          !_near(world.field.height, GameViewport.referenceFieldSide)) {
        return 'world_scale';
      }
      if (!_near(paintedSize.width, paintedSize.height) ||
          !_near(displayedField.width, displayedField.height)) {
        return 'field_distorted';
      }
      final visible = displayedField.intersect(visibleScreen);
      if (visible.isEmpty ||
          visible.width *
                  visible.height /
                  (displayedField.width * displayedField.height) <
              1 - tolerance) {
        return 'field_clipped';
      }
      final heroRatio = world.playerSize / world.field.width;
      final expectedHeroRatio =
          world.config.playerSize *
          GameWorld.characterSizeScale /
          GameViewport.referenceFieldSide;
      if (!_near(heroRatio, expectedHeroRatio) ||
          heroRatio < .03 ||
          heroRatio > .25) {
        return 'hero_scale';
      }
      final scaleX = displayedField.width / world.field.width;
      final scaleY = displayedField.height / world.field.height;
      bool visibleBody(Rect body) {
        if (!_offset(body.topLeft) || !_size(body.size)) {
          return false;
        }
        final intersection = body.intersect(Offset.zero & world.field);
        return !intersection.isEmpty &&
            intersection.width *
                    intersection.height /
                    (body.width * body.height) >=
                1 - tolerance;
      }

      bool readable(double w, double h) =>
          math.min(w * scaleX, h * scaleY) * devicePixelRatio >= 8;
      if (!visibleBody(
            Rect.fromLTWH(
              world.player.dx,
              world.player.dy,
              world.playerSize,
              world.playerSize,
            ),
          ) ||
          !readable(world.playerSize, world.playerSize)) {
        return 'hero_invisible';
      }
      final aspects = world.config.enemyAspects
          .where((a) => a.isFinite && a > .05 && a < 50)
          .toList();
      if (aspects.isEmpty) aspects.addAll([1, .25, .5, 3]);
      if (world.enemies.length != 4 || aspects.length != 4) {
        return 'enemy_count';
      }
      final area =
          world.playerSize *
          world.playerSize *
          world.config.enemyAreaMultiplier.clamp(.2, 20);
      for (var i = 0; i < 4; i++) {
        final enemy = world.enemies[i];
        final w = math.sqrt(area * aspects[i]);
        final h = math.sqrt(area / aspects[i]);
        if (!_near(enemy.w, w) || !_near(enemy.h, h)) {
          return 'enemy_scale';
        }
        if (!_offset(enemy.pos) ||
            !_offset(enemy.homePos) ||
            !enemy.orientDeg.isFinite ||
            !visibleBody(enemy.rect) ||
            !visibleBody(
              Rect.fromLTWH(
                enemy.homePos.dx,
                enemy.homePos.dy,
                enemy.w,
                enemy.h,
              ),
            ) ||
            !readable(enemy.w, enemy.h)) {
          return 'enemy_invisible';
        }
        if (!_offset(enemy.vel) ||
            !_offset(enemy.homeVel) ||
            !enemy.initialSpeed.isFinite ||
            enemy.initialSpeed < 0 ||
            !enemy.acceleration.isFinite ||
            enemy.acceleration < 0) {
          return 'enemy_motion';
        }
      }
      return null;
    } catch (_) {
      // Incomplete world initialization must fail closed, never crash or score.
      return 'world_not_ready';
    }
  }
}
