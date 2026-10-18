import 'package:flutter/material.dart';
import '../../ui/game_ui.dart';

/// Standalone ranking has its own tone; the result's embedded ranking keeps
/// the palette of the result window.
class LeaderboardTone extends InheritedWidget {
  const LeaderboardTone({super.key, required super.child});
  static bool dark(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LeaderboardTone>() != null;
  static Color text(BuildContext context) =>
      dark(context) ? GameUi.text : GameUi.ink;
  static Color muted(BuildContext context) =>
      dark(context) ? GameUi.muted : GameUi.inkMuted;
  @override
  bool updateShouldNotify(LeaderboardTone oldWidget) => false;
}
