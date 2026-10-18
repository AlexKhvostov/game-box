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
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_viewport.dart';

const boundary = ValueKey('compact-shop-capture');
Future<EconomyStore> open(
  WidgetTester tester,
  Size size,
  String lang,
  double scale, {
  int tab = 1,
  bool claimed = false,
}) async {
  await tester.pumpWidget(const SizedBox());
  SharedPreferences.setMockInitialValues({});
  final economy = EconomyStore(now: () => DateTime(2026, 10, 13, 18));
  await economy.load();
  economy.tokens = 999;
  if (claimed) {
    economy.lastTimedBonusClaimAt = DateTime(2026, 10, 13, 18);
    economy.lastDailyClaimAt = DateTime(2026, 10, 13, 18);
    economy.dailyStreak = 2;
  }
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: economy,
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildGameTheme(),
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: GameViewport(child: child!),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCrystalsSheet(context, initialTab: tab),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return economy;
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('COMPACT_SHOP_VISUAL_QA')) return;
  final render = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundary),
  );
  await tester.runAsync(() async {
    final image = await render.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/release-evidence/shop-compact-20261013/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('COMPACT_SHOP_VISUAL_QA')) return;
    for (final font in {
      'Roboto': 'C:/Windows/Fonts/segoeui.ttf',
      'MaterialIcons':
          'C:/Users/alexe/develop/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(font.key);
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File(font.value).readAsBytes()),
        ),
      );
      await loader.load();
    }
  });
  tearDown(() {
    testerViewReset();
  });
  for (final lang in ['ru', 'en']) {
    for (final size in [
      const Size(390, 844),
      const Size(360, 770),
      const Size(320, 480),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('four packs fully inside $lang $size font$scale', (
          tester,
        ) async {
          final economy = await open(tester, size, lang, scale);
          final area = tester.getRect(
            find.byKey(const ValueKey('shop-tab-content')),
          );
          for (final id in ['pack_s', 'pack_m', 'pack_l', 'pack_xl']) {
            final card = tester.getRect(
              find.byKey(ValueKey('crystal-package-$id')),
            );
            expect(card.top, greaterThanOrEqualTo(area.top));
            expect(card.bottom, lessThanOrEqualTo(area.bottom));
            expect(card.height, lessThanOrEqualTo(140));
          }
          final balance = tester.getRect(
            find.byKey(const ValueKey('shop-crystal-balance')),
          );
          final bonus = tester.getRect(
            find.byKey(const ValueKey('shop-gift-material')),
          );
          expect(bonus.height, closeTo(balance.height, .1));
          expect(bonus.left - balance.right, greaterThanOrEqualTo(9));
          expect(bonus.width, greaterThan(balance.width * .7));
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            'packs-$lang-${size.width.toInt()}-font${scale.toInt()}',
          );
          await tester.pumpWidget(const SizedBox());
          economy.dispose();
        });
      }
    }
    for (final claimed in [false, true]) {
      testWidgets('compact daily $lang claimed$claimed', (tester) async {
        final economy = await open(
          tester,
          const Size(390, 844),
          lang,
          1,
          tab: 0,
          claimed: claimed,
        );
        final plus = tester.getRect(
          find.byKey(const ValueKey('daily-plus-card')),
        );
        final row = tester.getRect(find.byKey(const ValueKey('daily-row-1')));
        expect(row.width, lessThanOrEqualTo(plus.width - 15));
        expect(row.height, lessThanOrEqualTo(56));
        expect(tester.takeException(), isNull);
        await capture(tester, 'daily-$lang-${claimed ? "claimed" : "ready"}');
        final before = economy.tokens;
        if (claimed) {
          expect(
            tester
                .widget<FilledButton>(find.byKey(const ValueKey('shop-gift')))
                .onPressed,
            isNull,
          );
        }
        expect(economy.tokens, before);
        await tester.pumpWidget(const SizedBox());
        economy.dispose();
      });
    }
  }
}

void testerViewReset() {
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view.resetPhysicalSize();
  view.resetDevicePixelRatio();
}
