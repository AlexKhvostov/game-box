import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/data/audience_policy.dart';
import 'rewarded_ad_age_flow_test.dart' as fixture;

void main() {
  setUpAll(() async {
    final dir = Platform.environment['AD_GUIDE_FONT_DIR'];
    if (dir == null) return;
    final font = FontLoader('Roboto');
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      font.addFont(
        Future.value(
          ByteData.sublistView(await File('$dir/$name').readAsBytes()),
        ),
      );
    }
    await font.load();
    final icons = Platform.environment['AD_GUIDE_ICON_FONT'];
    if (icons != null) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(await File(icons).readAsBytes())),
          ))
          .load();
    }
  });

  for (final width in [320.0, 360.0, 430.0]) {
    for (final scale in [1.0, 1.4]) {
      testWidgets(
        'compact footer and details remain usable at $width / $scale',
        (t) async {
          t.view.physicalSize = Size(width, 800);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final (policy, _, driver, ops) = await fixture.mount(
            t,
            age: AgeBand.adult18plus,
            scale: scale,
          );
          final footer = find.byKey(const ValueKey('rewarded-ad-disclosure'));
          await t.ensureVisible(footer);
          await t.pumpAndSettle();
          final rect = t.getRect(footer);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(find.textContaining('18+ · Добровольно'), findsNothing);
          expect(find.byType(Checkbox), findsNothing);
          expect(policy.adDataConsent, null);
          expect(driver.calls, 0);
          expect(ops, isEmpty);
          if (const bool.fromEnvironment('AD_GUIDE_CAPTURE')) {
            await saveFrame(t, 'guide-${width.toInt()}-$scale');
          }
          final link = find.byKey(const ValueKey('rewarded-ad-data-info'));
          await t.ensureVisible(link);
          await t.tap(link);
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('rewarded-ad-data-details')),
            findsOneWidget,
          );
          expect(policy.adDataConsent, null);
          if (const bool.fromEnvironment('AD_GUIDE_CAPTURE') &&
              width == 360 &&
              scale == 1) {
            await saveFrame(t, 'details-360');
          }
          await t.tap(find.text('Понятно'));
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('rewarded-ad-data-details')),
            findsNothing,
          );
          expect(t.takeException(), null);
        },
      );
    }
  }
}

Future<void> saveFrame(WidgetTester t, String name) async {
  final boundary =
      fixture.captureKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('output/ad-guide-compact-20261026');
    await dir.create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
