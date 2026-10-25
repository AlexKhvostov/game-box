import '../ui/analytics_navigation.dart';
import '../data/appmetrica_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../l10n/locale_resolver.dart';
import '../ui/game_sfx.dart';
import '../ui/game_viewport.dart';
import 'shell_screen.dart';
import '../features/balance/crystals_sheet.dart';
import '../features/game/lives_sheet.dart';
import '../features/profile/profile_screen.dart';
import 'theme.dart';
import 'google_startup.dart';

class GameBoxApp extends StatefulWidget {
  const GameBoxApp({super.key, this.forceLocale = '', this.initialWindow});
  final String? initialWindow;

  /// Из Firebase Remote Config: `en` | `ru` | пусто.
  final String forceLocale;

  @override
  State<GameBoxApp> createState() => _GameBoxAppState();
}

class _GameBoxAppState extends State<GameBoxApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  final _analytics = AnalyticsNavigatorObserver();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final windowContext = _navigator.currentContext;
      if (windowContext == null) return;
      switch (widget.initialWindow) {
        case 'profile':
          showProfileSheet(windowContext);
        case 'lives':
          showLivesSheet(windowContext);
        case 'daily':
          showCrystalsSheet(windowContext, initialTab: 0);
        case 'shop':
          showCrystalsSheet(windowContext, initialTab: 1);
        case 'rent':
          showCrystalsSheet(windowContext, initialTab: 2);
        case 'earn':
          showCrystalsSheet(windowContext, initialTab: 3);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _analytics.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        GameSfx.onAppResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        GameSfx.onAppPaused();
        AppMetricaAnalytics.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final forced = LocaleResolver.parseForce(widget.forceLocale);

    return MaterialApp(
      navigatorKey: _navigator,
      navigatorObservers: [_analytics],
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildGameTheme(),
      builder: (context, child) => GameViewport(child: child!),
      locale: forced,
      supportedLocales: LocaleResolver.supported,
      localeResolutionCallback: (device, supported) {
        return LocaleResolver.resolve(
          device: device,
          forceLocale: widget.forceLocale,
        );
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: GoogleStartupGate(
        enabled: widget.initialWindow == null,
        child: const ShellScreen(),
      ),
    );
  }
}
