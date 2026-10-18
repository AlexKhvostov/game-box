import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/ui/bonus_celebration.dart';
import 'simple_energy_test.dart' as fixture;

const burst = ValueKey('bonus-confirmed-celebration');
const orb = ValueKey('simple-bonus-orb');

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  testWidgets(
    'Pending double tap waits for ACK; one credit and finite effect',
    (t) async {
      final e = await fixture.store();
      addTearDown(e.dispose);
      final ack = Completer<void>();
      var calls = 0;
      e.sendEnergyOperation = (kind, args) async {
        calls++;
        await ack.future;
        await e.applyServerWallet(
          fixture.simpleWallet(balance: 80, nextAt: fixture.stamp + 28800000),
          serverNow: fixture.stamp,
          owner: 'android:1',
        );
      };
      await t.pumpWidget(fixture.app(e));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(orb));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.byKey(orb));
      expect(e.energy, 50);
      expect(calls, 1);
      expect(find.byKey(burst), findsNothing);
      ack.complete();
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(e.energy, 80);
      expect(find.byKey(burst), findsOneWidget);
      expect(find.text('08:00:00'), findsOneWidget);
      // The actual cooldown remains visible underneath the reward effect.
      final source = find.ancestor(
        of: find.byKey(orb),
        matching: find.byType(EnergyRewardDim),
      );
      expect(source, findsOneWidget);
      expect(
        t
            .widget<Opacity>(
              find.descendant(of: source, matching: find.byType(Opacity)).first,
            )
            .opacity,
        1,
      );
      expect(
        t
            .widget<IgnorePointer>(
              find
                  .descendant(of: source, matching: find.byType(IgnorePointer))
                  .first,
            )
            .ignoring,
        isTrue,
      );
      await t.pumpAndSettle();
      expect(find.byKey(burst), findsNothing);
      await t.tap(find.byKey(orb));
      await t.pump();
      expect(calls, 1);
      expect(find.byKey(burst), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      expect(t.takeException(), isNull);
    },
  );

  for (final failure in [true, false]) {
    testWidgets(
      'No celebration on ${failure ? "error" : "unchanged response"}',
      (t) async {
        final e = await fixture.store();
        addTearDown(e.dispose);
        e.sendEnergyOperation = (_, _) async {
          if (failure) throw StateError('offline');
        };
        await t.pumpWidget(fixture.app(e));
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(orb));
        await t.pumpAndSettle();
        expect(e.energy, 50);
        expect(find.byKey(burst), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('Closing window before ACK cannot leave an overlay/ticker', (
    t,
  ) async {
    final e = await fixture.store();
    addTearDown(e.dispose);
    final ack = Completer<void>();
    e.sendEnergyOperation = (_, _) => ack.future;
    await t.pumpWidget(fixture.app(e));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(orb));
    await t.pump();
    await t.pumpWidget(const SizedBox.shrink());
    ack.complete();
    await t.pumpAndSettle();
    expect(find.byKey(burst), findsNothing);
    expect(t.takeException(), isNull);
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'Effect respects reduced motion=$reduced and disposes mid-flight',
      (t) async {
        final key = GlobalKey<BonusCelebrationState>();
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Center(
                child: BonusCelebration(
                  key: key,
                  child: const SizedBox(width: 320, height: 500),
                ),
              ),
            ),
          ),
        );
        key.currentState!.play(
          from: const Offset(200, 300),
          to: const Offset(270, 80),
          amount: 30,
        );
        await t.pump();
        expect(find.byKey(burst), findsOneWidget);
        await t.pump(const Duration(milliseconds: 750));
        expect(find.byKey(burst), reduced ? findsNothing : findsOneWidget);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(seconds: 2));
        expect(t.takeException(), isNull);
      },
    );
  }
}
