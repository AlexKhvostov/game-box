// Physical profile/release harness. No real account, Google, payment or ad SDK.
// Build only as com.best4u.untouch.uiprobe.review; loopback controls are QA-only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/data/android_firebase_config.dart';
import 'package:game_box/data/android_invite_source.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/app/mobile_gameplay_tuning.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/game/game_world.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';

class MemoryVault implements AccountVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    value = v;
  }
}

class NoLinks implements AndroidInviteSource {
  @override
  void listen(VoidCallback onAvailable) {}
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

final errors = <String>[];
final rootKey = GlobalKey();
late EconomyStore economy;
late ScoresStore scores;
late MobileAccount account;
late Map<String, dynamic> wallet;
final rounds = <String, Map<String, dynamic>>{};
final commands = <String>[];
int version = 0;
bool offline = false;
String? failure;
int startupConfigMs = 0;
int configRemoteWaitMs = 0;
Map<String, dynamic>? lastPhysicalProof;
GameWorld? visibleWorld() {
  GameWorld? world;
  void visit(Element e) {
    final w = e.widget;
    if (w is CustomPaint && w.painter is GameFieldPainter) {
      world = (w.painter! as GameFieldPainter).world;
    }
    e.visitChildElements(visit);
  }

  visit(rootKey.currentContext! as Element);
  return world;
}

const owner = 'supabase:12345678-1234-4234-8234-123456789abc';
Map<String, dynamic> profile() => {
  'id': owner,
  'nickname': 'ReviewPlayer',
  'googleLinked': false,
  'wallet': wallet,
  'walletVersion': ++version,
  'serverNow': DateTime.now().millisecondsSinceEpoch,
};
Future<http.Response> respond(http.Request request) async {
  final body = jsonDecode(request.body) as Map,
      action = body['action'] as String;
  commands.add(action);
  if (offline) throw const SocketException('isolated offline fixture');
  if (action == 'round_start' && failure == 'rules_changed') {
    return http.Response('{"ok":false,"error":"rules_changed"}', 409);
  }
  if (action == 'round_finish' && failure == 'result_time_invalid') {
    return http.Response('{"ok":false,"error":"result_time_invalid"}', 400);
  }
  final data = <String, dynamic>{'ok': true};
  switch (action) {
    case 'round_start':
      final id = body['requestId'] as String;
      rounds.putIfAbsent(id, () {
        wallet['energy'] =
            (wallet['energy'] as int) -
            1 -
            (body['helmet'] == true ? 1 : 0) -
            (body['jump'] == true ? 1 : 0);
        return {
          'helmet': body['helmet'],
          'jump': body['jump'],
          'activated': false,
          'finished': false,
        };
      });
      data['roundId'] = id;
    case 'round_activate':
      rounds[body['requestId']]!['activated'] = true;
    case 'round_finish':
      final row = rounds[body['roundId']]!;
      if (body['proof'] is Map) {
        lastPhysicalProof = {
          ...Map<String, dynamic>.from(body),
          'requestId': body['roundId'],
          'config':
              (jsonDecode(
                    await rootBundle.loadString(
                      AndroidFirebaseConfig.assetPath,
                    ),
                  )
                  as Map)['config'],
        };
      }
      if (row['finished'] != true) {
        row['finished'] = true;
        row['timeMs'] = body['timeMs'];
        row['runDistance'] = body['runDistance'];
        row['riskCount'] = body['riskCount'];
        row['reward'] =
            (body['runDistance'] as int) ~/ economy.config.runRewardEvery +
            (body['riskCount'] as int) ~/ economy.config.riskRewardEvery;
        wallet['energy'] = (wallet['energy'] as int) + (row['reward'] as int);
        wallet['bestTimeMs'] = body['timeMs'];
      }
      data['energyReward'] = row['reward'];
    case 'scores':
      final rows = <Map<String, dynamic>>[
        for (final entry in rounds.entries)
          if (entry.value['finished'] == true)
            {
              'id': entry.key,
              'playerName': 'ReviewPlayer',
              'userId': owner,
              'timeMs': entry.value['timeMs'],
              'createdAt': DateTime.now().millisecondsSinceEpoch,
              'place': 1,
              'runDistance': entry.value['runDistance'],
              'riskCount': entry.value['riskCount'],
              'hadJump': entry.value['jump'],
              'hadHelmet': entry.value['helmet'],
            },
      ];
      data['periods'] = {
        for (final p in ['all', 'day', 'week', 'month', 'year']) p: rows,
      };
  }
  data['profile'] = profile();
  return http.Response(jsonEncode(data), 200);
}

Map<String, dynamic> state() {
  var phase = 'idle';
  Rect? field;
  final texts = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is ArcadeHud && w.isPlaying) phase = 'playing';
    if (w is ResultOverlay) phase = 'result';
    if (w is Text && w.data != null) texts.add(w.data!);
    if (w.key == const ValueKey('arcade-game-field')) {
      final box = e.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        field = Rect.fromPoints(
          box.localToGlobal(Offset.zero),
          box.localToGlobal(box.size.bottomRight(Offset.zero)),
        );
      }
    }
    e.visitChildElements(visit);
  }

  if (rootKey.currentContext != null) visit(rootKey.currentContext! as Element);
  final dpr =
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  return {
    'phase': phase,
    'energy': economy.energy,
    'rulesUpdateRequired': scores.rulesUpdateRequired,
    'attempts': [
      for (final a in scores.myAttempts)
        {
          'shared': a.shared,
          'pending': scores.isAttemptPending(a.id),
          'error': a.deliveryError,
          'timeMs': a.timeMs,
        },
    ],
    'commands': commands,
    'texts': texts,
    'errors': errors,
    'startupConfigMs': startupConfigMs,
    'configRemoteWaitMs': configRemoteWaitMs,
    if (lastPhysicalProof != null) 'lastPhysicalProof': lastPhysicalProof,
    if (visibleWorld() case final world?)
      'player': [world.player.dx, world.player.dy, world.playerSize],
    if (field != null)
      'field': [
        field!.left * dpr,
        field!.top * dpr,
        field!.right * dpr,
        field!.bottom * dpr,
      ],
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (e) {
    errors.add(e.exceptionAsString());
    FlutterError.presentError(e);
  };
  final configClock = Stopwatch()..start();
  var remoteBegan = 0;
  final shared = await AndroidFirebaseConfig.load(
    remoteLoader: (defaults) async {
      remoteBegan = configClock.elapsedMilliseconds;
      await Future<void>.delayed(const Duration(seconds: 4));
      return defaults;
    },
  );
  startupConfigMs = configClock.elapsedMilliseconds;
  configRemoteWaitMs = startupConfigMs - remoteBegan;
  final prefix =
      'supabase_android_review_probe_${DateTime.now().microsecondsSinceEpoch}_';
  wallet = {
    'energyVersion': 2,
    'energy': 50,
    'energyConfig': shared.economy.androidEnergyV2.toJson(),
    'batteries': [],
    'energySubscription': null,
    'claimed': [],
    'unlocked': [],
    'gamesStarted': 0,
    'bestTimeMs': 0,
    'simpleBonus': {
      'contract': 3,
      'nextAt': 0,
      'durationMs': 28800000,
      'reward': 30,
      'tier': 1,
    },
  };
  economy = EconomyStore(
    config: shared.economy,
    storagePrefix: prefix,
    serverEnergyRequired: true,
  );
  await economy.load();
  account = MobileAccount(
    vault: MemoryVault(),
    client: MockClient(respond),
    storagePrefix: prefix,
    rulesRevision: shared.revision,
  );
  final bridge = MobileWalletBridge(account, economy);
  await bridge.load();
  await account.load();
  await bridge.flush();
  scores = ScoresStore(
    account: account,
    storagePrefix: prefix,
    instantEconomy: economy,
  );
  await scores.loadLocal();
  final audience = AudiencePolicy();
  await audience.load();
  await audience.correct(AgeBand.adult18plus);
  final prefs = PlayerPreferences();
  await prefs.load();
  await prefs.setMusic(false);
  await prefs.setSound(false);
  final invites = MobileInvites(
    account: account,
    source: NoLinks(),
    enabled: false,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: scores),
        ChangeNotifierProvider.value(value: account),
        ChangeNotifierProvider.value(value: audience),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider.value(value: invites),
        ChangeNotifierProvider(create: (_) => PlayBillingService(account)),
        ChangeNotifierProvider(
          create: (_) => AdsService(NoAds(), audience: audience),
        ),
        Provider.value(value: MobileGameplayTuning.apply(shared.gameplay)),
      ],
      child: KeyedSubtree(
        key: rootKey,
        child: const GameBoxApp(forceLocale: 'ru'),
      ),
    ),
  );
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8898);
  await for (final request in server) {
    try {
      if (request.uri.path == '/energy-fixture') {
        BuildContext? screen;
        void find(Element e) {
          if (e.widget is Scaffold) screen ??= e;
          e.visitChildElements(find);
        }

        find(rootKey.currentContext! as Element);
        final page = request.uri.queryParameters['page'] == 'feedback'
            ? EnergyPage.feedback
            : EnergyPage.subscription;
        final context = screen!;
        if (context.mounted) {
          unawaited(showSimpleEnergyWindow(context, page: page));
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (request.uri.path == '/stall-frame') {
        final stall = Stopwatch()..start();
        while (stall.elapsedMilliseconds < 120) {}
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      if (request.uri.path == '/collision-fixture') {
        final world = visibleWorld()!;
        world.player = const Offset(50, 120);
        world.enemies
          ..clear()
          ..add(
            EnemyBody(
              pos: const Offset(170, 100),
              vel: Offset.zero,
              w: 8,
              h: 100,
              aspect: .08,
              angleDeg: 0,
              quadrantN: 0,
              fieldQuadrant: 0,
              initialSpeed: 0,
              acceleration: 0,
            ),
          );
      }
      if (request.uri.path == '/result-fixture') {
        offline = true;
        failure = null;
        final key = scores.beginInstantRound(
          helmet: false,
          jump: false,
          cost: 1,
        );
        if (key == null) throw StateError('Fixture start blocked');
        await scores.recordAttempt(1000, runDistance: 1000, riskCount: 10);
        BuildContext? screen;
        void find(Element e) {
          if (e.widget is Scaffold) screen ??= e;
          e.visitChildElements(find);
        }

        find(rootKey.currentContext! as Element);
        final context = screen!;
        if (context.mounted) {
          unawaited(
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (c) => ResultOverlay(
                timeMs: 1000,
                runDistance: 1000,
                riskCount: 10,
                rewardClaimed: false,
                onOk: () => Navigator.of(c).pop(),
                onShare: () {},
              ),
            ),
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      if (request.uri.path == '/fixture-run') {
        if (state()['phase'] == 'playing') {
          throw StateError('Finish the physical run first');
        }
        offline = request.uri.queryParameters['offline'] == 'true';
        failure = request.uri.queryParameters['failure'];
        final key = scores.beginInstantRound(
          helmet: false,
          jump: false,
          cost: 1,
        );
        if (key == null) throw StateError('Fixture start blocked');
        await scores.recordAttempt(1);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (request.uri.path == '/retry') {
        offline = false;
        failure = null;
        await scores.retryPendingResults();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(state()));
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$e'}));
    }
    await request.response.close();
  }
}
