import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/scores_store.dart';
import '../../domain/score_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_sheet.dart';
import 'leaderboard_widgets.dart';

/// Общий фильтр и список лидеров — один UI для Leaderboard и Share.
/// Порядок: All → Year → Month → Week → Day | Mine справа.
class LeaderboardPanel extends StatefulWidget {
  const LeaderboardPanel({
    super.key,
    this.ghostTimeMs,
    this.ghostCountryCode = '--',
    this.listPadding = const EdgeInsets.fromLTRB(12, 8, 12, 20),
  });

  /// Если задано — в рейтинге периодов показывается строка «Вы».
  final int? ghostTimeMs;
  final String ghostCountryCode;
  final EdgeInsets listPadding;

  @override
  State<LeaderboardPanel> createState() => LeaderboardPanelState();
}

class LeaderboardPanelState extends State<LeaderboardPanel> {
  /// 0 All · 1 Year · 2 Month · 3 Week · 4 Day · 5 Mine
  /// По умолчанию — дневной рейтинг.
  int filter = 4;

  bool get isMine => filter == 5;

  String get periodKey {
    switch (filter) {
      case 1:
        return 'year';
      case 2:
        return 'month';
      case 3:
        return 'week';
      case 4:
        return 'day';
      default:
        return 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final store = context.watch<ScoresStore>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      LeaderboardFilterChip(
                        label: l10n.periodAll,
                        selected: filter == 0,
                        compact: true,
                        onTap: () => setState(() => filter = 0),
                      ),
                      LeaderboardFilterChip(
                        label: l10n.periodYear,
                        selected: filter == 1,
                        compact: true,
                        onTap: () => setState(() => filter = 1),
                      ),
                      LeaderboardFilterChip(
                        label: l10n.periodMonth,
                        selected: filter == 2,
                        compact: true,
                        onTap: () => setState(() => filter = 2),
                      ),
                      LeaderboardFilterChip(
                        label: l10n.periodWeek,
                        selected: filter == 3,
                        compact: true,
                        onTap: () => setState(() => filter = 3),
                      ),
                      LeaderboardFilterChip(
                        label: l10n.periodDay,
                        selected: filter == 4,
                        compact: true,
                        onTap: () => setState(() => filter = 4),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.white24,
              ),
              LeaderboardFilterChip(
                label: l10n.periodMine,
                selected: isMine,
                accent: true,
                compact: true,
                onTap: () => setState(() => filter = 5),
              ),
            ],
          ),
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
                child: Text(
                  isMine ? l10n.colAttempt : l10n.colPlayer,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (!isMine)
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
          child: isMine
              ? _MineList(store: store, padding: widget.listPadding)
              : _ScoresList(
                  store: store,
                  periodKey: periodKey,
                  padding: widget.listPadding,
                  ghostTimeMs: widget.ghostTimeMs,
                  ghostCountryCode: widget.ghostCountryCode,
                ),
        ),
      ],
    );
  }
}

class LeaderboardFilterChip extends StatelessWidget {
  const LeaderboardFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // «Мои» — лёгкий золотисто-жёлтый оттенок
    final active = accent ? const Color(0xFFFFD54F) : theme.colorScheme.primary;
    final idleBorder = accent
        ? const Color(0xFFFFD54F).withValues(alpha: 0.35)
        : Colors.white12;
    final idleBg = accent
        ? const Color(0xFFFFD54F).withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.04);
    final idleText = accent
        ? const Color(0xFFFFECB3).withValues(alpha: 0.9)
        : Colors.white70;

    return Padding(
      padding: EdgeInsets.only(right: compact ? 4 : 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? (accent ? 10 : 8) : 12,
              vertical: compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 8 : 10),
              color: selected ? active.withValues(alpha: 0.22) : idleBg,
              border: Border.all(
                color: selected ? active.withValues(alpha: 0.65) : idleBorder,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 11 : 12,
                color: selected ? active : idleText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoresList extends StatelessWidget {
  const _ScoresList({
    required this.store,
    required this.periodKey,
    required this.padding,
    this.ghostTimeMs,
    this.ghostCountryCode = '--',
  });

  final ScoresStore store;
  final String periodKey;
  final EdgeInsets padding;
  final int? ghostTimeMs;
  final String ghostCountryCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final list = store.scoresForNamedPeriod(periodKey).take(50).toList();
    final ghostMs = ghostTimeMs;

    if (ghostMs == null) {
      if (list.isEmpty) {
        return Center(child: Text(l10n.leaderboardEmpty));
      }
      return ListView.builder(
        padding: padding,
        itemCount: list.length,
        itemBuilder: (context, i) {
          return LeaderboardRankRow(
            place: i + 1,
            entry: list[i],
            highlight: i < 3,
          );
        },
      );
    }

    final insertAt = store.rankFor(ghostMs, period: periodKey).place - 1;
    final ghost = ScoreEntry(
      id: 'ghost',
      displayName: l10n.youGhost,
      timeMs: ghostMs,
      createdAt: DateTime.now(),
      countryCode: ghostCountryCode,
    );

    if (list.isEmpty) {
      return ListView(
        padding: padding,
        children: [
          LeaderboardRankRow(
            place: 1,
            entry: ghost,
            ghost: true,
            ghostLabel: l10n.youGhost,
          ),
          const SizedBox(height: 8),
          Center(child: Text(l10n.leaderboardEmpty)),
        ],
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: list.length + 1,
      itemBuilder: (context, i) {
        if (i == insertAt) {
          return LeaderboardRankRow(
            place: insertAt + 1,
            entry: ghost,
            ghost: true,
            ghostLabel: l10n.youGhost,
          );
        }
        final idx = i < insertAt ? i : i - 1;
        final place = idx < insertAt ? idx + 1 : idx + 2;
        return LeaderboardRankRow(
          place: place,
          entry: list[idx],
          highlight: place <= 3,
        );
      },
    );
  }
}

class _MineList extends StatelessWidget {
  const _MineList({required this.store, required this.padding});

  final ScoresStore store;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final attempts = store.myAttempts;
    if (attempts.isEmpty) {
      return Center(child: Text(l10n.myAttemptsEmpty));
    }
    final byTime = [...attempts]..sort((a, b) => b.timeMs.compareTo(a.timeMs));
    final placeOf = <String, int>{
      for (var i = 0; i < byTime.length; i++) byTime[i].id: i + 1,
    };
    return ListView.builder(
      padding: padding,
      itemCount: attempts.length,
      itemBuilder: (context, i) {
        final a = attempts[i];
        return MyAttemptRow(
          place: placeOf[a.id] ?? (i + 1),
          attempt: a,
        );
      },
    );
  }
}

class MyAttemptRow extends StatelessWidget {
  const MyAttemptRow({
    super.key,
    required this.place,
    required this.attempt,
  });

  final int place;
  final LocalAttempt attempt;

  String _dateLabel(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm\n$hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final top = place <= 3;

    return GamePanel(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      accent: attempt.shared
          ? theme.colorScheme.primary
          : const Color(0xFF7EE0FF),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$place',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: top ? theme.colorScheme.primary : Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              attempt.shared ? l10n.attemptShared : l10n.attemptLocal,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: attempt.shared
                    ? theme.colorScheme.primary
                    : const Color(0xFF7EE0FF),
              ),
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              '${attempt.timeSec.toStringAsFixed(2)}s',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: top ? theme.colorScheme.primary : Colors.white70,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              _dateLabel(attempt.createdAt),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white54,
                fontWeight: FontWeight.w600,
                height: 1.2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
