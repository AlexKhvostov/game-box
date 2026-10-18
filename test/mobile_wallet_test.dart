import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/data/economy_store.dart';
import 'mobile_account_test.dart' show MemoryVault;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'wallet lost acknowledgement persists operation and retries the same ID',
    () async {
      var offline = true;
      final operationIds = <String>[];
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (body['action'] == 'wallet_operation') {
            operationIds.add(body['operationId'] as String);
            if (offline) throw StateError('response lost');
          }
          return http.Response(
            jsonEncode({
              'ok': true,
              'profile': {
                'id': 'android:1',
                'nickname': 'user00000001',
                'walletVersion': 1,
                'wallet': {
                  'lives': 30,
                  'tokens': 29,
                  'claimed': [],
                  'unlocked': [],
                },
              },
            }),
            200,
          );
        }),
      );
      final economy = EconomyStore();
      await economy.load();
      final bridge = MobileWalletBridge(account, economy);
      await bridge.load();
      await account.load();
      economy.claimDaily();
      await expectLater(bridge.flush(), throwsA(isA<StateError>()));
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('mobile_wallet_operations_v1')!),
        hasLength(1),
      );
      offline = false;
      await bridge.flush();
      expect(operationIds.toSet(), hasLength(1));
      expect(
        jsonDecode(prefs.getString('mobile_wallet_operations_v1')!),
        isEmpty,
      );
      expect(economy.tokens, 29);
    },
  );
  test(
    'late older wallet response cannot replace a newer server balance',
    () async {
      var version = 5;
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'ok': true,
              'profile': {
                'id': 'android:1',
                'nickname': 'user00000001',
                'walletVersion': version,
                'wallet': {'tokens': version},
              },
            }),
            200,
          ),
        ),
      );
      await account.load();
      version = 4;
      await account.refreshProfile();
      expect(account.wallet!['tokens'], 5);
      version = 6;
      await account.refreshProfile();
      expect(account.wallet!['tokens'], 6);
    },
  );
}
