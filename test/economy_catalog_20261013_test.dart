import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/domain/economy_config.dart';
import 'package:game_box/domain/shop_catalog.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/game/lives_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_viewport.dart';
import 'package:game_box/ui/life_balance_card.dart';

EconomyConfig approved() => EconomyConfig.fromJson(
  (jsonDecode(File('assets/config/published-gameplay.json').readAsStringSync())
          as Map)['config']['economy']
      as Map<String, dynamic>,
);

class ShopPriceFixture extends PlayBillingService {
  ShopPriceFixture(super.account);
  @override
  String? price(String id) => 'EUR 2.34';
}

const root = ValueKey('economy-qa-root');
Future<EconomyStore> mount(
  WidgetTester tester, {
  String lang = 'ru',
  Size size = const Size(390, 844),
  String screen = 'lives',
  bool livePrice = false,
}) async {
  await tester.pumpWidget(const SizedBox());
  SharedPreferences.setMockInitialValues({});
  final economy = EconomyStore(config: approved());
  await economy.load();
  economy.lives = 999;
  economy.tokens = 100;
  final account = MobileAccount()
    ..id = 'android:999'
    ..nickname = 'Fixture'
    ..googleLinked = true;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: account),
        if (livePrice)
          ChangeNotifierProvider<PlayBillingService>.value(
            value: ShopPriceFixture(account),
          ),
      ],
      child: RepaintBoundary(
        key: root,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildGameTheme(),
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: GameViewport(child: child!),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => screen == 'lives'
                      ? showLivesSheet(context)
                      : showCrystalsSheet(context, initialTab: 1),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  if (screen == 'lives') {
    final context = tester.element(
      find.byKey(const ValueKey('lives-inventory')),
    );
    final image = ResizeImage.resizeIfNeeded(
      (MediaQuery.sizeOf(context).width *
              MediaQuery.devicePixelRatioOf(context))
          .ceil(),
      null,
      const AssetImage('assets/branding/ui/lives-room-v2.png'),
    );
    await tester.runAsync(() => precacheImage(image, context));
    await tester.pumpAndSettle();
  }
  return economy;
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('ECONOMY_VISUAL_QA')) return;
  final render = tester.renderObject<RenderRepaintBoundary>(find.byKey(root));
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/release-evidence/economy-20261013/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
  setUpAll(() async {
    if (!const bool.fromEnvironment('ECONOMY_VISUAL_QA')) return;
    for (final font in {
      'Roboto': 'C:/Windows/Fonts/segoeui.ttf',
      'MaterialIcons':
          'C:/Users/alexe/develop/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(font.key)
        ..addFont(
          Future.value(
            ByteData.sublistView(await File(font.value).readAsBytes()),
          ),
        );
      await loader.load();
    }
  });
  test(
    'approved constructor, JSON defaults and bundled economics match exact schedule',
    () {
      for (final config in [
        const EconomyConfig(),
        EconomyConfig.fromJson({}),
        approved(),
      ]) {
        expect(
          config.resolvedLifePacks.map((p) => (p.costTokens, p.lives)).toList(),
          [(1, 1), (10, 15), (25, 50), (49, 100)],
        );
        expect(config.dailyRewardTokens, [2, 4, 8, 12, 18, 24, 36]);
        expect(config.timedBonusTokens, 4);
        expect(config.timedBonusHours, 1);
        expect(config.jumpRentalCost, 10);
        expect(config.helmetRentalCost, 10);
        expect(config.jumpRentalMinutes, 10);
        expect(config.helmetRentalMinutes, 10);
        expect(config.jumpRentalHourCost, 20);
        expect(config.helmetRentalHourCost, 20);
        expect(config.jumpRentalHourMinutes, 60);
        expect(config.helmetRentalHourMinutes, 60);
        expect(
          config.earnActions.singleWhere((a) => a.id == 'watch_ad').reward,
          10,
        );
      }
      expect(ShopCatalog.packs.map((p) => (p.usdCents, p.crystals)).toList(), [
        (99, 20),
        (199, 50),
        (399, 200),
        (999, 1000),
      ]);
    },
  );
  test(
    'each life offer debits exact crystals and insufficient balance preserves wallet',
    () async {
      for (final pack in approved().resolvedLifePacks) {
        final store = EconomyStore(config: approved());
        await store.load();
        store.tokens = pack.costTokens;
        store.lives = 8;
        expect(store.buyLifePackOffer(pack), true);
        expect(store.tokens, 0);
        expect(store.lives, 8 + pack.lives);
        expect(store.buyLifePackOffer(pack), false);
        expect(store.tokens, 0);
        expect(store.lives, 8 + pack.lives);
      }
    },
  );
  test('both rentals cost ten/20 and last ten minutes/hour', () async {
    final now = DateTime(2026, 10, 13, 15);
    for (final helmet in [false, true]) {
      for (final hour in [false, true]) {
        SharedPreferences.setMockInitialValues({});
        final store = EconomyStore(config: approved(), now: () => now);
        await store.load();
        store.tokens = 100;
        expect(
          helmet ? store.rentHelmet(hour: hour) : store.rentJump(hour: hour),
          true,
        );
        expect(store.tokens, 100 - (hour ? 20 : 10));
        expect(
          helmet ? store.helmetRentalUntil : store.jumpRentalUntil,
          now.add(Duration(minutes: hour ? 60 : 10)),
        );
      }
    }
  });
  test(
    'seven daily rewards, duplicate rejection, Plus multiplier preserved',
    () async {
      var now = DateTime(2026, 10, 13, 12);
      final store = EconomyStore(config: approved(), now: () => now);
      await store.load();
      for (final amount in [2, 4, 8, 12, 18, 24, 36]) {
        expect(store.claimDaily(), amount);
        expect(store.claimDaily(), isNull);
        now = now.add(const Duration(days: 1));
      }
      expect(store.claimDaily(), 36);
      expect(approved().dailyTokensForStreak(6, premium: true), 72);
    },
  );
  test('new config does not reset an existing saved balance', () async {
    final old = EconomyStore();
    await old.load();
    old.tokens = 77;
    old.lives = 17;
    // Persist using a legitimate local purchase, then reload with the new config.
    old.buyLifePackOffer(const LifePackOffer(lives: 1, costTokens: 1));
    await Future<void>.delayed(Duration.zero);
    final next = EconomyStore(config: approved());
    await next.load();
    expect(next.tokens, 76);
    expect(next.lives, 18);
  });
  for (final lang in ['ru', 'en']) {
    for (final size in [const Size(390, 844), const Size(320, 480)]) {
      testWidgets(
        'vertical life balance left, separate exchange, large font $lang $size',
        (tester) async {
          final economy = await mount(tester, lang: lang, size: size);
          expect(tester.takeException(), isNull);
          final balance = tester.getRect(
            find.byKey(const ValueKey('lives-inventory')),
          );
          final currency = tester.getRect(
            find.byKey(const ValueKey('lives-exchange-currency')),
          );
          expect(balance.width / currency.width, inInclusiveRange(.20, .34));
          expect(balance.height / balance.width, inInclusiveRange(1.0, 1.3));
          expect(balance.left, lessThan(currency.center.dx));
          expect(currency.top, greaterThan(balance.bottom));
          expect(
            find.byKey(const ValueKey('lives-heart-pulse')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('lives-balance-amount')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const ValueKey('lives-inventory')));
          await tester.pumpAndSettle();
          expect(economy.lives, 999);
          expect(economy.tokens, 100);
          await capture(tester, 'lives-$lang-${size.width.toInt()}');
          await tester.pumpWidget(const SizedBox());
        },
      );
      testWidgets(
        'four pack cards with exact quantities and prices $lang $size',
        (tester) async {
          await mount(tester, lang: lang, size: size, screen: 'shop');
          expect(tester.takeException(), isNull);
          for (final offer in ShopCatalog.packs) {
            expect(
              find.byKey(ValueKey('crystal-package-${offer.id}')),
              findsOneWidget,
            );
            expect(
              tester
                  .widget<Text>(
                    find.byKey(ValueKey('crystal-pack-amount-${offer.id}')),
                  )
                  .data,
              '${offer.crystals}',
            );
            expect(
              tester
                  .widget<Text>(
                    find.byKey(ValueKey('crystal-pack-price-${offer.id}')),
                  )
                  .data,
              offer.priceLabel,
            );
          }
          final first = tester.getRect(
            find.byKey(const ValueKey('crystal-package-pack_s')),
          );
          final second = tester.getRect(
            find.byKey(const ValueKey('crystal-package-pack_m')),
          );
          expect(second.top, first.top);
          expect(second.left, greaterThan(first.right));
          await capture(tester, 'packs-$lang-${size.width.toInt()}');
          await tester.ensureVisible(
            find.byKey(const ValueKey('crystal-package-pack_xl')),
          );
          await tester.pumpAndSettle();
          await capture(tester, 'packs-bottom-$lang-${size.width.toInt()}');
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('Google Play localized price takes precedence over planned USD', (
    tester,
  ) async {
    await mount(tester, screen: 'shop', livePrice: true);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('crystal-pack-price-pack_s')))
          .data,
      'EUR 2.34',
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'heart pulses, pauses in background and respects reduced motion',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 115,
              child: LifeBalanceCard(lives: 9),
            ),
          ),
        ),
      );
      final transition = find.byKey(const ValueKey('lives-heart-pulse'));
      double scale() => tester.widget<ScaleTransition>(transition).scale.value;
      await tester.pump(const Duration(milliseconds: 100));
      expect(scale(), greaterThan(1));
      await tester.pump(const Duration(milliseconds: 450));
      expect(scale(), 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 2));
      expect(scale(), 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(scale(), greaterThan(1));
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SizedBox(
              width: 100,
              height: 115,
              child: LifeBalanceCard(lives: 9),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(scale(), 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
