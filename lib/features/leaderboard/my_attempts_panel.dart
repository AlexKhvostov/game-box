import '../../ui/analytics_navigation.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/scores_store.dart';
import '../../domain/average_ranking.dart';
import '../../domain/my_attempts.dart';
import '../../domain/round_delivery.dart';
import '../../domain/score_entry.dart';
import '../../ui/game_status_overlay.dart';
import '../../ui/game_ui.dart';
import '../result/share_score_sheet.dart';
import '../result/result_screen.dart';
import 'player_result_sheet.dart';

const _cyan = Color(0xFF5EEAFF), _gold = Color(0xFFFFE368);
const _text = Color(0xFFF0FDFF), _muted = Color(0xFFB2DDEC);
String _seconds(num? ms, bool ru) => ms == null
    ? '—'
    : (ms / 1000).toStringAsFixed(3).replaceAll('.', ru ? ',' : '.');
String _date(DateTime date, bool ru) {
  final d = date.toLocal(), now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final prefix = day == today
      ? (ru ? 'Сегодня' : 'Today')
      : day == today.subtract(const Duration(days: 1))
      ? (ru ? 'Вчера' : 'Yesterday')
      : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  return '$prefix, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

Future<void> openMyAttemptsWindow(
  BuildContext context, {
  Widget panel = const MyAttemptsPanel(),
}) => showModalBottomSheet<void>(
  routeSettings: analyticsWindow('attempts'),
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: false,
  backgroundColor: Colors.transparent,
  sheetAnimationStyle: GameUi.windowAnimationStyle,
  builder: (_) => MyAttemptsSheet(panel: panel),
);

class MyAttemptsSheet extends StatelessWidget {
  const MyAttemptsSheet({super.key, this.panel = const MyAttemptsPanel()});
  final Widget panel;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: math.min(media.size.width - 24, 400),
          height: math.min(
            620,
            media.size.height - media.padding.vertical - 24,
          ),
          child: Container(
            key: const ValueKey('my-attempts-sheet'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: _cyan, width: 2.5),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B405C), Color(0xFF02172A)],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x6611D9FF), blurRadius: 15),
              ],
            ),
            foregroundDecoration: const _AttemptsInnerBorder(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(11, 6, 5, 1),
                  child: Row(
                    children: [
                      Transform.rotate(
                        angle: -.12,
                        child: Image.asset(
                          'assets/branding/ui/my-attempts-hero-v1.png',
                          key: const ValueKey('my-attempts-hero'),
                          width: 41,
                          height: 41,
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            ru ? 'Мои попытки' : 'My attempts',
                            style: const TextStyle(
                              color: _text,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('my-attempts-close'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded, color: _cyan),
                      ),
                    ],
                  ),
                ),
                Expanded(child: panel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyAttemptsPanel extends StatefulWidget {
  const MyAttemptsPanel({super.key});
  @override
  State<MyAttemptsPanel> createState() => _MyAttemptsPanelState();
}

class _MyAttemptsPanelState extends State<MyAttemptsPanel> {
  bool _expanded = true;
  String? _selected, _owner;
  bool _ownerReady = false;
  final _list = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final store = context.read<ScoresStore>();
        store.refreshIfStale();
        store.loadAttemptHistory(refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  void _select(
    String id,
    MyAttemptsData data,
    double rowHeight, {
    bool scroll = false,
  }) {
    setState(() => _selected = id);
    if (!scroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_list.hasClients) return;
      final index = data.rows.reversed.toList().indexWhere((a) => a.id == id);
      if (index < 0) return;
      _list.animateTo(
        (index * rowHeight -
                _list.position.viewportDimension / 2 +
                rowHeight / 2)
            .clamp(0, _list.position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _detail(LocalAttempt attempt, ScoresStore store, int number) {
    if (!attempt.shared && store.account == null) {
      showShareScoreSheet(
        context,
        timeMs: attempt.timeMs,
        runDistance: attempt.runDistance,
        riskCount: attempt.riskCount,
        hadJump: attempt.hadJump,
        hadHelmet: attempt.hadHelmet,
      );
      return;
    }
    showPlayerResultSheet(
      context,
      entry: ScoreEntry(
        id: attempt.id,
        displayName:
            attempt.displayName ??
            (Localizations.localeOf(context).languageCode == 'ru'
                ? 'Моя попытка'
                : 'My attempt'),
        timeMs: attempt.timeMs,
        createdAt: attempt.createdAt,
        riskCount: attempt.riskCount,
        runDistance: attempt.runDistance,
        hadJump: attempt.hadJump,
        hadHelmet: attempt.hadHelmet,
      ),
      place: number,
      showPlace: number > 0,
      periodLabel: number > 0
          ? null
          : (Localizations.localeOf(context).languageCode == 'ru'
                ? 'Рекорд'
                : 'Best attempt'),
      own: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScoresStore>();
    final account = store.account;
    return account == null
        ? _buildPanel(context, store)
        : ListenableBuilder(
            listenable: account,
            builder: (context, _) => _buildPanel(context, store),
          );
  }

  Widget _buildPanel(BuildContext context, ScoresStore store) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final owner = store.account?.id;
    if (!_ownerReady || _owner != owner) {
      final changedOwner = _ownerReady;
      _ownerReady = true;
      _owner = owner;
      _selected = null;
      _expanded = true;
      if (changedOwner) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) store.loadAttemptHistory(refresh: true);
        });
      }
    }
    final ownRecords =
        owner == null
              ? <ScoreEntry>[]
              : store
                    .scoresForNamedPeriod('all')
                    .where((r) => r.uid == owner)
                    .toList()
          ..sort((a, b) => b.timeMs.compareTo(a.timeMs));
    final walletBest = MyAttemptsData.confirmedWalletBestTimeMs(
      wallet: store.account?.wallet,
      walletOwner: store.account?.walletOwner,
      owner: owner,
    );
    final data = MyAttemptsData(
      attempts: store.localHistoryReadable ? store.myAttempts : [],
      ranking: store.averageRanking,
      isPending: store.isAttemptPending,
      serverIdOf: store.serverAttemptKey,
      officialBest: ownRecords.firstOrNull,
      officialBestTimeMs: walletBest,
      serverHistory: store.serverAttemptHistory,
    );
    if (_selected == null ||
        (!data.rows.any((a) => a.id == _selected) &&
            data.best?.id != _selected)) {
      _selected = data.rows.lastOrNull?.id;
    }
    final selected =
        data.rows.where((a) => a.id == _selected).firstOrNull ??
        (data.best?.id == _selected ? data.best : null);
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final scale = textScale.clamp(1.0, 1.4);
    final rowHeight = 57 * scale;
    final visible = data.visibleAround(_selected);
    final currentAverage = data.averageMs;
    final totalAttempts =
        data.serverHistory?.totalCount ?? data.ranking?.mine.totalAttempts;
    final selectedOutside =
        selected != null && !data.rows.any((a) => a.id == selected.id);
    return GameStatusOverlay(
      message: store.loading || store.historyLoading
          ? (ru ? 'Обновляем историю…' : 'Refreshing history…')
          : null,
      busy: store.loading || store.historyLoading,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summaryHeight = 72 * scale;
          final plotHeight = math.min(
            190.0,
            math.max(80.0, constraints.maxHeight - summaryHeight - 230),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.max(
                    0,
                    constraints.maxHeight -
                        (rowHeight + 10) -
                        (16 + 20 * textScale) -
                        (!data.historyComplete &&
                                data.ranking?.mine.totalAttempts != null
                            ? 30 * textScale
                            : 0) -
                        (selectedOutside ? 48 * textScale : 0) -
                        1,
                  ),
                ),
                child: SingleChildScrollView(
                  key: const ValueKey('my-attempts-upper-scroll'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(11, 4, 11, 8),
                        child: SizedBox(
                          height: summaryHeight,
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  value: totalAttempts?.toString() ?? '—',
                                  label: ru
                                      ? 'Всего попыток'
                                      : 'Total attempts',
                                  subtitle: totalAttempts == null
                                      ? (ru ? 'Загружаем' : 'Loading')
                                      : (ru ? 'Подтверждено' : 'Confirmed'),
                                  onTap: null,
                                  valueKey: const ValueKey('my-attempts-total'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _StatTile(
                                  label: ru ? 'Лучшая попытка' : 'Best attempt',
                                  trophy: true,
                                  value:
                                      '${_seconds(data.bestTimeMs, ru)} ${ru ? 'с' : 's'}',
                                  subtitle: data.best == null
                                      ? (data.bestTimeMs != null
                                            ? (ru
                                                  ? 'Дата недоступна'
                                                  : 'Date unavailable')
                                            : (ru
                                                  ? 'Пока нет рекорда'
                                                  : 'No record yet'))
                                      : _date(data.best!.createdAt, ru),
                                  onTap: data.best == null
                                      ? null
                                      : () => showBestAttemptResult(
                                          context,
                                          data.best!,
                                        ),
                                  valueKey: const ValueKey('my-attempts-best'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _StatTile(
                                  value:
                                      '${_seconds(data.averageMs, ru)} ${ru ? 'с' : 's'}',
                                  label: ru ? 'Среднее' : 'Average',
                                  gold: true,
                                  info: true,
                                  subtitle: data.ranking != null
                                      ? (ru
                                            ? 'Учтено: ${data.ranking!.mine.usedCount}'
                                            : 'Counted: ${data.ranking!.mine.usedCount}')
                                      : (ru ? 'Загружаем' : 'Loading'),
                                  onTap: () => showDialog<void>(
                                    context: context,
                                    barrierColor: GameUi.modalBarrier,
                                    builder: (_) => MyAttemptsAverageHelp(
                                      ranking: data.ranking,
                                      historyComplete: data.historyComplete,
                                    ),
                                  ),
                                  valueKey: const ValueKey('my-attempts-mean'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!data.bestIsOfficial && data.best != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: Text(
                            data.historyComplete
                                ? (ru
                                      ? 'Рекорд подтверждённой истории'
                                      : 'Best in confirmed history')
                                : (ru
                                      ? 'Рекорд по доступной истории'
                                      : 'Best in available history'),
                            key: const ValueKey('my-attempts-best-source'),
                            style: const TextStyle(color: _muted, fontSize: 10),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        child: Container(
                          key: const ValueKey('my-attempts-graph-shell'),
                          decoration: BoxDecoration(
                            color: const Color(0xFF032137),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(color: _cyan, width: 1.3),
                          ),
                          child: Column(
                            children: [
                              TextButton(
                                key: const ValueKey('my-attempts-toggle'),
                                onPressed: () =>
                                    setState(() => _expanded = !_expanded),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  foregroundColor: _muted,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ru
                                            ? 'График · время, с'
                                            : 'Chart · time, s',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    Text(
                                      _expanded
                                          ? (ru ? 'Свернуть' : 'Collapse')
                                          : (ru ? 'Развернуть' : 'Expand'),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: _cyan,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Icon(
                                      _expanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 18,
                                      color: _cyan,
                                    ),
                                  ],
                                ),
                              ),
                              if (_expanded)
                                SizedBox(
                                  height: plotHeight,
                                  child: visible.isEmpty
                                      ? Center(
                                          child: Text(
                                            store.historyError != null
                                                ? (ru
                                                      ? 'История временно недоступна'
                                                      : 'History temporarily unavailable')
                                                : store.historyLoading
                                                ? (ru
                                                      ? 'Загружаем историю…'
                                                      : 'Loading history…')
                                                : (ru
                                                      ? 'Пока нет попыток'
                                                      : 'No attempts yet'),
                                            key: const ValueKey(
                                              'my-attempts-empty-graph-message',
                                            ),
                                            style: const TextStyle(
                                              color: _muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      : LayoutBuilder(
                                          builder: (context, chartBox) => Focus(
                                            onKeyEvent: (_, event) {
                                              if (event is! KeyDownEvent) {
                                                return KeyEventResult.ignored;
                                              }
                                              final step =
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .arrowRight
                                                  ? 1
                                                  : event.logicalKey ==
                                                        LogicalKeyboardKey
                                                            .arrowLeft
                                                  ? -1
                                                  : 0;
                                              if (step == 0 ||
                                                  data.rows.isEmpty) {
                                                return KeyEventResult.ignored;
                                              }
                                              final index = data.rows
                                                  .indexWhere(
                                                    (a) => a.id == _selected,
                                                  );
                                              _select(
                                                data
                                                    .rows[(index + step).clamp(
                                                      0,
                                                      data.rows.length - 1,
                                                    )]
                                                    .id,
                                                data,
                                                rowHeight,
                                                scroll: true,
                                              );
                                              return KeyEventResult.handled;
                                            },
                                            child: GestureDetector(
                                              key: const ValueKey(
                                                'my-attempts-plot',
                                              ),
                                              onTapDown: (details) {
                                                final i =
                                                    ((details.localPosition.dx -
                                                                35) /
                                                            (chartBox.maxWidth -
                                                                50) *
                                                            math.max(
                                                              1,
                                                              visible.length -
                                                                  1,
                                                            ))
                                                        .round()
                                                        .clamp(
                                                          0,
                                                          visible.length - 1,
                                                        );
                                                _select(
                                                  visible[i].id,
                                                  data,
                                                  rowHeight,
                                                  scroll: true,
                                                );
                                              },
                                              child: Semantics(
                                                label: ru
                                                    ? 'График попыток и среднего'
                                                    : 'Attempts and average chart',
                                                child: CustomPaint(
                                                  size: Size(
                                                    chartBox.maxWidth,
                                                    plotHeight,
                                                  ),
                                                  painter:
                                                      MyAttemptsChartPainter(
                                                        rows: visible,
                                                        allRows: data.rows,
                                                        numbers: {
                                                          for (final a
                                                              in visible)
                                                            a.id: data.numberOf(
                                                              a.id,
                                                            ),
                                                        },
                                                        averages: data.averages,
                                                        selected: _selected,
                                                        confirmed: data
                                                            .confirmed
                                                            .map((a) => a.id)
                                                            .toSet(),
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_expanded) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 7, 12, 2),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              currentAverage == null
                                  ? ''
                                  : '${ru ? 'Среднее' : 'Average'} ${_seconds(currentAverage, ru)} ${ru ? 'с' : 's'}',
                              key: const ValueKey(
                                'my-attempts-selected-average',
                              ),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 9),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if (data.averages.values.any(
                                (value) => value != null,
                              ))
                                _LegendMark(
                                  label: ru ? 'Среднее' : 'Average',
                                  average: true,
                                ),
                              _LegendMark(
                                label: ru ? 'Попытка' : 'Attempt',
                                average: false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(height: 1, color: _cyan.withValues(alpha: .6)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(
                  children: [
                    Flexible(
                      flex: 3,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${ru ? 'История' : 'History'} · ${data.serverHistory == null ? data.rows.length : '${data.serverHistory!.rows.length} / ${data.serverHistory!.totalCount}'}',
                          style: const TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        data.serverHistory != null
                            ? (ru ? 'Серверная история' : 'Server history')
                            : (ru ? 'На этом устройстве' : 'On this device'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              if (data.serverHistory == null &&
                  !data.historyComplete &&
                  data.ranking?.mine.totalAttempts != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 3),
                  child: Text(
                    ru
                        ? 'Подтверждено попыток: ${data.ranking!.mine.totalAttempts}. История устройства может быть неполной.'
                        : '${data.ranking!.mine.totalAttempts} confirmed attempts. Device history may be incomplete.',
                    key: const ValueKey('my-attempts-history-source'),
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ),
              Expanded(
                child: data.rows.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                store.historyError != null
                                    ? (ru
                                          ? 'История временно недоступна'
                                          : 'History temporarily unavailable')
                                    : store.historyLoading
                                    ? (ru
                                          ? 'Загружаем историю…'
                                          : 'Loading history…')
                                    : !store.localHistoryReadable
                                    ? (ru
                                          ? 'История на устройстве недоступна'
                                          : 'Device history unavailable')
                                    : (ru
                                          ? 'Ваши попытки будут здесь.\nПока нет результатов.'
                                          : 'Your attempts will appear here.\nNo results yet.'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                              if (store.historyError != null)
                                TextButton(
                                  key: const ValueKey(
                                    'my-attempts-history-retry',
                                  ),
                                  onPressed: store.historyLoading
                                      ? null
                                      : () => store.loadAttemptHistory(
                                          refresh: true,
                                        ),
                                  child: Text(
                                    ru ? 'Повторить' : 'Retry',
                                    style: const TextStyle(
                                      color: _cyan,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        key: const ValueKey('my-attempts-history'),
                        controller: _list,
                        padding: const EdgeInsets.fromLTRB(7, 1, 7, 4),
                        itemExtent: rowHeight,
                        itemCount:
                            data.rows.length +
                            (store.serverAttemptHistory?.nextCursor != null ||
                                    store.historyError != null
                                ? 1
                                : 0),
                        itemBuilder: (context, i) {
                          if (i == data.rows.length) {
                            return TextButton(
                              key: const ValueKey('my-attempts-load-more'),
                              onPressed: store.historyLoading
                                  ? null
                                  : () => store.loadAttemptHistory(
                                      more:
                                          store
                                              .serverAttemptHistory
                                              ?.nextCursor !=
                                          null,
                                    ),
                              child: Text(
                                store.historyLoading
                                    ? (ru ? 'Загружаем…' : 'Loading…')
                                    : store.historyError != null
                                    ? (ru
                                          ? 'Не удалось загрузить · Повторить'
                                          : 'Could not load · Retry')
                                    : (ru ? 'Загрузить ещё' : 'Load more'),
                                style: const TextStyle(
                                  color: _cyan,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          }
                          final a = data.rows[data.rows.length - 1 - i];
                          final n = data.numberOf(a.id) ?? 0;
                          final confirmed = data.confirmed.any(
                            (p) => p.id == a.id,
                          );
                          final status = confirmed
                              ? ''
                              : a.deliveryError != null
                              ? RoundDelivery.message(a.deliveryError!, ru: ru)
                              : store.isAttemptPending(a.id)
                              ? (ru ? 'Ожидает сети' : 'Waiting for network')
                              : (ru ? 'Локальная попытка' : 'Local attempt');
                          return _AttemptRow(
                            attempt: a,
                            number: n,
                            selected: a.id == _selected,
                            best: a.id == data.best?.id,
                            status: status,
                            ru: ru,
                            onTap: () => _select(a.id, data, rowHeight),
                            onDetail: () => _detail(a, store, n),
                          );
                        },
                      ),
              ),
              if (selectedOutside)
                TextButton(
                  key: const ValueKey('my-attempts-missing-record'),
                  onPressed: () =>
                      _detail(selected, store, data.numberOf(selected.id) ?? 0),
                  child: Text(
                    ru
                        ? 'Рекорд вне загруженной истории · Подробнее'
                        : 'Best outside loaded history · Details',
                    style: const TextStyle(fontSize: 10, color: _gold),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AttemptsInnerBorder extends Decoration {
  const _AttemptsInnerBorder();
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _AttemptsBorderPainter();
}

class _AttemptsBorderPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (offset & size).deflate(4),
        const Radius.circular(20),
      ),
      Paint()
        ..color = const Color(0x9931C9E7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
  }
}

class _LegendMark extends StatelessWidget {
  const _LegendMark({required this.label, required this.average});
  final String label;
  final bool average;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: average ? 18 : 5,
        height: average ? 3 : 10,
        child: ColoredBox(color: average ? _gold : _cyan),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
    ],
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.onTap,
    required this.valueKey,
    this.gold = false,
    this.trophy = false,
    this.info = false,
  });
  final String label, value, subtitle;
  final VoidCallback? onTap;
  final Key valueKey;
  final bool gold, info, trophy;
  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: valueKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: gold ? _gold : _cyan, width: 1.5),
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                gold ? const Color(0xFF42636B) : const Color(0xFF1A6684),
                const Color(0xFF052A43),
                const Color(0xFF021C31),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: (gold ? _gold : _cyan).withValues(alpha: .16),
                blurRadius: 9,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      if (trophy)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.emoji_events_rounded,
                            color: _gold,
                            size: 14,
                          ),
                        ),
                      Text(
                        label.replaceFirst(' ', '\n'),
                        style: TextStyle(
                          color: gold ? _gold : _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (info)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: gold ? _gold : _cyan,
                            size: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: gold ? const Color(0xFFFFF4A3) : _text,
                      fontSize: 23,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: gold ? const Color(0xFFE0D7AE) : _muted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({
    required this.attempt,
    required this.number,
    required this.selected,
    required this.best,
    required this.status,
    required this.ru,
    required this.onTap,
    required this.onDetail,
  });
  final LocalAttempt attempt;
  final int number;
  final bool selected, best, ru;
  final String status;
  final VoidCallback onTap, onDetail;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('my-attempt-${attempt.id}'),
        onTap: onTap,
        onLongPress: onDetail,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.only(left: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: _cyan)
                : const Border(bottom: BorderSide(color: Color(0xFF21627D))),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF145D78), Color(0xFF06304A)],
                  )
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  number > 0 ? '#$number' : '—',
                  style: const TextStyle(
                    color: Color(0xFF8AE4EE),
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _date(attempt.createdAt, ru),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _text, fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status.isNotEmpty
                          ? status
                          : '${ru ? 'Шаги' : 'Steps'} ${attempt.runDistance} · ${ru ? 'Риск' : 'Risk'} ${attempt.riskCount}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: status.isEmpty ? _muted : _gold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _seconds(attempt.timeMs, ru),
                        style: TextStyle(
                          color: best ? _gold : _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        ' ${ru ? 'с' : 's'}',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  key: ValueKey('my-attempt-detail-${attempt.id}'),
                  tooltip: ru ? 'Подробнее о попытке' : 'Attempt details',
                  onPressed: onDetail,
                  icon: const Icon(Icons.more_horiz, color: _muted, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MyAttemptsAverageHelp extends StatelessWidget {
  const MyAttemptsAverageHelp({
    super.key,
    required this.ranking,
    required this.historyComplete,
  });
  final AverageRanking? ranking;
  final bool historyComplete;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru',
        r = ranking;
    final known =
        r != null &&
        {
          AverageRanking.quadraticAlgorithm,
          AverageRanking.legacyAlgorithm,
        }.contains(r.algorithm);
    final rules = r == null
        ? (ru
              ? 'Правила среднего ещё не получены с сервера. Обновите историю при доступном соединении.'
              : 'Average rules have not arrived from the server yet. Refresh history when connected.')
        : !known
        ? (ru
              ? 'Среднее обновляется после подтверждения попытки. Чем оно выше, тем лучше.'
              : 'Your average updates after an attempt is confirmed. Higher is better.')
        : (ru
              ? 'Среднее показывает ваш текущий уровень игры в секундах.\n\n'
                    'Учитываем последние подтверждённые попытки. '
                    '${r.previousWeightPercent == 100 ? 'Все они имеют одинаковый вес.' : 'Свежие попытки влияют сильнее старых.'}\n\n'
                    '${r.isQuadratic ? 'Большие результаты влияют сильнее маленьких. Поэтому удачная длинная попытка заметнее повышает среднее.\n\n' : ''}'
                    'Среднее обновляется после подтверждения попытки. Чем оно выше, тем лучше.'
              : 'Average shows your current skill level in seconds.\n\n'
                    'We use your recent confirmed attempts. '
                    '${r.previousWeightPercent == 100 ? 'They all have equal weight.' : 'Recent attempts matter more than older ones.'}\n\n'
                    '${r.isQuadratic ? 'Higher results matter more than lower ones, so a good long attempt gives your average a bigger boost.\n\n' : ''}'
                    'Your average updates after an attempt is confirmed. Higher is better.');
    return Dialog(
      key: const ValueKey('my-attempts-average-help'),
      backgroundColor: const Color(0xFF052C43),
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _cyan, width: 2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ru ? 'Как считается среднее' : 'How average works',
                      style: const TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('my-attempts-help-close'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _cyan),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  key: const ValueKey('my-attempts-help-scroll'),
                  child: Text(
                    '$rules\n\n${ru ? 'Лучшая попытка — ваш отдельный рекорд за всё время.' : 'Your best attempt is a separate all-time record.'}',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const ValueKey('my-attempts-help-done'),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    ru ? 'Понятно' : 'Got it',
                    style: const TextStyle(color: _text),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyAttemptsChartPainter extends CustomPainter {
  const MyAttemptsChartPainter({
    required this.rows,
    required this.allRows,
    required this.averages,
    required this.selected,
    required this.confirmed,
    this.numbers = const {},
    this.referenceAverageMs,
  });
  final List<LocalAttempt> rows, allRows;
  final Map<String, double?> averages;
  final String? selected;
  final Set<String> confirmed;
  final Map<String, int?> numbers;
  final double? referenceAverageMs;
  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;
    const l = 35.0, right = 15.0, top = 9.0, bottom = 25.0;
    final width = size.width - l - right, height = size.height - top - bottom;
    var maximum = 5000.0;
    for (final a in rows) {
      maximum = math.max(
        maximum,
        math.max(a.timeMs.toDouble(), averages[a.id] ?? 0),
      );
    }
    maximum = (maximum / 5000).ceil() * 5000.0;
    double x(int i) =>
        l + (rows.length == 1 ? width / 2 : i * width / (rows.length - 1));
    double y(num ms) => top + height * (1 - ms / maximum);
    void text(String text, Offset at, {bool end = false}) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: _muted,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, at - Offset(end ? p.width : 0, p.height / 2));
    }

    for (var i = 0; i <= 5; i++) {
      final value = maximum * i / 5;
      canvas.drawLine(
        Offset(l, y(value)),
        Offset(size.width - right, y(value)),
        Paint()..color = const Color(0xFF17475E),
      );
      text(
        (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1),
        Offset(l - 7, y(value)),
        end: true,
      );
    }
    final path = Path();
    var hasPoint = false;
    for (var i = 0; i < rows.length; i++) {
      final a = rows[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x(i) - 1.5, y(a.timeMs), x(i) + 1.5, y(0)),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = a.id == selected
              ? const Color(0xFFC3FFFF)
              : confirmed.contains(a.id)
              ? const Color(0x9932E6F3)
              : const Color(0x667194A7),
      );
      final average = averages[a.id];
      if (average != null) {
        if (hasPoint) {
          path.lineTo(x(i), y(average));
        } else {
          path.moveTo(x(i), y(average));
          hasPoint = true;
        }
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _gold
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    final index = rows.indexWhere((a) => a.id == selected);
    if (index >= 0) {
      canvas.drawLine(
        Offset(x(index), top),
        Offset(x(index), y(0)),
        Paint()
          ..color = const Color(0x66B2DDEC)
          ..strokeWidth = 1,
      );
      final average = averages[selected];
      if (average != null) {
        canvas.drawCircle(
          Offset(x(index), y(average)),
          4,
          Paint()..color = _gold,
        );
      }
    }
    for (final i in {0, (rows.length - 1) ~/ 2, rows.length - 1}) {
      text(
        numbers.containsKey(rows[i].id)
            ? (numbers[rows[i].id]?.toString() ?? '—')
            : '${allRows.indexWhere((a) => a.id == rows[i].id) + 1}',
        Offset(x(i), size.height - 10),
        end: i == rows.length - 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MyAttemptsChartPainter oldDelegate) => true;
}
