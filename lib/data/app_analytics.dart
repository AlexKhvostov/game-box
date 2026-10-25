import 'ui_summary.dart';

// Product events stay independent of the SDK. An absent/failed sink is harmless.
class AppAnalytics {
  AppAnalytics._();

  static Future<void> Function(String, Map<String, Object>?)? sink;
  static final Map<String, Object> context = {};
  static String screen = 'home';
  static int _sequence = 0;
  static final _clock = Stopwatch()..start();
  static UiSummary ui = UiSummary(
    nowMs: () => _clock.elapsedMilliseconds,
    wallMs: () => DateTime.now().millisecondsSinceEpoch,
    nextId: nextId,
  );
  static void Function()? checkpointWindows;
  static void Function()? resetWindowTiming;
  static int privacyEpoch = 0;
  static void resetPrivacyBoundary() {
    privacyEpoch++;
    ui.clear();
    _uiContext = null;
    resetWindowTiming?.call();
  }

  static void Function(bool)? windowsForeground;
  static bool Function()? hasActiveWindows;
  static Map<String, Object>? _uiContext;
  static bool _flushingUi = false;
  static String nextId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';
  static Future<void> log(String name, {Map<String, Object>? params}) async {
    try {
      if (sink == null) return;
      if (UiSummary.aggregatedEvents.contains(name)) {
        if (!_flushingUi &&
            _uiContext != null &&
            _uiContext.toString() != context.toString()) {
          flushUi('context_changed');
        }
        if (!_flushingUi) _uiContext = Map.of(context);
        ui.record(name, params ?? {});
        return;
      }
      await sink?.call(name, {
        'analytics_schema_version': 2,
        ...context,
        ...?params,
      });
    } catch (_) {
      /* Optional telemetry cannot break gameplay. */
    }
  }

  static Future<void> flushUi(String reason) async {
    if (_flushingUi) return;
    _flushingUi = true;
    try {
      checkpointWindows?.call();
      final snapshot = ui.take(reason);
      final capturedContext = _uiContext ?? Map<String, Object>.of(context);
      _uiContext = null;
      if (hasActiveWindows?.call() == true) ui.continueInterval();
      _flushingUi = false;
      if (snapshot == null) return;
      await sink?.call('ui_summary', {
        'analytics_schema_version': 2,
        ...capturedContext,
        ...snapshot,
      });
    } catch (_) {
      /* Optional analytics must not interrupt the app. */
    } finally {
      _flushingUi = false;
    }
  }

  static void setUiForeground(bool value) {
    windowsForeground?.call(value);
    ui.setForeground(value);
    if (value && hasActiveWindows?.call() == true) ui.continueInterval();
  }

  static void event(String name, [Map<String, Object> params = const {}]) {
    // log catches both synchronous and asynchronous failures.
    log(name, params: params);
  }

  static void view(String name) {
    screen = name;
    event('screen_view', {'screen': name});
  }

  static void click(String feature, {String? placement}) => event(
    'feature_clicked',
    {'feature': feature, 'placement': placement ?? screen},
  );

  static void page(
    String container,
    String page, {
    String source = 'navigation',
  }) => event('page_selected', {
    'container': container,
    'page': page,
    'source': source,
  });

  /// Старт приложения (не путать с авто-событием GA session_start).
  static Future<void> appOpen() => log('app_open');

  static Future<void> gameStart() => log('game_start');

  static Future<void> gameFinish({
    required int timeMs,
    int riskCount = 0,
    int runDistance = 0,
  }) => log(
    'game_finish',
    params: {
      'time_ms': timeMs,
      'risk_count': riskCount,
      'run_distance': runDistance,
    },
  );

  static Future<void> tapLives() => log('tap_lives');

  static Future<void> tapCrystals() => log('tap_crystals');

  static Future<void> tapRecord() => log('tap_record');

  static Future<void> openDaily() => log('open_daily');

  static Future<void> openShop() => log('open_shop');

  static Future<void> openRent() => log('open_rent');

  static Future<void> openEarn() => log('open_earn');

  static Future<void> claimDaily({int? tokens}) =>
      log('claim_daily', params: tokens == null ? null : {'tokens': tokens});

  static Future<void> claimGift({int? tokens}) =>
      log('claim_gift', params: tokens == null ? null : {'tokens': tokens});

  static Future<void> buyLifePack({required int lives, required int cost}) =>
      log('buy_life_pack', params: {'lives': lives, 'cost': cost});

  static Future<void> tapPlus() => log('tap_plus');

  static Future<void> plusActivate() => log('plus_activate');

  static Future<void> plusCancel() => log('plus_cancel');

  static Future<void> shareOpen() => log('share_open');

  static Future<void> shareSocial() => log('share_social');

  static Future<void> openCrystalsTab(int index) {
    switch (index) {
      case 0:
        return openDaily();
      case 1:
        return openShop();
      case 2:
        return openRent();
      case 3:
        return openEarn();
      default:
        return Future.value();
    }
  }
}
