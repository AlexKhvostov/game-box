import 'package:flutter/material.dart';

/// Всплывающая подсказка возле якоря (как мини-уведомление).
/// Тап по затемнению снаружи закрывает.
class InfoTipBubble extends StatelessWidget {
  const InfoTipBubble({
    super.key,
    required this.anchorKey,
    required this.body,
    required this.accent,
    required this.onDismiss,
    this.footnote,
    this.maxWidth = 260,
  });

  final GlobalKey anchorKey;
  final String body;
  final String? footnote;
  final Color accent;
  final VoidCallback onDismiss;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || overlayBox == null || !overlayBox.hasSize) {
      return const SizedBox.shrink();
    }

    final anchorTopLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final anchorSize = box.size;
    final overlaySize = overlayBox.size;
    final tipWidth = maxWidth.clamp(160.0, overlaySize.width - 24);

    // Предпочитаем под блоком; если места мало — над ним.
    const estimatedHeight = 120.0;
    final spaceBelow = overlaySize.height - (anchorTopLeft.dy + anchorSize.height);
    final showBelow = spaceBelow >= estimatedHeight + 8;

    var left = anchorTopLeft.dx + anchorSize.width / 2 - tipWidth / 2;
    left = left.clamp(12.0, overlaySize.width - tipWidth - 12);

    final top = showBelow
        ? anchorTopLeft.dy + anchorSize.height + 8
        : (anchorTopLeft.dy - estimatedHeight - 8).clamp(8.0, overlaySize.height);

    // Стрелка к центру якоря
    final arrowX = (anchorTopLeft.dx + anchorSize.width / 2 - left)
        .clamp(16.0, tipWidth - 16);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.28),
            ),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: tipWidth,
          child: GestureDetector(
            onTap: () {}, // не закрывать по тапу на саму плашку
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showBelow)
                    Align(
                      alignment: Alignment(-1 + 2 * (arrowX / tipWidth), 0),
                      child: CustomPaint(
                        size: const Size(14, 8),
                        painter: _ArrowPainter(
                          color: const Color(0xFF1A242C),
                          border: accent.withValues(alpha: 0.55),
                          up: true,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(accent, const Color(0xFF1A242C), 0.82)!,
                          const Color(0xFF12181E),
                        ],
                      ),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_rounded,
                              size: 16,
                              color: accent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                body,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (footnote != null && footnote!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            footnote!,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!showBelow)
                    Align(
                      alignment: Alignment(-1 + 2 * (arrowX / tipWidth), 0),
                      child: CustomPaint(
                        size: const Size(14, 8),
                        painter: _ArrowPainter(
                          color: const Color(0xFF12181E),
                          border: accent.withValues(alpha: 0.55),
                          up: false,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.color,
    required this.border,
    required this.up,
  });

  final Color color;
  final Color border;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (up) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
      path.close();
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.border != border ||
      oldDelegate.up != up;
}
