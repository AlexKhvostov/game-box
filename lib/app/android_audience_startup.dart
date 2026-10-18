import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../ui/audience_gate.dart';
import 'theme.dart';

/// Start one game session for everyone. Age settings never recreate it.
class AndroidAudienceStartup extends StatelessWidget {
  const AndroidAudienceStartup({super.key, required this.startGame});
  final Future<Widget> Function() startGame;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildGameTheme(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: AudienceGate(child: _StartGame(startGame: startGame)),
  );
}

class _StartGame extends StatefulWidget {
  const _StartGame({required this.startGame});
  final Future<Widget> Function() startGame;

  @override
  State<_StartGame> createState() => _StartGameState();
}

class _StartGameState extends State<_StartGame> {
  late final Future<Widget> _game;

  @override
  void initState() {
    super.initState();
    _game = widget.startGame();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _game,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.data!;
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      return Scaffold(
        body: Center(
          child: snapshot.hasError
              ? Text(
                  ru
                      ? 'Не удалось запустить игру. Перезапустите приложение.'
                      : 'Could not start the game. Please restart the app.',
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}
