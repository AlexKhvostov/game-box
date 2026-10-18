import '../balance/energy_sheet.dart';
import '../../ui/crystal_cost_badge.dart';
import '../../ui/game_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_analytics.dart';
import '../../data/economy_store.dart';
import '../../domain/economy_config.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/crystal_cube_icon.dart';
import '../../ui/game_sheet.dart';
import '../../ui/game_toast.dart';
import '../../ui/life_balance_card.dart';
import '../../ui/audience_gate.dart';
import '../balance/crystals_sheet.dart';

/// Contrasting exchange cards share the game mascot and currency accents.
const _heartRed = Color(0xFFFF5A5F);
const _lifeMint = Color(0xFF5EE6B0);

Future<void> showLivesSheet(BuildContext context) {
  if (context.read<EconomyStore>().energyEnabled) {
    return showEnergySheet(context);
  }
  return showDialog<void>(
    animationStyle: GameUi.windowAnimationStyle,
    context: context,
    // Android starts the game inside the audience shell's Navigator. Keep
    // this window in the game Navigator, alongside its economy providers.
    useRootNavigator: false,
    useSafeArea: true,
    builder: (_) => Dialog(
      key: const ValueKey('lives-floating-window'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: const _LivesSheet(),
      ),
    ),
  );
}

void _openCrystalsShop(BuildContext context) {
  AppAnalytics.tapCrystals();
  Navigator.pop(context);
  showCrystalsSheet(context, initialTab: 1);
}

class _LivesSheet extends StatefulWidget {
  const _LivesSheet();
  @override
  State<_LivesSheet> createState() => _LivesSheetState();
}

class _LivesSheetState extends State<_LivesSheet> {
  bool _exchanging = false;
  Future<void> _exchange(EconomyStore economy, LifePackOffer pack) async {
    if (_exchanging || !mounted) return;
    _exchanging = true;
    if (!await ensureResourceAge(context) || !mounted) {
      _exchanging = false;
      return;
    }
    if (!economy.buyLifePackOffer(pack)) {
      _openCrystalsShop(context);
      return;
    }
    AppAnalytics.buyLifePack(lives: pack.lives, cost: pack.costTokens);
    final message = AppLocalizations.of(context).livesGained(pack.lives);
    showGameToast(
      context,
      message: message,
      accent: _lifeMint,
      flyTo: ToastFlyTarget.lives,
      icon: const Icon(Icons.favorite, color: _heartRed),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final l10n = AppLocalizations.of(context);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final packs = economy.config.resolvedLifePacks;
    final best = packs.isEmpty
        ? -1
        : List.generate(packs.length, (i) => i).reduce(
            (a, b) =>
                packs[b].lives /
                        (packs[b].costTokens > 0 ? packs[b].costTokens : 1) >
                    packs[a].lives /
                        (packs[a].costTokens > 0 ? packs[a].costTokens : 1)
                ? b
                : a,
          );
    return GameSheetChrome(
      heightFactor: .86,
      fitContent: true,
      modal: true,
      glass: GameGlass.none,
      backgroundGradient: GameUi.navySheetGradient,
      backgroundImage: DecorationImage(
        image: ResizeImage.resizeIfNeeded(
          (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .ceil(),
          null,
          const AssetImage('assets/branding/ui/lives-room-v2.png'),
        ),
        fit: BoxFit.fitWidth,
        alignment: Alignment.topRight,
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 190),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xE6061B2D),
                      Color(0xB3061B2D),
                      Color(0x00061B2D),
                      Color(0x00061B2D),
                    ],
                    stops: [0, .38, .65, 1],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: Text(
                              l10n.livesConvertTitle.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                                color: GameUi.text,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('lives-close'),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 24,
                            color: GameUi.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final side = (constraints.maxWidth * .29).clamp(
                          84.0,
                          112.0,
                        );
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            key: const ValueKey('lives-inventory'),
                            width: side,
                            height: side * 1.15,
                            child: LifeBalanceCard(lives: economy.lives),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              key: const ValueKey('lives-exchange-currency'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF17698D),
                    Color(0xFF0B3959),
                    Color(0xFF082A43),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GameUi.cyan, width: 1.5),
              ),
              child: Row(
                children: [
                  const CrystalCubeIcon(
                    size: 34,
                    glow: true,
                    onLightBackground: false,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ru ? 'Баланс кристаллов' : 'Crystal balance',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: GameUi.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ru
                              ? 'Для обмена на жизни'
                              : 'For exchanging into lives',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            color: Color(0xFFB6DFED),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${economy.tokens}',
                        key: const ValueKey('lives-crystal-balance-amount'),
                        style: const TextStyle(
                          fontSize: 26,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: GameUi.text,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const ValueKey('lives-to-crystals-shop'),
                    onPressed: () => _openCrystalsShop(context),
                    tooltip: ru ? 'В магазин кристаллов' : 'Open crystal shop',
                    icon: const Icon(
                      Icons.storefront_rounded,
                      color: GameUi.cyan,
                      size: 23,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = ((constraints.maxWidth - 8) / 2).clamp(
                  0.0,
                  176.0,
                );
                return Wrap(
                  key: const ValueKey('life-packs-list'),
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < packs.length; i++)
                      SizedBox(
                        width: cardWidth,
                        child: _LifePackCard(
                          pack: packs[i],
                          canBuy: economy.canBuyLifePackOffer(packs[i]),
                          best: i == best,
                          onTap: () => _exchange(economy, packs[i]),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LifePackCard extends StatelessWidget {
  const _LifePackCard({
    required this.pack,
    required this.canBuy,
    required this.best,
    required this.onTap,
  });
  final LifePackOffer pack;
  final bool canBuy, best;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Container(
      key: ValueKey('life-pack-${pack.lives}-${pack.costTokens}'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF174C68), Color(0xFF0A3048)],
        ),
        borderRadius: BorderRadius.circular(GameUi.radius),
        border: Border.all(
          color: !canBuy
              ? const Color(0xFF677887)
              : best
              ? GameUi.yellow
              : const Color(0xFF81CCE2),
          width: best ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (MediaQuery.textScalerOf(context).scale(13) > 18)
            Align(
              alignment: Alignment.topRight,
              child: CrystalCostBadge(
                amount: pack.costTokens,
                available: canBuy,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: GameUi.heart,
                      size: 17,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '+${pack.lives}',
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: GameUi.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (MediaQuery.textScalerOf(context).scale(13) <= 18) ...[
                const SizedBox(width: 4),
                CrystalCostBadge(amount: pack.costTokens, available: canBuy),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            !canBuy
                ? (ru ? 'Не хватает' : 'Not enough')
                : best
                ? AppLocalizations.of(context).badgeBest
                : ' ',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: GameUi.yellow,
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            label: ru
                ? '${pack.costTokens} кристаллов за ${pack.lives} жизней'
                : '${pack.costTokens} crystals for ${pack.lives} lives',
            button: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('life-exchange-${pack.lives}-${pack.costTokens}'),
                borderRadius: BorderRadius.circular(8),
                onTap: onTap,
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: GameUi.touchTarget(context),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: canBuy
                        ? const LinearGradient(
                            colors: [Color(0xFF84E2BD), Color(0xFF43BA98)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF43596B), Color(0xFF2D4253)],
                          ),
                    border: Border.all(
                      color: canBuy ? _lifeMint : const Color(0xFF677887),
                    ),
                  ),
                  child: Text(
                    canBuy
                        ? (ru ? 'Обменять' : 'Exchange')
                        : (ru ? 'В магазин' : 'Shop'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: canBuy ? GameUi.ink : const Color(0xFFBAC7D0),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
