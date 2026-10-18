import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/android_firebase_config.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/instant_round_journal.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/features/game/game_start_guard.dart';
import 'package:game_box/features/game/game_world.dart';
import 'instant_round_journal_test.dart' as fixture;
import 'simple_energy_test.dart' as energy;

class FirstFinishRefusal extends fixture.RunServer {
  String? firstRound;
  @override
  Future<Map<String, dynamic>> send(Map<String, dynamic> command) async {
    if (!offline && command['action'] == 'round_finish') {
      firstRound ??= command['roundId'] as String;
      if (command['roundId'] == firstRound) {
        commands.add(Map.from(command));
        throw const MobileApiError('result_time_invalid');
      }
    }
    return super.send(command);
  }
}

class RevisionAccount extends fixture.RunAccount {
  RevisionAccount(super.server, this.revision);
  final String revision;
  @override
  String get rulesRevision => revision;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<EconomyStore> wallet(fixture.RunServer server) async {
    final e = EconomyStore();
    await e.load();
    await e.applyServerWallet(
      server.wallet(),
      owner: fixture.owner,
      serverNow: energy.stamp,
    );
    return e;
  }

  test(
    'a rejected result remains in history with reason and old rules block further starts across restart',
    () async {
      final server = fixture.RunServer()..offline = true;
      final e = await wallet(server), a = RevisionAccount(server, 'old-rules');
      var s = ScoresStore(account: a, instantEconomy: e);
      await s.loadLocal();
      s.beginInstantRound(helmet: false, jump: false, cost: 1);
      await s.recordAttempt(1);
      await fixture.flush();
      server.offline = false;
      server.refusal = 'rules_changed';
      await s.retryPendingResults();
      await fixture.flush();
      expect(s.rulesUpdateRequired, true);
      expect(s.myAttempts.single.deliveryError, 'rules_changed');
      expect(s.isAttemptPending(s.myAttempts.single.id), false);
      expect(s.beginInstantRound(helmet: false, jump: false, cost: 1), isNull);
      expect(e.energy, 50);
      s.dispose();
      s = ScoresStore(account: a, instantEconomy: e);
      await s.loadLocal();
      await fixture.flush();
      expect(s.rulesUpdateRequired, true);
      expect(s.myAttempts.single.deliveryError, 'rules_changed');
      s.dispose();
      a.dispose();
      final updated = RevisionAccount(server, 'new-rules');
      server.offline = true;
      server.refusal = null;
      s = ScoresStore(account: updated, instantEconomy: e);
      await s.loadLocal();
      expect(s.rulesUpdateRequired, false);
      expect(
        s.beginInstantRound(helmet: false, jump: false, cost: 1),
        isNotNull,
      );
      s.dispose();
      updated.dispose();
      e.dispose();
    },
  );
  test(
    'permanent finish failure archives once and later valid results still publish',
    () async {
      final server = FirstFinishRefusal()..offline = true;
      final e = await wallet(server), a = fixture.RunAccount(server);
      var now = 0;
      final failures = <String, String>{}, published = <String>[];
      final j = InstantRoundJournal(
        account: a,
        economy: e,
        changed: () {},
        recoverResult: (_) => null,
        elapsedMilliseconds: () => now,
        published: (_, id) async {
          published.add(id);
        },
        rejected: (_, id, code) async {
          failures[id] = code;
        },
      );
      await j.bindOwner();
      final first = j.begin(helmet: false, jump: false, cost: 1)!;
      await j.complete(first, fixture.result);
      final second = j.begin(helmet: false, jump: false, cost: 1)!;
      await j.complete(second, fixture.result);
      await fixture.flush();
      server.offline = false;
      j.retry();
      await fixture.flush();
      now = 6000;
      j.retry();
      await fixture.flush();
      expect(published, [second]);
      expect(
        failures,
        isEmpty,
        reason: 'An early finish must not be discarded on its first refusal',
      );
      for (var retry = 0; retry < 8; retry++) {
        now += 3600001;
        j.retry();
        await fixture.flush();
      }
      expect(failures, {first: 'result_time_invalid'});
      expect(published, [second]);
      expect(j.hasPending, false);
      expect(e.energy, 48);
      final archive = (await SharedPreferences.getInstance()).getStringList(
        '${a.storagePrefix}instant_rounds_v1_${a.id}_rejected',
      )!;
      expect(archive.length, 1);
      expect(jsonDecode(archive.single)['result'], fixture.result);
      j.dispose();
      a.dispose();
      e.dispose();
    },
  );
  test(
    'Android rejects unplayable config before activation; valid rotating geometry always passes field guard',
    () async {
      final base =
          jsonDecode(
                await rootBundle.loadString(AndroidFirebaseConfig.assetPath),
              )
              as Map<String, dynamic>;
      String encode(Map<String, dynamic> s) {
        s['revision'] = sha256
            .convert(utf8.encode(jsonEncode(s['config'])))
            .toString();
        return jsonEncode(s);
      }

      for (final size in [4, 79, 200]) {
        final s = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        s['config']['player']['size'] = size;
        expect(
          () => AndroidFirebaseConfig.parse(encode(s), 'test'),
          throwsFormatException,
        );
      }
      base['config']['enemies']['spinDegPerSec'] = 120;
      final config = AndroidFirebaseConfig.parse(encode(base), 'test').gameplay;
      for (var seed = 0; seed < 50; seed++) {
        final w = GameWorld(
          config: config,
          field: const Size.square(380),
          rng: Random(seed),
        )..resetLayout();
        expect(
          GameStartGuard.check(
            world: w,
            paintedSize: const Size.square(380),
            displayedField: const Rect.fromLTWH(16, 116, 380, 380),
            visibleScreen: const Rect.fromLTWH(0, 0, 412, 900),
            devicePixelRatio: 3,
          ),
          isNull,
          reason: 'seed=$seed',
        );
      }
    },
  );
}
