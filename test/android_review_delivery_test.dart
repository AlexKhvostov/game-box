import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'instant_round_journal_test.dart' as run;
import 'simple_energy_test.dart' as energy;

class BoardAccount extends run.RunAccount {
  BoardAccount(super.server);
  @override
  String get storagePrefix => 'supabase_android_delivery_test_';
  int fetches = 0;
  @override
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> payload, {
    bool guest = false,
  }) async {
    if (payload['action'] == 'scores') fetches++;
    final rows = [
      for (final r in server.rounds.entries)
        if (r.value['finished'] == true)
          {
            'id': r.key,
            'userId': id,
            'playerName': 'Mine',
            'timeMs': 1,
            'createdAt': 1,
            'place': 1,
          },
    ];
    return {
      'ok': true,
      'periods': {
        for (final p in ['all', 'day', 'week', 'month', 'year']) p: rows,
      },
    };
  }
}

class ResultScores extends ScoresStore {
  bool accepted = false;
  void acknowledge() {
    accepted = true;
    notifyListeners();
  }

  @override
  LocalAttempt get latestAttempt => LocalAttempt(
    id: 'current',
    timeMs: 10000,
    createdAt: DateTime(2026),
    shared: accepted,
  );
  @override
  bool isAttemptPending(String id) => !accepted;
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
}

class PurchaseAccount extends MobileAccount {
  PurchaseAccount() : super(storagePrefix: 'supabase_android_billing_test_') {
    id = run.owner;
  }
  int verifications = 0, syncs = 0;
  bool fail = true;
  @override
  Future<void> verifyPlay(String productId, String token) async {
    verifications++;
    await Future<void>.delayed(Duration.zero);
    if (fail) throw const MobileApiError('connection_failed');
  }

  @override
  Future<void> syncPlay() async {
    syncs++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'real own place survives top200 truncation; an unavailable global percentage is explicit',
    () async {
      final a = MobileAccount(
        storagePrefix: 'supabase_android_delivery_test_',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'ok': true,
              'periods': {
                for (final p in ['all', 'day', 'week', 'month', 'year'])
                  p: [
                    for (var i = 1; i <= 200; i++)
                      {
                        'id': '$i',
                        'userId': 'other:$i',
                        'playerName': 'Other',
                        'timeMs': 10000 - i,
                        'createdAt': 1,
                        'place': i,
                      },
                    {
                      'id': 'mine',
                      'userId': run.owner,
                      'playerName': 'Mine',
                      'timeMs': 1000,
                      'createdAt': 1,
                      'place': 520,
                    },
                  ],
              },
            }),
            200,
          ),
        ),
      )..id = run.owner;
      final s = ScoresStore(account: a);
      await s.load();
      expect(s.rankFor(1000).place, 520);
      expect(s.rankFor(1000).placeKnown, true);
      expect(s.rankFor(1000).percentileKnown, false);
      s.dispose();
      a.dispose();
    },
  );
  test(
    'publication refreshes an already loaded board without reopening it',
    () async {
      final server = run.RunServer(), e = EconomyStore();
      await e.load();
      await e.applyServerWallet(
        server.wallet(),
        owner: run.owner,
        serverNow: energy.stamp,
      );
      final a = BoardAccount(server),
          s = ScoresStore(account: a, instantEconomy: e);
      await s.loadLocal();
      await s.load();
      expect(a.fetches, 1);
      s.beginInstantRound(helmet: false, jump: false, cost: 1);
      await s.recordAttempt(1);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await s.retryPendingResults();
      await run.flush();
      expect(s.myAttempts.single.shared, true);
      await Future<void>.delayed(const Duration(milliseconds: 420));
      await run.flush();
      expect(s.scores.length, 1);
      expect(a.fetches, 2);
      s.dispose();
      a.dispose();
      e.dispose();
    },
  );
  test(
    'bad ranking cache is ignored, while an unreadable valuable journal is preserved and never overwritten',
    () async {
      final prefix = 'supabase_android_delivery_test_';
      final stateKey = '${prefix}mobile_score_state_v2_${run.owner}';
      SharedPreferences.setMockInitialValues({
        '${prefix}local_scores_v2_${run.owner}': 'bad cache',
        stateKey: 'valuable broken journal',
      });
      final a = MobileAccount(storagePrefix: prefix)..id = run.owner;
      final e = EconomyStore();
      await e.load();
      final s = ScoresStore(
        account: a,
        storagePrefix: prefix,
        instantEconomy: e,
      );
      await s.loadLocal();
      expect(s.localHistoryReadable, false);
      expect(s.beginInstantRound(helmet: false, jump: false, cost: 1), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(stateKey),
        'valuable broken journal',
      );
      s.dispose();
      a.dispose();
      e.dispose();
      SharedPreferences.setMockInitialValues({
        '${prefix}local_scores_v2_pending': 'bad cache',
      });
      final b = MobileAccount(storagePrefix: prefix),
          t = ScoresStore(account: b, storagePrefix: prefix);
      await t.loadLocal();
      expect(t.localHistoryReadable, true);
      expect(t.scores, isEmpty);
      t.dispose();
      b.dispose();
    },
  );
  testWidgets(
    'energy result says earned only after ACK and never offers an already automatic second grant',
    (tester) async {
      final e = EconomyStore();
      await e.load();
      await e.applyServerWallet(
        energy.simpleWallet(),
        owner: run.owner,
        serverNow: energy.stamp,
      );
      final s = ResultScores();
      addTearDown(e.dispose);
      addTearDown(s.dispose);
      await tester.binding.setSurfaceSize(const Size(412, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: e),
            ChangeNotifierProvider<ScoresStore>.value(value: s),
          ],
          child: MaterialApp(
            theme: buildGameTheme(),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ResultOverlay(
              timeMs: 10000,
              runDistance: 10000,
              riskCount: 100,
              onOk: () {},
              onShare: () {},
              rewardClaimed: false,
              onClaimReward: () async => true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byKey(const ValueKey('result-claim-reward')), findsNothing);
      expect(find.textContaining('получено'), findsNothing);
      s.acknowledge();
      await tester.pump();
      expect(find.textContaining('получено'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );

  Future<PlayBillingService> pending(PurchaseAccount a, {String? owner}) async {
    FlutterSecureStorage.setMockInitialValues({
      '${a.storagePrefix}untouch_play_pending_v1': jsonEncode([
        {
          'owner': owner ?? a.id,
          'productId': 'energy_100_v1',
          'token': 'synthetic-purchase-token',
        },
      ]),
    });
    final b = PlayBillingService(
      a,
      pendingRetryDelay: const Duration(milliseconds: 20),
    );
    await b.loadPendingJournal();
    return b;
  }

  test(
    'pending purchased token retries automatically after connection recovers; no store/purchase UI is called',
    () async {
      final a = PurchaseAccount(), b = await pending(a);
      await b.retryPending();
      expect(a.verifications, 1);
      expect(b.error, 'verification_pending');
      a.fail = false;
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(a.verifications, 2);
      expect(b.error, isNull);
      final raw = await const FlutterSecureStorage().read(
        key: '${a.storagePrefix}untouch_play_pending_v1',
      );
      expect(jsonDecode(raw!), isEmpty);
      b.dispose();
      a.dispose();
    },
  );
  test(
    'purchase retries pause in background and resume when foreground returns',
    () async {
      final a = PurchaseAccount()..fail = false, b = await pending(a);
      b.didChangeAppLifecycleState(AppLifecycleState.paused);
      await b.retryPending();
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(a.verifications, 0);
      b.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(a.verifications, 1);
      b.dispose();
      a.dispose();
    },
  );
  test('another owner cannot verify or discard a pending purchase', () async {
    final a = PurchaseAccount()..fail = false,
        b = await pending(a, owner: 'supabase:other-owner');
    await b.retryPending();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(a.verifications, 0);
    expect(b.error, 'purchase_owner_invalid');
    final raw = await const FlutterSecureStorage().read(
      key: '${a.storagePrefix}untouch_play_pending_v1',
    );
    expect((jsonDecode(raw!) as List).length, 1);
    b.dispose();
    a.dispose();
  });
}
