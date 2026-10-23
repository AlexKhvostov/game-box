import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/average_ranking.dart';
import 'package:game_box/domain/server_attempt_history.dart';
import 'package:game_box/features/leaderboard/my_attempts_panel.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'server_attempt_history_test.dart' show historyReply, historyOwner;

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['SERVER_HISTORY_EVIDENCE_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('server-history-capture')),
    );
    final snapshot = await boundary.toImage(pixelRatio: 2);
    final bytes = await snapshot.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    snapshot.dispose();
  });
}

class HistoryUiAccount extends MobileAccount {
  HistoryUiAccount() : super(storagePrefix: 'supabase_android_history_ui_') {
    id = historyOwner;
  }
  void changeOwner(String owner) {
    id = owner;
    notifyListeners();
  }
}

class HistoryUiStore extends ScoresStore {
  HistoryUiStore() : super(account: HistoryUiAccount()) {
    serverAttemptHistory = ServerAttemptHistory.fromJson(
      historyReply(),
      owner: historyOwner,
    );
    // A newer unrelated ranking refresh must not detach the history average.
    averageRanking = const AverageRanking(
      mine: AverageRankEntry(averageMs: 99999),
    );
  }
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
  int loads = 0;
  @override
  Future<void> loadAttemptHistory({
    bool more = false,
    bool refresh = false,
  }) async {
    if (more) {
      loads++;
      serverAttemptHistory = serverAttemptHistory!.append(
        ServerAttemptHistory.fromJson(
          historyReply(offset: serverAttemptHistory!.rows.length),
          owner: historyOwner,
        ),
      );
      notifyListeners();
    }
  }
}

class EmptyRetryUiStore extends HistoryUiStore {
  int retries = 0;
  EmptyRetryUiStore() {
    serverAttemptHistory = null;
  }
  @override
  Future<void> loadAttemptHistory({
    bool more = false,
    bool refresh = false,
  }) async {
    if (++retries == 1) {
      historyError = 'connection_failed';
    } else {
      historyError = null;
      serverAttemptHistory = ServerAttemptHistory.fromJson(
        historyReply(),
        owner: historyOwner,
      );
    }
    notifyListeners();
  }
}

void main() {
  setUpAll(() async {
    final dir = Platform.environment['RANKING_FONT_DIR'];
    if (dir == null) return;
    final loader = FontLoader('Roboto');
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$dir/$name').readAsBytes()),
        ),
      );
    }
    await loader.load();
    final icon = Platform.environment['RANKING_ICON_FONT'];
    if (icon != null) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(await File(icon).readAsBytes())),
          ))
          .load();
    }
  });
  for (final language in ['ru', 'en']) {
    testWidgets(
      'Confirmed empty history does not claim it is still loading $language',
      (t) async {
        final store = HistoryUiStore();
        store.serverAttemptHistory = ServerAttemptHistory.fromJson(
          historyReply(total: 0),
          owner: historyOwner,
        );
        addTearDown(store.dispose);
        addTearDown(store.account!.dispose);
        await t.pumpWidget(
          ChangeNotifierProvider<ScoresStore>.value(
            value: store,
            child: MaterialApp(
              theme: buildGameTheme(),
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: Center(child: MyAttemptsSheet())),
            ),
          ),
        );
        await t.pumpAndSettle();
        final mean = find.byKey(const ValueKey('my-attempts-mean'));
        expect(
          find.descendant(
            of: mean,
            matching: find.text(language == 'ru' ? 'Учтено: 0' : 'Counted: 0'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: mean,
            matching: find.text(language == 'ru' ? 'Загружаем' : 'Loading'),
          ),
          findsNothing,
        );
        expect(
          t
              .widget<Text>(
                find.byKey(const ValueKey('my-attempts-empty-graph-message')),
              )
              .data,
          language == 'ru' ? 'Пока нет попыток' : 'No attempts yet',
        );
        store.serverAttemptHistory = null;
        store.historyLoading = true;
        store.notifyListeners();
        await t.pump();
        expect(
          t
              .widget<Text>(
                find.byKey(const ValueKey('my-attempts-empty-graph-message')),
              )
              .data,
          language == 'ru' ? 'Загружаем историю…' : 'Loading history…',
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final language in ['ru', 'en']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Three summary blocks fit 320px $language scale$scale using the server total',
        (t) async {
          t.view.physicalSize = const Size(320, 640);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final store = HistoryUiStore();
          addTearDown(store.dispose);
          addTearDown(store.account!.dispose);
          await t.pumpWidget(
            ChangeNotifierProvider<ScoresStore>.value(
              value: store,
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
                home: const Scaffold(body: Center(child: MyAttemptsSheet())),
              ),
            ),
          );
          await t.pumpAndSettle();
          final total = find.byKey(const ValueKey('my-attempts-total'));
          final best = find.byKey(const ValueKey('my-attempts-best'));
          final mean = find.byKey(const ValueKey('my-attempts-mean'));
          expect(t.getRect(total).right, lessThan(t.getRect(best).left));
          expect(t.getRect(best).right, lessThan(t.getRect(mean).left));
          expect(
            find.descendant(of: total, matching: find.text('650')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('my-attempts-selection')),
            findsNothing,
          );
          expect(
            find.text(
              language == 'ru' ? 'Среднее 20,000 с' : 'Average 20.000 s',
            ),
            findsOneWidget,
          );
          await t.tap(mean);
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('my-attempts-average-help')),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'Actual SQL snapshot renders one current mean and its five historical points',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final reply = Map<String, dynamic>.from(
        jsonDecode(
              File(
                'test/fixtures/server_attempt_history_sql.json',
              ).readAsStringSync(),
            )
            as Map,
      );
      final owner = (reply['history'] as Map)['userId'] as String;
      final store = HistoryUiStore();
      // Set the fixture's owner first: identity notification intentionally clears
      // any previous account snapshot before the SQL response is assigned.
      (store.account! as HistoryUiAccount).changeOwner(owner);
      store.serverAttemptHistory = ServerAttemptHistory.fromJson(
        reply,
        owner: owner,
      );
      addTearDown(store.dispose);
      addTearDown(store.account!.dispose);
      await t.pumpWidget(
        ChangeNotifierProvider<ScoresStore>.value(
          value: store,
          child: RepaintBoundary(
            key: const ValueKey('server-history-capture'),
            child: MaterialApp(
              theme: buildGameTheme(),
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: Center(child: MyAttemptsSheet())),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('5,665 с'), findsOneWidget);
      expect(find.text('Среднее 5,665 с'), findsOneWidget);
      expect(find.text('История · 5 / 5'), findsOneWidget);
      final painter = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<MyAttemptsChartPainter>()
          .single;
      expect(painter.averages.length, 5);
      expect(painter.averages['tg_history_owner_0'], 2000);
      expect(painter.averages['tg_history_owner_1'], 3201.5621187164243);
      expect(painter.averages['tg_history_owner_2'], 4422.457018947937);
      expect(painter.averages['tg_history_owner_3'], 5665.183990622241);
      expect(painter.averages['tg_history_zero'], 5665.183990622241);
      expect(painter.rows.map((r) => r.timeMs), [2000, 4000, 6000, 8000, 0]);
      expect(painter.referenceAverageMs, isNull);
      await _capture(t, 'sql-curve-390');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'First history error offers retry without claiming the account has no results',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = EmptyRetryUiStore();
      addTearDown(store.dispose);
      addTearDown(store.account!.dispose);
      await t.pumpWidget(
        ChangeNotifierProvider<ScoresStore>.value(
          value: store,
          child: RepaintBoundary(
            key: const ValueKey('server-history-capture'),
            child: MaterialApp(
              theme: buildGameTheme(),
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: Center(child: MyAttemptsSheet())),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('История временно недоступна'), findsNWidgets(2));
      expect(
        t
            .widget<Text>(
              find.byKey(const ValueKey('my-attempts-empty-graph-message')),
            )
            .data,
        'История временно недоступна',
      );
      expect(find.text('Пока нет попыток'), findsNothing);
      expect(find.textContaining('Пока нет результатов.'), findsNothing);
      await _capture(t, 'emptyretry-390');
      await t.tap(find.byKey(const ValueKey('my-attempts-history-retry')));
      await t.pumpAndSettle();
      expect(store.retries, 2);
      expect(find.text('История · 100 / 650'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('my-attempts-history-retry')),
        findsNothing,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final size in [const Size(390, 844), const Size(320, 640)]) {
    testWidgets(
      'Server curve, current values, real ordinal and page loading at $size',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final store = HistoryUiStore();
        addTearDown(store.dispose);
        addTearDown(store.account!.dispose);
        await t.pumpWidget(
          ChangeNotifierProvider<ScoresStore>.value(
            value: store,
            child: RepaintBoundary(
              key: const ValueKey('server-history-capture'),
              child: MaterialApp(
                theme: buildGameTheme(),
                locale: const Locale('ru'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(body: Center(child: MyAttemptsSheet())),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('20,000 с'), findsOneWidget);
        expect(find.text('Среднее 20,000 с'), findsOneWidget);
        expect(find.text('История · 100 / 650'), findsOneWidget);
        final totalBlock = find.byKey(const ValueKey('my-attempts-total'));
        final bestBlock = find.byKey(const ValueKey('my-attempts-best'));
        final meanBlock = find.byKey(const ValueKey('my-attempts-mean'));
        expect(t.getRect(totalBlock).left, lessThan(t.getRect(bestBlock).left));
        expect(t.getRect(bestBlock).left, lessThan(t.getRect(meanBlock).left));
        expect(
          find.descendant(of: totalBlock, matching: find.text('650')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('my-attempts-selection')),
          findsNothing,
        );
        final painter = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<MyAttemptsChartPainter>()
            .single;
        expect(painter.referenceAverageMs, isNull);
        expect(painter.rows, hasLength(100));
        expect(store.serverAttemptHistory!.average.windowSize, 50);
        expect(painter.averages.values.toSet().length, greaterThan(2));
        expect(painter.numbers['round-650'], 650);
        expect(painter.averages['round-551'], 19505);
        await _capture(t, 'servercurve-${size.width.toInt()}');
        final plot = t.getRect(find.byKey(const ValueKey('my-attempts-plot')));
        await t.tapAt(Offset(plot.left + 36, plot.center.dy));
        await t.pumpAndSettle();
        expect(find.text('Среднее 20,000 с'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('my-attempts-mean')));
        await t.pumpAndSettle();
        expect(
          find.textContaining('Свежие попытки влияют сильнее старых.'),
          findsOneWidget,
        );
        expect(find.textContaining('92'), findsNothing);
        await _capture(t, 'help-${size.width.toInt()}');
        await t.tap(find.byKey(const ValueKey('my-attempts-help-done')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('my-attempts-toggle')));
        await t.pumpAndSettle();
        await t.drag(
          find.byKey(const ValueKey('my-attempts-history')),
          const Offset(0, -10000),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('my-attempts-load-more')));
        await t.pumpAndSettle();
        expect(store.loads, 1);
        expect(find.text('История · 200 / 650'), findsOneWidget);
        expect(find.text('20,000 с'), findsOneWidget);
        await _capture(t, 'loadmore-${size.width.toInt()}');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
