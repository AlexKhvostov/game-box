import '../../ui/game_ui.dart';
import 'package:flutter/material.dart';
import 'leaderboard_panel.dart';
import 'ranking_frame.dart';
import 'package:provider/provider.dart';
import '../../data/scores_store.dart';

enum LeaderboardTab { record, average }

Future<void> showLeaderboardSheet(
  BuildContext context, {
  LeaderboardTab initialTab = LeaderboardTab.record,
  bool allTime = false,
}) => showModalBottomSheet<void>(
  sheetAnimationStyle: GameUi.windowAnimationStyle,
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => LeaderboardSheet(initialTab: initialTab, allTime: allTime),
);

Future<void> showMyAttemptsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: GameUi.windowAnimationStyle,
      builder: (c) => RankingFrame(
        title: Localizations.localeOf(c).languageCode == 'ru'
            ? 'Мои попытки'
            : 'My attempts',
        child: const RankingAttemptsPanel(),
      ),
    );

class LeaderboardSheet extends StatelessWidget {
  const LeaderboardSheet({
    super.key,
    this.initialTab = LeaderboardTab.record,
    this.allTime = false,
  });
  final LeaderboardTab initialTab;
  final bool allTime;
  @override
  Widget build(BuildContext context) => RankingFrame(
    onMyAttempts: context.watch<ScoresStore>().supportsAverage
        ? () => showMyAttemptsSheet(context)
        : null,
    child: LeaderboardPanel(
      initialAverage: initialTab == LeaderboardTab.average,
      initialPeriod: allTime ? 0 : 4,
    ),
  );
}
