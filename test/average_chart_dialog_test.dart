import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/average_ranking.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/leaderboard/average_ranking_panel.dart';
import 'package:game_box/l10n/app_localizations.dart';

final durations = List.generate(
  100,
  (i) => i % 13 == 3 ? 200 + (i % 8) * 100 : 1000 + ((i * 7307 + 1931) % 19001),
);

class ChartStore extends ScoresStore {
  ChartStore() {
    online = true;
    averageRanking = const AverageRanking(
      algorithm: AverageRanking.quadraticAlgorithm,
      mine: AverageRankEntry(
        averageMs: 10995.868454706817,
        totalAttempts: 100,
        usedCount: 50,
        eligibleCount: 100,
        place: 1,
      ),
    );
  }
  List<LocalAttempt> history = [
    for (var i = 0; i < durations.length; i++)
      LocalAttempt(
        id: '$i',
        timeMs: durations[i],
        createdAt: DateTime.utc(2026, 10, 19).add(Duration(seconds: i)),
        shared: true,
      ),
  ];
  @override
  List<LocalAttempt> get myAttempts => List.of(history);
  void updateHistory(List<LocalAttempt> value) {
    history = value;
    notifyListeners();
  }

  @override
  Future<void> load() async {}
}

Future<void> mount(
  WidgetTester t,
  ChartStore store, {
  double scale = 1,
  String lang = 'ru',
}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: buildGameTheme(),
      locale: Locale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (c, child) => RepaintBoundary(
        key: const ValueKey('chart-capture'),
        child: MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: Scaffold(body: AverageRankingPanel(store: store)),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('average-chart-open')));
  await t.pumpAndSettle();
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
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(ByteData.sublistView(await File(icon).readAsBytes())),
        );
      await icons.load();
    }
  });
  for (final size in [
    const Size(1000, 780),
    const Size(390, 844),
    const Size(320, 480),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'graph opens/closes without losing ranking at $size scale$scale',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final store = ChartStore();
          addTearDown(store.dispose);
          await mount(t, store, scale: scale);
          expect(
            find.byKey(const ValueKey('average-chart-dialog')),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          expect(find.textContaining('100 сохранённых'), findsOneWidget);
          expect(find.text('В расчёте — последние 50'), findsOneWidget);
          final close = t.getRect(
            find.byKey(const ValueKey('average-chart-close')),
          );
          expect(close.right, lessThanOrEqualTo(size.width));
          expect(close.top, greaterThanOrEqualTo(0));
          if (scale == 1) {
            final out = Platform.environment['AVERAGE_CHART_EVIDENCE_DIR'];
            if (out != null)
              await t.runAsync(() async {
                final boundary = t.renderObject<RenderRepaintBoundary>(
                  find.byKey(const ValueKey('chart-capture')),
                );
                final image = await boundary.toImage(pixelRatio: 2);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(out).create(recursive: true);
                await File(
                  '$out/flutter-${size.width.toInt()}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
          }
          await t.tap(find.byKey(const ValueKey('average-chart-close')));
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('average-chart-dialog')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('average-ranking-info')),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'bar selection, offline/partial and owner history changes remain read-only',
    (t) async {
      final store = ChartStore();
      addTearDown(store.dispose);
      store.online = false;
      await mount(t, store);
      expect(find.text('Без сети · сохранённая история'), findsOneWidget);
      final plot = find.byKey(const ValueKey('average-chart-plot'));
      final bounds = t.getRect(plot);
      await t.tapAt(Offset(bounds.left + 48, bounds.center.dy));
      await t.pumpAndSettle();
      expect(find.textContaining('Попытка 1:'), findsOneWidget);
      store.updateHistory([]);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('average-chart-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('average-chart-plot')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'English, unknown ranking, under-threshold history and long history scroll',
    (t) async {
      final store = ChartStore();
      addTearDown(store.dispose);
      store.history = [
        for (var i = 0; i < 200; i++)
          LocalAttempt(
            id: '$i',
            timeMs: 900,
            createdAt: DateTime.utc(2026).add(Duration(seconds: i)),
            shared: true,
          ),
      ];
      store.averageRanking = const AverageRanking(minDurationMs: 1000);
      await mount(t, store, lang: 'en');
      expect(find.textContaining('last 0'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('average-chart-partial')),
        findsOneWidget,
      );
      await t.drag(
        find.byKey(const ValueKey('average-chart-horizontal')),
        const Offset(-180, 0),
      );
      await t.pumpAndSettle();
      store.averageRanking = null;
      store.updateHistory([]);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('average-chart-empty')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
