import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/instant_round_journal.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/average_ranking.dart';
import 'package:game_box/domain/my_attempts.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/domain/server_attempt_history.dart';

const historyOwner = 'supabase:history-owner';
Map<String, dynamic> historyReply({
  String owner = historyOwner,
  String snapshot = 'snapshot-a',
  int total = 650,
  int offset = 0,
  int limit = 100,
  double mean = 20000,
}) {
  Map<String, dynamic> point(int number) => {
    'id': 'round-$number',
    'number': number,
    'timeMs': number == 1 ? 90000 : 1000 + number * 100,
    'createdAt': 1760000000000 + number * 1000,
    'runDistance': number * 3,
    'riskCount': number % 9,
    'hadJump': number.isEven,
    'hadHelmet': number.isOdd,
    'averageMs': mean - (total - number) * 5,
    'included': true,
    'windowCount': 50,
  };
  final count = (total - offset).clamp(0, limit);
  return {
    'ok': true,
    'source': 'supabase',
    'average': AverageRanking(
      algorithm: AverageRanking.quadraticAlgorithm,
      mine: AverageRankEntry(
        userId: owner,
        averageMs: total == 0 ? null : mean,
        totalAttempts: total,
        usedCount: total == 0 ? 0 : 50,
        eligibleCount: total,
      ),
    ).toJson(),
    'history': {
      'userId': owner,
      'snapshot': snapshot,
      'totalCount': total,
      'rows': List.generate(count, (i) => point(total - offset - i)),
      'nextCursor': offset + count < total ? '${offset + count}' : null,
      'best': total == 0 ? null : point(1),
    },
  };
}

class HistoryAccount extends MobileAccount {
  HistoryAccount(this.reply)
    : super(storagePrefix: 'supabase_android_history_') {
    id = historyOwner;
  }
  Future<Map<String, dynamic>> Function(Map<String, dynamic>) reply;
  final calls = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> payload, {
    bool guest = false,
  }) async {
    calls.add(Map.of(payload));
    return reply(payload);
  }

  void changeOwner(String? owner) {
    id = owner;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Expired cached cursor restarts the first page instead of retrying the same invalid token',
    () async {
      final account = HistoryAccount((body) async {
        if (body['cursor'] != null) {
          throw const MobileApiError('attempt_history_cursor_invalid');
        }
        return historyReply();
      });
      final store = ScoresStore(account: account);
      addTearDown(store.dispose);
      addTearDown(account.dispose);
      await store.loadAttemptHistory();
      await store.loadAttemptHistory(more: true);
      expect(account.calls.length, 3);
      expect(account.calls.last.containsKey('cursor'), false);
      expect(store.historyError, isNull);
      expect(store.serverAttemptHistory!.rows.length, 100);
    },
  );
  test(
    'Legacy zero survives parsing and server ordinals preserve ties independently of ID collation',
    () {
      final reply = historyReply(total: 2);
      final body = reply['history'] as Map;
      final rows = body['rows'] as List;
      (rows[0] as Map).addAll(<String, dynamic>{
        'id': 'aa',
        'timeMs': 0,
        'included': false,
        'createdAt': 1,
      });
      (rows[1] as Map).addAll(<String, dynamic>{'id': 'zz', 'createdAt': 1});
      body['best'] = rows[1];
      final history = ServerAttemptHistory.fromJson(reply, owner: historyOwner);
      final model = MyAttemptsData(
        attempts: [],
        ranking: null,
        isPending: (_) => false,
        serverHistory: history,
      );
      expect(model.rows.map((r) => r.id), ['zz', 'aa']);
      expect(model.rows.last.timeMs, 0);
      expect(model.numberOf('aa'), 2);
      expect(model.numberOf('zz'), 1);
    },
  );
  test(
    'Instant pending request resolves to the server round without modifying its durable journal',
    () async {
      final account = HistoryAccount(
        (_) async => throw StateError('No network expected'),
      );
      final economy = EconomyStore();
      final raw = jsonEncode([
        {
          'owner': historyOwner,
          'requestId': 'local-request',
          'roundId': 'round-650',
          'cost': 3,
          'charged': true,
          'result': {'timeMs': 66000},
        },
      ]);
      final key = '${account.storagePrefix}instant_rounds_v1_$historyOwner';
      SharedPreferences.setMockInitialValues({key: raw});
      final journal = InstantRoundJournal(
        account: account,
        economy: economy,
        changed: () {},
        published: (_, _) async {},
        recoverResult: (_) => null,
        mayDeliver: () => false,
      );
      addTearDown(journal.dispose);
      addTearDown(economy.dispose);
      addTearDown(account.dispose);
      await journal.bindOwner();
      expect(journal.serverRoundIdFor('local-request'), 'round-650');
      final history = ServerAttemptHistory.fromJson(
        historyReply(),
        owner: historyOwner,
      );
      final model = MyAttemptsData(
        attempts: [
          LocalAttempt(
            id: 'local-request',
            timeMs: 66000,
            createdAt: DateTime.utc(2026),
          ),
        ],
        ranking: null,
        isPending: journal.pendingAttempt,
        serverIdOf: (id) => journal.serverRoundIdFor(id) ?? id,
        serverHistory: history,
      );
      expect(model.rows.length, 100);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), raw);
      account.changeOwner('another');
      expect(journal.serverRoundIdFor('local-request'), isNull);
      expect(account.calls, isEmpty);
    },
  );
  test(
    'Server points keep full context with only a page loaded, one current mean, true record/number',
    () {
      final history = ServerAttemptHistory.fromJson(
        historyReply(),
        owner: historyOwner,
      );
      final local = LocalAttempt(
        id: 'pending',
        timeMs: 999999,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1770000000000),
      );
      final data = MyAttemptsData(
        attempts: [history.rows.first.attempt, local],
        ranking: const AverageRanking(mine: AverageRankEntry(averageMs: 1)),
        isPending: (_) => true,
        serverHistory: history,
      );
      expect(data.rows.length, 101);
      expect(data.confirmed.length, 100);
      expect(data.averages['round-551'], 19505);
      expect(data.averages['pending'], isNull);
      expect(data.averageMs, 20000);
      expect(data.referenceAverageMs, isNull);
      expect(data.showsHistoricalAverage, true);
      expect(data.historyComplete, false);
      expect(data.numberOf('round-650'), 650);
      expect(data.numberOf('round-1'), 1);
      expect(data.numberOf('pending'), isNull);
      expect(data.best!.id, 'round-1');
      expect(data.bestTimeMs, 90000);
    },
  );
  test(
    'A legacy pending attempt with a canonical round key is not duplicated',
    () {
      final history = ServerAttemptHistory.fromJson(
        historyReply(),
        owner: historyOwner,
      );
      final data = MyAttemptsData(
        attempts: [
          LocalAttempt(
            id: 'legacy-local',
            timeMs: 66000,
            createdAt: DateTime.utc(2026),
          ),
        ],
        ranking: null,
        isPending: (_) => true,
        serverIdOf: (_) => 'round-650',
        serverHistory: history,
      );
      expect(data.rows.length, 100);
      expect(data.rows.any((r) => r.id == 'legacy-local'), false);
    },
  );
  test(
    'Owner, snapshot, ordering and duplicate boundaries reject invalid history',
    () {
      expect(
        () => ServerAttemptHistory.fromJson(
          historyReply(owner: 'other'),
          owner: historyOwner,
        ),
        throwsFormatException,
      );
      final first = ServerAttemptHistory.fromJson(
        historyReply(),
        owner: historyOwner,
      );
      for (final reply in [
        historyReply(offset: 100, snapshot: 'changed'),
        historyReply(offset: 99),
        historyReply(offset: 101),
      ]) {
        final next = ServerAttemptHistory.fromJson(reply, owner: historyOwner);
        expect(() => first.append(next), throwsFormatException);
      }
      final invalid = historyReply();
      final rows = (invalid['history'] as Map)['rows'] as List;
      rows[1] = rows[0];
      expect(
        () => ServerAttemptHistory.fromJson(invalid, owner: historyOwner),
        throwsFormatException,
      );
    },
  );
  test(
    'All 650 rows load in pages without a client limit and cache never becomes a delivery queue',
    () async {
      final account = HistoryAccount(
        (body) async =>
            historyReply(offset: int.tryParse('${body['cursor']}') ?? 0),
      );
      final store = ScoresStore(account: account);
      addTearDown(store.dispose);
      addTearDown(account.dispose);
      await store.loadAttemptHistory();
      while (store.serverAttemptHistory!.nextCursor != null) {
        await store.loadAttemptHistory(more: true);
      }
      expect(store.serverAttemptHistory!.rows.length, 650);
      expect(store.serverAttemptHistory!.complete, true);
      expect(account.calls.length, 7);
      expect(
        account.calls.every(
          (r) => r['action'] == 'attempts_history' && r['limit'] == 100,
        ),
        true,
      );
      expect(store.myAttempts, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = prefs.getKeys().singleWhere(
        (k) => k.startsWith('server_attempt_history_'),
      );
      expect(
        (jsonDecode(prefs.getString(cacheKey)!) as Map).containsKey('outbox'),
        false,
      );
      final restored = ScoresStore(account: account);
      addTearDown(restored.dispose);
      await restored.loadLocal();
      expect(restored.serverAttemptHistory!.rows.length, 100);
      expect(restored.serverAttemptHistory!.nextCursor, '100');
      expect(restored.serverAttemptHistory!.totalCount, 650);
      expect(restored.myAttempts, isEmpty);
    },
  );
  test(
    'Changed snapshot reloads the first page; network failure keeps verified data and retries',
    () async {
      var changed = false, fail = false;
      final account = HistoryAccount((body) async {
        if (fail) throw StateError('offline');
        if (body['cursor'] != null && !changed) {
          changed = true;
          throw const MobileApiError('attempt_history_changed');
        }
        return historyReply(
          total: changed ? 651 : 650,
          snapshot: changed ? 'snapshot-b' : 'snapshot-a',
          offset: int.tryParse('${body['cursor']}') ?? 0,
        );
      });
      final store = ScoresStore(account: account);
      addTearDown(store.dispose);
      addTearDown(account.dispose);
      await store.loadAttemptHistory();
      await store.loadAttemptHistory(more: true);
      expect(store.serverAttemptHistory!.snapshot, 'snapshot-b');
      expect(store.serverAttemptHistory!.rows.length, 100);
      expect(store.serverAttemptHistory!.rows.first.number, 651);
      fail = true;
      await store.loadAttemptHistory(more: true);
      expect(store.historyError, 'attempt_history_unavailable');
      expect(store.serverAttemptHistory!.rows.length, 100);
      fail = false;
      await store.loadAttemptHistory(more: true);
      expect(store.historyError, isNull);
      expect(store.serverAttemptHistory!.rows.length, 200);
    },
  );
  test(
    'Late reply cannot restore another owner or a superseded refresh',
    () async {
      final late = Completer<Map<String, dynamic>>();
      final account = HistoryAccount((_) => late.future);
      final store = ScoresStore(account: account);
      addTearDown(store.dispose);
      addTearDown(account.dispose);
      await store.loadLocal();
      final request = store.loadAttemptHistory();
      await Future<void>.delayed(Duration.zero);
      account.changeOwner('supabase:new-owner');
      late.complete(historyReply());
      await request;
      expect(store.serverAttemptHistory, isNull);
      expect(store.historyLoading, false);
      account.reply = (_) async => historyReply(owner: 'supabase:new-owner');
      await store.loadAttemptHistory();
      expect(store.serverAttemptHistory!.userId, 'supabase:new-owner');
      account.changeOwner(null);
      expect(store.serverAttemptHistory, isNull);
    },
  );
  test('Refresh generation wins over an older in-flight response', () async {
    final late = Completer<Map<String, dynamic>>();
    var count = 0;
    final account = HistoryAccount(
      (_) => ++count == 1
          ? late.future
          : Future.value(historyReply(snapshot: 'new')),
    );
    final store = ScoresStore(account: account);
    addTearDown(store.dispose);
    addTearDown(account.dispose);
    await store.loadLocal();
    final first = store.loadAttemptHistory();
    await Future<void>.delayed(Duration.zero);
    await store.loadAttemptHistory(refresh: true);
    late.complete(historyReply(snapshot: 'old'));
    await first;
    expect(store.serverAttemptHistory!.snapshot, 'new');
  });
  test(
    'Old endpoint fallback and corrupt read cache never invent a curve or erase the result journal',
    () async {
      final journal = jsonEncode({
        'attempts': [
          LocalAttempt(
            id: 'local',
            timeMs: 5000,
            shared: true,
            createdAt: DateTime.utc(2026),
          ).toJson(),
        ],
        'outbox': [],
      });
      SharedPreferences.setMockInitialValues({
        'server_attempt_history_v1_$historyOwner': '{broken',
        'mobile_score_state_v2_$historyOwner': journal,
      });
      final account = HistoryAccount(
        (_) async => throw const MobileApiError('action_invalid'),
      );
      final store = ScoresStore(account: account);
      addTearDown(store.dispose);
      addTearDown(account.dispose);
      await store.loadAttemptHistory();
      expect(store.serverAttemptHistory, isNull);
      expect(store.historyError, 'action_invalid');
      expect(store.myAttempts.single.id, 'local');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mobile_score_state_v2_$historyOwner'), journal);
      final data = MyAttemptsData(
        attempts: store.myAttempts,
        ranking: const AverageRanking(
          algorithm: AverageRanking.quadraticAlgorithm,
          mine: AverageRankEntry(
            averageMs: 20000,
            totalAttempts: 650,
            usedCount: 50,
          ),
        ),
        isPending: (_) => false,
      );
      expect(data.averages, isEmpty);
      expect(data.referenceAverageMs, isNull);
      expect(data.averageMs, 20000);
    },
  );
}
