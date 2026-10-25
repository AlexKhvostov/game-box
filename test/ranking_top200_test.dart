import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/domain/average_ranking.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/features/leaderboard/ranking_summary.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'average_ranking_test.dart' show AverageAccount;

class TopFixture extends ScoresStore {
  TopFixture(MobileAccount account, this.ownPlace) : super(account: account) {
    online = true;
    averageRanking = AverageRanking(
      rows: [for (var i = 1; i <= 200; i++) average(i)],
      mine: average(ownPlace),
    );
  }
  @override
  Future<void> loadAttemptHistory({
    bool more = false,
    bool refresh = false,
  }) async {}
  final int ownPlace;
  AverageRankEntry average(int place) => AverageRankEntry(
    userId: place == ownPlace ? account!.id : 'other-$place',
    playerName: place == ownPlace ? 'Вы' : 'Игрок $place',
    averageMs: 200000 - place.toDouble(),
    usedCount: 50,
    eligibleCount: 61,
    totalAttempts: 123,
    place: place,
  );
  @override
  List<ScoreEntry> scoresForNamedPeriod(String period) => [
    for (var i = 1; i <= 200; i++) record(i, period),
    if (ownPlace > 200) record(ownPlace, period),
  ];
  ScoreEntry record(int place, String period) => ScoreEntry(
    id: '$period-$place',
    uid: place == ownPlace ? account!.id : 'other-$place',
    displayName: place == ownPlace ? 'Вы' : 'Игрок $place',
    timeMs: (period == 'day' ? 200000 : 300000) - place,
    createdAt: DateTime(2026, 10, 18),
    place: place,
    hadJump: place.isEven,
    hadHelmet: true,
    riskCount: 8,
    runDistance: 435,
  );
  @override
  List<LocalAttempt> get myAttempts => [
    for (var i = 1; i <= 7; i++)
      LocalAttempt(
        id: 'attempt-$i',
        timeMs: 3000 + i,
        createdAt: DateTime(2026, 10, 18),
        shared: true,
        displayName: 'Вы',
      ),
  ];
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
  @override
  Future<void> load() async {}
}

Future<void> host(
  WidgetTester t,
  TopFixture store,
  Size size,
  double scale,
) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ScoresStore>.value(value: store),
        ChangeNotifierProvider<MobileAccount>.value(value: store.account!),
      ],
      child: MaterialApp(
        theme: buildGameTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(body: LeaderboardSheet()),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> shot(WidgetTester t, String name) async {
  final dir = Platform.environment['TOP200_EVIDENCE_DIR'];
  if (dir == null) return;
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('ranking-frame')).last,
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
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
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final place in [1, 50, 200, 201, 520]) {
    testWidgets(
      'top200 / own $place keeps real place, one own row, divider only outside',
      (t) async {
        final account = AverageAccount(),
            store = TopFixture(AverageAccount(), place);
        addTearDown(() => t.view.resetPhysicalSize());
        addTearDown(() => t.view.resetDevicePixelRatio());
        await host(t, store, const Size(360, 720), 1);
        expect(
          t.getRect(find.byKey(const ValueKey('ranking-legend'))).bottom,
          lessThanOrEqualTo(
            t.getRect(find.byKey(const ValueKey('ranking-periods'))).top,
          ),
        );
        expect(
          t
              .getSize(find.byKey(const ValueKey('record-personal-summary')))
              .height,
          lessThanOrEqualTo(30),
        );
        final list = find.byKey(const PageStorageKey('ranking-day'));
        expect(
          (t.widget<ListView>(list).childrenDelegate
                  as SliverChildBuilderDelegate)
              .childCount,
          place > 200 ? 202 : 200,
        );
        await shot(t, 'record-$place');
        if (place > 200) {
          await t.scrollUntilVisible(
            find.byKey(ValueKey('record-row-$place')),
            600,
            scrollable: find.descendant(
              of: list,
              matching: find.byType(Scrollable),
            ),
            maxScrolls: 80,
          );
          expect(find.byType(RankingOwnDivider), findsOneWidget);
          expect(find.text('Игрок 201'), findsNothing);
          expect(find.text('Игрок 519'), findsNothing);
          await shot(t, 'record-$place-bottom');
          await t.tap(find.byKey(ValueKey('record-row-$place')));
          await t.pumpAndSettle();
          expect(find.textContaining('$place'), findsWidgets);
          Navigator.of(t.element(find.byType(Scaffold).first)).pop();
          await t.pumpAndSettle();
        }
        await t.tap(find.byKey(const ValueKey('leaderboard-filter-6')));
        await t.pumpAndSettle();
        final averages = find.byKey(const PageStorageKey('ranking-average'));
        expect(
          (t.widget<ListView>(averages).childrenDelegate
                  as SliverChildBuilderDelegate)
              .childCount,
          place > 200 ? 202 : 200,
        );
        expect(find.text('Попыток: 123'), findsOneWidget);
        expect(
          t
              .getSize(find.byKey(const ValueKey('average-personal-summary')))
              .height,
          lessThanOrEqualTo(30),
        );
        await shot(t, 'average-$place');
        if (place > 200) {
          await t.scrollUntilVisible(
            find.byKey(ValueKey('average-row-$place')),
            600,
            scrollable: find.descendant(
              of: averages,
              matching: find.byType(Scrollable),
            ),
            maxScrolls: 80,
          );
          expect(find.byType(RankingOwnDivider), findsOneWidget);
          expect(find.text('Игрок 201'), findsNothing);
          await shot(t, 'average-$place-bottom');
        }
        expect(t.takeException(), null);
        await t.pumpWidget(const SizedBox());
        store.dispose();
        store.account!.dispose();
        account.dispose();
      },
    );
  }
  for (final size in [const Size(320, 480), const Size(430, 800)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'attached ranking and history fit $size at text scale $scale',
        (t) async {
          final store = TopFixture(AverageAccount(), 50);
          addTearDown(() => t.view.resetPhysicalSize());
          addTearDown(() => t.view.resetDevicePixelRatio());
          await host(t, store, size, scale);
          await shot(t, 'record-${size.width}-$scale');
          await t.tap(find.byKey(const ValueKey('leaderboard-filter-2')));
          await t.pumpAndSettle();
          expect(find.textContaining('299.950'), findsOneWidget);
          await t.tap(find.byKey(const ValueKey('leaderboard-filter-6')));
          await t.pumpAndSettle();
          await shot(t, 'average-${size.width}-$scale');
          await t.tap(find.byKey(const ValueKey('ranking-my-attempts')));
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('my-attempts-mean')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('my-attempts-total')),
              matching: find.text('123'),
            ),
            findsOneWidget,
          );
          await shot(t, 'history-${size.width}-$scale');
          expect(t.takeException(), null);
          await t.pumpWidget(const SizedBox());
          store.dispose();
          store.account!.dispose();
        },
      );
    }
  }
}
