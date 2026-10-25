import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/features/game/jump_ready_signal.dart';
import 'package:game_box/features/game/jump_glow.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/game/game_world.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'uniform_pace_helmet_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'exact boundary, one pulse, hold, pause, repeat, reset and invalid input',
    () {
      final s = JumpReadySignal();
      void observe(double now, double left) =>
          s.observe(enabled: true, remainingMs: left, nowMs: now);
      observe(0, 0);
      expect(s.ready, true);
      expect(s.ageMs, null);
      observe(0, 2000);
      observe(1999.99, .01);
      expect(s.ready, false);
      expect(s.ageMs, null);
      observe(2050, 0);
      expect(s.ready, true);
      expect(s.ageMs, closeTo(50, 1e-8));
      observe(2210, 0);
      expect(JumpReadySignal.flash(s.ageMs), closeTo(1, 1e-8));
      observe(2210, 0);
      expect(s.ageMs, closeTo(210, 1e-8));
      observe(2420, 0);
      expect(JumpReadySignal.flash(s.ageMs), 0);
      observe(20000, 0);
      expect(JumpReadySignal.flash(s.ageMs), 0);
      observe(20000, 120);
      expect(s.ageMs, null);
      observe(20119.99, .01);
      expect(s.ready, false);
      observe(20120, 0);
      expect(s.ageMs, closeTo(0, 1e-8));
      expect(JumpReadySignal.flash(210, reducedMotion: true), 0);
      s.observe(enabled: false, remainingMs: 0, nowMs: 20120);
      observe(20120, 0);
      expect(s.ageMs, null);
      observe(0, 0);
      expect(s.ageMs, null);
      for (final bad in [double.nan, double.infinity, -1.0]) {
        observe(0, bad);
        expect(s.ready, false);
        expect(s.ageMs, null);
        expect(JumpReadySignal.flash(bad), 0);
      }
    },
  );

  test(
    'ready/flash palettes preserve the original geometry and alpha gains',
    () {
      final source = createJumpGlowPixels(256);
      for (final flash in [false, true]) {
        final p = createJumpReadyPixels(256, flash: flash);
        for (var i = 0; i < source.length; i += 4) {
          expect(
            p.sublist(i, i + 3),
            flash ? [255, 255, 236] : [232, 255, 105],
          );
          expect(
            p[i + 3],
            (source[i + 3] * (flash ? 1.65 : 1.3)).round().clamp(0, 255),
          );
        }
      }
    },
  );

  test(
    'native painter shows B with helmet, keeps face/rim stable, reduces motion',
    () async {
      await JumpGlowArtwork.prewarm();
      final world = GameWorld(
        config: const GameplayConfig(
          enemies: EnemiesConfig(aspects: []),
          player: PlayerConfig(size: 100, showFace: true),
        ),
        field: const Size(240, 240),
      )..player = const Offset(60, 60);
      Future<List<int>> draw(
        String name,
        double? age, {
        bool reduced = false,
      }) async {
        final rec = ui.PictureRecorder();
        GameFieldPainter(
          world: world,
          accent: GameFieldColors.hero,
          danger: GameFieldColors.enemy,
          fieldColor: GameFieldColors.floor,
          borderColor: GameFieldColors.wall,
          hasJump: true,
          hasHelmet: true,
          jumpNowMs: () => 0,
          jumpReadyAgeMs: () => age,
          reducedMotion: reduced,
          showFace: true,
        ).paint(Canvas(rec), const Size(240, 240));
        final pic = rec.endRecording();
        final image = await pic.toImage(240, 240);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        final out = Platform.environment['JUMP_READY_EVIDENCE'];
        if (out != null) {
          Directory(out).createSync(recursive: true);
          File('$out/native-$name.png').writeAsBytesSync(
            (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List(),
          );
        }
        image.dispose();
        pic.dispose();
        return data;
      }

      final ready = await draw('ready', null), pulse = await draw('flash', 210);
      final reduced = await draw('reduced', 210, reduced: true);
      final settled = await draw('settled', 420);
      expect(reduced, ready);
      expect(settled, ready);
      List<int> pixel(List<int> p, int x, int y) =>
          p.sublist((y * 240 + x) * 4, (y * 240 + x) * 4 + 4);
      expect(pixel(pulse, 64, 120), isNot(pixel(ready, 64, 120)));
      for (final pt in [
        const Offset(58, 120),
        const Offset(120, 110),
        const Offset(20, 20),
      ]) {
        expect(
          pixel(pulse, pt.dx.toInt(), pt.dy.toInt()),
          pixel(ready, pt.dx.toInt(), pt.dy.toInt()),
        );
      }
    },
  );

  testWidgets(
    'actual screen consumes and rearms only after zero-cooldown flight',
    (t) async {
      await fixture.mount(
        t,
        const GameplayConfig(
          game: GameConfig(
            startInvulnSec: 60,
            jumpCooldownSec: 0,
            jumpDurationSec: .38,
          ),
          enemies: EnemiesConfig(aspects: []),
        ),
        rentals: true,
      );
      GameFieldPainter field() =>
          t
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('arcade-game-field')),
                  )
                  .painter!
              as GameFieldPainter;
      expect(field().jumpReadyAgeMs?.call(), null);
      await fixture.start(t);
      final point = t.getCenter(
        find.byKey(const ValueKey('arcade-game-field')),
      );
      final primary = await t.startGesture(point, pointer: 1);
      Future<void> jump(int id) async {
        final second = await t.startGesture(
          point + const Offset(8, 0),
          pointer: id,
        );
        await t.pump();
        await second.up();
      }

      await jump(2);
      expect(field().world.isJumping, true);
      expect(field().jumpReadyAgeMs?.call(), null);
      for (var i = 0; i < 7; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(field().world.isJumping, true);
      expect(field().jumpReadyAgeMs?.call(), null);
      await t.pump(const Duration(milliseconds: 50));
      expect(field().world.isJumping, false);
      expect(field().jumpReadyAgeMs?.call(), inInclusiveRange(0, 50));
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(field().jumpReadyAgeMs!.call(), greaterThan(420));
      await jump(3);
      expect(field().jumpReadyAgeMs?.call(), null);
      await primary.up();
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), null);
    },
  );
}
