import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/game/game_world.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final color in [const Color(0xFF2B2B2B), const Color(0xFF123456)]) {
    test('Mobile grid is rendered on configurable surface $color', () async {
      final world = GameWorld(
        config: GameplayConfig(),
        field: const Size(240, 240),
        wallInset: 3,
      )..resetLayout();
      world.enemies.clear();
      Future<List<int>> pixel(bool grid, int x) async {
        final recorder = ui.PictureRecorder();
        GameFieldPainter(
          world: world,
          accent: Colors.green,
          danger: Colors.red,
          fieldColor: color,
          borderColor: GameFieldColors.wall,
          drawGrid: grid,
        ).paint(Canvas(recorder), const Size(240, 240));
        final picture = recorder.endRecording();
        final image = await picture.toImage(240, 240);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final offset = (43 * 240 + x) * 4;
        final rgba = List.generate(4, (i) => data!.getUint8(offset + i));
        image.dispose();
        picture.dispose();
        return rgba;
      }

      expect(
        await pixel(true, 20),
        isNot(await pixel(false, 20)),
        reason: 'A visible vertical grid stroke must survive a color change',
      );
      expect(
        await pixel(true, 25),
        await pixel(false, 25),
        reason: 'The grid must not replace the configured floor fill',
      );
    });
  }
}
