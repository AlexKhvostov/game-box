import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/game/game_world.dart';
import 'package:game_box/features/game/jump_glow.dart';

double readiness({
  bool enabled = true,
  double cooldown = 2000,
  double remaining = 0,
  double duration = 350,
  double jumping = 0,
}) => jumpGlowProgress(
  enabled: enabled,
  cooldownMs: cooldown,
  cooldownRemainingMs: remaining,
  jumpDurationMs: duration,
  jumpRemainingMs: jumping,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('artwork exactly matches the approved Telegram runtime RGBA texture', () {
    // Independently computed with Node from createJumpGlowPixels(256,{radius:.1}).
    expect(
      sha256.convert(createJumpGlowPixels(256)).toString(),
      '79aaf75a4bc881994868822e3da65e00aa192135d72f448e683981fac4435d97',
    );
  });

  test(
    'glow follows real readiness and never advertises mid-air zero cooldown',
    () {
      expect(readiness(enabled: false), 0);
      expect(readiness(), 1);
      expect(readiness(remaining: 2000, jumping: 350), 0);
      expect(readiness(remaining: 1340), closeTo(.33, 1e-9));
      expect(readiness(remaining: 680), closeTo(.66, 1e-9));
      expect(readiness(cooldown: 0, jumping: 350), 0);
      expect(readiness(cooldown: 0, jumping: 175), .5);
      expect(readiness(cooldown: 0), 1);
      expect(readiness(cooldown: 100, remaining: 0, jumping: 175), .5);
      expect(readiness(cooldown: 0, duration: 0, jumping: 120), 0);
      for (final invalid in [double.nan, double.infinity, -1.0]) {
        expect(readiness(cooldown: invalid), 0);
        expect(readiness(remaining: invalid), 0);
        expect(readiness(duration: invalid), 0);
        expect(readiness(jumping: invalid), 0);
      }
    },
  );

  test(
    'texture is cached and partial fill crops without vertically blurring',
    () async {
      final image = await JumpGlowArtwork.prewarm();
      expect(identical(await JumpGlowArtwork.prewarm(), image), isTrue);
      Future<ByteData> draw(double progress) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        JumpGlowArtwork.draw(
          canvas,
          const Rect.fromLTWH(0, 0, 256, 256),
          progress: progress,
        );
        final picture = recorder.endRecording();
        final result = await picture.toImage(256, 256);
        final data = await result.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        result.dispose();
        picture.dispose();
        return data!;
      }

      final empty = await draw(0),
          partial = await draw(.66),
          full = await draw(1);
      int alpha(ByteData data, int x, int y) =>
          data.getUint8((y * 256 + x) * 4 + 3);
      expect(alpha(empty, 7, 160), 0);
      expect(alpha(partial, 7, 50), 0);
      expect(alpha(full, 7, 50), greaterThan(150));
      expect(alpha(partial, 7, 87), greaterThan(150));
      expect(alpha(partial, 7, 86), 0);
      expect(alpha(partial, 7, 180), alpha(full, 7, 180));
      expect(alpha(full, 128, 128), 0);
      final source = createJumpGlowPixels(256);
      final sample = (128 * 256 + 37) * 4;
      expect(
        full.getUint8(sample + 2),
        closeTo((source[sample + 2] * source[sample + 3] / 255).round(), 1),
        reason:
            'Flutter decoding must premultiply straight browser RGBA first; otherwise light becomes white',
      );
      expect(
        alpha(full, 37, 35),
        greaterThan(alpha(full, 37, 128)),
        reason:
            'The light reaches deeper at the upper/lower ends than at eye height',
      );
    },
  );

  test(
    'painter clips to hero, preserves helmet and scales the same artwork',
    () async {
      await JumpGlowArtwork.prewarm();
      const side = 240;
      final world = GameWorld(
        config: const GameplayConfig(
          enemies: EnemiesConfig(aspects: []),
          player: PlayerConfig(size: 140, showFace: true),
        ),
        field: const Size(240, 240),
      )..player = const Offset(36, 36);
      Future<({ByteData pixels, Uint8List png})> draw(
        bool glow,
        bool helmet,
      ) async {
        final recorder = ui.PictureRecorder();
        GameFieldPainter(
          world: world,
          accent: GameFieldColors.hero,
          danger: GameFieldColors.enemy,
          fieldColor: GameFieldColors.floor,
          borderColor: GameFieldColors.wall,
          hasJump: glow,
          hasHelmet: helmet,
          showFace: true,
        ).paint(Canvas(recorder), const Size(240, 240));
        final picture = recorder.endRecording();
        final image = await picture.toImage(side, side);
        final pixels = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        return (pixels: pixels!, png: png!.buffer.asUint8List());
      }

      final plain = await draw(false, false), glow = await draw(true, false);
      final helmet = await draw(false, true), both = await draw(true, true);
      List<int> pixel(ByteData d, int x, int y) =>
          List.generate(4, (i) => d.getUint8((y * side + x) * 4 + i));
      // The hero begins at x/y36 and has a168px body; left/right light is internal.
      expect(pixel(glow.pixels, 42, 120), isNot(pixel(plain.pixels, 42, 120)));
      expect(pixel(glow.pixels, 33, 120), pixel(plain.pixels, 33, 120));
      expect(pixel(both.pixels, 33, 120), pixel(helmet.pixels, 33, 120));
      expect(pixel(glow.pixels, 120, 120), pixel(plain.pixels, 120, 120));
      final evidence = Platform.environment['JUMP_GLOW_EVIDENCE'];
      if (evidence != null && evidence.isNotEmpty) {
        final directory = Directory(evidence)..createSync(recursive: true);
        File('${directory.path}/hero-jump-glow.png').writeAsBytesSync(glow.png);
        File(
          '${directory.path}/hero-jump-glow-helmet.png',
        ).writeAsBytesSync(both.png);
      }
    },
  );
}
