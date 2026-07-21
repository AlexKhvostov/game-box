import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'data/economy_store.dart';
import 'data/local_scores_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final economy = EconomyStore();
  await economy.load();

  final scores = LocalScoresStore();
  await scores.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: scores),
      ],
      child: const GameBoxApp(),
    ),
  );
}
