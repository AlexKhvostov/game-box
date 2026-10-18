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
import '../legacy/flutter/fixtures/features/balance/legacy_energy_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use the Android app's Roboto metrics, not the test-only square Ahem font.
    final fonts = File(Platform.resolvedExecutable).parent.parent.parent;
    final loader = FontLoader('Roboto');
    for (final weight in ['regular', 'bold', 'black']) {
      final bytes = await File(
        '${fonts.path}/material_fonts/roboto-$weight.ttf',
      ).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });
  for (final width in [360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final units in [0, 13, 20]) {
        testWidgets(
          'Five readouts remain legible: width$width, font$scale, $units/20',
          (t) async {
            SharedPreferences.setMockInitialValues({});
            final e = EconomyStore(
              storagePrefix: 'five_readability_${scale}_${units}_',
            );
            await e.load();
            await e.enableEnergyPreview(batteryCount: 5, initialUnits: units);
            await t.binding.setSurfaceSize(Size(width, 620));
            addTearDown(() => t.binding.setSurfaceSize(null));
            await t.pumpWidget(
              ChangeNotifierProvider.value(
                value: e,
                child: MaterialApp(
                  theme: buildGameTheme(),
                  locale: const Locale('ru'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c).copyWith(
                      disableAnimations: true,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: width - 24,
                        child: const LegacyEnergySheet(),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            for (var i = 0; i < 5; i++) {
              final tile = find.byKey(ValueKey('energy-battery-$i'));
              final shell = t.getRect(
                find.descendant(of: tile, matching: find.byType(InkWell)),
              );
              for (final entry in [('percent', 14.0), ('amount', 9.0)]) {
                final text = find.descendant(
                  of: tile,
                  matching: find.byKey(
                    ValueKey('energy-battery-compact-${entry.$1}'),
                  ),
                );
                final paragraph = t.renderObject<RenderParagraph>(text);
                final nominal = (paragraph.text as TextSpan).style!.fontSize!;
                final effective =
                    paragraph.textScaler.scale(nominal) *
                    paragraph.getTransformTo(null).getMaxScaleOnAxis();
                expect(
                  effective,
                  greaterThanOrEqualTo(entry.$2),
                  reason:
                      '${entry.$1} must remain readable after every FittedBox: $effective',
                );
                final rect = t.getRect(text);
                expect(shell.contains(rect.topLeft), isTrue);
                expect(shell.contains(rect.bottomRight), isTrue);
              }
            }
            await t.pumpWidget(const SizedBox.shrink());
            e.dispose();
          },
        );
      }
    }
  }
  for (final scenario in [
    ('free', 1, 13),
    ('two', 2, 13),
    ('five', 5, 13),
    ('empty', 1, 0),
    ('full', 1, 20),
  ]) {
    testWidgets('Accumulator shell and live counters: ${scenario.$1}', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final e = EconomyStore(
        storagePrefix: 'accumulator_design_${scenario.$1}_',
      );
      await e.load();
      await e.enableEnergyPreview(
        batteryCount: scenario.$2,
        initialUnits: scenario.$3,
      );
      await t.binding.setSurfaceSize(const Size(390, 620));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final boundary = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ChangeNotifierProvider.value(
            value: e,
            child: MaterialApp(
              theme: buildGameTheme(),
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: const Scaffold(
                backgroundColor: Color(0xFF061B2D),
                body: Center(child: SizedBox(width: 366, child: LegacyEnergySheet())),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('${scenario.$3 * 5}%'), findsNWidgets(scenario.$2));
      expect(e.accumulatedEnergy, scenario.$3 * scenario.$2);
      expect(e.energy, 47);
      for (var i = 0; i < scenario.$2; i++) {
        final tile = find.byKey(ValueKey('energy-battery-$i'));
        final touch = t.getRect(
          find.descendant(of: tile, matching: find.byType(InkWell)),
        );
        expect(touch.width, greaterThan(35));
        expect(touch.height, greaterThan(60));
        if (scenario.$2 <= 2) {
          expect((touch.width - touch.height).abs(), lessThan(1));
        }
        expect(
          find.descendant(of: tile, matching: find.byType(CustomPaint)),
          findsWidgets,
        );
      }
      if (Platform.environment['ENERGY_ACCUMULATOR_RENDER'] == '1') {
        await t.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '.private/energy-accumulator-20261015/render-${scenario.$1}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      if (scenario.$1 == 'free') {
        await t.tap(find.text('Подключить'));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('energy-subscription-dialog')),
          findsOneWidget,
        );
        expect(
          e.energy,
          47,
          reason: 'Opening an inactive shell must not spend or grant energy',
        );
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox.shrink());
      e.dispose();
    });
  }
}
