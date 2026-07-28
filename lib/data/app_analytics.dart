import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Firebase Analytics: события MVP из docs/ANALYTICS_AND_ADMIN.md.
///
/// Имена короткие (лимит GA: 40 символов). Ошибки глотаем — игра не падает.
class AppAnalytics {
  AppAnalytics._();

  static FirebaseAnalytics? _fa;
  static bool _enabled = false;

  static Future<void> init() async {
    if (!FirebaseBootstrap.ready) {
      _enabled = false;
      return;
    }
    try {
      _fa = FirebaseAnalytics.instance;
      _enabled = true;
      final uid = FirebaseBootstrap.uid;
      if (uid != null && uid.isNotEmpty) {
        await _fa!.setUserId(id: uid);
      }
    } catch (e) {
      debugPrint('AppAnalytics.init: $e');
      _enabled = false;
    }
  }

  static Future<void> log(
    String name, {
    Map<String, Object>? params,
  }) async {
    if (!_enabled || _fa == null) return;
    try {
      await _fa!.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('AppAnalytics.log($name): $e');
    }
  }

  /// Старт приложения (не путать с авто-событием GA session_start).
  static Future<void> appOpen() => log('app_open');

  static Future<void> gameStart() => log('game_start');

  static Future<void> gameFinish({
    required int timeMs,
    int riskCount = 0,
    int runDistance = 0,
  }) =>
      log('game_finish', params: {
        'time_ms': timeMs,
        'risk_count': riskCount,
        'run_distance': runDistance,
      });

  static Future<void> tapLives() => log('tap_lives');

  static Future<void> tapCrystals() => log('tap_crystals');

  static Future<void> tapRecord() => log('tap_record');

  static Future<void> openDaily() => log('open_daily');

  static Future<void> openShop() => log('open_shop');

  static Future<void> openRent() => log('open_rent');

  static Future<void> openEarn() => log('open_earn');

  static Future<void> claimDaily({int? tokens}) => log(
        'claim_daily',
        params: tokens == null ? null : {'tokens': tokens},
      );

  static Future<void> claimGift({int? tokens}) => log(
        'claim_gift',
        params: tokens == null ? null : {'tokens': tokens},
      );

  static Future<void> buyLifePack({required int lives, required int cost}) =>
      log('buy_life_pack', params: {
        'lives': lives,
        'cost': cost,
      });

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
