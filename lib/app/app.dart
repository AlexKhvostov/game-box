import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../l10n/locale_resolver.dart';
import 'shell_screen.dart';
import 'theme.dart';

class GameBoxApp extends StatelessWidget {
  const GameBoxApp({
    super.key,
    this.forceLocale = '',
  });

  /// Из Firebase Remote Config: `en` | `ru` | пусто.
  final String forceLocale;

  @override
  Widget build(BuildContext context) {
    final forced = LocaleResolver.parseForce(forceLocale);

    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildGameTheme(),
      locale: forced,
      supportedLocales: LocaleResolver.supported,
      localeResolutionCallback: (device, supported) {
        return LocaleResolver.resolve(
          device: device,
          forceLocale: forceLocale,
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
