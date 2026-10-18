import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/google_identity.dart';

class GoogleFixture implements GoogleIdentity {
  GoogleFixture({this.failure});
  final Exception? failure;
  int calls = 0;
  @override
  bool get configured => true;
  @override
  Future<String> token() async {
    calls++;
    if (failure != null) throw failure!;
    return 'fixture-id-token';
  }
}

class MemoryVault implements AccountVault {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async {
    if (failWrite) throw StateError('storage unavailable');
    value = data;
  }
}

void main() {
  test(
    'new Google link accepts server allocated counter nickname without another request',
    () async {
      final actions = <String>[];
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final action = (jsonDecode(request.body) as Map)['action'] as String;
          actions.add(action);
          return http.Response(
            jsonEncode({
              'ok': true,
              'profile': {
                'id': 'android:1',
                'nickname': action == 'google_link'
                    ? 'alexey.games_2'
                    : 'user00000001',
                'googleLinked': action == 'google_link',
                'googleEmail': action == 'google_link'
                    ? 'alexey.games@example.invalid'
                    : null,
                'walletVersion': 1,
                'wallet': {'tokens': 23},
              },
            }),
            200,
          );
        }),
      );
      await account.load();
      expect(account.nickname, 'user00000001');
      await account.linkGoogle(GoogleFixture());
      expect(account.nickname, 'alexey.games_2');
      expect(account.googleEmail, 'alexey.games@example.invalid');
      expect(account.wallet!['tokens'], 23);
      expect(actions, ['guest', 'google_link']);
      account.dispose();
    },
  );
  for (final outcome in [
    'success',
    'restore_failure',
    'pending_round',
    'other_link_error',
  ]) {
    test(
      'one Google selection automatically restores; $outcome preserves ownership',
      () async {
        final vault = MemoryVault();
        final actions = <String>[];
        final identity = GoogleFixture();
        String? selectedToken;
        final account = MobileAccount(
          vault: vault,
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map;
            final action = body['action'] as String;
            actions.add(action);
            if (action == 'google_link') {
              selectedToken = body['idToken'] as String;
              return http.Response(
                jsonEncode({
                  'ok': false,
                  'error': outcome == 'other_link_error'
                      ? 'google_already_linked'
                      : 'google_profile_exists',
                }),
                409,
              );
            }
            if (action == 'google_restore') {
              expect(body['idToken'], selectedToken);
              expect(request.headers['Authorization'], isNull);
              expect(
                body['secret'],
                (jsonDecode(vault.value!) as Map)['secret'],
              );
              if (outcome == 'restore_failure') {
                return http.Response(
                  '{"ok":false,"error":"service_unavailable"}',
                  503,
                );
              }
            }
            return http.Response(
              jsonEncode({
                'ok': true,
                'profile': {
                  'id': action == 'google_restore' ? 'android:2' : 'android:1',
                  'nickname': action == 'google_restore'
                      ? 'Returning'
                      : 'Guest',
                  'googleLinked': action == 'google_restore',
                  'walletVersion': action == 'google_restore' ? 1 : 9,
                  'wallet': {'tokens': action == 'google_restore' ? 7 : 23},
                },
              }),
              200,
            );
          }),
        );
        await account.load();
        final credentials = vault.value;
        account.beforeRound = () async {
          actions.add('flush');
        };
        account.beforeIdentityChange = () async {
          actions.add('before_identity');
          if (outcome == 'pending_round') {
            throw const MobileApiError('round_delivery_pending');
          }
        };
        if (outcome == 'success') {
          await account.linkGoogle(identity);
          expect(account.id, 'android:2');
          expect(account.nickname, 'Returning');
          expect(account.wallet!['tokens'], 7);
          expect(account.googleLinked, true);
        } else {
          await expectLater(
            account.linkGoogle(identity),
            throwsA(isA<MobileApiError>()),
          );
          if (outcome == 'restore_failure') {
            expect(account.ready, false);
            expect(account.id, isNull);
            expect(account.wallet, isNull);
            expect((jsonDecode(vault.value!) as Map)['owner'], isNull);
          } else {
            expect(account.id, 'android:1');
            expect(account.nickname, 'Guest');
            expect(account.wallet!['tokens'], 23);
            expect(account.googleLinked, false);
          }
        }
        expect(identity.calls, 1);
        final previous = jsonDecode(credentials!) as Map;
        final current = jsonDecode(vault.value!) as Map;
        expect(current['installation'], previous['installation']);
        expect(current['secret'], previous['secret']);
        expect(
          current['owner'],
          outcome == 'success'
              ? 'android:2'
              : outcome == 'restore_failure'
              ? null
              : 'android:1',
        );
        expect(account.busy, false);
        expect(account.googleStage, isNull);
        expect(
          actions.contains('google_restore'),
          outcome == 'success' || outcome == 'restore_failure',
        );
        expect(
          actions.contains('before_identity'),
          outcome != 'other_link_error',
        );
        account.dispose();
      },
    );
  }
  testWidgets(
    'Google accepts seven-second verification while ordinary requests keep timeout',
    (tester) async {
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final action = (jsonDecode(request.body) as Map)['action'];
          if (action != 'guest') {
            await Future<void>.delayed(const Duration(seconds: 7));
          }
          return http.Response(
            jsonEncode({
              'ok': true,
              'profile': {
                'id': 'android:1',
                'nickname': 'Guest',
                'googleLinked': action == 'google_link',
              },
            }),
            200,
          );
        }),
      );
      await account.load();
      var complete = false;
      final linking = account
          .linkGoogle(GoogleFixture())
          .then((_) => complete = true);
      await tester.pump();
      expect(account.googleStage, GoogleConnectionStage.verifying);
      await tester.pump(const Duration(seconds: 7));
      await linking;
      expect(complete, true);
      expect(account.googleLinked, true);
      expect(account.googleStage, isNull);
      Object? failure;
      final ordinary = account.request({'action': 'profile'}).catchError((
        Object e,
      ) {
        failure = e;
        return <String, dynamic>{};
      });
      await tester.pump(const Duration(seconds: 6));
      await ordinary;
      expect(failure, isA<TimeoutException>());
      await tester.pump(const Duration(seconds: 1));
      account.dispose();
    },
  );
  test(
    'Google preparation is visible, serialized, and failure unlocks retry',
    () async {
      final preparation = Completer<void>();
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient(
          (_) async => http.Response(
            '{"ok":true,"profile":{"id":"android:1","nickname":"Guest","googleLinked":false}}',
            200,
          ),
        ),
      );
      await account.load();
      account.beforeRound = () => preparation.future;
      final linking = account.linkGoogle(GoogleFixture());
      expect(account.googleStage, GoogleConnectionStage.preparing);
      await expectLater(
        account.linkGoogle(GoogleFixture()),
        throwsA(isA<MobileApiError>()),
      );
      preparation.complete();
      await expectLater(
        linking,
        throwsA(
          isA<MobileApiError>().having(
            (e) => e.code,
            'code',
            'google_not_linked',
          ),
        ),
      );
      expect(account.busy, false);
      expect(account.googleStage, isNull);
      account.dispose();
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  for (final restore in [false, true]) {
    test(
      'late profile refresh cannot undo Google ${restore ? "restore" : "link"}',
      () async {
        final stale = Completer<http.Response>();
        final started = Completer<void>();
        final account = MobileAccount(
          vault: MemoryVault(),
          client: MockClient((request) async {
            final action = (jsonDecode(request.body) as Map)['action'];
            if (action == 'profile') {
              started.complete();
              return stale.future;
            }
            final linked =
                action == 'google_link' || action == 'google_restore';
            return http.Response(
              jsonEncode({
                'ok': true,
                'profile': {
                  'id': linked && restore ? 'android:2' : 'android:1',
                  'nickname': linked && restore ? 'Restored' : 'Guest',
                  'googleLinked': linked,
                  'walletVersion': linked && restore ? 1 : 9,
                  'wallet': {'crystals': linked && restore ? 7 : 30},
                },
              }),
              200,
            );
          }),
        );
        await account.load();
        final refresh = account.refreshProfile();
        await started.future;
        if (restore) {
          await account.restoreGoogle(GoogleFixture());
        } else {
          await account.linkGoogle(GoogleFixture());
        }
        expect(account.googleLinked, true);
        stale.complete(
          http.Response(
            '{"ok":true,"profile":{"id":"android:1","nickname":"Guest","googleLinked":false,"walletVersion":9,"wallet":{"crystals":30}}}',
            200,
          ),
        );
        await refresh;
        expect(account.googleLinked, true);
        expect(account.id, restore ? 'android:2' : 'android:1');
        expect(account.wallet?['crystals'], restore ? 7 : 30);
        expect(account.busy, false);
      },
    );
  }
  test(
    'Google link and restore use verified token routes and reset wallet on identity change',
    () async {
      final vault = MemoryVault();
      final actions = <String>[];
      final account = MobileAccount(
        vault: vault,
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          final action = body['action'] as String;
          actions.add(action);
          if (action != 'guest') expect(body['idToken'], 'fixture-id-token');
          if (action == 'google_link') {
            expect(request.headers['Authorization'], startsWith('Bearer '));
          }
          if (action == 'google_restore') {
            expect(request.headers['Authorization'], isNull);
            final saved = jsonDecode(vault.value!) as Map;
            expect(body['secret'], saved['secret']);
            expect(body['installation'], saved['installation']);
          }
          return http.Response(
            jsonEncode({
              'ok': true,
              'profile': {
                'id': action == 'google_restore' ? 'android:2' : 'android:1',
                'nickname': action == 'google_restore' ? 'Restored' : 'Guest',
                'googleLinked': action != 'guest',
                'walletVersion': action == 'google_restore' ? 1 : 9,
                'wallet': {'crystals': action == 'google_restore' ? 7 : 30},
              },
            }),
            200,
          );
        }),
      );
      await account.load();
      await account.linkGoogle(GoogleFixture());
      expect(account.googleLinked, true);
      expect(account.id, 'android:1');
      await account.restoreGoogle(GoogleFixture());
      expect(account.id, 'android:2');
      expect(account.wallet?['crystals'], 7);
      expect(account.busy, false);
      expect(actions, ['guest', 'google_link', 'google_restore']);
    },
  );
  test(
    'rejected Google restore preserves the current profile and credentials',
    () async {
      final vault = MemoryVault();
      var identityRequests = 0;
      final account = MobileAccount(
        vault: vault,
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (body['action'] == 'guest') {
            return http.Response(
              '{"ok":true,"profile":{"id":"android:1","nickname":"Guest"}}',
              200,
            );
          }
          identityRequests++;
          return http.Response(
            '{"ok":false,"error":"google_profile_not_found"}',
            404,
          );
        }),
      );
      await account.load();
      final credentials = vault.value;
      await expectLater(
        account.restoreGoogle(GoogleFixture()),
        throwsA(isA<MobileApiError>()),
      );
      expect(account.id, 'android:1');
      expect(account.googleLinked, false);
      expect(vault.value, credentials);
      expect(account.busy, false);
      await expectLater(
        account.linkGoogle(
          GoogleFixture(failure: const MobileApiError('google_token_missing')),
        ),
        throwsA(isA<MobileApiError>()),
      );
      expect(identityRequests, 1);
      expect(account.id, 'android:1');
      expect(account.busy, false);
    },
  );
  test(
    'credentials persist before registration and survive a lost response',
    () async {
      final vault = MemoryVault();
      final requests = <Map>[];
      var failure = true;
      final client = MockClient((request) async {
        expect(vault.value, isNotNull);
        final body = jsonDecode(request.body) as Map;
        requests.add(body);
        expect(body['installation'], matches(r'^[a-f0-9]{32}$'));
        expect(body['secret'], matches(r'^[a-f0-9]{64}$'));
        if (failure) throw StateError('lost response');
        return http.Response(
          jsonEncode({
            'ok': true,
            'profile': {
              'id': 'android:21',
              'nickname': 'user00000021',
              'googleLinked': false,
            },
          }),
          200,
        );
      });
      final first = MobileAccount(vault: vault, client: client);
      await first.load();
      expect(first.ready, false);
      failure = false;
      final second = MobileAccount(vault: vault, client: client);
      await second.load();
      expect(second.nickname, 'user00000021');
      expect(requests[0], requests[1]);
    },
  );
  test(
    'failed secure persistence never registers an unresumable player',
    () async {
      final vault = MemoryVault()..failWrite = true;
      var requests = 0;
      final account = MobileAccount(
        vault: vault,
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      await account.load();
      expect(requests, 0);
      expect(account.ready, false);
    },
  );
  test(
    'concurrent registration is coalesced and nickname changes only after server success',
    () async {
      final waiting = Completer<http.Response>();
      var guests = 0;
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (body['action'] == 'guest') {
            guests++;
            return waiting.future;
          }
          expect(request.headers['Authorization'], startsWith('Bearer '));
          return http.Response('{"ok":false,"error":"nickname_taken"}', 409);
        }),
      );
      final a = account.load(), b = account.load();
      await Future<void>.delayed(Duration.zero);
      expect(guests, 1);
      waiting.complete(
        http.Response(
          '{"ok":true,"profile":{"id":"android:1","nickname":"user00000001"}}',
          200,
        ),
      );
      await Future.wait([a, b]);
      await expectLater(
        account.rename('Taken'),
        throwsA(isA<MobileApiError>()),
      );
      expect(account.nickname, 'user00000001');
      expect(account.busy, false);
    },
  );
}
