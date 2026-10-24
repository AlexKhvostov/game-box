import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/data/android_updates.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'package:game_box/ui/android_update_host.dart';
import 'android_updates_test.dart' show FakePlayUpdates, downloaded;
import 'uniform_pace_helmet_test.dart' as game;

void main() {
  testWidgets(
    'Real game never prompts during start/play/result; offers after closing result',
    (t) async {
      t.view.physicalSize = const Size(412, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final economy = EconomyStore();
      await economy.load();
      final scores = ScoresStore();
      await scores.loadLocal();
      final source = FakePlayUpdates()
        ..current = const PlayUpdateInfo(supported: false);
      final updates = AndroidUpdates(
        source: source,
        preferences: await SharedPreferences.getInstance(),
        prepareForRestart: () async {
          await scores.prepareForAppRestart();
          await economy.prepareForAppRestart();
        },
      );
      await updates.start();
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: economy),
            ChangeNotifierProvider.value(value: scores),
            ChangeNotifierProvider.value(value: updates),
            Provider.value(
              value: const GameplayConfig(
                game: GameConfig(idleEnemiesMove: false, startInvulnSec: 0),
              ),
            ),
          ],
          child: const GameBoxApp(forceLocale: 'en'),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 16));
      await game.start(t);
      expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).isPlaying, true);
      source.send(downloaded);
      await t.pump(const Duration(milliseconds: 16));
      expect(find.byType(AndroidUpdateDialog), findsNothing);
      expect(find.byType(AndroidUpdateBanner), findsNothing);
      final world = game.worldOf(t);
      world.player = const Offset(-1000, -1000);
      for (
        var i = 0;
        i < 60 && find.byType(ResultOverlay).evaluate().isEmpty;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(find.byType(ResultOverlay), findsOneWidget);
      expect(find.byType(AndroidUpdateDialog), findsNothing);
      await scores.prepareForAppRestart();
      expect(scores.latestAttempt, isNotNull);
      t.widget<ResultOverlay>(find.byType(ResultOverlay)).onOk();
      await t.pump();
      await t.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const ValueKey('update-dialog-ready')), findsOneWidget);
      expect(source.completions, 0);
      await t.tap(find.byKey(const ValueKey('update-later')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 350));
      expect(find.byType(AndroidUpdateBanner), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      updates.dispose();
      scores.dispose();
      economy.dispose();
      await source.stream.close();
    },
  );
}
