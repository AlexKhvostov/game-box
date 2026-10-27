import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import '../app/app_target.dart';
import '../data/ads_service.dart';
import '../data/audience_policy.dart';
import '../data/bottom_banner_config.dart';
import '../data/yandex_ads_driver.dart';
import '../data/economy_store.dart';

/// Adapter also lets layout/privacy/races be tested without a native ad SDK.
abstract class BottomBannerSession extends ChangeNotifier {
  bool get loaded;
  bool get failed;
  Widget get view;
  Future<void> load(String unit);
  Future<void> close();
}

class _YandexBannerSession extends BottomBannerSession {
  _YandexBannerSession(int width)
    : _ad = BannerAd(adSize: BannerAdSize.inline(width: width, maxHeight: 50)) {
    _subscription = _ad.loadStateStream.listen((state) {
      loaded = state is BannerAdLoadStateLoaded;
      failed = state is BannerAdLoadStateError;
      notifyListeners();
    });
  }
  final BannerAd _ad;
  late final StreamSubscription<BannerAdLoadState> _subscription;
  @override
  bool loaded = false;
  @override
  bool failed = false;
  @override
  Widget get view => AdWidget(bannerAd: _ad);
  @override
  Future<void> load(String unit) => _ad.load(AdRequest(adUnitId: unit));
  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _ad.destroy();
    dispose();
  }
}

/// Separate from the game's Listener: a banner tap never starts/jumps a round.
class AndroidBottomBanner extends StatefulWidget {
  const AndroidBottomBanner({
    super.key,
    required this.active,
    this.createSession,
    this.initialize,
  });
  final bool active;
  @visibleForTesting
  final BottomBannerSession Function(int width)? createSession;
  @visibleForTesting
  final Future<void> Function()? initialize;

  @override
  State<AndroidBottomBanner> createState() => _AndroidBottomBannerState();
}

class _AndroidBottomBannerState extends State<AndroidBottomBanner>
    with WidgetsBindingObserver {
  BottomBannerSession? _session;
  String? _requestKey;
  int _generation = 0;
  bool _foreground = true;
  Timer? _retry;
  Timer? _eligibilityTimer;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final foreground = state == AppLifecycleState.resumed;
    final config = context.read<BottomBannerConfig?>();
    if (foreground) {
      config?.start();
    } else {
      config?.pause();
      _eligibilityTimer?.cancel();
      _eligibilityTimer = null;
      // A paused app may stop producing frames. Dispose now, rather than
      // waiting for build() to remove the native view after returning.
      _reconcile(null, 0, '', null);
    }
    setState(() => _foreground = foreground);
  }

  Future<void> _close(BottomBannerSession? session) async {
    if (session == null) return;
    session.removeListener(_changed);
    try {
      await session.close();
    } catch (_) {
      // Cleanup failure must never break the game.
    }
  }

  void _changed() {
    if (!mounted) return;
    if (_session?.failed == true) {
      // No immediate retry loop on no-fill/offline. A single retry per minute.
      _retry ??= Timer(const Duration(minutes: 1), () {
        _retry = null;
        if (mounted) setState(() => _requestKey = null);
      });
    }
    setState(() {});
  }

  void _reconcile(String? key, int width, String unit, AdsService? ads) {
    if (_requestKey == key) return;
    _requestKey = key;
    final generation = ++_generation;
    _retry?.cancel();
    _retry = null;
    final previous = _session;
    _session = null;
    unawaited(_replace(previous, key, generation, width, unit, ads));
  }

  Future<void> _replace(
    BottomBannerSession? previous,
    String? key,
    int generation,
    int width,
    String unit,
    AdsService? ads,
  ) async {
    await _close(previous);
    if (key == null) return;
    try {
      final initialize = widget.initialize;
      if (initialize != null) {
        await initialize();
      } else {
        final driver = ads?.driver;
        if (driver is! YandexAdsDriver) return;
        await driver.initializeForBanner().timeout(const Duration(seconds: 20));
      }
      if (!mounted || generation != _generation) return;
      final session = (widget.createSession ?? _YandexBannerSession.new)(width);
      _session = session;
      session.addListener(_changed);
      // Mount the SDK platform view even while loading (SDK starts at 1dp).
      // Zero-size Offstage would prevent the native view/request from starting.
      await session.load(unit);
      if (!mounted || generation != _generation) return;
      setState(() {});
    } catch (_) {
      if (!mounted || generation != _generation) return;
      final failed = _session;
      _session = null;
      unawaited(_close(failed));
      _retry ??= Timer(const Duration(minutes: 1), () {
        _retry = null;
        if (mounted) setState(() => _requestKey = null);
      });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<BottomBannerConfig?>();
    final audience = context.watch<AudiencePolicy?>();
    final ads = context.watch<AdsService?>();
    final settings = config?.settings;
    final economy = context.watch<EconomyStore?>();
    final delay = settings?.installDelaySec ?? 0;
    final remaining = delay == 0
        ? Duration.zero
        : economy?.bannerDelayLeft(delay);
    _eligibilityTimer?.cancel();
    _eligibilityTimer = null;
    if (_foreground &&
        widget.active &&
        settings?.enabled == true &&
        remaining != null &&
        remaining > Duration.zero) {
      _eligibilityTimer = Timer(remaining, () {
        _eligibilityTimer = null;
        if (mounted) setState(() {});
      });
    }
    final supported =
        !kIsWeb &&
        AppTargetConfig.isMobile &&
        defaultTargetPlatform == TargetPlatform.android;
    final allowed =
        supported &&
        widget.active &&
        _foreground &&
        audience?.adsEnabled == true &&
        remaining == Duration.zero &&
        ads?.busy != true &&
        settings?.enabled == true &&
        (AudiencePolicy.demoAds || settings?.configured == true);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.floor();
        final unit = AudiencePolicy.demoAds
            ? 'demo-banner-yandex'
            : settings?.adUnitId ?? '';
        final key = allowed && width >= 300
            ? '$width:$unit:${audience!.adConsentRevision}'
            : null;
        _reconcile(key, width, unit, ads);
        final session = _session;
        if (key == null || session == null || session.failed) {
          return const SizedBox.shrink();
        }
        return Padding(
          key: const ValueKey('android-bottom-banner'),
          padding: EdgeInsets.only(top: session.loaded ? 8 : 0),
          child: Center(heightFactor: 1, child: session.view),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    _retry?.cancel();
    _eligibilityTimer?.cancel();
    unawaited(_close(_session));
    super.dispose();
  }
}
