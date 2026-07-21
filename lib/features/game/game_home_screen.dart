import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import 'game_play_screen.dart';
import 'widgets/freeze_sheet.dart';

class GameHomeScreen extends StatelessWidget {
  const GameHomeScreen({super.key});

  Future<void> _onPlay(BuildContext context) async {
    final economy = context.read<EconomyStore>();
    if (!economy.canPlay) {
      await showFreezeSheet(context);
      return;
    }
    final started = economy.tryStartGame();
    if (!started || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const GamePlayScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _StatChip(
                  icon: Icons.favorite,
                  label: '${economy.lives}',
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.toll,
                  label: '${economy.tokens}',
                  color: theme.colorScheme.primary,
                ),
                const Spacer(),
                if (economy.bestTimeMs > 0)
                  Text(
                    'Рекорд ${(economy.bestTimeMs / 1000).toStringAsFixed(1)}с',
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              'GAME BOX',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 40,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Уворачивайся от квадратов.\nПродержись дольше всех.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
                height: 1.4,
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => _onPlay(context),
              child: Text(economy.canPlay ? 'Играть' : 'Нет жизней'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
