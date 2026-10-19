import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/android_config_session.dart';
import 'package:game_box/data/android_firebase_config.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'instant_round_journal_test.dart' as fixture;
import 'simple_energy_test.dart' as energy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final raw = File(AndroidFirebaseConfig.assetPath).readAsStringSync();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'first server profile replaces stale bundled rules without restart or new account',
    () async {
      final previous = AndroidFirebaseConfig.parse(raw, 'bundled');
      final next = jsonDecode(raw) as Map<String, dynamic>;
      next['config']['audio']['musicVolume'] = .31;
      next['revision'] = sha256
          .convert(utf8.encode(jsonEncode(next['config'])))
          .toString();
      final server = fixture.RunServer()..offline = true;
      final account = fixture.RunAccount(server);
      account.applyRulesRevision(previous.revision);
      account.serverGameConfig = next;
      final economy = EconomyStore();
      await economy.load();
      await economy.applyServerWallet(
        server.wallet(),
        owner: fixture.owner,
        serverNow: energy.stamp,
      );
      final scores = ScoresStore(account: account, instantEconomy: economy);
      await scores.loadLocal();
      final session = AndroidConfigSession(previous, account, economy);
      final owner = account.id, balance = economy.energy;
      expect(await session.synchronize(), true);
      expect(account.rulesRevision, next['revision']);
      expect(session.snapshot.source, 'game-server');
      expect(account.id, owner);
      expect(economy.energy, balance);
      expect(scores.myAttempts, isEmpty);
      expect(
        scores.beginInstantRound(helmet: false, jump: false, cost: 1),
        isNotNull,
      );
      expect(economy.energy, balance - 1);
      expect(
        scores.beginInstantRound(helmet: false, jump: false, cost: 1),
        isNull,
      );
      expect(economy.energy, balance - 1);
      scores.dispose();
      session.dispose();
      account.dispose();
      economy.dispose();
    },
  );

  test(
    'rejected revision unblocks in same process; old rejected attempt never resubmits',
    () async {
      final server = fixture.RunServer()..offline = true;
      final account = fixture.RunAccount(server)
        ..applyRulesRevision('old-rules');
      final economy = EconomyStore();
      await economy.load();
      await economy.applyServerWallet(
        server.wallet(),
        owner: fixture.owner,
        serverNow: energy.stamp,
      );
      final scores = ScoresStore(account: account, instantEconomy: economy);
      await scores.loadLocal();
      scores.beginInstantRound(helmet: false, jump: false, cost: 1);
      await scores.recordAttempt(1);
      await fixture.flush();
      server.offline = false;
      server.refusal = 'rules_changed';
      await scores.retryPendingResults();
      await fixture.flush();
      expect(scores.rulesUpdateRequired, true);
      expect(economy.energy, 50);
      final oldId = scores.myAttempts.single.id;
      account.serverGameConfig = jsonDecode(raw) as Map<String, dynamic>;
      final session = AndroidConfigSession(
        AndroidFirebaseConfig.parse(raw, 'bundled'),
        account,
        economy,
      );
      // Same snapshot hash, but the account still refers to the obsolete rules.
      account.applyRulesRevision(session.snapshot.revision);
      expect(scores.rulesUpdateRequired, false);
      server.refusal = null;
      server.offline = true;
      expect(
        scores.beginInstantRound(helmet: false, jump: false, cost: 1),
        isNotNull,
      );
      expect(scores.isAttemptPending(oldId), false);
      expect(scores.myAttempts.single.deliveryError, 'rules_changed');
      scores.dispose();
      session.dispose();
      account.dispose();
      economy.dispose();
    },
  );

  test(
    'invalid server snapshot cannot mutate active rules or wallet',
    () async {
      final old = AndroidFirebaseConfig.parse(raw, 'bundled');
      final server = fixture.RunServer();
      final account = fixture.RunAccount(server)
        ..applyRulesRevision(old.revision);
      final economy = EconomyStore();
      await economy.load();
      account.serverGameConfig = jsonDecode(raw) as Map<String, dynamic>;
      account.serverGameConfig!['revision'] = '0' * 64;
      final session = AndroidConfigSession(old, account, economy);
      await expectLater(session.synchronize(), throwsFormatException);
      expect(session.snapshot, same(old));
      expect(account.rulesRevision, old.revision);
      session.dispose();
      account.dispose();
      economy.dispose();
    },
  );
}
