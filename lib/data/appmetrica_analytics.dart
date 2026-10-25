import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/app_target.dart';
import 'app_analytics.dart';
import 'ui_summary_outbox.dart';
import 'mobile_account.dart';

/// Small SDK boundary, also used by tests without network or real SDK keys.
abstract class AnalyticsTransport {
  Future<void> activate(AppMetricaConfig config);
  Future<void> sending(bool enabled);
  Future<void> profile(String? id);
  Future<void> event(String name, Map<String, Object> values);
  Future<void> resume();
  Future<void> pause();
  Future<void> flush();
}

class _NativeAnalyticsTransport implements AnalyticsTransport {
  @override
  Future<void> activate(AppMetricaConfig config) => AppMetrica.activate(config);
  @override
  Future<void> sending(bool enabled) =>
      AppMetrica.setDataSendingEnabled(enabled);
  @override
  Future<void> profile(String? id) => AppMetrica.setUserProfileID(id);
  @override
  Future<void> event(String name, Map<String, Object> values) =>
      AppMetrica.reportEventWithMap(name, values);
  @override
  Future<void> resume() => AppMetrica.resumeSession();
  @override
  Future<void> pause() => AppMetrica.pauseSession();
  @override
  Future<void> flush() => AppMetrica.sendEventsBuffer();
}

/// Explicit consent is the only entry point. No activation, installation ID or
/// persisted outbox replay occurs for an unknown/under18/nonconsenting player.
class AppMetricaAnalytics {
  static const apiKey = String.fromEnvironment('APPMETRICA_API_KEY');
  static const environment = String.fromEnvironment(
    'APPMETRICA_ENV',
    defaultValue: 'production',
  );
  static const enabled = bool.fromEnvironment(
    'APPMETRICA_ENABLED',
    defaultValue: true,
  );
  static bool _allowed = false, _active = false, _ready = false;
  static bool? _installedBeforeConsent;
  static int _generation = 0, _queued = 0;
  static Future<void> _control = Future.value(), _queue = Future.value();
  static String? _nativeProfile, _installProfile;
  static UiSummaryOutbox? _uiOutbox;
  static final _lifecycle = _AnalyticsLifecycle();
  static MobileAccount? _account;
  @visibleForTesting
  static AnalyticsTransport transport = _NativeAnalyticsTransport();
  @visibleForTesting
  static bool? supportedOverride;
  @visibleForTesting
  static String? keyOverride;
  static bool get _supported =>
      supportedOverride ??
      (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          AppTargetConfig.isMobile);
  static bool get collectionEnabled => _allowed && _ready;
  static bool get _configured =>
      enabled && _supported && (keyOverride ?? apiKey).isNotEmpty;

  static void bindAccount(MobileAccount account) {
    _account?.removeListener(_updateAccount);
    _account = account;
    account.addListener(_updateAccount);
    _updateAccount();
  }

  static void _updateAccount() {
    if (!collectionEnabled) return;
    final owner = _account?.id;
    final next = owner == null
        ? _installProfile
        : sha256.convert(utf8.encode('untouch-analytics-v1:$owner')).toString();
    if (AppAnalytics.context['profile_key'] != next) {
      unawaited(AppAnalytics.flushUi('identity_changed'));
      if (next != null) AppAnalytics.context['profile_key'] = next;
    }
  }

  /// Kept for older internal tools; an initialize call never grants permission.
  static Future<void> initialize() => setConsent(_allowed);

  static Future<void> setConsent(bool value) {
    _allowed = value;
    final generation = ++_generation;
    if (!value) {
      _ready = false;
      AppAnalytics.sink = null;
      AppAnalytics.resetPrivacyBoundary();
      AppAnalytics.context.remove('profile_key');
      AppAnalytics.context.remove('analytics_environment');
      _lifecycle.stop();
      // Dispatch immediately as well as on the serialized control path.
      if (_active) {
        unawaited(transport.sending(false).catchError((Object _) {}));
      }
    }
    final job = _control.then((_) => _apply(value, generation));
    _control = job.catchError((Object _) {});
    return _control;
  }

  static bool _current(int generation) => _allowed && generation == _generation;

  static Future<void> _apply(bool value, int generation) async {
    final prefs = await SharedPreferences.getInstance();
    _installedBeforeConsent ??= prefs.getKeys().any(
      (key) =>
          key == 'device_sound' ||
          key == 'audience_age_band_v1' ||
          key.contains('wallet') ||
          key.contains('account'),
    );
    if (!value) {
      final old = _uiOutbox;
      _uiOutbox = null;
      if (old != null) {
        await old.discard();
      } else {
        await prefs.remove(UiSummaryOutbox.storageKey);
      }
      if (_active) {
        await transport.sending(false);
        await transport.pause();
      }
      return;
    }
    if (!_current(generation) || !_configured) return;
    try {
      if (!_active) {
        _installProfile = prefs.getString('analytics_install_profile_v1');
        if (_installProfile == null) {
          final random = Random.secure();
          _installProfile = List.generate(
            16,
            (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
          if (!await prefs.setString(
            'analytics_install_profile_v1',
            _installProfile!,
          )) {
            return;
          }
        }
        if (!_current(generation)) return;
        await transport
            .activate(
              AppMetricaConfig(
                keyOverride ?? apiKey,
                userProfileID: _installProfile,
                // Even an activation racing a withdrawal cannot start sending.
                dataSendingEnabled: false,
                locationTracking: false,
                advIdentifiersTracking: false,
                logs: false,
                crashReporting: false,
                flutterCrashReporting: false,
                nativeCrashReporting: false,
                anrMonitoring: false,
                revenueAutoTrackingEnabled: false,
                firstActivationAsUpdate: _installedBeforeConsent,
                sessionsAutoTrackingEnabled: false,
                sessionTimeout: 30,
                dispatchPeriodSeconds: 30,
                appEnvironment: {'analytics_environment': environment},
              ),
            )
            .timeout(const Duration(seconds: 3));
        _active = true;
        _nativeProfile = _installProfile;
      }
      if (!_current(generation)) return;
      await transport.sending(true);
      if (!_current(generation)) return;
      AppAnalytics.sink = null;
      AppAnalytics.resetPrivacyBoundary();
      AppAnalytics.context['profile_key'] = _installProfile!;
      AppAnalytics.context['analytics_environment'] = environment;
      Future<void> send(String name, Map<String, Object>? params) {
        if (!_current(generation)) return Future.value();
        if (_queued >= 200) {
          return Future.error(StateError('analytics_queue_full'));
        }
        _queued++;
        final snapshot = Map<String, Object>.of(params ?? {});
        final profile = snapshot.remove('profile_key') as String?;
        final job = _queue
            .then((_) async {
              if (!_current(generation)) return;
              if (_nativeProfile != profile) {
                await transport.profile(profile);
                _nativeProfile = profile;
              }
              if (!_current(generation)) return;
              await transport.event(name, snapshot);
            })
            .timeout(const Duration(seconds: 3));
        _queue = job.catchError((Object _) {});
        return job.whenComplete(() => _queued--);
      }

      _uiOutbox = UiSummaryOutbox(prefs, (packet) => send('ui_summary', packet))
        ..restore();
      final outbox = _uiOutbox!;
      AppAnalytics.sink = (name, params) => !_current(generation)
          ? Future.value()
          : name == 'ui_summary'
          ? outbox.push(params ?? {})
          : send(name, params);
      _ready = true;
      _updateAccount();
      unawaited(outbox.retry());
      _lifecycle.start();
    } catch (_) {
      _ready = false;
      AppAnalytics.sink = null;
      if (_active) {
        try {
          await transport.sending(false);
        } catch (_) {}
      }
      // Optional SDK failure never blocks the game or logs configuration.
    }
  }

  static Future<void> flush() async {
    if (!collectionEnabled) return;
    try {
      await _queue;
      if (collectionEnabled) await transport.flush();
    } catch (_) {}
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    await setConsent(false);
    await _queue;
    _account?.removeListener(_updateAccount);
    _account = null;
    _active = _ready = _allowed = false;
    _nativeProfile = _installProfile = null;
    _installedBeforeConsent = null;
    _queued = 0;
    supportedOverride = null;
    keyOverride = null;
    transport = _NativeAnalyticsTransport();
  }
}

class _AnalyticsLifecycle extends WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true, _observing = false;
  void start() {
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    AppAnalytics.setUiForeground(_foreground);
    if (_foreground && AppMetricaAnalytics.collectionEnabled) {
      unawaited(
        AppMetricaAnalytics.transport.resume().catchError((Object _) {}),
      );
    }
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_foreground || !AppMetricaAnalytics.collectionEnabled) return;
      AppAnalytics.checkpointWindows?.call();
      if (AppAnalytics.ui.due) {
        await AppAnalytics.flushUi('interval');
        await AppMetricaAnalytics._uiOutbox?.retry();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground || !AppMetricaAnalytics.collectionEnabled) {
      return;
    }
    _foreground = foreground;
    AppAnalytics.setUiForeground(foreground);
    if (!foreground) {
      unawaited(
        AppMetricaAnalytics.transport.pause().catchError((Object _) {}),
      );
      unawaited(
        AppAnalytics.flushUi(
          'background',
        ).then((_) => AppMetricaAnalytics.flush()),
      );
    } else {
      unawaited(
        AppMetricaAnalytics.transport.resume().catchError((Object _) {}),
      );
      unawaited(AppMetricaAnalytics._uiOutbox?.retry());
    }
  }
}
