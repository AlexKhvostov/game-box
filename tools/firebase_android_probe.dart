// Physical Android acceptance against local Firebase Auth/Functions/Firestore.
// This entrypoint is built ONLY into com.best4u.untouch.uiprobe.firebase.
// It contains no fake wallet, fake price or in-process backend replacement.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/mobile_gameplay_tuning.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/android_firebase_config.dart';
import 'package:game_box/data/firebase_mobile_client.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/data/android_invite_source.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/yandex_ads_driver.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_home_screen.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_viewport.dart';

late EconomyStore economy;
late MobileAccount account;
late MobileWalletBridge bridge;
late ScoresStore scores;
final errors = <String>[];
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const String.fromEnvironment('FIREBASE_AUTH_EMULATOR_HOST').isEmpty) {
    throw StateError(
      'Physical Firebase probe requires emulator; never production',
    );
  }
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
    FlutterError.presentError(details);
  };
  final config = await AndroidFirebaseConfig.load();
  final prefs = PlayerPreferences();
  await prefs.load();
  await prefs.setSound(false);
  await prefs.setMusic(false);
  await prefs.markGoogleStartupSeen();
  final audience = AudiencePolicy();
  await audience.load();
  economy = EconomyStore(
    config: config.economy,
    storagePrefix: FirebaseMobileClient.storagePrefix,
    serverEnergyRequired: true,
  );
  await economy.load();
  account = MobileAccount(
    storagePrefix: FirebaseMobileClient.storagePrefix,
    client: FirebaseMobileClient(),
    endpoint: FirebaseMobileClient.endpoint,
    rulesRevision: config.revision,
  );
  bridge = MobileWalletBridge(account, economy);
  await bridge.load();
  await account.load();
  if (!account.ready) {
    throw StateError('Firebase probe startup: ${account.error}');
  }
  await bridge.flush();
  scores = ScoresStore(
    account: account,
    storagePrefix: FirebaseMobileClient.storagePrefix,
  );
  await scores.loadLocal();
  await scores.load();
  final invites = MobileInvites(
    account: account,
    source: NativeAndroidInviteSource(),
    startupResolved: true,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: account),
        ChangeNotifierProvider.value(value: scores),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider.value(value: audience),
        ChangeNotifierProvider.value(value: invites),
        ChangeNotifierProvider(create: (_) => PlayBillingService(account)),
        ChangeNotifierProvider(
          create: (_) => AdsService(
            YandexAdsDriver(audience: audience),
            audience: audience,
          ),
        ),
        Provider<GameplayConfig>.value(
          value: MobileGameplayTuning.apply(config.gameplay),
        ),
        Provider<SharedConfigs>.value(value: config),
      ],
      child: const ProbeApp(),
    ),
  );
}

class ProbeApp extends StatefulWidget {
  const ProbeApp({super.key});
  @override
  State<ProbeApp> createState() => _ProbeState();
}

class _ProbeState extends State<ProbeApp> {
  final navigator = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    unawaited(serve());
  }

  Future<void> serve() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8898);
    await for (final request in server) {
      try {
        if (request.uri.path == '/energy') {
          final windowContext = navigator.currentState!.overlay!.context;
          if (!windowContext.mounted) {
            throw StateError('Probe window unavailable');
          }
          unawaited(showSimpleEnergyWindow(windowContext));
          await Future<void>.delayed(const Duration(milliseconds: 500));
        } else if (request.uri.path == '/sync') {
          await account.refreshProfile();
          await bridge.flush();
          await scores.load();
        }
        final rects = <String, Map<String, double>>{},
            texts = <String>[],
            game = <String, dynamic>{};
        void visit(Element element) {
          final widget = element.widget;
          if (widget is Text && widget.data != null) texts.add(widget.data!);
          if (widget is ArcadeHud) {
            game.addAll({
              'playing': widget.isPlaying,
              'timeMs': widget.timeMs(),
            });
          }
          final key = widget.key;
          if (key is ValueKey<String>) {
            final box = element.findRenderObject();
            if (box is RenderBox && box.hasSize && box.attached) {
              final ratio = View.of(element).devicePixelRatio,
                  origin = box.localToGlobal(Offset.zero) * ratio;
              rects[key.value] = {
                'left': origin.dx,
                'top': origin.dy,
                'width': box.size.width * ratio,
                'height': box.size.height * ratio,
              };
            }
          }
          element.visitChildElements(visit);
        }

        visit(navigator.currentContext! as Element);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'backend': 'local-firebase-emulators',
            'errors': errors,
            'owner': account.id,
            'energy': economy.energy,
            'confirmedEnergy': economy.confirmedEnergy,
            'bonusNextAt': economy.simpleEnergyBonus?.nextAtMs,
            'bonusRemainingMs': economy.simpleEnergyBonus
                ?.remainingAt(economy.energyNow)
                .inMilliseconds,
            'serverClock': economy.energyClockSynchronized,
            'rankingOnline': scores.online,
            'attempts': scores.myAttempts.length,
            'pending': scores.myAttempts
                .where((a) => scores.isAttemptPending(a.id))
                .length,
            'rectangles': rects,
            'texts': texts,
            'game': game,
            'accountError': account.error,
            'realGoogleOrPurchases': false,
            'syntheticWallet': false,
          }),
        );
      } catch (e, st) {
        request.response.statusCode = 500;
        request.response.write('$e\n$st');
      }
      await request.response.close();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    theme: buildGameTheme(),
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    debugShowCheckedModeBanner: false,
    builder: (context, child) => GameViewport(child: child!),
    home: const GameHomeScreen(),
  );
}
