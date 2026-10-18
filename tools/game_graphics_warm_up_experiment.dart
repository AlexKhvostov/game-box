import 'package:flutter/material.dart';
import '../lib/ui/game_ui.dart';

/// Diagnostic experiment only: did not eliminate cold sheet stalls on Huawei.
/// Retained for reproducibility; not included in the production entry point.
class GameGraphicsWarmUp extends ShaderWarmUp {
  const GameGraphicsWarmUp();
  @override
  Size get size => const Size(512, 512);

  @override
  Future<void> warmUpOnCanvas(Canvas canvas) async {
    const rectSize = Size(180, 130);
    final decorations = <BoxDecoration>[
      const GameGlassDecoration(
        glass: GameGlass.sheet,
        gradient: GameUi.sheetGradient,
        borderRadius: BorderRadius.all(Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Color(0x55020E1F),
            blurRadius: 28,
            offset: Offset(0, -12),
          ),
        ],
      ),
      const GameGlassDecoration(
        glass: GameGlass.card,
        gradient: GameUi.panelGradient,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      const GameGlassDecoration(
        glass: GameGlass.button,
        gradient: GameUi.panelGradient,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      const GameGlassDecoration(
        glass: GameGlass.selected,
        gradient: GameUi.panelGradient,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      GameUi.hudPanel(),
    ];
    canvas.drawColor(GameUi.background, BlendMode.src);
    for (var i = 0; i < decorations.length; i++) {
      final painter = decorations[i].createBoxPainter();
      painter.paint(
        canvas,
        Offset(12 + (i % 2) * 220.0, 20 + (i ~/ 2) * 155.0),
        const ImageConfiguration(
          size: rectSize,
          textDirection: TextDirection.ltr,
        ),
      );
      painter.dispose();
    }
    for (final size in [11.0, 18.0, 28.0, 46.0]) {
      final text = TextPainter(
        text: TextSpan(
          text: 'Прыжок Аккаунт 00:12.345',
          style: TextStyle(
            fontSize: size,
            color: GameUi.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 470);
      text.paint(canvas, Offset(10, size * 7));
      text.dispose();
    }
  }
}
