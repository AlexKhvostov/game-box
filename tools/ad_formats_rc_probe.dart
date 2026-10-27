import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:game_box/data/bottom_banner_config.dart';
import 'package:game_box/data/remote_config_bootstrap.dart';
import 'package:game_box/domain/ad_formats_config.dart';

/// Only imported by the isolated QA entry point, never by the main app.
class ProbeAdFormatsRemote {
  ProbeAdFormatsRemote({required this.apply, Future<String> Function()? fetch})
    : _fetch = fetch ?? _fetchFirebase;

  static const key = 'android_ad_formats_qa_v1';
  static const initial = AdFormatsConfig(
    automatic: AutomaticFormatConfig(enabled: false),
  );
  final void Function(AdFormatsConfig) apply;
  final Future<String> Function() _fetch;
  DateTime? receivedAt;
  int refreshes = 0;
  String? lastError;

  Future<BottomBannerSettings> fetchBanner() async {
    try {
      final raw = jsonDecode(await _fetch());
      // An incomplete QA value must not inherit automatic.enabled=true.
      if (raw is! Map ||
          raw['banner'] is! Map ||
          raw['automatic'] is! Map ||
          raw['banner']['enabled'] is! bool ||
          raw['automatic']['enabled'] is! bool) {
        throw const FormatException('QA RC needs explicit format switches');
      }
      final next = AdFormatsConfig.fromJson(raw);
      apply(next);
      receivedAt = DateTime.now();
      refreshes++;
      lastError = null;
      return BottomBannerSettings(
        enabled: next.banner.enabled,
        installDelaySec: next.banner.installDelaySec,
        adUnitId: next.banner.unitId,
      );
    } catch (error) {
      lastError = error.runtimeType.toString();
      rethrow;
    }
  }

  static Future<String> _fetchFirebase() async {
    await RemoteConfigBootstrap.initialize();
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 6),
        minimumFetchInterval: Duration.zero,
      ),
    );
    await rc.fetchAndActivate();
    final value = rc.getValue(key);
    if (value.source != ValueSource.valueRemote) {
      throw const FormatException('QA Remote Config not published');
    }
    return value.asString();
  }
}
