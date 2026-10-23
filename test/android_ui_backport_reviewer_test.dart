// Independent reviewer fixtures: no real HTTP, device, purchases or RC writes.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/energy_presentation.dart';
import 'package:game_box/data/instant_round_journal.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/domain/economy_config.dart';

import 'mobile_account_test.dart' show MemoryVault;
import 'simple_energy_test.dart' as fixture;

const _owner = 'android:1';
const _other = 'android:2';
const _result = <String, dynamic>{
  'timeMs': 100,
  'runDistance': 20,
  'riskCount': 3,
  'hadJump': false,
  'hadHelmet': false,
};

Future<void> _drain() async {
  for (var n = 0; n < 40; n++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<EconomyStore> _economy({int balance = 50}) async {
  final e = EconomyStore(
    config: const EconomyConfig(runRewardEvery: 10, riskRewardEvery: 2),
  );
  await e.load();
  await e.applyServerWallet(
    fixture.simpleWallet(balance: balance),
    owner: _owner,
    serverNow: fixture.stamp,
  );
  return e;
}

class _Disk extends InMemorySharedPreferencesStore {
  _Disk() : super.empty();
  bool Function(String, Object)? reject;
  bool Function(String, Object)? block;
  Completer<void>? entered, release;
  int journalWrites = 0;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.contains('instant_rounds_v1_')) journalWrites++;
    if (block?.call(key, value) == true) {
      if (entered?.isCompleted == false) entered!.complete();
      await release?.future;
    }
    if (reject?.call(key, value) == true) return false;
    return super.setValue(type, key, value);
  }
}

class _RunAccount extends MobileAccount {
  _RunAccount() : super(storagePrefix: 'reviewer_backport_') {
    id = _owner;
    nickname = 'Player';
    wallet = fixture.simpleWallet();
    serverNow = fixture.stamp;
  }

  int balance = 50, reward = 3;
  String? refusal;
  String? finishRefusal;
  bool loseFinishOnce = false;
  final commands = <String>[];
  final starts = <String>{}, finishes = <String>{};

  @override
  Future<Map<String, dynamic>> synchronizeRun(
    String expectedOwner,
    Map<String, dynamic> command,
  ) async {
    expect(expectedOwner, id);
    final action = command['action'] as String;
    commands.add(action);
    if (refusal != null && action != 'profile') {
      throw MobileApiError(refusal!);
    }
    if (action == 'round_finish' && finishRefusal != null) {
      throw MobileApiError(finishRefusal!);
    }
    final key = (command['requestId'] ?? command['roundId']) as String?;
    if (action == 'round_start' && starts.add(key!)) balance--;
    if (action == 'round_finish') {
      if (finishes.add(key!)) balance += reward;
      if (loseFinishOnce) {
        loseFinishOnce = false;
        throw const MobileApiError('connection_failed');
      }
    }
    wallet = fixture.simpleWallet(balance: balance);
    return {
      'ok': true,
      'roundId': key,
      if (action == 'round_finish') 'energyReward': reward,
      'profile': {'id': expectedOwner},
    };
  }
}

InstantRoundJournal _journal(
  _RunAccount a,
  EconomyStore e, {
  bool Function()? deliver,
  Future<void> Function(String, String)? published,
}) {
  var elapsed = 0;
  return InstantRoundJournal(
    account: a,
    economy: e,
    published: published ?? (_, _) async {},
    recoverResult: (_) => null,
    changed: () {},
    mayDeliver: deliver ?? () => false,
    elapsedMilliseconds: () => elapsed += 10000,
  );
}

class _WalletServer {
  int balance = 50, version = 1;
  bool offline = false;
  String? refusal;
  Completer<void>? entered, gate;
  final operations = <String>[];
  final granted = <String>{};

  http.Response profile({String owner = _owner, String? operationId}) =>
      http.Response(
        jsonEncode({
          'ok': true,
          'serverNow': fixture.stamp,
          if (operationId != null)
            'energyGrant': {'operationId': operationId, 'amount': 30},
          'profile': {
            'id': owner,
            'nickname': 'Player',
            'walletVersion': version,
            'wallet': fixture.simpleWallet(
              balance: balance,
              nextAt: granted.isEmpty ? 0 : fixture.stamp + 28800000,
            ),
          },
        }),
        200,
      );

  Future<http.Response> send(http.Request request) async {
    final body = jsonDecode(request.body) as Map;
    if (body['action'] != 'wallet_operation') return profile();
    final id = body['operationId'] as String;
    operations.add(id);
    if (entered?.isCompleted == false) entered!.complete();
    await gate?.future;
    if (offline) throw const MobileApiError('connection_failed');
    if (refusal != null) {
      return http.Response(jsonEncode({'ok': false, 'error': refusal}), 409);
    }
    if (granted.add(id)) {
      balance += 30;
      version++;
    }
    return profile(operationId: id);
  }
}

Future<(MobileAccount, EconomyStore, MobileWalletBridge)> _wallet(
  _WalletServer server,
) async {
  final a = MobileAccount(
    vault: MemoryVault(),
    client: MockClient(server.send),
  );
  final e = await _economy();
  final bridge = MobileWalletBridge(a, e);
  await bridge.load();
  await a.load();
  await bridge.flush();
  return (a, e, bridge);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('reviewer named presentation ledger', () {
    test('profile ahead of ACK does not double two provisional grants', () {
      final p = EnergyPresentation()..wallet(_owner, 50);
      expect(p.begin('round:r', 3), true);
      expect(p.begin('wallet:w', 30), true);
      p.wallet(_owner, 83); // Profile already includes both lost ACKs.
      expect(p.balance, 83);
      p.settle('round:r', amount: 3);
      expect(p.balance, 83);
      p.settle('wallet:w', amount: 30);
      expect(p.balance, 83);
      expect(p.begin('round:r', 3), false);
      expect(p.pending, false);
    });

    test('partial accepted correction applies before unrelated ACK', () {
      final p = EnergyPresentation()..wallet(_owner, 50);
      p.begin('round:r', 5);
      p.begin('wallet:w', 30);
      p.wallet(_owner, 52);
      p.settle('round:r', amount: 2);
      expect(p.balance, 82);
      p.wallet(_owner, 82);
      p.settle('wallet:w', amount: 30);
      expect(p.balance, 82);
    });

    test(
      'terminal refusal removes its grant and never invents cost refund',
      () {
        final p = EnergyPresentation()..wallet(_owner, 49);
        p.begin('round:r', 3);
        p.begin('wallet:w', 30);
        p.settle('round:r', rejected: true);
        expect(p.balance, 79);
        p.wallet(_owner, 79);
        p.settle('wallet:w', amount: 30);
        expect(p.balance, 79);
        expect(p.credits.first.rejected, true);
      },
    );

    test(
      'reservation debit is exactly once despite charge and stale profile',
      () {
        final p = EnergyPresentation()..wallet(_owner, 50);
        p.begin('wallet:w', 30);
        p.debit('run:a', 3);
        p.debit('run:a', 3);
        p.wallet(_owner, 47);
        expect(p.balance, 77);
        p.wallet(_owner, 77);
        p.settle('wallet:w', amount: 30);
        expect(p.balance, 77);
      },
    );

    test('quiet restore and owner replacement never replay cached credits', () {
      final p = EnergyPresentation()..wallet(_owner, 83);
      p.begin('round:restored', 0, animate: false);
      p.wallet(_owner, 83);
      expect(p.balance, 83);
      expect(p.credits.single.animate, false);
      p.settle('round:restored', amount: 3);
      expect(p.balance, 83);
      p.wallet(_other, 7);
      expect(p.balance, 7);
      expect(p.credits, isEmpty);
      p.settle('round:restored', amount: 3);
      expect(p.balance, 7);
    });
  });

  group('reviewer actual InstantRoundJournal', () {
    test(
      'durable result uses start divisors, not newly applied config',
      () async {
        final e = await _economy();
        final a = _RunAccount();
        final j = _journal(a, e);
        addTearDown(() {
          j.dispose();
          a.dispose();
          e.dispose();
        });
        await j.bindOwner();
        final id = j.begin(helmet: false, jump: false, cost: 1)!;
        e.applyConfig(
          const EconomyConfig(runRewardEvery: 1, riskRewardEvery: 1),
        );
        await j.complete(id, _result);
        expect(e.energy, 49);
        expect(e.confirmedEnergy, 50);
        expect(e.presentedEnergy, 52);
        expect(e.energyPresentation.credits.single.amount, 3);
        final prefs = await SharedPreferences.getInstance();
        final rows =
            jsonDecode(
                  prefs.getString(
                    '${a.storagePrefix}instant_rounds_v1_$_owner',
                  )!,
                )
                as List;
        expect(rows.single['rewardPresented'], true);
        expect(rows.single['presentationAmount'], 3);
        expect(a.commands, isEmpty);
      },
    );

    test(
      'false result write does not animate and identical retry persists',
      () async {
        final disk = _Disk();
        SharedPreferencesStorePlatform.instance = disk;
        final e = await _economy();
        final a = _RunAccount();
        final j = _journal(a, e);
        addTearDown(() {
          j.dispose();
          a.dispose();
          e.dispose();
        });
        await j.bindOwner();
        final id = j.begin(helmet: false, jump: false, cost: 1)!;
        await _drain();
        disk.reject = (key, value) =>
            key.contains('instant_rounds_v1_') &&
            value is String &&
            value.contains('"result":');
        await expectLater(j.complete(id, _result), throwsA(isA<StateError>()));
        expect(e.energyPresentation.credits, isEmpty);
        disk.reject = null;
        final before = disk.journalWrites;
        await j.complete(id, _result);
        expect(disk.journalWrites, greaterThan(before));
        expect(e.energyPresentation.credits.single.amount, 3);
        expect(e.presentedEnergy, 52);
      },
    );

    test(
      'owner switch during durable complete cannot credit replacement owner',
      () async {
        final disk = _Disk();
        SharedPreferencesStorePlatform.instance = disk;
        final e = await _economy();
        final a = _RunAccount();
        final j = _journal(a, e);
        addTearDown(() {
          j.dispose();
          a.dispose();
          e.dispose();
        });
        await j.bindOwner();
        final id = j.begin(helmet: false, jump: false, cost: 1)!;
        await _drain();
        disk.entered = Completer<void>();
        disk.release = Completer<void>();
        disk.block = (key, value) =>
            key.contains('instant_rounds_v1_') &&
            value is String &&
            value.contains('"result":');
        final completed = j.complete(id, _result);
        await disk.entered!.future;
        a.id = _other;
        await e.applyServerWallet(
          fixture.simpleWallet(balance: 7),
          owner: _other,
          serverNow: fixture.stamp,
        );
        disk.release!.complete();
        await completed;
        expect(e.energyOwner, _other);
        expect(e.energyPresentation.credits, isEmpty);
        expect(e.presentedEnergy, 7);
      },
    );

    test(
      'lost finish ACK retries same proof and does not double UI or money',
      () async {
        final e = await _economy();
        final a = _RunAccount()..loseFinishOnce = true;
        var deliver = false, published = 0;
        final j = _journal(
          a,
          e,
          deliver: () => deliver,
          published: (_, _) async {
            published++;
          },
        );
        addTearDown(() {
          j.dispose();
          a.dispose();
          e.dispose();
        });
        await j.bindOwner();
        final id = j.begin(helmet: false, jump: false, cost: 1)!;
        await j.complete(id, _result);
        deliver = true;
        j.retry();
        await _drain();
        expect(j.hasPending, true);
        expect(a.balance, 52);
        expect(e.presentedEnergy, 52);
        // A generic newer snapshot already contains the lost finish grant.
        await e.applyServerWallet(
          fixture.simpleWallet(balance: 52),
          owner: _owner,
          serverNow: fixture.stamp,
        );
        expect(e.presentedEnergy, 52);
        j.retry();
        await _drain();
        expect(j.hasPending, false);
        expect(e.energy, 52);
        expect(e.presentedEnergy, 52);
        expect(e.energyPresentation.credits, hasLength(1));
        expect(a.starts, hasLength(1));
        expect(a.finishes, hasLength(1));
        expect(published, 1);
      },
    );

    test(
      'terminal finish refusal removes preview without refunding paid cost',
      () async {
        final e = await _economy();
        final a = _RunAccount()..finishRefusal = 'result_metrics_invalid';
        var deliver = false;
        final j = _journal(a, e, deliver: () => deliver);
        addTearDown(() {
          j.dispose();
          a.dispose();
          e.dispose();
        });
        await j.bindOwner();
        final id = j.begin(helmet: false, jump: false, cost: 1)!;
        await j.complete(id, _result);
        expect(e.presentedEnergy, 52);
        deliver = true;
        j.retry();
        await _drain();
        expect(j.hasPending, false);
        expect(e.energy, 49);
        expect(e.presentedEnergy, 49);
        expect(e.energyPresentation.credits.single.rejected, true);
        expect(a.finishes, isEmpty);
      },
    );

    test(
      'reloaded completed row is quiet when cached wallet includes its ACK',
      () async {
        final a = _RunAccount();
        final e = await _economy(balance: 52);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '${a.storagePrefix}instant_rounds_v1_$_owner',
          jsonEncode([
            {
              'owner': _owner,
              'requestId': 'restored-result',
              'helmet': false,
              'jump': false,
              'cost': 1,
              'charged': true,
              'roundId': 'restored-result',
              'activated': true,
              'proofVersion': 1,
              'rulesRevision': a.rulesRevision,
              'result': _result,
              'rewardPresented': true,
              'presentationAmount': 3,
            },
          ]),
        );
        final j = _journal(a, e);
        addTearDown(() {
          j.dispose();
          a.dispose();
          e.dispose();
        });
        await j.bindOwner();
        expect(e.energy, 52);
        expect(e.presentedEnergy, 52);
        expect(e.energyPresentation.credits.single.amount, 0);
        expect(e.energyPresentation.credits.single.animate, false);
        expect(j.hasPending, true);
        expect(a.commands, isEmpty);
      },
    );
  });

  group('reviewer actual MobileWalletBridge', () {
    test(
      'offline repeated tap reuses durable ID and one visual grant',
      () async {
        final server = _WalletServer()..offline = true;
        final (a, e, b) = await _wallet(server);
        addTearDown(() {
          a.dispose();
          e.dispose();
        });
        await expectLater(
          e.claimSimpleEnergyBonus(),
          throwsA(isA<MobileApiError>()),
        );
        expect(e.energy, 50);
        expect(e.presentedEnergy, 80);
        await expectLater(
          e.claimSimpleEnergyBonus(),
          throwsA(isA<MobileApiError>()),
        );
        expect(e.energyPresentation.credits, hasLength(1));
        expect(server.operations.toSet(), hasLength(1));
        server.offline = false;
        await b.flush();
        expect(server.granted, hasLength(1));
        expect(e.energy, 80);
        expect(e.presentedEnergy, 80);
        expect(e.energyPresentation.pending, false);
      },
    );

    test(
      'failed durable enqueue does not POST or start presentation',
      () async {
        final disk = _Disk();
        SharedPreferencesStorePlatform.instance = disk;
        final server = _WalletServer();
        final (a, e, b) = await _wallet(server);
        addTearDown(() {
          a.dispose();
          e.dispose();
        });
        disk.reject = (key, value) =>
            key.endsWith('mobile_wallet_operations_v1');
        await expectLater(
          e.claimSimpleEnergyBonus(),
          throwsA(isA<MobileApiError>()),
        );
        expect(server.operations, isEmpty);
        expect(e.energyPresentation.credits, isEmpty);
        disk.reject = null;
        await e.claimSimpleEnergyBonus();
        await b.flush();
        expect(server.granted, hasLength(1));
        expect(e.energyPresentation.credits, hasLength(1));
        expect(e.presentedEnergy, 80);
      },
    );

    test(
      'false dequeue retries receipt ID without another grant or projection',
      () async {
        final disk = _Disk();
        SharedPreferencesStorePlatform.instance = disk;
        final server = _WalletServer();
        final (a, e, b) = await _wallet(server);
        addTearDown(() {
          a.dispose();
          e.dispose();
        });
        disk.reject = (key, value) =>
            key.endsWith('mobile_wallet_operations_v1') && value == '[]';
        await expectLater(
          e.claimSimpleEnergyBonus(),
          throwsA(isA<MobileApiError>()),
        );
        expect(e.energy, 80);
        expect(e.presentedEnergy, 80);
        disk.reject = null;
        await b.flush();
        expect(server.operations.length, greaterThanOrEqualTo(2));
        expect(server.operations.toSet(), hasLength(1));
        expect(server.granted, hasLength(1));
        expect(e.energyPresentation.credits, hasLength(1));
        expect(e.presentedEnergy, 80);
      },
    );

    test(
      'terminal refusal corrects only local projection and retires command',
      () async {
        final server = _WalletServer()..refusal = 'bonus_not_ready';
        final (a, e, b) = await _wallet(server);
        addTearDown(() {
          a.dispose();
          e.dispose();
        });
        await expectLater(
          e.claimSimpleEnergyBonus(),
          throwsA(isA<MobileApiError>()),
        );
        await b.flush();
        expect(e.energy, 50);
        expect(e.presentedEnergy, 50);
        expect(e.energyPresentation.credits.single.rejected, true);
        expect(e.energyPresentation.pending, false);
        final prefs = await SharedPreferences.getInstance();
        expect(
          jsonDecode(prefs.getString('mobile_wallet_operations_v1')!),
          isEmpty,
        );
        expect(server.granted, isEmpty);
      },
    );

    test(
      'late previous-owner HTTP cannot animate or credit new owner',
      () async {
        final server = _WalletServer();
        final (a, e, _) = await _wallet(server);
        addTearDown(() {
          a.dispose();
          e.dispose();
        });
        server.entered = Completer<void>();
        server.gate = Completer<void>();
        final operation = e.claimSimpleEnergyBonus();
        // Register the error handler before releasing the deferred request.
        final assertion = expectLater(
          operation,
          throwsA(isA<MobileApiError>()),
        );
        await server.entered!.future;
        expect(e.presentedEnergy, 80);
        a.id = _other;
        await e.applyServerWallet(
          fixture.simpleWallet(balance: 7),
          owner: _other,
          serverNow: fixture.stamp,
        );
        server.gate!.complete();
        await assertion;
        expect(a.id, _other);
        expect(e.energyOwner, _other);
        expect(e.energy, 7);
        expect(e.presentedEnergy, 7);
        expect(e.energyPresentation.credits, isEmpty);
      },
    );
  });
}
