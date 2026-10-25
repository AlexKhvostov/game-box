import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'jump_ready_signal.dart';

/// Matches Telegram's approved warm inward side glow. The static texture is
/// generated and decoded once; a game frame only crops and draws that image.
abstract final class JumpGlowArtwork {
  static const textureSide = 256;
  static final repaint = ValueNotifier<int>(0);
  static Future<ui.Image>? _loading;
  static ui.Image? _image;
  static ui.Image? _readyImage, _flashImage;
  static final _paint = Paint()..filterQuality = FilterQuality.low;

  static Future<ui.Image> prewarm() => _loading ??= _prepare();

  static Future<ui.Image> _prepare() async {
    final images = await Future.wait([
      _decode(createJumpGlowPixels(textureSide)),
      _decode(createJumpReadyPixels(textureSide)),
      _decode(createJumpReadyPixels(textureSide, flash: true)),
    ]);
    _image = images[0];
    _readyImage = images[1];
    _flashImage = images[2];
    repaint.value++;
    return images[0];
  }

  static Future<ui.Image> _decode(Uint8List pixels) async {
    final complete = Completer<ui.Image>();
    // decodeImageFromPixels expects premultiplied RGBA, whereas browser
    // ImageData (and the portable approved artwork) contains straight RGBA.
    for (var i = 0; i < pixels.length; i += 4) {
      final alpha = pixels[i + 3] / 255;
      pixels[i] = (pixels[i] * alpha).round();
      pixels[i + 1] = (pixels[i + 1] * alpha).round();
      pixels[i + 2] = (pixels[i + 2] * alpha).round();
    }
    ui.decodeImageFromPixels(
      pixels,
      textureSide,
      textureSide,
      ui.PixelFormat.rgba8888,
      complete.complete,
    );
    return complete.future;
  }

  /// The caller clips to the actual hero body and supplies its existing alpha.
  static void draw(
    Canvas canvas,
    Rect body, {
    required double progress,
    double opacity = 1,
    bool ready = false,
    double? readyAgeMs,
    bool reducedMotion = false,
  }) {
    final image = ready ? _readyImage : _image;
    if (image == null ||
        !progress.isFinite ||
        !opacity.isFinite ||
        progress <= 0 ||
        opacity <= 0 ||
        !body.isFinite ||
        body.isEmpty) {
      return;
    }
    final p = progress.clamp(0.0, 1.0);
    final top = 1 - p;
    _paint.color = const Color(
      0xFFFFFFFF,
    ).withValues(alpha: opacity.clamp(0.0, 1.0));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
        0,
        textureSide * top,
        textureSide.toDouble(),
        textureSide * p,
      ),
      Rect.fromLTWH(
        body.left,
        body.top + body.height * top,
        body.width,
        body.height * p,
      ),
      _paint,
    );
    final flash = JumpReadySignal.flash(
      readyAgeMs,
      reducedMotion: reducedMotion,
    );
    if (ready && flash > 0 && _flashImage != null) {
      _paint.color = const Color(
        0xFFFFFFFF,
      ).withValues(alpha: opacity.clamp(0.0, 1.0) * flash);
      canvas.drawImageRect(
        _flashImage!,
        const Rect.fromLTWH(0, 0, 256, 256),
        body,
        _paint,
      );
    }
  }
}

/// The approved B palette reuses the original geometry and alpha falloff.
@visibleForTesting
Uint8List createJumpReadyPixels(int side, {bool flash = false}) {
  final pixels = createJumpGlowPixels(side);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = flash ? 255 : 232;
    pixels[i + 1] = 255;
    pixels[i + 2] = flash ? 236 : 105;
    pixels[i + 3] = math.min(
      255,
      (pixels[i + 3] * (flash ? 1.65 : 1.3)).round(),
    );
  }
  return pixels;
}

/// RGBA formula is identical to telegram-app/src/game/jump-glow.ts at radius .1.
/// Eye-height light stays shallow; both ends reach farther inward. There is no
/// vertical blur: the charge boundary remains legible at 66% versus 100%.
@visibleForTesting
Uint8List createJumpGlowPixels(int side) {
  if (side < 16 || side > 1024) {
    throw RangeError.range(side, 16, 1024, 'side');
  }
  const radius = .1, eyeDepth = .14, endDepth = .22;
  final pixels = Uint8List(side * side * 4);
  for (var row = 0; row < side; row++) {
    final y = (row + .5) / side;
    final corner = math.pow((2 * y - 1).abs(), 1.4);
    final depth = eyeDepth + (endDepth - eyeDepth) * corner;
    final rimFade = (math.min(y, 1 - y) / .035).clamp(0.0, 1.0);
    final dy = y < radius
        ? radius - y
        : y > 1 - radius
        ? y - (1 - radius)
        : 0.0;
    final inset = dy > 0
        ? radius - math.sqrt(math.max(0, radius * radius - dy * dy))
        : 0.0;
    for (var col = 0; col < side; col++) {
      final x = (col + .5) / side;
      final d = math.min(x, 1 - x) - inset;
      if (d < 0 || d > .34) continue;
      final diffuse = .94 * math.exp(-math.pow(d / (depth * .8), 2));
      final core = .38 * math.exp(-math.pow((d - .025) / .032, 2));
      final seam = .10 * math.exp(-d / .014);
      final alpha = (1 - (1 - diffuse) * (1 - core) * (1 - seam)) * rimFade;
      final coverage = (d * side + .5).clamp(0.0, 1.0);
      final i = (row * side + col) * 4;
      pixels[i] = 255;
      pixels[i + 1] = (243 + 12 * core).round();
      pixels[i + 2] = (122 + 88 * core).round();
      pixels[i + 3] = (255 * alpha * coverage).round();
    }
  }
  return pixels;
}

/// Real round readiness, including the independent guard against mid-air jumps.
/// No animation timer can get ahead of the simulation, even at zero cooldown.
double jumpGlowProgress({
  required bool enabled,
  required double cooldownMs,
  required double cooldownRemainingMs,
  required double jumpDurationMs,
  required double jumpRemainingMs,
}) {
  if (!enabled ||
      !cooldownMs.isFinite ||
      cooldownMs < 0 ||
      !cooldownRemainingMs.isFinite ||
      cooldownRemainingMs < 0 ||
      !jumpDurationMs.isFinite ||
      jumpDurationMs < 0 ||
      !jumpRemainingMs.isFinite ||
      jumpRemainingMs < 0) {
    return 0;
  }
  final total = math.max(cooldownMs, math.max(120.0, jumpDurationMs));
  final remaining = math.max(cooldownRemainingMs, jumpRemainingMs);
  return (1 - remaining / total).clamp(0.0, 1.0);
}
