/// Конфиг экономики. Позже значения придут из Remote Config.
class EconomyConfig {
  const EconomyConfig({
    this.initialLives = 10,
    this.lifePackSize = 10,
    this.lifePackCostTokens = 5,
    this.dailyRewardTokens = const [2, 3, 4, 5, 6, 7, 10],
    this.timedBonusTokens = 3,
    this.timedBonusHours = 8,
  });

  final int initialLives;
  final int lifePackSize;
  final int lifePackCostTokens;
  final List<int> dailyRewardTokens;
  final int timedBonusTokens;
  final int timedBonusHours;

  int dailyTokensForStreak(int streak) {
    if (dailyRewardTokens.isEmpty) return 2;
    final index = streak.clamp(0, dailyRewardTokens.length - 1);
    return dailyRewardTokens[index];
  }
}
