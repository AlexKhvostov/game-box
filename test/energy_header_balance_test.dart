// Legacy contract2 regression coverage. The current contract3 surface is
// verified in simple_energy_test.dart; this suite retains historical dialogs.
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
import 'package:game_box/features/balance/energy_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use Android's real Roboto metrics rather than test-only Ahem squares.
    final fonts = File(Platform.resolvedExecutable).parent.parent.parent;
    final loader = FontLoader('Roboto');
    for (final weight in ['regular', 'bold', 'black']) {
      final bytes = await File(
        '${fonts.path}/material_fonts/roboto-$weight.ttf',
      ).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    final bytes = await File(
      '${fonts.path}/material_fonts/materialicons-regular.otf',
    ).readAsBytes();
    icons.addFont(Future.value(ByteData.sublistView(bytes)));
    await icons.load();
  });

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final value in [1974, 1988, 99999, 999999]) {
        testWidgets('Energy header $value at $width / font$scale', (t) async {
          SharedPreferences.setMockInitialValues({});
          final e = EconomyStore(storagePrefix: 'header_balance_');
          await e.load();
          await e.enableEnergyPreview(balance: value);
          await t.binding.setSurfaceSize(Size(width, 760));
          addTearDown(() => t.binding.setSurfaceSize(null));
          final boundary = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: ChangeNotifierProvider.value(
                value: e,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildGameTheme(),
                  locale: const Locale('ru'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Builder(
                      builder: (c) => Center(
                        child: TextButton(
                          onPressed: () => showLegacyEnergySheet(c),
                          child: const Text('open'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.tap(find.text('open'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          final header = find.byKey(const ValueKey('energy-balance'));
          final balance = t.getRect(header);
          final fullText = find.descendant(
            of: header,
            matching: find.text('⚡ $value'),
          );
          expect(fullText, findsOneWidget);
          final paragraph = t.renderObject<RenderParagraph>(fullText);
          final matrix = paragraph.getTransformTo(null);
          final painted = MatrixUtils.transformRect(
            matrix,
            Offset.zero & paragraph.size,
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(balance.inflate(.1).contains(painted.topLeft), isTrue);
          expect(balance.inflate(.1).contains(painted.bottomRight), isTrue);
          final text = t.widget<Text>(fullText);
          final effectiveSize =
              paragraph.textScaler.scale(text.style!.fontSize!) *
              matrix.getMaxScaleOnAxis();
          expect(
            effectiveSize,
            greaterThanOrEqualTo(value < 10000 ? 23 : 18),
            reason:
                'Full balance remains readable after real FittedBox scaling',
          );
          expect(balance.width, greaterThan(112));
          expect(balance.height, closeTo(43, .1));
          if (width >= 360) expect(balance.width, closeTo(170, .1));
          final close = t.getRect(find.byKey(const ValueKey('energy-close')));
          expect(balance.right, lessThanOrEqualTo(close.left));
          final title = t.renderObject<RenderParagraph>(find.text('Энергия'));
          expect(title.didExceedMaxLines, isFalse);

          if (Platform.environment['ENERGY_HEADER_RENDER'] == '1' &&
              ((width == 360 && scale == 1 && value == 1974) ||
                  (width == 390 && scale == 1 && value == 1988) ||
                  (width == 320 && scale == 2 && value == 999999))) {
            await t.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 3);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'docs/release-evidence/energy-header-balance-20261015/'
                'widget-$value-${width.toInt()}-font${scale.toInt()}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (width == 360 && scale == 1 && value == 1974) {
            final sheet = t.getRect(find.byKey(const ValueKey('energy-sheet')));
            final content = t.getRect(
              find.byKey(const ValueKey('energy-content')),
            );
            for (var tab = 1; tab < 4; tab++) {
              await t.tap(find.byKey(ValueKey('energy-tab-$tab')));
              await t.pumpAndSettle();
              expect(
                t.getRect(find.byKey(const ValueKey('energy-sheet'))),
                sheet,
              );
              expect(
                t.getRect(find.byKey(const ValueKey('energy-content'))),
                content,
              );
              expect(t.getRect(header), balance);
              expect(t.takeException(), isNull);
            }
          }
          await t.pumpWidget(const SizedBox.shrink());
          e.dispose();
        });
      }
    }
  }
}
