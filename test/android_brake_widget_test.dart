import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/domain/enemy_pace.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/game/enemy_speed_meter.dart';
import 'uniform_pace_helmet_test.dart' as fixture;

GameFieldPainter field(WidgetTester t) =>
    t
            .widget<CustomPaint>(
              find.byKey(const ValueKey('arcade-game-field')),
            )
            .painter!
        as GameFieldPainter;
void main() {
  for (final brakeEnabled in [true, false]) {
    for (final speedBarEnabled in [true, false]) {
      testWidgets(
        'native screen: brake=$brakeEnabled, speed meter=$speedBarEnabled, automatic pressure plate',
        (t) async {
          await fixture.mount(
            t,
            GameplayConfig(
              game: const GameConfig(startInvulnSec: 60),
              enemyPace: EnemyPaceSettings(
                brakeEnabled: brakeEnabled,
                speedBarEnabled: speedBarEnabled,
              ),
            ),
          );
          final f = find.byKey(const ValueKey('arcade-game-field'));
          expect(t.getSize(f), const Size(380, 380));
          expect(
            find.byType(EnemySpeedMeter),
            speedBarEnabled ? findsOneWidget : findsNothing,
          );
          if (speedBarEnabled) {
            expect(
              t
                  .getBottomRight(
                    find.byKey(const ValueKey('enemy-speed-meter')),
                  )
                  .dy,
              lessThanOrEqualTo(t.getTopLeft(f).dy),
            );
          }
          await fixture.start(t);
          for (var i = 0; i < 121; i++) {
            await t.pump(const Duration(milliseconds: 50));
          }
          final p = field(t).enemyPace!;
          expect(p.brakeEnabled, brakeEnabled);
          expect(p.speedBarEnabled, speedBarEnabled);
          expect(p.presses, brakeEnabled ? 1 : 0);
          if (!brakeEnabled) {
            expect(p.effective, greaterThan(6));
          } else {
            expect(p.effective, lessThan(.2));
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets(
    'jumping over a ready native pedal delays braking until landing',
    (t) async {
      await fixture.mount(
        t,
        const GameplayConfig(
          game: GameConfig(startInvulnSec: 60),
          enemyPace: EnemyPaceSettings(),
        ),
        rentals: true,
      );
      await fixture.start(t);
      final p = field(t).enemyPace!;
      for (var i = 0; i < 116; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      final w = field(t).world;
      expect(w.tryJump(nowMs: p.elapsed * 1000), true);
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      if (w.isJumping) expect(p.presses, 0);
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(p.presses, 1);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
