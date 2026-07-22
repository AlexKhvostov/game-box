import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/economy_store.dart';

Future<void> showFreezeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return Consumer<EconomyStore>(
        builder: (context, economy, _) {
          final cfg = economy.config;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Нет жизней',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Купите пак из ${cfg.lifePackSize} жизней за ${cfg.lifePackCostTokens} кристалов '
                  'или обменяйте прямо на экране Игра.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text('У вас кристалов: ${economy.tokens}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: economy.canBuyLifePack
                      ? () {
                          economy.buyLifePack();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '+${cfg.lifePackSize} жизней',
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Text(
                    'Разморозить (−${cfg.lifePackCostTokens} кристалов)',
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
