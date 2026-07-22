import 'package:flutter/material.dart';

import '../features/game/game_home_screen.dart';

/// Корень приложения без нижнего меню (гиперказуальный цикл).
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GameHomeScreen();
  }
}
