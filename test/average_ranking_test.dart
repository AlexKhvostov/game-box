import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/average_ranking.dart';
import 'package:game_box/features/leaderboard/leaderboard_panel.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/app/theme.dart';
import 'mobile_account_test.dart' show MemoryVault;

const owner = 'supabase:12345678-1234-4234-8234-123456789abc';
Map<String, dynamic> payload() => {
  'rules': {
    'windowSize': 50,
    'previousWeightPercent': 92,
    'minAttempts': 20,
    'minDurationMs': 1000,
  },
  'rows': [
    {
      'userId': owner,
      'playerName': 'Проверенный игрок',
      'averageMs': 6723.490968743577,
      'usedCount': 50,
      'eligibleCount': 60,
      'totalAttempts': 112,
      'place': 1,
    },
  ],
  'mine': {
    'averageMs': 6723.490968743577,
    'usedCount': 50,
    'eligibleCount': 60,
    'totalAttempts': 112,
    'place': 1,
  },
};

class AverageAccount extends MobileAccount {
  AverageAccount()
    : super(vault: MemoryVault(), storagePrefix: 'supabase_android_v1_') {
    id = owner;
  }
  bool fail = false;
  @override
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> body, {
    bool guest = false,
  }) async {
    if (fail) throw const MobileApiError('offline');
    return {
      'periods': {
        for (final p in ['all', 'day', 'week', 'month', 'year']) p: [],
      },
      'average': payload(),
    };
  }
}

class AverageFixture extends ScoresStore {
  AverageFixture(MobileAccount owner) : super(account: owner) {
    online = true;
    averageRanking = AverageRanking.fromJson(payload());
  }
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
  @override
  Future<void> load() async {}
}

class CachedBoardAccount extends AverageAccount {
  @override
  Future<Map<String,dynamic>> request(Map<String,dynamic> body,{bool guest=false}) async {
    final result=await super.request(body,guest:guest);
    result['periods']={for(final period in ['all','day','week','month','year'])period:[{
      'id':'own-$period','userId':owner,'playerName':'Проверенный игрок',
      'timeMs':3001,'createdAt':1,'place':520,
    }]};
    return result;
  }
}

Future<void> captureAverage(WidgetTester t, String name) async {
  final output = Platform.environment['AVERAGE_EVIDENCE_DIR'];
  if (output == null) return;
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('average-overlay-capture')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = Platform.environment['RANKING_FONT_DIR'];
    if (fonts == null) return;
    final loader = FontLoader('Roboto');
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$fonts/$name').readAsBytes()),
        ),
      );
    }
    await loader.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('record periods retain actual own rank offline, including late owner restore, never another owner',()async {
    final firstAccount=CachedBoardAccount(),first=ScoresStore(account:CachedBoardAccount());
    await first.load();
    expect(first.scoresForNamedPeriod('day').single.place,520);
    final account=CachedBoardAccount()..id=null;
    final restored=ScoresStore(account:account);
    await restored.loadLocal();
    expect(restored.scoresForNamedPeriod('day'),isEmpty);
    account.id=owner;account.notifyListeners();
    expect(restored.scoresForNamedPeriod('day').single.place,520);
    expect(restored.averageRanking!.mine.totalAttempts,112);
    account.id='supabase:22345678-1234-4234-8234-123456789abc';account.notifyListeners();
    expect(restored.scoresForNamedPeriod('day'),isEmpty);
    expect(restored.scores,isEmpty);expect(restored.averageRanking,null);
    first.dispose();first.account!.dispose();firstAccount.dispose();restored.dispose();account.dispose();
  });
  test(
    'server average stays precise, caches confirmed data for offline restart, clears on owner switch',
    () async {
      final account = AverageAccount();
      final store = ScoresStore(account: account);
      await store.load();
      expect(store.supportsAverage, true);
      expect(
        store.averageRanking!.mine.averageMs,
        closeTo(6723.490968743577, 1e-9),
      );
      expect(store.averageRanking!.rows.single.place, 1);
      account.fail = true;
      final restored = ScoresStore(account: account);
      await restored.load();
      expect(restored.online, false);
      expect(restored.averageRanking!.mine.eligibleCount, 60);
      account.id = 'supabase:22345678-1234-4234-8234-123456789abc';
      account.notifyListeners();
      expect(store.averageRanking, null);
      expect(restored.averageRanking, null);
      store.dispose();
      restored.dispose();
      account.dispose();
    },
  );
  test('missing old-server aggregate does not invent a ranking', () async {
    final account = AverageAccount();
    final store = ScoresStore(account: account);
    await store.loadLocal();
    expect(store.averageRanking, null);
    store.dispose();
    account.dispose();
  });
  test(
    'offline startup restores average when secure owner arrives after local load',
    () async {
      final firstAccount = AverageAccount();
      final first = ScoresStore(account: firstAccount);
      await first.load();
      final account = AverageAccount()..id = null;
      final restarted = ScoresStore(account: account);
      await restarted.loadLocal();
      expect(restarted.averageRanking, null);
      account.id = owner;
      account.notifyListeners();
      expect(
        restarted.averageRanking!.mine.averageMs,
        closeTo(6723.490968743577, 1e-9),
      );
      restarted.dispose();
      first.dispose();
      account.dispose();
      firstAccount.dispose();
    },
  );
  for (final size in [const Size(360, 720), const Size(320, 480)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'average tab $size scale$scale handles own/provisional/offline/empty states',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(() => t.view.resetPhysicalSize());
          addTearDown(() => t.view.resetDevicePixelRatio());
          final account = AverageAccount(),
              store = AverageFixture(AverageAccount());
          await t.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<ScoresStore>.value(value: store),
                ChangeNotifierProvider<MobileAccount>.value(
                  value: store.account!,
                ),
              ],
              child: MaterialApp(
                theme: buildGameTheme(),
                locale: const Locale('ru'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (c, child) => RepaintBoundary(
                  key: const ValueKey('average-overlay-capture'),
                  child: MediaQuery(
                    data: MediaQuery.of(
                      c,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                ),
                home: Scaffold(
                  body: RepaintBoundary(
                    key: const ValueKey('average-capture'),
                    child: const LeaderboardSheet(),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(find.text('Рекорд'), findsOneWidget);
          expect(find.text('Средние'), findsOneWidget);
          expect(find.byKey(const ValueKey('ranking-legend')), findsOneWidget);
          if (scale == 1) {
            expect(
              t.getSize(find.byKey(const ValueKey('ranking-legend'))).height,
              lessThan(50),
            );
          }
          await t.tap(find.byKey(const ValueKey('leaderboard-filter-2')));
          await t.pumpAndSettle();
          await captureAverage(t, 'record-${size.width.toInt()}-scale$scale');
          await t.tap(find.byKey(const ValueKey('leaderboard-filter-6')));
          await t.pumpAndSettle();
          expect(find.text('Средние'), findsOneWidget);
          expect(find.byKey(const ValueKey('ranking-legend')), findsNothing);
          expect(
            find.byKey(const ValueKey('leaderboard-filter-0')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('leaderboard-filter-5')),
            findsNothing,
          );
          expect(find.textContaining('%'), findsNothing);
          expect(find.text('Рейтинг по среднему времени'), findsOneWidget);
          await t.tap(find.byKey(const ValueKey('average-ranking-info')));
          await t.pumpAndSettle();
          expect(
            find.textContaining('Свежие результаты влияют сильнее'),
            findsOneWidget,
          );
          final tipBounds = t.getRect(
            scale > 1.5
                ? find.byKey(const ValueKey('average-info-scroll'))
                : find.textContaining('Свежие результаты влияют сильнее'),
          );
          expect(tipBounds.left, greaterThanOrEqualTo(0));
          expect(tipBounds.right, lessThanOrEqualTo(size.width));
          expect(tipBounds.top, greaterThanOrEqualTo(0));
          expect(tipBounds.bottom, lessThanOrEqualTo(size.height));
          expect(find.textContaining('50 попыток дольше 1 с.'), findsOneWidget);
          expect(find.textContaining('92%'), findsNothing);
          expect(t.takeException(), null);
          await captureAverage(t, 'info-${size.width.toInt()}-scale$scale');
          if (scale > 1.5) {
            Navigator.of(
              t.element(find.byKey(const ValueKey('average-info-scroll'))),
            ).pop();
            await t.pumpAndSettle();
          }
          await t.tap(find.byKey(const ValueKey('leaderboard-tab-record')));
          await t.pumpAndSettle();
          expect(
            t
                .state<LeaderboardPanelState>(find.byType(LeaderboardPanel))
                .filter,
            2,
          );
          expect(find.byKey(const ValueKey('ranking-legend')), findsOneWidget);
          await t.tap(find.byKey(const ValueKey('ranking-my-attempts')));
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('attempts-average-card')),
            findsOneWidget,
          );
          Navigator.of(t.element(find.byType(RankingAttemptsPanel))).pop();
          await t.pumpAndSettle();
          await t.tap(find.byKey(const ValueKey('leaderboard-filter-6')));
          await t.pumpAndSettle();
          expect(find.textContaining('Ваше среднее: 6.723'), findsOneWidget);
          await t.scrollUntilVisible(
            find.text('Проверенный игрок'),
            100,
            scrollable: find.byType(Scrollable).last,
          );
          expect(find.text('Проверенный игрок'), findsOneWidget);
          expect(t.takeException(), null);
          final evidence = Platform.environment['AVERAGE_EVIDENCE_DIR'];
          if (evidence != null) {
            await t.runAsync(() async {
              final boundary = t.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('average-capture')),
              );
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(evidence).create(recursive: true);
              await File(
                '$evidence/average-${size.width.toInt()}-scale$scale.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          store.online = false;
          store.averageRanking = const AverageRanking(
            minAttempts: 20,
            minDurationMs: 1000,
            mine: AverageRankEntry(
              averageMs: 5000,
              usedCount: 19,
              eligibleCount: 19,
            ),
          );
          store.notifyListeners();
          await t.pumpAndSettle();
          expect(find.textContaining('19/20'), findsOneWidget);
          await t.drag(find.byType(Scrollable).last, const Offset(0, 600));
          await t.pumpAndSettle();
          expect(find.textContaining('Без сети'), findsOneWidget);
          expect(t.takeException(), null);
          store.averageRanking = null;
          store.notifyListeners();
          await t.pumpAndSettle();
          expect(find.text('Повторить'), findsOneWidget);
          expect(t.takeException(), null);
          await t.pumpWidget(const SizedBox());
          store.account!.dispose();
          store.dispose();
          account.dispose();
        },
      );
    }
  }
}
