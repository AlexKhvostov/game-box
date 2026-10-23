import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/result/result_screen.dart';

Future<EconomyStore> _mount(
  WidgetTester t, {
  int balance = 10,
  bool selected = false,
  bool abilitiesEnabled = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(412, 900);
  t.view.devicePixelRatio = 1;
  final economy = EconomyStore(storagePrefix: 'energy_entry_');
  await economy.load();
  await economy.enableEnergyPreview(balance: balance);
  economy.setHelmetSelected(selected);
  economy.setJumpSelected(selected);
  final scores = ScoresStore();
  await scores.loadLocal();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    scores.dispose();
    economy.dispose();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: scores),
        Provider.value(
          value: GameplayConfig(
            game: GameConfig(
              startInvulnSec: 0,
              idleEnemiesMove: false,
              helmetEnabled: abilitiesEnabled,
              jumpEnabled: abilitiesEnabled,
            ),
            enemies: const EnemiesConfig(
              speedMin: 0,
              speedMax: 0,
              accelMin: 0,
              accelMax: 0,
            ),
            audio: const AudioConfig(
              music: false,
              sfxMobWall: false,
              sfxMobCollide: false,
              sfxHeroMob: false,
              sfxHeroWall: false,
              sfxNearMiss: false,
              sfxHelmet: false,
              sfxJump: false,
              sfxStart: false,
            ),
          ),
        ),
      ],
      child: const GameBoxApp(forceLocale: 'ru'),
    ),
  );
  await t.pump();
  return economy;
}

Future<void> _touchField(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('arcade-game-field')));
  await t.pump();
  await t.pump(const Duration(milliseconds: 32));
  await t.pump(const Duration(milliseconds: 32));
}

Future<void> _finish(WidgetTester t) async {
  await _touchField(t);
  final world =
      (t
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('arcade-game-field')),
                  )
                  .painter!
              as GameFieldPainter)
          .world;
  world.enemies.first.setCenter(
    world.player + Offset(world.playerSize / 2, world.playerSize / 2),
  );
  for (var i = 0; i < 16; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  expect(find.byType(ResultOverlay), findsOneWidget);
}

void _expectEnergyHub() {
  expect(find.byKey(const ValueKey('simple-energy-window')), findsOneWidget);
  expect(find.byKey(const ValueKey('simple-bonus-orb')), findsOneWidget);
  expect(find.byKey(const ValueKey('simple-energy-feedback')), findsOneWidget);
  expect(
    find.byKey(const ValueKey('simple-pack-tile-energy_100_v1')),
    findsNothing,
  );
}

void main() {
  for (final balance in [0, 1]) {
    testWidgets('Field opens common Energy at insufficient balance $balance', (
      t,
    ) async {
      await _mount(t, balance: balance, selected: true);
      await _touchField(t);
      _expectEnergyHub();
      expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(), 0);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('Enough energy starts the effective loadout and charges once', (
    t,
  ) async {
    final economy = await _mount(t, balance: 3, selected: true);
    await _touchField(t);
    expect(find.byKey(const ValueKey('simple-energy-window')), findsNothing);
    expect(
      t.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(),
      greaterThan(0),
    );
    expect(economy.energy, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('Disabled RC abilities do not price or block stale selections', (
    t,
  ) async {
    final economy = await _mount(
      t,
      balance: 1,
      selected: true,
      abilitiesEnabled: false,
    );
    expect(
      economy.attemptEnergyCost,
      3,
    ); // Stale selection is deliberately kept.
    expect(find.byKey(const ValueKey('lives-recovery-banner')), findsNothing);
    expect(find.text('Попытка: 1 ⚡ · коснитесь поля'), findsOneWidget);
    await _touchField(t);
    final hud = t.widget<ArcadeHud>(find.byType(ArcadeHud));
    expect(hud.timeMs(), greaterThan(0));
    expect(hud.helmetEquipped, isFalse);
    expect(economy.energy, 0);
    expect(find.byKey(const ValueKey('simple-energy-window')), findsNothing);
    expect(t.takeException(), isNull);
  });

  for (final balance in [0, 1, 3]) {
    testWidgets('Replay rechecks next loadout at balance $balance', (t) async {
      final economy = await _mount(t);
      await _finish(t);
      await economy.enableEnergyPreview(balance: balance);
      economy.setHelmetSelected(true);
      economy.setJumpSelected(true);
      await t.pump();
      await t.tap(find.byKey(const ValueKey('result-replay')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 350));
      expect(find.byType(ResultOverlay), findsNothing);
      if (balance < 3) {
        _expectEnergyHub();
      } else {
        expect(
          find.byKey(const ValueKey('simple-energy-window')),
          findsNothing,
        );
      }
      expect(
        economy.energy,
        balance,
      ); // Replay prepares; it does not buy a run.
      expect(t.takeException(), isNull);
    });
  }

  for (final action in ['close', 'back']) {
    testWidgets('Result $action only closes even at zero energy', (t) async {
      final economy = await _mount(t);
      await _finish(t);
      await economy.enableEnergyPreview(balance: 0);
      await t.pump();
      if (action == 'back') {
        await t.binding.handlePopRoute();
      } else {
        // The backdrop/close path, also used by an external close control.
        await t.tapAt(const Offset(2, 450));
      }
      await t.pump();
      await t.pump(const Duration(milliseconds: 350));
      expect(find.byType(ResultOverlay), findsNothing);
      expect(find.byKey(const ValueKey('simple-energy-window')), findsNothing);
      expect(t.takeException(), isNull);
    });
  }

  test(
    'Practice explicit cost rejects invalid or unaffordable amounts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final economy = EconomyStore(storagePrefix: 'energy_entry_cost_');
      await economy.load();
      await economy.enableEnergyPreview(balance: 1);
      expect(economy.spendEnergyForPractice(cost: 0), isFalse);
      expect(economy.spendEnergyForPractice(cost: -1), isFalse);
      expect(economy.spendEnergyForPractice(cost: 2), isFalse);
      expect(economy.energy, 1);
      expect(economy.spendEnergyForPractice(cost: 1), isTrue);
      expect(economy.energy, 0);
      economy.dispose();
    },
  );
}
