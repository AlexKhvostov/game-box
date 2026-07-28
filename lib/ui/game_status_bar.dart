import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../ui/crystal_cube_icon.dart';

/// Шапка: жизни, кристалы, рекорд.
class GameStatusBar extends StatelessWidget {
  const GameStatusBar({
    super.key,
    this.trailing,
  });

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final theme = Theme.of(context);

    return Row(
      children: [
        _Chip(
          icon: Icon(Icons.favorite, size: 18, color: theme.colorScheme.error),
          label: '${economy.lives}',
          border: theme.colorScheme.error.withValues(alpha: 0.35),
        ),
        const SizedBox(width: 8),
        _Chip(
          icon: const CrystalCubeIcon(size: 18, glow: false),
          label: '${economy.tokens}',
          border: const Color(0xFF7EE0FF).withValues(alpha: 0.35),
        ),
        const Spacer(),
        _Chip(
          icon: Icon(
            Icons.star_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          label: economy.bestTimeMs > 0
              ? '${(economy.bestTimeMs / 1000).toStringAsFixed(2)}с'
              : '0',
          border: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          trailing!,
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.border,
  });

  final Widget icon;
  final String label;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
