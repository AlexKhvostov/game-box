// Reproductions of current behavior. Passing confirms the reported defect;
// these are audit probes, not acceptance tests for corrected behavior.
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_world.dart';
import 'package:game_box/features/game/game_start_guard.dart';
import 'package:game_box/data/android_firebase_config.dart';
import '../../../../test/instant_round_journal_test.dart' as fixture;
import '../../../../test/simple_energy_test.dart' as energy;

class FinishRefusalServer extends fixture.RunServer {
  @override
  Future<Map<String,dynamic>> send(Map<String,dynamic> command) async {
    if (!offline && command['action']=='round_finish') {
      commands.add(Map<String,dynamic>.from(command));
      throw const MobileApiError('result_time_invalid');
    }
    return super.send(command);
  }
}

class RankingRunAccount extends fixture.RunAccount {
  RankingRunAccount(super.server);
  @override
  String get storagePrefix=>'supabase_android_probe_';
  int rankingRequests=0;
  @override
  Future<Map<String,dynamic>> request(Map<String,dynamic> payload,{bool guest=false}) async {
    if(payload['action']!='scores') throw const MobileApiError('audit_unexpected_action');
    rankingRequests++;
    final finished=server.rounds.entries.where((e)=>e.value['finished']==true);
    return {'ok':true,'periods':{for(final p in ['all','day','week','month','year']) p:[
      for(final entry in finished) {'id':entry.key,'playerName':'Mine','userId':id,'timeMs':1,'createdAt':1,'place':1}
    ]}};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('R01 rankFor ignores true place 520 and counts only downloaded rows', () async {
    final a = MobileAccount(storagePrefix: 'supabase_android_probe_', client: MockClient((request) async {
      return http.Response(jsonEncode({'ok':true,'periods': {
        for (final p in ['all','day','week','month','year']) p: [
          for (var i = 1; i <= 200; i++) {
            'id':'$i','userId':'other:$i','playerName':'Other',
            'timeMs':10000-i,'createdAt':1,'place':i,
          },
          {'id':'own','userId':fixture.owner,'playerName':'Mine','timeMs':1000,'createdAt':1,'place':520},
        ],
      }}), 200);
    }))..id = fixture.owner;
    final s = ScoresStore(account:a);
    await s.load();
    expect(s.scores.last.place,520);
    expect(s.rankFor(1000).place,201);
    expect(s.rankFor(1000).percentile,0);
    s.dispose(); a.dispose();
  });

  Future<(EconomyStore, fixture.RunAccount, ScoresStore)> setup(fixture.RunServer server) async {
    final e=EconomyStore(); await e.load();
    await e.applyServerWallet(server.wallet(),owner:fixture.owner,serverNow:energy.stamp);
    final a=fixture.RunAccount(server);
    final s=ScoresStore(account:a,instantEconomy:e);
    await s.loadLocal();
    return(e,a,s);
  }

  test('R02 rules_changed silently rejects the whole new run and remains pending', () async {
    final server=fixture.RunServer()..offline=true;
    final(e,a,s)=await setup(server);
    expect(s.beginInstantRound(helmet:false,jump:false,cost:1),isNotNull);
    await s.recordAttempt(1); await fixture.flush();
    server.offline=false; server.refusal='rules_changed';
    await s.retryPendingResults(); await fixture.flush();
    final rows=jsonDecode((await SharedPreferences.getInstance()).getString('${a.storagePrefix}instant_rounds_v1_${a.id}')!) as List;
    expect(rows.single['rejected'],'rules_changed');
    expect(s.myAttempts.single.shared,false);
    expect(s.isAttemptPending(s.myAttempts.single.id),true);
    expect(a.roundError,isNull); expect(a.error,isNull);
    // Another run is still admitted using the same obsolete revision.
    expect(s.beginInstantRound(helmet:false,jump:false,cost:1),isNotNull);
    s.dispose(); a.dispose(); e.dispose();
  });

  test('R03 permanent result_time_invalid prevents a later valid row from progressing', () async {
    final server=FinishRefusalServer()..offline=true;
    final(e,a,s)=await setup(server);
    expect(s.beginInstantRound(helmet:false,jump:false,cost:1),isNotNull);
    await s.recordAttempt(1);
    await fixture.flush();
    server.offline=false; server.commands.clear();
    await s.retryPendingResults();await Future<void>.delayed(const Duration(milliseconds:25));await fixture.flush();
    expect(server.commands.any((c)=>c['action']=='round_finish'),true);
    final second=s.beginInstantRound(helmet:false,jump:false,cost:1);
    expect(second,isNotNull);await s.recordAttempt(1);
    for(var i=0;i<3;i++) { await s.retryPendingResults(); await Future<void>.delayed(const Duration(milliseconds:20)); await fixture.flush(); }
    expect(server.commands.where((c)=>c['action']=='round_finish').length,greaterThanOrEqualTo(2));
    expect(server.commands.where((c)=>c['action']=='round_finish').map((c)=>c['roundId']).toSet().length,1);
    expect(server.commands.any((c)=>c['action']=='round_start'&&c['requestId']==second),false);
    expect(s.myAttempts.every((a)=>s.isAttemptPending(a.id)),true);
    s.dispose(); a.dispose(); e.dispose();
  });

  test('R04 an individual pointer move crosses a whole enemy without collision', () {
    final w=GameWorld(config:const GameplayConfig(),field:const Size.square(380))..resetLayout();
    w.player=const Offset(50,150);
    final e=w.enemies.first;
    e.pos=const Offset(160,150); e.orientDeg=0;
    w.enemies..clear()..add(e);
    expect(w.playerHitsEnemy(),false);
    final swept=Rect.fromLTRB(50,150,300+w.playerSize,150+w.playerSize);
    expect(e.overlapsAabb(swept),true);
    w.movePlayerBy(const Offset(250,0));
    expect(w.playerHitsEnemy(),false);
  });

  test('R05 completed old-owner pending results do not block switching owner', () async {
    final server=fixture.RunServer()..offline=true;
    final(e,a,s)=await setup(server);
    s.beginInstantRound(helmet:false,jump:false,cost:1);
    await s.recordAttempt(1); await fixture.flush();
    final oldId=s.myAttempts.single.id;
    expect(s.isAttemptPending(oldId),true);
    await a.beforeIdentityChange!();
    a.id='supabase:12345678-1234-4234-8234-123456789abd';
    a.notifyListeners(); await fixture.flush();
    expect(s.myAttempts,isEmpty);
    final prefs=await SharedPreferences.getInstance();
    expect(prefs.getString('${a.storagePrefix}instant_rounds_v1_${fixture.owner}'),contains(oldId));
    s.dispose(); a.dispose(); e.dispose();
  });

  test('R08 accepted Remote Config value player.size=4 makes the field unplayable', () async {
    final snapshot=jsonDecode(await rootBundle.loadString(AndroidFirebaseConfig.assetPath)) as Map<String,dynamic>;
    snapshot['config']['player']['size']=4;
    snapshot['revision']=sha256.convert(utf8.encode(jsonEncode(snapshot['config']))).toString();
    final config=AndroidFirebaseConfig.parse(jsonEncode(snapshot),'audit-only').gameplay;
    final w=GameWorld(config:config,field:const Size.square(380))..resetLayout();
    expect(GameStartGuard.check(world:w,paintedSize:const Size.square(380),
      displayedField:const Rect.fromLTWH(0,0,380,380),visibleScreen:const Rect.fromLTWH(0,0,412,800),devicePixelRatio:3), 'hero_scale');
  });

  test('R09 corrupt disposable score cache makes awaited startup load fail', () async {
    SharedPreferences.setMockInitialValues({'supabase_android_probe_local_scores_v2_pending':'broken-json'});
    final a=MobileAccount(storagePrefix:'supabase_android_probe_');
    final s=ScoresStore(account:a,storagePrefix:'supabase_android_probe_');
    await expectLater(s.loadLocal(),throwsA(isA<FormatException>()));
    s.dispose();a.dispose();
  });

  test('R10 publication marks history shared but leaves an open ranking unchanged', () async {
    final server=fixture.RunServer();
    final e=EconomyStore(); await e.load();
    await e.applyServerWallet(server.wallet(),owner:fixture.owner,serverNow:energy.stamp);
    final a=RankingRunAccount(server);
    final s=ScoresStore(account:a,instantEconomy:e);
    await s.loadLocal();await s.load();expect(a.rankingRequests,1);
    s.beginInstantRound(helmet:false,jump:false,cost:1);await s.recordAttempt(1);
    await Future<void>.delayed(const Duration(milliseconds:25));
    await s.retryPendingResults();await fixture.flush();
    expect(s.myAttempts.single.shared,true);
    expect(s.scores,isEmpty);expect(a.rankingRequests,1);
    await s.refreshIfStale();expect(s.scores.length,1);
    s.dispose();a.dispose();e.dispose();
  });
}
