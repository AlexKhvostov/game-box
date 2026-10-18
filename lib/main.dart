import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/android_audience_startup.dart';
import 'app/app_target.dart';
import 'app/mobile_gameplay_tuning.dart';
import 'app/test_tools.dart';
import 'data/economy_store.dart';
import 'data/ads_service.dart';
import 'data/audience_policy.dart';
import 'data/yandex_ads_driver.dart';
import 'data/player_preferences.dart';
import 'data/supabase_mobile_client.dart';
import 'data/android_firebase_config.dart';
import 'data/shared_config_loader.dart';
import 'data/scores_store.dart';
import 'data/mobile_account.dart';
import 'data/mobile_invites.dart';
import 'data/android_invite_source.dart';
import 'data/mobile_connection.dart';
import 'data/mobile_wallet_bridge.dart';
import 'data/play_billing_service.dart';
import 'telegram/telegram_bridge.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
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

      final audience = AudiencePolicy();
      await audience.load();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        runApp(
          ChangeNotifierProvider.value(
            value: audience,
            child: AndroidAudienceStartup(
              startGame: () => _createGame(audience),
            ),
          ),
        );
      } else {
        runApp(await _createGame(audience));
      }
    },
    (error, stack) {
      debugPrint('Uncaught zone error: $error\n$stack');
    },
  );
}

Future<Widget> _createGame(AudiencePolicy audience) async {
  final useSupabase =
      !kIsWeb &&
      AppTargetConfig.isMobile &&
      defaultTargetPlatform == TargetPlatform.android &&
      !TestTools.enabled;
  final remote = useSupabase
      ? await AndroidFirebaseConfig.load()
      : await SharedConfigLoader.load();
  final backendStoragePrefix = useSupabase
      ? SupabaseMobileClient.storagePrefix
      : TestTools.storagePrefix;
  final economyConfig = remote.economy;
  final phonePace = !kIsWeb && AppTargetConfig.isMobile;
  final gameplayConfig = phonePace
      ? MobileGameplayTuning.apply(remote.gameplay)
      : remote.gameplay;
  if (phonePace) {
    debugPrint(
      'Mobile enemy pace: '
      'speed=${gameplayConfig.speedMin.toStringAsFixed(1)}-'
      '${gameplayConfig.speedMax.toStringAsFixed(1)}, '
      'accel=${gameplayConfig.accelMin.toStringAsFixed(1)}-'
      '${gameplayConfig.accelMax.toStringAsFixed(1)}, '
      'startSteps=${gameplayConfig.mobileEnemies.startSpeedSteps}, '
      'accelerationSteps=${gameplayConfig.mobileEnemies.accelerationSteps}',
    );
  }
  final forceLocale = remote.forceLocale;
  debugPrint(
    'Economy RC: timedBonus=${economyConfig.timedBonusTokens}, '
    'daily=${economyConfig.dailyRewardTokens}, '
    'earn=${economyConfig.earnActions.map((e) => e.id).join(',')}, '
    'configSource=${remote.source}, revision=${remote.revision}',
  );

  final economy = EconomyStore(
    config: economyConfig,
    storagePrefix: backendStoragePrefix,
    serverEnergyRequired: useSupabase,
  );
  await economy.load();
  if (TestTools.enabled) {
    debugPrint(
      'Local test wallet: lives=${economy.lives}, tokens=${economy.tokens}',
    );
  }
  final preferences = PlayerPreferences();
  await preferences.load();

  final account = MobileAccount(
    rulesRevision: remote.revision,
    mayUseOnline: () => !TestTools.enabled,
    storagePrefix: useSupabase ? SupabaseMobileClient.storagePrefix : '',
    client: useSupabase ? SupabaseMobileClient() : null,
    endpoint: useSupabase ? SupabaseMobileClient.endpoint : null,
  );
  final walletBridge = MobileWalletBridge(account, economy);
  if (!TestTools.enabled) await walletBridge.load();
  final billing = PlayBillingService(account);
  unawaited(billing.initialize());
  final scores = ScoresStore(
    account: account,
    storagePrefix: backendStoragePrefix,
    instantEconomy: useSupabase && !TestTools.enabled ? economy : null,
  );
  await scores.loadLocal();

  final invites = MobileInvites(
    account: account,
    source: NativeAndroidInviteSource(),
    enabled:
        !kIsWeb &&
        AppTargetConfig.isMobile &&
        defaultTargetPlatform == TargetPlatform.android &&
        !TestTools.enabled,
    startupResolved: preferences.googleStartupSeen,
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => economy),
      ChangeNotifierProvider(create: (_) => preferences),
      ChangeNotifierProvider.value(value: audience),
      ChangeNotifierProvider(create: (_) => scores),
      ChangeNotifierProvider(create: (_) => account),
      ChangeNotifierProvider<MobileInvites>(
        lazy: false,
        create: (_) => invites..start(),
      ),
      Provider<MobileConnection>(
        lazy: false,
        create: (_) => MobileConnection(
          account: account,
          synchronize: () async {
            if (TestTools.enabled) return;
            if (!account.ready) await account.load();
            if (!account.ready) {
              throw const MobileApiError('connection_failed');
            }
            await account.beforeRound?.call();
            await account.refreshProfile();
            await walletBridge.flush();
            // The age band stays on this device. Only completion is shared
            // so an existing player can manually claim the new task reward.
            if (economy.energyEnabled &&
                audience.band != null &&
                audience.band != AgeBand.unknown &&
                !economy.energyRewardReady('age') &&
                !economy.energyRewardClaimed('age')) {
              await economy.completeEnergyAge();
            }
            // Purchase recovery has its own durable worker. A slow Google
            // verification must not hold the ranking refresh behind it.
            if (PlayBillingService.enabled) {
              unawaited(billing.reconnect().catchError((Object _) {}));
            }
            await scores.load();
            if (!scores.online) {
              throw const MobileApiError('ranking_unavailable');
            }
          },
        )..start(),
        dispose: (_, connection) => connection.dispose(),
      ),
      ChangeNotifierProvider(create: (_) => billing),
      ChangeNotifierProvider(
        create: (_) =>
            AdsService(YandexAdsDriver(audience: audience), audience: audience),
      ),
      Provider.value(value: gameplayConfig),
      Provider.value(value: remote),
    ],
    child: GameBoxApp(forceLocale: forceLocale),
  );
}
