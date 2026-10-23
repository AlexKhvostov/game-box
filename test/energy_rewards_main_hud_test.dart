import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'package:game_box/ui/energy_widgets.dart';
import 'package:game_box/ui/hud_fly_targets.dart';
import 'simple_energy_test.dart' as fixture;

const effect = ValueKey('bonus-confirmed-celebration');
const hudAmount = ValueKey('hud-energy-amount');

Future<EconomyStore> mount(
  WidgetTester t, {
  double width = 360,
  double scale = 1,
}) async {
  t.view.physicalSize = Size(width, 780);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final e = await fixture.store();
  final scores = ScoresStore();
  await scores.loadLocal();
  addTearDown(e.dispose);
  addTearDown(scores.dispose);
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: e),
        ChangeNotifierProvider.value(value: scores),
        Provider.value(
          value: const GameplayConfig(
            game: GameConfig(idleEnemiesMove: false, startHintEnabled: false),
            audio: AudioConfig(music: false),
          ),
        ),
      ],
      child: const GameBoxApp(forceLocale: 'ru'),
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  return e;
}

void expectBalances(WidgetTester t, int value, {bool window = true}) {
  expect(
    find.descendant(of: find.byKey(hudAmount), matching: find.text('$value')),
    findsOneWidget,
  );
  if (window) {
    expect(
      t
          .widget<EnergyText>(
            find.byKey(const ValueKey('energy-reward-balance-value')),
          )
          .amount,
      value,
    );
  }
}

void main() {
  setUp(
    () => TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed),
  );

  for (final action in ['close', 'owner', 'debit']) {
    testWidgets(
      'Rolling balance keeps confirmed wallet correct during $action',
      (t) async {
        final e = await mount(t);
        await t.tap(find.byKey(const ValueKey('hud-energy-card')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        await e.applyServerWallet(
          fixture.simpleWallet(balance: 80),
          serverNow: fixture.stamp,
          owner: 'android:1',
        );
        await t.pump();
        await t.pump();
        expect(e.energy, 80);
        expectBalances(t, 50);
        if (action == 'close') {
          await t.tap(find.byKey(const ValueKey('simple-energy-close')));
          await t.pump();
          await t.pump(const Duration(milliseconds: 300));
          expectBalances(t, 80, window: false);
          expect(find.byKey(effect), findsNothing);
        } else {
          await e.applyServerWallet(
            fixture.simpleWallet(balance: action == 'owner' ? 999 : 75),
            serverNow: fixture.stamp,
            owner: action == 'owner' ? 'android:other' : 'android:1',
          );
          await t.pump();
          await t.pump();
          expectBalances(t, action == 'owner' ? 999 : 45);
          await t.pump(const Duration(milliseconds: 1601));
          expectBalances(t, action == 'owner' ? 999 : 75);
        }
        await t.pumpWidget(const SizedBox());
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Open real modal: ACK holds both balances until arrival, then rolls them together; burst escapes dialog to main HUD',
    (t) async {
      final e = await mount(t);
      expect(find.byKey(effect), findsNothing);
      final ack = Completer<void>();
      var operations = 0;
      e.sendEnergyOperation = (_, _) async {
        operations++;
        await ack.future;
        await e.applyServerWallet(
          fixture.simpleWallet(balance: 80, nextAt: fixture.stamp + 28800000),
          serverNow: fixture.stamp,
          owner: 'android:1',
        );
      };
      await t.tap(find.byKey(const ValueKey('hud-energy-card')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expectBalances(t, 50);
      // The live wallet must not be part of the frozen scene's painted snapshot.
      expect(
        find.ancestor(
          of: find.byKey(hudAmount),
          matching: find.byType(SnapshotWidget),
        ),
        findsNothing,
      );
      final snapshot = t.widget<SnapshotWidget>(
        find.byKey(const ValueKey('game-modal-backdrop')),
      );
      expect(snapshot.controller.allowSnapshotting, isTrue);
      await t.tap(find.byKey(const ValueKey('simple-bonus-orb')));
      await t.pump();
      expectBalances(t, 50);
      expect(find.byKey(effect), findsNothing);
      ack.complete();
      await t.pump();
      await t.pump();
      await t.pump();
      expect(e.energy, 80);
      expectBalances(t, 50);
      expect(find.byKey(effect), findsOneWidget);
      expect(
        DefaultTextStyle.of(
          t.element(find.text('Энергия получена!')),
        ).style.decoration,
        TextDecoration.none,
        reason: 'A root overlay must not inherit the yellow fallback underline',
      );
      expect(
        find.descendant(
          of: find.byType(SimpleEnergyWindow),
          matching: find.byKey(effect),
        ),
        findsNothing,
      );
      final target = HudFlyTargets.centerOf(ToastFlyTarget.energy)!;
      expect(
        target.dy,
        lessThan(t.getTopLeft(find.byType(SimpleEnergyWindow)).dy),
      );
      await t.pump(const Duration(milliseconds: 1280));
      expect(
        (t.getCenter(find.byKey(const ValueKey('energy-reward-flight'))) -
                target)
            .distance,
        lessThan(.01),
      );
      expectBalances(t, 80);
      expect(operations, 1);
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 10));
        expectBalances(t, 80);
        expect(
          e.energy,
          80,
          reason:
              'Only the presentation rolls; the wallet is already committed',
        );
      }
      await t.pump(const Duration(milliseconds: 300));
      expectBalances(t, 80);
      expect(find.byKey(effect), findsNothing);
      expect(find.byType(SimpleEnergyWindow), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );

  for (final page in [
    EnergyPage.packs,
    EnergyPage.feedback,
    EnergyPage.friends,
  ]) {
    testWidgets(
      'Confirmed credit in $page uses main HUD without changing the current page',
      (t) async {
        final e = await mount(t, width: 320, scale: 2);
        final home = t.element(find.byKey(const ValueKey('hud-energy-card')));
        unawaited(showSimpleEnergyWindow(home, page: page));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        await e.applyServerWallet(
          fixture.simpleWallet(balance: 125),
          serverNow: fixture.stamp,
          owner: 'android:1',
        );
        await t.pump();
        await t.pump();
        expectBalances(t, 50, window: page == EnergyPage.packs);
        expect(find.byKey(effect), findsOneWidget);
        expect(
          t
              .widget<SimpleEnergyWindow>(find.byType(SimpleEnergyWindow))
              .initialPage,
          page,
        );
        await t.pump(const Duration(milliseconds: 1280));
        expect(
          (t.getCenter(find.byKey(const ValueKey('energy-reward-flight'))) -
                  HudFlyTargets.centerOf(ToastFlyTarget.energy)!)
              .distance,
          lessThan(.01),
        );
        await t.pump(const Duration(milliseconds: 330));
        expectBalances(t, 125, window: page == EnergyPage.packs);
        await t.pumpWidget(const SizedBox());
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Asynchronous credit with no window celebrates once; replay, debit, owner and cache never celebrate',
    (t) async {
      final e = await mount(t);
      Future<void> wallet(
        int amount, {
        String owner = 'android:1',
        bool cache = false,
      }) async {
        await e.applyServerWallet(
          fixture.simpleWallet(balance: amount),
          serverNow: fixture.stamp,
          owner: owner,
          fromCache: cache,
        );
        await t.pump();
        await t.pump();
      }

      await wallet(110);
      expectBalances(t, 50, window: false);
      expect(e.energy, 110);
      expect(find.byKey(effect), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1601));
      expectBalances(t, 110, window: false);
      for (final amount in [110, 109]) {
        await wallet(amount);
        expect(find.byKey(effect), findsNothing);
      }
      await wallet(999, owner: 'android:other');
      expect(find.byKey(effect), findsNothing);
      await wallet(1200, owner: 'android:other', cache: true);
      expect(find.byKey(effect), findsNothing);
      await wallet(1300, owner: 'android:other');
      expect(find.byKey(effect), findsNothing);
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Two successive confirmed grants queue without duplicates or stale final balance',
    (t) async {
      final e = await mount(t);
      await t.tap(find.byKey(const ValueKey('hud-energy-card')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      for (final amount in [80, 120]) {
        await e.applyServerWallet(
          fixture.simpleWallet(balance: amount),
          serverNow: fixture.stamp,
          owner: 'android:1',
        );
        await t.pump();
        await t.pump();
      }
      expectBalances(t, 50);
      expect(e.energy, 120);
      expect(find.text('+30'), findsOneWidget);
      expect(find.byKey(effect), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1601));
      await t.pump();
      expectBalances(t, 80);
      expect(find.text('+40'), findsOneWidget);
      expect(find.byKey(effect), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1601));
      expect(find.byKey(effect), findsNothing);
      expectBalances(t, 120);
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );
}
