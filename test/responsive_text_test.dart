import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/game/lives_sheet.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_sheet.dart';
import 'package:game_box/ui/game_viewport.dart';

class _OfflineScores extends ScoresStore {
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
}

class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();
  @override
  double scale(double fontSize) => fontSize * (fontSize <= 16 ? 1.25 : 1.1);
  @override
  double get textScaleFactor => 1.25;
}

void main() {
  test('normal screens preserve nonlinear system text below the limit', () {
    final scaler = GameViewport.textScalerFor(
      const _NonlinearTextScaler(),
      size: const Size(412, 844),
    );
    expect(scaler.scale(16), 20);
    expect(scaler.scale(32), 35.2);
  });

  testWidgets('rendered text shrinks with width and with available height', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final systemScale in [1.0, 2.0]) {
      final heights = <double>[];
      tester.platformDispatcher.textScaleFactorTestValue = systemScale;
      for (final size in [
        const Size(320, 480),
        const Size(320, 740),
        const Size(412, 740),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => GameViewport(child: child!),
            home: const Scaffold(
              body: Center(
                child: Text('Readable', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        );
        await tester.pump();
        heights.add(tester.getRect(find.text('Readable')).height);
        final before = tester.getRect(find.text('Readable'));
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pump();
        expect(
          tester.getRect(find.text('Readable')).height,
          closeTo(before.height, 1e-6),
        );
        tester.view.resetViewInsets();
        expect(tester.takeException(), isNull);
      }
      expect(heights[0], lessThan(heights[1]));
      expect(heights[1], lessThan(heights[2]));
    }
  });

  testWidgets('system enlargement cannot double text inside a small modal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final navigator = GlobalKey<NavigatorState>();
    final rendered = <double>[];
    for (final scale in [1.0, 2.0]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => GameViewport(child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => const AlertDialog(
                    content: Text('Modal text', style: TextStyle(fontSize: 18)),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      rendered.add(tester.getRect(find.text('Modal text')).height);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
    }
    expect(rendered[1], greaterThan(rendered[0]));
    expect(rendered[1], lessThan(rendered[0] * 1.2));
  });

  for (final language in ['ru', 'en']) {
    for (final size in [
      const Size(280, 480),
      const Size(320, 480),
      const Size(320, 560),
      const Size(390, 844),
    ]) {
      for (final systemScale in [1.0, 2.0]) {
        testWidgets('scaled windows $language $size system$systemScale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          tester.platformDispatcher.textScaleFactorTestValue = systemScale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          SharedPreferences.setMockInitialValues({});
          final economy = EconomyStore();
          await economy.load();
          final audience = AudiencePolicy();
          await audience.load();
          await audience.select(AgeBand.age21plus);
          final prefs = PlayerPreferences();
          await prefs.load();
          final account = MobileAccount()
            ..id = 'android:90000000'
            ..nickname = 'TestPlayer'
            ..googleLinked = true
            ..googleName = 'Тестовый игрок'
            ..googleEmail = 'player@example.invalid';
          final scores = _OfflineScores();
          final navigator = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: economy),
                ChangeNotifierProvider.value(value: audience),
                ChangeNotifierProvider.value(value: prefs),
                ChangeNotifierProvider.value(value: account),
                ChangeNotifierProvider<ScoresStore>.value(value: scores),
                Provider.value(value: GameplayConfig()),
              ],
              child: MaterialApp(
                navigatorKey: navigator,
                theme: buildGameTheme(),
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => GameViewport(child: child!),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        TextButton(
                          onPressed: () => showProfileSheet(context),
                          child: const Text('Profile'),
                        ),
                        TextButton(
                          onPressed: () => showCrystalsSheet(context),
                          child: const Text('Shop'),
                        ),
                        TextButton(
                          onPressed: () => showLivesSheet(context),
                          child: const Text('Lives'),
                        ),
                        TextButton(
                          onPressed: () => showLeaderboardSheet(context),
                          child: const Text('Ranking'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          for (final name in ['Profile', 'Shop', 'Lives', 'Ranking']) {
            await tester.tap(find.text(name));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$name $size $language',
            );
            final title = find.byType(GameSheetHeader);
            if (title.evaluate().isNotEmpty) {
              final rect = tester.getRect(title.first);
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(size.width));
            }
            navigator.currentState!.pop();
            await tester.pumpAndSettle();
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
