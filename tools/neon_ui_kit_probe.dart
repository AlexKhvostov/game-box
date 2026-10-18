// Real Android widgets, synthetic data, isolated package. No external actions.
// Build only with UNTOUCH_UI_PROBE=true and --dart-define=NEON_UI_KIT_PROBE=true.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/google_identity.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/balance/energy_sheet.dart';
import 'package:game_box/features/game/game_home_screen.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/features/leaderboard/leaderboard_panel.dart';
import 'package:game_box/features/leaderboard/player_result_sheet.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/features/profile/google_startup_dialog.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'package:game_box/features/result/run_summary.dart';
import 'package:game_box/features/result/share_social_sheet.dart';
import 'package:game_box/features/result/share_score_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/audience_gate.dart';
import 'package:game_box/ui/energy_widgets.dart';
import 'package:game_box/ui/game_ui.dart';
import 'package:game_box/ui/game_viewport.dart';
import 'package:game_box/ui/test_service_preview.dart';
import 'energy_v2_probe.dart' as base;

const storagePrefix = 'neon_ui_kit_';
const screenNames = {
  'home',
  'charge',
  'tasks',
  'friends',
  'friends-help',
  'buy',
  'subscription',
  'subscription-upgrade',
  'subscription-downgrade',
  'purchase',
  'test-service',
  'achievements',
  'feedback',
  'helmet',
  'jump',
  'profile',
  'google-offer',
  'profile-confirm',
  'age',
  'leaderboard',
  'player',
  'result',
  'share-social',
  'share-score',
  'components',
};
final errors = <String>[];
late KitFixture fixture;
late EconomyStore economy;
late KitAccount account;
late MobileWalletBridge bridge;
late AudiencePolicy audience;
late PlayerPreferences preferences;
late KitScores scores;
late MobileInvites invites;
late KitBilling billing;

// Every HTTP consumer below receives a MockClient. This is the final guard
// against a newly introduced, uninjected HTTP consumer (loopback server is fine).
class NoOutgoingHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('External HTTP is disabled in the UI kit');
}

class NoGoogle implements GoogleIdentity, GoogleIdentitySession {
  const NoGoogle();
  @override
  bool get configured => true;
  @override
  Future<String> token() async => throw StateError('Google disabled in UI kit');
  @override
  Future<void> signOut() async => throw StateError('Google disabled in UI kit');
}

class KitAccount extends MobileAccount {
  KitAccount()
    : super(vault: base.Vault(), client: MockClient(fixture.respond));
  @override
  Future<void> linkGoogle(GoogleIdentity google) async =>
      throw StateError('Google disabled in UI kit');
  @override
  Future<void> restoreGoogle(GoogleIdentity google) async =>
      throw StateError('Google disabled in UI kit');
  @override
  Future<void> unlinkGoogle(GoogleIdentity google) async =>
      throw StateError('Google disabled in UI kit');
}

class KitFixture extends base.Fixture {
  int fixedNow = DateTime.now().millisecondsSinceEpoch;
  Map<String, String> query = {};
  @override
  int get now => fixedNow;
  @override
  Map<String, dynamic> get profile => {
    ...super.profile,
    'nickname': query['nicknameEdit'] == 'true' ? 'Новый игрок' : 'Алексей',
    'googleName': linked ? 'Алексей' : null,
    'hideGoogleAccount': query['privacy'] != 'public',
  };
  @override
  void configure(Map<String, String> q) {
    fixedNow = DateTime.now().millisecondsSinceEpoch;
    query = Map.of(q);
    super.configure(q);
    final claimed = List<String>.from(wallet['claimed'] as List);
    switch (q['achievementState']) {
      case 'claimed':
        claimed.addAll(['survive_10s', 'record_20s', 'risks_5']);
      case 'mixed':
        claimed.add('survive_10s');
    }
    if (q['feedbackState'] == 'sent') claimed.add('energy_feedback');
    wallet['claimed'] = claimed.toSet().toList();
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    final data = jsonDecode(request.body) as Map;
    final action = '${data['action']}';
    if (action.startsWith('google_') || action.contains('play')) {
      throw StateError('Identity/store operations disabled in UI kit');
    }
    return super.respond(request);
  }

  Future<http.Response> scoreResponse(http.Request request) async {
    if (query['scoreState'] == 'offline' ||
        query['scoreState'] == 'offlineEmpty') {
      return http.Response(
        '{}',
        503,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final period = request.url.queryParameters['period'] ?? 'day';
    final spanDays =
        {'day': 0, 'week': 5, 'month': 25, 'year': 250, 'all': 400}[period] ??
        0;
    final bestMs =
        {
          'day': 31000,
          'week': 42000,
          'month': 57000,
          'year': 68000,
          'all': 79000,
        }[period] ??
        31000;
    return http.Response(
      jsonEncode({
        'ok': true,
        'source': 'mysql',
        'scores': query['scoreState'] == 'empty'
            ? []
            : List.generate(
                12,
                (i) => {
                  'id': 'kit-score-$i',
                  'userId': i == 2 ? 'android:900009' : 'android:${700 + i}',
                  'playerName': i == 4
                      ? 'ОченьДлинноеИмяИгрока123'
                      : 'Игрок ${i + 1}',
                  'timeMs': bestMs - i * 973,
                  'createdAt': now - spanDays * i * 86400000 ~/ 12 - i * 1000,
                  'countryCode': i.isEven ? 'BY' : 'US',
                  'riskCount': 8 - i % 4,
                  'runDistance': 435 - i * 10,
                  'hadJump': i.isEven,
                  'hadHelmet': i % 3 == 0,
                },
              ),
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class KitBilling extends PlayBillingService {
  KitBilling(super.account) : super(testServicePreview: true);
  String mode = 'preview';
  @override
  bool get testServicePreview => mode == 'preview';
  void configure(String? store) {
    mode = store ?? 'preview';
    products.clear();
    available = mode == 'fixture';
    error = null;
    busy = false;
    if (available) {
      for (final row in const {
        'energy_100_v1': 2,
        'energy_250_v1': 4,
        'energy_500_v1': 6,
        'energy_1000_v1': 9,
        'energy_batteries_2_v1': 1,
        'energy_batteries_5_v1': 3,
      }.entries) {
        products[row.key] = ProductDetails(
          id: row.key,
          title: row.key,
          description: 'Synthetic preview only',
          price: '\$${row.value}',
          rawPrice: row.value.toDouble(),
          currencyCode: 'USD',
          currencySymbol: r'$',
        );
      }
    }
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> refreshCatalog() async {}
  @override
  Future<void> retryPending() async {}
  @override
  Future<void> buy(String id) async => throw StateError('Payments disabled');
  @override
  Future<void> restore() async => throw StateError('Store restore disabled');
}

// Only display getters differ. No round is started or uploaded for result shots.
class KitScores extends ScoresStore {
  KitScores()
    : super(
        account: account,
        storagePrefix: storagePrefix,
        client: MockClient(fixture.scoreResponse),
      );
  @override
  LocalAttempt? get latestAttempt => fixture.query['screen'] == 'result'
      ? LocalAttempt(
          id: 'kit-result',
          timeMs: fixture.query['resultState'] == 'zero' ? 0 : 21349,
          createdAt: DateTime.fromMillisecondsSinceEpoch(fixture.now),
          riskCount: 16,
          runDistance: 1998,
          shared: fixture.query['resultState'] != 'pending',
        )
      : super.latestAttempt;
  @override
  bool isAttemptPending(String id) => id == 'kit-result'
      ? fixture.query['resultState'] == 'pending'
      : id == 'kit-mine-2'
      ? true
      : super.isAttemptPending(id);
  @override
  List<LocalAttempt> get myAttempts =>
      fixture.query['screen'] == 'leaderboard' && fixture.query['period'] == '5'
      ? List.generate(
          4,
          (i) => LocalAttempt(
            id: 'kit-mine-$i',
            timeMs: 21349 - i * 1700,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              fixture.now - i * 3600000,
            ),
            displayName: 'Алексей',
            riskCount: 16 - i * 3,
            runDistance: 1998 - i * 320,
            hadJump: i.isEven,
            hadHelmet: i % 3 == 0,
            shared: i < 2,
          ),
        )
      : super.myAttempts;
}

Future<void> main() async {
  if (!const bool.fromEnvironment('NEON_UI_KIT_PROBE') || !Platform.isAndroid) {
    throw StateError('Dedicated Android UI-kit build required');
  }
  final process = (await File(
    '/proc/self/cmdline',
  ).readAsBytes()).takeWhile((byte) => byte != 0).toList();
  if (utf8.decode(process) != 'com.best4u.untouch.uiprobe') {
    throw StateError('Refusing owner application package');
  }
  if (PlayBillingService.enabled ||
      AudiencePolicy.adsBuildEnabled ||
      NativeGoogleIdentity.clientId.isNotEmpty) {
    throw StateError('Build must omit native Billing/Ads/Google credentials');
  }
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = NoOutgoingHttp();
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
    FlutterError.presentError(details);
  };
  fixture = KitFixture()..configure({'screen': 'home'});
  final configClient = MockClient(
    (_) async =>
        throw StateError('Bundled config must not issue HTTP in UI kit'),
  );
  final shared = await SharedConfigLoader.load(
    allowNetwork: false,
    client: configClient,
  );
  configClient.close();
  economy = EconomyStore(
    config: shared.economy,
    storagePrefix: storagePrefix,
    now: () => DateTime.fromMillisecondsSinceEpoch(fixture.now),
  );
  await economy.load();
  account = KitAccount();
  bridge = MobileWalletBridge(account, economy);
  await bridge.load();
  await account.load();
  await bridge.flush();
  audience = AudiencePolicy();
  await audience.load();
  await audience.correct(AgeBand.age21plus);
  preferences = PlayerPreferences();
  await preferences.load();
  await preferences.setSound(false);
  await preferences.setMusic(false);
  scores = KitScores();
  await scores.loadLocal();
  await scores.load();
  invites = MobileInvites(
    account: account,
    source: base.NoLinks(),
    vault: base.InviteMemory(),
    startupResolved: true,
  )..start();
  billing = KitBilling(account)..configure(null);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider<MobileAccount>.value(value: account),
        ChangeNotifierProvider.value(value: audience),
        ChangeNotifierProvider.value(value: preferences),
        ChangeNotifierProvider<ScoresStore>.value(value: scores),
        ChangeNotifierProvider.value(value: invites),
        ChangeNotifierProvider<PlayBillingService>.value(value: billing),
        ChangeNotifierProvider(
          create: (_) => AdsService(base.NoAds(), audience: audience),
        ),
        Provider.value(
          value: GameplayConfig(
            enemies: shared.gameplay.enemies,
            player: shared.gameplay.player,
            field: shared.gameplay.field,
            audio: shared.gameplay.audio,
            mobileEnemies: shared.gameplay.mobileEnemies,
            game: GameConfig.fromJson({
              ...shared.gameplay.game.toJson(),
              'idleEnemiesMove': false,
            }),
          ),
        ),
      ],
      child: const KitApp(),
    ),
  );
}

class KitApp extends StatefulWidget {
  const KitApp({super.key});
  @override
  State<KitApp> createState() => KitState();
}

class KitState extends State<KitApp> {
  final navigator = GlobalKey<NavigatorState>();
  int epoch = 0, revision = 0;
  bool complete = false;
  String currentScreen = 'home';
  Map<String, String> query = {'screen': 'home'};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      complete = true;
      unawaited(serve());
    });
  }

  Future<void> settle([int milliseconds = 450]) async {
    await Future<void>.delayed(Duration(milliseconds: milliseconds));
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
  }

  List<Element> elements() {
    final found = <Element>[];
    void visit(Element e) {
      found.add(e);
      e.visitChildElements(visit);
    }

    visit(navigator.currentContext! as Element);
    return found;
  }

  Element keyed(String key) => elements().firstWhere(
    (e) => e.widget.key == ValueKey(key),
    orElse: () => throw StateError('Missing actual widget: $key'),
  );
  // Only these exact existing, render-only callbacks may be invoked remotely.
  void invoke(String key) {
    if (!{
      'energy-friends-info',
      'energy-subscribe-1',
      'energy-subscribe-4',
      'profile-support-expand',
      'energy-feedback-send',
    }.contains(key)) {
      throw StateError('Callback outside render whitelist');
    }
    VoidCallback? callback;
    void visit(Element e) {
      final w = e.widget;
      if (callback != null) return;
      if (w is ButtonStyleButton) callback = w.onPressed;
      if (w is IconButton) callback = w.onPressed;
      if (w is InkWell) callback = w.onTap;
      if (w is GestureDetector) callback = w.onTap;
      if (callback == null) e.visitChildElements(visit);
    }

    visit(keyed(key));
    if (callback == null) throw StateError('No active render callback: $key');
    callback!();
  }

  Future<void> show(Map<String, String> q) async {
    final screen = q['screen'] ?? 'home';
    if (!screenNames.contains(screen)) throw StateError('Unknown screen');
    complete = false;
    revision++;
    navigator.currentState!.popUntil((r) => r.isFirst);
    setState(() {
      currentScreen = 'home';
      epoch++;
    });
    await settle();
    errors.clear();
    query = {...q, 'screen': screen};
    fixture.configure(query);
    fixture.offline = false;
    economy.bestTimeMs = 0;
    billing.configure(q['store']);
    await account.refreshProfile();
    await bridge.flush();
    await audience.correct(
      q['age'] == 'unknown' ? AgeBand.unknown : AgeBand.age21plus,
    );
    economy.setHelmetSelected(q['helmet'] == 'true');
    economy.setJumpSelected(q['jump'] == 'true');
    await invites.refresh();
    if (q['scoreState'] == 'offline') {
      // Seed confirmed synthetic cache first. A subsequent mocked failure
      // exercises the real offline-with-saved-results branch deterministically.
      fixture.query = {...query, 'scoreState': 'ready'};
      await scores.load();
      fixture.query = Map.of(query);
    }
    if (q['scoreState'] == 'offlineEmpty') {
      // Clear synthetic cache through the normal injected loader before503,
      // without depending on whichever scene was captured previously.
      fixture.query = {...query, 'scoreState': 'empty'};
      await scores.load();
      fixture.query = Map.of(query);
    }
    await scores.load();
    fixture.offline = q['state'] == 'offline';
    setState(() {
      currentScreen = screen;
      epoch++;
    });
    await settle();
    final c = navigator.currentState!.overlay!.context;
    if (!c.mounted) throw StateError('Render navigator was disposed');
    final tab = {
      'charge': 0,
      'tasks': 1,
      'friends': 2,
      'friends-help': 2,
      'buy': 3,
    }[screen];
    if (tab != null) unawaited(showEnergySheet(c, initialTab: tab));
    switch (screen) {
      case 'profile':
        unawaited(showProfileSheet(c, googleIdentity: const NoGoogle()));
      case 'helmet':
        unawaited(showEnergyAbilitySheet(c, helmet: true));
      case 'jump':
        unawaited(showEnergyAbilitySheet(c, helmet: false));
      case 'subscription' || 'subscription-upgrade' || 'subscription-downgrade':
        unawaited(showEnergySubscriptionSheet(c));
      case 'purchase':
        final amount = int.tryParse(q['amount'] ?? '') ?? 100;
        unawaited(showEnergyPurchaseSheet(c, 'energy_${amount}_v1', amount));
      case 'test-service':
        unawaited(
          showTestServiceUnavailable(
            c,
            service: TestService.values.firstWhere(
              (s) => s.name == q['service'],
              orElse: () => TestService.payment,
            ),
          ),
        );
      case 'achievements':
        unawaited(showEnergyAchievementsSheet(c));
      case 'feedback':
        unawaited(showEnergyFeedbackSheet(c));
      case 'google-offer':
        unawaited(
          showGoogleStartupOffer(
            c,
            account: account,
            identity: const NoGoogle(),
          ),
        );
      case 'profile-confirm':
        final future = switch (q['kind']) {
          'restore' => showProfileRestoreConfirmation(c),
          'reset' => showProfileResetConfirmation(c),
          _ => showProfileGoogleDisconnectConfirmation(c),
        };
        unawaited(future.then((_) {}));
      case 'age':
        unawaited(
          showAudienceSelection(
            c,
            resourceAction: q['kind'] == 'resource',
            editing: q['kind'] == 'editing',
          ),
        );
      case 'leaderboard':
        unawaited(showLeaderboardSheet(c));
      case 'share-score':
        unawaited(showShareScoreSheet(c, timeMs: 21349));
      case 'player':
        unawaited(
          showPlayerResultSheet(
            c,
            entry: ScoreEntry(
              id: 'kit-player',
              displayName: q['player'] == 'long'
                  ? 'ОченьДлинноеИмяИгрока123'
                  : 'Алексей',
              uid: q['player'] == 'own' ? account.id : 'android:700',
              timeMs: 21349,
              createdAt: DateTime.fromMillisecondsSinceEpoch(fixture.now),
              riskCount: 16,
              runDistance: 1998,
              hadJump: true,
              hadHelmet: true,
              countryCode: 'BY',
            ),
            place: 3,
            own: q['player'] == 'own',
            periodLabel: 'День',
          ),
        );
      case 'share-social':
        unawaited(
          showShareSocialSheet(
            c,
            timeMs: 21349,
            riskCount: 16,
            runSteps: 1998,
            betterPercent: 87,
          ),
        );
    }
    await settle(650);
    if (screen == 'friends-help') invoke('energy-friends-info');
    if (screen == 'subscription-upgrade') invoke('energy-subscribe-4');
    if (screen == 'subscription-downgrade') invoke('energy-subscribe-1');
    if (screen == 'profile' && q['expanded'] == 'true') {
      invoke('profile-support-expand');
    }
    if (screen == 'leaderboard') {
      final panel =
          elements()
                  .whereType<StatefulElement>()
                  .firstWhere((e) => e.state is LeaderboardPanelState)
                  .state
              as LeaderboardPanelState;
      // Fixture-only selection of the actual public panel state.
      // ignore: invalid_use_of_protected_member
      panel.setState(() => panel.filter = int.tryParse(q['period'] ?? '') ?? 4);
    }
    if (screen == 'feedback') {
      final state = q['feedbackState'] ?? 'empty';
      if (!{'empty', 'sent'}.contains(state)) {
        final field = keyed('energy-feedback-text').widget as TextField;
        field.controller!.text = state == 'invalid'
            ? '1234567890123456789'
            : 'Хочу улучшить игру: всё работает хорошо.';
        // Controller assignment updates EditableText, but Flutter deliberately
        // does not call onChanged for programmatic edits. Invoke the existing
        // form callback too, so its counter/validation matches this fixture.
        field.onChanged?.call(field.controller!.text);
        if (state == 'rating1' || state == 'rating5') {
          final text = state == 'rating1' ? '1 ★' : '5 ★';
          final label = elements().firstWhere(
            (e) => e.widget is Text && (e.widget as Text).data == text,
          );
          label.visitAncestorElements((e) {
            if (e.widget is InkWell) {
              (e.widget as InkWell).onTap?.call();
              return false;
            }
            return true;
          });
        }
        await settle();
        if (state == 'error') {
          fixture.offline = true;
          invoke('energy-feedback-send');
        }
      }
    }
    if (screen == 'result' && {'risk', 'run'}.contains(q['tip'])) {
      final summary =
          elements().firstWhere((e) => e.widget is RunSummary).widget
              as RunSummary;
      q['tip'] == 'risk' ? summary.onRisk() : summary.onRun();
    }
    await settle(650);
    complete = true;
  }

  Map<String, dynamic> snapshot() {
    final rectangles = <String, Map<String, double>>{};
    final texts = <String>[];
    final scrolls = <Map<String, dynamic>>[];
    for (final e in elements()) {
      final w = e.widget;
      if (w is Text && w.data != null) texts.add(w.data!);
      if (w.key is ValueKey<String>) {
        final box = e.findRenderObject();
        if (box is RenderBox && box.attached && box.hasSize) {
          final ratio = View.of(e).devicePixelRatio;
          final origin = box.localToGlobal(Offset.zero) * ratio;
          rectangles[(w.key as ValueKey<String>).value] = {
            'left': origin.dx,
            'top': origin.dy,
            'width': box.size.width * ratio,
            'height': box.size.height * ratio,
          };
        }
      }
      if (e is StatefulElement && e.state is ScrollableState) {
        final position = (e.state as ScrollableState).position;
        scrolls.add({
          'pixels': position.pixels,
          'maxExtent': position.maxScrollExtent,
        });
      }
    }
    return {
      'currentScreen': currentScreen,
      'query': query,
      'renderComplete': complete,
      'revisionToken': '$revision:$epoch',
      'rectangles': rectangles,
      'texts': texts,
      'scrolls': scrolls,
      'errors': errors,
      'energy': economy.energy,
      'charge': economy.accumulatedEnergy,
      'capacity': economy.energyCapacity,
      'attemptCost': economy.attemptEnergyCost,
      'requests': fixture.requests,
      'starts': fixture.starts,
      'finishes': fixture.finishes,
      'allNetworkIntercepted': true,
      'allApiIntercepted': true,
      'syntheticData': true,
      'syntheticPrices': true,
      'realPayments': false,
      'realGoogleActions': false,
      'realMessages': false,
      'touchesAbsorbed': true,
      'storeMode': billing.mode,
      'scoreFixture': {
        'online': scores.online,
        'periodCounts': {
          for (final period in ['day', 'week', 'month', 'year', 'all'])
            period: scores.scoresForNamedPeriod(period).length,
        },
        'myAttempts': scores.myAttempts.length,
      },
    };
  }

  Future<void> serve() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8894);
    await for (final request in server) {
      try {
        if (request.uri.path == '/show') {
          await show(request.uri.queryParameters);
        } else if (request.uri.path != '/state') {
          throw StateError('Only /show and /state are supported');
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(snapshot()));
      } catch (error, stack) {
        complete = false;
        request.response.statusCode = 500;
        request.response.write(
          jsonEncode({'error': '$error', 'stack': '$stack'}),
        );
      }
      await request.response.close();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    theme: buildGameTheme(),
    debugShowCheckedModeBanner: false,
    locale: Locale(query['lang'] ?? 'ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          double.tryParse(query['scale'] ?? '') ?? 1,
        ),
      ),
      child: AbsorbPointer(child: GameViewport(child: child!)),
    ),
    home: currentScreen == 'components'
        ? const ComponentsBoard()
        : Stack(
            children: [
              GameHomeScreen(key: ValueKey('neon-kit-game-$epoch')),
              if (currentScreen == 'result')
                Positioned.fill(
                  child: ResultOverlay(
                    key: ValueKey('neon-kit-result-$epoch'),
                    timeMs: query['resultState'] == 'zero' ? 0 : 21349,
                    runDistance: query['resultState'] == 'zero' ? 0 : 1998,
                    riskCount: query['resultState'] == 'zero' ? 0 : 16,
                    previousBestTimeMs: query['resultState'] == 'record'
                        ? 15000
                        : 25000,
                    rewardClaimed: false,
                    onClaimReward: () async => false,
                    onOk: () {},
                    onShare: () {},
                  ),
                ),
            ],
          ),
  );
}

class ComponentsBoard extends StatelessWidget {
  const ComponentsBoard({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF061B2B),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            key: const ValueKey('ui-kit-components'),
            width: 358,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Компоненты игры',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  width: 170,
                  height: 48,
                  child: EnergyBalanceCapsule(amount: 47, showPlus: true),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: Row(
                    children: [
                      const Expanded(
                        child: EnergyBatteryTile(
                          percent: 65,
                          amount: 13,
                          capacity: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EnergyBatteryTile(
                          percent: 0,
                          amount: 0,
                          capacity: 20,
                          active: false,
                          onConnect: () {},
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('Основное действие'),
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: null,
                    child: Text('Недоступно'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Дополнительное действие'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(foregroundColor: GameUi.muted),
                  child: const Text('Спокойная ссылка'),
                ),
                const EnergyNeonSurface(
                  child: TextField(
                    decoration: InputDecoration(hintText: 'Поле ввода'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in [
                      energyNeon,
                      GameUi.cyan,
                      GameUi.mint,
                      GameUi.ink,
                      GameUi.muted,
                    ])
                      Padding(
                        padding: const EdgeInsets.all(5),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
