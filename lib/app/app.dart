import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../l10n/locale_resolver.dart';
import '../ui/game_sfx.dart';
import 'shell_screen.dart';
import 'theme.dart';

class GameBoxApp extends StatefulWidget {
  const GameBoxApp({
    super.key,
    this.forceLocale = '',
  });

  /// Из Firebase Remote Config: `en` | `ru` | пусто.
  final String forceLocale;

  @override
  State<GameBoxApp> createState() => _GameBoxAppState();
}

class _GameBoxAppState extends State<GameBoxApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final forced = LocaleResolver.parseForce(widget.forceLocale);

    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildGameTheme(),
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
      home: const ShellScreen(),
    );
  }
}
