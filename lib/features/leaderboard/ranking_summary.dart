import 'package:flutter/material.dart';

/// A small informational strip, with a wrapping accessibility layout.
class RankingSummary extends StatelessWidget {
  const RankingSummary({super.key, required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(10) > 15;
    final children = items
        .map(
          (text) => Text(
            text,
            style: const TextStyle(
              color: Color(0xFFFFEEA2),
              fontSize: 10,
              height: 1.25,
            ),
          ),
        )
        .toList();
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      margin: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x1819B6A4),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0x665F9F89)),
      ),
      foregroundDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFFFEE85), width: 2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          var width = 0.0;
          for (final text in items) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: const TextStyle(fontSize: 10)),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            width += painter.width;
            painter.dispose();
          }
          return large || width + 12 > constraints.maxWidth
              ? Wrap(spacing: 14, runSpacing: 4, children: children)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: children,
                );
        },
      ),
    );
  }
}

class RankingOwnDivider extends StatelessWidget {
  const RankingOwnDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
    child: Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFF376171))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            Localizations.localeOf(context).languageCode == 'ru'
                ? 'Ваше место'
                : 'Your place',
            style: const TextStyle(fontSize: 9, color: Color(0xFFC4DEE9)),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFF376171))),
      ],
    ),
  );
}
