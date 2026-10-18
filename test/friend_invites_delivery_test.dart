import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:game_box/data/invite_code.dart';
import 'package:game_box/data/android_invite_source.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/google_identity.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/app/google_startup.dart';

const codeA = 'ABCDEFGH2345';
const codeC = 'JKLMNPQR6789';
const ownGuest = 'AAAAAAAAAAAA';
const ownRestored = 'BBBBBBBBBBBB';

class Vault implements InviteVault {
  String? raw;
  int fails = 0;
  @override
  Future<String?> read() async => raw;
  @override
  Future<void> write(String value) async {
    if (fails-- > 0) throw const MobileApiError('invite_storage_failed');
    raw = value;
  }
}

class Source implements AndroidInviteSource {
  final urls = <String>[];
  final referrers = <InviteReferrer>[];
  Completer<InviteReferrer>? heldReferrer;
  int reads = 0, acknowledgements = 0;
  VoidCallback? available;
  void Function(String)? beforeAck;
  @override
  void listen(VoidCallback onAvailable) => available = onAvailable;
  @override
  Future<String?> peekAppLink() async => urls.isEmpty ? null : urls.first;
  @override
  Future<void> acknowledgeAppLink(String url) async {
    beforeAck?.call(url);
    expect(urls.first, url);
    urls.removeAt(0);
    acknowledgements++;
  }

  @override
  Future<InviteReferrer> readInstallReferrer() async {
    reads++;
    if (heldReferrer != null) return heldReferrer!.future;
    return referrers.isEmpty
        ? const InviteReferrer(InviteReferrerStatus.absent)
        : referrers.removeAt(0);
  }

  @override
  void dispose() => available = null;
}

class Account extends MobileAccount {
  Account({bool linked = true}) {
    id = 'android:1';
    nickname = 'Guest';
    googleLinked = linked;
  }
  final bindings = <Map<String, dynamic>>[];
  final inviters = <String, String?>{};
  Completer<Map<String, dynamic>>? hold;
  String? failure;
  int requests = 0, refreshes = 0;
  List<Map<String, Object?>> paid = [];
  String? cursor;
  Map<String, dynamic> data(String owner) => {
    'invites': {
      'profileId': owner,
      'ownCode': owner == 'android:1' ? ownGuest : ownRestored,
      'inviteUrl': InviteCode.url(
        owner == 'android:1' ? ownGuest : ownRestored,
      ),
      'inviterAssigned': inviters[owner] != null,
      'inviterCode': inviters[owner],
      'googleLinked': googleLinked,
      'completedGames': 5,
      'bonusStatus': inviters[owner] == null
          ? 'unbound'
          : (googleLinked ? 'rewarded' : 'waiting_google'),
      'reward': 10,
      'requiredGames': 5,
      'rewardTotal': 100,
      'paidRows': paid,
      'nextCursor': cursor,
    },
  };
  @override
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> payload, {
    bool guest = false,
  }) async {
    requests++;
    final owner = id!;
    if (hold != null && payload['action'] == 'invites_state') {
      final pending = hold!;
      hold = null;
      return pending.future;
    }
    if (failure != null) throw MobileApiError(failure!);
    if (payload['action'] == 'invites_bind') {
      final code = payload['code'] as String;
      if (!{codeA, codeC}.contains(code)) {
        throw const MobileApiError('invite_not_found');
      }
      if (inviters[owner] != null && inviters[owner] != code) {
        throw const MobileApiError('invite_already_bound');
      }
      bindings.add({'owner': owner, ...payload});
      inviters[owner] = code;
    }
    return data(owner);
  }

  @override
  Future<void> refreshProfile() async {
    refreshes++;
  }

  void resolve({required bool linked, String? owner}) {
    if (owner != null) id = owner;
    googleLinked = linked;
    busy = false;
    googleStage = null;
    notifyListeners();
  }
}

/// Hold a rejected request until identity changes; successful replies already have owner guards.
class HeldActionAccount extends Account {
  HeldActionAccount(this.action, {super.linked});
  final String action;
  final entered = Completer<void>();
  final reply = Completer<Map<String, dynamic>>();
  bool held = false;
  int matchingCalls = 0;

  @override
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> payload, {
    bool guest = false,
  }) {
    if (payload['action'] == action) {
      matchingCalls++;
      if (!held) {
        held = true;
        entered.complete();
        return reply.future;
      }
    }
    return super.request(payload, guest: guest);
  }
}

MobileInvites service(
  Account account,
  Source source,
  Vault vault, {
  bool resolved = true,
  bool enabled = true,
}) {
  final result = MobileInvites(
    account: account,
    source: source,
    vault: vault,
    startupResolved: resolved,
    enabled: enabled,
    retryDelay: const Duration(days: 1),
  );
  addTearDown(result.dispose);
  return result;
}

class Identity implements GoogleIdentity {
  final pending = Completer<String>();
  @override
  bool get configured => true;
  @override
  Future<String> token() => pending.future;
}

class GateAccount extends Account {
  GateAccount() : super(linked: false);
  @override
  Future<void> linkGoogle(GoogleIdentity google) async {
    busy = true;
    googleStage = GoogleConnectionStage.choosingAccount;
    notifyListeners();
    try {
      await google.token();
      googleLinked = true;
    } finally {
      busy = false;
      googleStage = null;
      notifyListeners();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final rejection in [
    'invite_self',
    'invite_code_invalid',
    'invite_not_found',
    'invite_already_bound',
    'action_invalid',
    'service_unavailable',
  ]) {
    test(
      'stale automatic bind $rejection preserves delivery for restored owner',
      () async {
        final account = HeldActionAccount('invites_bind', linked: false);
        final source = Source()..urls.add(InviteCode.url(codeA));
        final vault = Vault();
        final invites = service(account, source, vault)..start();
        await account.entered.future;
        account.resolve(linked: true, owner: 'android:2');
        account.reply.completeError(MobileApiError(rejection));
        await invites.refresh();
        expect(account.inviters['android:2'], codeA);
        expect(account.matchingCalls, 2);
        expect(account.bindings.single['owner'], 'android:2');
        expect(invites.state!.ownCode, ownRestored);
        expect(invites.error, isNull);
      },
    );
  }
  for (final rejection in [
    'invite_self',
    'action_invalid',
    'service_unavailable',
  ]) {
    test(
      'stale manual bind $rejection reports profile_changed without consuming incoming delivery',
      () async {
        final account = HeldActionAccount('invites_bind', linked: false);
        final source = Source()..urls.add(InviteCode.url(codeC));
        final vault = Vault();
        final invites = service(account, source, vault, resolved: false)
          ..start();
        await invites.refresh();
        expect(invites.pendingCode, codeC);
        final manual = invites.bindManual(codeA);
        await account.entered.future;
        final rejected = expectLater(
          manual,
          throwsA(
            isA<MobileApiError>().having(
              (e) => e.code,
              'code',
              'profile_changed',
            ),
          ),
        );
        account.resolve(linked: true, owner: 'android:2');
        account.reply.completeError(MobileApiError(rejection));
        await rejected;
        await invites.refresh();
        expect(account.inviters['android:2'], codeC);
        expect(account.bindings.single['code'], codeC);
        expect(invites.state!.profileId, 'android:2');
        expect(invites.error, isNull);
      },
    );
  }
  test(
    'stale paid-page rejection cannot affect restored state or error',
    () async {
      final account = HeldActionAccount('invites_list')
        ..paid = [
          {'id': '8', 'nickname': 'Old owner', 'rewardedAt': 1, 'amount': 10},
        ]
        ..cursor = '8';
      final invites = service(account, Source(), Vault())..start();
      await invites.refresh();
      final page = invites.loadMore();
      await account.entered.future;
      account.paid = [
        {'id': '99', 'nickname': 'New owner', 'rewardedAt': 1, 'amount': 10},
      ];
      account.cursor = null;
      account.resolve(linked: true, owner: 'android:2');
      account.reply.completeError(const MobileApiError('invite_page_invalid'));
      await page;
      await invites.refresh();
      expect(invites.state!.profileId, 'android:2');
      expect(invites.state!.paidRows.single.id, '99');
      expect(invites.error, isNull);
    },
  );
  for (final rejection in [
    'invite_self',
    'invite_code_invalid',
    'invite_not_found',
  ]) {
    test(
      'current-owner terminal bind $rejection still clears invalid delivery once',
      () async {
        final account = HeldActionAccount('invites_bind');
        final vault = Vault();
        final invites = service(
          account,
          Source()..urls.add(InviteCode.url(codeA)),
          vault,
        )..start();
        await account.entered.future;
        account.reply.completeError(MobileApiError(rejection));
        await invites.refresh();
        await invites.refresh();
        expect(invites.pendingCode, isNull);
        expect(account.matchingCalls, 1);
        expect((jsonDecode(vault.raw!) as Map)['pending'], isNull);
      },
    );
  }
  test('app-link parser accepts only scoped public HTTPS addresses', () {
    expect(InviteCode.normalize('ABCDEFGſ2345'), isNull);
    expect(InviteCode.fromAppLink(InviteCode.url(codeA)), codeA);
    expect(
      InviteCode.fromAppLink('${InviteCode.url(codeA.toLowerCase())}/'),
      codeA,
    );
    for (final value in [
      'http://untouch.fun/a/$codeA',
      'https://untouch.fun.evil/a/$codeA',
      'https://evil@untouch.fun/a/$codeA',
      'https://untouch.fun:443/a/$codeA',
      'https://untouch.fun/i/$codeA',
      'https://untouch.fun/a/$codeA?invite=$codeC',
      'https://untouch.fun/a/$codeA#other',
      'https://untouch.fun/a/%41BCDEFGH2345',
      'https://untouch.fun/a/$codeA/more',
      'x' * 2049,
      null,
    ]) {
      expect(InviteCode.fromAppLink(value), isNull, reason: '$value');
    }
  });
  test(
    'bounded referrer rejects duplicates, bad encodings and unrelated organic installs',
    () {
      expect(InviteCode.fromReferrer('invite=$codeA'), codeA);
      expect(
        InviteCode.fromReferrer(
          'utm_source=friend&invite=${codeA.toLowerCase()}',
        ),
        codeA,
      );
      for (final value in [
        'invite=$codeA&invite=$codeC',
        'invite=short',
        'invite%3D$codeA',
        'invite=%ZZ',
        'invite=%FF',
        'invite=$codeA#x',
        'utm_source=google-play',
        'x' * 4097,
        null,
      ]) {
        expect(InviteCode.fromReferrer(value), isNull, reason: '$value');
      }
    },
  );
  test(
    'cold URL persists before native acknowledgement and binds once',
    () async {
      final account = Account();
      final source = Source()..urls.add(InviteCode.url(codeA));
      final vault = Vault();
      source.beforeAck = (_) =>
          expect((jsonDecode(vault.raw!) as Map)['pending']['code'], codeA);
      final invites = service(account, source, vault)..start();
      await invites.refresh();
      expect(account.bindings.single['code'], codeA);
      expect(source.acknowledgements, 1);
      expect(invites.state!.inviterCode, codeA);
      expect(invites.pendingCode, isNull);
      await invites.refresh();
      expect(account.bindings.length, 1);
    },
  );
  test(
    'storage failure never acknowledges unpersisted native delivery',
    () async {
      final account = Account();
      final source = Source()..urls.add(InviteCode.url(codeA));
      final vault = Vault()..fails = 1;
      final invites = service(account, source, vault);
      await invites.refresh();
      expect(source.acknowledgements, 0);
      expect(account.bindings, isEmpty);
      source.beforeAck = (_) =>
          expect((jsonDecode(vault.raw!) as Map)['pending']['code'], codeA);
      await invites.refresh();
      expect(account.bindings.length, 1);
      expect(source.acknowledgements, 1);
    },
  );
  test(
    'startup/native chooser block guest binding until final resolution',
    () async {
      final account = Account(linked: false);
      final source = Source()..urls.add(InviteCode.url(codeA));
      final vault = Vault();
      final invites = service(account, source, vault, resolved: false)..start();
      await invites.refresh();
      expect(account.bindings, isEmpty);
      expect(invites.pendingCode, codeA);
      account.busy = true;
      account.googleStage = GoogleConnectionStage.choosingAccount;
      account.notifyListeners();
      invites.markStartupResolved();
      await invites.refresh();
      expect(account.bindings, isEmpty);
      account.resolve(linked: false);
      await invites.refresh();
      expect(account.bindings.single['owner'], 'android:1');
      expect(invites.pendingCode, codeA);
    },
  );
  test(
    'cancelled guest binding survives restart and applies after existing Google restore',
    () async {
      final account = Account(linked: false);
      final source = Source()..urls.add(InviteCode.url(codeA));
      final vault = Vault();
      final invites = service(account, source, vault)..start();
      await invites.refresh();
      expect(invites.pendingCode, codeA);
      invites.dispose();
      final restored = Account()..id = 'android:2';
      final next = service(restored, Source(), vault)..start();
      await next.refresh();
      expect(restored.bindings.single['owner'], 'android:2');
      expect(next.state!.ownCode, ownRestored);
      expect(next.pendingCode, isNull);
      expect((jsonDecode(vault.raw!) as Map)['pending'], isNull);
    },
  );
  test(
    'new Google on same guest resolves pending without another bind',
    () async {
      final account = Account(linked: false);
      final vault = Vault();
      final invites = service(
        account,
        Source()..urls.add(InviteCode.url(codeA)),
        vault,
      )..start();
      await invites.refresh();
      account.resolve(linked: true);
      await invites.refresh();
      expect(account.bindings.length, 1);
      expect(invites.pendingCode, isNull);
      expect(invites.state!.ownCode, ownGuest);
    },
  );
  test('existing canonical inviter beats late automatic referrer', () async {
    final account = Account()..inviters['android:1'] = codeC;
    final source = Source()
      ..referrers.add(
        const InviteReferrer(InviteReferrerStatus.available, 'invite=$codeA'),
      );
    final invites = service(account, source, Vault())..start();
    await invites.refresh();
    expect(account.bindings, isEmpty);
    expect(invites.state!.inviterCode, codeC);
    expect(invites.pendingCode, isNull);
  });
  test('invalid first code does not consume valid second app link', () async {
    final source = Source()
      ..urls.addAll([InviteCode.url('ZZZZZZZZZZZZ'), InviteCode.url(codeA)]);
    final account = Account();
    final invites = service(account, source, Vault())..start();
    await invites.refresh();
    expect(account.bindings.single['code'], codeA);
    expect(source.acknowledgements, 2);
    expect(invites.error, isNull);
  });
  test(
    'two valid links keep first committed inviter without replacing it',
    () async {
      final source = Source()
        ..urls.addAll([InviteCode.url(codeA), InviteCode.url(codeC)]);
      final account = Account();
      final invites = service(account, source, Vault())..start();
      await invites.refresh();
      expect(account.bindings.length, 1);
      expect(invites.state!.inviterCode, codeA);
    },
  );
  test(
    'SDK temporary failure retries, definitive invalid source is consumed once',
    () async {
      final source = Source()
        ..referrers.addAll([
          const InviteReferrer(InviteReferrerStatus.retry),
          const InviteReferrer(InviteReferrerStatus.available, 'invite=bad'),
        ]);
      final account = Account();
      final invites = service(account, source, Vault());
      await invites.refresh();
      await invites.refresh();
      await invites.refresh();
      expect(source.reads, 2);
      expect(account.bindings, isEmpty);
    },
  );
  test(
    'API offline keeps incoming code durable for next synchronization',
    () async {
      final account = Account()..failure = 'service_unavailable';
      final source = Source()..urls.add(InviteCode.url(codeA));
      final vault = Vault();
      final invites = service(account, source, vault);
      await invites.refresh();
      expect(invites.pendingCode, codeA);
      expect((jsonDecode(vault.raw!) as Map)['pending']['code'], codeA);
      account.failure = null;
      await invites.refresh();
      expect(account.bindings.length, 1);
    },
  );
  test(
    'wrong code is terminal, cannot loop or consume future manual binding',
    () async {
      final source = Source()
        ..referrers.add(
          const InviteReferrer(
            InviteReferrerStatus.available,
            'invite=ZZZZZZZZZZZZ',
          ),
        );
      final account = Account();
      final invites = service(account, source, Vault());
      await invites.refresh();
      await invites.refresh();
      expect(source.reads, 1);
      expect(invites.pendingCode, isNull);
      await invites.bindManual(codeC);
      expect(invites.state!.inviterCode, codeC);
    },
  );
  test('manual accepted code is protected from later source', () async {
    final account = Account();
    final source = Source();
    final invites = service(account, source, Vault())..start();
    await invites.bindManual(codeC);
    source.urls.add(InviteCode.url(codeA));
    await invites.refresh();
    expect(account.bindings.length, 1);
    expect(invites.state!.inviterCode, codeC);
    await expectLater(
      invites.bindManual('bad'),
      throwsA(isA<MobileApiError>()),
    );
    expect(account.bindings.length, 1);
  });
  test(
    'old response cannot show guest outgoing code after owner restore',
    () async {
      final account = Account();
      final source = Source();
      final invites = service(account, source, Vault())..start();
      await invites.refresh();
      final response = Completer<Map<String, dynamic>>();
      account.hold = response;
      final old = invites.refresh();
      await Future<void>.delayed(Duration.zero);
      account.resolve(linked: true, owner: 'android:2');
      expect(invites.state, isNull);
      response.complete(account.data('android:1'));
      await old;
      await invites.refresh();
      expect(invites.state!.profileId, 'android:2');
      expect(invites.state!.ownCode, ownRestored);
    },
  );
  test('old request error cannot overwrite restored owner state', () async {
    final account = Account();
    final invites = service(account, Source(), Vault())..start();
    await invites.refresh();
    final response = Completer<Map<String, dynamic>>();
    account.hold = response;
    final old = invites.refresh();
    await Future<void>.delayed(Duration.zero);
    account.resolve(linked: true, owner: 'android:2');
    response.completeError(const MobileApiError('service_unavailable'));
    await old;
    await invites.refresh();
    expect(invites.state!.profileId, 'android:2');
    expect(invites.error, isNull);
  });
  test(
    'paid pagination merges by ledger ID and keeps canonical total',
    () async {
      final account = Account()
        ..paid = [
          {'id': '8', 'nickname': 'First', 'rewardedAt': 1, 'amount': 10},
        ]
        ..cursor = '8';
      final invites = service(account, Source(), Vault())..start();
      await invites.refresh();
      account.paid = [
        {'id': '8', 'nickname': 'First', 'rewardedAt': 1, 'amount': 10},
        {'id': '7', 'nickname': null, 'rewardedAt': 1, 'amount': 10},
      ];
      account.cursor = null;
      await invites.loadMore();
      expect(invites.state!.paidRows.length, 2);
      expect(invites.state!.rewardTotal, 100);
    },
  );
  test(
    'disabled isolated probe does not invoke source, store or network',
    () async {
      final account = Account();
      final source = Source()..urls.add(InviteCode.url(codeA));
      final vault = Vault();
      final invites = service(account, source, vault, enabled: false)..start();
      await invites.refresh();
      expect(account.requests, 0);
      expect(source.reads, 0);
      expect(vault.raw, isNull);
    },
  );
  test('real preference vault survives a new service instance', () async {
    SharedPreferences.setMockInitialValues({});
    final vault = PreferencesInviteVault();
    await vault.write('{"pending":{"code":"$codeA"},"referrerDone":false}');
    expect(await PreferencesInviteVault().read(), contains(codeA));
  });
  test(
    'native channel maps retry/absent/available and acknowledges explicit URI',
    () async {
      const channel = MethodChannel('untouch/invites');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'peekAppLink') return InviteCode.url(codeA);
            if (call.method == 'readReferrer') {
              return {'status': 'available', 'value': 'invite=$codeA'};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final native = NativeAndroidInviteSource(channel: channel);
      expect(await native.peekAppLink(), InviteCode.url(codeA));
      await native.acknowledgeAppLink(InviteCode.url(codeA));
      expect(
        (await native.readInstallReferrer()).status,
        InviteReferrerStatus.available,
      );
      expect(calls[1].arguments, {'url': InviteCode.url(codeA)});
    },
  );
  testWidgets('startup signal waits for actual chooser completion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PlayerPreferences();
    await preferences.load();
    final account = GateAccount();
    final source = Source()..urls.add(InviteCode.url(codeA));
    final invites = service(account, source, Vault(), resolved: false)..start();
    final identity = Identity();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MobileAccount>.value(value: account),
          ChangeNotifierProvider.value(value: preferences),
          ChangeNotifierProvider.value(value: invites),
        ],
        child: MaterialApp(
          home: GoogleStartupGate(identity: identity, child: const SizedBox()),
        ),
      ),
    );
    await tester.pump();
    await invites.refresh();
    expect(account.bindings, isEmpty);
    identity.pending.complete('fixture');
    await tester.pump();
    await tester.pump();
    await invites.refresh();
    expect(account.bindings.single['code'], codeA);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'unreleased server does not retry an unsupported invite API forever',
    (tester) async {
      final account = Account()..failure = 'action_invalid';
      final source = Source()
        ..referrers.add(const InviteReferrer(InviteReferrerStatus.retry));
      final invites = MobileInvites(
        account: account,
        source: source,
        vault: Vault(),
        startupResolved: true,
        retryDelay: const Duration(seconds: 1),
      )..start();
      addTearDown(invites.dispose);
      await invites.refresh();
      final requests = account.requests;
      await tester.pump(const Duration(seconds: 10));
      expect(account.requests, requests);
      expect(invites.error, 'invites_unavailable');
      await expectLater(
        invites.bindManual(codeA),
        throwsA(
          isA<MobileApiError>().having(
            (e) => e.code,
            'code',
            'invites_unavailable',
          ),
        ),
      );
    },
  );

  test(
    'invalid deferred first candidate leaves next native candidate untouched',
    () async {
      final account = Account(linked: false);
      final source = Source()
        ..urls.addAll([InviteCode.url('ZZZZZZZZZZZZ'), InviteCode.url(codeA)]);
      final invites = service(account, source, Vault(), resolved: false)
        ..start();
      await invites.refresh();
      expect(source.acknowledgements, 1);
      expect(source.urls.single, InviteCode.url(codeA));
      invites.markStartupResolved();
      await invites.refresh();
      expect(account.bindings.single['code'], codeA);
      expect(source.acknowledgements, 2);
    },
  );
  test(
    'warm native notification applies a new link without reopening the app',
    () async {
      final account = Account();
      final source = Source();
      final invites = service(account, source, Vault())..start();
      await invites.refresh();
      source.urls.add(InviteCode.url(codeA));
      source.available!();
      await invites.refresh();
      expect(account.bindings.single['code'], codeA);
    },
  );
  test(
    'delayed SDK result in background persists but binds only after resume',
    () async {
      final account = Account();
      final vault = Vault();
      final source = Source();
      final referrer = Completer<InviteReferrer>();
      source.heldReferrer = referrer;
      final invites = service(account, source, vault)..start();
      await Future<void>.delayed(Duration.zero);
      invites.didChangeAppLifecycleState(AppLifecycleState.paused);
      referrer.complete(
        const InviteReferrer(InviteReferrerStatus.available, 'invite=$codeA'),
      );
      await invites.refresh();
      expect(account.bindings, isEmpty);
      expect(invites.pendingCode, codeA);
      expect((jsonDecode(vault.raw!) as Map)['pending']['code'], codeA);
      invites.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await invites.refresh();
      expect(account.bindings.single['code'], codeA);
    },
  );
  test(
    'background source remains durable and resumes without an extra confirmation',
    () async {
      final account = Account();
      final source = Source();
      final invites = service(account, source, Vault())..start();
      await invites.refresh();
      invites.didChangeAppLifecycleState(AppLifecycleState.paused);
      source.urls.add(InviteCode.url(codeA));
      source.available!();
      await invites.refresh();
      expect(account.bindings, isEmpty);
      expect(source.urls.length, 1);
      invites.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await invites.refresh();
      expect(account.bindings.single['code'], codeA);
    },
  );
  test(
    'production account adapter sends bearer and refreshes authoritative wallet',
    () async {
      SharedPreferences.setMockInitialValues({});
      final credentials = _AccountVault();
      final requests = <String>[];
      final fixture = Account();
      final client = MockClient((request) async {
        final action = (jsonDecode(request.body) as Map)['action'] as String;
        requests.add(action);
        if (action != 'guest') {
          expect(
            request.headers['Authorization'],
            matches(r'^Bearer [a-f0-9]{64}$'),
          );
        }
        if (action == 'invites_bind') fixture.inviters['android:1'] = codeA;
        final profile = {
          'id': 'android:1',
          'nickname': 'Player',
          'googleLinked': true,
          'walletVersion': action == 'guest' ? 1 : 2,
          'wallet': {'tokens': action == 'guest' ? 0 : 10},
        };
        return http.Response(
          jsonEncode({
            'ok': true,
            'profile': profile,
            if (action.startsWith('invites_')) ...fixture.data('android:1'),
          }),
          200,
        );
      });
      final account = MobileAccount(vault: credentials, client: client);
      addTearDown(account.dispose);
      await account.load();
      final invites = MobileInvites(
        account: account,
        source: Source()..urls.add(InviteCode.url(codeA)),
        vault: Vault(),
        startupResolved: true,
        retryDelay: const Duration(days: 1),
      )..start();
      addTearDown(invites.dispose);
      await invites.refresh();
      expect(
        requests,
        containsAll(['guest', 'invites_state', 'invites_bind', 'profile']),
      );
      expect(account.wallet!['tokens'], 10);
      expect(invites.state!.inviterCode, codeA);
    },
  );
}

class _AccountVault implements AccountVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}
