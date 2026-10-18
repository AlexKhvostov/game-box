import 'package:flutter/material.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';

/// Standalone host reuses the same ranking as the game menu.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      SafeArea(child: const LeaderboardSheet());
}
