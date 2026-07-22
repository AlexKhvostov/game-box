import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:game_box/app/app.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Hypercasual home shows field hint', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final economy = EconomyStore();
    await economy.load();
    final scores = ScoresStore();
    await scores.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: economy),
          ChangeNotifierProvider.value(value: scores),
          Provider.value(value: const GameplayConfig()),
        ],
        child: const GameBoxApp(forceLocale: 'en'),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Tap anywhere'), findsOneWidget);
    expect(find.text('Игра'), findsNothing);
    expect(find.text('Баланс'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
