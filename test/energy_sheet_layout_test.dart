// Legacy contract2 regression coverage. The current contract3 surface is
// verified in simple_energy_test.dart; this suite retains historical dialogs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import '../legacy/flutter/fixtures/features/balance/legacy_energy_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';

void main() {
  for (final size in const [Size(320, 480), Size(390, 568), Size(390, 760)]) {
    for (final textScale in [1.0, 1.2]) {
      testWidgets('Energy tabs keep one geometry $size/$textScale', (t) async {
        SharedPreferences.setMockInitialValues({});
        final economy = EconomyStore(storagePrefix: 'energy_layout_');
        await economy.load();
        await economy.enableEnergyPreview();
        await t.binding.setSurfaceSize(size);
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(
          ChangeNotifierProvider.value(
            value: economy,
            child: MaterialApp(
              theme: buildGameTheme(),
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () => showLegacyEnergySheet(context),
                      child: const Text('open'),
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
        final bounds = t.getRect(find.byKey(const ValueKey('energy-sheet')));
        final content = t.getRect(find.byKey(const ValueKey('energy-content')));
        final header = t.getRect(find.text('Энергия'));
        final balance = t.getRect(find.byKey(const ValueKey('energy-balance')));
        expect(
          (header.center.dy - balance.center.dy).abs(),
          lessThan(8),
          reason: 'Approved header keeps title and wallet side by side',
        );
        expect(find.text('Накоплено'), findsOneWidget);
        for (var tab = 0; tab < 4; tab++) {
          final box = t.getRect(find.byKey(ValueKey('energy-tab-$tab')));
          final label = t.getRect(
            find.byKey(ValueKey('energy-tab-label-$tab')),
          );
          expect(
            (label.center.dx - box.center.dx).abs(),
            lessThan(1),
            reason: 'Tab label is horizontally centered',
          );
          expect(
            (label.center.dy - box.center.dy).abs(),
            lessThan(1),
            reason: 'Tab label is vertically centered independently of FREE',
          );
        }

        for (var i = 1; i < 4; i++) {
          await t.tap(find.byKey(ValueKey('energy-tab-$i')));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          if (i == 1) {
            if (size.height >= 568) {
              expect(
                find.text('Награды сразу пополняют ваш баланс.'),
                findsOneWidget,
              );
            }
            for (final id in [
              'achievements',
              'watch_ad',
              'google',
              'age',
              'feedback',
            ]) {
              final area = t.getRect(find.byKey(ValueKey('energy-task-$id')));
              expect(
                area.height,
                greaterThanOrEqualTo(48),
                reason: '$id real touch area',
              );
            }
          }
          if (i == 2) {
            for (final id in ['code', 'link']) {
              final copy = find.byKey(ValueKey('energy-copy-$id'));
              final touch = t.getRect(copy);
              expect(touch.width, greaterThanOrEqualTo(48));
              expect(touch.height, greaterThanOrEqualTo(48));
              final button = t.widget<IconButton>(copy);
              expect(button.tooltip, 'Копировать');
              final icon = t.getRect(
                find.descendant(of: copy, matching: find.byType(Icon)),
              );
              expect(
                icon.height,
                lessThanOrEqualTo(30),
                reason: 'Copy stays visually compact',
              );
            }
          }
          if (i == 3) {
            final first = t.getRect(
              find.byKey(const ValueKey('energy-pack-energy_100_v1')),
            );
            final second = t.getRect(
              find.byKey(const ValueKey('energy-pack-energy_250_v1')),
            );
            final third = t.getRect(
              find.byKey(const ValueKey('energy-pack-energy_500_v1')),
            );
            expect(
              first.top,
              second.top,
              reason: 'Packs use approved two-column grid',
            );
            expect(third.top, greaterThan(first.bottom));
            for (final id in [
              'energy_100_v1',
              'energy_250_v1',
              'energy_500_v1',
              'energy_1000_v1',
            ]) {
              final area = t.getRect(find.byKey(ValueKey('energy-pack-$id')));
              expect(
                area.height,
                greaterThanOrEqualTo(48),
                reason: '$id whole row touch area',
              );
            }
          }
          expect(t.getRect(find.byKey(const ValueKey('energy-sheet'))), bounds);
          expect(
            t.getRect(find.byKey(const ValueKey('energy-content'))),
            content,
          );
        }
        await t.pumpWidget(const SizedBox.shrink());
        economy.dispose();
      });
    }
  }
  testWidgets('Separate abilities toggle without spending', (t) async {
    SharedPreferences.setMockInitialValues({});
    final e = EconomyStore(storagePrefix: 'energy_ability_');
    await e.load();
    await e.enableEnergyPreview();
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: e,
        child: MaterialApp(
          theme: buildGameTheme(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => showLegacyEnergyAbilitySheet(c, helmet: true),
                child: const Text('helmet'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('helmet'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('energy-helmet-switch')));
    await t.pumpAndSettle();
    expect(e.helmetSelected, isTrue);
    expect(e.energy, 47);
    expect(e.attemptEnergyCost, 2);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    e.dispose();
  });
}
