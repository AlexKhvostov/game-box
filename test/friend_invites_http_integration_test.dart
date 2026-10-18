import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/android_invite_source.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/google_identity.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';

class MemoryAccountVault implements AccountVault {
  String? raw;
  @override
  Future<String?> read() async => raw;
  @override
  Future<void> write(String value) async => raw = value;
  String get secret => (jsonDecode(raw!) as Map)['secret'] as String;
}

/// Actual IO transport, limited to this fixture's single localhost listener.
class LoopbackClient extends http.BaseClient {
  LoopbackClient(this.port) : _io = IOClient();
  final int port;
  final IOClient _io;
  int calls = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.scheme != 'http' ||
        request.url.host != '127.0.0.1' ||
        request.url.port != port) {
      throw StateError('Only the current private loopback fixture is allowed');
    }
    calls++;
    return _io.send(request);
  }

  @override
  void close() => _io.close();
}

class ActualHttp extends HttpOverrides {}

class SyntheticGoogle implements GoogleIdentity {
  SyntheticGoogle(this.value);
  final String value;
  @override
  bool get configured => true;
  @override
  Future<String> token() async => value;
}

class NoNativeSource implements AndroidInviteSource {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final file = Platform.environment['UNTOUCH_FRIEND_INVITES_CONTROL_FILE'];
  test(
    'real localhost controller SQL account invite wallet and canonical restore',
    () async {
      final meta = jsonDecode(File(file!).readAsStringSync()) as Map;
      expect(
        meta['dsn'],
        'mysql:host=127.0.0.1;port=43317;dbname=untouch_friend_invites_tests;charset=utf8mb4',
      );
      final endpoint = Uri.parse(meta['endpoint'] as String);
      expect(endpoint.host, '127.0.0.1');
      SharedPreferences.setMockInitialValues({});
      // Bypass flutter_test's synthetic HTTP 400 only inside this test's IO zone.
      // Neither global runtime nor production account/source code is changed.
      await HttpOverrides.runWithHttpOverrides(() async {
        final transport = LoopbackClient(endpoint.port);
        final vaultA = MemoryAccountVault(),
            vaultB = MemoryAccountVault(),
            vaultC = MemoryAccountVault();
        final health = jsonDecode((await transport.get(endpoint)).body) as Map;
        final revision = health['rulesRevision'] as String;
        final a = MobileAccount(
          vault: vaultA,
          client: transport,
          endpoint: endpoint,
          rulesRevision: revision,
        );
        final b = MobileAccount(
          vault: vaultB,
          client: transport,
          endpoint: endpoint,
          rulesRevision: revision,
        );
        final c = MobileAccount(
          vault: vaultC,
          client: transport,
          endpoint: endpoint,
          rulesRevision: revision,
        );
        final economy = EconomyStore();
        await economy.load();
        final bridge = MobileWalletBridge(b, economy);
        await bridge.load();
        final invites = MobileInvites(
          account: b,
          source: NoNativeSource(),
          startupResolved: true,
        );
        Future<Map<String, dynamic>> control(Map<String, dynamic> body) async {
          final response = await transport.post(
            endpoint.replace(path: '/api/fixture.php'),
            headers: {
              'Content-Type': 'application/json',
              'X-Fixture-Control': meta['controlSecret'] as String,
            },
            body: jsonEncode(body),
          );
          final data = Map<String, dynamic>.from(
            jsonDecode(response.body) as Map,
          );
          expect(response.statusCode, 200, reason: 'Private fixture control');
          expect(data['ok'], true);
          return data;
        }

        Future<SyntheticGoogle> identity(int subject) async => SyntheticGoogle(
          (await control({'action': 'token', 'subject': '$subject'}))['idToken']
              as String,
        );
        try {
          await a.load();
          await b.load();
          await c.load();
          expect(a.ready && b.ready && c.ready, true);
          final originalB = b.id;
          await a.rename('DartInviter');
          await b.rename('DartFriend');
          await c.rename('RestoredFriend');
          await control({
            'action': 'seed',
            'playerSecret': vaultA.secret,
            'tokens': 31,
          });
          await control({
            'action': 'seed',
            'playerSecret': vaultB.secret,
            'tokens': 17,
            'marker': 'B-original',
          });
          await control({
            'action': 'seed',
            'playerSecret': vaultC.secret,
            'tokens': 70,
            'marker': 'C-restored',
            'bestTimeMs': 45000,
          });
          await a.linkGoogle(await identity(701));
          await b.linkGoogle(await identity(702));
          await c.linkGoogle(await identity(703));
          await b.setGooglePrivacy(false);
          await bridge.flush();
          expect(economy.tokens, 17);
          expect(b.nickname, 'DartFriend');
          final aCode = InviteState.fromJson(
            Map<String, dynamic>.from(
              (await a.request({'action': 'invites_state'}))['invites'] as Map,
            ),
          ).ownCode;
          invites.start();
          await invites.refresh();
          final originalOwnCode = invites.state!.ownCode;
          await invites.bindManual(aCode);
          expect(invites.state!.inviterCode, aCode);
          expect(invites.state!.completedGames, 0);
          expect(invites.state!.bonusStatus, 'waiting_games');
          expect(economy.tokens, 17);
          String? lastRound;
          const finish = {
            'timeMs': 1000,
            'runDistance': 0,
            'riskCount': 0,
            'hadJump': false,
            'hadHelmet': false,
          };
          for (var n = 1; n <= 5; n++) {
            lastRound = await b.startRound();
            expect(lastRound, isNotNull, reason: 'Real HTTP round start');
            await b.finishRound(lastRound!, finish);
            await invites.refresh();
            await bridge.flush();
            expect(invites.state!.completedGames, n);
            expect(b.wallet!['tokens'], n < 5 ? 17 : 27);
            expect(economy.tokens, n < 5 ? 17 : 27);
          }
          expect(invites.state!.bonusStatus, 'rewarded');
          await a.refreshProfile();
          expect(a.wallet!['tokens'], 41);
          final paid = InviteState.fromJson(
            Map<String, dynamic>.from(
              (await a.request({'action': 'invites_state'}))['invites'] as Map,
            ),
          );
          expect(paid.rewardTotal, 10);
          expect(paid.paidRows.single.nickname, 'DartFriend');
          expect(paid.paidRows.single.amount, 10);
          expect(paid.paidRows.single.rewardedAt, greaterThan(0));
          expect(b.wallet!['lives'], 95);
          expect(b.wallet!['bestTimeMs'], 25000);
          expect(
            b.wallet!['plusUntil'],
            greaterThan(DateTime.now().millisecondsSinceEpoch),
          );
          expect(b.wallet!['claimed'], ['install_bonus']);
          expect(b.wallet!['_fixturePreserve'], 'B-original');
          expect(b.hideGoogleAccount, false);
          expect(b.googleEmail, 'fixture702@example.test');
          expect(economy.bestTimeMs, 25000);
          expect(economy.gamesStartedCount, 5);
          await b.finishRound(lastRound!, finish);
          await invites.bindManual(aCode);
          await invites.refresh();
          await bridge.flush();
          expect(economy.tokens, 27);
          final dbB = await control({
            'action': 'inspect',
            'playerId': int.parse(originalB!.split(':')[1]),
          });
          expect(dbB['ledgerRows'], 1);
          expect(dbB['ledgerSum'], 10);
          expect(dbB['finished'], 5);
          // The existing target has its own immutable inviter, wallet and outgoing code.
          await c.request({'action': 'invites_bind', 'code': aCode});
          await b.restoreGoogle(await identity(703));
          await invites.refresh();
          await bridge.flush();
          expect(b.id, c.id);
          expect(b.id, isNot(originalB));
          expect(invites.state!.profileId, c.id);
          expect(invites.state!.inviterCode, aCode);
          expect(invites.state!.ownCode, isNot(originalOwnCode));
          expect(b.nickname, 'RestoredFriend');
          expect(b.wallet!['_fixturePreserve'], 'C-restored');
          expect(economy.tokens, 70);
          expect(economy.bestTimeMs, 45000);
          expect(b.hideGoogleAccount, true);
          await expectLater(
            invites.bindManual(originalOwnCode),
            throwsA(
              isA<MobileApiError>().having(
                (e) => e.code,
                'code',
                'invite_already_bound',
              ),
            ),
          );
          final forged = await b.request({
            'action': 'profile',
            'playerId': a.id,
            'tokens': 99999,
          });
          expect((forged['profile'] as Map)['id'], c.id);
          expect((forged['profile'] as Map)['wallet']['tokens'], 70);
          final oldB = await control({
            'action': 'inspect',
            'playerId': int.parse(originalB.split(':')[1]),
          });
          expect((oldB['wallet'] as Map)['tokens'], 27);
          expect(oldB['ledgerRows'], 1);
          expect(transport.calls, greaterThan(45));
          debugPrint('Actual loopback HTTP requests: ${transport.calls}');
        } finally {
          invites.dispose();
          a.dispose();
          b.dispose();
          c.dispose();
          economy.dispose();
          transport.close();
        }
      }, ActualHttp());
    },
    skip: file == null,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
