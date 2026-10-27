import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'simple_energy_test.dart' as fixture;

class _NoAds implements AdsDriver {
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async =>
      throw StateError('Ads must never run in a layout test');
  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async =>
      throw StateError('Ads must never run in a layout test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('D006_CAPTURE')) return;
    for (final family in ['Roboto', 'Ahem']) {
      final font = FontLoader(family);
      for (final weight in ['Regular', 'Bold']) {
        font.addFont(
          Future.value(
            ByteData.sublistView(
              await File(
                'telegram-app/public/fonts/Roboto-$weight.ttf',
              ).readAsBytes(),
            ),
          ),
        );
      }
      await font.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Live quota remains inside ad button at $width/font$scale', (
        t,
      ) async {
        final e = await fixture.store();
        final audience = AudiencePolicy();
        final ads = AdsService(_NoAds(), audience: audience);
        addTearDown(e.dispose);
        addTearDown(ads.dispose);
        addTearDown(audience.dispose);
        await t.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final capture = GlobalKey();
        await t.pumpWidget(
          ChangeNotifierProvider.value(
            value: ads,
            child: RepaintBoundary(
              key: capture,
              child: fixture.app(e, scale: scale),
            ),
          ),
        );
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        Future<void> wallet(
          int used,
          int limit, {
          int? lastAdAt,
          int? resetAt,
        }) async {
          final data = fixture.simpleWallet();
          (data['energyConfig'] as Map)['watchAdDailyLimit'] = limit;
          data['adQuota'] = {
            'used': used,
            'limit': limit,
            'resetAt': resetAt ?? fixture.stamp + 86400000,
          };
          if (lastAdAt != null) data['lastAdAt'] = lastAdAt;
          await e.applyServerWallet(
            data,
            serverNow: fixture.stamp,
            owner: 'android:1',
          );
          await t.pumpAndSettle();
        }

        final button = find.byKey(const ValueKey('simple-energy-video'));
        final count = find.byKey(const ValueKey('ad-quota-count'));
        for (final used in [0, 7, 20]) {
          await wallet(used, 20);
          expect(
            find.descendant(
              of: button,
              matching: find.text('Сегодня · $used/20'),
            ),
            findsOneWidget,
          );
          expect(find.textContaining('Сегодня:'), findsNothing);
          final b = t.getRect(button), c = t.getRect(count);
          final invite = t.getSize(
            find.byKey(const ValueKey('simple-energy-friends')),
          );
          expect(b.width, closeTo(invite.width, .1));
          expect(b.height, closeTo(invite.height, .1));
          expect(b.height, closeTo(44, .01));
          expect(b.contains(c.topLeft), isTrue);
          expect(b.contains(c.bottomRight), isTrue);
          expect(t.widget<NeonAction>(button).onTap == null, used == 20);
          final fill = t.widget<FractionallySizedBox>(
            find.byKey(const ValueKey('ad-quota-fill')),
          );
          expect(fill.widthFactor, used / 20);
          expect(t.takeException(), isNull);
        }
        await wallet(7, 20, lastAdAt: fixture.stamp);
        expect(find.text('Сегодня · 7/20'), findsOneWidget);
        expect(t.widget<NeonAction>(button).onTap, isNull);
        await wallet(2, 5);
        expect(find.text('Сегодня · 2/5'), findsOneWidget);
        ads.busy = true;
        ads.notifyListeners();
        await t.pumpAndSettle();
        expect(
          find.descendant(of: button, matching: find.text('Загрузка…')),
          findsOneWidget,
        );
        expect(find.text('Сегодня · 2/5'), findsOneWidget);
        expect(t.widget<NeonAction>(button).onTap, isNull);
        ads.busy = false;
        ads.notifyListeners();
        await wallet(7, 20, resetAt: fixture.stamp - 1);
        expect(find.text('Сегодня · 0/20'), findsOneWidget);
        await wallet(7, 20);
        if (scale == 1 && const bool.fromEnvironment('D006_CAPTURE')) {
          await t.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final output = Directory(
              'docs/release-evidence/d006-ad-counter-compact-20261025',
            );
            await output.create(recursive: true);
            await File(
              '${output.path}/android-${width.toInt()}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets('English quota and unknown data stay legible', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: Center(
          child: SizedBox(
            width: 100,
            child: AdQuotaButtonContent(action: 'Loading…', enabled: false),
          ),
        ),
      ),
    );
    expect(find.text('Today · —'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
