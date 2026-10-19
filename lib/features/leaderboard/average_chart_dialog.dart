import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/scores_store.dart';
import '../../domain/average_chart.dart';
import '../../ui/game_ui.dart';

Future<void> showAverageChartDialog(BuildContext context, ScoresStore store) =>
    showDialog<void>(
      context: context,
      barrierColor: GameUi.modalBarrier,
      animationStyle: GameUi.windowAnimationStyle,
      builder: (_) => AverageChartDialog(store: store),
    );

String _seconds(double ms, bool ru) {
  final value = (ms / 1000).toStringAsFixed(3);
  return ru ? value.replaceAll('.', ',') : value;
}

class AverageChartDialog extends StatelessWidget {
  const AverageChartDialog({super.key, required this.store});
  final ScoresStore store;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.4,
      child: Dialog(
        key: const ValueKey('average-chart-dialog'),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF39DDEB), width: 2),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF07314A),
                  Color(0xFF011828),
                  Color(0xFF062E45),
                ],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x3300D5FF), blurRadius: 12),
              ],
            ),
            child: AnimatedBuilder(
              animation: store,
              builder: (context, _) {
                final board = store.averageRanking;
                final data = board == null || !store.localHistoryReadable
                    ? null
                    : AverageChartData.fromAttempts(
                        attempts: store.myAttempts,
                        ranking: board,
                        isPending: store.isAttemptPending,
                      );
                return SingleChildScrollView(
                  key: const ValueKey('average-chart-scroll'),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ru ? 'Средний результат' : 'Average result',
                                  style: const TextStyle(
                                    color: GameUi.text,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data == null || data.points.isEmpty
                                      ? (ru
                                            ? 'История попыток'
                                            : 'Attempt history')
                                      : (ru
                                            ? 'Последние ${data.points.length} сохранённых попыток'
                                            : 'Last ${data.points.length} saved attempts'),
                                  style: const TextStyle(
                                    color: GameUi.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('average-chart-close'),
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonLabel,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: GameUi.cyan,
                            ),
                          ),
                        ],
                      ),
                      if (data?.averageMs != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.show_chart_rounded,
                              color: GameUi.yellow,
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                '${_seconds(data!.averageMs!, ru)} ${ru ? 'с' : 's'}',
                                key: const ValueKey('average-chart-value'),
                                style: const TextStyle(
                                  color: GameUi.text,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (data == null || data.points.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            board == null
                                ? (ru
                                      ? 'Данные среднего пока недоступны. Обновите рейтинг и откройте график снова.'
                                      : 'Average data is unavailable. Refresh the ranking and reopen the chart.')
                                : (ru
                                      ? 'На этом устройстве пока нет подтверждённых попыток. Они появятся здесь после игры и сохранения в рейтинг.'
                                      : 'No confirmed attempts on this device yet. Play and save a result to see it here.'),
                            key: const ValueKey('average-chart-empty'),
                            style: const TextStyle(
                              color: GameUi.muted,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      if (data != null && data.points.isNotEmpty)
                        AverageChartView(
                          key: ValueKey(
                            'average-chart-${store.account?.id ?? "local"}',
                          ),
                          data: data,
                          ru: ru,
                        ),
                      if (data != null && data.points.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ChartLegend(ru: ru),
                        const SizedBox(height: 10),
                        Text(
                          ru
                              ? 'Линия — ${board!.isQuadratic ? "среднее квадратичное" : "среднее"} после каждой попытки, с весами по давности. ${board.minDurationMs == 0 ? "Короткие попытки тоже учитываются" : "Учитываются попытки дольше ${_seconds(board.minDurationMs.toDouble(), ru)} с"}'
                              : 'Line: ${board!.isQuadratic ? "weighted root mean square" : "weighted average"} after each attempt. ${board.minDurationMs == 0 ? "Short attempts also count" : "Only attempts longer than ${_seconds(board.minDurationMs.toDouble(), ru)} s count"}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: GameUi.muted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                        if (!data.historyComplete)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              ru
                                  ? 'График рассчитан по подтверждённой истории этого устройства. Полная история может отличаться.${board.mine.averageMs == null ? "" : " Среднее в рейтинге: ${_seconds(board.mine.averageMs!, ru)} с."}'
                                  : 'The chart uses this device’s confirmed history. Full history may differ.${board.mine.averageMs == null ? "" : " Ranking average: ${_seconds(board.mine.averageMs!, ru)} s."}',
                              key: const ValueKey('average-chart-partial'),
                              style: const TextStyle(
                                color: GameUi.muted,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                      ],
                      if ((data?.awaitingCount ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            ru
                                ? 'Ожидают подтверждения: ${data!.awaitingCount}'
                                : 'Awaiting confirmation: ${data!.awaitingCount}',
                            style: const TextStyle(
                              color: GameUi.muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      if (!store.online)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            ru
                                ? 'Без сети · сохранённая история'
                                : 'Offline · saved history',
                            style: const TextStyle(
                              color: GameUi.muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class AverageChartView extends StatefulWidget {
  const AverageChartView({super.key, required this.data, required this.ru});
  final AverageChartData data;
  final bool ru;
  @override
  State<AverageChartView> createState() => _AverageChartViewState();
}

class _AverageChartViewState extends State<AverageChartView> {
  int? _selected;
  final _horizontal = ScrollController();
  bool _positioned = false;
  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.data.points;
    final selected = (_selected ?? points.length - 1).clamp(
      0,
      points.length - 1,
    );
    final point = points[selected], ru = widget.ru;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                ru
                    ? 'На графике: ${points.length} попыток'
                    : 'Shown: ${points.length} attempts',
                style: const TextStyle(color: GameUi.muted, fontSize: 11),
              ),
              Text(
                ru
                    ? 'В расчёте — последние ${widget.data.currentWindowCount}'
                    : 'In current average: last ${widget.data.currentWindowCount}',
                key: const ValueKey('average-chart-window'),
                style: const TextStyle(
                  color: GameUi.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
          decoration: BoxDecoration(
            color: const Color(0x55001A2B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF155877)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  ru ? 'Время, мин:сек' : 'Time, min:sec',
                  style: const TextStyle(color: GameUi.muted, fontSize: 11),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.max(
                    constraints.maxWidth,
                    points.length * 5.0 + 60,
                  );
                  final textScale =
                      (MediaQuery.textScalerOf(context).scale(11) / 11).clamp(
                        1.0,
                        1.5,
                      );
                  if (!_positioned) {
                    _positioned = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _horizontal.hasClients) {
                        _horizontal.jumpTo(
                          _horizontal.position.maxScrollExtent,
                        );
                      }
                    });
                  }
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        key: const ValueKey('average-chart-horizontal'),
                        controller: _horizontal,
                        scrollDirection: Axis.horizontal,
                        child: Focus(
                          onKeyEvent: (_, event) {
                            if (event is! KeyDownEvent) {
                              return KeyEventResult.ignored;
                            }
                            final step =
                                event.logicalKey ==
                                    LogicalKeyboardKey.arrowRight
                                ? 1
                                : event.logicalKey ==
                                      LogicalKeyboardKey.arrowLeft
                                ? -1
                                : 0;
                            if (step == 0) return KeyEventResult.ignored;
                            setState(
                              () => _selected = (selected + step).clamp(
                                0,
                                points.length - 1,
                              ),
                            );
                            return KeyEventResult.handled;
                          },
                          child: GestureDetector(
                            key: const ValueKey('average-chart-plot'),
                            onTapDown: (details) {
                              final index =
                                  ((details.localPosition.dx - 44) /
                                          (width - 56) *
                                          points.length)
                                      .floor()
                                      .clamp(0, points.length - 1);
                              setState(() => _selected = index);
                            },
                            child: Semantics(
                              label: ru
                                  ? 'График попыток и среднего'
                                  : 'Attempts and average chart',
                              value:
                                  '${selected + 1}: ${_seconds(point.attempt.timeMs.toDouble(), ru)}',
                              child: CustomPaint(
                                size: Size(width, 230 * textScale),
                                painter: _AveragePainter(
                                  points: points,
                                  selected: selected,
                                  textScale: textScale,
                                  ru: ru,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size(44, 230 * textScale),
                          painter: _AveragePainter(
                            points: points,
                            selected: selected,
                            textScale: textScale,
                            ru: ru,
                            axisOnly: true,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Text(
                ru ? 'Попытки · нажмите на столбик' : 'Attempts · tap a bar',
                textAlign: TextAlign.center,
                style: const TextStyle(color: GameUi.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              ru
                  ? 'Попытка ${selected + 1}: ${_seconds(point.attempt.timeMs.toDouble(), ru)} с'
                  : 'Attempt ${selected + 1}: ${_seconds(point.attempt.timeMs.toDouble(), ru)} s',
              key: const ValueKey('average-chart-selection'),
              style: const TextStyle(color: GameUi.text, fontSize: 12),
            ),
            Text(
              '${ru ? "Среднее" : "Average"}: ${point.averageMs == null ? "—" : _seconds(point.averageMs!, ru)} ${ru ? "с" : "s"}',
              style: const TextStyle(
                color: GameUi.yellow,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.ru});
  final bool ru;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF176C88)),
    ),
    child: Wrap(
      spacing: 18,
      runSpacing: 10,
      children: [
        _item(const Color(0xFF36ECF2), ru ? 'Попытка ≥ 1 с' : 'Attempt ≥ 1 s'),
        _item(const Color(0xFF7B91A5), ru ? 'Короче 1 с' : 'Under 1 s'),
        _item(GameUi.yellow, ru ? 'Среднее' : 'Average', line: true),
      ],
    ),
  );
  Widget _item(Color color, String label, {bool line = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: line ? 22 : 10,
        height: line ? 3 : 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(color: GameUi.text, fontSize: 11)),
    ],
  );
}

class _AveragePainter extends CustomPainter {
  const _AveragePainter({
    required this.points,
    required this.selected,
    required this.textScale,
    required this.ru,
    this.axisOnly = false,
  });
  final List<AverageChartPoint> points;
  final int selected;
  final double textScale;
  final bool ru;
  final bool axisOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(44, 14, size.width - 12, size.height - 30);
    final maxMs = points.fold<double>(
      1000,
      (v, p) =>
          math.max(v, math.max(p.attempt.timeMs.toDouble(), p.averageMs ?? 0)),
    );
    final rawStep = math.max(1000.0, maxMs / 4);
    final magnitude = math
        .pow(10, (math.log(rawStep) / math.ln10).floor())
        .toDouble();
    final normalized = rawStep / magnitude;
    final step =
        (normalized <= 1
            ? 1
            : normalized <= 2
            ? 2
            : normalized <= 5
            ? 5
            : 10) *
        magnitude;
    final top = step * 4;
    double x(int i) => plot.left + plot.width * (i + .5) / points.length;
    double y(double ms) => plot.bottom - plot.height * ms / top;
    void label(String text, Offset offset, {bool right = false}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: GameUi.muted,
            fontSize: 10 * textScale,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        offset -
            Offset(
              right ? painter.width : painter.width / 2,
              painter.height / 2,
            ),
      );
    }

    final grid = Paint()
      ..color = const Color(0xFF19556E)
      ..strokeWidth = .7;
    if (axisOnly) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF032132),
      );
      for (var i = 0; i <= 4; i++) {
        final ms = step * i, sec = (ms / 1000).round();
        label(
          '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, "0")}',
          Offset(plot.left - 6, y(ms)),
          right: true,
        );
      }
      canvas.drawLine(plot.bottomLeft, plot.topLeft, grid);
      return;
    }
    final firstActive = points.indexWhere((p) => p.inCurrentWindow);
    if (firstActive >= 0) {
      final start = plot.left + plot.width * firstActive / points.length;
      canvas.drawRect(
        Rect.fromLTRB(start, plot.top, plot.right, plot.bottom),
        Paint()..color = const Color(0x1422E5D9),
      );
      for (var yy = plot.top; yy < plot.bottom; yy += 9) {
        canvas.drawLine(
          Offset(start, yy),
          Offset(start, math.min(yy + 4, plot.bottom)),
          Paint()
            ..color = const Color(0xAA56E7E9)
            ..strokeWidth = 1,
        );
      }
    }
    for (var i = 0; i <= 4; i++) {
      final ms = step * i, yy = y(ms);
      for (var xx = plot.left; xx < plot.right; xx += 7) {
        canvas.drawLine(
          Offset(xx, yy),
          Offset(math.min(xx + 3, plot.right), yy),
          grid,
        );
      }
      final sec = (ms / 1000).round();
      label(
        '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, "0")}',
        Offset(plot.left - 6, yy),
        right: true,
      );
    }
    canvas.drawLine(plot.bottomLeft, plot.topLeft, grid);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, grid);
    final barWidth = math.min(27.0, plot.width / points.length * .55);
    for (var i = 0; i < points.length; i++) {
      final point = points[i], short = point.attempt.timeMs < 1000;
      final alpha = point.inCurrentWindow ? 1.0 : .32;
      final rect = Rect.fromLTRB(
        x(i) - barWidth / 2,
        math.min(plot.bottom - 2, y(point.attempt.timeMs.toDouble())),
        x(i) + barWidth / 2,
        plot.bottom,
      );
      final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      final color = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:
              (short
                      ? const [Color(0xFF9CAFC0), Color(0xFF5F788D)]
                      : const [Color(0xFF64FBF5), Color(0xFF00A8CD)])
                  .map((c) => c.withValues(alpha: alpha))
                  .toList(),
        ).createShader(rect);
      canvas.drawRRect(rounded, color);
      canvas.drawRRect(
        rounded,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == selected ? 2 : 1
          ..color = i == selected
              ? const Color(0xFFDAFFFF)
              : short
              ? const Color(0xFFADC3D6)
              : const Color(0xFF52F7F4),
      );
      final labelEvery = math.max(1, (points.length / 6).ceil());
      if (i == 0 || i == points.length - 1 || (i + 1) % labelEvery == 0) {
        label('${i + 1}', Offset(x(i), plot.bottom + 16));
      }
    }
    final path = Path();
    var begun = false;
    for (var i = 0; i < points.length; i++) {
      final average = points[i].averageMs;
      if (average == null) continue;
      if (!begun) {
        path.moveTo(x(i), y(average));
        begun = true;
      } else {
        path.lineTo(x(i), y(average));
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x44FFE56B)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFE56B)
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < points.length; i++) {
      if (points[i].averageMs == null) continue;
      canvas.drawCircle(
        Offset(x(i), y(points[i].averageMs!)),
        i == selected ? 4 : 2.8,
        Paint()..color = const Color(0xFFFFE56B),
      );
    }
  }

  @override
  bool shouldRepaint(_AveragePainter oldDelegate) =>
      points != oldDelegate.points ||
      selected != oldDelegate.selected ||
      textScale != oldDelegate.textScale ||
      ru != oldDelegate.ru ||
      axisOnly != oldDelegate.axisOnly;
}
