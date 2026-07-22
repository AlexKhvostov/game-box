import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/scores_store.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_sheet.dart';
import 'leaderboard_panel.dart';

Future<void> showLeaderboardSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LeaderboardSheet(),
  );
}

class _LeaderboardSheet extends StatelessWidget {
  const _LeaderboardSheet();

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
          const Expanded(child: LeaderboardPanel()),
        ],
      ),
    );
  }
}
