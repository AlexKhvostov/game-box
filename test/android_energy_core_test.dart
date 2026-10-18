import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/domain/android_energy.dart';
import 'package:game_box/domain/arcade_rules.dart';
import 'package:game_box/domain/economy_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mobile_account_test.dart' show MemoryVault;

Map<String, dynamic> wallet({int energy = 20}) => {
  'energyVersion': 2,
  'energy': energy,
  'energyConfig': const AndroidEnergyConfig(enabled: true).toJson(),
  'batteries': [
    const EnergyBattery(
      id: 'free',
      startedAtMs: 0,
      capacity: 20,
      durationMs: 43200000,
      initialUnits: 20,
    ).toJson(),
  ],
  'claimed': <String>[],
  'unlocked': <String>[],
  'energyGoogleReady': true,
  'energyAgeCompleted': true,
};

http.Response profile(Map<String, dynamic> value, {int version = 1}) =>
    http.Response(
      jsonEncode({
        'ok': true,
        'profile': {
          'id': 'android:1',
          'nickname': 'user00000001',
          'walletVersion': version,
          'serverNow': 0,
          'wallet': value,
        },
      }),
      200,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Android offline defaults and prepared offers use eight-hour charge',
    () {
      for (final config in [
        const AndroidEnergyConfig(),
        AndroidEnergyConfig.fromJson({}),
        AndroidEnergyConfig.fromJson({
          'subscriptions': [
            {'id': 'energy_batteries_2_v1', 'batteryCount': 2},
            {'id': 'energy_batteries_5_v1', 'batteryCount': 5},
          ],
        }),
      ]) {
        expect(config.chargeHours, 8);
        expect(config.batteryCapacity, 20);
        expect(config.durationMs, 28800000);
        expect(config.batteryCapacity * 24 / config.chargeHours, 60);
        expect(config.subscriptions.map((e) => e.chargeHours), [8, 8]);
        expect(
          config.subscriptions.map(
            (offer) =>
                config.batteryCapacity * 24 / config.chargeHours +
                offer.additionalBatteries *
                    offer.batteryCapacity *
                    24 /
                    offer.chargeHours,
          ),
          [120, 300],
        );
        final decoded = AndroidEnergyConfig.fromJson(config.toJson());
        expect(decoded.chargeHours, 8);
        expect(decoded.subscriptions.map((e) => e.chargeHours), [8, 8]);
      }
    },
  );

  test(
    'Missing cycle duration uses eight hours; explicit server12 is retained',
    () {
      final missing = EnergyBattery.fromJson({'id': 'free'});
      final old = EnergyBattery.fromJson({
        'id': 'paid',
        'durationMs': 43200000,
      });
      final atEight = DateTime.fromMillisecondsSinceEpoch(28800000);
      expect(missing.durationMs, 28800000);
      expect(missing.unitsAt(atEight), 20);
      expect(old.durationMs, 43200000);
      expect(old.unitsAt(atEight), 13);
      expect(EnergyBattery.fromJson(old.toJson()).durationMs, 43200000);
    },
  );

  test(
    'Isolated preview cycle follows its eight-hour config for1/2/5 cells',
    () async {
      for (final count in [1, 2, 5]) {
        final store = EconomyStore(storagePrefix: 'charge8_preview_$count');
        await store.load();
        await store.enableEnergyPreview(batteryCount: count, initialUnits: 0);
        expect(store.energyConfig.chargeHours, 8);
        expect(store.energyBatteries, hasLength(count));
        for (final battery in store.energyBatteries) {
          expect(battery.durationMs, store.energyConfig.durationMs);
          expect(battery.capacity, 20);
        }
        store.dispose();
      }
    },
  );

  test(
    'battery boundaries, cap, rollback and independent newly connected cells',
    () {
      const empty = EnergyBattery(
        id: 'paid',
        startedAtMs: 0,
        capacity: 20,
        durationMs: 43200000,
      );
      DateTime at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);
      expect(empty.unitsAt(at(-1000)), 0);
      expect(empty.unitsAt(at(2160000 - 1)), 0);
      expect(empty.unitsAt(at(2160000)), 1);
      expect(empty.unitsAt(at(43200000 - 1)), 19);
      expect(empty.unitsAt(at(43200000)), 20);
      expect(empty.unitsAt(at(86400000)), 20);
      expect(empty.remainingAt(at(43200000)), Duration.zero);
      const full = EnergyBattery(
        id: 'free',
        startedAtMs: 0,
        capacity: 20,
        durationMs: 43200000,
        initialUnits: 20,
      );
      expect(full.unitsAt(at(0)) + empty.unitsAt(at(0)), 20);
      expect(full.remainingAt(at(0)), Duration.zero);
      expect(empty.remainingAt(at(0)), const Duration(hours: 12));
    },
  );

  test(
    'cycle freezes old capacity/duration despite changing current config',
    () {
      final old = EnergyBattery.fromJson({
        'id': 'free',
        'startedAt': 0,
        'capacity': 20,
        'durationMs': 43200000,
        'revision': 'old',
      });
      final next = AndroidEnergyConfig.fromJson({
        'batteryCapacity': 40,
        'chargeHours': 6,
      });
      expect(next.batteryCapacity, 40);
      expect(old.unitsAt(DateTime.fromMillisecondsSinceEpoch(21600000)), 10);
      expect(old.capacity, 20);
    },
  );

  test(
    'remote prepared version works and SKU composition cannot be changed',
    () {
      final parsed = AndroidEnergyConfig.fromJson({
        'packages': [
          {'id': 'energy_250_v2', 'energy': 250},
          {'id': 'energy_250_v2', 'energy': 250},
          {'id': 'energy_100_v1', 'energy': 999},
          {'id': 'malicious', 'energy': 1},
        ],
        'subscriptions': [
          {'id': 'energy_batteries_5_v2', 'batteryCount': 5, 'periodDays': 7},
          {'id': 'energy_batteries_2_v2', 'batteryCount': 5},
          {'id': 'energy_batteries_5_v3', 'batteryCount': 5, 'periodDays': 14},
        ],
      });
      expect(parsed.packages.map((e) => e.id), ['energy_250_v2']);
      expect(parsed.subscriptions.map((e) => e.id), ['energy_batteries_5_v2']);
      expect(parsed.subscriptions.single.additionalBatteries, 4);
      expect(PlayBillingService.isEnergyProduct('energy_250_v2'), isTrue);
    },
  );

  test(
    'local remote enable alone never migrates or activates legacy wallet',
    () async {
      final store = EconomyStore(
        config: const EconomyConfig(
          androidEnergyV2: AndroidEnergyConfig(enabled: true),
        ),
      );
      await store.load();
      expect(store.energyEnabled, isFalse);
      await store.applyServerWallet({
        'lives': 10,
        'tokens': 40,
        'claimed': [],
        'unlocked': [],
      });
      expect(store.energyEnabled, isFalse);
      expect(store.lives, 10);
      expect(store.tokens, 40);
    },
  );

  test(
    'server-confirmed V2 operations credit only after confirmation; practice never earns',
    () async {
      final store = EconomyStore(
        now: () => DateTime.fromMillisecondsSinceEpoch(0),
      );
      await store.load();
      await store.applyServerWallet(wallet());
      store.setHelmetSelected(true);
      store.setJumpSelected(true);
      expect(store.attemptEnergyCost, 3);
      expect(store.spendEnergyForPractice(), isTrue);
      expect(store.energy, 17);
      store.completeRound(timeMs: 50000, runDistance: 100000, riskCount: 100);
      expect(store.energy, 17);
      expect(store.confirmedEnergy, 20);
      expect(store.unlockedEarnIds, isEmpty);
      expect(store.grantCrystals(100), 0);
      store.sendEnergyOperation = (kind, args) async {
        expect(store.confirmedEnergy, 20);
        expect(kind, 'energy_claim');
        await store.applyServerWallet(wallet(energy: 40));
      };
      await store.claimEnergy();
      expect(store.energy, 40);
      expect(store.accumulatedEnergy, 20); // Fixture, not a local reset.
      expect(store.energyRewardReady('age'), isTrue);
      await store.applyServerWallet(
        wallet()
          ..['claimed'] = ['energy_age', 'energy_google', 'energy_feedback'],
      );
      expect(store.energyRewardClaimed('age'), isTrue);
      expect(store.energyRewardReady('google'), isFalse);
      expect(store.energyRewardClaimed('feedback'), isTrue);
    },
  );

  test(
    'feedback length counts Unicode code points and never sends actual age',
    () async {
      final store = EconomyStore();
      await store.load();
      await store.applyServerWallet({...wallet(), 'feedbackSpentEnergy': 100});
      final sent = <Map<String, dynamic>>[];
      store.sendEnergyOperation = (kind, args) async =>
          sent.add({'kind': kind, ...args});
      await expectLater(
        store.sendEnergyFeedback('😀' * 19),
        throwsArgumentError,
      );
      await store.sendEnergyFeedback('  ${'😀' * 20}  ', rating: 1);
      await store.completeEnergyAge();
      expect(sent[0]['comment'], '😀' * 20);
      expect(sent[0]['rating'], 1);
      expect(sent[1], {'kind': 'energy_age_completed'});
    },
  );

  test(
    'new rewards are one energy per old threshold, not migration multiplier',
    () {
      const config = EconomyConfig(
        riskRewardEvery: 8,
        runRewardEvery: 400,
        riskRewardTokens: 3,
        runRewardTokens: 4,
      );
      expect(ArcadeRules.roundReward(config, 800, 16), 14);
      expect(ArcadeRules.energyRoundReward(config, 800, 16), 4);
    },
  );

  test('localized discounts depend on real Google currency prices', () {
    final billing = PlayBillingService(MobileAccount());
    const config = AndroidEnergyConfig();
    expect(billing.energyDiscount('energy_250_v1', config), isNull);
    void price(String id, double value, {String currency = 'USD'}) =>
        billing.products[id] = ProductDetails(
          id: id,
          title: id,
          description: id,
          price: '$value $currency',
          rawPrice: value,
          currencyCode: currency,
        );
    price('energy_100_v1', 2);
    price('energy_250_v1', 4);
    price('energy_500_v1', 6);
    price('energy_1000_v1', 9);
    expect(billing.energyDiscount('energy_250_v1', config), 20);
    expect(billing.energyDiscount('energy_500_v1', config), 40);
    expect(billing.energyDiscount('energy_1000_v1', config), 55);
    price('energy_250_v1', 4, currency: 'EUR');
    expect(billing.energyDiscount('energy_250_v1', config), isNull);
    price('energy_batteries_2_v1', 1);
    price('energy_batteries_5_v1', 3);
    expect(billing.batteryDiscount('energy_batteries_5_v1', config), 25);
    billing.dispose();
  });

  test(
    'lost start acknowledgement survives process restart and config revision change',
    () async {
      final vault = MemoryVault();
      final starts = <Map<String, dynamic>>[];
      var drop = true;
      final client = MockClient((request) async {
        final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        if (body['action'] == 'round_start') {
          final persisted = jsonDecode(vault.value!) as Map;
          expect(
            persisted['pendingRoundStart']['requestId'],
            body['requestId'],
          );
          starts.add(body);
          if (drop) throw StateError('ack lost');
          return http.Response(
            jsonEncode({'ok': true, 'roundId': 'same-round'}),
            200,
          );
        }
        return profile(wallet());
      });
      final first = MobileAccount(
        vault: vault,
        client: client,
        rulesRevision: 'old',
      );
      await first.load();
      expect(
        await first.startRound(helmet: true, economyRevision: 'r1'),
        isNull,
      );
      first.dispose();
      drop = false;
      final restarted = MobileAccount(
        vault: vault,
        client: client,
        rulesRevision: 'new',
      );
      await restarted.load();
      expect(
        await restarted.startRound(jump: true, economyRevision: 'r2'),
        'same-round',
      );
      expect(starts[1]['requestId'], starts[0]['requestId']);
      expect(starts[1]['revision'], 'r1');
      expect(starts[1]['helmet'], true);
      expect(starts[1]['jump'], false);
      expect(starts[1]['rulesRevision'], 'old');
      restarted.dispose();
    },
  );

  test(
    'V2 claim queue is persisted with owner and retries same operation ID',
    () async {
      var offline = true;
      final ids = <String>[];
      var version = 1;
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (body['action'] == 'wallet_operation') {
            ids.add(body['operationId'] as String);
            final prefs = await SharedPreferences.getInstance();
            final pending =
                jsonDecode(prefs.getString('mobile_wallet_operations_v1')!)
                    as List;
            expect(pending.single['owner'], 'android:1');
            if (offline) throw StateError('offline');
            version++;
          }
          return profile(
            wallet(energy: version == 1 ? 20 : 40),
            version: version,
          );
        }),
      );
      final store = EconomyStore();
      await store.load();
      final bridge = MobileWalletBridge(account, store);
      await bridge.load();
      await account.load();
      await bridge.flush();
      await expectLater(store.claimEnergy(), throwsStateError);
      expect(store.energy, 20);
      offline = false;
      await bridge.flush();
      expect(ids.toSet(), hasLength(1));
      expect(store.energy, 40);
    },
  );
  test(
    'failed secure writes never allow a retry to send an undurable start',
    () async {
      var starts = 0;
      final vault = MemoryVault();
      final account = MobileAccount(
        vault: vault,
        client: MockClient((request) async {
          if ((jsonDecode(request.body) as Map)['action'] == 'round_start') {
            starts++;
          }
          return profile(wallet());
        }),
      );
      await account.load();
      vault.failWrite = true;
      expect(await account.startRound(), isNull);
      expect(await account.startRound(), isNull);
      expect(starts, 0);
      account.dispose();
    },
  );

  test(
    'activated receipt is not replayed as a second free game after restart',
    () async {
      final ids = <String>[];
      var drop = true;
      var activated = true;
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (body['action'] == 'round_start') {
            ids.add(body['requestId'] as String);
            if (drop) throw StateError('lost ack');
            return http.Response(
              jsonEncode({
                'ok': true,
                'roundId': 'r',
                'activated': activated,
                'finished': false,
              }),
              200,
            );
          }
          return profile(wallet());
        }),
      );
      await account.load();
      expect(await account.startRound(), isNull);
      drop = false;
      expect(await account.startRound(), isNull);
      expect(account.roundError, 'round_already_started');
      expect(account.pendingRoundRequestId, isNull);
      activated = false;
      expect(await account.startRound(), 'r');
      expect(ids[0], ids[1]);
      expect(ids[2], isNot(ids[1]));
      account.dispose();
    },
  );

  test(
    'late wallet reply cannot switch back to an earlier restored owner',
    () async {
      final response = Completer<http.Response>();
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          if ((jsonDecode(request.body) as Map)['action'] ==
              'wallet_operation') {
            return response.future;
          }
          return profile(wallet());
        }),
      );
      await account.load();
      final job = account.walletOperation(
        account.operationId(),
        'energy_claim',
        {},
      );
      await Future<void>.delayed(Duration.zero);
      account.id = 'android:2';
      final rejected = expectLater(job, throwsA(isA<MobileApiError>()));
      response.complete(profile(wallet(energy: 999)));
      await rejected;
      expect(account.id, 'android:2');
      expect(account.wallet!['energy'], 20);
      account.dispose();
    },
  );

  test(
    'unconfirmed legacy rejection is archived, never silently dropped or credited',
    () async {
      SharedPreferences.setMockInitialValues({
        'mobile_wallet_owner_v1': 'android:1',
        'mobile_wallet_operations_v1': jsonEncode([
          {
            'id': 'old-id',
            'owner': 'android:1',
            'kind': 'earn',
            'args': {'id': 'survive_10s'},
          },
        ]),
      });
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          if ((jsonDecode(request.body) as Map)['action'] ==
              'wallet_operation') {
            return http.Response(
              jsonEncode({'ok': false, 'error': 'update_required'}),
              409,
            );
          }
          return profile(wallet());
        }),
      );
      final store = EconomyStore();
      await store.load();
      final bridge = MobileWalletBridge(account, store);
      await bridge.load();
      await account.load();
      await bridge.flush();
      final prefs = await SharedPreferences.getInstance();
      final archived =
          jsonDecode(prefs.getStringList('mobile_wallet_deferred_v2')!.single)
              as Map;
      expect(archived['owner'], 'android:1');
      expect(archived['id'], 'old-id');
      expect(archived['kind'], 'earn');
      expect(archived['args'], {'id': 'survive_10s'});
      expect(archived['reason'], 'update_required');
      expect(store.energy, 20);
      account.dispose();
    },
  );

  test(
    'expired paid cell display freezes at effective entitlement boundary',
    () {
      const cell = EnergyBattery(
        id: 'paid',
        startedAtMs: 0,
        capacity: 20,
        durationMs: 43200000,
        activeUntilMs: 21600000,
      );
      expect(cell.unitsAt(DateTime.fromMillisecondsSinceEpoch(21600000)), 10);
      expect(cell.unitsAt(DateTime.fromMillisecondsSinceEpoch(86400000)), 10);
      expect(cell.percentAt(DateTime.fromMillisecondsSinceEpoch(86400000)), 50);
    },
  );

  test(
    'subscription advertised rate uses immutable offer, not free cell current config',
    () {
      final config = AndroidEnergyConfig.fromJson({
        'batteryCapacity': 40,
        'chargeHours': 6,
        'subscriptions': [
          {
            'id': 'energy_batteries_5_v2',
            'batteryCount': 5,
            'capacity': 20,
            'chargeHours': 12,
            'periodDays': 7,
          },
        ],
      });
      expect(config.batteryCapacity, 40);
      expect(config.subscriptions.single.batteryCapacity, 20);
      expect(config.subscriptions.single.chargeHours, 12);
      expect(config.subscriptions.single.periodDays, 7);
    },
  );
}
