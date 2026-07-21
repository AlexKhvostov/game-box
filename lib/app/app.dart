import 'package:flutter/material.dart';

import 'shell_screen.dart';
import 'theme.dart';

class GameBoxApp extends StatelessWidget {
  const GameBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Box',
      debugShowCheckedModeBanner: false,
      theme: buildGameTheme(),
      home: const ShellScreen(),
    );
  }
}
