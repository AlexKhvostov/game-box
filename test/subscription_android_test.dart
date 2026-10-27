import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/ad_formats_config.dart';
import 'package:game_box/domain/android_energy.dart';
import 'package:game_box/domain/energy_test_catalog.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'package:game_box/features/balance/subscription_offer_presentation.dart';
import 'simple_energy_test.dart' as fixture;

void main() {
  test(
    '25% comparison uses same-duration, same-currency live prices; no invented discount',
    () {
      const offers = AndroidEnergyConfig.defaultSubscriptions;
      final prices = <String, EnergyOfferPrice>{
        offers[0].id: const EnergyOfferPrice(
          price: r'$1',
          rawPrice: 1,
          currencyCode: 'USD',
          currencySymbol: r'$',
        ),
        offers[1].id: const EnergyOfferPrice(
          price: r'$3',
          rawPrice: 3,
          currencyCode: 'USD',
          currencySymbol: r'$',
        ),
      };
      SubscriptionSaving? saving() => subscriptionSaving(
        offer: offers[1],
        offers: offers,
        priceFor: (id) => prices[id],
        locale: 'en_US',
      );
      expect(saving()?.percent, 25);
      expect(saving()?.comparisonPrice, r'$4.00');
      expect(
        subscriptionSaving(
          offer: offers[0],
          offers: offers,
          priceFor: (id) => prices[id],
          locale: 'en',
        ),
        isNull,
      );
      prices[offers[1].id] = const EnergyOfferPrice(
        price: '€3',
        rawPrice: 3,
        currencyCode: 'EUR',
        currencySymbol: '€',
      );
      expect(saving(), isNull);
      prices.remove(offers[0].id);
      expect(saving(), isNull);
    },
  );
  test(
    'all16 format/history cases and persistence; unknown config never promises ad removal',
    () async {
      final e = await fixture.store();
      await e.recordUnrequestedAdShown(banner: false);
      expect(e.subscriptionBlocksSeenAds, false);
      for (final auto in [false, true]) {
        for (final banner in [false, true]) {
          for (final autoSeen in [false, true]) {
            for (final bannerSeen in [false, true]) {
              e.automaticAdSeen = autoSeen;
              e.bannerAdSeen = bannerSeen;
              e.applyAdvertising(
                AdFormatsConfig(
                  automatic: AutomaticFormatConfig(enabled: auto),
                  banner: BannerFormatConfig(enabled: banner),
                ),
              );
              expect(
                e.subscriptionBlocksSeenAds,
                (auto && autoSeen) || (banner && bannerSeen),
              );
            }
          }
        }
      }
      e.automaticAdSeen = false;
      e.bannerAdSeen = false;
      await e.recordUnrequestedAdShown(banner: false);
      await e.recordUnrequestedAdShown(banner: true);
      final copy = EconomyStore(storagePrefix: 'simple_tests_');
      await copy.load();
      expect(copy.automaticAdSeen, true);
      expect(copy.bannerAdSeen, true);
      copy.dispose();
      e.dispose();
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(360, 740),
    const Size(430, 900),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'E02 side by side at${size.width}/font$scale keeps live data, choice and billing price',
        (t) async {
          final e = await fixture.store();
          final account = MobileAccount();
          final billing = PlayBillingService(account);
          for (final pair in [
            ('energy_batteries_2_v1', 1.0),
            ('energy_batteries_5_v1', 3.0),
          ]) {
            billing.products[pair.$1] = ProductDetails(
              id: pair.$1,
              title: pair.$1,
              description: 'fixture',
              price: '\$${pair.$2.toInt()}',
              rawPrice: pair.$2,
              currencyCode: 'USD',
              currencySymbol: r'$',
            );
          }
          await t.binding.setSurfaceSize(size);
          await t.pumpWidget(
            ChangeNotifierProvider<PlayBillingService>.value(
              value: billing,
              child: fixture.app(
                e,
                page: EnergyPage.subscription,
                scale: scale,
              ),
            ),
          );
          await t.tap(find.text('open'));
          await t.pumpAndSettle();
          expect(find.text('Подписка'), findsOneWidget);
          expect(find.text('30'), findsNWidgets(2));
          expect(find.text('60 энергии'), findsOneWidget);
          expect(find.text('150 энергии'), findsOneWidget);
          expect(find.text('До 180 энергии'), findsOneWidget);
          expect(find.text('До 450 энергии'), findsOneWidget);
          final a = t.getRect(find.byKey(const ValueKey('simple-tier-2'))),
              b = t.getRect(find.byKey(const ValueKey('simple-tier-5')));
          expect(a.top, closeTo(b.top, .1));
          expect(a.width, closeTo(b.width, .1));
          expect(a.height, closeTo(b.height, .1));
          expect(
            find.byKey(const ValueKey('subscription-ad-benefit')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('subscription-discount-5')),
            findsOneWidget,
          );
          await t.ensureVisible(find.byKey(const ValueKey('simple-tier-2')));
          await t.tap(find.byKey(const ValueKey('simple-tier-2')));
          await t.pumpAndSettle();
          final button = find.descendant(
            of: find.byKey(const ValueKey('simple-subscribe')),
            matching: find.byType(Text),
          );
          expect(
            button
                .evaluate()
                .map(
                  (x) =>
                      (x.widget as Text).textSpan?.toPlainText() ??
                      (x.widget as Text).data,
                )
                .join(' '),
            contains(r'$1'),
          );
          expect(e.energy, 50);
          expect(e.energyTier, 1);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          billing.dispose();
          account.dispose();
          e.dispose();
          await t.binding.setSurfaceSize(null);
        },
      );
    }
  }
  testWidgets('base circle follows live bonus policy instead of a fixed30', (
    t,
  ) async {
    final e = await fixture.store();
    final wallet = fixture.simpleWallet();
    (wallet['simpleBonus'] as Map<String, dynamic>)['policy'] = {
      'reward': 40,
      'tier2Reward': 80,
      'tier5Reward': 200,
      'periodSec': 28800,
    };
    await e.applyServerWallet(
      wallet,
      serverNow: fixture.stamp,
      owner: 'android:1',
    );
    await t.pumpWidget(fixture.app(e, page: EnergyPage.subscription));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('40'), findsNWidgets(2));
    expect(find.text('80 энергии'), findsOneWidget);
    expect(find.text('200 энергии'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    e.dispose();
  });
  testWidgets(
    'enabled shown format exposes common shield; off removes it; owned retains management',
    (t) async {
      final e = await fixture.store(tier: 5);
      await e.recordUnrequestedAdShown(banner: true);
      e.applyAdvertising(
        const AdFormatsConfig(banner: BannerFormatConfig(enabled: true)),
      );
      await t.pumpWidget(fixture.app(e, page: EnergyPage.subscription));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('subscription-ad-benefit')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('subscription-cta-shield')),
        findsOneWidget,
      );
      expect(find.textContaining('Видео за энергию'), findsNothing);
      expect(find.text('Управлять'), findsOneWidget);
      expect(find.text('Восстановить покупки'), findsOneWidget);
      e.applyAdvertising(
        const AdFormatsConfig(automatic: AutomaticFormatConfig(enabled: false)),
      );
      await t.pump();
      expect(
        find.byKey(const ValueKey('subscription-ad-benefit')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('subscription-cta-shield')),
        findsNothing,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      e.dispose();
    },
  );
}
