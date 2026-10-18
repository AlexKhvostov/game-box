import 'leaderboard_tone.dart';
import 'ranking_art.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mobile_account.dart';
import '../../domain/score_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_sheet.dart';
import '../../ui/game_ui.dart';
import '../../ui/public_name_controls.dart';

abstract final class LeaderboardLayout {
  static bool narrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;
  static double placeFor(BuildContext context) =>
      LeaderboardTone.dark(context) ? (narrow(context) ? 30 : 34) : place;
  static double boostsFor(BuildContext context) =>
      LeaderboardTone.dark(context) ? (narrow(context) ? 44 : 50) : boosts;
  static double timeFor(BuildContext context) =>
      LeaderboardTone.dark(context) ? (narrow(context) ? 78 : 85) : time;
  static const place = 20.0,
      country = 20.0,
      boosts = 44.0,
      time = 96.0,
      risk = 24.0,
      path = 30.0;
}

String scoreDateLabel(DateTime value, {bool full = false}) {
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}${full ? '.${d.year}' : ''} · ${two(d.hour)}:${two(d.minute)}';
}

/// Informational marks, not separate buttons in a ranking row.
class ScoreBoostIcons extends StatelessWidget {
  const ScoreBoostIcons({
    super.key,
    required this.hadJump,
    required this.hadHelmet,
  });
  final bool hadJump, hadHelmet;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Semantics(
      label: ru
          ? 'Прыжок: ${hadJump ? "да" : "нет"}. Шлем: ${hadHelmet ? "да" : "нет"}.'
          : 'Jump: ${hadJump ? "yes" : "no"}. Helmet: ${hadHelmet ? "yes" : "no"}.',
      child: SizedBox(
        width: LeaderboardLayout.boostsFor(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BoostMark(helmet: false, used: hadJump),
            SizedBox(width: LeaderboardTone.dark(context) ? 3 : 4),
            _BoostMark(helmet: true, used: hadHelmet),
          ],
        ),
      ),
    );
  }
}

class _BoostMark extends StatelessWidget {
  const _BoostMark({required this.helmet, required this.used});
  final bool helmet, used;
  @override
  Widget build(BuildContext context) => Container(
    width: LeaderboardTone.dark(context) && !LeaderboardLayout.narrow(context)
        ? 22
        : 20,
    height: LeaderboardTone.dark(context) ? 23 : 20,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(5),
      border: Border.all(
        color: used ? const Color(0xFFC0F6FF) : const Color(0x3357BAD1),
      ),
      color: LeaderboardTone.dark(context) ? const Color(0xFF00334D) : null,
    ),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: LeaderboardTone.dark(context)
              ? Opacity(
                  opacity: used ? 1 : .3,
                  child: RankingArt(
                    helmet ? "helmet" : "jump",
                    width: 19,
                    height: 21,
                  ),
                )
              : GameAbilityIcon(helmet: helmet, size: 18, enabled: used),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            decoration: BoxDecoration(
              color: used ? const Color(0xFFD9FFF4) : null,
              borderRadius: BorderRadius.circular(3),
            ),
            child: used
                ? const Icon(
                    Icons.check_rounded,
                    size: 7,
                    color: Color(0xFF036482),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    ),
  );
}

/// Shared three-zone presentation: player/date, abilities, run metrics.
class LeaderboardDetailRow extends StatelessWidget {
  const LeaderboardDetailRow({
    super.key,
    required this.place,
    required this.title,
    required this.timeMs,
    required this.riskCount,
    required this.runDistance,
    required this.hadJump,
    required this.hadHelmet,
    required this.accent,
    this.detail,
    this.date,
    this.countryCode = '--',
    this.highlight = false,
    this.showMedal = false,
    this.onTap,
  });
  final int place, timeMs, riskCount, runDistance;
  final String title, countryCode;
  final String? detail, date;
  final bool hadJump, hadHelmet, highlight, showMedal;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (LeaderboardTone.dark(context)) {
      return _NeonDetailRow(row: this);
    }
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final large = MediaQuery.textScalerOf(context).scale(11) > 16.5;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: title,
          child: Text(
            title,
            maxLines: large ? null : 1,
            overflow: large ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: LeaderboardTone.text(context),
            ),
          ),
        ),
        if (date != null || countryCode != '--')
          Text(
            [if (countryCode != '--') countryCode, ?date].join(' · '),
            style: TextStyle(
              fontSize: 10,
              color: LeaderboardTone.muted(context),
            ),
          ),
        if (detail != null)
          Text(
            detail!,
            style: TextStyle(
              fontSize: 10,
              color: LeaderboardTone.muted(context),
            ),
          ),
      ],
    );
    final boosts = ScoreBoostIcons(hadJump: hadJump, hadHelmet: hadHelmet);
    final metrics = Column(
      crossAxisAlignment: large
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          '${(timeMs / 1000).toStringAsFixed(3)}${ru ? "с" : "s"}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: LeaderboardTone.text(context),
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Wrap(
          spacing: 5,
          runSpacing: 2,
          children: [
            Semantics(
              label: '${ru ? "Риск" : "Risk"}: $riskCount',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameMetricIcon(risk: true, size: 11),
                  const SizedBox(width: 2),
                  Text(
                    '$riskCount',
                    style: TextStyle(
                      fontSize: 10,
                      color: LeaderboardTone.text(context),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: '${ru ? "Пробег" : "Distance"}: $runDistance',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameMetricIcon(risk: false, size: 11),
                  const SizedBox(width: 2),
                  Text(
                    '$runDistance',
                    style: TextStyle(
                      fontSize: 10,
                      color: LeaderboardTone.text(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: LeaderboardLayout.place,
          child: Text(
            '$place',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: LeaderboardTone.dark(context) && place <= 3
                  ? GameUi.yellow
                  : LeaderboardTone.muted(context),
            ),
          ),
        ),
        Expanded(
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: 4),
                    boosts,
                    const SizedBox(height: 4),
                    metrics,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 4),
                    boosts,
                    const SizedBox(width: 4),
                    SizedBox(width: LeaderboardLayout.time, child: metrics),
                  ],
                ),
        ),
      ],
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: BoxConstraints(minHeight: GameUi.touchTarget(context)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          margin: LeaderboardTone.dark(context)
              ? const EdgeInsets.only(bottom: 6)
              : null,
          decoration: BoxDecoration(
            gradient: LeaderboardTone.dark(context)
                ? LinearGradient(
                    colors: highlight
                        ? const [Color(0xFF1E5264), Color(0xFF153B4F)]
                        : const [Color(0xFF153249), Color(0xFF102B40)],
                  )
                : highlight
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF0AE), Color(0xFFFFD56C)],
                  )
                : null,
            borderRadius: LeaderboardTone.dark(context) || highlight
                ? BorderRadius.circular(8)
                : null,
            border: LeaderboardTone.dark(context)
                ? Border.all(
                    color: highlight
                        ? const Color(0xFF65BAAC)
                        : const Color(0xFF36576C),
                  )
                : highlight
                ? Border.all(color: const Color(0xFFFFF0AE))
                : Border(
                    bottom: BorderSide(
                      color: LeaderboardTone.muted(
                        context,
                      ).withValues(alpha: .22),
                    ),
                  ),
          ),
          child: row,
        ),
      ),
    );
  }
}

class LeaderboardRankRow extends StatelessWidget {
  const LeaderboardRankRow({
    super.key,
    required this.place,
    required this.entry,
    this.highlight = false,
    this.ghost = false,
    this.ghostLabel,
    this.onTap,
  });
  final int place;
  final ScoreEntry entry;
  final bool highlight, ghost;
  final String? ghostLabel;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final mine =
        !ghost &&
        entry.uid != null &&
        entry.uid == context.watch<MobileAccount?>()?.id;
    return LeaderboardDetailRow(
      place: place,
      title: ghost
          ? (ghostLabel ?? entry.displayName)
          : context.watch<MobileAccount?>()?.isPlayerHidden(entry.uid) == true
          ? publicPlayerName(context, entry.uid, entry.displayName)
          : entry.accountName == null
          ? entry.displayName
          : '${entry.displayName} · ${entry.accountName}',
      date: scoreDateLabel(entry.createdAt),
      countryCode: entry.countryCode,
      timeMs: entry.timeMs,
      riskCount: entry.riskCount,
      runDistance: entry.runDistance,
      hadJump: entry.hadJump,
      hadHelmet: entry.hadHelmet,
      accent: GameUi.ink,
      highlight: ghost || mine,
      showMedal: !ghost,
      onTap: onTap,
    );
  }
}

/// Native table face of approved ranking A, without changing score actions.
class _NeonDetailRow extends StatelessWidget {
  const _NeonDetailRow({required this.row});
  final LeaderboardDetailRow row;

  @override
  Widget build(BuildContext context) {
    final narrow = LeaderboardLayout.narrow(context);
    final large = MediaQuery.textScalerOf(context).scale(11) > 16.5;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    const mint = Color(0xFF71FFF0);
    final medal = row.showMedal && row.place <= 3;
    final leaderColor = [
      const Color(0xFFFFE876),
      const Color(0xFFE7FCFF),
      const Color(0xFFFFB17D),
    ][(row.place - 1).clamp(0, 2)];
    final metadata = [
      if (row.countryCode != '--') row.countryCode,
      ?row.date,
    ].join(' · ');
    final identity = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: row.title,
          child: Text(
            row.title,
            maxLines: large ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFF2F8FF),
              fontWeight: FontWeight.w800,
              fontSize: narrow ? 11.5 : 13.2,
              height: 1.15,
            ),
          ),
        ),
        if (metadata.isNotEmpty) ...[
          SizedBox(height: row.detail == null ? 4 : 1),
          Text(
            metadata,
            style: TextStyle(
              color: const Color(0xFFA4CDEF),
              fontSize: narrow ? 8.3 : 9.4,
              height: 1.1,
            ),
          ),
        ],
        if (row.detail != null) ...[
          const SizedBox(height: 1),
          Text(
            row.detail!,
            style: const TextStyle(
              color: Color(0xFFA4CDEF),
              fontSize: 9,
              height: 1.15,
            ),
          ),
        ],
      ],
    );
    Widget metric(bool risk, int value) => Semantics(
      label:
          '${risk ? (ru ? "Риск" : "Risk") : (ru ? "Пробег" : "Distance")}: $value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RankingArt(risk ? 'risk' : 'footsteps', width: 10, height: 12),
          const SizedBox(width: 2),
          Text(
            '$value',
            style: TextStyle(
              color: risk ? const Color(0xFFFF9AB2) : const Color(0xFFCFE5F9),
              fontSize: narrow ? 9 : 10,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
    final metrics = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            '${(row.timeMs / 1000).toStringAsFixed(3)} ${ru ? "с" : "s"}',
            style: TextStyle(
              color: const Color(0xFFF2F8FF),
              fontSize: narrow ? 12 : 13.3,
              height: 1.15,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              metric(true, row.riskCount),
              const SizedBox(width: 4),
              metric(false, row.runDistance),
            ],
          ),
        ),
      ],
    );
    final boosts = ScoreBoostIcons(
      hadJump: row.hadJump,
      hadHelmet: row.hadHelmet,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: row.onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          key: ValueKey('ranking-row-${row.place}'),
          constraints: const BoxConstraints(minHeight: 44),
          margin: const EdgeInsets.only(bottom: 3),
          padding: EdgeInsets.symmetric(
            horizontal: 3,
            vertical: row.detail == null ? 4 : 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: row.highlight ? mint : const Color(0xFF1187B5),
              width: row.highlight ? 1.4 : .8,
            ),
            gradient: LinearGradient(
              colors: row.highlight
                  ? const [
                      Color(0xFF00454F),
                      Color(0xFF002538),
                      Color(0xFF003947),
                    ]
                  : const [
                      Color(0xFF032A44),
                      Color(0xFF00162B),
                      Color(0xFF00213C),
                    ],
            ),
            boxShadow: row.highlight
                ? const [BoxShadow(color: Color(0x4000E2C1), blurRadius: 5)]
                : null,
          ),
          child: Stack(
            children: [
              if (medal && !row.highlight)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 1.2, color: leaderColor),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: LeaderboardLayout.placeFor(context),
                    child: medal
                        ? RankingArt(
                            'medal-${row.place}',
                            width: narrow ? 29 : 35,
                            height: 34,
                          )
                        : Text(
                            '${row.place}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: row.highlight
                                  ? mint
                                  : const Color(0xFF9EDBFF),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: large
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              identity,
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  boosts,
                                  const SizedBox(width: 8),
                                  Expanded(child: metrics),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: identity),
                              const SizedBox(width: 4),
                              boosts,
                              const SizedBox(width: 4),
                              SizedBox(
                                width: LeaderboardLayout.timeFor(context),
                                child: metrics,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка мест по срезам (день / неделя / месяц / год / всё).
class PeriodRanksCard extends StatelessWidget {
  const PeriodRanksCard({super.key, required this.ranks});

  final PeriodRanks ranks;

  @override
  Widget build(BuildContext context) {
    return PeriodRanksCompact(ranks: ranks);
  }
}

/// Компактные карточки мест: сверху период, снизу номер — в один ряд.
class PeriodRanksCompact extends StatelessWidget {
  const PeriodRanksCompact({super.key, required this.ranks});

  final PeriodRanks ranks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final items = <(String, RankInfo)>[
      (l10n.periodAll, ranks.all),
      (l10n.periodYear, ranks.year),
      (l10n.periodMonth, ranks.month),
      (l10n.periodWeek, ranks.week),
      (l10n.periodDay, ranks.day),
    ];

    return GamePanel(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      accent: GameUi.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.yourPlacesTitle,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
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
    const accent = GameUi.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: highlight
            ? GameUi.ink.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: highlight ? GameUi.ink.withValues(alpha: 0.4) : Colors.white12,
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
              color: GameUi.inkMuted,
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
