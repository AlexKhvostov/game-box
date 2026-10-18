import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/data/invite_code.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'friend_invites_delivery_test.dart' as fixture;

class ModernAccount extends fixture.Account {
  ModernAccount({super.linked}) {
    id = 'supabase:22345678-1234-4234-8234-123456789abc';
  }
  final calls = <Map<String, dynamic>>[];
  String own = 'XYZ234';
  String? urlOverride;
  @override
  Map<String, dynamic> data(String owner) {
    final result = super.data(owner);
    final body = result['invites'] as Map<String, dynamic>;
    body['ownCode'] = own;
    body['inviteUrl'] = urlOverride ?? InviteCode.url(own);
    return result;
  }

  @override
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> payload, {
    bool guest = false,
  }) async {
    calls.add(Map.of(payload));
    if (payload['action'] == 'invites_bind') {
      bindings.add(Map.of(payload));
      inviters[id!] = payload['code'] as String;
    }
    return data(id!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'only 6 or 12 ASCII alphabet symbols; both canonical App Link hosts',
    () {
      for (final code in ['ABC234', fixture.codeA]) {
        expect(InviteCode.normalize(' ${code.toLowerCase()} '), code);
        for (final url in [
          InviteCode.url(code),
          InviteCode.firebaseUrl(code),
        ]) {
          expect(InviteCode.fromAppLink(url), code);
          expect(InviteCode.fromAppLink('$url/'), code);
          for (final bad in [
            '$url?x=1',
            '$url#x',
            '$url/more',
            url.replaceFirst('/a/', '/a/%41'),
          ]) {
            expect(InviteCode.fromAppLink(bad), isNull, reason: bad);
          }
        }
        expect(
          InviteCode.fromReferrer(
            'utm_source=friend&invite=${code.toLowerCase()}',
          ),
          code,
        );
        expect(InviteCode.fromReferrer('invite=$code&invite=$code'), isNull);
      }
      for (final code in [
        'ABCDE',
        'ABCDEFG',
        'ABCDEFGH',
        'ABCDEFGHJ',
        'ABCDEFGHJK',
        'ABCDEFGHJKL',
        'ABC01I',
        'АBC234',
        'ABCDEſ',
        'ABC23\n4',
      ]) {
        expect(InviteCode.normalize(code), isNull, reason: code);
      }
      for (final url in [
        'https://untouch.fun.evil/a/ABC234',
        'https://evil@untouch.fun/a/ABC234',
        'https://untouch.fun:443/a/ABC234',
        'http://untouch.fun/a/ABC234',
        'https://UNTOUCH.FUN/a/ABC234',
      ]) {
        expect(InviteCode.fromAppLink(url), isNull, reason: url);
      }
    },
  );
  test(
    'DTO permits only exact canonical URLs for modern owners, untouch only for legacy owner',
    () {
      final account = ModernAccount();
      for (final owner in [
        'supabase:22345678-1234-4234-8234-123456789abc',
        'firebase:short-owner',
        'android:1',
      ]) {
        for (final code in ['ABC234', fixture.codeA]) {
          for (final url in [
            InviteCode.url(code),
            InviteCode.firebaseUrl(code),
          ]) {
            final body =
                Map<String, dynamic>.from(account.data(owner)['invites'] as Map)
                  ..['ownCode'] = code
                  ..['inviteUrl'] = url;
            if (owner == 'android:1' && url == InviteCode.firebaseUrl(code)) {
              expect(
                () => InviteState.fromJson(body),
                throwsA(isA<MobileApiError>()),
              );
            } else {
              expect(InviteState.fromJson(body).ownCode, code);
            }
            for (final bad in [
              '$url/',
              '$url?x=1',
              url.replaceFirst('https://', 'https://evil@'),
            ]) {
              body['inviteUrl'] = bad;
              expect(
                () => InviteState.fromJson(body),
                throwsA(isA<MobileApiError>()),
              );
            }
          }
        }
      }
    },
  );
  test(
    'all three actions use ordinary payloads; cached response upgrades without owner/code leakage',
    () async {
      final account = ModernAccount()
        ..own = fixture.ownGuest
        ..urlOverride = InviteCode.firebaseUrl(fixture.ownGuest)
        ..cursor = '123_1';
      final invites = fixture.service(
        account,
        fixture.Source(),
        fixture.Vault(),
      );
      invites.start();
      await invites.refresh();
      expect(invites.state!.ownCode, fixture.ownGuest);
      account.own = 'XYZ234';
      account.urlOverride = null;
      await invites.refresh();
      expect(invites.state!.ownCode, 'XYZ234');
      await invites.bindManual('abc234');
      await invites.loadMore();
      expect(
        account.calls.map((p) => p['action']).toSet(),
        containsAll(['invites_state', 'invites_bind', 'invites_list']),
      );
      expect(
        account.calls.every((p) => !p.containsKey('inviteCodeVersion')),
        isTrue,
      );
      expect(account.bindings.single['code'], 'ABC234');
      account.resolve(
        linked: true,
        owner: 'supabase:32345678-1234-4234-8234-123456789abc',
      );
      expect(invites.state, isNull);
    },
  );
  for (final pending in ['ABC234', fixture.codeA]) {
    test(
      'durable incoming $pending survives restart then canonical synchronization',
      () async {
        final account = ModernAccount();
        final vault = fixture.Vault()
          ..raw = jsonEncode({
            'referrerDone': true,
            'pending': {'code': pending, 'source': 'app_link'},
          });
        final invites = fixture.service(account, fixture.Source(), vault);
        await invites.refresh();
        expect(account.bindings.single['code'], pending);
        expect(invites.state!.inviterCode, pending);
        expect((jsonDecode(vault.raw!) as Map)['pending'], isNull);
      },
    );
  }
  test(
    'short incoming link waits for canonical Google restore and clears guest outgoing state',
    () async {
      final account = ModernAccount(linked: false);
      final source = fixture.Source()..urls.add(InviteCode.url('ABC234'));
      final vault = fixture.Vault();
      final invites = fixture.service(account, source, vault, resolved: false)
        ..start();
      await invites.refresh();
      expect(invites.pendingCode, 'ABC234');
      expect(account.bindings, isEmpty);
      expect(source.acknowledgements, 1);
      account.own = 'JKLM23';
      account.resolve(
        linked: true,
        owner: 'supabase:32345678-1234-4234-8234-123456789abc',
      );
      invites.markStartupResolved();
      await invites.refresh();
      expect(account.bindings.single['code'], 'ABC234');
      expect(invites.state!.profileId, account.id);
      expect(invites.state!.ownCode, 'JKLM23');
      expect(invites.pendingCode, isNull);
    },
  );
}
