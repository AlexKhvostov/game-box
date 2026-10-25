// Legacy contract2 regression coverage. The current contract3 surface is
// verified in simple_energy_test.dart; this suite retains historical dialogs.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/data/audience_policy.dart';
import '../legacy/flutter/fixtures/features/balance/legacy_energy_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';

class _Account extends MobileAccount {
  void owner(String value) {
    id = value;
    notifyListeners();
  }
}

class _Billing extends PlayBillingService {
  _Billing(super.account) {
    available = true;
    for (final id in [
      'energy_100_v1',
      'energy_batteries_2_v1',
      'energy_batteries_5_v1',
    ]) {
      products[id] = ProductDetails(
        id: id,
        title: id,
        description: id,
        price: 'USD 3.00',
        rawPrice: 3,
        currencyCode: 'USD',
      );
    }
  }
  int calls = 0, restores = 0;
  @override
  Future<void> buy(String id) async {
    calls++;
  }

  @override
  Future<void> restore() async {
    restores++;
  }

  void status({bool active = false, String? problem}) {
    busy = active;
    error = problem;
    notifyListeners();
  }
}

class _FeedbackEconomy extends EconomyStore {
  _FeedbackEconomy(this.account)
    : super(storagePrefix: 'feedback_confirmation_');
  final _Account account;
  @override
  bool get canSendEnergyFeedback => true;
  Completer<void>? pending;
  final accepted = <String>{};
  @override
  bool energyRewardClaimed(String id) => id == 'feedback'
      ? accepted.contains(account.id)
      : super.energyRewardClaimed(id);
  @override
  Future<void> sendEnergyFeedback(String comment, {int? rating}) async {
    pending = Completer<void>();
    await pending!.future;
  }
}

Future<void> _mount(
  WidgetTester t,
  EconomyStore e,
  _Account account,
  _Billing billing,
  Future<void> Function(BuildContext) open, {
  AudiencePolicy? policy,
}) async {
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<EconomyStore>.value(value: e),
        ChangeNotifierProvider<MobileAccount>.value(value: account),
        ChangeNotifierProvider<PlayBillingService>.value(value: billing),
        if (policy != null) ChangeNotifierProvider.value(value: policy),
      ],
      child: MaterialApp(
        theme: buildGameTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
  testWidgets('Subscription offers display8hours and120/300 per day', (
    t,
  ) async {
    final a = _Account()..id = 'android:1';
    final b = _Billing(a);
    final e = EconomyStore(storagePrefix: 'subscription_eight_hours_');
    await e.load();
    await e.enableEnergyPreview();
    await _mount(t, e, a, b, showLegacyEnergySubscriptionSheet);
    expect(find.text('за 8 часов'), findsNWidgets(2));
    expect(find.text('до 120 за сутки'), findsOneWidget);
    expect(find.text('до 300 за сутки'), findsOneWidget);
    expect(find.textContaining('каждые 12 часов'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    e.dispose();
    b.dispose();
    a.dispose();
  });
  for (final check in ['comparable prices', 'remote proportional scale']) {
    testWidgets('Energy packages: $check', (t) async {
      final a = _Account()
        ..id = 'android:1'
        ..googleLinked = true;
      final b = _Billing(a)..products.clear();
      final e = EconomyStore(storagePrefix: 'energy_price_comparison_');
      await e.load();
      await e.enableEnergyPreview();
      final config = e.energyConfig.toJson();
      config['packages'] = [
        {'id': 'energy_200_v2', 'amount': 200},
        {'id': 'energy_500_v2', 'amount': 500},
        {'id': 'energy_1000_v2', 'amount': 1000},
        {'id': 'energy_2000_v2', 'amount': 2000},
      ];
      final now = DateTime.now().millisecondsSinceEpoch;
      await e.applyServerWallet(
        {
          'energyVersion': 2,
          'energy': 47,
          'energyConfig': config,
          'batteries': [
            {
              'id': 'free',
              'startedAt': now,
              'capacity': 20,
              'durationMs': 43200000,
              'initialUnits': 19,
            },
          ],
          'claimed': <String>[],
          'unlocked': <String>[],
        },
        owner: a.id,
        serverNow: now,
      );
      for (final row in [
        ('energy_200_v2', 2.0, 'USD', r'$'),
        ('energy_500_v2', 4.0, 'USD', r'$'),
        ('energy_1000_v2', 6.0, 'EUR', '€'),
        ('energy_2000_v2', 9.0, 'USD', r'$'),
      ]) {
        b.products[row.$1] = ProductDetails(
          id: row.$1,
          title: row.$1,
          description: 'Test',
          price: '${row.$4}${row.$2}',
          rawPrice: row.$2,
          currencyCode: row.$3,
          currencySymbol: row.$4,
        );
      }
      await _mount(t, e, a, b, (c) => showLegacyEnergySheet(c, initialTab: 3));
      if (check == 'comparable prices') {
        final comparison = t.widget<Text>(
          find.byKey(const ValueKey('energy-before-energy_500_v2')),
        );
        expect(comparison.data!.replaceAll(RegExp(r'[\s\u00A0]'), ''), r'5$');
        expect(comparison.style!.decoration, TextDecoration.lineThrough);
        expect(comparison.semanticsLabel, contains('базового пакета'));
        final currentFinder = find.byKey(
          const ValueKey('energy-current-price-energy_500_v2'),
        );
        final previousRect = t.getRect(
          find.byKey(const ValueKey('energy-before-energy_500_v2')),
        );
        final currentRect = t.getRect(currentFinder);
        expect(
          previousRect.bottom,
          lessThanOrEqualTo(currentRect.top),
          reason: 'Base comparison price is above the current price',
        );
        expect(
          (previousRect.center.dx - currentRect.center.dx).abs(),
          lessThan(1),
          reason: 'Both prices share a centered axis',
        );
        final current = t.widget<Text>(currentFinder);
        expect(
          comparison.style!.fontSize!,
          greaterThanOrEqualTo(current.style!.fontSize! * .9),
          reason:
              'Comparison price is approximately as large as the current price',
        );

        expect(
          find.byKey(const ValueKey('energy-before-energy_200_v2')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('energy-before-energy_1000_v2')),
          findsNothing,
          reason: 'Different currencies must not be compared',
        );
        final maxComparison = t.widget<Text>(
          find.byKey(const ValueKey('energy-before-energy_2000_v2')),
        );
        expect(
          maxComparison.data!.replaceAll(RegExp(r'[\s\u00A0]'), ''),
          r'20$',
        );
      } else {
        final firstFill = t.widget<FractionallySizedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('energy-pack-energy_200_v2')),
            matching: find.byType(FractionallySizedBox),
          ),
        );
        final largestFill = t.widget<FractionallySizedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('energy-pack-energy_2000_v2')),
            matching: find.byType(FractionallySizedBox),
          ),
        );
        expect(firstFill.widthFactor, .1);
        expect(largestFill.widthFactor, 1);
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      e.dispose();
    });
  }
  for (final count in [2, 5]) {
    testWidgets(
      'Subscription $count replacement has accurate terms and cancel is free',
      (t) async {
        final a = _Account()
          ..id = 'android:1'
          ..googleLinked = true;
        final b = _Billing(a);
        final e = EconomyStore(storagePrefix: 'subscription_terms_');
        await e.load();
        await e.enableEnergyPreview(batteryCount: count);
        await _mount(t, e, a, b, showLegacyEnergySubscriptionSheet);
        final key = ValueKey('energy-subscribe-${count == 2 ? 4 : 1}');
        await t.ensureVisible(find.byKey(key));
        await t.tap(find.byKey(key));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('energy-purchase-terms')),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            count == 2
                ? 'Google рассчитает доплату'
                : 'со следующего оплаченного периода',
          ),
          findsOneWidget,
        );
        await t.ensureVisible(find.text('Отмена'));
        await t.tap(find.text('Отмена'));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('energy-purchase-confirm')),
          findsNothing,
        );
        expect(b.calls, 0);
        await t.pumpWidget(const SizedBox.shrink());
        e.dispose();
        b.dispose();
        a.dispose();
      },
    );
  }
  testWidgets('Purchase keeps age admission and guest recovery before Play', (
    t,
  ) async {
    final a = _Account()..id = 'android:1';
    final b = _Billing(a);
    final e = EconomyStore(storagePrefix: 'purchase_gate_');
    await e.load();
    await e.enableEnergyPreview();
    final policy = AudiencePolicy();
    await policy.load();
    await _mount(
      t,
      e,
      a,
      b,
      (c) => showEnergyPurchaseSheet(c, 'energy_100_v1', 100),
      policy: policy,
    );
    expect(find.byKey(const ValueKey('age-group-list')), findsOneWidget);
    expect(b.calls, 0);
    await t.tap(find.byKey(const ValueKey('age-cancel')));
    await t.pumpAndSettle();
    expect(b.calls, 0);
    await policy.select(AgeBand.age6to8);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Google для покупок'), findsOneWidget);
    expect(find.byKey(const ValueKey('energy-purchase-confirm')), findsNothing);
    expect(b.calls, 0);
    await t.pumpWidget(const SizedBox.shrink());
    e.dispose();
    b.dispose();
    a.dispose();
    policy.dispose();
  });
  testWidgets(
    'Late billing status stays in reserved panel and restore is explicit',
    (t) async {
      final a = _Account()
        ..id = 'android:1'
        ..googleLinked = true;
      final b = _Billing(a);
      final e = EconomyStore(storagePrefix: 'billing_status_');
      await e.load();
      await e.enableEnergyPreview();
      await _mount(t, e, a, b, (c) => showLegacyEnergySheet(c, initialTab: 3));
      final sheet = t.getRect(find.byKey(const ValueKey('energy-sheet')));
      final status = t.getRect(
        find.byKey(const ValueKey('energy-billing-status')).first,
      );
      b.status(active: true);
      await t.pump();
      expect(find.textContaining('Покупка обрабатывается'), findsOneWidget);
      b.status(problem: 'purchase_failed');
      await t.pump();
      expect(
        find.text('Не удалось завершить оплату в Google Play.'),
        findsOneWidget,
      );
      expect(find.textContaining('Восстановите её'), findsNothing);
      b.status(problem: 'verification_pending');
      await t.pump();
      expect(find.textContaining('Не оплачивайте повторно'), findsOneWidget);
      expect(t.getRect(find.byKey(const ValueKey('energy-sheet'))), sheet);
      expect(
        t.getRect(find.byKey(const ValueKey('energy-billing-status')).first),
        status,
      );
      await t.tap(find.byKey(const ValueKey('energy-billing-restore')).first);
      await t.pumpAndSettle();
      expect(b.restores, 1);
      await t.pumpWidget(const SizedBox.shrink());
      e.dispose();
      b.dispose();
      a.dispose();
    },
  );
  testWidgets(
    'Subscription reconciliation freezes paid charge and disables collection',
    (t) async {
      var now = DateTime.utc(2026, 10, 15, 12);
      final a = _Account()
        ..id = 'android:1'
        ..googleLinked = true;
      final b = _Billing(a);
      final e = EconomyStore(
        storagePrefix: 'pending_subscription_',
        now: () => now,
      );
      await e.load();
      final started = now
          .subtract(const Duration(hours: 7))
          .millisecondsSinceEpoch;
      final until = now
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      Map<String, dynamic> wallet(bool pending) => {
        'energyVersion': 2,
        'energy': 47,
        'energyConfig': {'enabled': true},
        'batteries': [
          {
            'id': 'free',
            'capacity': 20,
            'durationMs': 43200000,
            'startedAt': started,
            'initialUnits': 0,
          },
          {
            'id': 'extra_1',
            'capacity': 20,
            'durationMs': 43200000,
            'startedAt': started,
            'initialUnits': 0,
          },
        ],
        'energySubscription': {
          'productId': 'energy_batteries_2_v1',
          'expiresAt': pending
              ? until
              : now.add(const Duration(days: 7)).millisecondsSinceEpoch,
          'awaitingReconciliation': pending,
        },
        'claimed': <String>[],
        'unlocked': <String>[],
      };
      await e.applyServerWallet(
        wallet(true),
        owner: a.id,
        serverNow: now.millisecondsSinceEpoch,
      );
      var operations = 0;
      e.sendEnergyOperation = (kind, args) async {
        operations++;
      };
      await _mount(t, e, a, b, (c) => showLegacyEnergySheet(c));
      final bounds = t.getRect(find.byKey(const ValueKey('energy-sheet')));
      expect(find.text('Проверяем подписку'), findsOneWidget);
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const ValueKey('energy-claim')))
            .onPressed,
        isNull,
      );
      final paidTile = t.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('energy-battery-1')),
          matching: find.byType(InkWell),
        ),
      );
      expect(
        (paidTile.width - paidTile.height).abs(),
        lessThan(1),
        reason:
            'Two connected batteries retain the same square body as the free battery',
      );
      final paid = e.energyBatteries[1].unitsAt(e.energyNow);
      now = now.add(const Duration(hours: 2));
      await t.pump(const Duration(seconds: 31));
      expect(e.energyBatteries[1].unitsAt(e.energyNow), paid);
      expect(e.energyBatteries[0].unitsAt(e.energyNow), 15);
      expect(operations, 0);
      await t.tap(find.byKey(const ValueKey('energy-charge-restore')));
      await t.pumpAndSettle();
      expect(b.restores, 1);
      await e.applyServerWallet(
        wallet(false),
        owner: a.id,
        serverNow: now.millisecondsSinceEpoch,
      );
      await t.pumpAndSettle();
      expect(find.text('Проверяем подписку'), findsNothing);
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const ValueKey('energy-claim')))
            .onPressed,
        isNotNull,
      );
      expect(t.getRect(find.byKey(const ValueKey('energy-sheet'))), bounds);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      e.dispose();
      b.dispose();
      a.dispose();
    },
  );
  testWidgets('Feedback Future alone and an old owner never display reward', (
    t,
  ) async {
    final a = _Account()..id = 'android:1';
    final b = _Billing(a);
    final e = _FeedbackEconomy(a);
    await e.load();
    await e.enableEnergyPreview();
    await _mount(t, e, a, b, showEnergyFeedbackSheet);
    await t.enterText(
      find.byKey(const ValueKey('energy-feedback-text')),
      'Тест отзыва минимум двадцать символов',
    );
    t.testTextInput.hide();
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('energy-feedback-send')));
    await t.tap(find.byKey(const ValueKey('energy-feedback-send')));
    await t.pump();
    e.pending!.complete();
    await t.pumpAndSettle();
    expect(find.textContaining('Ваш отзыв принят'), findsNothing);
    expect(find.textContaining('Отзыв пока не подтверждён'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('energy-feedback-send')));
    await t.pump();
    a.owner('android:2');
    await t.pump();
    e.accepted.add('android:1');
    e.pending!.complete();
    await t.pumpAndSettle();
    expect(find.textContaining('Ваш отзыв принят'), findsNothing);
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('energy-feedback-text')))
          .controller!
          .text,
      isEmpty,
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    e.dispose();
    b.dispose();
    a.dispose();
  });

  testWidgets('Feedback 19 and 20 characters have distinct disabled visuals', (
    t,
  ) async {
    final a = _Account()..id = 'android:1';
    final b = _Billing(a);
    final e = EconomyStore(storagePrefix: 'feedback_visual_');
    await e.load();
    await e.enableEnergyPreview();
    await e.applyServerWallet({
      'energyVersion': 2,
      'energy': 47,
      'energyConfig': e.energyConfig.toJson(),
      'feedbackSpentEnergy': 100,
      'claimed': <String>[],
    });
    await _mount(t, e, a, b, showEnergyFeedbackSheet);
    await t.enterText(
      find.byKey(const ValueKey('energy-feedback-text')),
      '1234567890123456789',
    );
    t.testTextInput.hide();
    await t.pumpAndSettle();
    final disabled = t.widget<OutlinedButton>(
      find.byKey(const ValueKey('energy-feedback-send')),
    );
    expect(disabled.onPressed, isNull);
    final disabledBorder = disabled.style!.side!.resolve({
      WidgetState.disabled,
    })!.color;
    final disabledBackground = disabled.style!.backgroundColor!.resolve({
      WidgetState.disabled,
    })!;
    await t.enterText(
      find.byKey(const ValueKey('energy-feedback-text')),
      '12345678901234567890',
    );
    t.testTextInput.hide();
    await t.pumpAndSettle();
    final enabled = t.widget<OutlinedButton>(
      find.byKey(const ValueKey('energy-feedback-send')),
    );
    expect(enabled.onPressed, isNotNull);
    final enabledBorder = enabled.style!.side!.resolve({})!.color;
    final enabledBackground = enabled.style!.backgroundColor!.resolve({})!;
    expect(
      disabledBorder.computeLuminance(),
      lessThan(enabledBorder.computeLuminance()),
    );
    expect(disabledBackground, isNot(enabledBackground));
    await t.pumpWidget(const SizedBox.shrink());
    e.dispose();
    b.dispose();
    a.dispose();
  });
}
