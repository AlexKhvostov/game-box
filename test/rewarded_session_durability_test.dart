import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'android_energy_core_test.dart' show wallet, profile;
import 'mobile_account_test.dart' show MemoryVault;
import 'rewarded_session_test.dart' show SessionDriver, RewardAudience;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'lost reward reply persists exact operation; retry confirms once without another ad',
    () async {
      SharedPreferences.setMockInitialValues({});
      var balance = 20, revision = 1, rewards = 0;
      var loseReply = true;
      final finishes = <Map<String, dynamic>>[];
      String? session;
      final accepted = <String>{};
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['action'] == 'wallet_operation') {
            final args = body['args'] as Map;
            if (body['kind'] == 'rewarded_ad_start') {
              session = args['sessionId'] as String;
            } else if (body['kind'] == 'watch_ad') {
              finishes.add(body);
              expect(args['sessionId'], session);
              if (accepted.add(body['operationId'] as String)) {
                balance += 40;
                rewards++;
              }
              if (loseReply) {
                return http.Response(
                  '{"ok":false,"error":"service_unavailable"}',
                  503,
                );
              }
            }
            revision++;
          }
          return profile({
            ...wallet(energy: balance),
            if (rewards > 0) 'lastAdAt': 2000000000000,
          }, version: revision);
        }),
      );
      final e = EconomyStore();
      await e.load();
      final bridge = MobileWalletBridge(account, e);
      await bridge.load();
      await account.load();
      await bridge.flush();
      final d = SessionDriver(), a = RewardAudience();
      final ads = AdsService(d, audience: a);
      final pending = ads.watchAndClaim(e);
      while (d.loads == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      d.result.complete(AdOutcome.rewarded);
      expect((await pending).reward, 0);
      expect(ads.lastFailure, AdFailure.confirmation);
      expect(e.energy, 20);
      expect(rewards, 1);
      final prefs = await SharedPreferences.getInstance();
      final journal =
          jsonDecode(prefs.getString('mobile_wallet_operations_v1')!) as List;
      expect(journal, hasLength(1));
      expect(journal.single['id'], finishes.single['operationId']);
      loseReply = false;
      await bridge.flush();
      expect(e.energy, 60);
      expect(rewards, 1);
      expect(d.loads, 1);
      expect(finishes, hasLength(2));
      expect(finishes[1], finishes[0]);
      expect(
        jsonDecode(prefs.getString('mobile_wallet_operations_v1')!),
        isEmpty,
      );
      ads.dispose();
      a.dispose();
      account.dispose();
      e.dispose();
    },
  );
}
