import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_analytics.dart';
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

Future<void> showLivesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LivesSheet(),
  );
}

void _openCrystalsShop(BuildContext context) {
  AppAnalytics.tapCrystals();
  Navigator.pop(context);
  showCrystalsSheet(context, initialTab: 1);
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
      heightFactor: 0.56,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.livesConvertTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.livesConvertSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 12),
            // Баланс — статус. Кристалы тапабельны → Shop.
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onLongPress: () => _confirmResetData(context),
                    child: _BalanceStatCard(
                      icon: const Icon(
                        Icons.favorite_rounded,
                        color: _heartRed,
                        size: 22,
                      ),
                      value: '${economy.lives}',
                      label: l10n.statLives,
                      accent: _heartRed,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BalanceStatCard(
                    icon: const CrystalCubeIcon(size: 22, glow: false),
                    value: '${economy.tokens}',
                    label: l10n.crystals,
                    accent: _lifeCyan,
                    tappable: true,
                    onTap: () => _openCrystalsShop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: packs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final pack = packs[i];
                  final canBuy = economy.canBuyLifePackOffer(pack);
                  final best = i == packs.length - 1;
                  return _LifePackTile(
                    pack: pack,
                    canBuy: canBuy,
                    bestValue: best,
                    onBuy: () {
                      if (!economy.buyLifePackOffer(pack)) {
                        _openCrystalsShop(context);
                        return;
                      }
                      AppAnalytics.buyLifePack(
                        lives: pack.lives,
                        cost: pack.costTokens,
                      );
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
                    onNeedCrystals: () => _openCrystalsShop(context),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _openCrystalsShop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: 0.75,
                    child: const CrystalCubeIcon(size: 16, glow: false),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.toCrystals,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceStatCard extends StatelessWidget {
  const _BalanceStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.onTap,
    this.tappable = false,
  });

  final Widget icon;
  final String value;
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF151C22),
        border: Border.all(
          color: accent.withValues(alpha: tappable ? 0.5 : 0.35),
          width: tappable ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          icon,
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1,
              color: accent,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              if (tappable) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: accent.withValues(alpha: 0.85),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
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
    required this.onNeedCrystals,
  });

  final LifePackOffer pack;
  final bool canBuy;
  final bool bestValue;
  final VoidCallback onBuy;
  final VoidCallback onNeedCrystals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = bestValue ? _lifeMint : _lifeCyan;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: canBuy ? onBuy : onNeedCrystals,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: bestValue
                  ? [
                      _lifeMint.withValues(alpha: 0.38),
                      const Color(0xFF1A2E28),
                      const Color(0xFF121A1E),
                    ]
                  : [
                      _lifeCyan.withValues(alpha: 0.28),
                      const Color(0xFF1A2830),
                      const Color(0xFF12181E),
                    ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: bestValue ? 0.75 : 0.55),
              width: bestValue ? 1.6 : 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: bestValue ? 0.22 : 0.14),
                blurRadius: bestValue ? 14 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _heartRed.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: _heartRed.withValues(alpha: 0.45),
                  ),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: _heartRed,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.livesPackLabel(pack.lives),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Color(0xFFF2F7FA),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (bestValue) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          color: _lifeMint.withValues(alpha: 0.28),
                          border: Border.all(
                            color: _lifeMint.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Text(
                          l10n.badgeBest,
                          style: const TextStyle(
                            color: _lifeMint,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: canBuy
                      ? LinearGradient(
                          colors: bestValue
                              ? const [_lifeMint, Color(0xFF7EE0FF)]
                              : const [_lifeCyan, _lifeMint],
                        )
                      : null,
                  color: canBuy ? null : const Color(0xFF243038),
                  border: canBuy
                      ? null
                      : Border.all(
                          color: _lifeCyan.withValues(alpha: 0.4),
                        ),
                  boxShadow: canBuy
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CrystalCubeIcon(size: 15, glow: false),
                    const SizedBox(width: 5),
                    Text(
                      '${pack.costTokens}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: canBuy
                            ? const Color(0xFF0E1419)
                            : _lifeCyan.withValues(alpha: 0.95),
                      ),
                    ),
                    if (!canBuy) ...[
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: _lifeCyan.withValues(alpha: 0.9),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
