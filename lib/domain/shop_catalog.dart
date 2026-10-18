/// Состав товаров. Денежные цены всегда загружаются из Google Play.
/// title/badge — ключи для l10n (см. L10nCatalog).
class ShopOffer {
  const ShopOffer({
    required this.id,
    required this.crystals,
    required this.priceLabel,
    required this.usdCents,
    this.badgeKey,
  });

  final String id;
  final int crystals;
  final String priceLabel;
  final int usdCents;
  final String? badgeKey;
}

class ShopCatalog {
  static const packs = <ShopOffer>[
    ShopOffer(id: 'pack_s', crystals: 20, priceLabel: r'$0.99', usdCents: 99),
    ShopOffer(
      id: 'pack_m',
      crystals: 50,
      priceLabel: r'$1.99',
      usdCents: 199,
      badgeKey: 'deal',
    ),
    ShopOffer(
      id: 'pack_l',
      crystals: 200,
      priceLabel: r'$3.99',
      usdCents: 399,
      badgeKey: 'best',
    ),
    ShopOffer(
      id: 'pack_xl',
      crystals: 1000,
      priceLabel: r'$9.99',
      usdCents: 999,
      badgeKey: 'max',
    ),
  ];

  static const subscribePrice = '—';
}
