import 'package:game_box/features/result/share_social_sheet.dart';
import 'package:game_box/features/result/share_score_sheet.dart';
import 'package:game_box/features/game/widgets/freeze_sheet.dart';
import 'package:game_box/features/floors/floors_levels_sheet.dart';
import 'package:game_box/features/floors/floors_progress.dart';
import 'package:game_box/ui/billing_unavailable.dart';
import 'package:game_box/ui/neon_chrome.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/game/lives_sheet.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/features/leaderboard/player_result_sheet.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/audience_gate.dart';
import 'package:game_box/ui/game_sheet.dart';
import 'package:game_box/ui/game_ui.dart';

class _Scores extends ScoresStore {
  int? today;
  @override
  List<ScoreEntry> scoresForNamedPeriod(String period) => today == null
      ? []
      : [
          ScoreEntry(
            id: 'test',
            displayName: 'Player',
            timeMs: today!,
            createdAt: DateTime.now(),
          ),
        ];
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
}

void main() {
  testWidgets(
    'daily leader updates; account record has no visible caption; run navigation disabled',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final economy = EconomyStore();
      await economy.load();
      economy.bestTimeMs = 21349;
      final scores = _Scores();
      final frame = ValueNotifier(0);
      var playing = false;
      var taps = 0;
      Future<void> mount() => tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: economy),
            ChangeNotifierProvider<ScoresStore>.value(value: scores),
            Provider.value(value: const GameplayConfig()),
          ],
          child: MaterialApp(
            theme: buildGameTheme(),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ArcadeHud(
                frame: frame,
                timeMs: () => playing ? 12430 : 0,
                jumpProgress: () => 1,
                isPlaying: playing,
                onLivesTap: () => taps++,
                onCrystalsTap: () => taps++,
                onRecordTap: () => taps++,
                onProfileTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      await mount();
      await tester.pump();
      expect(find.text('—'), findsOneWidget);
      expect(find.text('21.349'), findsOneWidget);
      expect(find.textContaining('Мой рекорд'), findsNothing);
      scores.today = 31420;
      scores.notifyListeners();
      await tester.pump();
      expect(find.text('31.420'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hud-ranking-card')));
      expect(taps, 1);
      playing = true;
      await mount();
      await tester.pump();
      for (final name in ['lives', 'crystals', 'ranking', 'account']) {
        await tester.tap(find.byKey(ValueKey('hud-$name-card')));
      }
      expect(taps, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      economy.dispose();
      scores.dispose();
      frame.dispose();
    },
  );

  testWidgets(
    'real sheets/dialogs/nested confirmations use identical backdrop and block background input',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final economy = EconomyStore();
      await economy.load();
      final scores = _Scores(),
          prefs = PlayerPreferences(),
          audience = AudiencePolicy();
      await prefs.load();
      await audience.load();
      final nav = GlobalKey<NavigatorState>();
      late BuildContext home;
      var backgroundTaps = 0;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: economy),
            ChangeNotifierProvider<ScoresStore>.value(value: scores),
            ChangeNotifierProvider.value(value: prefs),
            ChangeNotifierProvider.value(value: audience),
            Provider.value(value: const GameplayConfig()),
          ],
          child: MaterialApp(
            theme: buildGameTheme(),
            navigatorKey: nav,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                home = context;
                return Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: TextButton(
                      onPressed: () => backgroundTaps++,
                      child: const Text('Background'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      final windows = <Future<void> Function()>[
        () => showLivesSheet(home),
        () => showCrystalsSheet(home),
        () => showProfileSheet(home),
        () => showLeaderboardSheet(home),
        () => showPlayerResultSheet(
          home,
          entry: ScoreEntry(
            id: 'test',
            displayName: 'Player',
            timeMs: 12345,
            createdAt: DateTime.now(),
          ),
          place: 1,
        ),
        () => showPlusSheet(home),
        () => showShareSocialSheet(home, timeMs: 12345),
        () => showShareScoreSheet(home, timeMs: 12345),
        () => showFreezeSheet(home),
        () => showFloorsLevelsSheet(
          context: home,
          progress: FloorsProgress.instance,
          onPlayFloor: (_) {},
        ),
        () async {
          showBillingUnavailable(home);
        },
        () => showAudienceSelection(home),
        () => showProfileResetConfirmation(home).then((_) {}),
        () => showProfileRestoreConfirmation(home).then((_) {}),
      ];
      for (final open in windows) {
        unawaited(open());
        await tester.pumpAndSettle();
        final barriers = tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .where((b) => b.color != null)
            .toList();
        expect(barriers, isNotEmpty);
        expect(barriers.every((b) => b.color == GameUi.modalBarrier), isTrue);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(backgroundTaps, 0);
        expect(nav.currentState!.canPop(), isFalse);
        if (nav.currentState!.canPop()) nav.currentState!.pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      // Captured sheet theme must keep the same barrier for a nested dialog.
      unawaited(showProfileSheet(home));
      await tester.pumpAndSettle();
      final nested = tester.element(find.byType(NeonGlass).first);
      unawaited(showProfileResetConfirmation(nested));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .where((b) => b.color != null)
            .every((b) => b.color == GameUi.modalBarrier),
        isTrue,
      );
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      economy.dispose();
      scores.dispose();
      prefs.dispose();
      audience.dispose();
    },
  );
}
