/** Калькулятор монетизации Untouch для админки. Не пишет в Firebase — только считает и собирает JSON для RC. */

const STORE_KEY = 'untouch_admin_monetize_v1';

const PROPOSED = {
  cohort: {
    dau: 100,
    sessionsPerDay: 2,
    runsPerSession: 6,
    dailyClaimRate: 0.55,
    giftClaimsPerDay: 1.4,
    rewardedAdsPerDay: 2,
    interstitialPerDay: 3,
    plusShare: 0.03,
    packBuyerShare: 0.04,
    packPurchasesPerWeek: 1,
    usdPerStar: 0.02,
    rewardedEcpm: 8,
    interstitialEcpm: 4,
    feePct: 0,
    avgRisksPerRun: 4,
    avgStepsPerRun: 180,
  },
  start: {
    initialLives: 8,
    initialTokens: 15,
    installBonus: 15,
  },
  lives: [
    { lives: 8, costTokens: 10 },
    { lives: 25, costTokens: 28 },
    { lives: 80, costTokens: 80 },
    { lives: 250, costTokens: 220 },
  ],
  daily: [3, 4, 5, 6, 8, 10, 12],
  gift: { tokens: 6, hours: 6 },
  ad: { reward: 3, cooldownSec: 180 },
  play: {
    riskEvery: 8,
    riskTokens: 1,
    runEvery: 400,
    runTokens: 1,
  },
  earn: {
    survive: 4,
    record: 8,
    risks: 4,
    notify: 5,
    invite: 15,
  },
  rent: {
    jump10: 12,
    jump60: 36,
    helmet10: 20,
    helmet60: 60,
  },
  packs: [
    { id: 'pack_s', title: 'Горсть', crystals: 30, stars: 39, badge: '' },
    { id: 'pack_m', title: 'Стопка', crystals: 80, stars: 89, badge: 'deal' },
    { id: 'pack_l', title: 'Сундук', crystals: 200, stars: 199, badge: 'best' },
    { id: 'pack_xl', title: 'Сейф', crystals: 500, stars: 449, badge: 'max' },
  ],
  plus: { id: 'plus_weekly', stars: 49, days: 7, dailyMult: 2 },
  interstitial: { graceSec: 210, cooldownSec: 180, minLives: 3 },
};

function clone(v) {
  return JSON.parse(JSON.stringify(v));
}

function n(v, fallback = 0) {
  const x = Number(v);
  return Number.isFinite(x) ? x : fallback;
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (!raw) return clone(PROPOSED);
    const parsed = JSON.parse(raw);
    return {
      ...clone(PROPOSED),
      ...parsed,
      cohort: { ...PROPOSED.cohort, ...(parsed.cohort || {}) },
      start: { ...PROPOSED.start, ...(parsed.start || {}) },
      gift: { ...PROPOSED.gift, ...(parsed.gift || {}) },
      ad: { ...PROPOSED.ad, ...(parsed.ad || {}) },
      play: { ...PROPOSED.play, ...(parsed.play || {}) },
      earn: { ...PROPOSED.earn, ...(parsed.earn || {}) },
      rent: { ...PROPOSED.rent, ...(parsed.rent || {}) },
      plus: { ...PROPOSED.plus, ...(parsed.plus || {}) },
      interstitial: { ...PROPOSED.interstitial, ...(parsed.interstitial || {}) },
      lives: Array.isArray(parsed.lives) && parsed.lives.length ? parsed.lives : clone(PROPOSED.lives),
      daily: Array.isArray(parsed.daily) && parsed.daily.length ? parsed.daily : clone(PROPOSED.daily),
      packs: Array.isArray(parsed.packs) && parsed.packs.length ? parsed.packs : clone(PROPOSED.packs),
    };
  } catch (_) {
    return clone(PROPOSED);
  }
}

function saveState(state) {
  try { localStorage.setItem(STORE_KEY, JSON.stringify(state)); } catch (_) {}
}

function money(v) {
  return new Intl.NumberFormat('ru-RU', { style: 'currency', currency: 'USD', maximumFractionDigits: 2 }).format(v || 0);
}

function qty(v, digits = 1) {
  return new Intl.NumberFormat('ru-RU', { maximumFractionDigits: digits }).format(v || 0);
}

function packUnit(p) {
  const cost = n(p && p.costTokens);
  const amt = n(p && p.lives);
  if (amt <= 0 || cost <= 0) return null;
  return { ...p, unit: cost / amt };
}

function cheapestLife(lives) {
  let best = null;
  for (const p of lives) {
    const row = packUnit(p);
    if (!row) continue;
    if (!best || row.unit < best.unit) best = row;
  }
  return best || { lives: 8, costTokens: 10, unit: 1.25 };
}

function calc(state) {
  const c = state.cohort;
  const dailySum = state.daily.reduce((s, v) => s + n(v), 0);
  const dailyDay1 = n(state.daily[0]);
  const giftCap = n(state.gift.hours) > 0 ? 24 / n(state.gift.hours) : 0;
  const giftDay = Math.min(n(c.giftClaimsPerDay), giftCap) * n(state.gift.tokens);
  const adDay = n(c.rewardedAdsPerDay) * n(state.ad.reward);
  const runsDay = n(c.sessionsPerDay) * n(c.runsPerSession);
  const runCr = n(state.play.runEvery) > 0
    ? (n(c.avgStepsPerRun) / n(state.play.runEvery)) * n(state.play.runTokens)
    : 0;
  const riskCr = n(state.play.riskEvery) > 0
    ? (n(c.avgRisksPerRun) / n(state.play.riskEvery)) * n(state.play.riskTokens)
    : 0;
  const playCrDay = runsDay * (runCr + riskCr);
  const claim = Math.max(0, Math.min(1, n(c.dailyClaimRate)));
  const grindDay = dailyDay1 * claim + giftDay + adDay;
  const f2pDay = grindDay + playCrDay;
  const f2pWeek = dailySum * claim + 7 * (giftDay + adDay + playCrDay);
  const plusExtraWeek = dailySum * claim * Math.max(0, n(state.plus.dailyMult) - 1);
  const bulk = cheapestLife(state.lives);
  const small = packUnit(state.lives[0]) || bulk;
  const crPerLife = small.unit;
  // День 1 без круга «сначала 12 забегов дохода»: старт + Daily + один подарок + один ролик.
  const day1Bank = n(state.start.initialTokens) + dailyDay1 * claim
    + Math.min(n(state.gift.tokens), giftDay)
    + Math.min(n(state.ad.reward), adDay);
  const day1Runs = n(state.start.initialLives) + Math.floor(day1Bank / Math.max(0.01, crPerLife));
  const weekRunsF2P = Math.floor(f2pWeek / Math.max(0.01, crPerLife));
  const needDay = runsDay * crPerLife;
  const grindCover = needDay > 0 ? grindDay / needDay : 0;
  const pack0 = state.packs[0] || { crystals: 30, stars: 39 };
  const crPerStar = n(pack0.stars) > 0 ? n(pack0.crystals) / n(pack0.stars) : 0.7;
  const plusCrValue = plusExtraWeek;
  const plusStarValue = n(state.plus.stars);
  const plusVsPack = crPerStar > 0 ? plusCrValue / (plusStarValue * crPerStar) : 0;
  const fee = Math.max(0, Math.min(0.9, n(c.feePct) / 100));
  const starUsd = n(c.usdPerStar) * (1 - fee);
  const dau = Math.max(0, n(c.dau));
  const plusRevDay = dau * n(c.plusShare) * (plusStarValue * starUsd) / Math.max(1, n(state.plus.days));
  const avgPackStars = state.packs.reduce((s, p) => s + n(p.stars), 0) / Math.max(1, state.packs.length);
  const packRevDay = dau * n(c.packBuyerShare) * (n(c.packPurchasesPerWeek) / 7) * avgPackStars * starUsd;
  const rewRevDay = dau * n(c.rewardedAdsPerDay) * n(c.rewardedEcpm) / 1000;
  const intUsers = dau * (1 - n(c.plusShare));
  const intRevDay = intUsers * n(c.interstitialPerDay) * n(c.interstitialEcpm) / 1000;
  const revDay = plusRevDay + packRevDay + rewRevDay + intRevDay;
  const arpdau = dau > 0 ? revDay / dau : 0;
  const notes = [];
  if (giftDay > 24) notes.push('Подарок слишком жирный: F2P не дойдёт до кассы.');
  if (dailySum > 80) notes.push('Daily за неделю слишком большой — падает спрос на пакеты.');
  if (day1Runs > 32) notes.push('День 1 слишком длинный без покупок.');
  if (day1Runs < 10) notes.push('День 1 короткий: новичок не зацепится.');
  if (grindCover > 1.5) notes.push('Daily+подарок+ролик покрывают попытки с запасом — жизни за Stars почти не нужны.');
  if (grindCover > 0 && grindCover < 0.4) notes.push('Без покупки обычный день слишком короткий: новичок упрётся в стену.');
  if (n(pack0.stars) > 60) notes.push('Первый пакет дороже импульса (лучше < 50 ⭐).');
  if (plusVsPack > 1.4) notes.push('Plus слишком выгоден против пакетов — касса уйдёт в подписку и дешёвые кристаллы.');
  if (plusVsPack < 0.45) notes.push('Plus слабый: мало ценности кроме комфорта без interstitial.');
  if (n(state.plus.days) !== 7 && n(state.plus.days) !== 30) {
    notes.push('Telegram автосписывает Stars только раз в 30 дней. 7 дней = разовая покупка с продлением.');
  }
  if (n(state.ad.cooldownSec) < 60) notes.push('Кулдаун ролика короче минуты — легко фармить кристаллы.');
  let tone = 'ok';
  let title = 'Баланс рабочий';
  if (notes.some((t) => t.includes('жирный') || t.includes('длинный') || t.includes('Daily') || t.includes('покрывают'))) {
    tone = 'warn';
    title = 'Слишком щедро';
  }
  if (notes.some((t) => t.includes('короткий') || t.includes('дороже импульса') || t.includes('слабый'))) {
    tone = tone === 'warn' ? 'warn' : 'bad';
    title = tone === 'warn' ? 'Смешанный сигнал' : 'Слишком жёстко';
  }
  if (!notes.length) {
    tone = 'ok';
    title = 'Сбалансировано';
  }
  return {
    dailySum,
    giftDay,
    adDay,
    playCrDay,
    grindDay,
    grindCover,
    needDay,
    f2pDay,
    f2pWeek,
    plusExtraWeek,
    crPerLife,
    day1Runs,
    weekRunsF2P,
    plusVsPack,
    plusRevDay,
    packRevDay,
    rewRevDay,
    intRevDay,
    revDay,
    arpdau,
    arpuMonth: arpdau * 30,
    adsShare: revDay > 0 ? (rewRevDay + intRevDay) / revDay : 0,
    notes,
    tone,
    title,
    life: small,
    bulk,
    pack0,
  };
}

function economyJson(state) {
  const watch = state.earn;
  return {
    initialLives: n(state.start.initialLives),
    initialTokens: n(state.start.initialTokens),
    installBonusAutoClaim: true,
    lifePacks: state.lives.map((p) => ({
      lives: n(p.lives),
      costTokens: n(p.costTokens),
    })),
    starsShop: {
      packs: state.packs.map((p) => {
        const row = {
          id: String(p.id || '').trim(),
          title: String(p.title || '').trim(),
          crystals: n(p.crystals),
          stars: n(p.stars),
        };
        if (p.badge) row.badge = p.badge;
        return row;
      }),
      plus: {
        id: String(state.plus.id || 'plus_weekly'),
        title: 'Plus',
        stars: n(state.plus.stars),
        days: n(state.plus.days, 7),
      },
    },
    dailyRewardTokens: state.daily.map((v) => n(v)),
    jumpRentalCost: n(state.rent.jump10),
    jumpRentalMinutes: 10,
    jumpRentalHourCost: n(state.rent.jump60),
    jumpRentalHourMinutes: 60,
    helmetRentalCost: n(state.rent.helmet10),
    helmetRentalMinutes: 10,
    helmetRentalHourCost: n(state.rent.helmet60),
    helmetRentalHourMinutes: 60,
    riskRewardEvery: n(state.play.riskEvery),
    riskRewardTokens: n(state.play.riskTokens),
    runRewardEvery: n(state.play.runEvery),
    runRewardTokens: n(state.play.runTokens),
    timedBonusTokens: n(state.gift.tokens),
    timedBonusHours: n(state.gift.hours),
    watchAdCooldownSec: n(state.ad.cooldownSec),
    adsgramBlockId: '46825',
    adsgramInterstitialBlockId: 'int-46979',
    interstitialGraceSec: n(state.interstitial.graceSec),
    interstitialCooldownSec: n(state.interstitial.cooldownSec),
    interstitialMinLives: n(state.interstitial.minLives),
    premiumDailyMultiplier: n(state.plus.dailyMult, 2),
    avatarCheatEnabled: false,
    avatarCheatTokens: 10,
    earnSurviveSeconds: 10,
    earnRecordSeconds: 20,
    earnRisksInRun: 5,
    earnActions: [
      { id: 'install_bonus', reward: n(state.start.installBonus) },
      { id: 'survive_10s', reward: n(watch.survive) },
      { id: 'record_20s', reward: n(watch.record) },
      { id: 'risks_5', reward: n(watch.risks) },
      { id: 'watch_ad', reward: n(state.ad.reward) },
      { id: 'enable_notifications', reward: n(watch.notify) },
      { id: 'invite_friend', reward: n(watch.invite) },
    ],
  };
}

function kv(obj, keys) {
  return keys.map((k) => `${k}: ${JSON.stringify(obj[k])}`).join('\n');
}

function formatRcBlocks(state) {
  const eco = economyJson(state);
  const plus = eco.starsShop.plus;
  const packs = eco.starsShop.packs.map((p) => {
    const badge = p.badge ? `, badge: ${JSON.stringify(p.badge)}` : '';
    return `  ${p.id}: ${p.crystals} крист. / ${p.stars} ⭐ (${p.title}${badge})`;
  }).join('\n');
  const lives = eco.lifePacks.map((p, i) => `  pack${i + 1}: ${p.lives} жизней = ${p.costTokens} крист.`).join('\n');
  const earn = eco.earnActions.map((a) => `  ${a.id}: ${a.reward}`).join('\n');
  const human = [
    '=== RC: economy / старт ===',
    kv(eco, ['initialLives', 'initialTokens', 'installBonusAutoClaim']),
    '',
    '=== RC: economy / жизни за кристаллы ===',
    lives,
    '',
    '=== RC: economy / Daily ===',
    `dailyRewardTokens: ${JSON.stringify(eco.dailyRewardTokens)}`,
    `premiumDailyMultiplier: ${eco.premiumDailyMultiplier}`,
    '',
    '=== RC: economy / подарок и ролик ===',
    kv(eco, ['timedBonusTokens', 'timedBonusHours', 'watchAdCooldownSec']),
    '',
    '=== RC: economy / награда за игру ===',
    kv(eco, ['riskRewardEvery', 'riskRewardTokens', 'runRewardEvery', 'runRewardTokens']),
    '',
    '=== RC: economy / аренда ===',
    kv(eco, [
      'jumpRentalCost', 'jumpRentalMinutes', 'jumpRentalHourCost', 'jumpRentalHourMinutes',
      'helmetRentalCost', 'helmetRentalMinutes', 'helmetRentalHourCost', 'helmetRentalHourMinutes',
    ]),
    '',
    '=== RC: economy / пакеты Stars ===',
    packs,
    '',
    '=== RC: economy / Plus ===',
    `id: ${JSON.stringify(plus.id)}`,
    `stars: ${plus.stars}`,
    `days: ${plus.days}`,
    '',
    '=== RC: economy / interstitial ===',
    kv(eco, [
      'adsgramBlockId', 'adsgramInterstitialBlockId',
      'interstitialGraceSec', 'interstitialCooldownSec', 'interstitialMinLives',
    ]),
    '',
    '=== RC: economy / earn ===',
    kv(eco, ['earnSurviveSeconds', 'earnRecordSeconds', 'earnRisksInRun']),
    earn,
    '',
    '=== RC: economy / JSON целиком (этот блок копирует кнопка) ===',
    JSON.stringify(eco, null, 2),
    '',
    '=== не RC: модель аудитории ===',
    JSON.stringify(state.cohort, null, 2),
  ].join('\n');
  return { text: human, json: JSON.stringify(eco, null, 2) };
}

function field(label, key, step = '1') {
  return `<label class="m-field">${label}<input type="number" step="${step}" data-k="${key}"></label>`;
}

function mount(root) {
  if (!root) return;
  if (root.dataset.ready === '1') {
    refresh(root);
    return;
  }
  root.dataset.ready = '1';
  root.innerHTML = `
    <section class="panel">
      <h2>Зачем так</h2>
      <p>Старые числа (подарок 22 кристалла каждый час, Daily до 81) слишком сытые: F2P не доходит до кассы. Предложенный баланс: день 1 чтобы зацепиться, дальше кристаллы заканчиваются. Plus — неделя за Stars. Telegram не умеет автосписание раз в неделю, поэтому это повторная покупка на 7 дней.</p>
      <p class="lead">Форма считает модель. В Firebase сама ничего не пишет. Скопируйте JSON в параметр <code>economy</code> и Publish.</p>
      <div class="m-actions">
        <button type="button" class="ghost" data-act="reset">Сбросить к предложенным</button>
        <button type="button" data-act="copy">Копировать JSON economy</button>
      </div>
    </section>
    <section class="panel">
      <h2>Модель аудитории (не RC)</h2>
      <div class="m-grid">
        ${field('DAU', 'cohort.dau')}
        ${field('Сессий / день', 'cohort.sessionsPerDay', '0.1')}
        ${field('Попыток / сессия', 'cohort.runsPerSession', '0.1')}
        ${field('Доля Daily', 'cohort.dailyClaimRate', '0.01')}
        ${field('Подарков / день', 'cohort.giftClaimsPerDay', '0.1')}
        ${field('Роликов / день', 'cohort.rewardedAdsPerDay', '0.1')}
        ${field('Interstitial / день', 'cohort.interstitialPerDay', '0.1')}
        ${field('Доля Plus', 'cohort.plusShare', '0.001')}
        ${field('Доля покупателей пакетов', 'cohort.packBuyerShare', '0.001')}
        ${field('Покупок пакета / нед.', 'cohort.packPurchasesPerWeek', '0.1')}
        ${field('USD за 1 ⭐', 'cohort.usdPerStar', '0.001')}
        ${field('eCPM ролик, $', 'cohort.rewardedEcpm', '0.1')}
        ${field('eCPM interstitial, $', 'cohort.interstitialEcpm', '0.1')}
        ${field('Комиссия, %', 'cohort.feePct', '1')}
        ${field('Рисков / попытка', 'cohort.avgRisksPerRun', '0.1')}
        ${field('Шагов / попытка', 'cohort.avgStepsPerRun')}
      </div>
    </section>
    <section class="panel">
      <h2>Старт</h2>
      <div class="m-grid">
        ${field('Жизни', 'start.initialLives')}
        ${field('Кристаллы (initialTokens)', 'start.initialTokens')}
        ${field('install_bonus', 'start.installBonus')}
      </div>
    </section>
    <section class="panel">
      <h2>Пакеты жизней</h2>
      <div class="m-grid m-grid-4" data-lives></div>
    </section>
    <section class="panel">
      <h2>Бесплатные кристаллы</h2>
      <h3>Daily, 7 дней</h3>
      <div class="m-grid m-grid-7" data-daily></div>
      <div class="m-grid">
        ${field('Подарок, крист.', 'gift.tokens')}
        ${field('Подарок, часы', 'gift.hours', '0.5')}
        ${field('Ролик, крист.', 'ad.reward')}
        ${field('Ролик, кулдаун сек', 'ad.cooldownSec')}
        ${field('Риск каждые', 'play.riskEvery')}
        ${field('Риск, крист.', 'play.riskTokens')}
        ${field('Шаги каждые', 'play.runEvery')}
        ${field('Шаги, крист.', 'play.runTokens')}
        ${field('Survive', 'earn.survive')}
        ${field('Рекорд', 'earn.record')}
        ${field('5 рисков', 'earn.risks')}
        ${field('Уведомления', 'earn.notify')}
        ${field('Инвайт', 'earn.invite')}
      </div>
    </section>
    <section class="panel">
      <h2>Аренда</h2>
      <div class="m-grid">
        ${field('Прыжок 10 мин', 'rent.jump10')}
        ${field('Прыжок 60 мин', 'rent.jump60')}
        ${field('Шлем 10 мин', 'rent.helmet10')}
        ${field('Шлем 60 мин', 'rent.helmet60')}
      </div>
    </section>
    <section class="panel">
      <h2>Stars</h2>
      <div class="m-packs" data-packs></div>
      <div class="m-grid">
        <label class="m-field">Plus id<input type="text" data-k="plus.id"></label>
        ${field('Plus, ⭐', 'plus.stars')}
        ${field('Plus, дни', 'plus.days')}
        ${field('Plus × Daily', 'plus.dailyMult', '0.1')}
      </div>
    </section>
    <section class="panel">
      <h2>Interstitial</h2>
      <div class="m-grid">
        ${field('Фриз после Daily, сек', 'interstitial.graceSec')}
        ${field('Кулдаун, сек', 'interstitial.cooldownSec')}
        ${field('Мин. жизней', 'interstitial.minLives')}
      </div>
    </section>
    <section class="panel">
      <h2>Расчёт успеха</h2>
      <p id="m-verdict" class="m-verdict"></p>
      <div id="m-kpis" class="cards m-kpis"></div>
      <ul id="m-notes" class="m-notes"></ul>
    </section>
    <section class="panel">
      <h2>Блоки Remote Config</h2>
      <p class="lead">Монетизация живёт в одном параметре <code>economy</code>. Ниже — тот же JSON, разложенный по смысловым блокам, затем цельный JSON для Publish. <code>enemies</code> / <code>player</code> / <code>field</code> / <code>game</code> / <code>audio</code> калькулятор не трогает.</p>
      <textarea id="m-rc" class="m-rc" spellcheck="false" readonly></textarea>
    </section>
  `;

  fillDynamic(root);
  bind(root);
  refresh(root);
}

function fillDynamic(root) {
  const lives = root.querySelector('[data-lives]');
  lives.innerHTML = [0, 1, 2, 3].map((i) => `
    <label class="m-field">Пак ${i + 1}: жизни<input type="number" data-k="lives.${i}.lives"></label>
    <label class="m-field">Пак ${i + 1}: цена<input type="number" data-k="lives.${i}.costTokens"></label>
  `).join('');
  const daily = root.querySelector('[data-daily]');
  daily.innerHTML = [1, 2, 3, 4, 5, 6, 7].map((d, i) =>
    `<label class="m-field">День ${d}<input type="number" data-k="daily.${i}"></label>`
  ).join('');
  const packs = root.querySelector('[data-packs]');
  packs.innerHTML = [0, 1, 2, 3].map((i) => `
    <div class="m-pack">
      <label class="m-field">id<input type="text" data-k="packs.${i}.id"></label>
      <label class="m-field">имя<input type="text" data-k="packs.${i}.title"></label>
      <label class="m-field">крист.<input type="number" data-k="packs.${i}.crystals"></label>
      <label class="m-field">⭐<input type="number" data-k="packs.${i}.stars"></label>
      <label class="m-field">badge<input type="text" data-k="packs.${i}.badge"></label>
    </div>
  `).join('');
}

function getByPath(obj, path) {
  return path.split('.').reduce((acc, key) => (acc == null ? acc : acc[key]), obj);
}

function setByPath(obj, path, value, asText = false) {
  const keys = path.split('.');
  let cur = obj;
  for (let i = 0; i < keys.length - 1; i += 1) {
    const k = keys[i];
    const next = keys[i + 1];
    if (cur[k] == null) cur[k] = /^\d+$/.test(next) ? [] : {};
    cur = cur[k];
  }
  const last = keys[keys.length - 1];
  cur[last] = asText ? String(value ?? '') : n(value, 0);
}

function readForm(root) {
  const state = loadState();
  root.querySelectorAll('[data-k]').forEach((el) => {
    const key = el.getAttribute('data-k');
    setByPath(state, key, el.value, el.type === 'text');
  });
  return state;
}

function writeForm(root, state) {
  root.querySelectorAll('[data-k]').forEach((el) => {
    const val = getByPath(state, el.getAttribute('data-k'));
    el.value = val == null ? '' : val;
  });
}

function bind(root) {
  root.addEventListener('input', () => {
    const state = readForm(root);
    saveState(state);
    paint(root, state);
  });
  root.querySelector('[data-act="reset"]')?.addEventListener('click', () => {
    const state = clone(PROPOSED);
    saveState(state);
    writeForm(root, state);
    paint(root, state);
  });
  root.querySelector('[data-act="copy"]')?.addEventListener('click', async () => {
    const json = formatRcBlocks(readForm(root)).json;
    try {
      await navigator.clipboard.writeText(json);
    } catch (_) {
      const area = root.querySelector('#m-rc');
      if (area) {
        area.value = json;
        area.select();
      }
    }
  });
}

function paint(root, state) {
  const r = calc(state);
  const verdict = root.querySelector('#m-verdict');
  verdict.className = `m-verdict ${r.tone}`;
  verdict.textContent = r.title;
  root.querySelector('#m-kpis').innerHTML = [
    ['Попыток в день 1', qty(r.day1Runs, 0), 'cyan'],
    ['Покрытие дня (Daily+подарок+ролик)', `${qty(r.grindCover * 100, 0)}%`, ''],
    ['Кристаллов F2P / день', qty(r.f2pDay), ''],
    ['Кристаллов F2P / нед.', qty(r.f2pWeek), ''],
    ['Попыток F2P / нед. с паков жизней', qty(r.weekRunsF2P, 0), ''],
    ['Plus даёт крист. / нед.', qty(r.plusExtraWeek), 'accent'],
    ['Plus vs пакет', `${qty(r.plusVsPack * 100, 0)}%`, ''],
    ['ARPDAU', money(r.arpdau), 'warn'],
    ['ARPU 30 дн.', money(r.arpuMonth), 'warn'],
    ['Касса / день', money(r.revDay), 'accent'],
    ['Доля рекламы', `${qty(r.adsShare * 100, 0)}%`, ''],
    ['Plus / день', money(r.plusRevDay), ''],
    ['Пакеты / день', money(r.packRevDay), ''],
    ['Ролики / день', money(r.rewRevDay), ''],
    ['Interstitial / день', money(r.intRevDay), ''],
    ['Цена 1 жизни (малый пак)', `${qty(r.crPerLife, 2)} крист.`, ''],
    ['Цена 1 жизни (опт)', `${qty(r.bulk.unit, 2)} крист.`, ''],
  ].map(([label, value, tone]) => `
    <article class="card ${tone}">
      <p class="label">${label}</p>
      <p class="value">${value}</p>
    </article>
  `).join('');
  const notes = root.querySelector('#m-notes');
  notes.innerHTML = r.notes.length
    ? r.notes.map((t) => `<li>${t}</li>`).join('')
    : '<li>День 1 хватает, чтобы понять игру. Дальше F2P живёт с Daily + подарком + роликом. Plus — комфорт и ×2 Daily, не бесконечные жизни.</li>';
  root.querySelector('#m-rc').value = formatRcBlocks(state).text;
}

function refresh(root) {
  const state = loadState();
  writeForm(root, state);
  paint(root, state);
}

window.UntouchMonetize = { mount, calc, economyJson, formatRcBlocks, PROPOSED };
