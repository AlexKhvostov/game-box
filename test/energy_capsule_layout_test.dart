import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/energy_widgets.dart';

void main() {
  for (final shape in [
    (112.0, 43.0, false),
    (150.0, 48.0, true),
    (220.0, 30.0, true),
  ]) {
    final home = shape.$3;
    for (final scale in [1.0, 2.0]) {
      for (final value in [0, 47, 99999999]) {
        testWidgets(
          'Energy capsule stays proportional and centered $shape / $scale / $value',
          (t) async {
            await t.pumpWidget(
              MaterialApp(
                theme: buildGameTheme(),
                locale: const Locale('ru'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Center(
                      child: SizedBox(
                        key: const ValueKey('capsule'),
                        width: shape.$1,
                        height: shape.$2,
                        child: EnergyBalanceCapsule(
                          amount: value,
                          showPlus: home,
                          amountKey: const ValueKey('amount'),
                          plusKey: const ValueKey('plus'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            final capsule = t.getRect(find.byKey(const ValueKey('capsule')));
            final amount = t.getRect(find.byKey(const ValueKey('amount')));
            expect((amount.center.dx - capsule.center.dx).abs(), lessThan(.5));
            expect(capsule.contains(amount.topLeft), isTrue);
            expect(capsule.contains(amount.bottomRight), isTrue);
            expect(find.text('Ваш баланс'), findsNothing);
            expect(find.text('Your balance'), findsNothing);
            expect(find.textContaining('%'), findsNothing);
            if (home) {
              final plus = t.getRect(find.byKey(const ValueKey('plus')));
              final disc = t.getRect(
                find.byKey(const ValueKey('energy-capsule-plus-disc')),
              );
              expect(
                disc.width,
                closeTo(disc.height, .01),
                reason:
                    'The plus rim is a physical circle at every aspect ratio',
              );
              expect(capsule.contains(disc.topLeft), isTrue);
              expect(capsule.contains(disc.bottomRight), isTrue);
              expect(capsule.contains(plus.topLeft), isTrue);
              expect(capsule.contains(plus.bottomRight), isTrue);
              expect(amount.right, lessThanOrEqualTo(plus.left));
            } else {
              expect(find.byKey(const ValueKey('plus')), findsNothing);
            }
            expect(t.takeException(), isNull);
          },
        );
      }
    }
  }
}
