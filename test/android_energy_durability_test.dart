import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'android_energy_core_test.dart' show wallet, profile;
import 'mobile_account_test.dart' show MemoryVault, GoogleFixture;

class RejectingDisk extends InMemorySharedPreferencesStore {
  RejectingDisk() : super.empty();
  bool Function(String, Object)? reject;
  @override
  Future<bool> setValue(String type, String key, Object value) =>
      reject?.call(key, value) == true
      ? Future.value(false)
      : super.setValue(type, key, value);
}

class PermittedAds extends AudiencePolicy {
  @override
  bool get adsEnabled => true;
}

class RewardedDriver implements AdsDriver {
  int loads = 0;
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async {
    loads++;
    return AdOutcome.rewarded;
  }

  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'false journal persistence never posts, even after preferences cache mutated',
    () async {
      final disk = RejectingDisk();
      SharedPreferencesStorePlatform.instance = disk;
      var posts = 0;
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          if ((jsonDecode(request.body) as Map)['action'] ==
              'wallet_operation') {
            posts++;
          }
          return profile(
            wallet(energy: posts == 0 ? 20 : 40),
            version: posts + 1,
          );
        }),
      );
      final store = EconomyStore();
      await store.load();
      final bridge = MobileWalletBridge(account, store);
      await bridge.load();
      await account.load();
      await bridge.flush();
      disk.reject = (key, value) => key.endsWith('mobile_wallet_operations_v1');
      await expectLater(store.claimEnergy(), throwsA(isA<MobileApiError>()));
      expect(posts, 0);
      await expectLater(bridge.flush(), throwsA(isA<MobileApiError>()));
      expect(posts, 0);
      disk.reject = null;
      await bridge.flush();
      expect(posts, 1);
      expect(store.energy, 40);
    },
  );

  test(
    'false dequeue persistence retains the ID and retries server receipt without double grant',
    () async {
      final disk = RejectingDisk();
      SharedPreferencesStorePlatform.instance = disk;
      final ids = <String>[];
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (body['action'] == 'wallet_operation') {
            ids.add(body['operationId'] as String);
          }
          return profile(
            wallet(energy: ids.isEmpty ? 20 : 40),
            version: ids.isEmpty ? 1 : 2,
          );
        }),
      );
      final store = EconomyStore();
      await store.load();
      final bridge = MobileWalletBridge(account, store);
      await bridge.load();
      await account.load();
      await bridge.flush();
      disk.reject = (key, value) =>
          key.endsWith('mobile_wallet_operations_v1') && value == '[]';
      await expectLater(store.claimEnergy(), throwsA(isA<MobileApiError>()));
      final persisted = await disk.getAll();
      expect(
        jsonDecode(persisted['flutter.mobile_wallet_operations_v1'] as String),
        hasLength(1),
      );
      disk.reject = null;
      await bridge.flush();
      expect(ids, hasLength(2));
      expect(ids.toSet(), hasLength(1));
      expect(store.energy, 40);
    },
  );

  test(
    'false archive persistence never removes deferred legacy operation',
    () async {
      final disk = RejectingDisk();
      SharedPreferencesStorePlatform.instance = disk;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mobile_wallet_owner_v1', 'android:1');
      await prefs.setString(
        'mobile_wallet_operations_v1',
        jsonEncode([
          {
            'id': 'legacy',
            'owner': 'android:1',
            'kind': 'earn',
            'args': {'id': 'survive_10s'},
          },
        ]),
      );
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          if ((jsonDecode(request.body) as Map)['action'] ==
              'wallet_operation') {
            return http.Response('{"ok":false,"error":"update_required"}', 409);
          }
          return profile(wallet());
        }),
      );
      final store = EconomyStore();
      await store.load();
      final bridge = MobileWalletBridge(account, store);
      await bridge.load();
      disk.reject = (key, value) => key.endsWith('mobile_wallet_deferred_v2');
      await account.load();
      await expectLater(bridge.flush(), throwsA(isA<MobileApiError>()));
      var persisted = await disk.getAll();
      expect(
        persisted.containsKey('flutter.mobile_wallet_deferred_v2'),
        isFalse,
      );
      expect(
        jsonDecode(persisted['flutter.mobile_wallet_operations_v1'] as String),
        hasLength(1),
      );
      disk.reject = null;
      await bridge.flush();
      persisted = await disk.getAll();
      expect(persisted['flutter.mobile_wallet_deferred_v2'], hasLength(1));
      expect(
        jsonDecode(persisted['flutter.mobile_wallet_operations_v1'] as String),
        isEmpty,
      );
    },
  );

  test(
    'Denied server session never loads a rewarded ad or promises energy',
    () async {
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          if ((jsonDecode(request.body) as Map)['action'] ==
              'wallet_operation') {
            return http.Response('{"ok":false,"error":"ad_not_ready"}', 409);
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
      final driver = RewardedDriver();
      final ads = AdsService(driver, audience: PermittedAds());
      final outcome = await ads.watchAndClaim(store);
      expect(outcome.reward, 0);
      expect(outcome.outcome, AdOutcome.unavailable);
      expect(store.energy, 20);
      expect(driver.loads, 0);
      ads.dispose();
    },
  );

  test(
    'retired pending video claim is archived and cannot block the next bonus',
    () async {
      final kinds = <String>[];
      var version = 1;
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (body['action'] == 'wallet_operation') {
            kinds.add(body['kind'] as String);
            if (body['kind'] == 'watch_ad') {
              return http.Response(
                '{"ok":false,"error":"ad_session_required"}',
                503,
              );
            }
            return profile(wallet(energy: 40), version: ++version);
          }
          return profile(wallet(), version: version);
        }),
      );
      final store = EconomyStore();
      await store.load();
      final bridge = MobileWalletBridge(account, store);
      await bridge.load();
      await account.load();
      await bridge.flush();
      await expectLater(
        store.claimEnergyReward('watch_ad'),
        throwsA(
          isA<MobileApiError>().having(
            (e) => e.code,
            'code',
            'ad_session_required',
          ),
        ),
      );
      await store.claimEnergy();
      await bridge.flush();
      expect(kinds.first, 'watch_ad');
      expect(kinds.length, 2);
      expect(store.energy, 40);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('mobile_wallet_operations_v1')!),
        isEmpty,
      );
      expect(prefs.getStringList('mobile_wallet_deferred_v2'), hasLength(1));
      store.dispose();
      account.dispose();
    },
  );

  test(
    'queued awaited operation quarantined after owner change fails its caller',
    () async {
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async => profile(wallet())),
      );
      final store = EconomyStore();
      await store.load();
      final bridge = MobileWalletBridge(account, store);
      await bridge.load();
      await account.load();
      await bridge.flush();
      final job = store.claimEnergy();
      account.id = 'android:2';
      await expectLater(job, throwsA(isA<MobileApiError>()));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('mobile_wallet_quarantine_v2'), hasLength(1));
    },
  );

  test(
    'atomic cache owner cannot be reattributed by a split legacy pointer',
    () async {
      final original = EconomyStore();
      await original.load();
      await original.applyServerWallet(
        wallet(),
        owner: 'android:1',
        serverNow: 1000,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mobile_wallet_owner_v1', 'android:2');
      final account = MobileAccount(
        vault: MemoryVault()
          ..value = jsonEncode({
            'owner': 'android:2',
            'installation': 'i',
            'secret': 's',
          }),
      );
      final restarted = EconomyStore();
      await restarted.load();
      expect(restarted.energyEnabled, isFalse);
      await MobileWalletBridge(account, restarted).load();
      expect(restarted.energyEnabled, isFalse);
      final snapshot =
          jsonDecode(prefs.getString('energy_v2_snapshot')!) as Map;
      expect(snapshot['owner'], 'android:1');
      expect(snapshot['wallet']['energy'], 20);
    },
  );

  test(
    'live server clock uses monotonic elapsed and ignores device date changes',
    () async {
      var wall = DateTime.fromMillisecondsSinceEpoch(0), elapsed = 0;
      final store = EconomyStore(
        now: () => wall,
        monotonicMilliseconds: () => elapsed,
      );
      await store.load();
      final state = wallet()
        ..['batteries'] = [
          {
            'id': 'free',
            'startedAt': 0,
            'capacity': 20,
            'durationMs': 43200000,
            'initialUnits': 0,
          },
        ];
      await store.applyServerWallet(state, owner: 'android:1', serverNow: 0);
      wall = DateTime(2100);
      expect(store.accumulatedEnergy, 0);
      elapsed = 2160000;
      expect(store.accumulatedEnergy, 1);
      wall = DateTime(1900);
      expect(store.accumulatedEnergy, 1);
      expect(store.energyClockSynchronized, isTrue);
    },
  );

  test(
    'offline restart freezes trusted saved charge until a fresh server anchor',
    () async {
      final original = EconomyStore();
      await original.load();
      final state = wallet()
        ..['batteries'] = [
          {
            'id': 'free',
            'startedAt': 0,
            'capacity': 20,
            'durationMs': 43200000,
            'initialUnits': 0,
          },
        ];
      await original.applyServerWallet(
        state,
        owner: 'android:1',
        serverNow: 2160000,
      );
      var elapsed = 0;
      final restarted = EconomyStore(
        now: () => DateTime(2100),
        monotonicMilliseconds: () => elapsed,
      );
      await restarted.load();
      await restarted.restoreEnergyCacheForOwner('android:1');
      expect(restarted.energyEnabled, isTrue);
      expect(restarted.accumulatedEnergy, 1);
      expect(restarted.energyClockSynchronized, isFalse);
      elapsed = 86400000;
      expect(restarted.accumulatedEnergy, 1);
      await restarted.applyServerWallet(
        state,
        owner: 'android:1',
        serverNow: 4320000,
      );
      expect(restarted.accumulatedEnergy, 2);
      expect(restarted.energyClockSynchronized, isTrue);
    },
  );

  test(
    'failed monetary snapshot write is retried even if plugin memory already changed',
    () async {
      final disk = RejectingDisk();
      SharedPreferencesStorePlatform.instance = disk;
      final store = EconomyStore();
      await store.load();
      disk.reject = (key, value) => key.endsWith('energy_v2_snapshot');
      await expectLater(
        store.applyServerWallet(wallet(), owner: 'android:1', serverNow: 0),
        throwsStateError,
      );
      expect(
        (await disk.getAll()).containsKey('flutter.energy_v2_snapshot'),
        isFalse,
      );
      disk.reject = null;
      await store.applyServerWallet(wallet(), owner: 'android:1', serverNow: 0);
      expect(
        (await disk.getAll()).containsKey('flutter.energy_v2_snapshot'),
        isTrue,
      );
    },
  );

  test(
    'restored tokens never inherit stale launch owner; purchased requires native owner proof',
    () {
      GooglePlayPurchaseDetails purchase(PurchaseStatus status, String owner) =>
          GooglePlayPurchaseDetails(
            productID: 'energy_100_v1',
            verificationData: PurchaseVerificationData(
              localVerificationData: '',
              serverVerificationData: 'token',
              source: 'google_play',
            ),
            transactionDate: '1',
            status: status,
            billingClientPurchase: PurchaseWrapper(
              orderId: 'order',
              packageName: 'example',
              purchaseTime: 1,
              purchaseToken: 'token',
              signature: 'sig',
              products: ['energy_100_v1'],
              isAutoRenewing: false,
              originalJson: '{}',
              isAcknowledged: false,
              purchaseState: PurchaseStateWrapper.purchased,
              obfuscatedAccountId: sha256
                  .convert(utf8.encode(owner))
                  .toString(),
            ),
          );
      final stale = {'owner': 'android:1', 'requestId': 'old'};
      expect(
        PlayBillingService.journalOwner(
          purchase(PurchaseStatus.restored, 'android:2'),
          stale,
        ),
        '',
      );
      expect(
        PlayBillingService.journalOwner(
          purchase(PurchaseStatus.purchased, 'android:2'),
          stale,
        ),
        '',
      );
      expect(
        PlayBillingService.journalOwner(
          purchase(PurchaseStatus.purchased, 'android:1'),
          stale,
        ),
        'android:1',
      );
    },
  );
  test(
    'pending subscription claim is archived and cannot deadlock Play verification',
    () async {
      var syncs = 0;
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final action = (jsonDecode(request.body) as Map)['action'];
          if (action == 'wallet_operation') {
            return http.Response(
              '{"ok":false,"error":"subscription_verification_pending"}',
              409,
            );
          }
          if (action == 'play_sync') syncs++;
          return profile(wallet());
        }),
      );
      final store = EconomyStore();
      await store.load();
      final bridge = MobileWalletBridge(account, store);
      await bridge.load();
      await account.load();
      await bridge.flush();
      await expectLater(
        store.claimEnergy(),
        throwsA(
          isA<MobileApiError>().having(
            (error) => error.code,
            'code',
            'subscription_verification_pending',
          ),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('mobile_wallet_operations_v1')!),
        isEmpty,
      );
      expect(
        jsonDecode(
          prefs.getStringList('mobile_wallet_deferred_v2')!.single,
        )['reason'],
        'subscription_verification_pending',
      );
      await account.beforeRound!();
      await account.syncPlay();
      expect(syncs, 1);
    },
  );

  test(
    'lost Google restore acknowledgement requires resync and quarantines old-owner queue',
    () async {
      var restored = false, oldPosts = 0;
      final vault = MemoryVault();
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        if (body['action'] == 'google_restore') {
          restored = true;
          throw StateError('server committed restore, acknowledgement lost');
        }
        if (body['action'] == 'wallet_operation') oldPosts++;
        final data =
            jsonDecode(
                  profile(
                    wallet(energy: restored ? 70 : 20),
                    version: restored ? 2 : 1,
                  ).body,
                )
                as Map;
        if (restored) {
          data['profile']['id'] = 'android:2';
          data['profile']['nickname'] = 'user00000002';
        }
        return http.Response(jsonEncode(data), 200);
      });
      final first = MobileAccount(vault: vault, client: client);
      final initial = EconomyStore();
      await initial.load();
      final firstBridge = MobileWalletBridge(first, initial);
      await firstBridge.load();
      await first.load();
      await firstBridge.flush();
      await expectLater(first.restoreGoogle(GoogleFixture()), throwsStateError);
      expect(first.ready, isFalse);
      expect(first.wallet, isNull);
      expect(await first.cachedCredentialOwner(), isNull);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'mobile_wallet_operations_v1',
        jsonEncode([
          {
            'id': 'old-A',
            'kind': 'energy_claim',
            'args': {},
            'owner': 'android:1',
            'awaited': true,
          },
        ]),
      );
      final restarted = MobileAccount(vault: vault, client: client);
      final fresh = EconomyStore();
      await fresh.load();
      final nextBridge = MobileWalletBridge(restarted, fresh);
      await nextBridge.load();
      expect(fresh.energyEnabled, isFalse);
      await restarted.load();
      await nextBridge.flush();
      expect(restarted.id, 'android:2');
      expect(fresh.energy, 70);
      expect(oldPosts, 0);
      expect(
        jsonDecode(
          prefs.getStringList('mobile_wallet_quarantine_v2')!.single,
        )['owner'],
        'android:1',
      );
      expect(
        jsonDecode(prefs.getString('energy_v2_snapshot')!)['owner'],
        'android:2',
      );
    },
  );

  test(
    'a complete atomic snapshot survives missing legacy fields after process death',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'energy_v2_snapshot',
        jsonEncode({
          'owner': 'android:1',
          'wallet': wallet(energy: 73),
          'serverNow': 1000,
        }),
      );
      expect(prefs.containsKey('lives'), isFalse);
      final store = EconomyStore();
      await store.load();
      expect(prefs.containsKey('energy_v2_snapshot'), isTrue);
      await store.restoreEnergyCacheForOwner('android:1');
      expect(store.energy, 73);
      expect(store.energyClockSynchronized, isFalse);
    },
  );
}
