// Actual game/SDK, isolated wallet and package. No live player API or payments.
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:game_box/data/app_analytics.dart';
import 'package:game_box/data/appmetrica_analytics.dart';
import 'android_brake_probe.dart' as brake;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('ANDROID_BRAKE_PROBE')) {
    throw StateError('isolated_probe_only');
  }
  // Legacy telemetry fixture explicitly represents an adult who opted in.
  // Product initialization stays off. Use the consent probe for age/choice QA.
  await AppMetricaAnalytics.setConsent(true);
  final send = AppAnalytics.sink;
  if (send == null) throw StateError('analytics_probe_not_configured');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  AppAnalytics.sink = (name, params) async {
    // Local evidence observes exactly the event given to the real native SDK.
    // This receiver is accessible only via adb reverse on the QA package.
    try {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:8883/events'),
      );
      request.headers.contentType = ContentType.json;
      final body = utf8.encode(jsonEncode({'name': name, 'params': params}));
      request.contentLength = body.length;
      request.add(body);
      await (await request.close()).drain<void>();
    } catch (_) {}
    await send(name, params);
  };
  Timer.periodic(
    const Duration(seconds: 10),
    (_) => AppMetricaAnalytics.flush(),
  );
  await brake.main();
}
