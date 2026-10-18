import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:game_box/data/google_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/mobile_account.dart';
import 'blue_glass_profile_test.dart' as fixture;

class PrivacyAccount extends fixture.ProfileTestAccount {
  bool fail = false;
  @override
  Future<void> setGooglePrivacy(bool hide) async {
    if (fail) throw const MobileApiError('service_unavailable');
    hideGoogleAccount = hide;
    notifyListeners();
  }
}

class CachedFixture extends NativeGoogleIdentity {
  @override
  Future<String?> cachedToken() async => 'fixture-token';
}

void main() {
  test(
    'late Google details cannot revert newer privacy/wallet changes',
    () async {
      final gate = Completer<void>();
      final requested = Completer<void>();
      final account =
          MobileAccount(
              client: MockClient((r) async {
                final action = (jsonDecode(r.body) as Map)['action'];
                if (action == 'google_details') {
                  requested.complete();
                  await gate.future;
                }
                return http.Response(
                  jsonEncode({
                    'ok': true,
                    'profile': {
                      'id': 'android:1',
                      'nickname': 'Fixture',
                      'googleLinked': true,
                      'googleEmail': 'fixture@example.invalid',
                      'hideGoogleAccount': action == 'google_details',
                      'walletVersion': action == 'google_details' ? 1 : 2,
                      'wallet': {
                        'tokens': action == 'google_details' ? 15 : 25,
                      },
                    },
                  }),
                  200,
                );
              }),
            )
            ..id = 'android:1'
            ..googleLinked = true;
      final pending = account.refreshGoogleDetails(CachedFixture());
      await requested.future;
      await account.setGooglePrivacy(false);
      expect(account.hideGoogleAccount, false);
      gate.complete();
      await pending;
      expect(account.hideGoogleAccount, false);
      expect(account.wallet!['tokens'], 25);
      expect(account.googleEmail, 'fixture@example.invalid');
    },
  );

  for (final size in [const Size(360, 770), const Size(320, 560)]) {
    testWidgets(
      'linked owner details/private default and privacy save failure $size',
      (tester) async {
        final account = PrivacyAccount()
          ..id = 'android:1'
          ..nickname = 'FixtureNick'
          ..googleLinked = true
          ..googleName = 'Fixture Name'
          ..googleEmail = 'fixture@example.invalid';
        await fixture.mountProfile(tester, size: size, fixtureAccount: account);
        await tester.ensureVisible(
          find.byKey(const ValueKey('profile-google-email')),
        );
        expect(find.text('Fixture Name'), findsOneWidget);
        expect(find.text('fixture@example.invalid'), findsOneWidget);
        final privacy = find.byKey(const ValueKey('profile-google-private'));
        await tester.ensureVisible(privacy);
        expect(tester.widget<SwitchListTile>(privacy).value, true);
        expect(
          find.text('Виден только игровой ник.'),
          findsOneWidget,
        );
        await tester.tap(privacy);
        await tester.pumpAndSettle();
        expect(account.hideGoogleAccount, false);
        expect(find.textContaining('Почта не показывается'), findsOneWidget);
        account.fail = true;
        await tester.tap(privacy);
        await tester.pumpAndSettle();
        expect(account.hideGoogleAccount, false);
        expect(find.textContaining('Не удалось сохранить'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'age correction is preselected; cancel preserves, confirm persists',
    (tester) async {
      await fixture.mountProfile(tester, size: const Size(360, 770));
      final policy = tester
          .element(find.byKey(const ValueKey('profile-age-setting')))
          .read<AudiencePolicy>();
      await policy.select(AgeBand.age6to8);
      await tester.pumpAndSettle();
      final change = find.byKey(const ValueKey('profile-age-edit'));
      await tester.ensureVisible(change);
      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('age-continue')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('age-adult18plus')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('age-cancel')));
      await tester.pumpAndSettle();
      expect(policy.band, AgeBand.age6to8);
      await tester.tap(change);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('age-adult18plus')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('age-continue')));
      await tester.pumpAndSettle();
      expect(policy.band, AgeBand.adult18plus);
      expect(policy.adsEnabled, false);
      final next = AudiencePolicy();
      await next.load();
      expect(next.band, AgeBand.adult18plus);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('explicit correction never restores advertising permission', () async {
    SharedPreferences.setMockInitialValues({});
    final policy = AudiencePolicy();
    await policy.load();
    await policy.select(AgeBand.age21plus);
    policy.allowAdsForSession();
    await policy.correct(AgeBand.age13to15);
    expect(policy.adsEnabled, false);
    await policy.correct(AgeBand.age21plus);
    expect(policy.adsEnabled, false);
    policy.revokeAdsForSession();
    await policy.correct(AgeBand.age18to20);
    policy.allowAdsForSession();
    expect(policy.adsEnabled, false);
  });
}
