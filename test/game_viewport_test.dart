import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/audience_gate.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/ui/game_viewport.dart';

GameFieldPainter painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('arcade-game-field')),
            )
            .painter!
        as GameFieldPainter;

Future<void> mount(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({});
  final economy = EconomyStore();
  await economy.load();
  final scores = ScoresStore();
  await scores.loadLocal();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: scores),
        Provider.value(
          value: const GameplayConfig(
            game: GameConfig(startInvulnSec: 30, idleEnemiesMove: false),
            enemies: EnemiesConfig(
              speedMin: 0,
              speedMax: 0,
              accelMin: 0,
              accelMax: 0,
            ),
          ),
        ),
      ],
      child: const GameBoxApp(forceLocale: 'en'),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('modal buttons share the viewport scale', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 840);
      SharedPreferences.setMockInitialValues({});
      final audience = AudiencePolicy();
      await audience.load();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: audience,
          child: MaterialApp(
            key: ValueKey(width),
            theme: buildGameTheme(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (c, child) => GameViewport(child: child!),
            home: Builder(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () => showAudienceSelection(c),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('age-under18'));
      final face = find
          .descendant(of: button, matching: find.byType(DecoratedBox))
          .first;
      expect(
        tester.getRect(face).height,
        closeTo(50 * GameViewport.scaleFor(width), .01),
      );
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('button surface and target share the viewport scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    double? referenceTextHeight;
    for (final width in [320.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 840);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildGameTheme(),
          builder: (c, child) => GameViewport(child: child!),
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(onPressed: () {}, child: const Text('Test')),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Outlined'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final button = find.byType(FilledButton);
      final face = find
          .descendant(of: button, matching: find.byType(DecoratedBox))
          .first;
      expect(
        tester.getRect(face).height,
        closeTo(36 * GameViewport.scaleFor(width), .01),
      );
      final outlined = find.byType(OutlinedButton);
      expect(
        tester
            .getRect(
              find
                  .descendant(of: outlined, matching: find.byType(DecoratedBox))
                  .first,
            )
            .height,
        closeTo(36 * GameViewport.scaleFor(width), .01),
      );
      expect(
        tester.getRect(button).height,
        closeTo(48 * GameViewport.scaleFor(width), .01),
      );
      expect(
        tester.getRect(outlined).height,
        closeTo(48 * GameViewport.scaleFor(width), .01),
      );
      final textHeight = tester.getRect(find.text('Test')).height;
      referenceTextHeight ??= textHeight / GameViewport.scaleFor(width);
      expect(
        textHeight,
        closeTo(referenceTextHeight * GameViewport.scaleFor(width), .01),
      );
    }
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [
    const Size(280, 480),
    const Size(320, 480),
    const Size(320, 560),
    const Size(390, 844),
    const Size(430, 932),
    const Size(768, 1024),
  ]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'field ratios and relative drag stay equal at $size text$textScale',
        (tester) async {
          await mount(tester, size, textScale: textScale);
          final field = find.byKey(const ValueKey('arcade-game-field'));
          final bounds = tester.getRect(field);
          final scale = GameViewport.scaleFor(size.width);
          expect(bounds.width, closeTo(380 * scale, .001));
          expect(bounds.height, closeTo(bounds.width, .001));
          expect(bounds.center.dx, closeTo(size.width / 2, .001));
          final world = painter(tester).world;
          final accountTarget = tester.getRect(
            find.byKey(const ValueKey('hud-account-card')),
          );
          expect(accountTarget.height, greaterThanOrEqualTo(48 * scale - .01));
          expect(accountTarget.width, greaterThanOrEqualTo(48 * scale - .01));
          final recordTarget = tester.getRect(
            find.byKey(const ValueKey('hud-record-button')),
          );
          expect(recordTarget.center.dx, greaterThan(bounds.center.dx));
          final timer = tester.getRect(
            find.byKey(const ValueKey('arcade-top-timer')),
          );
          expect(timer.center.dx, closeTo(bounds.center.dx, .01));
          expect(
            bounds.top - 24,
            lessThanOrEqualTo((size.height - 48) * .20 + .01),
          );
          expect(recordTarget.height, greaterThanOrEqualTo(48 * scale - .01));

          expect(world.field, const Size.square(380));
          expect(
            world.playerSize * scale / bounds.width,
            closeTo(43.2 / 380, 1e-10),
          );
          for (final enemy in world.enemies) {
            expect(
              enemy.w * enemy.h / (world.playerSize * world.playerSize),
              closeTo(2, 1e-8),
            );
          }
          final before = world.player;
          final gesture = await tester.startGesture(bounds.center);
          await gesture.moveBy(Offset(bounds.width * .1, 0));
          await tester.pump();
          expect(world.player.dx - before.dx, closeTo(38, .001));
          expect(world.playerDistance, closeTo(38, .001));
          await gesture.up();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 3));
        },
      );
    }
  }
  testWidgets('short home shows the full ability row above the field', (
    tester,
  ) async {
    for (final scale in [1.0, 2.0]) {
      await mount(tester, const Size(320, 480), textScale: scale);
      final field = tester.getRect(
        find.byKey(const ValueKey('arcade-game-field')),
      );
      final ability = tester.getRect(
        find.byKey(const ValueKey('hud-helmet-button')),
      );
      expect(ability.bottom, lessThanOrEqualTo(field.top));
      final hud = tester.getRect(
        find.byKey(const ValueKey('arcade-hud-region')),
      );
      expect(ability.bottom, lessThanOrEqualTo(hud.bottom + .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('keyboard keeps the game field size and position', (
    tester,
  ) async {
    await mount(tester, const Size(390, 844));
    final field = find.byKey(const ValueKey('arcade-game-field'));
    final before = tester.getRect(field);
    addTearDown(tester.view.resetViewInsets);
    for (final height in [300.0, 340.0, 360.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: height);
      await tester.pump();
      expect(tester.getRect(field), before);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('resize keeps the current world, player and elapsed run', (
    tester,
  ) async {
    await mount(tester, const Size(320, 560));
    final world = painter(tester).world;
    final field = find.byKey(const ValueKey('arcade-game-field'));
    final gesture = await tester.startGesture(tester.getCenter(field));
    await gesture.moveBy(const Offset(16, 0));
    await gesture.up();
    final before = world.player;
    final distance = world.playerDistance;
    await tester.pump(const Duration(milliseconds: 250));
    tester.view.physicalSize = const Size(430, 932);
    await tester.pump();
    await tester.pump();
    expect(painter(tester).world, same(world));
    expect(world.player, before);
    expect(world.playerDistance, distance);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
