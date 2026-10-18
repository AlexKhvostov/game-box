import 'package:flutter/material.dart';

/// Folder tabs share one contour with the content below. The selected tab has
/// an open lower edge; the inactive one is recessed, even without colour.
class RankingTabs extends StatelessWidget {
  const RankingTabs({
    super.key,
    required this.average,
    required this.onRecord,
    required this.onAverage,
  });
  final bool average;
  final VoidCallback onRecord, onAverage;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final height = MediaQuery.textScalerOf(context).scale(12) > 18
        ? 58.0
        : 44.0;
    Widget tab(String label, bool selected, VoidCallback action, Key key) =>
        Expanded(
          child: Semantics(
            selected: selected,
            button: true,
            child: InkWell(
              key: key,
              onTap: action,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? const Color(0xFFFFEE85)
                        : const Color(0xFFAACBE0),
                  ),
                ),
              ),
            ),
          ),
        );
    return CustomPaint(
      painter: _TabContour(average: average),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            tab(
              ru ? 'Рекорд' : 'Record',
              !average,
              onRecord,
              const ValueKey('leaderboard-tab-record'),
            ),
            tab(
              ru ? 'Средние' : 'Averages',
              average,
              onAverage,
              const ValueKey('leaderboard-filter-6'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabContour extends CustomPainter {
  const _TabContour({required this.average});
  final bool average;
  @override
  void paint(Canvas canvas, Size size) {
    final half = size.width / 2;
    for (final selected in [false, true]) {
      final index = (selected == average) ? 1 : 0;
      final left = index * half + .5, right = (index + 1) * half - .5;
      final top = selected ? 10.0 : 14.0;
      final path = Path()
        ..moveTo(left, size.height)
        ..lineTo(left, top + 8)
        ..quadraticBezierTo(left, top, left + 8, top)
        ..lineTo(right - 8, top)
        ..quadraticBezierTo(right, top, right, top + 8)
        ..lineTo(right, size.height);
      canvas.drawPath(
        path,
        Paint()
          ..color = selected
              ? const Color(0xFF04283C)
              : const Color(0xFF021C30),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = selected
              ? const Color(0xFFB5B77A)
              : const Color(0xFF145570),
      );
      if (!selected) {
        canvas.drawLine(
          Offset(left, size.height - .5),
          Offset(right, size.height - .5),
          Paint()..color = const Color(0xFF197997),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TabContour oldDelegate) => oldDelegate.average != average;
}
