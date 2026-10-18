import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/leaderboard/player_result_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'blue_glass_profile_test.dart' as profile;

const owner = 'supabase:20000000-0000-4000-8000-000000000002';
const target = 'supabase:30000000-0000-4000-8000-000000000003';

class FirstPublicAccount extends profile.ProfileTestAccount {
  FirstPublicAccount() {
    id = owner;
    nickname = 'My name';
    communityRulesVersion = 0;
  }
  int accepted = 0, privacyWrites = 0, reports = 0, hides = 0;
  String? reportTarget, reportReason;
  @override
  Future<void> acceptCommunityRules() async {
    accepted++;
    communityRulesVersion = 1;
    notifyListeners();
  }

  @override
  Future<void> setGooglePrivacy(bool hide) async {
    privacyWrites++;
    hideGoogleAccount = hide;
    notifyListeners();
  }

  @override
  Future<void> hidePublicName(String target, bool hide) async {
    hides++;
    if (hide) {
      hiddenPlayers.add(target);
    } else {
      hiddenPlayers.remove(target);
    }
    notifyListeners();
  }

  @override
  Future<void> reportPublicName(String target, String reason) async {
    reports++;
    reportTarget = target;
    reportReason = reason;
  }
}

class NameVault implements AccountVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    value = v;
  }
}

void main() {
  testWidgets(
    'first rename requires explicit rules; cancel keeps name and acceptance is reused',
    (t) async {
      final a = FirstPublicAccount();
      await profile.mountProfile(
        t,
        size: const Size(390, 844),
        fixtureAccount: a,
      );
      final input = find.byKey(const ValueKey('profile-nickname-input')),
          save = find.byKey(const ValueKey('profile-nickname-save'));
      await t.enterText(input, 'New name');
      await t.pumpAndSettle();
      await t.tap(save);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('community-rules')), findsOneWidget);
      expect(a.renames, 0);
      expect(a.accepted, 0);
      await t.tap(find.byKey(const ValueKey('community-rules-cancel')));
      await t.pumpAndSettle();
      expect(a.nickname, 'My name');
      await t.tap(save);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('community-rules-accept')));
      await t.pumpAndSettle();
      expect(a.accepted, 1);
      expect(a.renames, 1);
      expect(a.nickname, 'New name');
      await t.enterText(input, 'AA');
      await t.pumpAndSettle();
      await t.tap(save);
      await t.pumpAndSettle();
      expect(a.renames, 2);
      expect(a.accepted, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'making Google name public uses the same explicit rules; cancel preserves privacy',
    (t) async {
      final a = FirstPublicAccount()
        ..googleLinked = true
        ..googleName = 'Fixture Google'
        ..googleEmail = 'fixture@example.invalid';
      await profile.mountProfile(
        t,
        size: const Size(390, 844),
        fixtureAccount: a,
      );
      final privacy = find.byKey(const ValueKey('profile-google-private'));
      await t.ensureVisible(privacy);
      await t.tap(privacy);
      await t.pumpAndSettle();
      expect(a.privacyWrites, 0);
      await t.tap(find.byKey(const ValueKey('community-rules-cancel')));
      await t.pumpAndSettle();
      expect(a.hideGoogleAccount, true);
      await t.tap(privacy);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('community-rules-accept')));
      await t.pumpAndSettle();
      expect(a.hideGoogleAccount, false);
      expect(a.privacyWrites, 1);
      expect(a.accepted, 1);
    },
  );
  for (final size in [const Size(390, 844), const Size(320, 480)]) {
    testWidgets(
      'public record reports and hides only its name without changing metrics: $size',
      (t) async {
        final a = FirstPublicAccount()..communityRulesVersion = 1;
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final entry = ScoreEntry(
          id: 'fixture-record',
          uid: target,
          displayName: 'Public name',
          timeMs: 5014,
          createdAt: DateTime(2026, 10, 18),
          runDistance: 12,
          riskCount: 3,
        );
        await t.pumpWidget(
          MaterialApp(
            // Production Android has the age-startup navigator above the game.
            home: ChangeNotifierProvider<MobileAccount>.value(
              value: a,
              child: MaterialApp(
                theme: buildGameTheme(),
                locale: const Locale('ru'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: Scaffold(
                  body: Builder(
                    builder: (c) => TextButton(
                      onPressed: () =>
                          showPlayerResultSheet(c, entry: entry, place: 7),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        final actions = find.byKey(const ValueKey('public-name-actions'));
        await t.ensureVisible(actions);
        await t.tap(actions);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('public-report')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('report-offensive_name')));
        await t.pumpAndSettle();
        expect(a.reports, 1);
        expect(a.reportTarget, target);
        expect(a.reportReason, 'offensive_name');
        await t.ensureVisible(actions);
        await t.tap(actions);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('public-hide')));
        await t.pumpAndSettle();
        expect(a.hides, 1);
        expect(find.text('Скрытое имя'), findsOneWidget);
        expect(find.text('Public name'), findsNothing);
        expect(entry.timeMs, 5014);
        expect(entry.runDistance, 12);
        expect(entry.riskCount, 3);
        expect(t.takeException(), isNull);
      },
    );
  }

  test(
    'hidden names survive secure offline owner recovery and do not leak to another owner',
    () async {
      final vault = NameVault();
      String serverOwner = owner;
      final hidden = <String>[];
      final client = MockClient((request) async {
        final input = jsonDecode(request.body) as Map;
        if (input['action'] == 'public_name_hide') {
          hidden.add(target.substring(9));
        }
        return http.Response(
          jsonEncode({
            'ok': true,
            'profile': {
              'id': serverOwner,
              'nickname': 'Fixture',
              'communityRulesVersion': 1,
              'hiddenPlayers': serverOwner == owner ? hidden : [],
              'wallet': {'tokens': 50},
              'walletVersion': 1,
            },
          }),
          200,
        );
      });
      final a = MobileAccount(
        vault: vault,
        client: client,
        storagePrefix: 'supabase_names_test_',
      );
      await a.load();
      await a.hidePublicName(target, true);
      expect(a.isPlayerHidden(target), true);
      final offline = MobileAccount(
        vault: vault,
        client: client,
        storagePrefix: 'supabase_names_test_',
      );
      await offline.restoreCachedOwner();
      expect(offline.id, owner);
      expect(offline.isPlayerHidden(target), true);
      serverOwner = 'supabase:40000000-0000-4000-8000-000000000004';
      await offline.load();
      expect(offline.id, serverOwner);
      expect(offline.hiddenPlayers, isEmpty);
      a.dispose();
      offline.dispose();
    },
  );
}
