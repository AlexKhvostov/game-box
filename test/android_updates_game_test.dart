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
import 'android_updates_test.dart' show FakePlayUpdates, downloaded, offered;
import 'uniform_pace_helmet_test.dart' as game;

void main() {
  for (final mode in ['later', 'install', 'start-race', 'entry-offer']) {
    final defer = mode != 'install';
    testWidgets(
      '${mode == 'entry-offer' ? 'Offer appears at entry before start; ' : ''}100% hidden during ${mode == 'start-race' ? 'queued start/' : ''}play/impact; result ${defer ? 'Later stays quiet in replay' : 'can install after saving'}',
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
          ..current = mode == 'entry-offer'
              ? offered
              : const PlayUpdateInfo(supported: false);
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
        if (mode == 'entry-offer') {
          await t.pump(const Duration(milliseconds: 350));
          expect(
            find.byKey(const ValueKey('update-dialog-available')),
            findsOneWidget,
          );
          expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(), 0);
          expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).isPlaying, false);
          await t.tap(find.byKey(const ValueKey('update-close')));
          await t.pump();
          await t.pump(const Duration(milliseconds: 350));
          expect(find.byType(AndroidUpdateDialog), findsNothing);
          expect(source.starts, 0);
        }
        // Queue completion at idle0, then start before its scheduled prompt.
        // The starting/playing phase must win even while the clock is still0.
        if (mode == 'start-race') source.send(downloaded);
        await game.start(t);
        expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).isPlaying, true);
        expect(
          t.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(),
          greaterThan(0),
        );
        if (mode != 'start-race') {
          source.send(
            const PlayUpdateInfo(
              installedVersion: 196,
              availableVersion: 197,
              installStatus: 2,
              downloadedBytes: 100,
              totalBytes: 100,
            ),
          );
        }
        await t.pump(const Duration(milliseconds: 16));
        expect(find.byType(AndroidUpdateDialog), findsNothing);
        expect(find.byType(AndroidUpdateBanner), findsNothing);
        source.send(downloaded);
        await t.pump(const Duration(milliseconds: 16));
        expect(find.byType(AndroidUpdateDialog), findsNothing);
        expect(find.byType(AndroidUpdateBanner), findsNothing);
        final world = game.worldOf(t);
        world.player = const Offset(-1000, -1000);
        await t.pump(const Duration(milliseconds: 16));
        expect(find.byType(ResultOverlay), findsNothing);
        expect(find.byType(AndroidUpdateDialog), findsNothing);
        expect(find.byType(AndroidUpdateBanner), findsNothing);
        for (
          var i = 0;
          i < 60 && find.byType(ResultOverlay).evaluate().isEmpty;
          i++
        ) {
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(find.byType(ResultOverlay), findsOneWidget);
        await t.pump(const Duration(milliseconds: 350));
        expect(
          find.byKey(const ValueKey('update-dialog-ready')),
          findsOneWidget,
        );
        expect(
          t.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(),
          greaterThan(0),
        );
        await scores.prepareForAppRestart();
        expect(scores.latestAttempt, isNotNull);
        expect(source.completions, 0);
        if (!defer) {
          await t.tap(find.byKey(const ValueKey('update-primary')));
          await t.pump();
          await t.pump(const Duration(milliseconds: 350));
          expect(source.completions, 1);
          expect(updates.phase, UpdatePhase.installing);
          expect(scores.latestAttempt, isNotNull);
        } else {
          await t.tap(find.byKey(const ValueKey('update-later')));
          await t.pump();
          await t.pump(const Duration(milliseconds: 350));
          expect(find.byType(AndroidUpdateBanner), findsOneWidget);
          expect(find.text('Update downloaded'), findsOneWidget);
          expect(find.text('100%'), findsOneWidget);
          t.widget<ResultOverlay>(find.byType(ResultOverlay)).onReplay!();
          await t.pump();
          await t.pump(const Duration(milliseconds: 16));
          await game.start(t);
          expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).isPlaying, true);
          expect(find.byType(AndroidUpdateDialog), findsNothing);
          expect(find.byType(AndroidUpdateBanner), findsNothing);
          expect(source.completions, 0);
        }
        await t.pumpWidget(const SizedBox());
        updates.dispose();
        scores.dispose();
        economy.dispose();
        await source.stream.close();
      },
    );
  }
}
