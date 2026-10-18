import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/instant_round_journal.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'simple_energy_test.dart' as energy_fixture;
import 'mobile_account_test.dart' show MemoryVault;

const owner = 'supabase:12345678-1234-4234-8234-123456789abc';

class RunServer {
  int energy = 50, spent = 0;
  bool offline = false, loseStart = false, loseFinish = false;
  String? refusal;
  Completer<void>? gate;
  final commands = <Map<String, dynamic>>[];
  final rounds = <String, Map<String, dynamic>>{};
  Map<String, dynamic> wallet() => {
    ...energy_fixture.simpleWallet(balance: energy),
    'feedbackSpentEnergy': spent,
  };
  Future<Map<String, dynamic>> send(Map<String, dynamic> command) async {
    commands.add(Map.from(command));
    await gate?.future;
    if (offline) throw const MobileApiError('connection_failed');
    if (refusal != null && command['action'] != 'profile') {
      throw MobileApiError(refusal!);
    }
    if (command['action'] == 'profile') {
      return {
        'ok': true,
        'profile': {'id': owner},
      };
    }
    final key = (command['requestId'] ?? command['roundId']) as String;
    switch (command['action']) {
      case 'round_start':
        rounds.putIfAbsent(key, () {
          final cost =
              1 +
              (command['helmet'] == true ? 1 : 0) +
              (command['jump'] == true ? 1 : 0);
          energy -= cost;
          return {'cost': cost, 'activated': false, 'finished': false};
        });
        if (loseStart) {
          loseStart = false;
          throw const MobileApiError('connection_failed');
        }
      case 'round_activate':
        if (rounds[key]!['activated'] != true) {
          rounds[key]!['activated'] = true;
          spent += rounds[key]!['cost'] as int;
        }
      case 'round_finish':
        expect(rounds[key]!['activated'], true);
        rounds[key]!['finished'] = true;
        if (loseFinish) {
          loseFinish = false;
          throw const MobileApiError('connection_failed');
        }
    }
    return {
      'roundId': key,
      'ok': true,
      'profile': {'id': owner},
    };
  }
}

class RunAccount extends MobileAccount {
  RunAccount(this.server) : super(storagePrefix: 'supabase_instant_test_') {
    id = owner;
    nickname = 'Player';
    wallet = server.wallet();
  }
  final RunServer server;
  @override
  Future<Map<String, dynamic>> synchronizeRun(
    String expected,
    Map<String, dynamic> command,
  ) async {
    expect(expected, id);
    final value = await server.send(command);
    wallet = server.wallet();
    serverNow = energy_fixture.stamp;
    return value;
  }
}

Future<void> flush() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const result = {
  'timeMs': 5000,
  'runDistance': 4,
  'riskCount': 0,
  'hadJump': false,
  'hadHelmet': false,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'obsolete unaccepted protocol row is retained diagnostically without blocking updated client',
    () async {
      final server = RunServer()..refusal = 'update_required';
      final e = EconomyStore();
      await e.load();
      await e.applyServerWallet(
        server.wallet(),
        owner: owner,
        serverNow: energy_fixture.stamp,
      );
      final a = RunAccount(server),
          prefs = await SharedPreferences.getInstance();
      final key = '${a.storagePrefix}instant_rounds_v1_$owner';
      await prefs.setString(
        key,
        jsonEncode([
          {
            'owner': owner,
            'requestId': 'old-protocol',
            'helmet': false,
            'jump': false,
            'cost': 1,
            'rulesRevision': a.rulesRevision,
            'revision': e.energyConfig.revision,
            'result': result,
          },
        ]),
      );
      final j = InstantRoundJournal(
        account: a,
        economy: e,
        published: (_, _) async {},
        recoverResult: (_) => null,
        changed: () {},
      );
      await j.bindOwner();
      j.retry();
      await flush();
      expect(j.hasPending, false);
      expect(j.rulesUpdateRequired, false);
      final retired =
          jsonDecode(prefs.getStringList('${key}_rejected')!.single) as Map;
      expect(retired['requestId'], 'old-protocol');
      expect(retired['rejected'], 'update_required');
      server.refusal = null;
      expect(j.begin(helmet: false, jump: false, cost: 1), isNotNull);
      j.dispose();
      a.dispose();
      e.dispose();
    },
  );
  test(
    'active or completed pending run blocks identity switch until confirmed',
    () async {
      final server = RunServer()..offline = true;
      final e = EconomyStore();
      await e.load();
      await e.applyServerWallet(
        server.wallet(),
        owner: owner,
        serverNow: energy_fixture.stamp,
      );
      final a = RunAccount(server);
      final scores = ScoresStore(account: a, instantEconomy: e);
      await scores.loadLocal();
      expect(
        scores.beginInstantRound(helmet: false, jump: false, cost: 1),
        isNotNull,
      );
      await expectLater(
        a.beforeIdentityChange!(),
        throwsA(isA<MobileApiError>()),
      );
      await scores.recordAttempt(1);
      await expectLater(
        a.beforeIdentityChange!(),
        throwsA(
          isA<MobileApiError>().having(
            (e) => e.code,
            'code',
            'round_delivery_pending',
          ),
        ),
      );
      expect(scores.isAttemptPending(scores.myAttempts.first.id), true);
      server.offline = false;
      await scores.retryPendingResults();
      for (
        var retry = 0;
        retry < 30 && scores.isAttemptPending(scores.myAttempts.first.id);
        retry++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await a.beforeIdentityChange!();
      expect(scores.isAttemptPending(scores.myAttempts.first.id), false);
      scores.dispose();
      a.dispose();
      e.dispose();
    },
  );
  test(
    'real cached wallet and two process restarts never subtract queued costs twice',
    () async {
      final server = RunServer()..offline = true;
      for (var boot = 0; boot < 3; boot++) {
        final e = EconomyStore();
        await e.load();
        if (boot == 0) {
          await e.applyServerWallet(
            server.wallet(),
            owner: owner,
            serverNow: energy_fixture.stamp,
          );
        } else {
          await e.restoreEnergyCacheForOwner(owner);
        }
        final a = RunAccount(server)..wallet = null;
        final s = ScoresStore(
          account: a,
          instantEconomy: e,
          storagePrefix: 'real_cache_',
        );
        await s.loadLocal();
        await flush();
        expect(e.confirmedEnergy, 50);
        expect(e.energy, 50 - boot);
        if (boot < 2) {
          expect(
            s.beginInstantRound(helmet: false, jump: false, cost: 1),
            isNotNull,
          );
          e.completeRound(timeMs: 100, runDistance: 0, riskCount: 0);
          await s.recordAttempt(100);
          await flush();
          expect(e.energy, 49 - boot);
        }
        s.dispose();
        a.dispose();
        e.dispose();
      }
    },
  );
  test(
    'ScoresStore keeps every offline attempt visible and marks both shared after restart',
    () async {
      final server = RunServer()..offline = true;
      var e = EconomyStore();
      await e.load();
      await e.applyServerWallet(
        server.wallet(),
        owner: owner,
        serverNow: energy_fixture.stamp,
      );
      var a = RunAccount(server);
      var s = ScoresStore(
        account: a,
        instantEconomy: e,
        storagePrefix: 'instant_history_',
      );
      await s.loadLocal();
      expect(
        s.beginInstantRound(helmet: false, jump: false, cost: 1),
        isNotNull,
      );
      await s.recordAttempt(1);
      expect(s.myAttempts.length, 1);
      expect(s.isAttemptPending(s.myAttempts.first.id), true);
      expect(
        s.beginInstantRound(helmet: false, jump: false, cost: 1),
        isNotNull,
      );
      await s.recordAttempt(2);
      await flush();
      expect(e.energy, 48);
      expect(s.myAttempts.length, 2);
      s.dispose();
      a.dispose();
      e.dispose();
      e = EconomyStore();
      await e.load();
      await e.applyServerWallet(
        server.wallet(),
        owner: owner,
        serverNow: energy_fixture.stamp,
      );
      a = RunAccount(server);
      s = ScoresStore(
        account: a,
        instantEconomy: e,
        storagePrefix: 'instant_history_',
      );
      await s.loadLocal();
      await flush();
      expect(e.energy, 48);
      expect(s.myAttempts.length, 2);
      server.offline = false;
      await s.retryPendingResults();
      await flush();
      await Future<void>.delayed(const Duration(milliseconds: 25));
      await s.retryPendingResults();
      await flush();
      expect(s.myAttempts.every((a) => a.shared), true);
      expect(server.energy, 48);
      expect(server.spent, 2);
      expect(s.myAttempts.every((a) => !s.isAttemptPending(a.id)), true);
      s.dispose();
      a.dispose();
      e.dispose();
    },
  );
  test(
    'known Supabase owner restores offline from secure credentials without HTTP',
    () async {
      final vault = MemoryVault()
        ..value = jsonEncode({
          'owner': owner,
          'secret': 'local-placeholder',
          'installation': 'local-install',
        });
      final a = MobileAccount(
        vault: vault,
        storagePrefix: 'supabase_android_v1_',
      );
      await a.restoreCachedOwner();
      expect(a.id, owner);
      expect(a.ready, true);
      expect(a.wallet, isNull);
      final unknown = MobileAccount(
        vault: MemoryVault()..value = jsonEncode({'owner': 'invalid'}),
        storagePrefix: 'supabase_android_v1_',
      );
      await unknown.restoreCachedOwner();
      expect(unknown.ready, false);
      a.dispose();
      unknown.dispose();
    },
  );
  Future<EconomyStore> economy(RunServer server) async {
    final e = EconomyStore();
    await e.load();
    await e.applyServerWallet(
      server.wallet(),
      owner: owner,
      serverNow: energy_fixture.stamp,
    );
    return e;
  }

  test(
    'prepared preview ID is used once without charging invalid or duplicate IDs',
    () async {
      final server = RunServer()..offline = true;
      final e = await economy(server), a = RunAccount(server);
      final journal = InstantRoundJournal(
        account: a,
        economy: e,
        published: (_, _) async {},
        recoverResult: (_) => null,
        changed: () {},
      );
      await journal.bindOwner();
      expect(
        journal.begin(
          helmet: false,
          jump: false,
          cost: 1,
          preparedKey: 'invalid',
        ),
        isNull,
      );
      expect(e.energy, 50);
      final key = 'a' * 64;
      expect(
        journal.begin(helmet: false, jump: false, cost: 1, preparedKey: key),
        key,
      );
      await journal.complete(key, result);
      expect(e.energy, 49);
      expect(
        journal.begin(helmet: false, jump: false, cost: 1, preparedKey: key),
        isNull,
      );
      expect(e.energy, 49);
      journal.dispose();
      a.dispose();
      e.dispose();
    },
  );
  for (final cost in [1, 2, 3]) {
    test(
      'last offline attempt costs $cost, zero survives restart and replay',
      () async {
        final server = RunServer()
          ..energy = cost
          ..offline = true;
        var e = await economy(server), a = RunAccount(server);
        var time = 0;
        final sent = <String>[];
        InstantRoundJournal journal() => InstantRoundJournal(
          account: a,
          economy: e,
          published: (_, id) async {
            sent.add(id);
          },
          recoverResult: (_) => null,
          changed: () {},
          elapsedMilliseconds: () => time,
        );
        var j = journal();
        await j.bindOwner();
        final id = j.begin(helmet: cost >= 2, jump: cost == 3, cost: cost)!;
        expect(e.energy, 0);
        for (var tap = 0; tap < 10; tap++) {
          expect(j.begin(helmet: false, jump: false, cost: 1), isNull);
        }
        await j.complete(id, {
          ...result,
          'hadHelmet': cost >= 2,
          'hadJump': cost == 3,
        });
        await flush();
        expect(j.begin(helmet: false, jump: false, cost: 1), isNull);
        expect(server.rounds, isEmpty);
        j.dispose();
        a.dispose();
        e.dispose();
        e = EconomyStore();
        await e.load();
        await e.restoreEnergyCacheForOwner(owner);
        a = RunAccount(server)..wallet = null;
        j = journal();
        await j.bindOwner();
        await flush();
        expect(e.energy, 0);
        expect(j.begin(helmet: false, jump: false, cost: 1), isNull);
        server.offline = false;
        j.retry();
        await flush();
        expect(e.energy, 0);
        expect(server.energy, 0);
        expect(server.spent, cost);
        time = 6000;
        j.retry();
        await flush();
        expect(sent, [id]);
        expect(j.hasPending, false);
        for (var retry = 0; retry < 3; retry++) {
          j.retry();
          await flush();
        }
        expect(server.rounds.length, 1);
        expect(server.spent, cost);
        expect(j.begin(helmet: false, jump: false, cost: 1), isNull);
        // A real authoritative top-up permits play again; reconnect alone does not.
        server.energy = 1;
        await e.applyServerWallet(
          server.wallet(),
          owner: owner,
          serverNow: energy_fixture.stamp,
        );
        expect(j.begin(helmet: true, jump: true, cost: 3), isNull);
        expect(j.begin(helmet: false, jump: false, cost: 1), isNotNull);
        await flush();
        j.dispose();
        a.dispose();
        e.dispose();
      },
    );
  }

  test(
    'server-empty balance replaces a stale offline balance before releasing a refused cost',
    () async {
      final server = RunServer()
        ..energy = 1
        ..offline = true;
      final e = await economy(server), a = RunAccount(server);
      var published = 0;
      final j = InstantRoundJournal(
        account: a,
        economy: e,
        published: (_, _) async {
          published++;
        },
        recoverResult: (_) => null,
        changed: () {},
      );
      await j.bindOwner();
      final id = j.begin(helmet: false, jump: false, cost: 1)!;
      await j.complete(id, result);
      await flush();
      expect(e.energy, 0);
      server.energy = 0;
      server.refusal = 'insufficient_energy';
      server.offline = false;
      j.retry();
      await flush();
      expect(e.confirmedEnergy, 0);
      expect(e.energy, 0);
      expect(j.begin(helmet: false, jump: false, cost: 1), isNull);
      expect(server.commands.any((c) => c['action'] == 'profile'), true);
      expect(published, 0);
      j.dispose();
      a.dispose();
      e.dispose();
    },
  );
  testWidgets('zero energy never starts the field offline', (t) async {
    t.view.physicalSize = const Size(412, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final server = RunServer()
      ..energy = 0
      ..offline = true;
    final e = await economy(server), a = RunAccount(server);
    final scores = ScoresStore(account: a, instantEconomy: e);
    await scores.loadLocal();
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: e),
          ChangeNotifierProvider.value(value: scores),
          Provider.value(value: const GameplayConfig()),
        ],
        child: const GameBoxApp(forceLocale: 'ru'),
      ),
    );
    await t.pump();
    for (var tap = 0; tap < 3; tap++) {
      await t.tap(find.byKey(const ValueKey('arcade-game-field')));
      await t.pump();
      expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).isPlaying, false);
      await t.binding.handlePopRoute();
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(e.energy, 0);
    expect(scores.myAttempts, isEmpty);
    expect(server.commands, isEmpty);
    await t.pumpWidget(const SizedBox());
    scores.dispose();
    a.dispose();
    e.dispose();
  });

  test(
    'offline costs, all results and frozen boosts survive restart and sync exactly once',
    () async {
      final server = RunServer()..offline = true;
      var e = await economy(server), a = RunAccount(server);
      var time = 0;
      final sent = <String>[];
      InstantRoundJournal journal() => InstantRoundJournal(
        account: a,
        economy: e,
        published: (_, id) async {
          sent.add(id);
        },
        recoverResult: (_) => null,
        changed: () {},
        elapsedMilliseconds: () => time,
      );
      var j = journal();
      await j.bindOwner();
      final one = j.begin(helmet: true, jump: false, cost: 2)!;
      expect(e.energy, 48);
      await j.complete(one, {...result, 'hadHelmet': true});
      final two = j.begin(helmet: false, jump: false, cost: 1)!;
      await j.complete(two, result);
      await flush();
      expect(e.energy, 47);
      expect(server.rounds, isEmpty);
      j.dispose();
      e.dispose();
      a.dispose();
      e = await economy(server);
      a = RunAccount(server);
      j = journal();
      await j.bindOwner();
      await flush();
      expect(e.energy, 47);
      expect(j.hasPending, true);
      server.offline = false;
      j.retry();
      await flush();
      expect(server.rounds.length, 2);
      expect(server.energy, 47);
      expect(server.spent, 3);
      expect(e.energy, 47);
      expect(sent, isEmpty);
      time = 6000;
      j.retry();
      await flush();
      expect(sent.toSet(), {one, two});
      expect(j.hasPending, false);
      j.retry();
      await flush();
      expect(server.energy, 47);
      expect(server.spent, 3);
      expect(sent.length, 2);
      j.dispose();
      a.dispose();
      e.dispose();
    },
  );
  test(
    'lost start and finish acknowledgements replay one ID without a second debit',
    () async {
      final server = RunServer()..loseStart = true;
      final e = await economy(server), a = RunAccount(server);
      var time = 0;
      var published = 0;
      final j = InstantRoundJournal(
        account: a,
        economy: e,
        published: (_, _) async {
          published++;
        },
        recoverResult: (_) => null,
        changed: () {},
        elapsedMilliseconds: () => time,
      );
      await j.bindOwner();
      final id = j.begin(helmet: false, jump: false, cost: 1)!;
      await j.complete(id, result);
      await flush();
      expect(server.energy, 49);
      expect(e.energy, 49);
      j.retry();
      await flush();
      expect(server.energy, 49);
      expect(server.spent, 1);
      server.loseFinish = true;
      time = 6000;
      j.retry();
      await flush();
      expect(published, 0);
      j.retry();
      await flush();
      expect(published, 1);
      expect(server.rounds.length, 1);
      expect(e.energy, 49);
      j.dispose();
      a.dispose();
      e.dispose();
    },
  );
  test(
    'server refusal never grants a score or reward, and owner changes cannot send old rows',
    () async {
      final server = RunServer()..refusal = 'insufficient_energy';
      final e = await economy(server), a = RunAccount(server);
      var published = 0;
      final j = InstantRoundJournal(
        account: a,
        economy: e,
        published: (_, _) async {
          published++;
        },
        recoverResult: (_) => null,
        changed: () {},
      );
      await j.bindOwner();
      final id = j.begin(helmet: false, jump: false, cost: 1)!;
      await j.complete(id, result);
      await flush();
      expect(e.energy, 50);
      expect(published, 0);
      expect(j.hasPending, false);
      server.refusal = null;
      server.offline = true;
      final next = j.begin(helmet: false, jump: false, cost: 1)!;
      await j.complete(next, result);
      await flush();
      final count = server.commands.length;
      a.id = 'supabase:22345678-1234-4234-8234-123456789abc';
      server.offline = false;
      j.retry();
      await flush();
      expect(server.commands.length, count);
      j.dispose();
      a.dispose();
      e.dispose();
    },
  );
  test(
    'pending local history recovers a result if the process died between two writes',
    () async {
      final server = RunServer()..offline = true;
      final e = await economy(server), a = RunAccount(server);
      final j = InstantRoundJournal(
        account: a,
        economy: e,
        published: (_, _) async {},
        recoverResult: (_) => null,
        changed: () {},
      );
      await j.bindOwner();
      final id = j.begin(helmet: false, jump: false, cost: 1)!;
      await flush();
      j.dispose();
      var time = 0;
      final sent = <String>[];
      final restored = InstantRoundJournal(
        account: a,
        economy: e,
        published: (_, id) async {
          sent.add(id);
        },
        recoverResult: (key) => key == id ? result : null,
        changed: () {},
        elapsedMilliseconds: () => time,
      );
      server.offline = false;
      await restored.bindOwner();
      await flush();
      time = 6000;
      restored.retry();
      await flush();
      expect(sent, [id]);
      expect(server.energy, 49);
      restored.dispose();
      a.dispose();
      e.dispose();
    },
  );
  for (final movingIdle in [false, true]) {
    testWidgets(
      'touch keeps visible enemies and enters playing while HTTP is unresolved: idleMove=$movingIdle',
      (t) async {
        t.view.physicalSize = const Size(412, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final server = RunServer()..gate = Completer<void>();
        final e = await economy(server), a = RunAccount(server);
        final scores = ScoresStore(
          account: a,
          instantEconomy: e,
          storagePrefix: 'instant_widget_',
        );
        await scores.loadLocal();
        await t.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: e),
              ChangeNotifierProvider.value(value: scores),
              Provider.value(
                value: GameplayConfig(
                  game: GameConfig(
                    startInvulnSec: 60,
                    idleEnemiesMove: movingIdle,
                  ),
                  enemies: const EnemiesConfig(spinDegPerSec: 75),
                ),
              ),
            ],
            child: const GameBoxApp(forceLocale: 'ru'),
          ),
        );
        await t.pump();
        for (var i = 0; i < 40; i++) {
          await t.pump(const Duration(milliseconds: 16));
        }
        GameFieldPainter painter() =>
            t
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('arcade-game-field')),
                    )
                    .painter
                as GameFieldPainter;
        final preview = painter().world;
        final positions = [for (final enemy in preview.enemies) enemy.pos];
        final angles = [for (final enemy in preview.enemies) enemy.orientDeg];
        expect(
          preview.enemies.any((enemy) => enemy.pos != enemy.homePos),
          true,
        );
        await t.tap(find.byKey(const ValueKey('arcade-game-field')));
        await t.pump();
        expect(painter().world, same(preview));
        expect([for (final enemy in preview.enemies) enemy.pos], positions);
        expect([for (final enemy in preview.enemies) enemy.orientDeg], angles);
        expect(scores.activeInstantRoundKey, isNotNull);
        expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).isPlaying, true);
        await t.pump(const Duration(milliseconds: 32));
        await t.pump(const Duration(milliseconds: 16));
        expect(
          t.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(),
          greaterThan(0),
        );
        expect(e.energy, 49);
        expect(find.textContaining('Подготавливаем'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await t.pump();
        final paused = t.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs();
        server.gate!.complete();
        await t.pump();
        await t.pump(const Duration(seconds: 1));
        expect(t.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(), paused);
        await t.pumpWidget(const SizedBox());
        scores.dispose();
        a.dispose();
        e.dispose();
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      },
    );
  }
}
