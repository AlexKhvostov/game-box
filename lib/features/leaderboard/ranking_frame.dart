import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'leaderboard_tone.dart';
import 'ranking_art.dart';

/// Compact native host for ranking A. Only the ranking list scrolls.
class RankingFrame extends StatelessWidget {
  const RankingFrame({
    super.key,
    required this.child,
    this.title,
    this.onMyAttempts,
  });
  final Widget child;
  final String? title;
  final VoidCallback? onMyAttempts;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(12) / 12;
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 8, 10, media.padding.bottom + 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: SizedBox(
            width: math.min(constraints.maxWidth, 400),
            height: math.min(
              550 * scale.clamp(1, 1.35),
              math.min(
                constraints.maxHeight,
                media.size.height -
                    media.padding.top -
                    media.padding.bottom -
                    24,
              ),
            ),
            child: LeaderboardTone(
              child: RepaintBoundary(
                key: const ValueKey('ranking-frame'),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF042C48), Color(0xFF001326)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x85009DFF),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Color(0x99000512),
                        blurRadius: 25,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    foregroundPainter: const _RankingFramePainter(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: Row(
                              children: [
                                const RankingArt(
                                  'trophy',
                                  width: 27,
                                  height: 30,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    title ??
                                        AppLocalizations.of(
                                          context,
                                        ).leaderboardTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFF2F8FF),
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x99008AFF),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (onMyAttempts != null)
                                  TextButton(
                                    key: const ValueKey('ranking-my-attempts'),
                                    onPressed: onMyAttempts,
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFC4F1FF),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      minimumSize: const Size(48, 48),
                                    ),
                                    child: Text(
                                      Localizations.localeOf(
                                                context,
                                              ).languageCode ==
                                              'ru'
                                          ? 'Мои попытки'
                                          : 'My attempts',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                IconButton(
                                  key: const ValueKey('ranking-close'),
                                  tooltip: MaterialLocalizations.of(
                                    context,
                                  ).closeButtonTooltip,
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF7BE7FF),
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(child: child),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingFramePainter extends CustomPainter {
  const _RankingFramePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    for (final (inset, color, width) in const [
      (0.7, Color(0xFF00DBFF), 1.3),
      (3.5, Color(0xFF2CE7FF), 1.0),
      (6.0, Color(0xFF158ABB), 0.8),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(inset),
          Radius.circular(22 - inset),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color,
      );
    }
    for (final y in [4.0, size.height - 4]) {
      final line = Rect.fromLTWH(size.width * .25, y, size.width * .5, 1.2);
      canvas.drawRect(
        line,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x002CE7FF), Color(0xFFE6FFFF), Color(0x002CE7FF)],
          ).createShader(line),
      );
    }
  }

  @override
  bool shouldRepaint(_RankingFramePainter oldDelegate) => false;
}
