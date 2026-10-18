import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'mobile_account_test.dart' show MemoryVault;
import 'ads_service_test.dart' show FakeAdsDriver;
import 'simple_energy_test.dart' show simpleWallet, stamp;

http.Response reply(Map<String, dynamic> wallet, int version) => http.Response(
  jsonEncode({
    'ok': true,
    'profile': {
      'id': 'android:1',
      'nickname': 'QA',
      'walletVersion': version,
      'serverNow': stamp,
      'wallet': wallet,
    },
  }),
  200,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Lost bonus ACK reuses durable operationId; restart reconciles once',
    () async {
      final w = simpleWallet();
      var version = 1, posts = 0;
      final ids = <String>[];
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body['economyVersion'], 2);
          expect(body['energyContract'], 3);
          if (body['action'] == 'wallet_operation') {
            ids.add(body['operationId'] as String);
            posts++;
            if (posts == 1) {
              w['energy'] = 70;
              (w['simpleBonus'] as Map)['nextAt'] = stamp + 28800000;
              version++;
              throw const SocketException('Lost committed response');
            }
          }
          return reply(w, version);
        }),
      );
      final e = EconomyStore();
      await e.load();
      final bridge = MobileWalletBridge(account, e);
      await bridge.load();
      await account.load();
      await bridge.flush();
      await expectLater(e.claimSimpleEnergyBonus(), throwsA(anything));
      expect(e.energy, 50);
      final prefs = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(prefs.getString('mobile_wallet_operations_v1')!) as List)
            .length,
        1,
      );
      await e.claimSimpleEnergyBonus();
      expect(ids.length, 2);
      expect(ids.toSet().length, 1);
      expect(e.energy, 70);
      expect(e.simpleBonusReady, isFalse);
      final restored = EconomyStore();
      await restored.load();
      await restored.restoreEnergyCacheForOwner('android:1');
      expect(restored.energy, 70);
      expect(restored.energyClockSynchronized, isFalse);
      expect(restored.simpleBonusReady, isFalse);
      e.dispose();
      restored.dispose();
      account.dispose();
    },
  );
  test(
    'Cooldown rejection is terminal and cannot block game or Play sync',
    () async {
      var syncs = 0;
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (body['action'] == 'wallet_operation') {
            return http.Response('{"ok":false,"error":"bonus_not_ready"}', 409);
          }
          if (body['action'] == 'play_sync') syncs++;
          return reply(simpleWallet(nextAt: stamp + 28800000), 1);
        }),
      );
      final e = EconomyStore();
      await e.load();
      final bridge = MobileWalletBridge(account, e);
      await bridge.load();
      await account.load();
      await bridge.flush();
      await expectLater(
        e.claimSimpleEnergyBonus(),
        throwsA(
          isA<MobileApiError>().having(
            (e) => e.code,
            'code',
            'bonus_not_ready',
          ),
        ),
      );
      await account.beforeRound!();
      await account.syncPlay();
      expect(syncs, 1);
      expect(
        jsonDecode(
          (await SharedPreferences.getInstance()).getString(
            'mobile_wallet_operations_v1',
          )!,
        ),
        isEmpty,
      );
      e.dispose();
      account.dispose();
    },
  );
  test(
    'Phone clock changes cannot finish the anchored server cooldown',
    () async {
      var elapsed = 0, wall = stamp;
      final e = EconomyStore(
        now: () => DateTime.fromMillisecondsSinceEpoch(wall),
        monotonicMilliseconds: () => elapsed,
      );
      await e.load();
      await e.applyServerWallet(
        simpleWallet(nextAt: stamp + 28800000),
        serverNow: stamp,
        owner: 'android:1',
      );
      wall += 86400000 * 10;
      expect(e.simpleBonusReady, isFalse);
      elapsed = 28799999;
      expect(e.simpleBonusReady, isFalse);
      elapsed++;
      expect(e.simpleBonusReady, isTrue);
      e.dispose();
    },
  );
  if (AudiencePolicy.adsBuildEnabled) {
    for (final outcome in [
      AdOutcome.rewarded,
      AdOutcome.dismissed,
      AdOutcome.unavailable,
    ]) {
      test('Subscriber SDK result $outcome credits only completion', () async {
        final e = EconomyStore();
        await e.load();
        await e.applyServerWallet(
          simpleWallet(tier: 5),
          serverNow: stamp,
          owner: 'android:1',
        );
        var claims = 0;
        e.sendEnergyOperation = (kind, args) async {
          claims++;
          expect(kind, 'watch_ad');
          await e.applyServerWallet(
            {...simpleWallet(tier: 5, balance: 90), 'lastAdAt': stamp},
            serverNow: stamp,
            owner: 'android:1',
          );
        };
        final policy = AudiencePolicy();
        await policy.load();
        await policy.select(AgeBand.age21plus);
        policy.allowAdsForSession();
        final driver = FakeAdsDriver();
        final ads = AdsService(driver, audience: policy);
        final job = ads.watchAndClaim(e);
        expect((await ads.watchAndClaim(e)).outcome, AdOutcome.busy);
        driver.pending.complete(outcome);
        final result = await job;
        expect(claims, outcome == AdOutcome.rewarded ? 1 : 0);
        expect(result.reward, outcome == AdOutcome.rewarded ? 40 : 0);
        expect(e.energy, outcome == AdOutcome.rewarded ? 90 : 50);
        expect(e.canClaimWatchAd, outcome != AdOutcome.rewarded);
        ads.dispose();
        policy.dispose();
        e.dispose();
      });
    }
  }
}
