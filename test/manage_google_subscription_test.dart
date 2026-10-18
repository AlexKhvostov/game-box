import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/domain/energy_test_catalog.dart';
import 'package:game_box/ui/billing_unavailable.dart';

void main() {
  const store = MethodChannel('untouch/store');
  final calls = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(store, (call) async {
          calls.add(call);
          return null;
        });
    calls.clear();
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(store, null);
  });

  Future<void> manage(
    WidgetTester tester,
    Map<String, dynamic>? wallet,
    Map<String, dynamic> expected,
  ) async {
    final account = MobileAccount()..wallet = wallet;
    final billing = PlayBillingService(account, testServicePreview: false);
    await tester.pumpWidget(
      ChangeNotifierProvider<PlayBillingService>.value(
        value: billing,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => manageGoogleSubscription(context),
              child: const Text('Manage'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.single.method, 'manageSubscription');
    expect(calls.single.arguments, expected);
    await tester.pumpWidget(const SizedBox.shrink());
    billing.dispose();
    account.dispose();
  }

  for (final id in ['energy_batteries_5_v1', 'energy_batteries_2_v1']) {
    testWidgets(
      'Manage sends the actual owned $id from the billing wallet',
      (tester) => manage(
        tester,
        {
          'energyVersion': 2,
          'energySubscription': {'productId': id},
          // A newly displayed offer must never replace the owned SKU.
          'energyConfig': {
            'subscriptions': [
              {
                'productId': id == 'energy_batteries_5_v1'
                    ? 'energy_batteries_2_v1'
                    : 'energy_batteries_5_v1',
              },
            ],
          },
        },
        {'productId': id},
      ),
      skip: TestServicePreview.enabled,
    );
  }
  testWidgets(
    'Legacy caller retains Plus management',
    (tester) => manage(tester, {'tokens': 3}, {'productId': 'plus_weekly'}),
    skip: TestServicePreview.enabled,
  );
  testWidgets(
    'Energy wallet without an active subscription opens the general list',
    (tester) => manage(tester, {'energyVersion': 2}, {}),
    skip: TestServicePreview.enabled,
  );
  testWidgets(
    'Missing wallet opens the general list instead of assuming legacy Plus',
    (tester) => manage(tester, null, {}),
    skip: TestServicePreview.enabled,
  );
  for (final unknown in ['unexpected_sku', 'energy_100_v1', 42]) {
    testWidgets(
      'Unknown subscription $unknown opens the general list',
      (tester) => manage(tester, {
        'energyVersion': 2,
        'energySubscription': {'productId': unknown},
      }, {}),
      skip: TestServicePreview.enabled,
    );
  }
}
