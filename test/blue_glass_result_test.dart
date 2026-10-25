import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'package:game_box/features/result/share_score_sheet.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';

class _Scores extends ScoresStore {
  _Scores({this.pending = false, this.shared = true, super.account});
  bool pending, shared;
  void acknowledge() {
    pending = false;
    shared = true;
    notifyListeners();
  }

  @override
  LocalAttempt get latestAttempt => LocalAttempt(
    id: 'isolated-result',
    timeMs: 21349,
    createdAt: DateTime(2026, 10, 10),
    shared: shared,
  );
  @override
  bool isAttemptPending(String id) => pending;
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
}

class _SubmitScores extends _Scores {
  _SubmitScores({super.account, this.fail = false, this.completion});
  final bool fail;
  final Completer<RankInfo>? completion;
  int submissions = 0;
  @override
  Future<RankInfo> saveScore({
    required String displayName,
    required int timeMs,
    String? countryCode,
    int riskCount = 0,
    int runDistance = 0,
    bool hadJump = false,
    bool hadHelmet = false,
  }) async {
    submissions++;
    if (fail) throw StateError('isolated-server-error');
    if (completion != null) return completion!.future;
    return RankInfo(place: 1, percentile: 90, totalCount: 10);
  }
}

Future<_SubmitScores> _submit(
  WidgetTester tester, {
  String language = 'ru',
  bool fail = false,
  bool androidAccount = false,
  Completer<RankInfo>? completion,
}) async {
  SharedPreferences.setMockInitialValues({});
  final economy = EconomyStore();
  await economy.load();
  final account = androidAccount ? (MobileAccount()..id = 'qa-mobile') : null;
  final scores = _SubmitScores(
    account: account,
    fail: fail,
    completion: completion,
  );
  addTearDown(economy.dispose);
  addTearDown(scores.dispose);
  if (account != null) addTearDown(account.dispose);
  await tester.binding.setSurfaceSize(const Size(320, 560));
  addTearDown(() {
    tester.view.resetViewInsets();
    return tester.binding.setSurfaceSize(null);
  });
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
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showShareScoreSheet(context, timeMs: 21349),
              child: const Text('open-submit'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-submit'));
  await tester.pumpAndSettle();
  return scores;
}

Future<void> _result(
  WidgetTester tester, {
  String language = 'ru',
  Size size = const Size(320, 560),
  double scale = 1,
  bool claimed = true,
  bool adBreak = false,
  Future<bool> Function()? claim,
  VoidCallback? replay,
  bool pending = false,
  bool shared = true,
  int? previousBest,
}) async {
  SharedPreferences.setMockInitialValues({});
  final economy = EconomyStore();
  await economy.load();
  final scores = _Scores(pending: pending, shared: shared);
  addTearDown(economy.dispose);
  addTearDown(scores.dispose);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
        home: Scaffold(
          body: ResultOverlay(
            timeMs: 21349,
            adBreakFollows: adBreak,
            previousBestTimeMs: previousBest,
            runDistance: 1040,
            riskCount: 8,
            rewardClaimed: claimed,
            onClaimReward: claim,
            onOk: replay ?? () {},
            onShare: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final language in ['ru', 'en']) {
    testWidgets('ad break is disclosed before leaving results: $language', (
      tester,
    ) async {
      var closes = 0;
      await _result(
        tester,
        language: language,
        scale: 2,
        adBreak: true,
        replay: () => closes++,
      );
      expect(
        find.byKey(const ValueKey('result-ad-break-notice')),
        findsOneWidget,
      );
      final next = find.byKey(const ValueKey('result-replay'));
      await tester.ensureVisible(next);
      expect(
        find.descendant(
          of: next,
          matching: find.text(language == 'ru' ? 'Продолжить' : 'Continue'),
        ),
        findsOneWidget,
      );
      await tester.tap(next);
      await tester.pump();
      expect(closes, 1);
      expect(tester.takeException(), null);
    });
  }

  testWidgets(
    'result backdrop closes once, card taps and tips do not close it',
    (tester) async {
      var closes = 0, claims = 0;
      await _result(
        tester,
        claimed: false,
        replay: () => closes++,
        claim: () async {
          claims++;
          return true;
        },
      );
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      await tester.tap(find.text('Результат попытки'));
      await tester.pump();
      expect(closes, 0);
      await tester.tap(find.byKey(const ValueKey('result-risk')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(closes, 0);
      await tester.tapAt(const Offset(2, 2));
      await tester.pump();
      await tester.tapAt(const Offset(2, 2));
      expect(closes, 1);
      expect(claims, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Android Back closes result once without leaving the game', (
    tester,
  ) async {
    var closes = 0;
    await _result(tester, replay: () => closes++);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.tap(find.byKey(const ValueKey('result-replay')));
    expect(closes, 1);
    expect(find.byType(ResultOverlay), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final language in ['ru', 'en']) {
    for (final size in [const Size(320, 560), const Size(390, 844)]) {
      testWidgets('result fits $language $size and replay is last 56dp', (
        tester,
      ) async {
        var replays = 0;
        await _result(
          tester,
          language: language,
          size: size,
          replay: () => replays++,
        );
        final card = tester.getRect(find.byKey(const ValueKey('result-card')));
        final replay = tester.getRect(
          find.byKey(const ValueKey('result-replay')),
        );
        expect(card.top, greaterThanOrEqualTo(0));
        expect(card.bottom, lessThanOrEqualTo(size.height));
        // Measure the RenderBox directly; subtracting Rect edges can round
        // an exact 56dp height to 55.99999999999994.
        expect(
          tester.getSize(find.byKey(const ValueKey('result-replay'))).height,
          greaterThanOrEqualTo(56),
        );
        expect(replay.bottom, lessThan(card.bottom));
        expect(
          replay.top,
          greaterThan(
            tester
                .getRect(find.byKey(const ValueKey('result-save-status')))
                .bottom,
          ),
        );
        await tester.tap(find.byKey(const ValueKey('result-replay')));
        expect(replays, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
      testWidgets('result keeps shell fixed with large text $language $size', (
        tester,
      ) async {
        var replays = 0;
        await _result(
          tester,
          language: language,
          size: size,
          scale: 2,
          replay: () => replays++,
        );
        final card = find.byKey(const ValueKey('result-card'));
        final content = find.byKey(const ValueKey('result-content'));
        final shellBefore = tester.getRect(card);
        final contentSize = tester.getSize(content);
        expect(shellBefore.top, greaterThanOrEqualTo(0));
        expect(shellBefore.bottom, lessThanOrEqualTo(size.height));
        final replay = find.byKey(const ValueKey('result-replay'));
        await tester.ensureVisible(replay);
        await tester.pumpAndSettle();
        expect(tester.getRect(card), shellBefore);
        expect(tester.getSize(content), contentSize);
        expect(replay.hitTestable(), findsOneWidget);
        expect(tester.getSize(replay).height, greaterThanOrEqualTo(56));
        await tester.tap(replay);
        expect(replays, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('risks contain bonus details and dialog Back dismisses', (
    tester,
  ) async {
    await _result(tester, claimed: false, claim: () async => false);
    await tester.tap(find.byKey(const ValueKey('result-risk')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('result-risk-tip')), findsOneWidget);
    expect(find.byKey(const ValueKey('result-reward-info')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('result-risk-tip')), findsNothing);
    expect(find.byKey(const ValueKey('result-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('claim cancellation leaves claim and success invokes once', (
    tester,
  ) async {
    var calls = 0;
    var successful = false;
    await _result(
      tester,
      claimed: false,
      claim: () async {
        calls++;
        return successful;
      },
    );
    await tester.tap(find.byKey(const ValueKey('result-claim-reward')));
    await tester.pump();
    expect(calls, 1);
    expect(find.byKey(const ValueKey('result-claim-reward')), findsOneWidget);
    successful = true;
    await tester.tap(find.byKey(const ValueKey('result-claim-reward')));
    await tester.pump();
    expect(calls, 2);
    expect(find.byKey(const ValueKey('result-claim-reward')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final pending in [true, false]) {
    testWidgets('result distinguishes pending $pending from practice', (
      tester,
    ) async {
      await _result(tester, pending: pending, shared: false, claimed: false);
      expect(
        find.text(
          pending
              ? 'Сохранено на устройстве · отправим автоматически'
              : 'Сохранено на устройстве · без общего рейтинга',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('acknowledging saved result keeps dialog geometry', (
    tester,
  ) async {
    await _result(tester, pending: true, shared: false);
    final before = tester.getRect(find.byKey(const ValueKey('result-card')));
    final store =
        tester
                .element(find.byKey(const ValueKey('result-card')))
                .read<ScoresStore>()
            as _Scores;
    store.acknowledge();
    await tester.pump();
    expect(tester.getRect(find.byKey(const ValueKey('result-card'))), before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('new best uses previous time and equal run is not new best', (
    tester,
  ) async {
    await _result(tester, previousBest: 18420);
    expect(find.text('Новый рекорд!'), findsOneWidget);
    expect(find.text('Предыдущий рекорд: 18.420 с'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await _result(tester, previousBest: 21349);
    expect(find.text('Новый рекорд!'), findsNothing);
    expect(find.text('Ваш результат'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final language in ['ru', 'en']) {
    for (final size in [const Size(320, 560), const Size(390, 844)]) {
      testWidgets('share preview fits $language $size and keeps contrast', (
        tester,
      ) async {
        await _result(tester, language: language, size: size);
        await tester.tap(find.text(language == 'ru' ? 'Поделиться' : 'Share'));
        await tester.pumpAndSettle();
        final preview = tester.getRect(
          find.byKey(const ValueKey('share-preview')),
        );
        final send = tester.getRect(find.byKey(const ValueKey('share-send')));
        expect(preview.top, greaterThanOrEqualTo(0));
        expect(send.bottom, lessThanOrEqualTo(size.height));
        expect(send.height, greaterThanOrEqualTo(48));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('share-preview')),
            matching: find.text(language == 'ru' ? '21.349 с' : '21.349 s'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('share-preview')),
            matching: find.byKey(const ValueKey('share-scene')),
          ),
          findsOneWidget,
        );
        expect(
          find.text(language == 'ru' ? 'Риск 8' : 'Risk 8'),
          findsOneWidget,
        );
        expect(
          find.text(language == 'ru' ? 'Шаги 1040' : 'Steps 1040'),
          findsOneWidget,
        );
        expect(
          find.text(
            language == 'ru'
                ? 'Сколько продержитесь вы?'
                : 'How long can you survive?',
          ),
          findsOneWidget,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('share-preview')), findsNothing);
        expect(find.byKey(const ValueKey('result-card')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('share large system text stays scaled and scrollable', (
    tester,
  ) async {
    await _result(tester, scale: 2);
    await tester.ensureVisible(find.text('Поделиться'));
    await tester.tap(find.text('Поделиться'));
    await tester.pumpAndSettle();
    final copy = find.text('Сколько продержитесь вы?');
    expect(MediaQuery.textScalerOf(tester.element(copy)).scale(14), 28);
    await tester.ensureVisible(find.byKey(const ValueKey('share-send')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('share preparation error is visible and retry remains enabled', (
    tester,
  ) async {
    await _result(tester);
    await tester.tap(find.text('Поделиться'));
    await tester.pumpAndSettle();
    final send = find.byKey(const ValueKey('share-send'));
    final feedback = find.byKey(const ValueKey('share-feedback'));
    // Rasterization, PNG encoding and file I/O must start in real asynchronous
    // time. Starting the tap outside runAsync leaves the export future in the
    // test's fake clock and pumpAndSettle cannot finish the busy spinner.
    Future<void> sendAndWaitForError() async {
      await tester.runAsync(() async {
        await tester.tap(send);
        await tester.pump();
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
          if (feedback.evaluate().isNotEmpty) break;
        }
      });
      expect(feedback, findsOneWidget);
      expect(
        find.text(
          'Не удалось подготовить карточку и вашу ссылку приглашения. Проверьте соединение и попробуйте ещё раз.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
    }

    await sendAndWaitForError();
    await sendAndWaitForError();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final language in ['ru', 'en']) {
    testWidgets(
      'legacy submit $language validates and shows server error with keyboard',
      (tester) async {
        final scores = await _submit(tester, language: language, fail: true);
        final save = find.byKey(const ValueKey('submit-save'));
        expect(tester.getRect(save).height, greaterThanOrEqualTo(48));
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(scores.submissions, 0);
        expect(
          find.text(language == 'ru' ? 'Введите имя' : 'Enter a name'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('submit-name')),
          'LongNicknameForAnIsolatedTest123456789012',
        );
        tester.view.viewInsets = FakeViewPadding(
          bottom: 200 * tester.view.devicePixelRatio,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(scores.submissions, 1);
        expect(
          find.text(
            language == 'ru'
                ? 'Результат ещё не подтверждён сервером. Проверьте соединение.'
                : 'The server has not confirmed this result. Check your connection.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('submit-content')), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'Android old submit entry opens ranking without extra submission',
    (tester) async {
      final scores = await _submit(tester, androidAccount: true);
      expect(find.byType(LeaderboardSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('submit-name')), findsNothing);
      expect(scores.submissions, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('legacy submit saves once with age unspecified', (tester) async {
    final completion = Completer<RankInfo>();
    final scores = await _submit(tester, completion: completion);
    await tester.enterText(
      find.byKey(const ValueKey('submit-name')),
      'IsolatedPlayer',
    );
    await tester.tap(find.byKey(const ValueKey('submit-save')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('submit-save')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('submit-save')));
    expect(scores.submissions, 1);
    completion.complete(RankInfo(place: 1, percentile: 90, totalCount: 10));
    await tester.pumpAndSettle();
    expect(scores.submissions, 1);
    expect(find.byKey(const ValueKey('submit-content')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
