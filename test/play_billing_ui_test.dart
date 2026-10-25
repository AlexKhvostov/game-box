import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:provider/provider.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/ui/billing_unavailable.dart';

class FakeBilling extends PlayBillingService {
  FakeBilling(super.account) {
    available = true;
    for (final id in ['pack_s', 'plus_weekly']) {
      products[id] = ProductDetails(
        id: id,
        title: id,
        description: id,
        price: 'USD 2.34',
        rawPrice: 2.34,
        currencyCode: 'USD',
      );
    }
  }
  int launched = 0;
  @override
  Future<void> buy(String id) async {
    launched++;
  }
}

void main() {
  test(
    'weekly purchase ignores trials and mismatched subscription periods',
    () {
      GooglePlayProductDetails offer(String period, {String? offerId}) =>
          GooglePlayProductDetails.fromProductDetails(
            ProductDetailsWrapper(
              description: 'Plus',
              name: 'Plus',
              productId: 'plus_weekly',
              productType: ProductType.subs,
              title: 'Plus',
              subscriptionOfferDetails: [
                SubscriptionOfferDetailsWrapper(
                  basePlanId: 'weekly',
                  offerId: offerId,
                  offerTags: [],
                  offerIdToken: 'test-offer',
                  pricingPhases: [
                    PricingPhaseWrapper(
                      billingCycleCount: 0,
                      billingPeriod: period,
                      formattedPrice: 'USD 2.34',
                      priceAmountMicros: 2340000,
                      priceCurrencyCode: 'USD',
                      recurrenceMode: RecurrenceMode.infiniteRecurring,
                    ),
                  ],
                ),
              ],
            ),
          ).single;
      expect(PlayBillingService.supportedProduct(offer('P1W')), isTrue);
      expect(PlayBillingService.supportedProduct(offer('P1M')), isFalse);
      expect(
        PlayBillingService.supportedProduct(offer('P1W', offerId: 'trial')),
        isFalse,
      );
    },
  );
  Future<void> mount(
    WidgetTester tester,
    FakeBilling billing,
    String id,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<PlayBillingService>.value(
        value: billing,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => buyGoogleProduct(context, id),
                    child: const Text('Buy'),
                  ),
                  const GoogleBillingStatus(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('no purchase before recoverable Google profile', (tester) async {
    final billing = FakeBilling(MobileAccount()..id = 'android:1');
    await mount(tester, billing, 'pack_s');
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Link Google'), findsOneWidget);
    expect(billing.launched, 0);
  });
  testWidgets(
    'real price and renewal disclosed; cancel never launches billing',
    (tester) async {
      final billing = FakeBilling(
        MobileAccount()
          ..id = 'android:1'
          ..googleLinked = true,
      );
      await mount(tester, billing, 'plus_weekly');
      await tester.tap(find.text('Buy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('USD 2.34 per week'), findsOneWidget);
      expect(
        find.textContaining('Renews automatically every week'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(billing.launched, 0);
      await tester.tap(find.text('Buy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to Google Play'));
      await tester.pumpAndSettle();
      expect(billing.launched, 1);
    },
  );
  testWidgets('connection failure warns against duplicate purchase', (
    tester,
  ) async {
    final billing = FakeBilling(MobileAccount())
      ..error = 'verification_pending';
    await mount(tester, billing, 'pack_s');
    expect(find.textContaining('Do not buy again'), findsOneWidget);
    expect(billing.launched, 0);
  });
  testWidgets('failed checkout does not claim a purchase awaits restoration', (
    tester,
  ) async {
    final billing = FakeBilling(MobileAccount())..error = 'purchase_failed';
    await mount(tester, billing, 'pack_s');
    expect(
      find.text('Could not complete payment in Google Play.'),
      findsOneWidget,
    );
    expect(find.textContaining('then restore purchases'), findsNothing);
    expect(billing.launched, 0);
  });
}
