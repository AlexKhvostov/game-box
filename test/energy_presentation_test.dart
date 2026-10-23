import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/data/energy_presentation.dart';
import 'package:game_box/ui/energy_reward_motion.dart';
import 'energy_rewards_main_hud_test.dart' as hud;
import 'simple_energy_test.dart' as fixture;

void main() {
  test('Named receipts ignore ambiguous profile snapshots and settle once', () {
    final p = EnergyPresentation()..wallet('a', 49);
    expect(p.begin('round:1', 4), isTrue);
    expect(p.balance, 53);
    p.wallet('a', 53); // Profile already contains the ACK we have not received.
    expect(p.balance, 53);
    expect(p.begin('round:1', 4), isFalse);
    p.begin('bonus:2', 30);
    p.wallet('a', 83);
    p.settle('round:1');
    expect(p.balance, 83);
    p.settle('bonus:2');
    expect(p.balance, 83);
    p.settle('bonus:2');
    expect(p.balance, 83);
  });
  test('Local attempt debit and server charge do not subtract twice', () {
    final p = EnergyPresentation()..wallet('a', 49);
    p.begin('round:1', 4);
    p.debit('run:2', 3);
    p.wallet('a', 46); // pending local reservation
    p.wallet('a', 46); // server charge replaces that reservation
    p.debit('run:2', 3);
    expect(p.balance, 50);
    p.wallet('a', 50);
    p.settle('round:1');
    expect(p.balance, 50);
  });
  test(
    'Refusal only removes its credit; actual correction and owner switch',
    () {
      final p = EnergyPresentation()..wallet('a', 49);
      p.begin('one', 4);
      p.begin('two', 30);
      p.settle('one', rejected: true);
      expect(p.balance, 79);
      p.wallet('a', 77); // server accepted a different amount, no second credit
      p.settle('two');
      expect(p.balance, 77);
      p.wallet('b', 8);
      expect(p.credits, isEmpty);
      expect(p.balance, 8);
      p.settle('one');
      expect(p.balance, 8);
    },
  );
  test(
    'Recovered receipt silently reconciles a possibly already credited cache',
    () {
      final p = EnergyPresentation()..wallet('a', 53);
      p.begin('round:1', 0, animate: false);
      p.wallet('a', 53);
      p.settle('round:1');
      expect(p.balance, 53);
      expect(p.credits.single.animate, isFalse);
    },
  );
  test(
    'Two recovered receipts never add grants already in the cached wallet',
    () {
      final p = EnergyPresentation()..wallet('a', 83);
      p.begin('round:1', 0, animate: false);
      p.begin('bonus:2', 0, animate: false);
      p.settle('round:1', amount: 3);
      expect(p.balance, 83);
      expect(p.correctionSerial, 0);
      p.settle('bonus:2', amount: 30);
      expect(p.balance, 83);
      expect(p.correctionSerial, 0);
    },
  );
  setUp(
    () => TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed),
  );
  for (final earlyAck in [false, true]) {
    testWidgets('Full displayed receipt lands before delayed ACK=$earlyAck', (
      t,
    ) async {
      final e = await hud.mount(t);
      e.presentEnergyCredit('round:test', 7);
      await t.pump();
      await t.pump();
      expect(e.energy, 50);
      hud.expectBalances(t, 50, window: false);
      expect(find.byKey(hud.effect), findsOneWidget);
      if (earlyAck) {
        await e.applyServerWallet(
          fixture.simpleWallet(balance: 57),
          owner: 'android:1',
          serverNow: fixture.stamp,
        );
        e.settleEnergyCredit('round:test');
        await t.pump();
        hud.expectBalances(t, 50, window: false);
      }
      await t.pump(const Duration(milliseconds: 1279));
      hud.expectBalances(t, 50, window: false);
      await t.pump(const Duration(milliseconds: 1));
      hud.expectBalances(t, 57, window: false);
      if (!earlyAck) {
        expect(e.energy, 50, reason: 'Optimistic UI is not spending authority');
        await e.applyServerWallet(
          fixture.simpleWallet(balance: 57),
          owner: 'android:1',
          serverNow: fixture.stamp,
        );
        e.settleEnergyCredit('round:test');
      }
      await t.pump(const Duration(milliseconds: 400));
      hud.expectBalances(t, 57, window: false);
      expect(find.byKey(hud.effect), findsNothing);
      e.presentEnergyCredit('round:test', 7);
      await t.pump();
      await t.pump();
      expect(find.byKey(hud.effect), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Final refusal after arrival corrects UI and does not replay', (
    t,
  ) async {
    final e = await hud.mount(t);
    e.presentEnergyCredit('round:refused', 7);
    await t.pump();
    await t.pump();
    await t.pump(const Duration(milliseconds: 1601));
    hud.expectBalances(t, 57, window: false);
    e.settleEnergyCredit('round:refused', rejected: true);
    await t.pump();
    hud.expectBalances(t, 50, window: false);
    expect(find.byKey(hud.effect), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  test('Receipt counter switches at arrival for full and reduced motion', () {
    expect(EnergyRewardFrame(.7999, reduced: false).roll, 0);
    expect(EnergyRewardFrame(.8, reduced: false).roll, 1);
    expect(EnergyRewardFrame(.4999, reduced: true).roll, 0);
    expect(EnergyRewardFrame(.5, reduced: true).roll, 1);
  });
  test(
    'An explicit zero grant is corrected while another receipt stays pending',
    () {
      final p = EnergyPresentation()..wallet('a', 49);
      p.begin('round:1', 7);
      p.begin('bonus:2', 30);
      p.settle('round:1', amount: 0);
      expect(p.balance, 79);
      expect(p.correctionSerial, 1);
      p.wallet('a', 79);
      p.settle('bonus:2', amount: 30);
      expect(p.balance, 79);
    },
  );
}
