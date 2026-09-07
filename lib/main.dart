import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_target.dart';
import 'data/app_analytics.dart';
import 'data/economy_store.dart';
import 'data/firebase_bootstrap.dart';
import 'data/remote_config_loader.dart';
import 'data/scores_store.dart';
import 'domain/economy_config.dart';
import 'domain/gameplay_config.dart';
import 'telegram/telegram_bridge.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PlatformError: $error\n$stack');
      return true;
    };

    if (AppTargetConfig.isTelegram || kIsWeb) {
      // Жесты игры не должны тянуть шторку Telegram.
      TelegramBridge.bootstrapFullscreen();
    }

    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    final firebaseOk = await FirebaseBootstrap.init();
    if (firebaseOk) {
      await AppAnalytics.init();
      await AppAnalytics.appOpen();
    }

    var economyConfig = const EconomyConfig();
    var gameplayConfig = const GameplayConfig();
    var forceLocale = '';
    if (firebaseOk) {
      final remote = await RemoteConfigLoader.load();
      economyConfig = remote.economy;
      gameplayConfig = remote.gameplay;
      forceLocale = remote.forceLocale;
    }
    debugPrint(
      'Economy RC: timedBonus=${economyConfig.timedBonusTokens}, '
      'daily=${economyConfig.dailyRewardTokens}, '
      'earn=${economyConfig.earnActions.map((e) => e.id).join(',')}, '
      'firebaseOk=$firebaseOk',
    );

    final economy = EconomyStore(config: economyConfig);
    await economy.load();

    final scores = ScoresStore();
    await scores.load();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: economy),
          ChangeNotifierProvider.value(value: scores),
          Provider.value(value: gameplayConfig),
        ],
        child: GameBoxApp(forceLocale: forceLocale),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}
