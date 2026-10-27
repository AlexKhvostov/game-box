import 'package:flutter/services.dart';

/// Read only this package's OS install date once during native startup.
/// Older native versions retain the saved first-open fallback.
Future<DateTime?> readAppInstallation({DateTime? now}) async {
  try {
    final version = await const MethodChannel('untouch/support')
        .invokeMapMethod<String, dynamic>('appVersion')
        .timeout(const Duration(seconds: 2));
    final stamp = version?['firstInstallTime'];
    if (stamp is num &&
        stamp > 0 &&
        stamp <= (now ?? DateTime.now()).millisecondsSinceEpoch) {
      return DateTime.fromMillisecondsSinceEpoch(stamp.toInt());
    }
  } catch (_) {}
  return null;
}
