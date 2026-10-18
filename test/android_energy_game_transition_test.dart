import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'uniform_pace_helmet_test.dart' as fixture;

class _Account extends MobileAccount {
  _Account() {
    id = 'android:900009';
    nickname = 'QA';
  }
  Map<String, dynamic>? loadout;
  bool pending = false;
  @override
  String? get pendingRoundRequestId => pending ? 'persisted-qa-receipt' : null;
  @override
  Map<String, dynamic>? get acceptedRoundLoadout => loadout;
}

class _Scores extends ScoresStore {
  _Scores(this.economy) : super(account: _Account());
  final EconomyStore economy;
  Completer<bool>? response;
  Completer<void>? activation;
  bool prepaid = false;
  String? refusal;
  int starts = 0, activations = 0, cancellations = 0;
  @override
  Future<bool> beginRound({
    bool helmet = false,
    bool jump = false,
    String? economyRevision,
  }) async {
    starts++;
    (account! as _Account).loadout = {
      'owner': account!.id,
      'helmet': helmet,
      'jump': jump,
    };
    if (response != null) await response!.future;
    if (refusal != null) {
      account!.roundError = refusal;
      return false;
    }
    final cost = 1 + (helmet ? 1 : 0) + (jump ? 1 : 0);
    if (!prepaid) {
      await economy.enableEnergyPreview(balance: economy.energy - cost);
    }
    return true;
  }

  @override
  Future<void> activateRound() async {
    activations++;
    if (activation != null) await activation!.future;
  }

  @override
  Future<void> cancelRound() async {
    cancellations++;
  }

  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
}

Future<(EconomyStore, _Scores)> _mount(
  WidgetTester tester, {
  bool helmet = false,
  bool jump = false,
}) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final economy = EconomyStore(storagePrefix: 'energy_transition_');
  await economy.load();
  await economy.enableEnergyPreview(balance: 47);
  economy.setHelmetSelected(helmet);
  economy.setJumpSelected(jump);
  final scores = _Scores(economy);
  await scores.loadLocal();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider<ScoresStore>.value(value: scores),
        Provider.value(
          value: const GameplayConfig(
            game: GameConfig(idleEnemiesMove: false, startInvulnSec: 60),
          ),
        ),
      ],
      child: const GameBoxApp(forceLocale: 'ru'),
    ),
  );
  await tester.pump();
  addTearDown(scores.dispose);
  return (economy, scores);
}

void main() {
  testWidgets(
    'last-energy paid pending receipt can be retried with zero wallet',
    (tester) async {
      final (economy, scores) = await _mount(tester);
      await economy.enableEnergyPreview(balance: 0);
      scores.prepaid = true;
      (scores.account! as _Account)
        ..pending = true
        ..loadout = {
          'owner': scores.account!.id,
          'helmet': false,
          'jump': false,
        };
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('arcade-game-field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 32));
      expect(scores.starts, 1);
      expect(scores.activations, 1);
      expect(economy.energy, 0);
      expect(
        tester.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(),
        greaterThan(0),
      );
      expect(find.byKey(const ValueKey('energy-sheet')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'activation finishing in background waits for visible touch without a second debit',
    (tester) async {
      final (economy, scores) = await _mount(tester, helmet: true);
      scores.activation = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('arcade-game-field')));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      scores.activation!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      expect(tester.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(), 0);
      expect(economy.energy, 45);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('arcade-game-field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 32));
      expect(scores.starts, 1);
      expect(scores.activations, 1);
      expect(economy.energy, 45);
      expect(
        tester.widget<ArcadeHud>(find.byType(ArcadeHud)).helmetEquipped,
        true,
      );
      expect(
        tester.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(),
        greaterThan(0),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final state in [
    (false, false, 1),
    (true, false, 2),
    (false, true, 2),
    (true, true, 3),
  ]) {
    testWidgets(
      'field touch confirms one debit ${state.$3} and freezes equipment',
      (tester) async {
        final (economy, scores) = await _mount(
          tester,
          helmet: state.$1,
          jump: state.$2,
        );
        await tester.tap(find.byKey(const ValueKey('arcade-game-field')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 32));
        expect(scores.starts, 1);
        expect(scores.activations, 1);
        expect(economy.energy, 47 - state.$3);
        final hud = tester.widget<ArcadeHud>(find.byType(ArcadeHud));
        expect(hud.helmetEquipped, state.$1);
        expect(hud.timeMs(), greaterThan(0));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('changing selection while waiting does not change paid loadout', (
    tester,
  ) async {
    final (economy, scores) = await _mount(tester, helmet: true, jump: true);
    scores.response = Completer<bool>();
    await tester.tap(find.byKey(const ValueKey('arcade-game-field')));
    await tester.pump();
    economy.setHelmetSelected(false);
    economy.setJumpSelected(false);
    scores.response!.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(economy.energy, 44);
    expect(
      tester.widget<ArcadeHud>(find.byType(ArcadeHud)).helmetEquipped,
      true,
    );
    expect((scores.account! as _Account).loadout!['jump'], true);
    await tester.pumpWidget(const SizedBox());
  });
  for (final refusal in [
    'insufficient_energy',
    'rules_changed',
    'update_required',
  ]) {
    testWidgets('$refusal cannot fall back to cached practice', (tester) async {
      final (economy, scores) = await _mount(tester);
      scores.refusal = refusal;
      scores.account!.error = 'connection_failed';
      await tester.tap(find.byKey(const ValueKey('arcade-game-field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(economy.energy, 47);
      expect(scores.activations, 0);
      expect(tester.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(), 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'bad geometry after confirmation is cancelled before activation',
    (tester) async {
      final (_, scores) = await _mount(tester);
      scores.response = Completer<bool>();
      await tester.tap(find.byKey(const ValueKey('arcade-game-field')));
      await tester.pump();
      fixture.worldOf(tester).enemies.clear();
      scores.response!.complete(true);
      await tester.pump();
      expect(scores.cancellations, 1);
      expect(scores.activations, 0);
      expect(
        find.byKey(const ValueKey('game-start-technical-error')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
