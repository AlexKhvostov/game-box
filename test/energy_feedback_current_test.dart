import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/data/economy_store.dart';
import 'simple_energy_test.dart' as fixture;

Future<void> progress(EconomyStore e, int spent, {bool claimed = false}) =>
    e.applyServerWallet(
      {
        ...fixture.simpleWallet(),
        'feedbackSpentEnergy': spent,
        'feedbackMinimumSpend': 100,
        'energy': claimed ? 100 : 50,
        'claimed': claimed ? ['energy_feedback'] : <String>[],
      },
      owner: 'android:1',
      serverNow: fixture.stamp,
    );

void main() {
  testWidgets(
    'Current energy menu shows feedback and keeps form locked below100',
    (t) async {
      final e = await fixture.store();
      addTearDown(e.dispose);
      await progress(e, 99);
      await t.pumpWidget(fixture.app(e));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      final button = find.byKey(const ValueKey('simple-energy-feedback'));
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(find.text('Потрачено: 99 из 100'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Достижения'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Server progress100 opens internal feedback; confirmed50 only once',
    (t) async {
      final e = await fixture.store();
      addTearDown(e.dispose);
      await progress(e, 100);
      final sent = <String>[];
      e.sendEnergyOperation = (kind, args) async {
        sent.add(kind);
        expect(
          args['comment'],
          'Мне было интересно, но управление можно улучшить.',
        );
        expect(args.containsKey('rating'), isFalse);
        await progress(e, 100, claimed: true);
      };
      await t.pumpWidget(fixture.app(e));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      final button = find.byKey(const ValueKey('simple-energy-feedback'));
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('energy-feedback-text')),
        'Мне было интересно, но управление можно улучшить.',
      );
      await t.pumpAndSettle();
      final send = find.byKey(const ValueKey('energy-feedback-send'));
      await t.ensureVisible(send);
      await t.tap(send);
      await t.pumpAndSettle();
      expect(find.text('Спасибо! Ваш отзыв принят.'), findsOneWidget);
      expect(e.energy, 100);
      expect(sent, ['energy_feedback']);
      await t.tap(find.byKey(const ValueKey('energy-feedback-back')));
      await t.pumpAndSettle();
      expect(find.text('Получено'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  test('Client refuses feedback before server-confirmed spend100', () async {
    final e = await fixture.store();
    addTearDown(e.dispose);
    var calls = 0;
    e.sendEnergyOperation = (_, args) async => calls++;
    await progress(e, 99);
    await expectLater(
      e.sendEnergyFeedback('Достаточно длинный текст впечатлений.'),
      throwsStateError,
    );
    expect(calls, 0);
  });
}
