import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/data/economy_store.dart';
import 'mobile_account_test.dart' show MemoryVault;
import 'simple_energy_test.dart' show simpleWallet, stamp;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a lost bonus reply keeps one durable command and reconciles one server credit',
    () async {
      SharedPreferences.setMockInitialValues({});
      var wallet = simpleWallet(), version = 1, loseReply = true;
      final ids = <String>[];
      const kind = 'energy_ad_unavailable_bonus';
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (body['action'] == 'wallet_operation') {
            expect(body['kind'], kind);
            expect(body['args'], isEmpty);
            ids.add(body['operationId'] as String);
            if (!(wallet['claimed'] as List).contains(kind)) {
              wallet = {
                ...wallet,
                'energy': 70,
                'claimed': [kind],
              };
              version++;
            }
            if (loseReply) throw StateError('reply_lost_after_commit');
          }
          return http.Response(
            jsonEncode({
              'ok': true,
              'serverNow': stamp,
              'profile': {
                'id': 'android:1',
                'nickname': 'QA',
                'walletVersion': version,
                'wallet': wallet,
              },
            }),
            200,
          );
        }),
      );
      final e = EconomyStore();
      await e.load();
      final bridge = MobileWalletBridge(account, e);
      await bridge.load();
      await account.load();
      await bridge.flush();
      expect(e.energy, 50);
      await expectLater(e.claimAdUnavailableBonus(), throwsStateError);
      expect(e.energy, 50);
      expect(e.adUnavailableBonusClaimed, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('mobile_wallet_operations_v1')!),
        hasLength(1),
      );
      loseReply = false;
      await bridge.flush();
      expect(e.energy, 70);
      expect(e.adUnavailableBonusClaimed, isTrue);
      expect(ids.toSet(), hasLength(1));
      expect(
        jsonDecode(prefs.getString('mobile_wallet_operations_v1')!),
        isEmpty,
      );
      final count = ids.length;
      await e.claimAdUnavailableBonus();
      expect(ids.length, count);
      expect(e.energy, 70);
      account.dispose();
      e.dispose();
    },
  );
}
