/// Каталог магазина (IAP подключим позже — пока UI + локальный preview).
/// title/badge — ключи для l10n (см. L10nCatalog).
class ShopOffer {
  const ShopOffer({
    required this.id,
    required this.crystals,
    required this.priceLabel,
    this.badgeKey,
  });

  final String id;
  final int crystals;
  final String priceLabel;
  final String? badgeKey;
}

class ShopCatalog {
  static const packs = <ShopOffer>[
    ShopOffer(
      id: 'pack_s',
      crystals: 40,
      priceLabel: '\$0.99',
    ),
    ShopOffer(
      id: 'pack_m',
      crystals: 120,
      priceLabel: '\$2.99',
      badgeKey: 'deal',
    ),
    ShopOffer(
      id: 'pack_l',
      crystals: 350,
      priceLabel: '\$6.99',
      badgeKey: 'best',
    ),
    ShopOffer(
      id: 'pack_xl',
      crystals: 900,
      priceLabel: '\$14.99',
      badgeKey: 'max',
    ),
  ];

  static const subscribePrice = '\$1.00 / week';
}
