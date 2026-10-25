import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/features/leaderboard/my_attempts_panel.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'friend_invites_delivery_test.dart' as fixtures;
import 'server_attempt_history_widget_test.dart' show HistoryUiStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['ru', 'en']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'best outside loaded page -> result -> share -> history $language $scale',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final economy = EconomyStore();
          await economy.load();
          final scores = HistoryUiStore();
          addTearDown(economy.dispose);
          addTearDown(scores.dispose);
          addTearDown(scores.account!.dispose);
          tester.view.physicalSize = const Size(320, 560);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final tokens = economy.tokens;
          final best = scores.serverAttemptHistory!.best!.attempt;
          expect(
            scores.serverAttemptHistory!.rows.any(
              (r) => r.attempt.id == best.id,
            ),
            isFalse,
          );
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: economy),
                ChangeNotifierProvider<ScoresStore>.value(value: scores),
              ],
              child: MaterialApp(
                theme: buildGameTheme(),
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const Scaffold(body: MyAttemptsSheet()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('my-attempts-best')));
          await tester.pumpAndSettle();
          final result = tester.widget<ResultOverlay>(
            find.byType(ResultOverlay),
          );
          expect(result.bestAttempt!.id, best.id);
          expect(result.timeMs, 90000);
          expect(result.runDistance, 3);
          expect(result.riskCount, 1);
          expect(
            find.text(
              language == 'ru' ? '🏆 Лучшая попытка' : '🏆 Best attempt',
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('result-claim-reward')),
            findsNothing,
          );
          expect(scores.latestAttempt, isNull);
          final share = find.text(language == 'ru' ? 'Поделиться' : 'Share');
          await tester.ensureVisible(share);
          await tester.tap(share);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('share-preview')),
              matching: find.text(language == 'ru' ? '90.000 с' : '90.000 s'),
            ),
            findsOneWidget,
          );
          expect(
            find.text(language == 'ru' ? 'Риск 1' : 'Risk 1'),
            findsOneWidget,
          );
          expect(
            find.text(language == 'ru' ? 'Шаги 3' : 'Steps 3'),
            findsOneWidget,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('share-cancel')),
          );
          await tester.tap(find.byKey(const ValueKey('share-cancel')));
          await tester.pumpAndSettle();
          expect(find.byType(ResultOverlay), findsOneWidget);
          await tester.ensureVisible(
            find.byKey(const ValueKey('result-replay')),
          );
          await tester.tap(find.byKey(const ValueKey('result-replay')));
          await tester.pumpAndSettle();
          expect(find.byType(ResultOverlay), findsNothing);
          expect(
            find.byKey(const ValueKey('my-attempts-sheet')),
            findsOneWidget,
          );
          expect(economy.tokens, tokens);
          expect(scores.latestAttempt, isNull);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  test(
    'share link loads own code without collecting or binding an incoming link',
    () async {
      final account = fixtures.Account();
      final source = fixtures.Source()
        ..urls.add('https://untouch.fun/a/ABCDEF');
      final invites = MobileInvites(
        account: account,
        source: source,
        vault: fixtures.Vault(),
      );
      addTearDown(account.dispose);
      addTearDown(invites.dispose);
      expect(
        await invites.resultShareUrl(),
        'https://untouch.fun/a/AAAAAAAAAAAA',
      );
      expect(source.reads, 0);
      expect(source.acknowledgements, 0);
      expect(account.bindings, isEmpty);
      final count = account.requests;
      expect(
        await invites.resultShareUrl(),
        'https://untouch.fun/a/AAAAAAAAAAAA',
      );
      expect(account.requests, count);
      account.resolve(linked: true, owner: 'android:2');
      expect(
        await invites.resultShareUrl(),
        'https://untouch.fun/a/BBBBBBBBBBBB',
      );
    },
  );
  test(
    'share never falls back to a generic URL when invitations fail',
    () async {
      final account = fixtures.Account()..failure = 'connection_failed';
      final invites = MobileInvites(
        account: account,
        source: fixtures.Source(),
        vault: fixtures.Vault(),
      );
      addTearDown(account.dispose);
      addTearDown(invites.dispose);
      await expectLater(
        invites.resultShareUrl(),
        throwsA(isA<MobileApiError>()),
      );
    },
  );
  test(
    'account switch during link request rejects the old player link',
    () async {
      final account = fixtures.Account();
      final reply = Completer<Map<String, dynamic>>();
      account.hold = reply;
      final invites = MobileInvites(
        account: account,
        source: fixtures.Source(),
        vault: fixtures.Vault(),
      );
      addTearDown(account.dispose);
      addTearDown(invites.dispose);
      final pending = invites.resultShareUrl();
      final assertion = expectLater(pending, throwsA(isA<MobileApiError>()));
      await Future<void>.delayed(Duration.zero);
      account.resolve(linked: true, owner: 'android:2');
      reply.complete(account.data('android:1'));
      await assertion;
      expect(
        await invites.resultShareUrl(),
        'https://untouch.fun/a/BBBBBBBBBBBB',
      );
    },
  );
}
