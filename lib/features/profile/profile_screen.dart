import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../ui/crystal_cube_icon.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          Text('Профиль', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            economy.displayName ?? 'Имя ещё не задано',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _InfoRow(label: 'Жизни', value: '${economy.lives}'),
                _InfoRow(
                  label: 'Crystals',
                  value: '${economy.tokens}',
                  trailing: const CrystalCubeIcon(size: 18, glow: false),
                ),
                _InfoRow(
                  label: 'Рекорд',
                  value: economy.bestTimeMs > 0
                      ? '${(economy.bestTimeMs / 1000).toStringAsFixed(2)} с'
                      : '—',
                ),
                _InfoRow(
                  label: 'Серия Daily',
                  value: '${economy.dailyStreak} дн.',
                ),
                _InfoRow(
                  label: 'Boost',
                  value: economy.hasPremium ? 'активен' : 'нет',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Награды, буст и магазин — во вкладке «Баланс».',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 6),
          ],
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
