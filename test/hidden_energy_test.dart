import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'mobile_account_test.dart' show MemoryVault;
import 'simple_energy_test.dart' as fixture;
import 'simple_energy_durability_test.dart' show reply;

void main() {
  final title = find.byKey(const ValueKey('energy-hidden-title'));
  Future<void> taps(WidgetTester t, int count) async {
    for (var i = 0; i < count; i++) {
      await t.tap(title);
      await t.pump();
    }
  }

  testWidgets('four taps do nothing; each complete five grants confirmed20', (
    t,
  ) async {
    final e = await fixture.store();
    var calls = 0;
    var balance = 50;
    e.sendEnergyOperation = (kind, args) async {
      expect(kind, 'energy_hidden_tap');
      expect(args, isEmpty);
      calls++;
      balance += 20;
      await e.applyServerWallet(
        fixture.simpleWallet(balance: balance),
        serverNow: fixture.stamp,
        owner: 'android:1',
      );
    };
    await t.pumpWidget(fixture.app(e));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await taps(t, 4);
    expect(calls, 0);
    expect(e.energy, 50);
    await taps(t, 1);
    await t.pump(const Duration(milliseconds: 300));
    expect(calls, 1);
    expect(e.energy, 70);
    await taps(t, 5);
    await t.pump(const Duration(milliseconds: 300));
    expect(calls, 2);
    expect(e.energy, 90);
    expect(e.gamesStartedCount, 0);
    await t.pumpWidget(const SizedBox());
    e.dispose();
  });
  testWidgets('pause and closing the window reset incomplete sequences', (
    t,
  ) async {
    final e = await fixture.store();
    var calls = 0;
    e.sendEnergyOperation = (k, a) async {
      calls++;
    };
    await t.pumpWidget(fixture.app(e));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await taps(t, 4);
    await t.pump(const Duration(milliseconds: 1501));
    await taps(t, 1);
    expect(calls, 0);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(fixture.app(e));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await taps(t, 4);
    expect(calls, 0);
    await taps(t, 1);
    await t.pump();
    expect(calls, 1);
    await t.pumpWidget(const SizedBox());
    e.dispose();
  });
  testWidgets('pending request blocks extra taps and never invents credit', (
    t,
  ) async {
    final e = await fixture.store();
    final gate = Completer<void>();
    var calls = 0;
    e.sendEnergyOperation = (k, a) {
      calls++;
      return gate.future;
    };
    await t.pumpWidget(fixture.app(e));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await taps(t, 5);
    await taps(t, 10);
    expect(calls, 1);
    expect(e.energy, 50);
    gate.completeError(const SocketException('offline'));
    await t.pump();
    expect(e.energy, 50);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    e.dispose();
  });
  test(
    'lost hidden-credit acknowledgement reuses journal ID and persists once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final wallet = fixture.simpleWallet();
      var version = 1, posts = 0;
      final ids = <String>[];
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          final input = jsonDecode(request.body) as Map;
          if (input['action'] == 'wallet_operation') {
            expect(input['kind'], 'energy_hidden_tap');
            expect(input['args'], isEmpty);
            ids.add(input['operationId'] as String);
            posts++;
            if (posts == 1) {
              wallet['energy'] = 70;
              version++;
              throw const SocketException('lost committed ACK');
            }
          }
          return reply(wallet, version);
        }),
      );
      final e = EconomyStore();
      await e.load();
      final bridge = MobileWalletBridge(account, e);
      await bridge.load();
      await account.load();
      await bridge.flush();
      await expectLater(e.claimHiddenEnergy(), throwsA(anything));
      expect(e.energy, 50);
      await e.claimHiddenEnergy();
      expect(e.energy, 70);
      expect(ids.toSet(), hasLength(1));
      final restored = EconomyStore();
      await restored.load();
      await restored.restoreEnergyCacheForOwner('android:1');
      expect(restored.energy, 70);
      e.dispose();
      restored.dispose();
      account.dispose();
    },
  );
  test(
    'old credit commands are quarantined without any network POST',
    () async {
      SharedPreferences.setMockInitialValues({
        'mobile_wallet_owner_v1': 'android:1',
        'mobile_wallet_operations_v1': jsonEncode([
          {
            'id': 'old-one',
            'owner': 'android:1',
            'kind': 'energy_test_grant',
            'args': {'source': 'video'},
          },
          {
            'id': 'old-two',
            'owner': 'android:1',
            'kind': 'beta_free_crystals',
            'args': {'productId': 'debug_10'},
          },
        ]),
      });
      var posts = 0;
      final account = MobileAccount(
        vault: MemoryVault(),
        client: MockClient((request) async {
          if ((jsonDecode(request.body) as Map)['action'] == 'wallet_operation')
            posts++;
          return reply(fixture.simpleWallet(), 1);
        }),
      );
      final e = EconomyStore();
      await e.load();
      final bridge = MobileWalletBridge(account, e);
      await bridge.load();
      await account.load();
      await bridge.flush();
      expect(posts, 0);
      expect(e.energy, 50);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('mobile_wallet_operations_v1')!),
        isEmpty,
      );
      expect(prefs.getStringList('mobile_wallet_deferred_v2'), hasLength(2));
      e.dispose();
      account.dispose();
    },
  );
}
