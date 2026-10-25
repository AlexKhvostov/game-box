import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/app_analytics.dart';
import 'package:game_box/data/round_analytics.dart';
import 'package:game_box/data/ui_summary.dart';
import 'package:game_box/data/ui_summary_outbox.dart';
import 'package:game_box/domain/enemy_pace.dart';
import 'package:game_box/ui/analytics_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final events = <({String name, Map<String, Object> p})>[];
  var t = 0;
  List<Map<String, Object>> named(String name) =>
      events.where((e) => e.name == name).map((e) => e.p).toList();
  setUp(() {
    t = 0;
    events.clear();
    AppAnalytics.context.clear();
    AppAnalytics.ui = UiSummary(
      nowMs: () => t,
      wallMs: () => 1000000 + t,
      nextId: AppAnalytics.nextId,
    );
    AppAnalytics.sink = (name, p) async {
      events.add((name: name, p: Map.of(p ?? {})));
    };
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    AppAnalytics.sink = null;
    AppAnalytics.context.clear();
  });

  test(
    'many actions produce exactly start + finish with exact weighted counters',
    () {
      AppAnalytics.context['config_revision'] = 'before';
      final round = RoundAnalytics()..start(helmet: true, jump: true);
      final pace = EnemyPace(const EnemyPaceSettings());
      final delays = [.5, 1.0, 2.9996, 3.0, 5.0, 10.0];
      for (final wait in delays) {
        pace.advance(6 + wait);
        for (var i = 0; i < 120; i++) {
          round.observeBrake(pace);
        }
        expect(pace.press(), true);
        round.brakeUsed(pace, readyWaitSec: wait);
        round.abilityUsed('jump', timeMs: 1);
      }
      round.abilityUsed('helmet', timeMs: 1);
      AppAnalytics.context['config_revision'] = 'after';
      round.finish(timeMs: 100000, pace: pace);
      round.finish(timeMs: 100000, pace: pace);
      expect(events.map((e) => e.name), ['game_start', 'game_finish']);
      final p = named('game_finish').single;
      expect(p['analytics_schema_version'], 2);
      expect(p['config_revision'], 'before');
      expect(p['run_id'], named('game_start').single['run_id']);
      expect(p['brake_wait_count'], 6);
      expect(p['brake_ready_count'], 6);
      expect(p['brake_wait_sum_ms'], 22500);
      expect(p['brake_wait_min_ms'], 500);
      expect(p['brake_wait_max_ms'], 10000);
      expect(p['brake_wait_under_1s_count'], 1);
      expect(
        p['brake_wait_1_3s_count'],
        2,
      ); // Classify before rounding 2.9996s.
      expect(p['brake_wait_3_5s_count'], 1);
      expect(p['brake_wait_5_10s_count'], 1);
      expect(p['brake_wait_10s_or_more_count'], 1);
      expect(p['jump_use_count'], 6);
      expect(p['helmet_use_count'], 1);
    },
  );
  test('no measurement is not a zero-second observation', () {
    final round = RoundAnalytics()..start(helmet: false, jump: false);
    final pace = EnemyPace(const EnemyPaceSettings())..advance(7);
    round.finish(timeMs: 7000, pace: pace);
    final p = named('game_finish').single;
    expect(p['brake_usage_state'], 'ready_unused');
    expect(p['brake_wait_count'], 0);
    expect(p.containsKey('brake_wait_min_ms'), false);
    expect(p['brake_ready_unused_ms'], 1000);
    expect(p['brake_first_wait_bucket'], 'no_use');
  });
  test(
    'abandoned attempt emits no false finish; next attempt resets counters',
    () {
      final round = RoundAnalytics()..start(helmet: true, jump: true);
      round.abilityUsed('jump', timeMs: 10);
      round.finish(reason: 'screen_disposed');
      expect(named('game_finish'), isEmpty);
      round.start(helmet: false, jump: false);
      round.finish(timeMs: 2000);
      expect(named('game_start'), hasLength(2));
      expect(named('game_finish').single['jump_use_count'], 0);
      expect(named('game_finish').single['brake_usage_state'], 'disabled');
    },
  );
  test(
    'UI preserves multiplicity, configuration values, pages and legacy clicks',
    () async {
      for (var i = 0; i < 100; i++) {
        AppAnalytics.click('profile', placement: 'hud');
      }
      AppAnalytics.view('result');
      AppAnalytics.view('playing');
      AppAnalytics.page('energy', 'video');
      AppAnalytics.event('ability_configured', {
        'ability': 'jump',
        'value': true,
      });
      await AppAnalytics.tapPlus();
      expect(events, isEmpty);
      await AppAnalytics.flushUi('background');
      final p = named('ui_summary').single;
      expect(p['feature_hud_profile_click_count'], 100);
      expect(p['screen_result_view_count'], 1);
      expect(p.containsKey('screen_playing_view_count'), false);
      expect(p['ability_jump_last_selected'], true);
      expect(p['page_energy_video_select_count'], 1);
      expect(p['legacy_tap_plus_count'], 1);
      await AppAnalytics.flushUi('background');
      expect(events, hasLength(1));
    },
  );
  test(
    'window time is split at interval, without duplicate opens or background',
    () async {
      final nav = AnalyticsNavigatorObserver(nowMs: () => t);
      final route = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
        settings: analyticsWindow('profile'),
      );
      nav.didPush(route, null);
      t = 300000;
      expect(AppAnalytics.ui.due, true);
      await AppAnalytics.flushUi('interval');
      // No gesture or navigation for another five minutes: the timer must still
      // produce a second packet for the same open window.
      t = 600000;
      AppAnalytics.checkpointWindows?.call();
      expect(AppAnalytics.ui.due, true);
      await AppAnalytics.flushUi('interval');
      expect(named('ui_summary')[1]['window_profile_active_ms'], 300000);
      t = 600000;
      t = 601000;
      AppAnalytics.setUiForeground(false);
      await AppAnalytics.flushUi('background');
      t = 999000;
      AppAnalytics.setUiForeground(true);
      t = 1000000;
      nav.didPop(route, null);
      await AppAnalytics.flushUi('test');
      final packets = named('ui_summary');
      expect(packets[0]['window_profile_open_count'], 1);
      expect(packets[0]['window_profile_active_ms'], 300000);
      expect(packets[2]['window_profile_active_ms'], 1000);
      expect(packets[3]['window_profile_active_ms'], 1000);
      expect(
        packets.skip(1).any((p) => p.containsKey('window_profile_open_count')),
        false,
      );
      nav.dispose();
    },
  );
  test(
    'UI context change splits users/configs with no recursive flush',
    () async {
      AppAnalytics.context['profile_key'] = 'A';
      AppAnalytics.click('profile', placement: 'hud');
      final nav = AnalyticsNavigatorObserver(nowMs: () => t);
      final route = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
        settings: analyticsWindow('profile'),
      );
      nav.didPush(route, null);
      t = 500;
      AppAnalytics.context['profile_key'] = 'B';
      AppAnalytics.click('energy', placement: 'hud');
      await AppAnalytics.flushUi('test');
      final packets = named('ui_summary');
      expect(packets, hasLength(2));
      expect(packets[0]['profile_key'], 'A');
      expect(packets[0]['window_profile_active_ms'], 500);
      expect(packets[0].containsKey('feature_hud_energy_click_count'), false);
      expect(packets[1]['profile_key'], 'B');
      nav.didPop(route, null);
      nav.dispose();
    },
  );
  test(
    'consent boundary discards earlier window time and unfinished rounds',
    () async {
      final nav = AnalyticsNavigatorObserver(nowMs: () => t);
      final route = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
        settings: analyticsWindow('profile'),
      );
      nav.didPush(route, null);
      final round = RoundAnalytics()..start(helmet: false, jump: true);
      t = 12000;
      AppAnalytics.sink = null;
      AppAnalytics.resetPrivacyBoundary();
      t = 24000;
      AppAnalytics.resetPrivacyBoundary();
      AppAnalytics.sink = (name, p) async {
        events.add((name: name, p: Map.of(p ?? {})));
      };
      t = 24500;
      round.finish(timeMs: 24500);
      nav.didPop(route, null);
      await AppAnalytics.flushUi('test');
      expect(named('game_finish'), isEmpty);
      final packet = named('ui_summary').single;
      expect(packet['window_profile_active_ms'], 500);
      expect(packet.containsKey('window_profile_open_count'), false);
      nav.dispose();
    },
  );
  test('counter cardinality and JSON payload remain bounded', () async {
    for (var i = 0; i < 10000; i++) {
      AppAnalytics.click('button_$i', placement: 'hud');
    }
    AppAnalytics.click('private value with spaces', placement: 'hud');
    await AppAnalytics.flushUi('test');
    final p = named('ui_summary').single;
    expect(p['counters_truncated'], true);
    expect(p.length, lessThan(200));
    expect(utf8.encode(jsonEncode(p)).length, lessThan(16000));
    expect(jsonEncode(p).contains('private value with spaces'), false);
  });
  test('rare business outcomes remain immediate', () {
    for (final name in [
      'purchase_result',
      'ad_result',
      'reward_claim_result',
      'account_action_result',
    ]) {
      AppAnalytics.event(name, {'status': 'confirmed'});
    }
    expect(events, hasLength(4));
    expect(events.every((e) => e.p['analytics_schema_version'] == 2), true);
  });
  test(
    'outbox recovers offline UI packet once SDK becomes available',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final offline = UiSummaryOutbox(
        prefs,
        (_) async => throw StateError('offline'),
      )..restore();
      await offline.push({'summary_id': 's1', 'profile_key': 'A', 'count': 3});
      expect(prefs.getStringList(UiSummaryOutbox.storageKey), hasLength(1));
      final delivered = <Map<String, Object>>[];
      final restarted = UiSummaryOutbox(prefs, (p) async {
        delivered.add(Map.of(p));
      })..restore();
      await Future.wait([restarted.retry(), restarted.retry()]);
      expect(delivered, [
        {'summary_id': 's1', 'profile_key': 'A', 'count': 3},
      ]);
      expect(prefs.getStringList(UiSummaryOutbox.storageKey), isEmpty);
    },
  );
  test('outbox concurrency and overflow remain bounded and explicit', () async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = UiSummaryOutbox(
      prefs,
      (_) async => throw StateError('offline'),
    );
    await Future.wait(
      List.generate(20, (i) => outbox.push({'summary_id': 's$i'})),
    );
    final pending = prefs.getStringList(UiSummaryOutbox.storageKey)!;
    expect(pending, hasLength(16));
    expect(jsonDecode(pending.last)['ui_outbox_overflow'], true);
  });
}
