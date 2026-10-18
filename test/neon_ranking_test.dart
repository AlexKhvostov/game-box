import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/leaderboard/leaderboard_panel.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/features/leaderboard/leaderboard_screen.dart';
import 'package:game_box/features/leaderboard/leaderboard_widgets.dart';
import 'package:game_box/features/leaderboard/player_result_sheet.dart';
import 'package:game_box/features/leaderboard/ranking_art.dart';
import 'package:game_box/l10n/app_localizations.dart';

class RankingFixtures extends ScoresStore {
  RankingFixtures(MobileAccount owner) : super(account: owner) {
    online = true;
  }
  bool empty = false;
  bool largeNumbers = false;
  int reloads = 0;
  final periods = <String>[];
  static const names = [
    'NeonFox',
    'SkyRunner',
    'Mira',
    'PlayerNova',
    'Вы',
    'CubeCat',
    'Ghost',
    'ОченьДлинныйНикИгрока123',
    'Pixel',
    'Лиса',
    'NightCube',
    'Nova',
  ];
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
  @override
  Future<void> load() async {
    reloads++;
  }

  @override
  List<ScoreEntry> scoresForNamedPeriod(String period) {
    periods.add(period);
    return empty
        ? []
        : List.generate(
            12,
            (i) => ScoreEntry(
              id: '$period-$i',
              uid: i == 4 ? account!.id : 'fixture-$i',
              displayName: names[i],
              timeMs: largeNumbers ? 2147483000 - i : 31000 - i * 973,
              createdAt: DateTime(2026, 10, 17, 0, 52 - i),
              countryCode: ['BY', 'PL', 'DE'][i % 3],
              riskCount: largeNumbers ? 999999 : 8 - i % 5,
              runDistance: largeNumbers ? 999999999 : 435 - i * 10,
              hadJump: i % 4 < 2,
              hadHelmet: i.isEven,
            ),
          );
  }

  @override
  bool isAttemptPending(String id) => id == 'pending';
  @override
  List<LocalAttempt> get myAttempts => empty
      ? []
      : [
          LocalAttempt(
            id: 'shared',
            timeMs: 27108,
            createdAt: DateTime(2026, 10, 17),
            shared: true,
            displayName: 'Вы',
            hadJump: true,
            hadHelmet: true,
          ),
          LocalAttempt(
            id: 'pending',
            timeMs: 23155,
            createdAt: DateTime(2026, 10, 17),
            hadJump: true,
          ),
        ];
}

class DenseMineFixtures extends RankingFixtures {
  DenseMineFixtures(super.owner);
  @override
  List<LocalAttempt> get myAttempts => List.generate(
    12,
    (i) => LocalAttempt(
      id: 'mine-$i',
      timeMs: 31000 - i * 973,
      createdAt: DateTime(2026, 10, 17, 0, i),
      shared: true,
      displayName: 'Игрок0',
      riskCount: i % 3,
      runDistance: 172 + i,
      hadJump: i.isEven,
      hadHelmet: i % 3 == 0,
    ),
  );
}

Future<void> mountRanking(
  WidgetTester tester,
  RankingFixtures store, {
  Size size = const Size(360, 740),
  double scale = 1,
  bool screen = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store.account!),
        ChangeNotifierProvider<ScoresStore>.value(value: store),
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
        home: screen
            ? const Scaffold(body: LeaderboardScreen())
            : Builder(
                builder: (context) => Scaffold(
                  backgroundColor: const Color(0xFF031827),
                  body: TextButton(
                    onPressed: () => showLeaderboardSheet(context),
                    child: const Text('open'),
                  ),
                ),
              ),
      ),
    ),
  );
  if (!screen) await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  final out = Platform.environment['RANKING_EVIDENCE_DIR'];
  if (out == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('ranking-frame')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(out).create(recursive: true);
    await File('$out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final fontPath = Platform.environment['RANKING_FONT_DIR'];
    if (fontPath == null) return;
    final loader = FontLoader('Roboto');
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$fontPath/$name').readAsBytes()),
        ),
      );
    }
    await loader.load();
    final iconPath = Platform.environment['RANKING_ICON_FONT'];
    if (iconPath != null) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(
              ByteData.sublistView(await File(iconPath).readAsBytes()),
            ),
          ))
          .load();
    }
  });

  for (final width in [320.0, 360.0]) {
    testWidgets(
      'Mine retains date and status with seven compact rows width$width',
      (tester) async {
        final account = MobileAccount()..id = 'ranking-mine-fixture';
        final store = DenseMineFixtures(account);
        await mountRanking(tester, store, size: Size(width, 740));
        await tester.tap(find.byKey(const ValueKey('leaderboard-filter-5')));
        await tester.pumpAndSettle();
        final viewport = tester.getRect(find.byType(ListView));
        final seventh = find.byKey(const ValueKey('ranking-row-7'));
        expect(seventh, findsOneWidget);
        expect(
          tester.getRect(seventh).bottom,
          lessThanOrEqualTo(viewport.bottom),
          reason: 'Seven full Mine rows, including date/status',
        );
        expect(find.text('В рейтинге'), findsWidgets);
        expect(find.textContaining('17.10'), findsWidgets);
        await capture(tester, 'flutter-mine-seven-${width.toInt()}');
        await tester.tap(find.byType(MyAttemptRow).first);
        await tester.pumpAndSettle();
        expect(find.byType(PlayerResultSheet), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const PageStorageKey('ranking-mine')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
        account.dispose();
      },
    );
  }

  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'approved ranking width$width scale$scale geometry and bundled vectors',
        (tester) async {
          final account = MobileAccount()..id = 'ranking-fixture-owner';
          final store = RankingFixtures(account);
          await mountRanking(
            tester,
            store,
            size: Size(width, 740),
            scale: scale,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(RankingArt), findsWidgets);
          final view = tester.getRect(find.byType(ListView));
          if (scale == 1) {
            final seventh = tester.getRect(
              find.byKey(const ValueKey('ranking-row-7')),
            );
            expect(
              seventh.bottom,
              lessThanOrEqualTo(view.bottom),
              reason: 'Seven complete rows at normal scale',
            );
          }
          await capture(tester, 'flutter-ranking-${width.toInt()}-$scale');
          for (final place in [1, 2, 3]) {
            final medal = find.byWidgetPredicate(
              (w) => w is RankingArt && w.name == 'medal-$place',
            );
            if (medal.evaluate().isEmpty) {
              await tester.scrollUntilVisible(
                medal,
                100,
                scrollable: find.byType(Scrollable).last,
              );
            }
            expect(medal, findsOneWidget);
          }
          final ownFinder = find.byWidgetPredicate(
            (w) => w is LeaderboardDetailRow && w.place == 5,
          );
          if (ownFinder.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              ownFinder,
              100,
              scrollable: find.byType(Scrollable).last,
            );
          }
          expect(
            tester.widget<LeaderboardDetailRow>(ownFinder).highlight,
            isTrue,
          );
          await tester.pumpWidget(const SizedBox());
          store.dispose();
          account.dispose();
        },
      );
    }
  }

  testWidgets(
    'all periods use real store selector, scroll and details preserve controls and position',
    (tester) async {
      final account = MobileAccount()..id = 'ranking-fixture-owner';
      final store = RankingFixtures(account);
      await mountRanking(tester, store);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(ValueKey('leaderboard-filter-$i')));
        await tester.pumpAndSettle();
        expect(store.periods.last, ['all', 'year', 'month', 'week', 'day'][i]);
        await capture(tester, 'flutter-period-$i');
      }
      final headerBefore = tester.getRect(
        find.byKey(const ValueKey('leaderboard-filter-0')),
      );
      final footerBefore = tester.getRect(
        find.byKey(const ValueKey('ranking-footer')),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -280));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).last,
      );
      final offset = scroll.position.pixels;
      expect(offset, greaterThan(0));
      expect(
        tester.getRect(find.byKey(const ValueKey('leaderboard-filter-0'))),
        headerBefore,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('ranking-footer'))),
        footerBefore,
      );
      final longName = find.text('ОченьДлинныйНикИгрока123');
      await tester.ensureVisible(longName);
      await tester.pumpAndSettle();
      final afterScroll = scroll.position.pixels;
      await capture(tester, 'flutter-ranking-scrolled');
      await tester.tap(longName);
      await tester.pumpAndSettle();
      expect(find.byType(PlayerResultSheet), findsOneWidget);
      expect(
        find.descendant(of: find.byType(PlayerResultSheet), matching: longName),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, closeTo(afterScroll, .1));
      expect(
        tester
            .state<LeaderboardPanelState>(find.byType(LeaderboardPanel))
            .filter,
        4,
      );
      await tester.tap(find.byKey(const ValueKey('leaderboard-filter-5')));
      await tester.pumpAndSettle();
      expect(find.text('Ожидает сети'), findsOneWidget);
      expect(find.text('Отправится автоматически'), findsOneWidget);
      await capture(tester, 'flutter-mine-pending');
      await tester.tap(find.byType(MyAttemptRow).first);
      await tester.pumpAndSettle();
      expect(find.text('Это ваш личный результат'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .state<LeaderboardPanelState>(find.byType(LeaderboardPanel))
            .filter,
        5,
      );
      await tester.tap(find.byKey(const ValueKey('leaderboard-filter-4')));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position
            .pixels,
        closeTo(afterScroll, .1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      account.dispose();
    },
  );

  testWidgets('empty, network error, retry and loading retain fixed footer', (
    tester,
  ) async {
    final account = MobileAccount()..id = 'ranking-fixture-owner';
    final store = RankingFixtures(account)..empty = true;
    await mountRanking(tester, store);
    await capture(tester, 'flutter-empty');
    store.online = false;
    store.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Повторить'), findsOneWidget);
    await capture(tester, 'flutter-error');
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    expect(store.reloads, 1);
    store.loading = true;
    store.notifyListeners();
    await tester.pump();
    expect(find.text('Загружаем рейтинг…'), findsOneWidget);
    await capture(tester, 'flutter-loading');
    expect(find.byKey(const ValueKey('ranking-footer')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    account.dispose();
  });

  testWidgets('long numbers and names fit narrow native columns', (
    tester,
  ) async {
    final account = MobileAccount()..id = 'ranking-fixture-owner';
    final store = RankingFixtures(account)..largeNumbers = true;
    await mountRanking(tester, store, size: const Size(320, 740), scale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('2147483.000 с'), findsOneWidget);
    await capture(tester, 'flutter-long-numbers');
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    account.dispose();
  });

  testWidgets('standalone route uses the same approved native window', (
    tester,
  ) async {
    final account = MobileAccount()..id = 'ranking-fixture-owner';
    final store = RankingFixtures(account);
    await mountRanking(tester, store, screen: true);
    expect(find.byKey(const ValueKey('ranking-frame')), findsOneWidget);
    expect(find.byType(LeaderboardRankRow), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    account.dispose();
  });
}
