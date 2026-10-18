// Legacy contract2 regression coverage. The current contract3 surface is
// verified in simple_energy_test.dart; this suite retains historical dialogs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/domain/android_energy.dart';
import 'package:game_box/domain/energy_test_catalog.dart';
import 'package:game_box/features/balance/legacy_energy_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';

class _Account extends MobileAccount {
  int quotes = 0, syncs = 0;
  @override
  Future<Map<String, dynamic>> quotePlay(String id, String requestId) async {
    quotes++;
    throw StateError('A test offer must never request a payment quote');
  }

  @override
  Future<void> syncPlay() async {
    syncs++;
  }
}

class _Economy extends EconomyStore {
  _Economy() : super(storagePrefix: 'test_service_preview_');
  int claims = 0, feedback = 0;
  @override
  bool get canSendEnergyFeedback => true;
  @override
  Future<void> claimEnergy() async {
    claims++;
  }

  @override
  Future<void> sendEnergyFeedback(String comment, {int? rating}) async {
    feedback++;
  }
}

Future<void> _mount(
  WidgetTester t,
  EconomyStore economy,
  PlayBillingService billing,
  Future<void> Function(BuildContext) open, {
  double scale = 1,
}) async {
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<EconomyStore>.value(value: economy),
        ChangeNotifierProvider<PlayBillingService>.value(value: billing),
        ChangeNotifierProvider<MobileAccount>.value(value: billing.account),
      ],
      child: MaterialApp(
        theme: buildGameTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (c) =>
                TextButton(onPressed: () => open(c), child: const Text('open')),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Reference prices are explicit, centralized and never native metadata',
    () async {
      final account = _Account();
      final ordinary = PlayBillingService(account, testServicePreview: false);
      final preview = PlayBillingService(account, testServicePreview: true);
      expect(ordinary.energyOfferPrice('energy_100_v1'), isNull);
      expect(preview.price('energy_100_v1'), isNull);
      expect(preview.products, isEmpty);
      for (final entry in EnergyTestCatalog.usd.entries) {
        final price = preview.energyOfferPrice(entry.key)!;
        expect(price.rawPrice, entry.value);
        expect(price.reference, isTrue);
      }
      const config = AndroidEnergyConfig();
      expect(preview.energyDiscount('energy_250_v1', config), 20);
      expect(preview.energyDiscount('energy_500_v1', config), 40);
      expect(preview.energyDiscount('energy_1000_v1', config), 55);
      expect(preview.batteryDiscount('energy_batteries_5_v1', config), 25);
      expect(preview.energyOfferPrice('energy_777_v9'), isNull);
      final native = ProductDetails(
        id: 'energy_100_v1',
        title: '',
        description: '',
        price: '2,49 €',
        rawPrice: 2.49,
        currencyCode: 'EUR',
        currencySymbol: '€',
      );
      preview.products[native.id] = native;
      expect(preview.energyOfferPrice(native.id)!.price, native.price);
      expect(preview.energyOfferPrice(native.id)!.reference, isFalse);
      expect(preview.price(native.id), native.price);
      expect(
        preview.energyDiscount('energy_250_v1', config),
        isNull,
        reason: 'Do not compare reference and real store prices',
      );
      for (final invalidPrice in [0.0, double.infinity, double.nan]) {
        for (final id in EnergyTestCatalog.usd.keys) {
          preview.products[id] = ProductDetails(
            id: id,
            title: '',
            description: '',
            price: 'store-price',
            rawPrice: invalidPrice,
            currencyCode: 'USD',
            currencySymbol: r'$',
          );
          final price = preview.energyOfferPrice(id)!;
          expect(price.price, 'store-price');
          expect(price.reference, isFalse);
        }
        expect(preview.energyDiscount('energy_1000_v1', config), isNull);
        expect(
          preview.batteryDiscount('energy_batteries_5_v1', config),
          isNull,
        );
      }
      await expectLater(
        preview.buy(native.id),
        throwsA(
          isA<MobileApiError>().having(
            (e) => e.code,
            'code',
            'test_service_unavailable',
          ),
        ),
      );
      await expectLater(
        preview.restore(),
        throwsA(
          isA<MobileApiError>().having(
            (e) => e.code,
            'code',
            'test_service_unavailable',
          ),
        ),
      );
      await preview.initialize();
      expect(account.quotes, 0);
      expect(account.syncs, 0);
      expect(preview.busy, isFalse);
      ordinary.dispose();
      preview.dispose();
      account.dispose();
    },
  );

  testWidgets(
    'Test purchase cards show prices and warn without purchase or credit',
    (t) async {
      final account = _Account();
      final billing = PlayBillingService(account, testServicePreview: true);
      final e = _Economy();
      await e.load();
      await e.enableEnergyPreview();
      await _mount(t, e, billing, (c) => showLegacyEnergySheet(c, initialTab: 3));
      for (final n in [2, 4, 6, 9]) {
        expect(find.text('\$$n'), findsOneWidget);
      }
      for (final n in [20, 40, 55]) {
        expect(find.text('−$n%'), findsOneWidget);
      }
      expect(find.text('Недоступно'), findsNothing);
      await t.tap(find.byKey(const ValueKey('energy-pack-energy_100_v1')));
      await t.pumpAndSettle();
      expect(
        find.text('В тестовой версии оплата пока недоступна.'),
        findsOneWidget,
      );
      expect(account.quotes, 0);
      expect(e.energy, 47);
      expect(e.claims, 0);
      await t.tap(find.byKey(const ValueKey('test-service-unavailable-close')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('energy-billing-restore')));
      await t.pumpAndSettle();
      expect(
        find.text('В тестовой версии восстановление покупок пока недоступно.'),
        findsOneWidget,
      );
      expect(account.syncs, 0);
      expect(e.energy, 47);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      e.dispose();
      billing.dispose();
      account.dispose();
    },
  );

  testWidgets('Test battery plans remain selectable and do not add batteries', (
    t,
  ) async {
    final account = _Account();
    final billing = PlayBillingService(account, testServicePreview: true);
    final e = _Economy();
    await e.load();
    await e.enableEnergyPreview();
    await _mount(t, e, billing, showLegacyEnergySubscriptionSheet);
    expect(find.textContaining(r'$1'), findsWidgets);
    expect(find.textContaining(r'$3'), findsWidgets);
    await t.ensureVisible(find.byKey(const ValueKey('energy-subscribe-4')));
    await t.tap(find.byKey(const ValueKey('energy-subscribe-4')));
    await t.pumpAndSettle();
    expect(
      find.text('В тестовой версии оплата пока недоступна.'),
      findsOneWidget,
    );
    expect(e.energyBatteries.length, 1);
    expect(e.energy, 47);
    expect(account.quotes, 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    e.dispose();
    billing.dispose();
    account.dispose();
  });

  testWidgets(
    'Unavailable test video warns and working feedback remains reachable',
    (t) async {
      final account = _Account();
      final billing = PlayBillingService(account, testServicePreview: true);
      final e = _Economy();
      await e.load();
      await e.enableEnergyPreview();
      await _mount(t, e, billing, (c) => showLegacyEnergySheet(c, initialTab: 1));
      await t.tap(find.byKey(const ValueKey('energy-task-watch_ad')));
      await t.pumpAndSettle();
      expect(
        find.text('В тестовой версии просмотр рекламы пока недоступен.'),
        findsOneWidget,
      );
      expect(e.energy, 47);
      await t.tap(find.byKey(const ValueKey('test-service-unavailable-close')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('energy-task-feedback')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('test-service-unavailable')),
        findsNothing,
      );
      expect(find.byType(TextField), findsWidgets);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      e.dispose();
      billing.dispose();
      account.dispose();
    },
  );

  testWidgets(
    'Explicit test gate warns even with native metadata and a linked owner',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final account = _Account()
        ..id = 'android:1'
        ..googleLinked = true;
      final billing = PlayBillingService(account, testServicePreview: true)
        ..available = true;
      billing.products['energy_100_v1'] = ProductDetails(
        id: 'energy_100_v1',
        title: '',
        description: '',
        price: r'$2.49',
        rawPrice: 2.49,
        currencyCode: 'USD',
      );
      final e = _Economy();
      await e.load();
      await e.enableEnergyPreview();
      await _mount(
        t,
        e,
        billing,
        (c) => showEnergyPurchaseSheet(c, 'energy_100_v1', 100),
        scale: 2,
      );
      expect(
        find.text('В тестовой версии оплата пока недоступна.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('energy-recovery-connect')),
        findsNothing,
      );
      expect(
        t
            .getRect(
              find.byKey(const ValueKey('test-service-unavailable-close')),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(account.quotes, 0);
      expect(e.energy, 47);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      e.dispose();
      billing.dispose();
      account.dispose();
    },
  );

  for (final scale in [1.0, 1.2, 2.0]) {
    testWidgets(
      'Collect button is compact centered and usable at320 width/$scale',
      (t) async {
        await t.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final account = _Account();
        final billing = PlayBillingService(account, testServicePreview: true);
        final e = _Economy();
        await e.load();
        await e.enableEnergyPreview();
        await _mount(t, e, billing, showLegacyEnergySheet, scale: scale);
        final claim = t.getRect(find.byKey(const ValueKey('energy-claim')));
        final summary = t.getRect(
          find.byKey(const ValueKey('energy-charge-summary')),
        );
        expect(claim.width, lessThan(summary.width));
        expect(claim.height, closeTo(48, .01));
        expect((claim.center.dx - summary.center.dx).abs(), lessThan(1));
        await t.tap(find.byKey(const ValueKey('energy-claim')));
        await t.pumpAndSettle();
        expect(
          e.claims,
          1,
          reason:
              'Working energy claim is not blocked by the test service gate',
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        e.dispose();
        billing.dispose();
        account.dispose();
      },
    );
  }
}
