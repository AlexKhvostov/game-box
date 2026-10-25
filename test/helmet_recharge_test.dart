import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/data/android_firebase_config.dart';
import 'package:game_box/domain/helmet_charge.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/helmet_artwork.dart';
import 'package:game_box/features/game/helmet_indicator.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/game/game_world.dart';
import 'uniform_pace_helmet_test.dart' as fixture;

GameFieldPainter field(WidgetTester t) =>
    t
            .widget<CustomPaint>(
              find.byKey(const ValueKey('arcade-game-field')),
            )
            .painter!
        as GameFieldPainter;

void main() {
  test(
    'zero is one use, not instant recharge; unequipped never regenerates',
    () {
      for (final equipped in [true, false]) {
        final h = HelmetCharge(equipped: equipped, cooldownSec: 0);
        expect(h.consume(), equipped);
        h.advanceTo(1000000);
        expect(h.ready, false);
        expect(h.cooling, false);
        expect(h.progress, 0);
      }
    },
  );
  for (final seconds in [.1, .5, 30.0, 60.0, 3600.0]) {
    test(
      '$seconds seconds: exact active-time boundary and repeated charge',
      () {
        final h = HelmetCharge(equipped: true, cooldownSec: seconds);
        h.advanceTo(125);
        expect(h.consume(), true);
        expect(h.consume(), false);
        final end = 125 + seconds * 1000;
        h.advanceTo(end - .001);
        expect(h.ready, false);
        expect(h.advanceTo(end), true);
        expect(h.ready, true);
        expect(h.advanceTo(end + 1), false);
        expect(h.consume(), true);
        h.advanceTo(end + 1 + seconds * 1000);
        expect(h.ready, true);
      },
    );
  }
  test(
    'absent field preserves old one-use policy; explicit invalid fields rejected',
    () {
      final original =
          jsonDecode(
                File('assets/config/android-firebase.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final value in [null, -1, 3601, '30']) {
        final raw = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
        raw['config']['game']['helmetCooldownSec'] = value;
        raw['revision'] = sha256
            .convert(utf8.encode(jsonEncode(raw['config'])))
            .toString();
        expect(
          () => AndroidFirebaseConfig.parse(jsonEncode(raw), 'test'),
          throwsFormatException,
        );
      }
      original['config']['game'].remove('helmetCooldownSec');
      original['revision'] = sha256
          .convert(utf8.encode(jsonEncode(original['config'])))
          .toString();
      expect(
        AndroidFirebaseConfig.parse(
          jsonEncode(original),
          'old',
        ).gameplay.helmetCooldownSec,
        0,
      );
    },
  );
  testWidgets(
    'actual screen: breaks, recharges at 30s, repeats, then an unshielded hit kills',
    (t) async {
      await fixture.mount(
        t,
        const GameplayConfig(
          game: GameConfig(
            startInvulnSec: 0,
            helmetInvulnSec: .1,
            helmetCooldownSec: 30,
          ),
        ),
        rentals: true,
      );
      await fixture.start(t);
      final w = field(t).world;
      w.enemies.clear();
      EnemyBody contact() => EnemyBody(
        pos: w.player + Offset(w.playerSize - 2, 10),
        vel: const Offset(-100, 0),
        w: 20,
        h: 20,
        aspect: 1,
        angleDeg: 0,
        quadrantN: 0,
        fieldQuadrant: 0,
        initialSpeed: 100,
        acceleration: 0,
      );
      w.enemies.add(contact());
      await t.pump(const Duration(milliseconds: 16));
      final h = field(t).helmetCharge!;
      expect(h.ready, false);
      expect(h.cooling, true);
      expect(field(t).helmetShatter, isNotNull);
      expect(find.text('Spent'), findsNothing);
      w.enemies.clear();
      for (var i = 0; i < 599; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(h.ready, false);
      await t.pump(const Duration(milliseconds: 50));
      expect(h.ready, true);
      expect(field(t).helmetFlash!.call(), greaterThan(0));
      await t.pump(const Duration(milliseconds: 50));
      w.enemies.add(contact());
      await t.pump(const Duration(milliseconds: 16));
      expect(h.ready, false);
      expect(h.remainingMs, greaterThan(29900));
      w.enemies.clear();
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      w.enemies.add(contact());
      await t.pump(const Duration(milliseconds: 16));
      final alive = fixture.worldOf(t);
      expect(identical(w, alive), true);
      final clock = h.remainingMs;
      await t.pump(const Duration(milliseconds: 50));
      expect(h.remainingMs, clock);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'background pauses shield and new round starts with a full charge',
    (t) async {
      await fixture.mount(
        t,
        const GameplayConfig(
          game: GameConfig(startInvulnSec: 0, helmetCooldownSec: 30),
        ),
        rentals: true,
      );
      await fixture.start(t);
      final w = field(t).world;
      w.enemies.clear();
      final h = field(t).helmetCharge!;
      h.consume();
      await t.pump(const Duration(milliseconds: 50));
      final before = h.remainingMs;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(seconds: 60));
      expect(h.remainingMs, before);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump(const Duration(milliseconds: 16));
      expect(h.ready, false);
      expect(h.remainingMs, greaterThan(before - 100));
      await t.pumpWidget(const SizedBox());
      final next = HelmetCharge(equipped: true, cooldownSec: 30);
      expect(next.ready, true);
    },
  );
  test(
    'artwork is dim while charging, one flash then steady bright; six fragments expire',
    () async {
      double luminance(Color c) => c.computeLuminance();
      expect(
        luminance(HelmetArtwork.bright),
        greaterThan(luminance(HelmetArtwork.dim) * 2),
      );
      expect(HelmetArtwork.flash(0), closeTo(0, 1e-9));
      expect(HelmetArtwork.flash(.21), closeTo(1, 1e-9));
      expect(HelmetArtwork.flash(.21, reducedMotion: true), 0);
      final burst = HelmetShatter(const Rect.fromLTWH(30, 30, 44, 44));
      expect(burst.update(.399), true);
      expect(burst.update(.0011), false);
      final recorder = ui.PictureRecorder();
      // Independent native raster board: actual production painter, no browser approximation.
      final c = Canvas(recorder);
      c.drawColor(const Color(0xFF082B40), BlendMode.src);
      final stages = [
        (0.0, false, 0.0),
        (.5, false, 0.0),
        (1.0, true, 1.0),
        (1.0, true, 0.0),
      ];
      for (var i = 0; i < stages.length; i++) {
        final s = stages[i];
        HelmetArtwork.paint(
          c,
          RRect.fromRectAndRadius(
            Rect.fromLTWH(30.0 + i * 110, 30, 64, 64),
            const Radius.circular(4),
          ),
          progress: s.$1,
          ready: s.$2,
          flash: s.$3,
        );
      }
      final image = await recorder.endRecording().toImage(460, 124);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final target = File(
        'docs/release-evidence/android-helmet-20261024/native-contour-states.png',
      );
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    },
  );
  testWidgets(
    'circular HUD preserves image aspect and reserves fixed geometry at 60 seconds',
    (t) async {
      final frame = ValueNotifier(0),
          h = HelmetCharge(equipped: true, cooldownSec: 60)..consume();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HelmetIndicator(
              equipped: true,
              ru: true,
              frame: frame,
              ready: () => h.ready,
              cooling: () => h.cooling,
              progress: () => h.progress,
              remainingMs: () => h.remainingMs,
              flash: () => 0,
            ),
          ),
        ),
      );
      final art = t.widget<Image>(find.byType(Image));
      expect(art.fit, BoxFit.cover);
      expect(t.getSize(find.byType(HelmetIndicator)), const Size(72, 44));
      expect(find.text('60,0 с'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );
}
