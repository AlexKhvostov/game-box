import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/data/app_analytics.dart';
import 'package:game_box/data/ui_summary.dart';
import 'package:game_box/data/round_analytics.dart';
import 'package:game_box/data/purchase_analytics.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/domain/enemy_pace.dart';
import 'package:game_box/ui/analytics_navigation.dart';
import 'package:game_box/ui/analytics_feature.dart';
import 'simple_energy_test.dart' as energy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final events = <({String name, Map<String, Object> params})>[];
  List<Map<String, Object>> named(String name) =>
      events.where((e) => e.name == name).map((e) => e.params).toList();
  setUp(() {
    events.clear();
    AppAnalytics.ui = UiSummary(
      nowMs: () => 0,
      wallMs: () => 0,
      nextId: AppAnalytics.nextId,
    );
    AppAnalytics.context.clear();
    AppAnalytics.sink = (name, params) async {
      events.add((name: name, params: params ?? {}));
    };
  });
  tearDown(() {
    AppAnalytics.sink = null;
    AppAnalytics.context.clear();
  });

  test('Reading prices during layout does not report user clicks', () async {
    final account = MobileAccount();
    final billing = PlayBillingService(account, testServicePreview: true);
    for (var i = 0; i < 100; i++) {
      billing.energyOfferPrice('energy_100_v1');
    }
    expect(named('feature_clicked'), isEmpty);
    await AppAnalytics.flushUi('test');
    expect(named('ui_summary'), isEmpty);
    billing.dispose();
    account.dispose();
  });

  test(
    'Confirmed purchase callbacks deduplicate across calls and separate purchases',
    () async {
      SharedPreferences.setMockInitialValues({});
      await Future.wait(
        List.generate(
          4,
          (_) => PurchaseAnalytics.confirmed(
            product: 'energy_100_v1',
            operation: 'one',
            deduplicationId: 'opaque-one',
          ),
        ),
      );
      await PurchaseAnalytics.confirmed(
        product: 'energy_100_v1',
        operation: 'two',
        deduplicationId: 'opaque-two',
      );
      expect(named('purchase_result'), hasLength(2));
      final stored = (await SharedPreferences.getInstance()).getStringList(
        'analytics_purchase_confirmations_v1',
      );
      expect(stored, ['opaque-one', 'opaque-two']);
      await PurchaseAnalytics.confirmed(
        product: 'energy_100_v1',
        operation: 'restored',
        deduplicationId: 'opaque-one',
      );
      expect(named('purchase_result'), hasLength(2));
    },
  );

  test(
    'Brake delay uses exact ready boundary and counts separate recharge cycles',
    () {
      final pace = EnemyPace(const EnemyPaceSettings());
      final trace = RoundAnalytics()..start(helmet: false, jump: false);
      pace.advance(9.4);
      trace.observeBrake(pace);
      final wait = pace.elapsed - pace.readyAt;
      expect(pace.press(), isTrue);
      trace.brakeUsed(pace, readyWaitSec: wait);
      expect(named('ability_used'), isEmpty);
      // Effective enemy clock was rewound, but the readiness clock was not.
      expect(pace.effective, closeTo(3.4, 1e-8));
      pace.advance(6);
      trace.observeBrake(pace);
      final secondWait = pace.elapsed - pace.readyAt;
      expect(pace.press(), isTrue);
      trace.brakeUsed(pace, readyWaitSec: secondWait);
      expect(named('ability_used'), isEmpty);
      pace.advance(8.5);
      trace.observeBrake(pace);
      trace.finish(timeMs: 23900, pace: pace);
      final result = named('game_finish').single;
      expect(result['brake_ready_count'], 3);
      expect(result['brake_use_count'], 2);
      expect(result['brake_wait_sum_ms'], 3400);
      expect(result['brake_wait_count'], 2);
      expect(result['brake_wait_3_5s_count'], 1);
      expect(result['brake_wait_under_1s_count'], 1);
      expect(result['brake_ready_unused_at_finish'], true);
      expect(result['brake_ready_unused_ms'], 2500);
      expect(named('game_start'), hasLength(1));
      expect(named('screen_view'), isEmpty);
      trace.finish(timeMs: 23900, pace: pace);
      expect(named('game_finish'), hasLength(1));
    },
  );

  test(
    'Early death is not an unused ready brake; frame samples never duplicate availability',
    () {
      final pace = EnemyPace(const EnemyPaceSettings());
      final trace = RoundAnalytics()..start(helmet: false, jump: false);
      pace.advance(5.9);
      trace.finish(timeMs: 5900, pace: pace);
      expect(named('ability_available'), isEmpty);
      expect(
        named('game_finish').single['brake_ready_unused_at_finish'],
        false,
      );
      trace.start(helmet: true, jump: false);
      pace.advance(.2);
      for (var i = 0; i < 120; i++) {
        trace.observeBrake(pace);
      }
      expect(named('ability_available'), isEmpty);
      trace.finish(reason: 'interrupted', pace: pace);
      expect(named('game_finish'), hasLength(1));
    },
  );

  test('Disabled brake is not counted even in a long run', () {
    final pace = EnemyPace(const EnemyPaceSettings(brakeEnabled: false))
      ..advance(100);
    final trace = RoundAnalytics()..start(helmet: false, jump: false);
    trace.observeBrake(pace);
    trace.finish(pace: pace);
    expect(named('ability_available'), isEmpty);
    expect(named('game_finish').single['brake_ready_count'], 0);
  });

  test('Analytics failures cannot escape into gameplay', () async {
    AppAnalytics.sink = (_, _) async => throw StateError('offline');
    await AppAnalytics.log('game_start');
    AppAnalytics.sink = (_, _) => throw StateError('unavailable');
    await AppAnalytics.log('game_start');
    AppAnalytics.sink = null;
    await AppAnalytics.log('game_start');
  });

  test(
    'Window exposure excludes background and an overlay in a different navigator',
    () async {
      var time = 0;
      final game = AnalyticsNavigatorObserver(nowMs: () => time);
      final root = AnalyticsNavigatorObserver(nowMs: () => time);
      final window = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
        settings: analyticsWindow('energy'),
      );
      final overlay = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
        settings: analyticsWindow('confirmation'),
      );
      game.didPush(window, null);
      time = 100;
      root.didPush(overlay, null);
      time = 300;
      root.didPop(overlay, null);
      time = 350;
      game.didChangeAppLifecycleState(AppLifecycleState.paused);
      time = 1000;
      game.didChangeAppLifecycleState(AppLifecycleState.resumed);
      time = 1100;
      game.didPop(window, null);
      expect(named('window_opened'), isEmpty);
      await AppAnalytics.flushUi('test');
      final summary = named('ui_summary').single;
      expect(summary['window_confirmation_active_ms'], 200);
      expect(summary['window_energy_active_ms'], 250);
      expect(summary['window_energy_open_count'], 1);
      expect(summary['window_energy_close_count'], 1);
      game.dispose();
      root.dispose();
    },
  );

  test(
    'Only confirmed rewards are successful; request arguments never enter analytics',
    () async {
      final store = await energy.store();
      store.sendEnergyOperation = (_, _) async => throw StateError('network');
      await expectLater(store.claimSimpleEnergyBonus(), throwsStateError);
      expect(named('reward_claim_result').single['status'], 'unconfirmed');
      store.sendEnergyOperation = (_, _) async {};
      await store.claimSimpleEnergyBonus();
      expect(named('reward_claim_result').last['status'], 'confirmed');
      expect(named('reward_claim_result').last['amount'], 0);
      expect(
        events.any(
          (e) =>
              e.params.containsKey('comment') || e.params.containsKey('args'),
        ),
        false,
      );
      store.dispose();
    },
  );

  testWidgets(
    'Visible feature is counted once across rebuilds, again when enabled state changes',
    (tester) async {
      Widget build(bool enabled) => MaterialApp(
        home: Scaffold(
          body: AnalyticsFeature(
            feature: 'shop',
            placement: 'home',
            enabled: enabled,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      await tester.pumpWidget(build(false));
      await tester.pump();
      await tester.pumpWidget(build(false));
      await tester.pump();
      await AppAnalytics.flushUi('test');
      expect(named('feature_shown'), isEmpty);
      expect(
        named('ui_summary').single['feature_home_shop_shown_disabled_count'],
        1,
      );
      await tester.pumpWidget(build(true));
      await tester.pump();
      await AppAnalytics.flushUi('test');
      expect(
        named('ui_summary').last['feature_home_shop_shown_enabled_count'],
        1,
      );
    },
  );

  testWidgets(
    'Offscreen feature is not an impression until scrolled into view',
    (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: SingleChildScrollView(
                controller: controller,
                child: const Column(
                  children: [
                    // Inside the screen but clipped by the 200px viewport.
                    SizedBox(height: 300),
                    AnalyticsFeature(
                      feature: 'deep',
                      placement: 'energy',
                      child: SizedBox(width: 100, height: 100),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(named('feature_shown'), isEmpty);
      controller.jumpTo(300);
      await tester.pump();
      await tester.pump();
      await AppAnalytics.flushUi('test');
      expect(
        named('ui_summary').single['feature_energy_deep_shown_enabled_count'],
        1,
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
