import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/average_chart.dart';
import 'package:game_box/domain/average_ranking.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/features/leaderboard/my_attempts_panel.dart';
import 'package:game_box/l10n/app_localizations.dart';

const owner = 'supabase:12345678-1234-4234-8234-123456789abc';

class _WalletAccount extends MobileAccount {
  _WalletAccount(this.confirmedOwner) {
    id = owner;
    wallet = {'bestTimeMs': 99999};
  }
  final String? confirmedOwner;
  @override
  String? get walletOwner => confirmedOwner;
}

class _WalletStore extends ScoresStore {
  _WalletStore(MobileAccount account) : super(account: account);
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
}

class AttemptsStore extends ScoresStore {
  AttemptsStore()
    : super(
        account: MobileAccount(storagePrefix: 'supabase_android_ui_')
          ..id = owner,
      ) {
    history = List.generate(100, (i) {
      final number = i + 1;
      final time = i == 99
          ? 18724
          : ((2.1 +
                        i * .09 +
                        math.sin(i * 2.43).abs() * 9.1 +
                        (i % 13 == 0 ? 4.3 : 0)) *
                    1000)
                .round();
      final today = number > 92;
      return LocalAttempt(
        id: '$number',
        timeMs: time,
        shared: true,
        createdAt: DateTime(
          2026,
          10,
          today ? 21 : 20,
          18,
          40,
        ).subtract(Duration(minutes: ((today ? 100 : 92) - number) * 7)),
        runDistance: (time / 1000 * 31.6 + i * 2).round(),
        riskCount: i * 7 % 9,
      );
    });
    final chart = AverageChartData.fromAttempts(
      attempts: history,
      ranking: const AverageRanking(
        algorithm: AverageRanking.quadraticAlgorithm,
      ),
    );
    averageRanking = AverageRanking(
      algorithm: AverageRanking.quadraticAlgorithm,
      mine: AverageRankEntry(
        averageMs: chart.averageMs,
        totalAttempts: history.length,
        usedCount: chart.currentWindowCount,
        eligibleCount: history.length,
      ),
    );
    online = true;
  }
  late List<LocalAttempt> history;
  @override
  List<LocalAttempt> get myAttempts => List.of(history);
  @override
  List<ScoreEntry> scoresForNamedPeriod(String period) {
    final best = history.reduce((a, b) => a.timeMs > b.timeMs ? a : b);
    return [
      ScoreEntry(
        id: best.id,
        uid: owner,
        displayName: 'Player',
        timeMs: best.timeMs,
        createdAt: best.createdAt,
      ),
    ];
  }

  @override
  Future<void> loadAttemptHistory({
    bool more = false,
    bool refresh = false,
  }) async {}
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
}

Future<void> _capture(WidgetTester t, String name) async {
  final directory = Platform.environment['MY_ATTEMPTS_EVIDENCE_DIR'];
  if (directory == null) return;
  await t.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await t.pump();
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('attempts-capture')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  for (final validOwner in [true, false]) {
    testWidgets(
      'Wallet-only best uses current owner and never fabricates a date owner$validOwner',
      (t) async {
        final account = _WalletAccount(validOwner ? owner : 'other');
        final store = _WalletStore(account);
        addTearDown(store.dispose);
        addTearDown(account.dispose);
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          ChangeNotifierProvider<ScoresStore>.value(
            value: store,
            child: MaterialApp(
              theme: buildGameTheme(),
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: Center(child: MyAttemptsSheet())),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.text('99,999 с'),
          validOwner ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Дата недоступна'),
          validOwner ? findsOneWidget : findsNothing,
        );
        expect(
          t
              .widget<InkWell>(find.byKey(const ValueKey('my-attempts-best')))
              .onTap,
          isNull,
        );
        expect(
          find.byKey(const ValueKey('my-attempts-missing-record')),
          findsNothing,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'Partial history keeps the same official mean when an old attempt is selected',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = AttemptsStore();
      store.history = store.history.take(11).toList();
      store.averageRanking = const AverageRanking(
        algorithm: AverageRanking.quadraticAlgorithm,
        mine: AverageRankEntry(
          averageMs: 11716.093,
          usedCount: 32,
          totalAttempts: 32,
        ),
      );
      addTearDown(store.dispose);
      addTearDown(store.account!.dispose);
      await t.pumpWidget(
        ChangeNotifierProvider<ScoresStore>.value(
          value: store,
          child: MaterialApp(
            theme: buildGameTheme(),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: RepaintBoundary(
                key: const ValueKey('attempts-capture'),
                child: const MyAttemptsSheet(),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('11,716 с'), findsOneWidget);
      expect(find.text('Среднее 11,716 с'), findsOneWidget);
      final painter = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<MyAttemptsChartPainter>()
          .single;
      expect(painter.referenceAverageMs, isNull);
      expect(painter.averages, isEmpty);
      final mean = find.byKey(const ValueKey('my-attempts-mean'));
      final best = find.byKey(const ValueKey('my-attempts-best'));
      BoxDecoration decoration(Finder finder) =>
          t
                  .widget<Container>(
                    find
                        .descendant(
                          of: finder,
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(
        (decoration(mean).border! as Border).top.color,
        const Color(0xFFFFE368),
      );
      expect(
        (decoration(best).border! as Border).top.color,
        isNot(const Color(0xFFFFE368)),
      );
      final plot = t.getRect(find.byKey(const ValueKey('my-attempts-plot')));
      await t.tapAt(Offset(plot.left + 36, plot.center.dy));
      await t.pumpAndSettle();
      expect(find.text('Среднее 11,716 с'), findsOneWidget);
      expect(find.textContaining('тогда'), findsNothing);
      await _capture(t, 'partial-official-390');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(320, 640),
    const Size(320, 480),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'My attempts native layout $size scale$scale, popup, collapse and reopen',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final store = AttemptsStore();
          addTearDown(store.dispose);
          addTearDown(store.account!.dispose);
          await t.pumpWidget(
            ChangeNotifierProvider<ScoresStore>.value(
              value: store,
              child: MaterialApp(
                theme: buildGameTheme(),
                locale: const Locale('ru'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => RepaintBoundary(
                  key: const ValueKey('attempts-capture'),
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showMyAttemptsSheet(context),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.tap(find.text('Open'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('my-attempts-plot')),
            findsOneWidget,
          );
          final history = find.byKey(const ValueKey('my-attempts-history'));
          final before = t.getRect(history);
          expect(
            before.height,
            greaterThanOrEqualTo(t.widget<ListView>(history).itemExtent! + 5),
          );
          final capture = scale == 1 && size.height != 480;
          if (capture) await _capture(t, 'expanded-${size.width.toInt()}');
          await t.tap(find.byKey(const ValueKey('my-attempts-mean')));
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('my-attempts-average-help')),
            findsOneWidget,
          );
          expect(
            find.textContaining('Свежие попытки влияют сильнее старых'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Большие результаты влияют сильнее маленьких'),
            findsOneWidget,
          );
          expect(find.textContaining('%'), findsNothing);
          expect(t.getRect(history), before);
          expect(t.takeException(), isNull);
          if (capture) await _capture(t, 'help-${size.width.toInt()}');
          await t.tap(find.byKey(const ValueKey('my-attempts-help-done')));
          await t.pumpAndSettle();
          await t.ensureVisible(
            find.byKey(const ValueKey('my-attempts-toggle')),
          );
          await t.tap(find.byKey(const ValueKey('my-attempts-toggle')));
          await t.pumpAndSettle();
          expect(find.byKey(const ValueKey('my-attempts-plot')), findsNothing);
          expect(t.getRect(history).height, greaterThan(before.height));
          if (capture) await _capture(t, 'collapsed-${size.width.toInt()}');
          await t.tap(find.byKey(const ValueKey('my-attempts-close')));
          await t.pumpAndSettle();
          await t.tap(find.text('Open'));
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('my-attempts-plot')),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
