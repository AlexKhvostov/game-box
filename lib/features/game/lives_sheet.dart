import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../data/scores_store.dart';
import '../../domain/economy_config.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/crystal_cube_icon.dart';
import '../../ui/game_sheet.dart';
import '../../ui/game_toast.dart';
import '../balance/crystals_sheet.dart';

/// Дружелюбные акценты окна жизней. Красный — только у иконки сердца.
const _heartRed = Color(0xFFFF5A5F);
const _lifeMint = Color(0xFF5EE6B0);
const _lifeCyan = Color(0xFF7EE0FF);
const _lifeSoftBg = Color(0xFF1A242C);

Future<void> showLivesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LivesSheet(),
  );
}

Future<void> _confirmResetData(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF151C22),
      title: Text(l10n.resetDataTitle),
      content: Text(l10n.resetDataBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  final economy = context.read<EconomyStore>();
  final scores = context.read<ScoresStore>();
  final messengerContext = context;
  await economy.resetToFreshInstall();
  await scores.clearLocalData();
  if (!messengerContext.mounted) return;
  Navigator.pop(messengerContext);
  showGameToast(
    messengerContext,
    message: l10n.resetDataDone,
    accent: const Color(0xFF7EE0FF),
  );
}

class _LivesSheet extends StatelessWidget {
  const _LivesSheet();

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final packs = economy.config.resolvedLifePacks;

    return GameSheetChrome(
      heightFactor: 0.62,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.livesConvertTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.livesConvertSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onLongPress: () => _confirmResetData(context),
              child: GamePanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                accent: _lifeCyan,
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: _heartRed,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.livesBalance(economy.lives),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    const CrystalCubeIcon(size: 18, glow: false),
                    const SizedBox(width: 6),
                    Text(
                      '${economy.tokens}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _lifeCyan,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: packs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final pack = packs[i];
                  final canBuy = economy.canBuyLifePackOffer(pack);
                  final best = i == packs.length - 1;
                  return _LifePackTile(
                    pack: pack,
                    canBuy: canBuy,
                    bestValue: best,
                    onBuy: () {
                      if (!economy.buyLifePackOffer(pack)) return;
                      Navigator.pop(context);
                      showGameToast(
                        context,
                        message: l10n.livesGained(pack.lives),
                        accent: _lifeMint,
                        flyTo: ToastFlyTarget.lives,
                        icon: const Icon(
                          Icons.favorite_rounded,
                          color: _heartRed,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showCrystalsSheet(context);
              },
              child: Text(l10n.toCrystals),
            ),
          ],
        ),
      ),
    );
  }
}

class _LifePackTile extends StatelessWidget {
  const _LifePackTile({
    required this.pack,
    required this.canBuy,
    required this.bestValue,
    required this.onBuy,
  });

  final LifePackOffer pack;
  final bool canBuy;
  final bool bestValue;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canBuy ? onBuy : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: bestValue
                  ? [
                      _lifeMint.withValues(alpha: 0.2),
                      _lifeSoftBg,
                    ]
                  : [
                      _lifeCyan.withValues(alpha: 0.08),
                      const Color(0xFF151C22),
                    ],
            ),
            border: Border.all(
              color: bestValue
                  ? _lifeMint.withValues(alpha: 0.55)
                  : _lifeCyan.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: _lifeCyan.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: _heartRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.livesPackLabel(pack.lives),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (bestValue)
                      Text(
                        l10n.badgeBest,
                        style: const TextStyle(
                          color: _lifeMint,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Opacity(
                opacity: canBuy ? 1 : 0.45,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: canBuy
                        ? const LinearGradient(
                            colors: [_lifeCyan, _lifeMint],
                          )
                        : null,
                    color: canBuy ? null : Colors.white12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CrystalCubeIcon(size: 16, glow: false),
                      const SizedBox(width: 5),
                      Text(
                        '${pack.costTokens}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: canBuy
                              ? const Color(0xFF0E1419)
                              : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
