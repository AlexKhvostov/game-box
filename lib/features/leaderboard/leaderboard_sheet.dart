import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/scores_store.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_sheet.dart';
import 'leaderboard_widgets.dart';

Future<void> showLeaderboardSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LeaderboardSheet(),
  );
}

class _LeaderboardSheet extends StatefulWidget {
  const _LeaderboardSheet();

  @override
  State<_LeaderboardSheet> createState() => _LeaderboardSheetState();
}

class _LeaderboardSheetState extends State<_LeaderboardSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this, initialIndex: 4);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _periodKey {
    switch (_tabs.index) {
      case 0:
        return 'day';
      case 1:
        return 'week';
      case 2:
        return 'month';
      case 3:
        return 'year';
      default:
        return 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final store = context.watch<ScoresStore>();

    return GameSheetChrome(
      heightFactor: 0.84,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
            child: Row(
              children: [
                Text(
                  l10n.leaderboardTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: store.online
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.white10,
                  ),
                  child: Text(
                    store.online ? l10n.online : l10n.offline,
                    style: TextStyle(
                      color: store.online
                          ? theme.colorScheme.primary
                          : Colors.white54,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.label,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: (_) => setState(() {}),
            tabs: [
              Tab(text: l10n.periodDay, height: 36),
              Tab(text: l10n.periodWeek, height: 36),
              Tab(text: l10n.periodMonth, height: 36),
              Tab(text: l10n.periodYear, height: 36),
              Tab(text: l10n.periodAll, height: 36),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(l10n.colPlace, style: theme.textTheme.bodySmall),
                ),
                Expanded(
                  child: Text(l10n.colPlayer, style: theme.textTheme.bodySmall),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    l10n.colCountry,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 58,
                  child: Text(
                    l10n.colTime,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    l10n.colDate,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) {
                final scores =
                    store.scoresForNamedPeriod(_periodKey).take(50).toList();
                if (scores.isEmpty) {
                  return Center(child: Text(l10n.leaderboardEmpty));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  itemCount: scores.length,
                  itemBuilder: (context, i) {
                    return LeaderboardRankRow(
                      place: i + 1,
                      entry: scores[i],
                      highlight: i < 3,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
