/** lib/domain/shop_catalog.dart + lib/l10n/l10n_catalog.dart */
export const SHOP_PACKS = [
  { id: 'pack_s', crystals: 40, priceLabel: '$0.99' },
  { id: 'pack_m', crystals: 120, priceLabel: '$2.99', badgeKey: 'deal' },
  { id: 'pack_l', crystals: 350, priceLabel: '$6.99', badgeKey: 'best' },
  { id: 'pack_xl', crystals: 900, priceLabel: '$14.99', badgeKey: 'max' },
];

export const PACK_TITLES = {
  pack_s: 'Горсть',
  pack_m: 'Стопка',
  pack_l: 'Сундук',
  pack_xl: 'Сейф',
};

export const PACK_BADGES = {
  deal: 'Выгодно',
  best: 'Лучшая цена',
  max: 'Максимум',
};

export const SUBSCRIBE_PRICE = '$1.00 / week';
