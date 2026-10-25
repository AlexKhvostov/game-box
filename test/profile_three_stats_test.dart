import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/average_ranking.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/features/leaderboard/leaderboard_panel.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'friend_invites_profile_test.dart' as fixture;

class ProfileScores extends ScoresStore {
  ProfileScores(MobileAccount account) : super(account: account);
  int refreshes = 0;
  @override
  bool get supportsAverage => true;
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {
    refreshes++;
  }

  void emit({double? average = 3737, int? attempts = 31, String? owner}) {
    averageRanking = AverageRanking(
      mine: AverageRankEntry(
        userId: owner ?? account!.id,
        averageMs: average,
        totalAttempts: attempts,
        usedCount: 28,
        eligibleCount: 28,
        place: 1,
      ),
    );
    notifyListeners();
  }
}

Finder key(String name) => find.byKey(ValueKey(name));
Future<void> capture(WidgetTester t, String name) async {
  final dir = Platform.environment['PROFILE_STATS_EVIDENCE_DIR'];
  if (dir == null) return;
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(fixture.boundary),
    );
    final image = await boundary.toImage(pixelRatio: 2),
        bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final dir = Platform.environment['RANKING_FONT_DIR'];
    if (dir == null) return;
    final loader = FontLoader('Roboto');
    for (final file in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$dir/$file').readAsBytes()),
        ),
      );
    }
    await loader.load();
  });
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final lang in ['ru', 'en']) {
        testWidgets(
          'profile three statistics one row $width scale$scale $lang',
          (t) async {
            final account = fixture.BindAccount(),
                invites = fixture.ProfileInvites(account)..emit();
            final scores = ProfileScores(account)..emit();
            addTearDown(scores.dispose);
            await fixture.mount(
              t,
              invites,
              scores: scores,
              size: Size(width, 740),
              scale: scale,
              lang: lang,
              seekSection: false,
            );
            final economy = t
                .element(find.byType(ProfileScreen))
                .read<EconomyStore>();
            economy.bestTimeMs = 13418;
            economy.dailyStreak = 7;
            economy.notifyListeners();
            await t.pumpAndSettle();
            expect(scores.refreshes, 1);
            expect(find.text(lang == 'ru' ? 'Серия' : 'Streak'), findsNothing);
            expect(
              find.descendant(
                of: key('profile-stat-record'),
                matching: find.text(lang == 'ru' ? '13.418 с' : '13.418 s'),
              ),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: key('profile-stat-average'),
                matching: find.text(lang == 'ru' ? '3.737 с' : '3.737 s'),
              ),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: key('profile-stat-attempts'),
                matching: find.text('31'),
              ),
              findsOneWidget,
            );
            final record = t.getRect(key('profile-stat-record')),
                average = t.getRect(key('profile-stat-average')),
                attempts = t.getRect(key('profile-stat-attempts'));
            expect(average.left, greaterThan(record.right));
            expect(attempts.left, greaterThan(average.right));
            expect(average.center.dy, closeTo(record.center.dy, .01));
            expect(attempts.center.dy, closeTo(record.center.dy, .01));
            if (scale == 1) {
              expect(t.getSize(key('profile-stats')).height, lessThan(60));
            }
            expect(t.takeException(), null);
            await capture(t, 'account-$width-$scale-$lang');
          },
        );
      }
    }
  }
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'profile links open correct destination and return, width$width scale$scale',
        (t) async {
          final account = fixture.BindAccount(),
              invites = fixture.ProfileInvites(account)..emit();
          final scores = ProfileScores(account)..emit();
          addTearDown(scores.dispose);
          await fixture.mount(
            t,
            invites,
            scores: scores,
            size: Size(width, 740),
            scale: scale,
            seekSection: false,
          );
          await t.pumpAndSettle();
          for (final destination in ['record', 'average', 'attempts']) {
            final action = key('profile-stat-$destination-action');
            expect(t.getSize(action).height, greaterThanOrEqualTo(48));
            await t.tap(action);
            await t.pumpAndSettle();
            if (destination == 'attempts') {
              expect(find.byType(RankingAttemptsPanel), findsOneWidget);
              expect(find.byType(LeaderboardPanel), findsNothing);
              expect(key('my-attempts-mean'), findsOneWidget);
            } else {
              final panel = t.state<LeaderboardPanelState>(
                find.byType(LeaderboardPanel),
              );
              expect(panel.filter, destination == 'record' ? 0 : 6);
              expect(find.byType(RankingAttemptsPanel), findsNothing);
            }
            if (destination == 'average') {
              await t.tap(key('leaderboard-tab-record'));
              await t.pumpAndSettle();
              expect(
                t
                    .state<LeaderboardPanelState>(find.byType(LeaderboardPanel))
                    .filter,
                0,
              );
            }
            if (destination == 'record') {
              await t.binding.handlePopRoute();
            } else {
              await t.tap(
                key(
                  destination == 'attempts'
                      ? 'my-attempts-close'
                      : 'ranking-close',
                ),
              );
            }
            await t.pumpAndSettle();
            expect(find.byType(LeaderboardPanel), findsNothing);
            expect(find.byType(RankingAttemptsPanel), findsNothing);
            expect(
              key('profile-stat-record-action').hitTestable(),
              findsOneWidget,
            );
          }
          expect(t.takeException(), null);
        },
      );
    }
  }
  testWidgets('ordinary ranking entry still starts on day', (t) async {
    final account = fixture.BindAccount(),
        invites = fixture.ProfileInvites(account)..emit();
    final scores = ProfileScores(account)..emit();
    addTearDown(scores.dispose);
    await fixture.mount(t, invites, scores: scores, seekSection: false);
    await t.pumpAndSettle();
    showLeaderboardSheet(t.element(find.byType(ProfileScreen)));
    await t.pumpAndSettle();
    expect(
      t.state<LeaderboardPanelState>(find.byType(LeaderboardPanel)).filter,
      4,
    );
    expect(t.takeException(), null);
  });
  testWidgets('all three profile links activate with keyboard Enter', (
    t,
  ) async {
    final account = fixture.BindAccount(),
        invites = fixture.ProfileInvites(account)..emit();
    final scores = ProfileScores(account)..emit();
    addTearDown(scores.dispose);
    await fixture.mount(t, invites, scores: scores, seekSection: false);
    await t.pumpAndSettle();
    for (final destination in ['record', 'average', 'attempts']) {
      final mouse = find
          .descendant(
            of: key('profile-stat-$destination-action'),
            matching: find.byType(MouseRegion),
          )
          .first;
      Focus.of(t.element(mouse)).requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      if (destination == 'attempts') {
        expect(find.byType(RankingAttemptsPanel), findsOneWidget);
      } else {
        expect(
          t.state<LeaderboardPanelState>(find.byType(LeaderboardPanel)).filter,
          destination == 'record' ? 0 : 6,
        );
      }
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(key('profile-stat-record-action').hitTestable(), findsOneWidget);
    }
    expect(t.takeException(), null);
  });
  testWidgets(
    'profile uses confirmed overall total, handles unknown/zero/offline and excludes another owner',
    (t) async {
      final account = fixture.BindAccount(),
          invites = fixture.ProfileInvites(account)..emit();
      final scores = ProfileScores(account);
      addTearDown(scores.dispose);
      await fixture.mount(t, invites, scores: scores, seekSection: false);
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: key('profile-stat-average'),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('profile-stat-attempts'),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      scores.emit(average: null, attempts: 0);
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: key('profile-stat-attempts'),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      scores.online = false;
      scores.emit(attempts: 123);
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: key('profile-stat-attempts'),
          matching: find.text('123'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('28'),
        findsNothing,
      ); // never use EMA sample count as total
      scores.emit(owner: 'another-owner');
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: key('profile-stat-average'),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('profile-stat-attempts'),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      scores.emit();
      account.id = null;
      account.notifyListeners();
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: key('profile-stat-attempts'),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), null);
    },
  );
}
