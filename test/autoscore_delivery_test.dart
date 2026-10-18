import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/data/scores_store.dart';
import 'mobile_account_test.dart' show MemoryVault, GoogleFixture;

class _Server {
  bool offline = false, loseAcknowledgement = false, profileOffline = false;
  String id = 'android:1', nickname = 'user00000001';
  bool googleLinked = false;
  int best = 0;
  final finishes = <String>[];
  final results = <String, int>{};
  late final account = MobileAccount(
    vault: MemoryVault(),
    client: MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      switch (body['action']) {
        case 'round_start':
          return http.Response(
            jsonEncode({'ok': true, 'roundId': body['requestId']}),
            200,
          );
        case 'round_finish':
          final round = body['roundId'] as String;
          finishes.add(round);
          if (offline) throw StateError('offline');
          results.putIfAbsent(round, () => body['timeMs'] as int);
          if (results[round]! > best) best = results[round]!;
          if (loseAcknowledgement) throw StateError('acknowledgement lost');
          return http.Response('{"ok":true,"scoreId":"isolated"}', 200);
        case 'profile':
          if (profileOffline) throw StateError('profile offline');
        case 'rename':
          nickname = body['nickname'] as String;
        case 'google_link':
          googleLinked = true;
        case 'google_restore':
          googleLinked = true;
          id = 'android:2';
          nickname = 'RestoredPlayer';
          best = 2000;
      }
      return http.Response(
        jsonEncode({
          'ok': true,
          'profile': {
            'id': id,
            'nickname': nickname,
            'googleLinked': googleLinked,
            'walletVersion': results.length,
            'wallet': {
              'lives': 30,
              'tokens': 40,
              'bestTimeMs': best,
              'claimed': [],
              'unlocked': [],
            },
          },
        }),
        200,
      );
    }),
  );
  late final board = MockClient(
    (_) async => http.Response('{"ok":true,"source":"mysql","scores":[]}', 200),
  );
  Future<ScoresStore> start() async {
    await account.load();
    final store = ScoresStore(account: account, client: board);
    await store.loadLocal();
    return store;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'attempt and outbox are durable before first send; restart and lost acknowledgement use one round ID',
    () async {
      final server = _Server()..loseAcknowledgement = true;
      final store = await server.start();
      expect(await store.beginRound(), true);
      await store.recordAttempt(12000, runDistance: 210, riskCount: 5);
      expect(server.finishes, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final state =
          jsonDecode(prefs.getString('mobile_score_state_v2_android:1')!)
              as Map;
      expect(state['attempts'], hasLength(1));
      expect(state['outbox'], hasLength(1));
      expect(store.isAttemptPending(store.myAttempts.single.id), true);
      await store.retryPendingResults();
      expect(server.results, hasLength(1));
      expect(store.myAttempts.single.shared, false);
      store.dispose();
      server.loseAcknowledgement = false;
      final restarted = ScoresStore(
        account: server.account,
        client: server.board,
      );
      await restarted.load();
      expect(restarted.myAttempts.single.shared, true);
      expect(server.finishes.toSet(), hasLength(1));
      expect(server.results, hasLength(1));
      expect(server.best, 12000);
      await restarted.beginRound();
      await restarted.recordAttempt(3000);
      await restarted.retryPendingResults();
      expect(server.best, 12000);
      expect(server.results, hasLength(2));
      restarted.dispose();
    },
  );
  testWidgets(
    'network recovery retries automatically without another run or manual save',
    (tester) async {
      final server = _Server()..offline = true;
      final store = await server.start();
      await store.beginRound();
      await store.recordAttempt(7000);
      await tester.pump(const Duration(seconds: 1));
      expect(server.finishes, hasLength(1));
      expect(store.myAttempts.single.shared, false);
      server.offline = false;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(store.myAttempts.single.shared, true);
      expect(server.results, hasLength(1));
      store.dispose();
    },
  );
  test(
    'successful finish stays acknowledged when profile refresh fails',
    () async {
      final server = _Server();
      final store = await server.start();
      await store.beginRound();
      await store.recordAttempt(4000);
      server.profileOffline = true;
      await store.retryPendingResults();
      expect(store.myAttempts.single.shared, true);
      expect(store.isAttemptPending(store.myAttempts.single.id), false);
      await store.retryPendingResults();
      expect(server.finishes, hasLength(1));
      store.dispose();
    },
  );
  test(
    'Google link keeps guest history; restore is blocked by queued delivery and scopes history',
    () async {
      final server = _Server();
      final store = await server.start();
      await store.beginRound();
      await store.recordAttempt(9000);
      server.offline = true;
      await expectLater(
        server.account.restoreGoogle(GoogleFixture()),
        throwsA(
          isA<MobileApiError>().having(
            (e) => e.code,
            'code',
            'round_delivery_pending',
          ),
        ),
      );
      expect(server.id, 'android:1');
      server.offline = false;
      await server.account.linkGoogle(GoogleFixture());
      expect(server.id, 'android:1');
      expect(store.myAttempts.single.shared, true);
      await server.account.rename('NewNickname');
      expect(server.results, hasLength(1));
      await server.account.restoreGoogle(GoogleFixture());
      expect(store.myAttempts, isEmpty);
      expect(server.id, 'android:2');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'mobile_score_state_v2_android:1',
        ),
        isNotNull,
      );
      store.dispose();
    },
  );
  test(
    'failed start/practice is local and cannot be submitted as a ranked score',
    () async {
      final server = _Server();
      final store = await server.start();
      await store.recordAttempt(6000);
      await store.retryPendingResults();
      expect(store.myAttempts.single.shared, false);
      expect(store.isAttemptPending(store.myAttempts.single.id), false);
      expect(server.finishes, isEmpty);
      await expectLater(
        store.saveScore(displayName: 'FakeName', timeMs: 6000),
        throwsA(isA<MobileApiError>()),
      );
      store.dispose();
    },
  );
  test(
    'legacy pending rows migrate once and only for the matching owner history',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'mobile_attempts_v1_android:1',
        jsonEncode([
          {
            'id': 'own-attempt',
            'timeMs': 5000,
            'createdAt': DateTime.now().toIso8601String(),
          },
        ]),
      );
      await prefs.setString(
        'mobile_round_outbox_v1',
        jsonEncode([
          {
            'roundId': 'own-round',
            'attemptId': 'own-attempt',
            'result': {'timeMs': 5000},
          },
          {
            'roundId': 'other-round',
            'attemptId': 'other-attempt',
            'result': {'timeMs': 99999},
          },
        ]),
      );
      final server = _Server();
      final store = await server.start();
      await store.retryPendingResults();
      expect(server.finishes, ['own-round']);
      await store.load();
      expect(server.finishes, ['own-round']);
      store.dispose();
    },
  );
  test(
    'stale wallet cannot lower local best; restoring another owner can',
    () async {
      final server = _Server();
      final economy = EconomyStore();
      await economy.load();
      final bridge = MobileWalletBridge(server.account, economy);
      await bridge.load();
      await server.account.load();
      await bridge.flush();
      await economy.recordBestTime(15000);
      await server.account.refreshProfile();
      await bridge.flush();
      expect(economy.bestTimeMs, 15000);
      await server.account.restoreGoogle(GoogleFixture());
      await bridge.flush();
      expect(economy.bestTimeMs, 2000);
    },
  );
}
