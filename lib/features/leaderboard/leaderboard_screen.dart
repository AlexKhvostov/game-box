import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/scores_store.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScoresStore>();
    final scores = store.scores;
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text('Рейтинг', style: theme.textTheme.titleLarge),
                const Spacer(),
                Text(
                  store.online ? 'онлайн' : 'офлайн',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: store.online
                        ? theme.colorScheme.primary
                        : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              '${scores.length} записей · по времени',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: scores.isEmpty
                ? Center(
                    child: Text(
                      'Пока нет сохранённых результатов',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: store.load,
                    child: ListView.builder(
                      itemCount: scores.length,
                      itemExtent: 40,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemBuilder: (context, index) {
                        final s = scores[index];
                        final top = index < 3;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: index.isOdd
                                ? theme.colorScheme.surface
                                    .withValues(alpha: 0.35)
                                : null,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withValues(alpha: 0.04),
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                      color: top
                                          ? theme.colorScheme.primary
                                          : Colors.white54,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    s.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                          top ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${s.timeSec.toStringAsFixed(2)}с',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    color: top
                                        ? theme.colorScheme.primary
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
