// Physical Android acceptance against real Supabase Auth/Edge/PostgreSQL.
// This entrypoint is built ONLY into a disposable .uiprobe QA package.
// It contains no fake wallet, fake price or in-process backend replacement.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:game_box/data/android_config_session.dart';
import 'package:game_box/ui/game_sfx.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/android_firebase_config.dart';
import 'package:game_box/data/supabase_mobile_client.dart';
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
late SharedConfigs config;
late AndroidConfigSession configSession;
final network = ProbeNetworkClient();

class ProbeNetworkClient extends http.BaseClient {
  final http.Client actual = http.Client();
  bool blocked = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (blocked) throw http.ClientException('isolated_probe_network_failure');
    return actual.send(request);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('SUPABASE_CLOUD_QA')) {
    throw StateError('Only the authorized isolated cloud QA package');
  }
  await SupabaseMobileClient.initialize();
  if (Supabase.instance.client.auth.currentUser == null) {
    await Supabase.instance.client.auth.signInAnonymously(
      data: {
        'untouch_qa_tag': const String.fromEnvironment(
          'SUPABASE_QA_TAG',
          defaultValue: 'huawei-startup-20261019',
        ),
      },
    );
  }
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
    FlutterError.presentError(details);
  };
  final raw =
      jsonDecode(await rootBundle.loadString(AndroidFirebaseConfig.assetPath))
          as Map<String, dynamic>;
  if (const bool.fromEnvironment('QA_LEGACY_SETTINGS', defaultValue: true)) {
    raw['config'].remove('ranking');
    raw['revision'] = sha256
        .convert(utf8.encode(jsonEncode(raw['config'])))
        .toString();
  }
  config = AndroidFirebaseConfig.parse(
    jsonEncode(raw),
    'legacy-first-launch-fixture',
  );
  if (Supabase.instance.client.auth.currentUser?.isAnonymous != true) {
    throw StateError('QA must use its own anonymous profile');
  }
  final prefs = PlayerPreferences();
  await prefs.load();
  await prefs.setSound(true);
  await prefs.setMusic(true);
  await prefs.markGoogleStartupSeen();
  final audience = AudiencePolicy();
  await audience.load();
  await audience.correct(AgeBand.adult18plus);
  economy = EconomyStore(
    config: config.economy,
    storagePrefix: SupabaseMobileClient.storagePrefix,
    serverEnergyRequired: true,
  );
  await economy.load();
  account = MobileAccount(
    storagePrefix: SupabaseMobileClient.storagePrefix,
    client: SupabaseMobileClient(client: network),
    endpoint: SupabaseMobileClient.endpoint,
    rulesRevision: config.revision,
  );
  bridge = MobileWalletBridge(account, economy);
  await bridge.load();
  await account.load();
  if (!account.ready) {
    throw StateError('Supabase probe startup: ${account.error}');
  }
  await bridge.flush();
  configSession = AndroidConfigSession(config, account, economy);
  scores = ScoresStore(
    account: account,
    instantEconomy: economy,
    storagePrefix: SupabaseMobileClient.storagePrefix,
  );
  await scores.loadLocal();
  await scores.load();
  final invites = MobileInvites(
    account: account,
    source: NativeAndroidInviteSource(),
    startupResolved: true,
  );
  prefs.applyAudio(config.gameplay.audio);
  await GameSfx.prepare().timeout(const Duration(seconds: 1), onTimeout: () {});
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
        ChangeNotifierProvider.value(value: configSession),
        ProxyProvider<AndroidConfigSession, GameplayConfig>(
          update: (_, session, _) => session.gameplay,
        ),
        ProxyProvider<AndroidConfigSession, SharedConfigs>(
          update: (_, session, _) => session.snapshot,
        ),
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
        if (request.uri.path == '/offline/on') network.blocked = true;
        if (request.uri.path == '/offline/off') network.blocked = false;
        if (request.uri.path == '/energy' || request.uri.path == '/video') {
          final windowContext = navigator.currentState!.overlay!.context;
          if (!windowContext.mounted) {
            throw StateError('Probe window unavailable');
          }
          unawaited(
            showSimpleEnergyWindow(
              windowContext,
              page: request.uri.path == '/video'
                  ? EnergyPage.video
                  : EnergyPage.energy,
            ),
          );
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
            'backend': 'supabase-cloud',
            'simulatedApiOutage': network.blocked,
            'configSource': config.source,
            'configRevision': configSession.snapshot.revision,
            'initialConfigRevision': config.revision,
            'accountRulesRevision': account.rulesRevision,
            'rulesUpdateRequired': scores.rulesUpdateRequired,
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
