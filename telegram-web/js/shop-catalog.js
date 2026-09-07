/** Каталог магазина Telegram Stars. Числа — из economy.starsShop (RC). */

export const PACK_BADGES = {
  deal: 'Выгодно',
  best: 'Лучшая цена',
  max: 'Максимум',
};

export const DEFAULT_STARS_SHOP = {
  packs: [
    { id: 'pack_s', title: 'Горсть', crystals: 40, stars: 49 },
    { id: 'pack_m', title: 'Стопка', crystals: 120, stars: 149, badge: 'deal' },
    { id: 'pack_l', title: 'Сундук', crystals: 350, stars: 349, badge: 'best' },
    { id: 'pack_xl', title: 'Сейф', crystals: 900, stars: 749, badge: 'max' },
  ],
  plus: {
    id: 'plus_monthly',
    title: 'Plus',
    stars: 199,
    days: 30,
  },
};

export function starsLabel(n) {
  return `${n} ⭐`;
}

function asInt(v, fallback = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? Math.round(n) : fallback;
}

function normalizePack(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const id = String(raw.id || '').trim();
  const crystals = asInt(raw.crystals, 0);
  const stars = asInt(raw.stars, 0);
  if (!id || crystals <= 0 || stars <= 0) return null;
  const title = String(raw.title || id).trim() || id;
  const badge = String(raw.badge || raw.badgeKey || '').trim();
  return { id, title, crystals, stars, badgeKey: badge || undefined };
}

function normalizePlus(raw) {
  const src = raw && typeof raw === 'object' ? raw : DEFAULT_STARS_SHOP.plus;
  const id = String(src.id || DEFAULT_STARS_SHOP.plus.id).trim() || DEFAULT_STARS_SHOP.plus.id;
  const stars = asInt(src.stars, DEFAULT_STARS_SHOP.plus.stars);
  const days = Math.max(1, asInt(src.days, DEFAULT_STARS_SHOP.plus.days));
  const title = String(src.title || 'Plus').trim() || 'Plus';
  if (stars <= 0) {
    return { ...DEFAULT_STARS_SHOP.plus };
  }
  return { id, title, stars, days };
}

export function starsShopFromEconomy(economy) {
  const shop = economy && typeof economy === 'object' ? economy.starsShop : null;
  const packsRaw = shop && Array.isArray(shop.packs) ? shop.packs : DEFAULT_STARS_SHOP.packs;
  const packs = packsRaw.map(normalizePack).filter(Boolean);
  return {
    packs: packs.length ? packs : DEFAULT_STARS_SHOP.packs.map(normalizePack).filter(Boolean),
    plus: normalizePlus(shop && shop.plus),
  };
}

export function subscribePriceLabel(plus) {
  const p = plus || DEFAULT_STARS_SHOP.plus;
  const days = Math.max(1, asInt(p.days, 30));
  return `${starsLabel(p.stars)} / ${days} дн.`;
}
