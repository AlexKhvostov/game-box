// Reviewer-only route fixtures. No phone, HTTP, purchases or real wallet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'simple_energy_test.dart' as fixture;

const _field = ValueKey('arcade-game-field');

Future<EconomyStore> _mount(
  WidgetTester t, {
  required int balance,
  bool boosts = false,
  bool enableAbilities = true,
}) async {
  t.view.physicalSize = const Size(412, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final e = await fixture.store(balance: balance);
  e.helmetSelected = e.jumpSelected = boosts;
  final scores = ScoresStore();
  await scores.loadLocal();
  addTearDown(e.dispose);
  addTearDown(scores.dispose);
  await t.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: e),
      ChangeNotifierProvider.value(value: scores),
      Provider.value(value: GameplayConfig(
        game: GameConfig(
          idleEnemiesMove: false,
          startHintEnabled: false,
          startInvulnSec: 0,
          jumpEnabled: enableAbilities,
          helmetEnabled: enableAbilities,
        ),
        audio: const AudioConfig(music: false),
      )),
    ],
    child: const GameBoxApp(forceLocale: 'ru'),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  return e;
}

void _expectGeneralEnergy(WidgetTester t) {
  expect(find.byKey(const ValueKey('simple-energy-window')), findsOneWidget);
  expect(find.byKey(const ValueKey('simple-bonus-orb')), findsOneWidget);
  for (final key in ['video', 'friends', 'feedback']) {
    expect(find.byKey(ValueKey('simple-energy-$key')), findsOneWidget);
  }
  // The shop CTA may be present; the active page must expose free ways first.
  expect(find.byKey(const ValueKey('simple-watch-video')), findsNothing);
}

Future<void> _finishLocalLastRun(WidgetTester t) async {
  await t.tap(find.byKey(_field));
  await t.pump();
  expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).isPlaying, true);
  final painter = t.widget<CustomPaint>(find.byKey(_field)).painter!
      as GameFieldPainter;
  // Local-only deterministic death: exercise the real GameHome/result callback.
  // This is not a physical gesture/proof/server acceptance test.
  painter.world.player = const Offset(-20, -20);
  for (var frame = 0; frame < 45; frame++) {
    await t.pump(const Duration(milliseconds: 16));
  }
  expect(find.byType(ResultOverlay), findsOneWidget);
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized()
      .handleAppLifecycleStateChanged(AppLifecycleState.resumed));

  for (final balance in [0, 1, 2]) {
    testWidgets('field balance $balance below selected cost3 opens general Energy', (t) async {
      final e = await _mount(t, balance: balance, boosts: true);
      expect(e.attemptEnergyCost, 3);
      await t.tap(find.byKey(_field));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      _expectGeneralEnergy(t);
      expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).isPlaying, false);
      expect(e.energy, balance);
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('Result Replay with exhausted wallet opens free Energy immediately', (t) async {
    final e = await _mount(t, balance: 1);
    await _finishLocalLastRun(t);
    expect(e.energy, 0);
    await t.tap(find.byKey(const ValueKey('result-replay')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    _expectGeneralEnergy(t);
    expect(e.energy, 0);
    expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).isPlaying, false);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  testWidgets('Result Replay with enough wallet returns idle without new spend', (t) async {
    final e = await _mount(t, balance: 5);
    await _finishLocalLastRun(t);
    expect(e.energy, 4);
    await t.tap(find.byKey(const ValueKey('result-replay')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(ResultOverlay), findsNothing);
    expect(find.byKey(const ValueKey('simple-energy-window')), findsNothing);
    expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).isPlaying, false);
    expect(e.energy, 4);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  testWidgets('RC-disabled saved boosts cannot block affordable actual base loadout', (t) async {
    final e = await _mount(t, balance: 1, boosts: true, enableAbilities: false);
    await t.tap(find.byKey(_field));
    await t.pump();
    await t.pump(const Duration(milliseconds: 30));
    expect(find.byKey(const ValueKey('simple-energy-window')), findsNothing);
    expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).isPlaying, true);
    expect(e.energy, 0);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });
}
