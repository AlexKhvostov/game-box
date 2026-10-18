import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'blue_glass_profile_test.dart' as profile;
import 'uniform_pace_helmet_test.dart' as game;

Future<EconomyStore> openShop(
  WidgetTester tester,
  String locale, {
  DateTime Function()? now,
}) async {
  SharedPreferences.setMockInitialValues({});
  final economy = EconomyStore(now: now);
  await economy.load();
  economy.lastDailyClaimAt = (now ?? DateTime.now)();
  economy.dailyStreak = 3;
  await tester.binding.setSurfaceSize(const Size(320, 560));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        Provider.value(value: GameplayConfig()),
      ],
      child: MaterialApp(
        theme: buildGameTheme(),
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCrystalsSheet(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return economy;
}

void main() {
  testWidgets(
    'modal background freezes through nested windows and resumes on close',
    (tester) async {
      await game.mount(tester, const GameplayConfig());
      final backdrop = find.byKey(const ValueKey('game-modal-backdrop'));
      SnapshotController controller() =>
          tester.widget<SnapshotWidget>(backdrop).controller;
      expect(controller().allowSnapshotting, false);
      await tester.tap(find.byKey(const ValueKey('hud-crystals-card')));
      await tester.pumpAndSettle();
      expect(controller().allowSnapshotting, true);
      await tester.tap(find.byKey(const ValueKey('daily-plus-card')));
      await tester.pumpAndSettle();
      expect(controller().allowSnapshotting, true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(controller().allowSnapshotting, true);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(controller().allowSnapshotting, false);
      expect(find.byType(TabBar), findsNothing);
      await game.start(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('00:00.000'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
  for (final locale in ['ru', 'en']) {
    for (final size in [const Size(320, 480), const Size(390, 844)]) {
      testWidgets(
        '$locale linked Google has details without action-row $size',
        (tester) async {
          final account = profile.ProfileTestAccount()
            ..id = 'fixture:linked'
            ..googleLinked = true
            ..googleName = 'Fixture Player'
            ..googleEmail = 'fixture@example.invalid';
          await profile.mountProfile(
            tester,
            language: locale,
            size: size,
            fixtureAccount: account,
            scale: size.height == 480 ? 2 : 1,
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('profile-google-email')),
            60,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('profile-content')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('profile-google-restore')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('profile-google-link')),
            findsNothing,
          );
          expect(find.text('Fixture Player'), findsOneWidget);
          expect(find.text('fixture@example.invalid'), findsOneWidget);
          final panel = tester.getRect(
            find.byKey(const ValueKey('profile-google-setting')),
          );
          final hint = tester.getRect(
            find.byKey(const ValueKey('profile-google-privacy-hint')),
          );
          expect(
            panel.bottom - hint.bottom,
              closeTo(13, .01),
            reason: 'No empty button row after the linked account',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
    testWidgets(
      '$locale shop retains pages/scroll and does not rebuild header after taps/swipes',
      (tester) async {
        var clock = DateTime(2026, 10, 12, 12);
        final economy = await openShop(tester, locale, now: () => clock);
        final bar = tester.widget<TabBar>(find.byType(TabBar));
        final header = tester.widget(
          find.byKey(const ValueKey('shop-crystal-balance')),
        );
        final daily = find.byKey(const ValueKey('daily-days-scroll'));
        final scroll = tester.state<ScrollableState>(
          find.descendant(of: daily, matching: find.byType(Scrollable)).first,
        );
        await tester.drag(daily, const Offset(0, -170));
        await tester.pumpAndSettle();
        final offset = scroll.position.pixels;
        expect(offset, greaterThan(0));
        for (final index in [1, 2, 3, 0, 2, 0]) {
          await tester.tap(find.byKey(ValueKey('shop-tab-$index')));
          await tester.pumpAndSettle();
          expect(bar.controller!.index, index);
          expect(
            identical(
              tester.widget(find.byKey(const ValueKey('shop-crystal-balance'))),
              header,
            ),
            true,
          );
        }
        expect(scroll.mounted, true);
        expect(scroll.position.pixels, closeTo(offset, .01));
        await tester.drag(find.byType(TabBarView), const Offset(-280, 0));
        await tester.pumpAndSettle();
        expect(bar.controller!.index, 1);
        await tester.drag(find.byType(TabBarView), const Offset(280, 0));
        await tester.pumpAndSettle();
        expect(bar.controller!.index, 0);
        expect(scroll.position.pixels, closeTo(offset, .01));
        // The retained daily pane reactivates its countdown on return.
        final countdown = find.byKey(const ValueKey('daily-next-countdown-4'));
        await tester.scrollUntilVisible(
          countdown,
          60,
          scrollable: find
              .descendant(of: daily, matching: find.byType(Scrollable))
              .first,
        );
        final before = tester.widget<Text>(countdown).data;
        clock = clock.add(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 2));
        expect(tester.widget<Text>(countdown).data, isNot(before));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        economy.dispose();
      },
    );
  }
}
