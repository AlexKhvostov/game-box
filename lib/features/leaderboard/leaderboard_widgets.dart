import 'package:flutter/material.dart';

import '../../domain/score_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/country_flag.dart';
import '../../ui/game_sheet.dart';

/// Строка рейтинга — общий вид для лидерборда и Share.
class LeaderboardRankRow extends StatelessWidget {
  const LeaderboardRankRow({
    super.key,
    required this.place,
    required this.entry,
    this.highlight = false,
    this.ghost = false,
    this.ghostLabel,
  });

  final int place;
  final ScoreEntry entry;
  final bool highlight;
  final bool ghost;
  final String? ghostLabel;

  String _dateLabel(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd.$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const youGold = Color(0xFFFFD54F);
    const youGoldSoft = Color(0xFFFFECB3);
    final accent = ghost
        ? youGold
        : highlight
            ? theme.colorScheme.primary
            : Colors.white70;
    final name = ghost ? (ghostLabel ?? entry.displayName) : entry.displayName;

    final row = Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '$place',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: accent,
            ),
          ),
        ),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontStyle: ghost ? FontStyle.italic : FontStyle.normal,
              color: ghost ? youGoldSoft : null,
              shadows: ghost
                  ? const [
                      Shadow(
                        color: Color(0x99FFD54F),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            countryFlagEmoji(entry.countryCode),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        SizedBox(
          width: 58,
          child: Text(
            '${entry.timeSec.toStringAsFixed(2)}s',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: accent,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: ghost
                  ? const [
                      Shadow(
                        color: Color(0x99FFD54F),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            ghost ? '—' : _dateLabel(entry.createdAt),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11,
              color: ghost ? youGold.withValues(alpha: 0.85) : Colors.white54,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );

    if (ghost) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              youGold.withValues(alpha: 0.22),
              const Color(0xFF2A2410),
              const Color(0xFF151C22),
            ],
          ),
          border: Border.all(color: youGold.withValues(alpha: 0.75), width: 1.3),
          boxShadow: [
            BoxShadow(
              color: youGold.withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 0.5,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: youGold.withValues(alpha: 0.18),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: row,
      );
    }

    return GamePanel(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      accent: highlight ? theme.colorScheme.primary : null,
      child: row,
    );
  }
}

/// Карточка мест по срезам (день / неделя / месяц / год / всё).
class PeriodRanksCard extends StatelessWidget {
  const PeriodRanksCard({
    super.key,
    required this.ranks,
  });

  final PeriodRanks ranks;

  @override
  Widget build(BuildContext context) {
    return PeriodRanksCompact(ranks: ranks);
  }
}

/// Компактные карточки мест: сверху период, снизу номер — в один ряд.
class PeriodRanksCompact extends StatelessWidget {
  const PeriodRanksCompact({
    super.key,
    required this.ranks,
  });

  final PeriodRanks ranks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = <(String, RankInfo)>[
      (l10n.periodAll, ranks.all),
      (l10n.periodYear, ranks.year),
      (l10n.periodMonth, ranks.month),
      (l10n.periodWeek, ranks.week),
      (l10n.periodDay, ranks.day),
    ];

    return GamePanel(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      accent: theme.colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.yourPlacesTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _PeriodPlaceCard(
                    label: items[i].$1,
                    place: items[i].$2.place,
                    highlight: items[i].$2.place <= 3,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodPlaceCard extends StatelessWidget {
  const _PeriodPlaceCard({
    required this.label,
    required this.place,
    required this.highlight,
  });

  final String label;
  final int place;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = highlight
        ? theme.colorScheme.primary
        : const Color(0xFFE8EEF4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: highlight
            ? theme.colorScheme.primary.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: highlight
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$place',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              height: 1.1,
              color: accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
