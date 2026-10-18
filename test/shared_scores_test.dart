import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/scores_store.dart';
import 'mobile_account_test.dart' show MemoryVault;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Android loads platform-neutral server periods and sorts by time',
    () async {
      final requested = <String>{};
      final store = ScoresStore(
        account: MobileAccount(vault: MemoryVault()),
        client: MockClient((request) async {
          requested.add(request.url.queryParameters['period']!);
          return http.Response(
            jsonEncode({
              'ok': true,
              'source': 'mysql',
              'scores': [
                {
                  'id': '1',
                  'userId': 'android:1',
                  'playerName': 'Android',
                  'timeMs': 2000,
                  'createdAt': 1,
                  'runDistance': 100,
                },
                {
                  'id': '2',
                  'userId': '22',
                  'playerName': 'Telegram',
                  'timeMs': 3000,
                  'createdAt': 1,
                  'runDistance': 1,
                },
              ],
            }),
            200,
          );
        }),
      );
      await store.load();
      expect(store.online, true);
      expect(requested, {'all', 'day', 'week', 'month', 'year'});
      expect(store.scores.map((e) => e.displayName), ['Telegram', 'Android']);
      await expectLater(
        store.saveScore(displayName: 'Fake', timeMs: 99999),
        throwsA(isA<MobileApiError>()),
      );
      expect(store.scores, hasLength(2));
    },
  );
  test(
    'lost finish is queued across restart and marked published only after acknowledgement',
    () async {
      var finishes = 0;
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (body['action'] == 'guest' || body['action'] == 'profile') {
            return http.Response(
              '{"ok":true,"profile":{"id":"android:1","nickname":"user00000001"}}',
              200,
            );
          }
          if (body['action'] == 'round_start') {
            return http.Response(
              jsonEncode({'ok': true, 'roundId': body['requestId']}),
              200,
            );
          }
          finishes++;
          if (finishes < 3) throw StateError('response lost');
          return http.Response('{"ok":true,"scoreId":"11"}', 200);
        }),
      );
      await account.load();
      final board = MockClient(
        (_) async =>
            http.Response('{"ok":true,"source":"mysql","scores":[]}', 200),
      );
      final first = ScoresStore(account: account, client: board);
      await first.load();
      await first.beginRound();
      await first.recordAttempt(1000);
      await first.retryPendingResults();
      expect(first.myAttempts.single.shared, false);
      final prefs = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(prefs.getString('mobile_score_state_v2_android:1')!)
            as Map)['outbox'],
        hasLength(1),
      );
      final restarted = ScoresStore(account: account, client: board);
      await restarted.load();
      expect(restarted.myAttempts.single.shared, false);
      await restarted.retryPendingResults();
      expect(restarted.myAttempts.single.shared, true);
      expect(
        (jsonDecode(prefs.getString('mobile_score_state_v2_android:1')!)
            as Map)['outbox'],
        isEmpty,
      );
      await restarted.load();
      expect(finishes, 3);
      first.dispose();
      restarted.dispose();
      account.dispose();
    },
  );
}
