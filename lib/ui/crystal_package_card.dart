import 'package:flutter/material.dart';
import '../domain/shop_catalog.dart';
import 'crystal_cube_icon.dart';
import 'game_ui.dart';

class CrystalPackageCard extends StatelessWidget {
  const CrystalPackageCard({
    super.key,
    required this.offer,
    required this.tier,
    required this.title,
    required this.price,
    required this.caption,
    required this.onTap,
    this.compact = false,
  });
  final ShopOffer offer;
  final int tier;
  final String title, price, caption;
  final VoidCallback onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    const accents = [
      GameUi.cyan,
      Color(0xFF69CFFF),
      GameUi.mint,
      Color(0xFFFFD778),
    ];
    final accent = accents[tier.clamp(0, 3)];
    final base = ShopCatalog.packs.first;
    final saving =
        (100 *
                (1 -
                    offer.usdCents *
                        base.crystals /
                        (offer.crystals * base.usdCents)))
            .round();
    final badge = tier == 3
        ? 'MAX'
        : saving > 0 && price == offer.priceLabel
        ? '−$saving%'
        : null;
    return Semantics(
      button: true,
      label: '$title, ${offer.crystals}, $price, $caption',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: compact ? 7 : 8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: .16),
                  const Color(0xFF0A2B43),
                  const Color(0xFF071F34),
                ],
              ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: accent.withValues(alpha: tier == 3 ? .9 : .6),
                width: tier == 3 ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: compact ? 14 : 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: GameUi.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (badge != null)
                        FittedBox(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: accent,
                                fontFamily: 'Roboto',
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 3 : 4),
                SizedBox(
                  height: compact ? 36 : 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${offer.crystals}',
                                  key: ValueKey(
                                    'crystal-pack-amount-${offer.id}',
                                  ),
                                  style: const TextStyle(
                                    color: GameUi.text,
                                    fontFamily: 'Roboto',
                                    fontSize: 32,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                ru ? 'кристаллов' : 'crystals',
                                style: const TextStyle(
                                  color: GameUi.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: compact ? 40 : 46,
                        child: FittedBox(
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: _CrystalPile(tier: tier),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 4 : 6),
                Container(
                  height: compact ? 28 : 30,
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, const Color(0xFF5ADFCB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      price,
                      key: ValueKey('crystal-pack-price-${offer.id}'),
                      style: const TextStyle(
                        color: GameUi.background,
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 3 : 4),
                SizedBox(
                  height: compact ? 10 : 12,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: GameUi.muted,
                        fontFamily: 'Roboto',
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CrystalPile extends StatelessWidget {
  const _CrystalPile({required this.tier});
  final int tier;
  @override
  Widget build(BuildContext context) {
    if (tier == 0) {
      return const Center(
        child: CrystalCubeIcon(size: 54, onLightBackground: false),
      );
    }
    final count = [1, 3, 6, 10][tier.clamp(0, 3)];
    final size = tier == 1
        ? 33.0
        : tier == 2
        ? 27.0
        : 23.0;
    final positions = <Offset>[];
    for (var row = 0; positions.length < count; row++) {
      for (var col = 0; col <= row && positions.length < count; col++) {
        positions.add(
          Offset(
            30 - size / 2 + (col - row / 2) * size * .66,
            row * size * .48,
          ),
        );
      }
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final offset in positions)
          Positioned(
            left: offset.dx,
            top: offset.dy,
            child: CrystalCubeIcon(
              size: size,
              glow: false,
              onLightBackground: false,
            ),
          ),
      ],
    );
  }
}
