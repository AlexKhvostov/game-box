import 'package:flutter/material.dart';
import '../../data/scores_store.dart';
import '../../ui/public_name_controls.dart';
import '../../domain/average_ranking.dart';
import '../../ui/game_ui.dart';
import 'leaderboard_tone.dart';
import 'ranking_art.dart';
import 'ranking_summary.dart';
import 'average_chart_dialog.dart';

String averageSeconds(double? ms) =>
    ms == null ? '—' : (ms / 1000).toStringAsFixed(3);

class AverageRankingPanel extends StatelessWidget {
  const AverageRankingPanel({super.key, required this.store});
  final ScoresStore store;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final board = store.averageRanking;
    final threshold = board == null
        ? ''
        : (board.minDurationMs / 1000)
              .toStringAsFixed(3)
              .replaceFirst(RegExp(r'\.?0+$'), '');
    final formulaExplanation = board?.isQuadratic == true
        ? (ru
              ? 'Используется среднее квадратичное: сильные попытки влияют заметнее. '
              : 'Uses a weighted root mean square: stronger attempts matter more. ')
        : '';
    final explanation =
        formulaExplanation +
        (ru
            ? '${board == null
                  ? "Среднее время последних попыток."
                  : board.minDurationMs == 0
                  ? "Среднее время последних ${board.windowSize} попыток, включая короткие. В рейтинге — с первой попытки."
                  : "Среднее время последних ${board.windowSize} попыток дольше $threshold с."} Свежие результаты влияют сильнее, поэтому показатель отражает текущий уровень игры. Чем выше среднее, тем выше место.'
            : '${board == null
                  ? "Average time of your latest attempts."
                  : board.minDurationMs == 0
                  ? "Average time of your last ${board.windowSize} attempts, including short runs. Ranked from your first attempt."
                  : "Average time of your last ${board.windowSize} attempts longer than $threshold s."} Recent results matter more, so this reflects your current skill. A higher average means a higher rank.');
    final rows =
        board?.rows.where((r) => (r.place ?? 201) <= 200).take(200).toList() ??
        <AverageRankEntry>[];
    final own = board?.mine;
    final outside = own?.place != null && own!.place! > 200;
    final text = LeaderboardTone.text(context),
        muted = LeaderboardTone.muted(context);
    final headers = <Widget>[
      Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                ru
                    ? 'Рейтинг по среднему времени'
                    : 'Ranking by average attempt time',
                style: TextStyle(
                  color: text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('average-chart-open'),
              onPressed: () => showAverageChartDialog(context, store),
              style: TextButton.styleFrom(
                foregroundColor: GameUi.cyan,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 44),
              ),
              icon: const Icon(Icons.show_chart_rounded, size: 18),
              label: Text(
                ru ? 'График' : 'Chart',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            _AverageInfoButton(message: explanation, ru: ru),
          ],
        ),
      ),
      if (store.loading) const LinearProgressIndicator(minHeight: 2),
      if (!store.online && board != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            ru ? 'Без сети · сохранённое среднее' : 'Offline · saved average',
            style: TextStyle(color: muted, fontSize: 10),
          ),
        ),
      if (board != null) ...[
        RankingSummary(
          key: const ValueKey('average-personal-summary'),
          items: [
            '${ru ? "Ваше среднее" : "Your average"}: ${averageSeconds(own!.averageMs)} ${ru ? "с" : "s"}',
            '${ru ? "Место" : "Place"}: ${own.place ?? "—"}',
            '${ru ? "Попыток" : "Attempts"}: ${own.totalAttempts ?? "—"}',
          ],
        ),
        if (own.place == null && board.minAttempts > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Text(
              ru
                  ? 'Предварительно · ${own.eligibleCount}/${board.minAttempts} попыток для допуска'
                  : 'Provisional · ${own.eligibleCount}/${board.minAttempts} qualifying attempts',
              style: TextStyle(fontSize: 10, color: muted),
            ),
          ),
        const _AverageColumns(),
      ],
    ];
    final count = board == null || rows.isEmpty
        ? 1
        : rows.length + (outside ? 2 : 0);
    Widget buildRow(BuildContext context, int i) {
      if (board == null) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(
                store.loading
                    ? (ru ? 'Загружаем среднее…' : 'Loading average…')
                    : (ru
                          ? 'Среднее временно недоступно'
                          : 'Average temporarily unavailable'),
                style: TextStyle(color: text),
              ),
              if (!store.loading)
                TextButton(
                  onPressed: store.load,
                  child: Text(ru ? 'Повторить' : 'Retry'),
                ),
            ],
          ),
        );
      }
      if (rows.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            ru
                ? board.minAttempts == 1
                      ? 'Сыграйте первую попытку — здесь появится ваше среднее'
                      : 'Пока нет игроков с ${board.minAttempts} подходящими попытками'
                : board.minAttempts == 1
                ? 'Play your first run to see your average here'
                : 'No player has ${board.minAttempts} qualifying attempts yet',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
        );
      }
      if (outside && i == rows.length) {
        return const RankingOwnDivider();
      }
      final row = i < rows.length ? rows[i] : own!;
      return _AverageRow(
        key: ValueKey('average-row-${row.place}'),
        row: row,
        own: i >= rows.length || row.userId == store.account?.id,
        ru: ru,
      );
    }

    final large = MediaQuery.textScalerOf(context).scale(12) > 18;
    if (large) {
      return RefreshIndicator(
        onRefresh: store.load,
        child: CustomScrollView(
          key: const PageStorageKey('ranking-average'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: headers,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  buildRow,
                  childCount: count,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...headers,
        Expanded(
          child: RefreshIndicator(
            onRefresh: store.load,
            child: ListView.builder(
              key: const PageStorageKey('ranking-average'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              itemCount: count,
              itemBuilder: buildRow,
            ),
          ),
        ),
      ],
    );
  }
}

class AverageHistoryCard extends StatelessWidget {
  const AverageHistoryCard({super.key, required this.store});
  final ScoresStore store;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final board = store.averageRanking, own = board?.mine;
    return Container(
      key: const ValueKey('attempts-average-card'),
      margin: const EdgeInsets.fromLTRB(4, 5, 4, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF073849),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF5FBCB9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ru ? "Среднее время" : "Average time"}   ${averageSeconds(own?.averageMs)} ${ru ? "с" : "s"}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFEE85),
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 18,
            runSpacing: 4,
            children: [
              Text(
                '${ru ? "Место" : "Place"}: ${own?.place ?? "—"}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFC4E5ED)),
              ),
              Text(
                '${ru ? "Всего попыток" : "Total attempts"}: ${own?.totalAttempts ?? "—"}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFC4E5ED)),
              ),
            ],
          ),
          if (own != null && own.place == null)
            Text(
              ru
                  ? 'Для допуска: ${own.eligibleCount}/${board!.minAttempts} подходящих попыток'
                  : 'To qualify: ${own.eligibleCount}/${board!.minAttempts} attempts',
              style: const TextStyle(fontSize: 10, color: Color(0xFFC4E5ED)),
            ),
          if (!store.online)
            Text(
              ru ? 'Без сети · сохранённые данные' : 'Offline · saved data',
              style: const TextStyle(fontSize: 10, color: Color(0xFFC4E5ED)),
            ),
        ],
      ),
    );
  }
}

class _AverageColumns extends StatelessWidget {
  const _AverageColumns();
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    Widget label(String value, {double? width}) => SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: width == null ? TextAlign.start : TextAlign.center,
        style: const TextStyle(fontSize: 8, color: Color(0xFFA4CDEF)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 2, 5, 4),
      child: Row(
        children: [
          label('#', width: 32),
          Expanded(child: label(ru ? 'Игрок' : 'Player')),
          label(ru ? 'Среднее время' : 'Average time', width: 82),
          label(ru ? 'Всего\nпопыток' : 'Total\nattempts', width: 52),
        ],
      ),
    );
  }
}

class _AverageInfoButton extends StatefulWidget {
  const _AverageInfoButton({required this.message, required this.ru});
  final String message;
  final bool ru;
  @override
  State<_AverageInfoButton> createState() => _AverageInfoButtonState();
}

class _AverageInfoButtonState extends State<_AverageInfoButton> {
  final _tip = GlobalKey<TooltipState>();
  void _showInfo() {
    if (MediaQuery.textScalerOf(context).scale(12) > 18) {
      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: GameUi.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: GameUi.cyan),
          ),
          content: SingleChildScrollView(
            key: const ValueKey('average-info-scroll'),
            child: Text(
              widget.message,
              style: const TextStyle(
                color: GameUi.text,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: Text(MaterialLocalizations.of(c).closeButtonLabel),
            ),
          ],
        ),
      );
    } else {
      _tip.currentState?.ensureTooltipVisible();
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    key: _tip,
    message: widget.message,
    triggerMode: TooltipTriggerMode.manual,
    showDuration: const Duration(seconds: 12),
    preferBelow: true,
    constraints: const BoxConstraints(maxWidth: 280),
    padding: const EdgeInsets.all(12),
    textStyle: const TextStyle(
      fontFamily: 'Roboto',
      color: GameUi.text,
      fontSize: 12,
      height: 1.35,
    ),
    decoration: BoxDecoration(
      color: GameUi.ink,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: GameUi.cyan),
    ),
    child: Semantics(
      label: widget.ru ? 'О рейтинге по среднему' : 'About average ranking',
      child: IconButton(
        key: const ValueKey('average-ranking-info'),
        onPressed: _showInfo,
        icon: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GameUi.cyan),
          ),
          child: const Text(
            'i',
            style: TextStyle(
              color: GameUi.cyan,
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

class _AverageRow extends StatelessWidget {
  const _AverageRow({
    super.key,
    required this.row,
    required this.own,
    required this.ru,
  });
  final AverageRankEntry row;
  final bool own, ru;
  @override
  Widget build(BuildContext context) {
    final place = row.place;
    final large = MediaQuery.textScalerOf(context).scale(11) > 16.5;
    final value = Text(
      '${averageSeconds(row.averageMs)} ${ru ? "с" : "s"}',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: own ? const Color(0xFFFFEE85) : const Color(0xFFF2F8FF),
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
    final count = Text(
      '${row.totalAttempts ?? "—"}',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFE4F3FF),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
    return GestureDetector(
      onTap: own
          ? null
          : () => showPublicNameActions(
              context,
              uid: row.userId,
              name: row.playerName,
            ),
      child: Semantics(
        button: !own && row.userId != null,
        hint: own
            ? null
            : (ru
                  ? 'Нажмите, чтобы пожаловаться или скрыть имя'
                  : 'Tap to report or hide this name'),
        label: ru
            ? 'Место $place. ${publicPlayerName(context, row.userId, row.playerName)}. Среднее ${averageSeconds(row.averageMs)} с. Всего попыток ${row.totalAttempts ?? "—"}.'
            : 'Place $place. ${publicPlayerName(context, row.userId, row.playerName)}. Average ${averageSeconds(row.averageMs)} s. Total attempts ${row.totalAttempts ?? "—"}.',
        child: Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          constraints: const BoxConstraints(minHeight: 49),
          decoration: BoxDecoration(
            color: own ? const Color(0xFF03454D) : null,
            borderRadius: BorderRadius.circular(6),
            border: own
                ? Border.all(color: const Color(0xFF71FFF0))
                : const Border(bottom: BorderSide(color: Color(0xFF174456))),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: place != null && place <= 3
                    ? RankingArt('medal-$place', width: 28, height: 32)
                    : Text(
                        '$place',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: own
                              ? const Color(0xFFADFFF1)
                              : const Color(0xFFA9D8EE),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      publicPlayerName(context, row.userId, row.playerName),
                      maxLines: large ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF2F8FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (large) ...[
                      value,
                      Text(
                        '${ru ? "Попыток" : "Attempts"}: ${row.totalAttempts ?? "—"}',
                        style: const TextStyle(
                          color: Color(0xFFE4F3FF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!large) ...[
                SizedBox(width: 82, child: value),
                SizedBox(width: 52, child: count),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
