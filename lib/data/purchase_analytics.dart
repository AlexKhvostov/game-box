import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_analytics.dart';

/// Best-effort product telemetry, independent of purchase verification/credit.
/// Keeps the last 1000 confirmations across restarts; never stores purchase tokens.
class PurchaseAnalytics {
  static Future<void> _queue = Future.value();
  static Future<void> confirmed({
    required String product,
    required String operation,
    required String deduplicationId,
    String storagePrefix = '',
  }) {
    if (AppAnalytics.sink == null) return Future.value();
    final context = Map<String, Object>.of(AppAnalytics.context);
    _queue = _queue
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          final key = '${storagePrefix}analytics_purchase_confirmations_v1';
          final seen = prefs.getStringList(key) ?? <String>[];
          if (seen.contains(deduplicationId)) return;
          seen.add(deduplicationId);
          if (seen.length > 1000) seen.removeRange(0, seen.length - 1000);
          if (!await prefs.setStringList(key, seen)) return;
          await AppAnalytics.log(
            'purchase_result',
            params: {
              ...context,
              'product_id': product,
              'operation_id': operation,
              'status': 'confirmed',
            },
          );
        })
        .catchError((Object _) {});
    return _queue;
  }
}
