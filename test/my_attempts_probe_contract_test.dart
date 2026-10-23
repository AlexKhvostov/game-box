import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tools/my_attempts_probe.dart' as probe;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    probe.unexpectedNetwork.clear();
  });
  test(
    'QA exercises the production store with isolated 100/100/32 server-contract pages',
    () async {
      final account = probe.ProbeAccount();
      final store = probe.ProbeScores(account);
      addTearDown(store.dispose);
      addTearDown(account.dispose);
      await store.setFixture('filled');
      final average = store.serverAttemptHistory!.average.mine.averageMs;
      expect(store.serverAttemptHistory!.rows.length, 100);
      expect(store.serverAttemptHistory!.totalCount, 232);
      expect(store.serverAttemptHistory!.best!.number, 1);
      expect(store.serverAttemptHistory!.best!.attempt.timeMs, 65000);
      expect(
        store.serverAttemptHistory!.rows.any((row) => row.number == 1),
        false,
      );
      await store.loadAttemptHistory(more: true);
      expect(store.serverAttemptHistory!.rows.length, 200);
      await store.loadAttemptHistory(more: true);
      expect(store.serverAttemptHistory!.rows.length, 232);
      expect(store.serverAttemptHistory!.nextCursor, isNull);
      expect(store.serverAttemptHistory!.average.mine.averageMs, average);
      expect(account.historyCalls.length, 3);
      expect(account.historyCalls.map((call) => call['cursor']), [
        null,
        'qa${probe.qaBuild}_filled:100',
        'qa${probe.qaBuild}_filled:200',
      ]);
      expect(
        store.serverAttemptHistory!.rows
            .map((row) => row.averageMs)
            .toSet()
            .length,
        greaterThan(10),
      );
      expect(store.myAttempts, isEmpty);
      expect(probe.unexpectedNetwork, isEmpty);
    },
  );
  test(
    'QA long/pending fixtures keep the server total independent of local pending data',
    () async {
      final account = probe.ProbeAccount();
      final store = probe.ProbeScores(account);
      addTearDown(store.dispose);
      addTearDown(account.dispose);
      await store.setFixture('long');
      expect(store.serverAttemptHistory!.totalCount, 900);
      expect(store.serverAttemptHistory!.rows.length, 100);
      await store.setFixture('pending');
      expect(store.serverAttemptHistory!.totalCount, 232);
      expect(store.myAttempts.single.id, 'pending-233');
      expect(
        store.serverAttemptHistory!.rows.any(
          (row) => row.attempt.id == 'pending-233',
        ),
        false,
      );
      expect(probe.unexpectedNetwork, isEmpty);
    },
  );
}
