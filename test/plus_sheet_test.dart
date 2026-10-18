import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'Plus small-screen offer scrolls and does not invent a store price',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final economy = EconomyStore();
      await economy.load();
      await tester.binding.setSurfaceSize(const Size(320, 560));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: economy,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showPlusSheet(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('PLUS SUBSCRIPTION'), findsOneWidget);
      expect(find.textContaining(r'$1'), findsNothing);
      expect(find.textContaining('Renews weekly'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Restore purchases'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Google Play purchases are not available in this test version yet.',
        ),
        findsOneWidget,
      );
      expect(economy.hasPremium, false);
      expect(economy.tokens, economy.config.initialTokens);
    },
  );
}
