import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:game_box/data/google_identity.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/ui/game_ui.dart';
import 'blue_glass_profile_test.dart' as profile;
import 'mobile_account_test.dart' as account_fixture;

class _Session implements GoogleIdentity, GoogleIdentitySession {
  int signouts = 0;
  bool fail = false;
  @override
  bool get configured => true;
  @override
  Future<String> token() async => 'fixture-token';
  @override
  Future<void> signOut() async {
    signouts++;
    if (fail) throw StateError('SDK unavailable');
  }
}

Map<String, Object?> _profile(bool linked) => {
  'ok': true,
  'profile': {
    'id': 'android:1',
    'nickname': 'MintPlayer',
    'googleLinked': linked,
    'googleName': linked ? 'Fixture' : null,
    'googleEmail': linked ? 'fixture@example.invalid' : null,
    'hideGoogleAccount': true,
    'walletVersion': linked ? 1 : 2,
    'wallet': {
      'energyVersion': 2,
      'energy': 47,
      'claimed': ['energy_google'],
      'batteries': [
        {'id': 'free', 'capacity': 20, 'startedAt': 1234},
      ],
    },
  },
};

http.Response _response(bool linked) =>
    http.Response(jsonEncode(_profile(linked)), 200);

class _UiAccount extends profile.ProfileTestAccount {
  int unlinks = 0;
  @override
  Future<void> unlinkGoogle(GoogleIdentity google) async {
    unlinks++;
    googleLinked = false;
    googleEmail = null;
    googleName = null;
    notifyListeners();
  }
}

void main() {
  for (final sdkFailure in [false, true]) {
    test(
      'Unlink preserves owner, credentials and progress; SDK failure $sdkFailure',
      () async {
        final vault = account_fixture.MemoryVault();
        final session = _Session()..fail = sdkFailure;
        final account = MobileAccount(
          vault: vault,
          client: MockClient((request) async {
            final input = jsonDecode(request.body) as Map;
            if (input['action'] == 'guest') return _response(true);
            expect(input['action'], 'google_unlink');
            expect(input['operationId'], matches(RegExp(r'^[a-f0-9]{64}$')));
            expect(request.headers['Authorization'], startsWith('Bearer '));
            return _response(false);
          }),
        );
        await account.load();
        final credentials = vault.value;
        final wallet = jsonEncode(account.wallet);
        await account.unlinkGoogle(session);
        expect(account.id, 'android:1');
        expect(account.nickname, 'MintPlayer');
        expect(account.googleLinked, false);
        expect(account.googleEmail, isNull);
        expect(account.googleName, isNull);
        expect(jsonEncode(account.wallet), wallet);
        expect(vault.value, credentials);
        expect(session.signouts, 1);
        expect(account.busy, false);
        expect(account.googleStage, isNull);
        account.dispose();
      },
    );
  }

  test('Unconfirmed server unlink retains link and SDK session', () async {
    final session = _Session();
    final account = MobileAccount(
      vault: account_fixture.MemoryVault(),
      client: MockClient((request) async {
        final input = jsonDecode(request.body) as Map;
        return input['action'] == 'guest'
            ? _response(true)
            : http.Response('{"ok":false,"error":"service_unavailable"}', 503);
      }),
    );
    await account.load();
    await expectLater(
      account.unlinkGoogle(session),
      throwsA(isA<MobileApiError>()),
    );
    expect(account.googleLinked, true);
    expect(session.signouts, 0);
    expect(account.busy, false);
    account.dispose();
  });

  test('Lost unlink acknowledgement retries the same receipt', () async {
    final keys = <String>[];
    final account = MobileAccount(
      vault: account_fixture.MemoryVault(),
      client: MockClient((request) async {
        final input = jsonDecode(request.body) as Map;
        if (input['action'] == 'guest') return _response(true);
        keys.add(input['operationId'] as String);
        if (keys.length == 1) {
          throw http.ClientException('Lost acknowledgement');
        }
        return _response(false);
      }),
    );
    await account.load();
    await expectLater(
      account.unlinkGoogle(_Session()),
      throwsA(isA<http.ClientException>()),
    );
    expect(account.googleLinked, true);
    await account.unlinkGoogle(_Session());
    expect(keys, hasLength(2));
    expect(keys[0], keys[1]);
    expect(account.googleLinked, false);
    account.dispose();
  });

  test(
    'Old profile response cannot restore a successfully removed link',
    () async {
      final old = Completer<http.Response>();
      final account = MobileAccount(
        vault: account_fixture.MemoryVault(),
        client: MockClient((request) async {
          final input = jsonDecode(request.body) as Map;
          if (input['action'] == 'profile') return old.future;
          return _response(input['action'] == 'guest');
        }),
      );
      await account.load();
      final refresh = account.refreshProfile();
      await account.unlinkGoogle(_Session());
      old.complete(_response(true));
      await refresh;
      expect(account.googleLinked, false);
      expect(account.googleEmail, isNull);
      account.dispose();
    },
  );

  test('A changed owner cannot receive an in-flight unlink response', () async {
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    final session = _Session();
    final account = MobileAccount(
      vault: account_fixture.MemoryVault(),
      client: MockClient((request) async {
        if ((jsonDecode(request.body) as Map)['action'] == 'guest') {
          return _response(true);
        }
        requested.complete();
        return response.future;
      }),
    );
    await account.load();
    final pending = account.unlinkGoogle(session);
    final rejected = expectLater(pending, throwsA(isA<MobileApiError>()));
    await requested.future;
    account.id = 'android:2';
    response.complete(_response(false));
    await rejected;
    expect(account.id, 'android:2');
    expect(session.signouts, 0);
    account.dispose();
  });

  test(
    'Confirmed disconnect then new link allocates a fresh unlink receipt',
    () async {
      final keys = <String>[];
      final account = MobileAccount(
        vault: account_fixture.MemoryVault(),
        client: MockClient((request) async {
          final input = jsonDecode(request.body) as Map;
          final action = input['action'];
          if (action == 'guest') return _response(true);
          if (action == 'profile') return _response(false);
          if (action == 'google_link') {
            final data = _profile(true);
            (data['profile'] as Map)['walletVersion'] = 3;
            return http.Response(jsonEncode(data), 200);
          }
          keys.add(input['operationId'] as String);
          if (keys.length == 1) throw http.ClientException('Lost ACK');
          final data = _profile(false);
          (data['profile'] as Map)['walletVersion'] = 4;
          return http.Response(jsonEncode(data), 200);
        }),
      );
      await account.load();
      await expectLater(
        account.unlinkGoogle(_Session()),
        throwsA(isA<http.ClientException>()),
      );
      await account.refreshProfile();
      await account.linkGoogle(_Session());
      await account.unlinkGoogle(_Session());
      expect(keys, hasLength(2));
      expect(keys[1], isNot(keys[0]));
      expect(account.googleLinked, false);
      account.dispose();
    },
  );

  for (final action in ['play_verify', 'wallet_operation']) {
    test('Late $action cannot resurrect an unlinked Google identity', () async {
      final old = Completer<http.Response>();
      final requested = Completer<void>();
      final account = MobileAccount(
        vault: account_fixture.MemoryVault(),
        client: MockClient((request) async {
          final input = jsonDecode(request.body) as Map;
          if (input['action'] == action) {
            requested.complete();
            return old.future;
          }
          return _response(input['action'] == 'guest');
        }),
      );
      await account.load();
      final pending = action == 'play_verify'
          ? account.verifyPlay('fixture-product', 'fixture-token')
          : account.walletOperation('fixture-operation', 'google_privacy', {
              'hide': true,
            });
      await requested.future;
      await account.unlinkGoogle(_Session());
      old.complete(_response(true));
      await pending;
      expect(account.googleLinked, false);
      expect(account.googleEmail, isNull);
      expect(account.googleName, isNull);
      account.dispose();
    });
  }

  testWidgets(
    'Quiet text disconnect asks first, cancel is inert and confirm reconnects UI',
    (tester) async {
      final account = _UiAccount()
        ..id = 'qa:profile'
        ..nickname = 'MintPlayer'
        ..googleLinked = true
        ..googleName = 'Fixture'
        ..googleEmail = 'fixture@example.invalid';
      await profile.mountProfile(tester, fixtureAccount: account, linked: true);
      final action = find.byKey(const ValueKey('profile-google-disconnect'));
      await tester.ensureVisible(action);
      final button = tester.widget<TextButton>(action);
      expect(button.style!.foregroundColor!.resolve({}), GameUi.muted);
      expect(button.style!.backgroundColor!.resolve({}), Colors.transparent);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Отключить Google?'), findsOneWidget);
      expect(account.unlinks, 0);
      await tester.tap(
        find.byKey(const ValueKey('profile-google-disconnect-confirm-cancel')),
      );
      await tester.pumpAndSettle();
      expect(account.unlinks, 0);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('profile-google-disconnect-confirm')),
      );
      await tester.pumpAndSettle();
      expect(account.unlinks, 1);
      expect(action, findsNothing);
      expect(find.byKey(const ValueKey('profile-google-link')), findsOneWidget);
      expect(find.text('Google отключён.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
