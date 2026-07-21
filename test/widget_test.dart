import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:game_box/app/app.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/local_scores_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Shell shows three tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final economy = EconomyStore();
    await economy.load();
    final scores = LocalScoresStore();
    await scores.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: economy),
          ChangeNotifierProvider.value(value: scores),
        ],
        child: const GameBoxApp(),
      ),
    );

    expect(find.text('GAME BOX'), findsOneWidget);
    expect(find.text('Игра'), findsOneWidget);
    expect(find.text('Рейтинг'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);

    // Снимаем дерево, чтобы отменить Timer в ProfileScreen (IndexedStack).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
