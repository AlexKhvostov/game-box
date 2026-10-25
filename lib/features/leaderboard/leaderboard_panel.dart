import '../../data/app_analytics.dart';
import 'leaderboard_tone.dart';
import 'ranking_art.dart';
import 'ranking_tabs.dart';
import 'ranking_summary.dart';
import 'average_ranking_panel.dart';
import 'my_attempts_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/scores_store.dart';
import '../../domain/score_entry.dart';
import '../../domain/round_delivery.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_ui.dart';
import '../result/share_score_sheet.dart';
import 'leaderboard_widgets.dart';
import 'player_result_sheet.dart';

/// Periods and the internally scrolling ranking shared by result and menu.
class LeaderboardPanel extends StatefulWidget {
  const LeaderboardPanel({
    super.key,
    this.ghostTimeMs,
    this.ghostCountryCode = '--',
    this.ghostRiskCount = 0,
    this.ghostRunDistance = 0,
    this.ghostHadJump = false,
    this.ghostHadHelmet = false,
    this.listPadding = const EdgeInsets.fromLTRB(1, 0, 1, 4),
    this.initialPeriod = 4,
    this.initialAverage = false,
  }) : assert(initialPeriod >= 0 && initialPeriod <= 4);
  final int initialPeriod;
  final bool initialAverage;
  final int? ghostTimeMs;
  final String ghostCountryCode;
  final int ghostRiskCount, ghostRunDistance;
  final bool ghostHadJump, ghostHadHelmet;
  final EdgeInsets listPadding;
  @override
  State<LeaderboardPanel> createState() => LeaderboardPanelState();
}

class LeaderboardPanelState extends State<LeaderboardPanel> {
  int filter = 4;
  int _recordFilter = 4;
  bool get isMine => filter == 5;
  bool get isAverage => filter == 6;
  String get periodKey =>
      ['all', 'year', 'month', 'week', 'day'][filter.clamp(0, 4)];
  @override
  void initState() {
    super.initState();
    _recordFilter = widget.initialPeriod;
    filter = widget.initialAverage ? 6 : _recordFilter;
    AppAnalytics.page(
      'leaderboard',
      isAverage ? 'average' : 'record',
      source: 'initial',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ScoresStore>().refreshIfStale();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = context.watch<ScoresStore>();
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final large = MediaQuery.textScalerOf(context).scale(11) > 16.5;
    final labels = ru
        ? ['Всё', 'Год', 'Мес.', 'Нед.', 'День']
        : [
            'All',
            'Year',
            large ? 'Mo.' : 'Month',
            large ? 'Wk.' : 'Week',
            'Day',
          ];
    final fullLabels = [
      l10n.periodAll,
      l10n.periodYear,
      l10n.periodMonth,
      l10n.periodWeek,
      l10n.periodDay,
    ];
    if (store.supportsAverage) {
      final rows = store.scoresForNamedPeriod(periodKey);
      final mine = rows.where((r) => r.uid == store.account?.id).firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RankingTabs(
            average: isAverage,
            onRecord: () {
              if (isAverage) AppAnalytics.page('leaderboard', 'record');
              setState(() => filter = _recordFilter.clamp(0, 4));
            },
            onAverage: () {
              if (!isAverage) AppAnalytics.page('leaderboard', 'average');
              setState(() {
                if (!isAverage) _recordFilter = filter.clamp(0, 4);
                filter = 6;
              });
              store.refreshIfStale();
            },
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF032438),
                border: Border(
                  left: BorderSide(color: Color(0xFF197997)),
                  right: BorderSide(color: Color(0xFF197997)),
                  bottom: BorderSide(color: Color(0xFF197997)),
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
              ),
              child: isAverage
                  ? AverageRankingPanel(store: store)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(8, 8, 8, 2),
                          child: _CompactRankingLegend(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            key: const ValueKey('ranking-periods'),
                            children: [
                              for (var i = 0; i < 5; i++) ...[
                                if (i > 0) const SizedBox(width: 4),
                                Expanded(
                                  child: Tooltip(
                                    message: fullLabels[i],
                                    child: LeaderboardFilterChip(
                                      key: ValueKey('leaderboard-filter-$i'),
                                      label: labels[i],
                                      selected: filter == i,
                                      compact: true,
                                      joined: true,
                                      onTap: () => setState(() {
                                        if (filter != i) {
                                          AppAnalytics.page(
                                            'ranking_period',
                                            [
                                              'all',
                                              'year',
                                              'month',
                                              'week',
                                              'day',
                                            ][i],
                                          );
                                        }
                                        filter = i;
                                        _recordFilter = i;
                                      }),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        RankingSummary(
                          key: const ValueKey('record-personal-summary'),
                          items: [
                            '${ru ? "Ваш рекорд" : "Your record"}: ${mine == null ? "—" : (mine.timeMs / 1000).toStringAsFixed(3)} ${ru ? "с" : "s"}',
                            '${ru ? "Место" : "Place"}: ${mine?.place ?? (mine == null ? "—" : rows.indexOf(mine) + 1)}',
                          ],
                        ),
                        const RankingRecordColumns(),
                        Expanded(
                          child: _ScoresList(
                            key: ValueKey('scores-$periodKey'),
                            store: store,
                            periodKey: periodKey,
                            padding: widget.listPadding,
                            widget: widget,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final legend = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          LeaderboardTone.dark(context)
                              ? const RankingArt("jump", width: 14, height: 15)
                              : const GameAbilityIcon(helmet: false, size: 16),
                          Text(
                            ru ? 'Прыжок ·' : 'Jump ·',
                            style: TextStyle(
                              fontSize: 10,
                              color: LeaderboardTone.text(context),
                            ),
                          ),
                          LeaderboardTone.dark(context)
                              ? const RankingArt(
                                  "helmet",
                                  width: 14,
                                  height: 15,
                                )
                              : const GameAbilityIcon(helmet: true, size: 16),
                          Text(
                            ru ? 'Шлем' : 'Helmet',
                            style: TextStyle(
                              fontSize: 10,
                              color: LeaderboardTone.text(context),
                            ),
                          ),
                        ],
                      ),
                      if (!large)
                        Text(
                          ru ? 'Яркие — были включены' : 'Bright = enabled',
                          style: TextStyle(
                            fontSize: 10,
                            color: LeaderboardTone.text(context),
                          ),
                        ),
                      Wrap(
                        spacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          LeaderboardTone.dark(context)
                              ? const RankingArt("risk", width: 12)
                              : const GameMetricIcon(risk: true, size: 12),
                          Text(
                            ru ? 'Риск ·' : 'Risk ·',
                            style: TextStyle(
                              fontSize: 10,
                              color: LeaderboardTone.text(context),
                            ),
                          ),
                          LeaderboardTone.dark(context)
                              ? const RankingArt("footsteps", width: 12)
                              : const GameMetricIcon(risk: false, size: 12),
                          Text(
                            ru ? 'Шаги' : 'Steps',
                            style: TextStyle(
                              fontSize: 10,
                              color: LeaderboardTone.text(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                  final mine = LeaderboardFilterChip(
                    key: const ValueKey('leaderboard-filter-5'),
                    label: ru ? 'Мои попытки' : 'My attempts',
                    selected: isMine,
                    accent: true,
                    compact: true,
                    onTap: () => openMyAttemptsWindow(
                      context,
                      panel: const RankingAttemptsPanel(),
                    ),
                  );
                  return large
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [legend, mine],
                        )
                      : Row(
                          children: [
                            Expanded(child: legend),
                            SizedBox(width: 6),
                            mine,
                          ],
                        );
                },
              ),
              if (!isAverage) ...[
                SizedBox(height: 2),
                Row(
                  children: [
                    for (var i = 0; i < 5; i++) ...[
                      if (i > 0) SizedBox(width: 4),
                      Expanded(
                        child: Tooltip(
                          message: fullLabels[i],
                          child: LeaderboardFilterChip(
                            key: ValueKey('leaderboard-filter-$i'),
                            label: labels[i],
                            selected: filter == i,
                            compact: true,
                            joined: true,
                            onTap: () => setState(() {
                              filter = i;
                              _recordFilter = i;
                            }),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!large && !isAverage)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: LeaderboardLayout.placeFor(context),
                          child: Text(
                            '#',
                            style: TextStyle(
                              fontSize: 10,
                              color: LeaderboardTone.muted(context),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            isMine ? l10n.colAttempt : l10n.colPlayer,
                            style: TextStyle(
                              fontSize: 10,
                              color: LeaderboardTone.muted(context),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: LeaderboardLayout.boostsFor(context),
                          child: Text(
                            LeaderboardTone.dark(context)
                                ? (ru
                                      ? (store.supportsAverage
                                            ? 'Усил.'
                                            : 'Усиления')
                                      : (store.supportsAverage
                                            ? 'Boosts'
                                            : 'Abilities'))
                                : l10n.colBoosts,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: LeaderboardTone.muted(context),
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        SizedBox(
                          width: LeaderboardLayout.timeFor(context),
                          child: Text(
                            ru ? 'Результат' : 'Result',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 10,
                              color: LeaderboardTone.muted(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        Expanded(
          child: isAverage
              ? AverageRankingPanel(store: store)
              : isMine
              ? _MineList(
                  key: const ValueKey('mine-list'),
                  store: store,
                  padding: widget.listPadding,
                )
              : _ScoresList(
                  key: ValueKey('scores-$periodKey'),
                  store: store,
                  periodKey: periodKey,
                  padding: widget.listPadding,
                  widget: widget,
                ),
        ),
        if (LeaderboardTone.dark(context) && !store.supportsAverage)
          const _RankingFooter(),
      ],
    );
  }
}

class _CompactRankingLegend extends StatelessWidget {
  const _CompactRankingLegend();
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final color = LeaderboardTone.text(context);
    return Column(
      key: const ValueKey('ranking-legend'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            for (final item in [
              ('jump', ru ? 'Прыжок' : 'Jump'),
              ('helmet', ru ? 'Шлем' : 'Helmet'),
              ('risk', ru ? 'Риск' : 'Risk'),
              ('footsteps', ru ? 'Шаги' : 'Steps'),
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RankingArt(item.$1, width: 12, height: 14),
                  const SizedBox(width: 3),
                  Text(
                    item.$2,
                    style: TextStyle(fontSize: 9, color: color, height: 1.1),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          ru ? 'Яркие — усиления включены' : 'Bright = abilities enabled',
          style: TextStyle(
            fontSize: 9,
            color: LeaderboardTone.muted(context),
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// 36dp visible glass face inside an at least 48dp tap region.
class LeaderboardFilterChip extends StatelessWidget {
  const LeaderboardFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
    this.compact = false,
    this.joined = false,
  });
  final String label;
  final bool selected, accent, compact, joined;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => LeaderboardTone.dark(context)
      ? _NeonFilterChip(
          label: label,
          selected: selected,
          accent: accent,
          onTap: onTap,
        )
      : Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                constraints: BoxConstraints(
                  minHeight: GameUi.touchTarget(context),
                  minWidth: GameUi.touchTarget(context),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: 6 + (GameUi.touchTarget(context) - 48) / 2,
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: EdgeInsets.symmetric(
                    horizontal: accent ? 12 : 2,
                    vertical: 7,
                  ),
                  decoration: GameGlassDecoration(
                    glass: LeaderboardTone.dark(context)
                        ? GameGlass.none
                        : selected && !accent
                        ? GameGlass.selected
                        : GameGlass.button,
                    borderRadius: BorderRadius.circular(accent ? 18 : 8),
                    border: Border.all(
                      color: LeaderboardTone.dark(context)
                          ? selected
                                ? GameUi.yellow
                                : const Color(0xFF426378)
                          : const Color(0xFFCDF5FF),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: LeaderboardTone.dark(context)
                          ? selected
                                ? const [Color(0xFF315269), Color(0xFF18394F)]
                                : const [Color(0xFF153248), Color(0xFF102A3E)]
                          : accent
                          ? [const Color(0xFFFFEFA9), const Color(0xFFFFCC5C)]
                          : selected
                          ? [const Color(0xFF175581), const Color(0xFF0B3557)]
                          : [const Color(0xFF95E2FA), const Color(0xFF39A1DB)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x660A4D75),
                        offset: Offset(0, 2),
                        blurRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: LeaderboardTone.dark(context)
                          ? selected
                                ? GameUi.yellow
                                : GameUi.muted
                          : selected && !accent
                          ? GameUi.text
                          : GameUi.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
}

class _NeonFilterChip extends StatelessWidget {
  const _NeonFilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final bool selected, accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = selected
        ? (accent ? const Color(0xFF71FFF0) : const Color(0xFFFFEE85))
        : const Color(0xFF30DEFF);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: accent ? 8 : 2,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(accent ? 9 : 6),
                border: Border.all(color: color),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: selected
                      ? const [
                          Color(0xFF34596B),
                          Color(0xFF092339),
                          Color(0xFF173D4C),
                        ]
                      : const [
                          Color(0xFF074269),
                          Color(0xFF021C36),
                          Color(0xFF0A3D5A),
                        ],
                ),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: .22), blurRadius: 6),
                ],
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? color : const Color(0xFFE1EDFF),
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingFooter extends StatelessWidget {
  const _RankingFooter();
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('ranking-footer'),
    constraints: const BoxConstraints(minHeight: 32),
    margin: const EdgeInsets.fromLTRB(3, 4, 3, 0),
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFF0B99B9))),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: Color(0xFF96E1F4),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            Localizations.localeOf(context).languageCode == 'ru'
                ? 'Прыжок / шлем — использованные усиления'
                : 'Jump / helmet — abilities used',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFFAACDEF),
              height: 1.2,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScoresList extends StatelessWidget {
  const _ScoresList({
    super.key,
    required this.store,
    required this.periodKey,
    required this.padding,
    required this.widget,
  });
  final ScoresStore store;
  final String periodKey;
  final EdgeInsets padding;
  final LeaderboardPanel widget;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final source = store.scoresForNamedPeriod(periodKey);
    final top = source
        .where((r) => (r.place ?? source.indexOf(r) + 1) <= 200)
        .take(200)
        .toList();
    final outside = source
        .where((r) => r.uid == store.account?.id && (r.place ?? 0) > 200)
        .firstOrNull;
    final list = [
      ...top,
      if (outside != null && !top.any((r) => r.uid == outside.uid)) outside,
    ];
    final ghostMs = widget.ghostTimeMs;
    if (list.isEmpty && ghostMs == null) return _RankingStatus(store: store);
    final ghostPlace = ghostMs == null
        ? null
        : store.rankFor(ghostMs, period: periodKey).place;
    final insertAt = ghostPlace == null
        ? -1
        : (ghostPlace - 1).clamp(0, list.length);
    final ghost = ghostMs == null
        ? null
        : ScoreEntry(
            id: 'ghost',
            displayName: l10n.youGhost,
            timeMs: ghostMs,
            createdAt: DateTime.now(),
            countryCode: widget.ghostCountryCode,
            riskCount: widget.ghostRiskCount,
            runDistance: widget.ghostRunDistance,
            hadJump: widget.ghostHadJump,
            hadHelmet: widget.ghostHadHelmet,
          );
    return Column(
      children: [
        if (store.loading) const LinearProgressIndicator(minHeight: 2),
        if (!store.loading && !store.online)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              Localizations.localeOf(context).languageCode == 'ru'
                  ? 'Без сети · сохранённые результаты'
                  : 'Offline · saved results',
              style: TextStyle(
                fontSize: 10,
                color: LeaderboardTone.muted(context),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: store.load,
            child: ListView.builder(
              key: PageStorageKey('ranking-$periodKey'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              itemCount:
                  list.length +
                  (ghost == null ? 0 : 1) +
                  (outside == null ? 0 : 1),
              itemBuilder: (context, i) {
                if (outside != null && i == top.length) {
                  return const RankingOwnDivider();
                }
                final position = outside != null && i > top.length ? i - 1 : i;
                if (position == insertAt) {
                  return LeaderboardRankRow(
                    place: ghostPlace!,
                    entry: ghost!,
                    ghost: true,
                    ghostLabel: l10n.youGhost,
                  );
                }
                final index = ghost != null && position > insertAt
                    ? position - 1
                    : position;
                final place = list[index].place ?? position + 1;
                return LeaderboardRankRow(
                  key: ValueKey('record-row-$place'),
                  place: place,
                  entry: list[index],
                  highlight: i < 3,
                  onTap: () => showPlayerResultSheet(
                    context,
                    entry: list[index],
                    place: place,
                    own:
                        list[index].uid != null &&
                        list[index].uid == store.account?.id,
                    periodLabel: {
                      'all': l10n.periodAll,
                      'year': l10n.periodYear,
                      'month': l10n.periodMonth,
                      'week': l10n.periodWeek,
                      'day': l10n.periodDay,
                    }[periodKey],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RankingStatus extends StatelessWidget {
  const _RankingStatus({required this.store, this.mine = false});
  final ScoresStore store;
  final bool mine;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mine && !store.localHistoryReadable) ...[
              Text(
                RoundDelivery.message('round_storage_failed', ru: ru),
                textAlign: TextAlign.center,
              ),
            ] else if (!mine && store.loading) ...[
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 12),
              Text(
                ru ? 'Загружаем рейтинг…' : 'Loading leaderboard…',
                style: TextStyle(color: LeaderboardTone.text(context)),
              ),
            ] else ...[
              const GameArtwork(GameArt.avatar, size: 56),
              SizedBox(height: 8),
              Text(
                mine
                    ? l10n.myAttemptsEmpty
                    : store.online
                    ? l10n.leaderboardEmpty
                    : ru
                    ? 'Не удалось загрузить рейтинг. Проверьте сеть.'
                    : 'Could not load the leaderboard. Check your connection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: LeaderboardTone.text(context)),
              ),
              if (!mine && !store.online)
                TextButton(
                  onPressed: store.load,
                  style: TextButton.styleFrom(
                    foregroundColor: LeaderboardTone.text(context),
                  ),
                  child: Text(ru ? 'Повторить' : 'Retry'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MineList extends StatelessWidget {
  const _MineList({super.key, required this.store, required this.padding});
  final ScoresStore store;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final attempts = [...store.myAttempts]
      ..sort((a, b) => b.timeMs.compareTo(a.timeMs));
    if (attempts.isEmpty) return _RankingStatus(store: store, mine: true);
    return ListView.builder(
      key: const PageStorageKey('ranking-mine'),
      padding: padding,
      itemCount: attempts.length,
      itemBuilder: (context, i) =>
          MyAttemptRow(place: i + 1, attempt: attempts[i]),
    );
  }
}

class MyAttemptRow extends StatelessWidget {
  const MyAttemptRow({super.key, required this.place, required this.attempt});
  final int place;
  final LocalAttempt attempt;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = context.watch<ScoresStore>();
    final automatic = store.account != null;
    final pending = store.isAttemptPending(attempt.id);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final name = attempt.displayName?.trim();
    final title = attempt.shared
        ? (name?.isNotEmpty == true ? name! : l10n.attemptShared)
        : attempt.deliveryError != null
        ? (ru ? 'Не принят сервером' : 'Not accepted')
        : pending
        ? (ru ? 'Ожидает сети' : 'Waiting for network')
        : l10n.attemptLocal;
    return LeaderboardDetailRow(
      place: place,
      title: title,
      date: scoreDateLabel(attempt.createdAt),
      detail: attempt.shared
          ? l10n.attemptShared
          : attempt.deliveryError != null
          ? RoundDelivery.message(attempt.deliveryError!, ru: ru)
          : automatic
          ? pending
                ? (ru ? 'Отправится автоматически' : 'Will sync automatically')
                : (ru ? 'Без общего рейтинга' : 'Outside shared ranking')
          : l10n.attemptTapToSave,
      timeMs: attempt.timeMs,
      riskCount: attempt.riskCount,
      runDistance: attempt.runDistance,
      hadJump: attempt.hadJump,
      hadHelmet: attempt.hadHelmet,
      accent: GameUi.ink,
      onTap: attempt.shared || automatic
          ? () => showPlayerResultSheet(
              context,
              entry: ScoreEntry(
                id: attempt.id,
                displayName: title,
                timeMs: attempt.timeMs,
                createdAt: attempt.createdAt,
                riskCount: attempt.riskCount,
                runDistance: attempt.runDistance,
                hadJump: attempt.hadJump,
                hadHelmet: attempt.hadHelmet,
              ),
              place: place,
              own: true,
            )
          : () => showShareScoreSheet(
              context,
              timeMs: attempt.timeMs,
              riskCount: attempt.riskCount,
              runDistance: attempt.runDistance,
              hadJump: attempt.hadJump,
              hadHelmet: attempt.hadHelmet,
            ),
    );
  }
}

class RankingRecordColumns extends StatelessWidget {
  const RankingRecordColumns({super.key, this.mine = false});
  final bool mine;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    Widget label(
      String value, {
      double? width,
      TextAlign align = TextAlign.start,
    }) => SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: align,
        style: TextStyle(fontSize: 9, color: LeaderboardTone.muted(context)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 2, 5, 4),
      child: Row(
        children: [
          label('#', width: LeaderboardLayout.placeFor(context)),
          Expanded(
            child: label(
              mine ? (ru ? 'Попытка' : 'Attempt') : (ru ? 'Игрок' : 'Player'),
            ),
          ),
          label(
            ru ? 'Усил.' : 'Boosts',
            width: LeaderboardLayout.boostsFor(context),
            align: TextAlign.center,
          ),
          const SizedBox(width: 4),
          label(
            ru ? 'Результат' : 'Result',
            width: LeaderboardLayout.timeFor(context),
            align: TextAlign.end,
          ),
        ],
      ),
    );
  }
}

class RankingAttemptsPanel extends StatelessWidget {
  const RankingAttemptsPanel({super.key});
  @override
  Widget build(BuildContext context) => const MyAttemptsPanel();
}
