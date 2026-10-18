// Rebuild the reviewable parameter inventory from the shipped defaults.
import fs from 'node:fs';
const c=JSON.parse(fs.readFileSync('assets/config/android-firebase.json','utf8')).config;
const rows=[];
function describe(key) {
  if(key.startsWith('theme.')) return ['Сохранённая схема источника; Android использует согласованный GameUi','Не активный Android RC; художественные tokens фиксированы'];
  if(key === 'game.speedRampSeconds') return ['MobileGameplayTuning','Android фиксирует0: равномерный разгон v0+a*t'];
  if(/^enemies\.(speed|accel)/.test(key)) return ['Совместимость GameplayConfig; Android считает из mobileEnemies','0…4000; Android использует mobileEnemies'];
  if(key.startsWith('mobileEnemies.')) return ['MobileEnemyPace → MobileGameplayTuning','скорость0.01…250; ускорение0…50; variation0…0.5'];
  if(key.startsWith('economy.androidEnergyV2.packages') || key.startsWith('economy.androidEnergyV2.subscriptions')) return ['AndroidEnergyConfig/PlayBillingService + server product()','Список активных SKU; содержимоеSKU неизменяемо; цены только Play'];
  if(key.includes('simpleBonus')) return ['SimpleEnergyBonus + server walletOperation/publicProfile','целые0…100000; period1…2592000с; cooldown0…86400с; серверная версия'];
  if(key.startsWith('economy.androidEnergyV2')) return ['AndroidEnergyConfig/EconomyStore + server engine','attempt1…1000; extras0…1000; reward0…100000; сервер проверяет'];
  if(/economy\.(initialLives|initialTokens|installBonusAutoClaim)/.test(key)) return ['Защитный fallback до профиля','0/0/false: локальные старые валюты не начисляются'];
  if(key.startsWith('economy.interstitial')) return ['EconomyStore/AdsService','целые≥0; сборочные/возрастные ограничения сохраняются'];
  if(key.startsWith('economy.')) return ['ArcadeRules/EconomyStore + server round snapshot','целые1…1000000; замораживаются на старте раунда'];
  if(key.startsWith('audio.')) return ['AudioConfig → PlayerPreferences → GameSfx','boolean; громкости0…1; локальное выключение имеет приоритет'];
  if(key.startsWith('player.')) return ['PlayerConfig → GameWorld/GameFieldPainter','size4…200; boolean showFace'];
  if(key.startsWith('field.')) return ['FieldConfig → GameFieldPainter/GameWorld','border0…24; brightness0…2; side100…2000; corner0…200; hexcolor'];
  if(key.startsWith('game.')) return ['GameConfig → GameHomeScreen/GameWorld/ArcadeHud','boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum'];
  if(key.startsWith('enemies.')) return ['EnemiesConfig → GameWorld','count1…32; aspects>0…100; area0.1…20; angle0…180'];
  if(key === 'forceLocale') return ['GameBoxApp/LocaleResolver','пусто, en, ru'];
  return ['Проверить потребителя при добавлении','Не заявлен активным без проверки'];
}
function walk(v,key='') {
  if(v && typeof v==='object') {
    for(const [k,x]of Object.entries(v)) walk(x,key?`${key}.${k}`:k);
  } else {const [consumer,rule]=describe(key);rows.push(`| \`${key}\` | ${typeof v} | \`${JSON.stringify(v)}\` | ${consumer} | ${rule} |`);}
}
walk(c);
const pre=`# Реестр Android Remote Config\n\nСгенерировано из текущего Android snapshot; ${rows.length} листовых значений. Команда: \`node tools/document_android_firebase_config.mjs\`.\n\nЕдинственный публикуемый ключ — \`android_config_v1\`, JSON. Типы/критические диапазоны проверяет сервер; клиент проверяет hash/структуру/пределы и использует отдельный cache/default. Изменения применяются при новом запуске; активный раунд/покупка/бонус сохраняет выданные условия. Запрещены условия аудитории для экономики.\n\n| Путь внутри config | Тип | Default | Потребитель | Диапазон/правило |\n|---|---|---|---|---|\n`;
const post=`\n## Обоснованные исключения\n\n- Графика, шрифты, геометрия согласованного UI141, pixel offsets и theme/GameUi — код/ресурсы приложения. Произвольная RC-перекомпоновка не поддерживается и нарушила бы сохранение интерфейса. Параметры поля/яркости/помощи/звука уже подключены отдельно.\n- Неизменяемые SKU и их содержимое находятся в server product registry; новый объём требует нового SKU. RC выбирает доступные SKU и благоприятную политику8ч; цена/валюта/скидка рассчитываются по ответам Billing.\n- Firebase project/appId, endpoint, база, OAuth clientId, signing cert, security rules, nonce format, idempotency и серверные сроки — технический контракт. Секреты/ключи платежей не публикуются в RC.\n- TEST_TOOLS, DEMO/LIVE_ADS, Play Billing, production guard и согласие/возраст остаются сборочными или локальными ограничениями. RC не включает их за пользователя.\n- Постоянный жест5тапов/≤1.5с/+20 — прямое продуктовое правило Алексея. Его сумма фиксирована доверенным сервером, не поступает из client payload.\n- Размер аудиопула, throttling звуков, сеть/timeouts/backoff и алгоритмы столкновений — технические ограничения. Их безопасное изменение требует выпуска кода и профильной проверки.\n- Telegram daily/lives/crystals/rentals/Stars и прежние avatar-cheats отсутствуют в новом Android snapshot. Telegram остаётся на своём сервере.\n`;
fs.writeFileSync('docs/ANDROID_FIREBASE_REMOTE_CONFIG.md',pre+rows.join('\n')+'\n'+post);
console.log(`${rows.length} parameters documented`);
