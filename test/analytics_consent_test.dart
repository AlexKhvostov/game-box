import 'dart:async';
import 'dart:convert';
import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/analytics_consent.dart';
import 'package:game_box/data/app_analytics.dart';
import 'package:game_box/data/appmetrica_analytics.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/ui_summary_outbox.dart';

class Transport extends AnalyticsTransport {
  final configs = <AppMetricaConfig>[];
  final sendingValues = <bool>[];
  final events = <String>[];
  final started = Completer<void>();
  Completer<void>? activation, eventBlock;
  int resumes = 0, pauses = 0;
  @override
  Future<void> activate(AppMetricaConfig config) async {
    configs.add(config);
    if (!started.isCompleted) started.complete();
    if (activation != null) await activation!.future;
  }

  @override
  Future<void> sending(bool value) async {
    sendingValues.add(value);
  }

  @override
  Future<void> profile(String? value) async {}
  @override
  Future<void> event(String name, Map<String, Object> values) async {
    events.add(name);
    if (eventBlock != null) await eventBlock!.future;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> flush() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final age in [null, ...AgeBand.values]) {
    final adult = [
      AgeBand.age18to20,
      AgeBand.age21plus,
      AgeBand.adult18plus,
    ].contains(age);
    test(
      'age $age: explicit adult declaration is required independently of ads',
      () async {
        SharedPreferences.setMockInitialValues({
          if (age != null) AudiencePolicy.storageKey: age.name,
          AnalyticsConsent.permissionKey: true,
        });
        final audience = AudiencePolicy();
        await audience.load();
        final values = <bool>[];
        final consent = AnalyticsConsent(
          audience,
          applyRuntime: (value) async => values.add(value),
        );
        await consent.load();
        expect(consent.eligible, adult);
        expect(consent.enabled, adult);
        expect(values.last, adult);
        expect(audience.adsEnabled, false);
        expect(consent.needsPrompt, adult);
        if (!adult) {
          await expectLater(consent.setEnabled(true), throwsStateError);
        }
        expect(values.where((v) => v), adult ? [true] : isEmpty);
        consent.dispose();
        audience.dispose();
      },
    );
  }
  test(
    'closing the prompt is remembered and never grants permission',
    () async {
      SharedPreferences.setMockInitialValues({
        AudiencePolicy.storageKey: 'adult18plus',
      });
      final a = AudiencePolicy();
      await a.load();
      final c = AnalyticsConsent(a, applyRuntime: (_) async {});
      await c.load();
      await c.markPromptSeen();
      expect(c.needsPrompt, false);
      expect(c.enabled, false);
      final restored = AnalyticsConsent(a, applyRuntime: (_) async {});
      await restored.load();
      expect(restored.needsPrompt, false);
      expect(restored.enabled, false);
      c.dispose();
      restored.dispose();
      a.dispose();
    },
  );
  test(
    'age correction revokes permission immediately; returning to adult does not restore it',
    () async {
      SharedPreferences.setMockInitialValues({
        AudiencePolicy.storageKey: 'adult18plus',
      });
      final a = AudiencePolicy();
      await a.load();
      final values = <bool>[];
      final c = AnalyticsConsent(a, applyRuntime: (v) async => values.add(v));
      await c.load();
      await c.setEnabled(true);
      expect(c.enabled, true);
      await a.correct(AgeBand.under18);
      expect(c.enabled, false);
      expect(values.last, false);
      await a.correct(AgeBand.adult18plus);
      expect(c.enabled, false);
      final disk = await SharedPreferences.getInstance();
      expect(disk.getBool(AnalyticsConsent.permissionKey), false);
      c.dispose();
      a.dispose();
    },
  );

  group('SDK boundary', () {
    late Transport sdk;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppMetricaAnalytics.resetForTesting();
      sdk = Transport();
      AppMetricaAnalytics.transport = sdk;
      AppMetricaAnalytics.supportedOverride = true;
      AppMetricaAnalytics.keyOverride = 'fixture-not-a-service-key';
    });
    tearDown(() async {
      await AppMetricaAnalytics.resetForTesting();
    });
    test(
      'default initialization does not activate SDK or create an installation ID',
      () async {
        await AppMetricaAnalytics.initialize();
        await AppAnalytics.gameStart();
        await AppMetricaAnalytics.flush();
        expect(sdk.configs, isEmpty);
        expect(sdk.events, isEmpty);
        expect(sdk.sendingValues, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('analytics_install_profile_v1'), isNull);
      },
    );
    test(
      'explicit consent activates with sending initially off and manual sessions',
      () async {
        await AppMetricaAnalytics.setConsent(true);
        expect(sdk.configs, hasLength(1));
        expect(sdk.configs.single.dataSendingEnabled, false);
        expect(sdk.configs.single.sessionsAutoTrackingEnabled, false);
        expect(sdk.configs.single.locationTracking, false);
        expect(sdk.configs.single.advIdentifiersTracking, false);
        expect(sdk.sendingValues, [true]);
        await AppAnalytics.gameStart();
        expect(sdk.events, ['game_start']);
      },
    );
    test('withdrawal during activation never enables sending', () async {
      sdk.activation = Completer<void>();
      final grant = AppMetricaAnalytics.setConsent(true);
      await sdk.started.future;
      final revoke = AppMetricaAnalytics.setConsent(false);
      sdk.activation!.complete();
      await Future.wait([grant, revoke]);
      expect(sdk.sendingValues, isNot(contains(true)));
      expect(AppMetricaAnalytics.collectionEnabled, false);
      await AppAnalytics.gameStart();
      expect(sdk.events, isEmpty);
    });
    test(
      'withdrawal drops queued events and never replays them on re-enable',
      () async {
        await AppMetricaAnalytics.setConsent(true);
        sdk.eventBlock = Completer<void>();
        final first = AppAnalytics.log('first');
        await Future<void>.delayed(Duration.zero);
        final second = AppAnalytics.log('queued-before-revocation');
        final revoke = AppMetricaAnalytics.setConsent(false);
        await AppAnalytics.log('after-revocation');
        expect(AppAnalytics.sink, isNull);
        sdk.eventBlock!.complete();
        await Future.wait([first, second, revoke]);
        sdk.eventBlock = null;
        await AppMetricaAnalytics.setConsent(true);
        expect(sdk.events, ['first']);
        expect(sdk.sendingValues, contains(false));
      },
    );
    test('denied startup erases only the local analytics outbox', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(UiSummaryOutbox.storageKey, [
        jsonEncode({'summary_id': 'old'}),
      ]);
      await prefs.setInt('wallet-preserved', 123);
      await AppMetricaAnalytics.setConsent(false);
      expect(prefs.getStringList(UiSummaryOutbox.storageKey), isNull);
      expect(prefs.getInt('wallet-preserved'), 123);
      await AppMetricaAnalytics.setConsent(true);
      expect(sdk.events, isEmpty);
    });
  });
  test(
    'discarding an in-flight outbox does not save or replay its packets',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final started = Completer<void>(), release = Completer<void>();
      final box = UiSummaryOutbox(prefs, (_) async {
        started.complete();
        await release.future;
      });
      final push = box.push({'summary_id': 'approved-but-pending'});
      await started.future;
      final discard = box.discard();
      release.complete();
      await Future.wait([push, discard]);
      expect(prefs.getStringList(UiSummaryOutbox.storageKey), isNull);
      await box.push({'summary_id': 'not-allowed'});
      expect(prefs.getStringList(UiSummaryOutbox.storageKey), isNull);
    },
  );
}
