import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/game/lives_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'mobile_account_test.dart' show MemoryVault, GoogleFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final stored in [
    null,
    ...AgeBand.values.map((b) => b.name),
    'invalid',
  ]) {
    test('guest autosave and Google do not require age: $stored', () async {
      SharedPreferences.setMockInitialValues({
        AudiencePolicy.storageKey: ?stored,
      });
      final policy = AudiencePolicy();
      await policy.load();
      final actions = <String>[];
      final transport = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('{"ok":true,"source":"mysql","scores":[]}', 200);
        }
        final body = jsonDecode(request.body) as Map;
        final action = body['action'] as String;
        actions.add(action);
        if (action == 'round_start') {
          return http.Response(
            jsonEncode({'ok': true, 'roundId': body['requestId']}),
            200,
          );
        }
        if (action == 'round_finish') {
          return http.Response(
            '{"ok":true,"scoreId":"age-independent-fixture"}',
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'ok': true,
            'profile': {
              'id': 'android:83',
              'nickname': 'GuestCube',
              'googleLinked': action == 'google_link',
            },
          }),
          200,
        );
      });
      final account = MobileAccount(vault: MemoryVault(), client: transport);
      final scores = ScoresStore(account: account, client: transport);
      await account.load();
      await scores.load();
      expect(account.onlineAllowed, true);
      expect(await scores.beginRound(), true);
      await scores.recordAttempt(
        3500,
        riskCount: 1,
        runDistance: 70,
        hadJump: false,
        hadHelmet: false,
      );
      await scores.retryPendingResults();
      expect(scores.myAttempts.single.shared, true);
      expect(scores.isAttemptPending(scores.myAttempts.single.id), false);
      expect(actions.where((a) => a == 'round_finish'), hasLength(1));
      await account.linkGoogle(GoogleFixture());
      expect(actions, contains('google_link'));
      expect(account.googleLinked, true);
      expect(policy.adsEnabled, false);
      expect(
        policy.band?.name,
        stored == null
            ? null
            : stored == 'invalid'
            ? 'unknown'
            : stored,
      );
      scores.dispose();
      account.dispose();
      policy.dispose();
    });
  }

  test(
    'explicit offline transport preserves practice without uploading it later',
    () async {
      var calls = 0;
      final transport = MockClient((request) async {
        calls++;
        if (request.method == 'GET') {
          return http.Response('{"ok":true,"source":"mysql","scores":[]}', 200);
        }
        return http.Response(
          jsonEncode({
            'ok': true,
            'profile': {'id': 'android:81', 'nickname': 'AgeTestPlayer'},
          }),
          200,
        );
      });
      final vault = MemoryVault();
      final localAccount = MobileAccount(
        vault: vault,
        client: transport,
        mayUseOnline: () => false,
      );
      final local = ScoresStore(account: localAccount, client: transport);
      await localAccount.load();
      await local.load();
      expect(await local.beginRound(), false);
      expect(localAccount.roundError, 'online_disabled');
      await local.recordAttempt(
        12500,
        riskCount: 2,
        runDistance: 245,
        hadJump: false,
        hadHelmet: false,
      );
      await local.retryPendingResults();
      await expectLater(
        localAccount.request({'action': 'profile'}),
        throwsA(isA<MobileApiError>()),
      );
      await expectLater(
        localAccount.linkGoogle(GoogleFixture()),
        throwsA(isA<MobileApiError>()),
      );
      await expectLater(
        localAccount.restoreGoogle(GoogleFixture()),
        throwsA(isA<MobileApiError>()),
      );
      expect(vault.value, null);
      expect(calls, 0);
      final practiceId = local.myAttempts.single.id;
      local.dispose();

      final adultAccount = MobileAccount(vault: vault, client: transport);
      final adult = ScoresStore(account: adultAccount, client: transport);
      await adult.loadLocal();
      await adultAccount.load();
      await adult.loadLocal();
      expect(adult.myAttempts.single.id, practiceId);
      expect(adult.myAttempts.single.shared, false);
      expect(adult.isAttemptPending(practiceId), false);
      await adult.load();
      expect(calls, 6); // guest + five public periods, no round_finish.
      adult.dispose();
      adultAccount.id = 'android:82';
      final other = ScoresStore(account: adultAccount, client: transport);
      await other.loadLocal();
      expect(other.myAttempts, isEmpty);
      other.dispose();
    },
  );

  test('offline configuration loads bundled/cache without even GET', () async {
    var calls = 0;
    final fixture = File(SharedConfigLoader.assetPath).readAsStringSync();
    final result = await SharedConfigLoader.load(
      allowNetwork: false,
      readBundled: () async => fixture,
      client: MockClient((_) async {
        calls++;
        return http.Response(fixture, 200);
      }),
    );
    expect(result.source, 'bundled');
    expect(calls, 0);
  });

  for (final language in ['ru', 'en']) {
    for (final stored in [null, 'age6to8', 'unknown']) {
      testWidgets(
        'resource actions cancel safely and continue once after age choice ($language, $stored)',
        (tester) async {
          final errorHandler = FlutterError.onError;
          FlutterError.onError = (details) {
            debugPrint(details.toString());
            errorHandler?.call(details);
          };
          addTearDown(() => FlutterError.onError = errorHandler);
          SharedPreferences.setMockInitialValues({
            AudiencePolicy.storageKey: ?stored,
          });
          final policy = AudiencePolicy();
          await policy.load();
          final economy = EconomyStore();
          await economy.load();
          economy.tokens = 100;
          final before = economy.tokens;
          await tester.binding.setSurfaceSize(const Size(320, 480));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: policy),
                ChangeNotifierProvider.value(value: economy),
                Provider.value(value: GameplayConfig()),
                ChangeNotifierProvider(create: (_) => MobileAccount()),
              ],
              child: MaterialApp(
                theme: buildGameTheme(),
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        TextButton(
                          onPressed: () => showCrystalsSheet(context),
                          child: const Text('Shop'),
                        ),
                        TextButton(
                          onPressed: () => showLivesSheet(context),
                          child: const Text('Lives'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Shop'));
          await tester.pumpAndSettle();
          for (var i = 0; i < 4; i++) {
            await tester.tap(find.byKey(ValueKey('shop-tab-$i')));
            await tester.pumpAndSettle();
          }
          expect(find.byKey(const ValueKey('age-continue')), findsNothing);
          await tester.tap(find.byKey(const ValueKey('shop-tab-0')));
          await tester.pumpAndSettle();
          final daily = find.byKey(const ValueKey('daily-claim-1'));
          await tester.scrollUntilVisible(
            daily,
            160,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await Scrollable.ensureVisible(tester.element(daily), alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(daily);
          await tester.pumpAndSettle();
          if (policy.needsSelection) {
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('age-continue')),
              120,
              scrollable: find.byType(Scrollable).last,
            );
            expect(find.byKey(const ValueKey('age-continue')), findsOneWidget);
            expect(
              tester
                  .widget<FilledButton>(
                    find.byKey(const ValueKey('age-continue')),
                  )
                  .onPressed,
              null,
            );
            expect(economy.tokens, before);
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('age-cancel')),
              100,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.tap(find.byKey(const ValueKey('age-cancel')));
            await tester.pumpAndSettle();
            expect(economy.tokens, before);
            await tester.pump(const Duration(seconds: 1));
            await tester.tap(daily);
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('age-under18')),
              100,
              scrollable: find.byType(Scrollable).last,
            );
            await Scrollable.ensureVisible(
              tester.element(find.byKey(const ValueKey('age-under18'))),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('age-under18')));
            await tester.pump();
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('age-continue')),
              100,
              scrollable: find.byType(Scrollable).last,
            );
            await Scrollable.ensureVisible(
              tester.element(find.byKey(const ValueKey('age-continue'))),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('age-continue')));
            await tester.pumpAndSettle();
          }
          expect(
            economy.tokens,
            before + economy.config.dailyTokensForStreak(0, premium: false),
          );
          expect(find.byKey(const ValueKey('age-continue')), findsNothing);
          final afterDaily = economy.tokens;
          await tester.tap(
            find.byTooltip(language == 'ru' ? 'Закрыть' : 'Close').first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Lives'));
          await tester.pumpAndSettle();
          final pack = economy.config.lifePacks.first;
          final action = find.byKey(
            ValueKey('life-exchange-${pack.lives}-${pack.costTokens}'),
          );
          await tester.scrollUntilVisible(
            action,
            160,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await Scrollable.ensureVisible(tester.element(action), alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byKey(const ValueKey('age-continue')), findsNothing);
          expect(economy.tokens, afterDaily - pack.costTokens);
          expect(policy.band?.name, stored == 'age6to8' ? stored : 'under18');
          expect(policy.adsEnabled, false);
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
          economy.dispose();
          policy.dispose();
        },
      );
    }
  }
}
