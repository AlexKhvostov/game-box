import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/gameplay_debug.dart';
import 'package:game_box/app/mobile_gameplay_tuning.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_debug_panel.dart';
import 'package:game_box/ui/billing_unavailable.dart';
import 'uniform_pace_helmet_test.dart' as fixture;

void main() {
  testWidgets(
    'holding timer toggles diagnostics without opening ranking or starting',
    (tester) async {
      await fixture.mount(
        tester,
        MobileGameplayTuning.apply(const GameplayConfig()),
      );
      final field = find.byKey(const ValueKey('arcade-game-field'));
      final bounds = tester.getRect(field);
      final timer = find.byKey(const ValueKey('hud-debug-toggle'));
      expect(find.byType(GameDebugPanel), findsNothing);
      await tester.longPress(timer);
      await tester.pump();
      expect(
        find.byType(GameDebugPanel),
        GameplayDebug.enabled ? findsOneWidget : findsNothing,
      );
      expect(tester.getRect(field), bounds);
      expect(find.textContaining('00:00.000'), findsOneWidget);
      if (GameplayDebug.enabled) {
        final panel = tester.getRect(find.byType(GameDebugPanel));
        expect(panel.top, greaterThanOrEqualTo(bounds.bottom));
        expect(panel.bottom, tester.view.physicalSize.height - 8);
        expect(find.textContaining('Current speed:'), findsOneWidget);
        expect(find.textContaining('Each enemy: start'), findsOneWidget);
        final panelText = tester
            .widget<Text>(
              find.descendant(
                of: find.byType(GameDebugPanel),
                matching: find.byType(Text),
              ),
            )
            .data!;
        for (var enemy = 1; enemy <= 4; enemy++) {
          expect(
            panelText,
            matches(
              'Enemy $enemy: start [0-9]+\\.[0-9]{2}, acceleration \\+[0-9]+\\.[0-9]{2}',
            ),
          );
        }
        await tester.longPress(timer);
        await tester.pump();
        expect(find.byType(GameDebugPanel), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'diagnostic speed is read from current vectors, not predicted time',
    (tester) async {
      await fixture.mount(tester, const GameplayConfig());
      final world = fixture.worldOf(tester);
      for (var i = 0; i < world.enemies.length; i++) {
        world.enemies[i].vel = Offset((i + 1) * 20, 0);
      }
      final stats = GameDebugStats(world);
      expect(stats.currentSpeed, 50);
      expect(stats.minSpeed, 20);
      expect(stats.maxSpeed, 80);
      expect(stats.initialSpeed, isNot(stats.currentSpeed));
      expect(stats.acceleration, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
