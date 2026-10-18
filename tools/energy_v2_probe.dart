// Isolated native acceptance. Only com.best4u.untouch.uiprobe; all HTTP is
// intercepted, all store prices synthetic, purchases/messages prohibited.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FrameTiming;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/android_invite_source.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/invite_code.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/domain/android_energy.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/balance/energy_sheet.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/features/game/game_home_screen.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_viewport.dart';

const qaPrefix = 'energy_probe_';
final errors = <String>[];
final frames = <FrameTiming>[];
late Fixture fixture;
late EconomyStore economy;
late MobileAccount account;
late MobileWalletBridge bridge;
late AudiencePolicy audience;
late PlayerPreferences preferences;
late ScoresStore scores;
late MobileInvites invites;

class Vault implements AccountVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async => value = data;
}

class InviteMemory implements InviteVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async => value = data;
}

class NoLinks implements AndroidInviteSource {
  @override
  void listen(VoidCallback callback) {}
  @override
  Future<String?> peekAppLink() async => null;
  @override
  Future<void> acknowledgeAppLink(String url) async {}
  @override
  Future<InviteReferrer> readInstallReferrer() async =>
      const InviteReferrer(InviteReferrerStatus.absent);
  @override
  void dispose() {}
}

class NoAds implements AdsDriver {
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async =>
      AdOutcome.unavailable;
  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async =>
      false;
}

class Prices extends PlayBillingService {
  Prices(super.account) {
    available = true;
    for (final row in const {
      'energy_100_v1': 2.0,
      'energy_250_v1': 4.0,
      'energy_500_v1': 6.0,
      'energy_1000_v1': 9.0,
      'energy_batteries_2_v1': 1.0,
      'energy_batteries_5_v1': 3.0,
    }.entries) {
      products[row.key] = ProductDetails(
        id: row.key,
        title: row.key,
        description: 'Synthetic QA only',
        price: '\$${row.value.toInt()}',
        rawPrice: row.value,
        currencyCode: 'USD',
        currencySymbol: r'$',
      );
    }
  }
  @override
  Future<void> buy(String id) async => throw StateError('No payments in probe');
  @override
  Future<void> restore() async =>
      throw StateError('No store restores in probe');
}

class Fixture {
  final operations = <String>{};
  final requests = <String, int>{};
  Map<String, dynamic> wallet = {};
  int version = 1, rowCount = 12, starts = 0, finishes = 0;
  bool linked = true, offline = false;
  final rounds = <String, Map<String, dynamic>>{};
  int get now => DateTime.now().millisecondsSinceEpoch;
  Map<String, dynamic> get profile => {
    'id': 'android:900009',
    'nickname': 'Energy QA',
    'googleLinked': linked,
    'googleName': linked ? 'Energy QA' : null,
    'googleEmail': linked ? 'qa@example.invalid' : null,
    'hideGoogleAccount': true,
    'walletVersion': version,
    'serverNow': now,
    'wallet': {...wallet, 'energyGoogleReady': linked},
  };
  void configure(Map<String, String> query) {
    version++;
    operations.clear();
    rounds.clear();
    offline = query['state'] == 'offline';
    linked = query['linked'] != 'false';
    rowCount = int.tryParse(query['friends'] ?? '') ?? 12;
    final count = (int.tryParse(query['slots'] ?? '') ?? 1).clamp(1, 5);
    final percent = (int.tryParse(query['percent'] ?? '') ?? 95).clamp(0, 100);
    final bestTime = int.tryParse(query['bestTimeMs'] ?? '') ?? 21349;
    const config = AndroidEnergyConfig(enabled: true);
    wallet = {
      'energyVersion': 2,
      'energy': int.tryParse(query['balance'] ?? '') ?? 47,
      'energyConfig': config.toJson(),
      'bestTimeMs': bestTime,
      'gamesStarted': 5,
      'energyAgeCompleted': query['age'] != 'unknown',
      'claimed': query['state'] == 'claimed'
          ? [
              'energy_google',
              'energy_age',
              'energy_feedback',
              'survive_10s',
              'record_20s',
              'risks_5',
            ]
          : <String>[],
      'unlocked': [
        if (bestTime >= 10000) 'survive_10s',
        if (bestTime >= 20000) 'record_20s',
        if (query['riskUnlocked'] != 'false') 'risks_5',
      ],
      'batteries': List.generate(
        count,
        (i) => {
          'id': i == 0 ? 'free' : 'paid-$i',
          'startedAt': query['state'] == 'mixed' && i > 0
              ? now
              : now - percent * 43200000 ~/ 100,
          'capacity': 20,
          'durationMs': 43200000,
          'initialUnits': 0,
          'revision': config.revision,
        },
      ),
      if (count > 1)
        'energySubscription': {
          'productId': count == 2
              ? 'energy_batteries_2_v1'
              : 'energy_batteries_5_v1',
          'basePlanId': 'weekly',
          'batteryCount': count,
          'expiresAt': query['state'] == 'pending'
              ? now - const Duration(hours: 1).inMilliseconds
              : now + const Duration(days: 7).inMilliseconds,
          if (query['state'] == 'pending') 'awaitingReconciliation': true,
          'periodId': 'qa-period',
          'capacity': 20,
          'durationMs': 43200000,
        },
    };
  }

  Map<String, dynamic> get invitationState => {
    'profileId': 'android:900009',
    'ownCode': 'ABCDEFGH2345',
    'inviteUrl': InviteCode.url('ABCDEFGH2345'),
    'inviterAssigned': false,
    'inviterCode': null,
    'googleLinked': linked,
    'completedGames': 5,
    'bonusStatus': 'unbound',
    'reward': 20,
    'currency': 'energy',
    'requiredGames': 5,
    'rewardTotal': rowCount * 20,
    'energyRewardTotal': rowCount * 20,
    'nextCursor': null,
    'paidRows': List.generate(
      rowCount,
      (i) => {
        'id': '${1000 - i}',
        'nickname': i == 1
            ? 'Очень длинное имя приглашённого игрока'
            : 'Игрок ${i + 1}',
        'rewardedAt': now - i * 86400000,
        'amount': 20,
        'currency': 'energy',
        'energyEquivalent': 20,
      },
    ),
  };
  Future<http.Response> respond(http.Request request) async {
    final data = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
    final action = '${data['action']}';
    requests[action] = (requests[action] ?? 0) + 1;
    if (offline) throw const SocketException('Synthetic disconnected network');
    if (action.startsWith('invites_')) {
      return response({
        'ok': true,
        'profile': profile,
        'invites': invitationState,
      });
    }
    if (action == 'wallet_operation') {
      final id = '${data['operationId']}';
      if (operations.add(id)) {
        final args = data['args'] as Map;
        switch (data['kind']) {
          case 'energy_claim':
            var amount = 0;
            for (final row in wallet['batteries'] as List) {
              amount += EnergyBattery.fromJson(
                Map<String, dynamic>.from(row as Map),
              ).unitsAt(DateTime.fromMillisecondsSinceEpoch(now));
              row['initialUnits'] = 0;
              row['startedAt'] = now;
            }
            wallet['energy'] += amount;
          case 'energy_age_completed':
            wallet['energyAgeCompleted'] = true;
          case 'energy_reward':
            final reward = '${args['id']}';
            final claimId = reward == 'google' || reward == 'age'
                ? 'energy_$reward'
                : reward;
            if (!(wallet['claimed'] as List).contains(claimId)) {
              wallet['energy'] += 10;
              (wallet['claimed'] as List).add(claimId);
            }
          case 'energy_feedback':
            if (!(wallet['claimed'] as List).contains('energy_feedback')) {
              wallet['energy'] += 20;
              (wallet['claimed'] as List).add('energy_feedback');
            }
          default:
            throw StateError('Unsupported QA operation ${data['kind']}');
        }
        version++;
      }
    }
    if (action == 'round_start') {
      final id = '${data['requestId']}';
      if (!rounds.containsKey(id)) {
        final cost =
            1 +
            (data['helmet'] == true ? 1 : 0) +
            (data['jump'] == true ? 1 : 0);
        if ((wallet['energy'] as int) < cost) {
          return response({'ok': false, 'error': 'insufficient_energy'}, 409);
        }
        wallet['energy'] -= cost;
        version++;
        starts++;
        rounds[id] = {
          'helmet': data['helmet'] == true,
          'jump': data['jump'] == true,
          'cost': cost,
          'activated': false,
        };
      }
      return response({'ok': true, 'roundId': id, 'profile': profile});
    }
    if (action == 'round_activate') {
      rounds['${data['requestId']}']?['activated'] = true;
      return response({'ok': true, 'profile': profile});
    }
    if (action == 'round_cancel') {
      final round = rounds['${data['requestId']}'];
      if (round != null &&
          round['activated'] != true &&
          round['cancelled'] != true) {
        wallet['energy'] += round['cost'];
        round['cancelled'] = true;
        version++;
      }
      return response({'ok': true, 'profile': profile});
    }
    if (action == 'round_finish') {
      finishes++;
      return response({'ok': true, 'scoreId': 'qa-only', 'profile': profile});
    }
    return response({'ok': true, 'profile': profile});
  }

  http.Response response(Map<String, dynamic> data, [int status = 200]) =>
      http.Response(
        jsonEncode(data),
        status,
        headers: {'content-type': 'application/json'},
      );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
    FlutterError.presentError(details);
  };
  WidgetsBinding.instance.addTimingsCallback((value) {
    frames.addAll(value);
    if (frames.length > 3000) frames.removeRange(0, frames.length - 3000);
  });
  fixture = Fixture()..configure(const {});
  final shared = await SharedConfigLoader.load(allowNetwork: false);
  economy = EconomyStore(config: shared.economy, storagePrefix: qaPrefix);
  await economy.load();
  account = MobileAccount(vault: Vault(), client: MockClient(fixture.respond));
  bridge = MobileWalletBridge(account, economy);
  await bridge.load();
  await account.load();
  await bridge.flush();
  audience = AudiencePolicy();
  await audience.load();
  await audience.select(AgeBand.age21plus);
  preferences = PlayerPreferences();
  await preferences.load();
  await preferences.setSound(false);
  await preferences.setMusic(false);
  scores = ScoresStore(
    account: account,
    storagePrefix: qaPrefix,
    client: MockClient(
      (_) async =>
          http.Response('{"ok":true,"source":"mysql","scores":[]}', 200),
    ),
  );
  await scores.loadLocal();
  invites = MobileInvites(
    account: account,
    source: NoLinks(),
    vault: InviteMemory(),
    startupResolved: true,
  )..start();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: account),
        ChangeNotifierProvider.value(value: audience),
        ChangeNotifierProvider.value(value: preferences),
        ChangeNotifierProvider.value(value: scores),
        ChangeNotifierProvider.value(value: invites),
        ChangeNotifierProvider<PlayBillingService>(
          create: (_) => Prices(account),
        ),
        ChangeNotifierProvider(
          create: (_) => AdsService(NoAds(), audience: audience),
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
              'startInvulnSec': 8,
            }),
          ),
        ),
      ],
      child: const ProbeApp(),
    ),
  );
}

class ProbeApp extends StatefulWidget {
  const ProbeApp({super.key});
  @override
  State<ProbeApp> createState() => ProbeState();
}

class ProbeState extends State<ProbeApp> {
  final navigator = GlobalKey<NavigatorState>();
  int epoch = 0;
  double scale = 1;
  String language = 'ru';
  @override
  void initState() {
    super.initState();
    unawaited(serve());
  }

  Future<void> serve() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8892);
    await for (final request in server) {
      try {
        if (request.uri.path == '/show') {
          navigator.currentState!.popUntil((route) => route.isFirst);
          await Future<void>.delayed(const Duration(milliseconds: 350));
          errors.clear();
          fixture.configure(request.uri.queryParameters);
          if (request.uri.queryParameters.containsKey('bestTimeMs')) {
            // Isolated fixture only: allow testing a smaller confirmed best
            // after a previous synthetic high score, without owner data.
            economy.bestTimeMs = 0;
          }
          fixture.offline = false;
          await account.refreshProfile();
          await bridge.flush();
          fixture.offline = request.uri.queryParameters['state'] == 'offline';
          economy.setHelmetSelected(
            request.uri.queryParameters['helmet'] == 'true',
          );
          economy.setJumpSelected(
            request.uri.queryParameters['jump'] == 'true',
          );
          await invites.refresh();
          setState(() {
            epoch++;
            scale =
                double.tryParse(request.uri.queryParameters['scale'] ?? '') ??
                1;
            language = request.uri.queryParameters['lang'] ?? 'ru';
          });
          await Future<void>.delayed(const Duration(milliseconds: 400));
          final context = navigator.currentState!.overlay!.context;
          final screen = request.uri.queryParameters['screen'] ?? 'home';
          final tab = {'charge': 0, 'tasks': 1, 'friends': 2, 'buy': 3}[screen];
          if (tab != null && context.mounted) {
            unawaited(showEnergySheet(context, initialTab: tab));
          }
          if (context.mounted) {
            switch (screen) {
              case 'profile':
                unawaited(showProfileSheet(context));
              case 'helmet':
                unawaited(showEnergyAbilitySheet(context, helmet: true));
              case 'jump':
                unawaited(showEnergyAbilitySheet(context, helmet: false));
              case 'subscription':
                unawaited(showEnergySubscriptionSheet(context));
              case 'feedback':
                unawaited(showEnergyFeedbackSheet(context));
              case 'achievements':
                unawaited(showEnergyAchievementsSheet(context));
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 850));
        }
        final rectangles = <String, Map<String, double>>{};
        final texts = <String>[];
        final scrolls = <Map<String, dynamic>>[];
        final gameplayState = <String, dynamic>{};
        void visit(Element element) {
          if (element.widget is ArcadeHud) {
            final hud = element.widget as ArcadeHud;
            gameplayState.addAll({
              'timeMs': hud.timeMs(),
              'playing': hud.isPlaying,
              'helmetActive': hud.helmetActive,
              'helmetEquipped': hud.helmetEquipped,
              'jumpProgress': hud.jumpProgress(),
            });
          }
          if (element.widget is CustomPaint &&
              (element.widget as CustomPaint).painter is GameFieldPainter) {
            final world =
                ((element.widget as CustomPaint).painter as GameFieldPainter)
                    .world;
            gameplayState.addAll({
              'isJumping': world.isJumping,
              'jumpRemaining': world.jumpRemaining,
              'jumpCooldownMs': world.jumpCooldownRemaining(),
            });
          }
          if (element.widget is Text) {
            final text = (element.widget as Text).data;
            if (text != null) texts.add(text);
          }
          final key = element.widget.key;
          if (key is ValueKey<String>) {
            final object = element.findRenderObject();
            if (object is RenderBox && object.hasSize && object.attached) {
              final view = View.of(element);
              final origin =
                  object.localToGlobal(Offset.zero) * view.devicePixelRatio;
              final end =
                  object.localToGlobal(object.size.bottomRight(Offset.zero)) *
                  view.devicePixelRatio;
              rectangles[key.value] = {
                'left': origin.dx,
                'top': origin.dy,
                'width': end.dx - origin.dx,
                'height': end.dy - origin.dy,
              };
            }
          }
          if (element is StatefulElement && element.state is ScrollableState) {
            final state = element.state as ScrollableState;
            scrolls.add({
              'key': '${element.widget.key}',
              'type': '${element.widget.runtimeType}',
              'maxExtent': state.position.maxScrollExtent,
              'pixels': state.position.pixels,
            });
          }
          element.visitChildElements(visit);
        }

        visit(navigator.currentContext! as Element);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'errors': errors,
            'rectangles': rectangles,
            'texts': texts,
            'scrolls': scrolls,
            'energy': economy.energy,
            'charge': economy.accumulatedEnergy,
            'capacity': economy.energyCapacity,
            'attemptCost': economy.attemptEnergyCost,
            'requests': fixture.requests,
            'starts': fixture.starts,
            'finishes': fixture.finishes,
            'wallet': fixture.wallet,
            'frameCount': frames.length,
            'gameplay': gameplayState,
            'syntheticPrices': true,
            'allNetworkIntercepted': true,
          }),
        );
      } catch (error, stack) {
        request.response.statusCode = 500;
        request.response.write('$error\n$stack');
      }
      await request.response.close();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    theme: buildGameTheme(),
    debugShowCheckedModeBanner: false,
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: GameViewport(child: child!),
    ),
    home: GameHomeScreen(key: ValueKey('energy-probe-game-$epoch')),
  );
}
