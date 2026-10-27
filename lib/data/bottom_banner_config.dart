import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'remote_config_bootstrap.dart';
import 'android_firebase_config.dart';

class BottomBannerSettings {
  const BottomBannerSettings({
    this.enabled = false,
    this.adUnitId = '',
    this.installDelaySec = 0,
  });
  final bool enabled;
  final String adUnitId;
  final int installDelaySec;

  // No rewarded/interstitial ID is reused for a banner placement.
  bool get configured => enabled && RegExp(r'^R-M-\d+-\d+$').hasMatch(adUnitId);
}

/// Banner object from the same admin-managed configuration as other formats.
/// Disabled by default. Refresh on startup, resume and once a minute in foreground.
class BottomBannerConfig extends ChangeNotifier {
  BottomBannerConfig({Future<BottomBannerSettings> Function()? fetch})
    : _fetch = fetch ?? _fetchRemote;

  final Future<BottomBannerSettings> Function() _fetch;
  BottomBannerSettings settings = const BottomBannerSettings();
  Future<void>? _pending;
  Timer? _timer;
  bool _disposed = false;

  void start() {
    if (_disposed || _timer != null) return;
    unawaited(refresh());
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(refresh()),
    );
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() =>
      _pending ??= _refresh().whenComplete(() => _pending = null);

  Future<void> _refresh() async {
    try {
      final next = await _fetch().timeout(const Duration(seconds: 12));
      if (_disposed) return;
      if (settings.enabled != next.enabled ||
          settings.adUnitId != next.adUnitId ||
          settings.installDelaySec != next.installDelaySec) {
        settings = next;
        notifyListeners();
      }
    } catch (_) {
      // A network failure preserves the last fetched choice; initial state is off.
    }
  }

  static Future<BottomBannerSettings> _fetchRemote() async {
    await RemoteConfigBootstrap.initialize();
    final rc = FirebaseRemoteConfig.instance;
    // Do not call setDefaults: gameplay's existing RC defaults stay intact.
    await rc.fetchAndActivate();
    final banner = AndroidFirebaseConfig.parse(
      rc.getString(AndroidFirebaseConfig.key),
      'banner-remote-config',
    ).advertising.banner;
    return BottomBannerSettings(
      enabled: banner.enabled,
      adUnitId: banner.unitId,
      installDelaySec: banner.installDelaySec,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    pause();
    super.dispose();
  }
}
