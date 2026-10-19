// Isolated UI acceptance: synthetic confirmed history, no account/API/wallet.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/average_chart.dart';
import 'package:game_box/domain/average_ranking.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/leaderboard/average_ranking_panel.dart';
import 'package:game_box/features/leaderboard/average_chart_dialog.dart';
import 'package:game_box/l10n/app_localizations.dart';

final navigator = GlobalKey<NavigatorState>();
final app = GlobalKey<ProbeState>();
final capture = GlobalKey();
final errors = <String>[];
late ChartProbeStore store;

class ChartProbeStore extends ScoresStore {
  ChartProbeStore() {
    setFixture('filled');
  }
  List<LocalAttempt> history = [];
  @override
  List<LocalAttempt> get myAttempts => List.of(history);
  @override
  Future<void> load() async {}
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
  void setFixture(String mode) {
    final length = mode == 'empty'
        ? 0
        : mode == 'long'
        ? 200
        : 100;
    history = [
      for (var i = 0; i < length; i++)
        LocalAttempt(
          id: 'qa-$i',
          timeMs: i % 13 == 3
              ? 200 + (i % 8) * 100
              : 1000 + ((i * 7307 + 1931) % 19001),
          createdAt: DateTime.utc(2026, 10, 19).add(Duration(seconds: i)),
          shared: true,
        ),
    ];
    final rules = AverageRanking(
      algorithm: AverageRanking.quadraticAlgorithm,
      minDurationMs: mode == 'threshold' ? 1000 : 0,
    );
    final data = AverageChartData.fromAttempts(
      attempts: history,
      ranking: rules,
    );
    final own = AverageRankEntry(
      playerName: 'QA график',
      averageMs: data.averageMs,
      totalAttempts: length,
      usedCount: data.currentWindowCount,
      eligibleCount: history
          .where((a) => a.timeMs > rules.minDurationMs)
          .length,
      place: 1,
    );
    averageRanking = AverageRanking(
      algorithm: rules.algorithm,
      minDurationMs: rules.minDurationMs,
      mine: own,
      rows: [own],
    );
    online = mode != 'offline';
    notifyListeners();
  }
}

class ProbeApp extends StatefulWidget {
  const ProbeApp({super.key});
  @override
  State<ProbeApp> createState() => ProbeState();
}

class ProbeState extends State<ProbeApp> {
  double scale = 1;
  String language = 'ru';
  void setDisplay(double value, String lang) => setState(() {
    scale = value;
    language = lang;
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    theme: buildGameTheme(),
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => RepaintBoundary(
      key: capture,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
    home: Scaffold(
      body: SafeArea(child: AverageRankingPanel(store: store)),
    ),
  );
}

Map<String, dynamic> state() {
  final rectangles = <String, dynamic>{};
  void walk(Element e) {
    if (e.widget.key case ValueKey<String>(:final value)) {
      if (value.startsWith('average-chart-') ||
          value == 'average-ranking-info') {
        final render = e.findRenderObject();
        if (render is RenderBox && render.attached && render.hasSize) {
          final offset = render.localToGlobal(Offset.zero), size = render.size;
          rectangles[value] = {
            'left': offset.dx,
            'top': offset.dy,
            'width': size.width,
            'height': size.height,
          };
        }
      }
    }
    e.visitChildElements(walk);
  }

  final context = capture.currentContext;
  if (context is Element) walk(context);
  final data = AverageChartData.fromAttempts(
    attempts: store.myAttempts,
    ranking: store.averageRanking!,
  );
  return {
    'qaBuild': 197,
    'allNetworkIntercepted': true,
    'errors': errors,
    'rectangles': rectangles,
    'devicePixelRatio': View.of(context!).devicePixelRatio,
    'points': data.points.length,
    'currentWindow': data.currentWindowCount,
    'historyComplete': data.historyComplete,
    'averageMs': data.averageMs,
    'activeBars': data.points.where((p) => p.inCurrentWindow).length,
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    errors.add('$error');
    return true;
  };
  store = ChartProbeStore();
  runApp(ProbeApp(key: app));
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8897);
  await for (final request in server) {
    try {
      if (request.uri.path == '/show') {
        navigator.currentState!.popUntil((r) => r.isFirst);
        store.setFixture(request.uri.queryParameters['mode'] ?? 'filled');
        app.currentState!.setDisplay(
          double.tryParse(request.uri.queryParameters['scale'] ?? '') ?? 1,
          request.uri.queryParameters['lang'] ?? 'ru',
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));
        final chartContext = navigator.currentState?.overlay?.context;
        if (request.uri.queryParameters['screen'] == 'chart' &&
            chartContext != null &&
            chartContext.mounted) {
          unawaited(showAverageChartDialog(chartContext, store));
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(state()));
    } catch (error, stack) {
      errors.add('$error');
      request.response.statusCode = 500;
      request.response.write(
        jsonEncode({'error': '$error', 'stack': '$stack'}),
      );
    }
    await request.response.close();
  }
}
