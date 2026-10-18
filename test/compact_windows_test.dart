import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/game/lives_sheet.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/features/leaderboard/leaderboard_panel.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'package:game_box/features/result/share_score_sheet.dart';
import 'package:game_box/features/result/share_social_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';

class _Scores extends ScoresStore {
  _Scores({super.account}) {
    online = true;
  }
  int refreshes = 0;
  bool populated = false;
  LocalAttempt? resultAttempt;
  @override
  LocalAttempt? get latestAttempt => resultAttempt ?? super.latestAttempt;
  void acknowledgeResult() {
    resultAttempt = resultAttempt?.copyWith(shared: true);
    notifyListeners();
  }

  @override
  List<ScoreEntry> scoresForNamedPeriod(String period) => [
    ScoreEntry(
      id: 'fixture1',
      uid: 'android:1',
      displayName: 'CompactPlayer',
      timeMs: 12345,
      createdAt: DateTime.now(),
      runDistance: 240,
      riskCount: 5,
      hadJump: true,
    ),
    ScoreEntry(
      id: 'fixture2',
      uid: 'android:2',
      displayName: 'Ловкий кубик',
      timeMs: 11070,
      createdAt: DateTime.now(),
      runDistance: 213,
      riskCount: 3,
      hadHelmet: true,
    ),
    ScoreEntry(
      id: 'fixture3',
      uid: 'android:3',
      displayName: 'AnotherPlayer',
      timeMs: 9012,
      createdAt: DateTime.now(),
      runDistance: 154,
      riskCount: 2,
    ),
  ];
  @override
  List<LocalAttempt> get myAttempts => [
    LocalAttempt(
      id: 'confirmed',
      displayName: 'CompactPlayer',
      timeMs: 12345,
      createdAt: DateTime.now(),
      shared: true,
      runDistance: 240,
      riskCount: 5,
      hadJump: true,
    ),
    LocalAttempt(
      id: 'queued',
      timeMs: 9100,
      createdAt: DateTime.now(),
      runDistance: 134,
      riskCount: 3,
    ),
    LocalAttempt(
      id: 'practice',
      timeMs: 4070,
      createdAt: DateTime.now(),
      runDistance: 78,
      riskCount: 1,
    ),
  ];
  @override
  bool isAttemptPending(String id) => id == 'queued';
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {
    refreshes++;
  }

  @override
  RankInfo rankFor(int timeMs, {String period = 'all'}) =>
      RankInfo(place: 1, percentile: 95, totalCount: populated ? 100 : 0);
  void updateRank() {
    populated = true;
    notifyListeners();
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['UI_EVIDENCE_DIR'];
  if (directory == null) return;
  final imageElements = find.byType(Image).evaluate().toList();
  await tester.runAsync(() async {
    for (final element in imageElements) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('evidence-screen')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final font = Platform.environment['UI_EVIDENCE_FONT'];
    if (font != null) {
      final loader = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.sublistView(await File(font).readAsBytes())),
        );
      await loader.load();
      final testFont = FontLoader('Ahem')
        ..addFont(
          Future.value(ByteData.sublistView(await File(font).readAsBytes())),
        );
      await testFont.load();
      final icons = Platform.environment['UI_EVIDENCE_ICONS'];
      if (icons != null) {
        final iconFont = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(ByteData.sublistView(await File(icons).readAsBytes())),
          );
        await iconFont.load();
      }
    }
  });
  for (final language in ['ru', 'en']) {
    for (final viewport in [
      const Size(320, 480),
      const Size(320, 560),
      const Size(360, 740),
      const Size(430, 932),
    ]) {
      final width = viewport.width;
      final height = viewport.height;
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('compact windows $language ${width}x$height text $scale', (
          tester,
        ) async {
          SharedPreferences.setMockInitialValues({});
          final previousErrorHandler = FlutterError.onError;
          String? layoutDetails;
          FlutterError.onError = (details) {
            layoutDetails = details.toString();
            previousErrorHandler?.call(details);
          };
          addTearDown(() => FlutterError.onError = previousErrorHandler);
          final economy = EconomyStore();
          await economy.load();
          final prefs = PlayerPreferences();
          await prefs.load();
          final account = MobileAccount()
            ..id = 'android:1'
            ..nickname = 'CompactPlayer'
            ..googleLinked = true;
          final scores = _Scores(account: account);
          final audience = AudiencePolicy();
          await audience.load();
          await audience.select(AgeBand.age21plus);
          await tester.binding.setSurfaceSize(viewport);
          addTearDown(() {
            tester.view.resetViewInsets();
            return tester.binding.setSurfaceSize(null);
          });
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: economy),
                ChangeNotifierProvider.value(value: prefs),
                ChangeNotifierProvider.value(value: account),
                ChangeNotifierProvider.value(value: audience),
                ChangeNotifierProvider<ScoresStore>.value(value: scores),
                Provider.value(value: GameplayConfig()),
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
                  child: RepaintBoundary(
                    key: const ValueKey('evidence-screen'),
                    child: child!,
                  ),
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Wrap(
                      children: [
                        TextButton(
                          onPressed: () => showLeaderboardSheet(context),
                          child: const Text('rating'),
                        ),
                        TextButton(
                          onPressed: () => showProfileSheet(context),
                          child: const Text('profile'),
                        ),
                        TextButton(
                          onPressed: () => showCrystalsSheet(context),
                          child: const Text('shop'),
                        ),
                        TextButton(
                          onPressed: () => showLivesSheet(context),
                          child: const Text('lives'),
                        ),
                        TextButton(
                          onPressed: () =>
                              showShareScoreSheet(context, timeMs: 12345),
                          child: const Text('save'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          final suffix = '$language-${width.toInt()}x${height.toInt()}-$scale';
          await tester.tap(find.text('rating'));
          await tester.pumpAndSettle();
          final firstPeriod = tester.getRect(
            find.byKey(const ValueKey('leaderboard-filter-0')),
          );
          for (var i = 1; i < 5; i++) {
            final period = tester.getRect(
              find.byKey(ValueKey('leaderboard-filter-$i')),
            );
            // Long period names can wrap at larger system text sizes. Their
            // touch targets stay in one centered row instead of truncating.
            expect(period.center.dy, firstPeriod.center.dy);
            expect(period.width, greaterThanOrEqualTo(48));
          }
          expect(
            tester
                .getRect(find.byKey(const ValueKey('leaderboard-filter-5')))
                .bottom,
            lessThanOrEqualTo(
              [
                for (var i = 0; i < 5; i++)
                  tester
                      .getRect(find.byKey(ValueKey('leaderboard-filter-$i')))
                      .top,
              ].reduce((a, b) => a < b ? a : b),
            ),
          );
          for (var i = 0; i < 6; i++) {
            final chip = find.byKey(ValueKey('leaderboard-filter-$i'));
            final rect = tester.getRect(chip);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
            expect(rect.bottom, lessThan(height));
            expect(rect.height, greaterThanOrEqualTo(48));
            await tester.tap(chip);
            await tester.pumpAndSettle();
            expect(
              tester
                  .state<LeaderboardPanelState>(find.byType(LeaderboardPanel))
                  .filter,
              i,
            );
          }
          expect(tester.takeException(), isNull, reason: layoutDetails);
          await _capture(tester, 'rating-$suffix');
          tester.state<NavigatorState>(find.byType(Navigator)).pop();
          await tester.pumpAndSettle();
          await tester.tap(find.text('profile'));
          await tester.pumpAndSettle();
          expect(
            tester
                .getRect(find.byKey(const ValueKey('profile-nickname-input')))
                .bottom,
            lessThan(height),
          );
          expect(tester.takeException(), isNull);
          await _capture(tester, 'profile-$suffix');
          final profileScroll = find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('profile-google-private')),
            100,
            scrollable: profileScroll,
          );
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('profile-google-privacy-group')),
              matching: find.byKey(const ValueKey('profile-google-private')),
            ),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('profile-age-setting')),
            100,
            scrollable: profileScroll,
          );
          await tester.pumpAndSettle();
          final agePanel = find.byKey(const ValueKey('profile-age-panel'));
          final ageRect = tester.getRect(
            find.byKey(const ValueKey('profile-age-setting')),
          );
          expect(
            find.descendant(
              of: agePanel,
              matching: find.byKey(const ValueKey('profile-age-setting')),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('profile-google-setting')),
              matching: find.byKey(const ValueKey('profile-age-setting')),
            ),
            findsNothing,
          );
          expect(tester.getRect(agePanel).contains(ageRect.center), isTrue);
          final ageBottomInList =
              ageRect.bottom +
              tester.state<ScrollableState>(profileScroll).position.pixels;
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('profile-game-settings')),
            100,
            scrollable: profileScroll,
          );
          await tester.pumpAndSettle();
          final settingsRect = tester.getRect(
            find.byKey(const ValueKey('profile-game-settings')),
          );
          expect(
            settingsRect.top +
                tester.state<ScrollableState>(profileScroll).position.pixels,
            greaterThan(ageBottomInList),
          );
          // Secondary links remain accessible in the expandable section.
          await tester.scrollUntilVisible(
            find.text(
              language == 'ru'
                  ? 'Помощь и конфиденциальность'
                  : 'Help and privacy',
            ),
            100,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(
              language == 'ru'
                  ? 'Помощь и конфиденциальность'
                  : 'Help and privacy',
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('profile-deletion')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('profile-deletion')).hitTestable(),
            findsOneWidget,
          );
          tester.state<NavigatorState>(find.byType(Navigator)).pop();
          await tester.pumpAndSettle();
          // Help is a child dialog; close the account as well.
          tester.state<NavigatorState>(find.byType(Navigator)).pop();
          await tester.pumpAndSettle();
          await tester.tap(find.text('shop'));
          await tester.pumpAndSettle();
          await _capture(tester, 'daily-$suffix');
          for (final index in [1, 2, 3]) {
            await tester.tap(find.byKey(ValueKey('shop-tab-$index')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: layoutDetails);
            await _capture(
              tester,
              '${['daily', 'shop', 'rent', 'earn'][index]}-$suffix',
            );
          }
          tester.state<NavigatorState>(find.byType(Navigator)).pop();
          await tester.pumpAndSettle();
          await tester.tap(find.text('lives'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _capture(tester, 'lives-$suffix');
          tester.state<NavigatorState>(find.byType(Navigator)).pop();
          await tester.pumpAndSettle();
          await tester.tap(find.text('save'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _capture(tester, 'save-$suffix');
          tester.view.viewInsets = FakeViewPadding(
            bottom: 260 * tester.view.devicePixelRatio,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();

          tester.state<NavigatorState>(find.byType(Navigator)).pop();
          await tester.pumpAndSettle();
          showShareSocialSheet(
            tester.element(find.byType(Scaffold)),
            timeMs: 12345,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _capture(tester, 'social-$suffix');

          await tester.pumpWidget(const SizedBox());
          economy.dispose();
          prefs.dispose();
          account.dispose();
          scores.dispose();
        });
      }
    }
    testWidgets(
      'result entry defers refresh and rank does not move card ($language)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final economy = EconomyStore();
        await economy.load();
        final scores = _Scores();
        scores.resultAttempt = LocalAttempt(
          id: 'queued',
          timeMs: 12345,
          createdAt: DateTime.now(),
        );
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
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: const ValueKey('evidence-screen'),
                child: Scaffold(
                  body: ResultOverlay(
                    timeMs: 12345,
                    runDistance: 0,
                    riskCount: 0,
                    onOk: () {},
                    onShare: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(scores.refreshes, 0);
        await tester.pump(const Duration(milliseconds: 180));
        expect(scores.refreshes, 1);
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('result-card'));
        final before = tester.getRect(card);
        final content = find.byKey(const ValueKey('result-content'));
        final contentBefore = tester.getRect(content);
        scores.updateRank();
        scores.acknowledgeResult();
        await tester.pumpAndSettle();
        expect(tester.getRect(card), before);
        expect(tester.getRect(content), contentBefore);
        expect(before.top, greaterThanOrEqualTo(0));
        expect(before.bottom, lessThanOrEqualTo(560));
        final replay = find.byKey(const ValueKey('result-replay'));
        // Larger system text may require the card's internal scroll. Making
        // the last action visible must not move or resize the dialog itself.
        await tester.ensureVisible(replay);
        await tester.pumpAndSettle();
        expect(tester.getRect(card), before);
        // A Rect's bottom-top can differ from the RenderBox height by floating
        // point rounding. Preserve geometry to a millionth of a logical pixel.
        expect(
          tester.getSize(content).width,
          closeTo(contentBefore.width, 1e-6),
        );
        expect(
          tester.getSize(content).height,
          closeTo(contentBefore.height, 1e-6),
        );
        expect(replay.hitTestable(), findsOneWidget);
        expect(tester.getSize(replay).height, greaterThanOrEqualTo(56));
        // The body scrolls independently of the pinned actions. Reveal the
        // status before comparing its screen position with the replay button.
        await tester.ensureVisible(
          find.byKey(const ValueKey('result-save-status')),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(card), before);
        expect(
          tester.getRect(replay).top,
          greaterThan(
            tester
                .getRect(find.byKey(const ValueKey('result-save-status')))
                .bottom,
          ),
        );
        expect(tester.takeException(), isNull);
        await _capture(tester, 'result-$language');
        await tester.pumpWidget(const SizedBox());
        economy.dispose();
        scores.dispose();
      },
    );
  }
}
