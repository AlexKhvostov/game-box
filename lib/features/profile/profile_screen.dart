import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final theme = Theme.of(context);
    final timedLeft = economy.timedBonusRemaining;

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
          _InfoCard(
            children: [
              _InfoRow(label: 'Жизни', value: '${economy.lives}'),
              _InfoRow(label: 'Жетоны', value: '${economy.tokens}'),
              _InfoRow(
                label: 'Рекорд',
                value: economy.bestTimeMs > 0
                    ? '${(economy.bestTimeMs / 1000).toStringAsFixed(1)} с'
                    : '—',
              ),
              _InfoRow(label: 'Daily streak', value: '${economy.dailyStreak}'),
            ],
          ),
          const SizedBox(height: 20),
          Text('Награды', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: economy.canClaimDaily
                ? () {
                    final amount = economy.claimDaily();
                    if (amount != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Daily: +$amount жетонов')),
                      );
                    }
                  }
                : null,
            child: Text(
              economy.canClaimDaily
                  ? 'Daily Reward (+${economy.upcomingDailyTokens})'
                  : 'Daily уже получен сегодня',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: economy.canClaimTimedBonus
                ? () {
                    final amount = economy.claimTimedBonus();
                    if (amount != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('+$amount жетонов')),
                      );
                    }
                  }
                : null,
            child: Text(
              economy.canClaimTimedBonus
                  ? 'Получить жетоны (+${economy.config.timedBonusTokens})'
                  : 'Доступно через ${_formatDuration(timedLeft ?? Duration.zero)}',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: economy.canBuyLifePack
                ? () {
                    economy.buyLifePack();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '+${economy.config.lifePackSize} жизней',
                        ),
                      ),
                    );
                  }
                : null,
            child: Text(
              'Пак жизней (−${economy.config.lifePackCostTokens} жетонов)',
            ),
          ),
          const SizedBox(height: 24),
          Text('Магазин', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Покупка жетонов за деньги появится после подключения Google Play Billing.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: null,
            child: const Text('Купить жетоны — скоро'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
