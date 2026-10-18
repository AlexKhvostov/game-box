import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'simple_energy_test.dart' as fixture;

void main() {
  testWidgets(
    'Bonus reward stays centered and inside the circle in each tier',
    (t) async {
      for (final width in [120.0, 200.0]) {
        for (final amount in [30, 60, 150]) {
          for (final ready in [true, false]) {
            await t.pumpWidget(
              MaterialApp(
                home: Center(
                  child: SizedBox(
                    width: width,
                    height: width,
                    child: BonusOrb(
                      amount: amount,
                      ready: ready,
                      remaining: const Duration(hours: 4),
                      fraction: .5,
                    ),
                  ),
                ),
              ),
            );
            final orb = t.getRect(
              find.byKey(const ValueKey('simple-bonus-orb')),
            );
            final reward = t.getRect(
              find.byKey(const ValueKey('simple-bonus-amount')),
            );
            final digits = t.getRect(
              find.byKey(const ValueKey('simple-bonus-value')),
            );
            final currency = t.getRect(
              find.byKey(const ValueKey('simple-bonus-currency')),
            );
            expect(
              find.byWidgetPredicate(
                (w) =>
                    w is CustomPaint &&
                    w.painter.runtimeType.toString() == '_BonusBoltPainter',
              ),
              findsNWidgets(ready ? 2 : 1),
            );
            expect(reward.center.dx, closeTo(orb.center.dx, .5));
            expect(digits.center.dx, closeTo(orb.center.dx, .5));
            expect(currency.left, greaterThan(digits.right));
            expect(currency.center.dy, closeTo(digits.center.dy, .5));
            expect(
              reward.left,
              greaterThanOrEqualTo(orb.left + orb.width * .16 - .1),
            );
            expect(
              reward.right,
              lessThanOrEqualTo(orb.right - orb.width * .16 + .1),
            );
            expect(reward.bottom, lessThan(orb.top + orb.height * .70));
            expect(t.takeException(), isNull);
          }
        }
      }
    },
  );

  for (final tier in [2, 5]) {
    testWidgets(
      'Subscription multiplier stays inside the bonus button tier$tier at320/font2',
      (t) async {
        final e = await fixture.store(tier: tier);
        addTearDown(e.dispose);
        await t.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(fixture.app(e, scale: 2));
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        final multiplier = find.byKey(
          const ValueKey('simple-bonus-multiplier'),
        );
        expect(multiplier, findsOneWidget);
        expect(find.text('×$tier'), findsOneWidget);
        final orb = t.getRect(find.byKey(const ValueKey('simple-bonus-orb')));
        final badge = t.getRect(multiplier);
        expect(badge.top, greaterThan(orb.top));
        expect(
          badge.bottom,
          lessThan(
            t.getRect(find.byKey(const ValueKey('simple-bonus-value'))).top,
          ),
        );
        expect(find.text('${tier * 30}'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Maximum tier5 cannot upgrade or glow; separate Manage remains available',
    (t) async {
      final e = await fixture.store(tier: 5);
      addTearDown(e.dispose);
      await t.pumpWidget(fixture.app(e));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      final boost = find.byKey(const ValueKey('simple-energy-boost'));
      expect(find.text('Максимальный\nбонус'), findsOneWidget);
      final panel = t.widget<Container>(
        find.descendant(of: boost, matching: find.byType(Container)).first,
      );
      expect((panel.decoration! as BoxDecoration).boxShadow, isEmpty);
      await t.tap(boost);
      await t.pumpAndSettle();
      expect(find.text('Максимальный\nбонус'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('simple-manage-subscription')));
      await t.pumpAndSettle();
      expect(find.text('Увеличить размер бонуса'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('confirmed bonus starts eight hours and countdown advances', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var elapsed = 0;
    final e = EconomyStore(monotonicMilliseconds: () => elapsed);
    await e.load();
    await e.applyServerWallet(
      fixture.simpleWallet(),
      serverNow: fixture.stamp,
      owner: 'android:1',
    );
    addTearDown(e.dispose);
    e.sendEnergyOperation = (kind, args) async {
      expect(kind, 'energy_bonus_claim');
      await e.applyServerWallet(
        fixture.simpleWallet(balance: 80, nextAt: fixture.stamp + 28800000),
        serverNow: fixture.stamp,
        owner: 'android:1',
      );
    };
    await t.pumpWidget(fixture.app(e));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('simple-bonus-orb')));
    await t.pumpAndSettle();
    expect(e.energy, 80);
    expect(find.text('08:00:00'), findsOneWidget);
    elapsed = 2100;
    await t.pump(const Duration(seconds: 1));
    expect(find.text('07:59:58'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('simple-bonus-orb')));
    expect(e.energy, 80);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unsupported server is not presented as active synchronization', (
    t,
  ) async {
    final e = await fixture.store();
    addTearDown(e.dispose);
    await e.applyServerWallet(
      fixture.simpleWallet()..remove('simpleBonus'),
      serverNow: fixture.stamp,
      owner: 'android:1',
    );
    await t.pumpWidget(fixture.app(e));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Ожидание сервера'), findsOneWidget);
    expect(find.text('Синхронизация'), findsNothing);
    expect(find.text('Бонус ждёт обновления сервера'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Pack ribbons use actual savings and disappear without comparable prices',
    (t) async {
      final e = await fixture.store();
      final account = MobileAccount();
      final billing = PlayBillingService(account);
      addTearDown(() {
        billing.dispose();
        account.dispose();
        e.dispose();
      });
      void price(String id, double value, [String currency = 'USD']) {
        billing.products[id] = ProductDetails(
          id: id,
          title: id,
          description: 'Test',
          price: '$currency $value',
          rawPrice: value,
          currencyCode: currency,
          currencySymbol: currency,
        );
      }

      price('energy_100_v1', 2);
      price('energy_250_v1', 4);
      price('energy_500_v1', 6);
      price('energy_1000_v1', 9);
      await t.pumpWidget(
        ChangeNotifierProvider<PlayBillingService>.value(
          value: billing,
          child: fixture.app(e, page: EnergyPage.packs),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      for (final percent in [20, 40, 55]) {
        expect(find.byKey(ValueKey('energy-savings-$percent')), findsOneWidget);
      }
      // The saving must read together with the crossed price, and the ribbons
      // must not make the card taller than the original compact pack.
      for (final id in ['energy_250_v1', 'energy_500_v1', 'energy_1000_v1']) {
        final tile = find.byKey(ValueKey('simple-pack-tile-$id'));
        final oldPrice = find.descendant(
          of: tile,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text && w.style?.decoration == TextDecoration.lineThrough,
          ),
        );
        final badge = find.descendant(
          of: tile,
          matching: find.byType(EnergySavingsBadge),
        );
        final previous = t.getRect(oldPrice), saving = t.getRect(badge);
        expect(saving.center.dy, closeTo(previous.center.dy, 1));
        final button = find.byKey(ValueKey('simple-pack-$id'));
        final current = t.getRect(
          find.byKey(ValueKey('simple-pack-price-$id')),
        );
        final purchase = t.getRect(button);
        expect(current.left - previous.right, inInclusiveRange(0, 8));
        expect(saving.left - current.right, inInclusiveRange(0, 8));
        expect(purchase.contains(previous.center), isTrue);
        expect(purchase.contains(current.center), isTrue);
        expect(purchase.contains(saving.center), isTrue);
        expect(t.getSize(tile).height, lessThanOrEqualTo(176));
      }
      expect(find.text('Выгода к цене 100 энергии'), findsOneWidget);
      price('energy_250_v1', 4, 'EUR');
      billing.notifyListeners();
      await t.pump();
      expect(find.byKey(const ValueKey('energy-savings-20')), findsNothing);
      expect(find.byKey(const ValueKey('energy-savings-55')), findsOneWidget);
      billing.products.remove('energy_100_v1');
      billing.notifyListeners();
      await t.pump();
      expect(find.byType(EnergySavingsBadge), findsNothing);
      expect(find.text('Выгода к цене 100 энергии'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Boost opens subscription without claiming or changing balance', (
    t,
  ) async {
    final e = await fixture.store();
    addTearDown(e.dispose);
    await t.pumpWidget(fixture.app(e));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    final boost = find.byKey(const ValueKey('simple-energy-boost'));
    expect(
      find.descendant(of: boost, matching: find.textContaining('×')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: boost,
        matching: find.text('Увеличить\nразмер\nбонуса'),
      ),
      findsOneWidget,
    );
    await t.tap(boost);
    await t.pumpAndSettle();
    expect(find.text('Увеличить размер бонуса'), findsOneWidget);
    expect(e.energy, 50);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
