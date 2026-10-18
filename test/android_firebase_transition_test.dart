import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/android_firebase_config.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/invite_code.dart';
import 'package:game_box/app/mobile_gameplay_tuning.dart';

class _Vault implements AccountVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final raw = File(AndroidFirebaseConfig.assetPath).readAsStringSync();
  final snapshot = jsonDecode(raw) as Map<String, dynamic>;

  test('client/server/RC ship identical validated Firebase snapshot', () {
    final remote = jsonDecode(
      File('firebase-android/remoteconfig.template.json').readAsStringSync(),
    );
    final server = jsonDecode(
      File(
        'firebase-android/functions/config/defaults.json',
      ).readAsStringSync(),
    );
    expect(server, snapshot);
    expect(
      jsonDecode(
        remote['parameters']['android_config_v1']['defaultValue']['value'],
      ),
      snapshot,
    );
    final config = AndroidFirebaseConfig.parse(raw, 'test');
    expect(config.economy.androidEnergyV2.enabled, true);
    expect(config.economy.androidEnergyV2.initialEnergy, 50);
    expect(config.economy.androidEnergyV2.reward('ad'), 40);
    expect(config.economy.androidEnergyV2.reward('invite'), 20);
    expect(
      config.gameplay.mobileEnemies.startSpeedSteps,
      snapshot['config']['mobileEnemies']['startSpeedSteps'],
    );
    expect(config.gameplay.jumpCooldownSec, 2);
  });
  test('Firebase links accept only their exact canonical host', () {
    const code='ABCDEFGH2345';
    expect(InviteCode.fromAppLink(InviteCode.firebaseUrl(code)),code);
    expect(InviteCode.fromAppLink('https://${InviteCode.firebaseHost}.evil/a/$code'),isNull);
    expect(InviteCode.fromAppLink('https://${InviteCode.firebaseHost}/a/$code?secret=x'),isNull);
  });
  test(
    'config rejects changed hash and harmful attempt cost even with new hash',
    () {
      final bad = jsonDecode(raw) as Map<String, dynamic>;
      bad['config']['economy']['androidEnergyV2']['baseAttemptCost'] = -10;
      expect(
        () => AndroidFirebaseConfig.parse(jsonEncode(bad), 'bad'),
        throwsFormatException,
      );
      bad['revision'] = sha256
          .convert(utf8.encode(jsonEncode(bad['config'])))
          .toString();
      expect(
        () => AndroidFirebaseConfig.parse(jsonEncode(bad), 'bad'),
        throwsFormatException,
      );
    },
  );
  test(
    'mobile variation is remotely configurable without changing base pace',
    () {
      final config = jsonDecode(raw) as Map<String, dynamic>;
      config['config']['mobileEnemies']['speedVariation'] = 0.2;
      config['revision'] = sha256
          .convert(utf8.encode(jsonEncode(config['config'])))
          .toString();
      final parsed = AndroidFirebaseConfig.parse(jsonEncode(config), 'test');
      final tuned = MobileGameplayTuning.apply(parsed.gameplay);
      expect(tuned.speedMax / tuned.speedMin, closeTo(1.5, 1e-9));
    },
  );
  test(
    'old balance, cached owner and durable operations are neither imported nor erased',
    () async {
      const prefix = 'firebase_android_v1_';
      const oldJournal =
          '[{"id":"old","owner":"android:1","kind":"watch_ad","args":{}}]';
      SharedPreferences.setMockInitialValues({
        'tokens': 99999,
        'lives': 99999,
        'mobile_wallet_operations_v1': oldJournal,
        'mobile_wallet_owner_v1': 'android:1',
        'energy_v2_snapshot':
            '{"owner":"android:1","wallet":{"energy":99999},"serverNow":123}',
      });
      final requests = <Map>[];
      final config = AndroidFirebaseConfig.parse(raw, 'test');
      final economy = EconomyStore(
        config: config.economy,
        storagePrefix: prefix,
        serverEnergyRequired: true,
      );
      await economy.load();
      expect(economy.energyEnabled, true);
      expect(economy.confirmedEnergy, 0);
      expect(economy.energyClockSynchronized, false);
      final account = MobileAccount(
        storagePrefix: prefix,
        vault: _Vault(),
        client: MockClient((request) async {
          final payload = jsonDecode(request.body) as Map;
          requests.add(payload);
          return http.Response(
            jsonEncode({
              'ok': true,
              'profile': {
                'id': 'firebase:new_uid',
                'nickname': 'Новый',
                'googleLinked': false,
                'walletVersion': 1,
                'serverNow': 100000,
                'wallet': {
                  'energyVersion': 2,
                  'energy': 50,
                  'energyConfig':
                      snapshot['config']['economy']['androidEnergyV2'],
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final bridge = MobileWalletBridge(account, economy);
      await bridge.load();
      await account.load();
      expect(account.error, isNull);
      await bridge.flush();
      expect(economy.confirmedEnergy, 50);
      expect(requests.where((r) => r['action'] == 'wallet_operation'), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mobile_wallet_operations_v1'), oldJournal);
      expect(prefs.getInt('tokens'), 99999);
      expect(
        prefs.getString('${prefix}mobile_wallet_owner_v1'),
        'firebase:new_uid',
      );
    },
  );
  test(
    'Firebase ranking uses the authenticated account path, never legacy HTTP',
    () async {
      SharedPreferences.setMockInitialValues({});
      final actions = <String>[];
      final account = MobileAccount(
        storagePrefix: 'firebase_android_v1_',
        vault: _Vault(),
        client: MockClient((request) async {
          final data = jsonDecode(request.body) as Map;
          actions.add(data['action'] as String);
          if (data['action'] == 'scores') {
            return http.Response(
              '{"ok":true,"source":"firebase","periods":{"all":[],"day":[],"week":[],"month":[],"year":[]}}',
              200,
            );
          }
          return http.Response(
            '{"ok":true,"profile":{"id":"firebase:test_uid","nickname":"Test","googleLinked":false}}',
            200,
          );
        }),
      );
      await account.load();
      final scores = ScoresStore(
        account: account,
        storagePrefix: account.storagePrefix,
        client: MockClient(
          (_) async => throw StateError('Legacy HTTP forbidden'),
        ),
      );
      await scores.load();
      expect(scores.online, true);
      expect(actions.where((a) => a == 'scores').length, 1);
      scores.dispose();
    },
  );
}
