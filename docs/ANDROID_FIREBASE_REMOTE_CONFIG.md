# Реестр Android Remote Config

Сгенерировано из текущего Android snapshot; 121 листовых значений. Команда: `node tools/document_android_firebase_config.mjs`.

Единственный публикуемый ключ — `android_config_v1`, JSON. Типы/критические диапазоны проверяет сервер; клиент проверяет hash/структуру/пределы и использует отдельный cache/default. Изменения применяются при новом запуске; активный раунд/покупка/бонус сохраняет выданные условия. Запрещены условия аудитории для экономики.

| Путь внутри config | Тип | Default | Потребитель | Диапазон/правило |
|---|---|---|---|---|
| `theme.bg` | string | `"#0E1419"` | Сохранённая схема источника; Android использует согласованный GameUi | Не активный Android RC; художественные tokens фиксированы |
| `theme.surface` | string | `"#172028"` | Сохранённая схема источника; Android использует согласованный GameUi | Не активный Android RC; художественные tokens фиксированы |
| `theme.primary` | string | `"#3DDC97"` | Сохранённая схема источника; Android использует согласованный GameUi | Не активный Android RC; художественные tokens фиксированы |
| `theme.danger` | string | `"#ff0008"` | Сохранённая схема источника; Android использует согласованный GameUi | Не активный Android RC; художественные tokens фиксированы |
| `theme.text` | string | `"#E8EEF4"` | Сохранённая схема источника; Android использует согласованный GameUi | Не активный Android RC; художественные tokens фиксированы |
| `theme.muted` | string | `"#8B9AAB"` | Сохранённая схема источника; Android использует согласованный GameUi | Не активный Android RC; художественные tokens фиксированы |
| `theme.cyan` | string | `"#7EE0FF"` | Сохранённая схема источника; Android использует согласованный GameUi | Не активный Android RC; художественные tokens фиксированы |
| `enemies.areaMultiplier` | number | `2` | EnemiesConfig → GameWorld | count1…32; aspects>0…100; area0.1…20; angle0…180 |
| `enemies.aspects.0` | number | `1` | EnemiesConfig → GameWorld | count1…32; aspects>0…100; area0.1…20; angle0…180 |
| `enemies.aspects.1` | number | `0.25` | EnemiesConfig → GameWorld | count1…32; aspects>0…100; area0.1…20; angle0…180 |
| `enemies.aspects.2` | number | `0.5` | EnemiesConfig → GameWorld | count1…32; aspects>0…100; area0.1…20; angle0…180 |
| `enemies.aspects.3` | number | `3` | EnemiesConfig → GameWorld | count1…32; aspects>0…100; area0.1…20; angle0…180 |
| `enemies.angleMinDeg` | number | `30` | EnemiesConfig → GameWorld | count1…32; aspects>0…100; area0.1…20; angle0…180 |
| `enemies.angleMaxDeg` | number | `60` | EnemiesConfig → GameWorld | count1…32; aspects>0…100; area0.1…20; angle0…180 |
| `enemies.speedMin` | number | `75` | Совместимость GameplayConfig; Android считает из mobileEnemies | 0…4000; Android использует mobileEnemies |
| `enemies.speedMax` | number | `105` | Совместимость GameplayConfig; Android считает из mobileEnemies | 0…4000; Android использует mobileEnemies |
| `enemies.accelMin` | number | `9` | Совместимость GameplayConfig; Android считает из mobileEnemies | 0…4000; Android использует mobileEnemies |
| `enemies.accelMax` | number | `15` | Совместимость GameplayConfig; Android считает из mobileEnemies | 0…4000; Android использует mobileEnemies |
| `enemies.collideWithEachOther` | boolean | `false` | EnemiesConfig → GameWorld | count1…32; aspects>0…100; area0.1…20; angle0…180 |
| `enemies.spinDegPerSec` | number | `0` | EnemiesConfig → GameWorld | count1…32; aspects>0…100; area0.1…20; angle0…180 |
| `player.size` | number | `36` | PlayerConfig → GameWorld/GameFieldPainter | size4…200; boolean showFace |
| `player.showFace` | boolean | `true` | PlayerConfig → GameWorld/GameFieldPainter | size4…200; boolean showFace |
| `field.borderWidth` | number | `3` | FieldConfig → GameFieldPainter/GameWorld | border0…24; brightness0…2; side100…2000; corner0…200; hexcolor |
| `field.brightness` | number | `1` | FieldConfig → GameFieldPainter/GameWorld | border0…24; brightness0…2; side100…2000; corner0…200; hexcolor |
| `field.shadowBrightness` | number | `1` | FieldConfig → GameFieldPainter/GameWorld | border0…24; brightness0…2; side100…2000; corner0…200; hexcolor |
| `field.colorHex` | string | `"#08253B"` | FieldConfig → GameFieldPainter/GameWorld | border0…24; brightness0…2; side100…2000; corner0…200; hexcolor |
| `field.cornerRadius` | number | `18` | FieldConfig → GameFieldPainter/GameWorld | border0…24; brightness0…2; side100…2000; corner0…200; hexcolor |
| `field.maxSide` | number | `380` | FieldConfig → GameFieldPainter/GameWorld | border0…24; brightness0…2; side100…2000; corner0…200; hexcolor |
| `game.startHintEnabled` | boolean | `true` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.idleSpeedMultiplier` | number | `0.5` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.idleEnemiesMove` | boolean | `false` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.speedRampSeconds` | number | `0.5` | MobileGameplayTuning | Android фиксирует0: равномерный разгон v0+a*t |
| `game.jumpEnabled` | boolean | `true` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.jumpDurationSec` | number | `0.38` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.jumpScale` | number | `1.32` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.helmetEnabled` | boolean | `true` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.helmetInvulnSec` | number | `0.3` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.startInvulnSec` | number | `0` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.heartbeatHaptic` | boolean | `true` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.timerHaptic` | boolean | `true` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.timerHapticStyle` | string | `"warning"` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.timerHapticStyle5` | string | `"warning"` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.timerHapticStyle10` | string | `"warning"` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.hudSpeedScaleMax` | number | `400` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.wallsKillPlayer` | boolean | `false` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `game.jumpCooldownSec` | number | `2` | GameConfig → GameHomeScreen/GameWorld/ArcadeHud | boolean; jumpCooldown2…60; duration0.05…5; scale1…3; invuln0…30; styles enum |
| `audio.music` | boolean | `true` | AudioConfig → PlayerPreferences → GameSfx | boolean; громкости0…1; локальное выключение имеет приоритет |
| `audio.musicVolume` | number | `0.35` | AudioConfig → PlayerPreferences → GameSfx | boolean; громкости0…1; локальное выключение имеет приоритет |
| `audio.sfxVolume` | number | `0.85` | AudioConfig → PlayerPreferences → GameSfx | boolean; громкости0…1; локальное выключение имеет приоритет |
| `audio.sfxMobWall` | boolean | `true` | AudioConfig → PlayerPreferences → GameSfx | boolean; громкости0…1; локальное выключение имеет приоритет |
| `audio.sfxMobCollide` | boolean | `false` | AudioConfig → PlayerPreferences → GameSfx | boolean; громкости0…1; локальное выключение имеет приоритет |
| `audio.sfxHeroMob` | boolean | `true` | AudioConfig → PlayerPreferences → GameSfx | boolean; громкости0…1; локальное выключение имеет приоритет |
| `audio.sfxHeroWall` | boolean | `true` | AudioConfig → PlayerPreferences → GameSfx | boolean; громкости0…1; локальное выключение имеет приоритет |
| `audio.sfxNearMiss` | boolean | `true` | AudioConfig → PlayerPreferences → GameSfx | boolean; громкости0…1; локальное выключение имеет приоритет |
| `audio.sfxHelmet` | boolean | `true` | AudioConfig → PlayerPreferences → GameSfx | boolean; громкости0…1; локальное выключение имеет приоритет |
| `audio.sfxJump` | boolean | `true` | AudioConfig → PlayerPreferences → GameSfx | boolean; громкости0…1; локальное выключение имеет приоритет |
| `audio.sfxStart` | boolean | `true` | AudioConfig → PlayerPreferences → GameSfx | boolean; громкости0…1; локальное выключение имеет приоритет |
| `economy.androidEnergyV2.enabled` | boolean | `true` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.revision` | string | `"firebase-energy-v1"` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.initialEnergy` | number | `50` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.batteryCapacity` | number | `20` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.chargeHours` | number | `8` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.baseAttemptCost` | number | `1` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.helmetExtraCost` | number | `1` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.jumpExtraCost` | number | `1` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.rewards.achievement` | number | `10` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.rewards.ad` | number | `40` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.rewards.google` | number | `10` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.rewards.age` | number | `10` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.rewards.feedback` | number | `50` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.rewards.invite` | number | `20` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.packages.0.id` | string | `"energy_100_v1"` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.packages.0.energy` | number | `100` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.packages.1.id` | string | `"energy_250_v1"` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.packages.1.energy` | number | `250` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.packages.2.id` | string | `"energy_500_v1"` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.packages.2.energy` | number | `500` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.packages.3.id` | string | `"energy_1000_v1"` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.packages.3.energy` | number | `1000` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.subscriptions.0.id` | string | `"energy_batteries_2_v1"` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.subscriptions.0.batteryCount` | number | `2` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.subscriptions.0.basePlanId` | string | `"weekly"` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.subscriptions.0.capacity` | number | `20` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.subscriptions.0.chargeHours` | number | `8` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.subscriptions.0.periodDays` | number | `7` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.subscriptions.1.id` | string | `"energy_batteries_5_v1"` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.subscriptions.1.batteryCount` | number | `5` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.subscriptions.1.basePlanId` | string | `"weekly"` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.subscriptions.1.capacity` | number | `20` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.subscriptions.1.chargeHours` | number | `8` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.subscriptions.1.periodDays` | number | `7` | AndroidEnergyConfig/PlayBillingService + server product() | Список активных SKU; содержимоеSKU неизменяемо; цены только Play |
| `economy.androidEnergyV2.watchAdCooldownSec` | number | `120` | AndroidEnergyConfig/EconomyStore + server engine | attempt1…1000; extras0…1000; reward0…100000; сервер проверяет |
| `economy.androidEnergyV2.simpleBonus.enabled` | boolean | `true` | SimpleEnergyBonus + server walletOperation/publicProfile | целые0…100000; period1…2592000с; cooldown0…86400с; серверная версия |
| `economy.androidEnergyV2.simpleBonus.version` | number | `1` | SimpleEnergyBonus + server walletOperation/publicProfile | целые0…100000; period1…2592000с; cooldown0…86400с; серверная версия |
| `economy.androidEnergyV2.simpleBonus.initialEnergy` | number | `50` | SimpleEnergyBonus + server walletOperation/publicProfile | целые0…100000; period1…2592000с; cooldown0…86400с; серверная версия |
| `economy.androidEnergyV2.simpleBonus.reward` | number | `30` | SimpleEnergyBonus + server walletOperation/publicProfile | целые0…100000; period1…2592000с; cooldown0…86400с; серверная версия |
| `economy.androidEnergyV2.simpleBonus.periodSec` | number | `28800` | SimpleEnergyBonus + server walletOperation/publicProfile | целые0…100000; period1…2592000с; cooldown0…86400с; серверная версия |
| `economy.androidEnergyV2.simpleBonus.tier2Reward` | number | `60` | SimpleEnergyBonus + server walletOperation/publicProfile | целые0…100000; period1…2592000с; cooldown0…86400с; серверная версия |
| `economy.androidEnergyV2.simpleBonus.tier5Reward` | number | `150` | SimpleEnergyBonus + server walletOperation/publicProfile | целые0…100000; period1…2592000с; cooldown0…86400с; серверная версия |
| `economy.androidEnergyV2.simpleBonus.videoReward` | number | `40` | SimpleEnergyBonus + server walletOperation/publicProfile | целые0…100000; period1…2592000с; cooldown0…86400с; серверная версия |
| `economy.androidEnergyV2.simpleBonus.videoCooldownSec` | number | `120` | SimpleEnergyBonus + server walletOperation/publicProfile | целые0…100000; period1…2592000с; cooldown0…86400с; серверная версия |
| `economy.androidEnergyV2.simpleBonus.inviterReward` | number | `60` | SimpleEnergyBonus + server walletOperation/publicProfile | целые0…100000; period1…2592000с; cooldown0…86400с; серверная версия |
| `economy.androidEnergyV2.simpleBonus.videoDailyLimit` | number | `20` | SimpleEnergyBonus + server walletOperation/publicProfile | целые0…100000; period1…2592000с; cooldown0…86400с; серверная версия |
| `economy.runRewardEvery` | number | `999` | ArcadeRules/EconomyStore + server round snapshot | целые1…1000000; замораживаются на старте раунда |
| `economy.riskRewardEvery` | number | `8` | ArcadeRules/EconomyStore + server round snapshot | целые1…1000000; замораживаются на старте раунда |
| `economy.earnSurviveSeconds` | number | `10` | ArcadeRules/EconomyStore + server round snapshot | целые1…1000000; замораживаются на старте раунда |
| `economy.earnRecordSeconds` | number | `20` | ArcadeRules/EconomyStore + server round snapshot | целые1…1000000; замораживаются на старте раунда |
| `economy.earnRisksInRun` | number | `5` | ArcadeRules/EconomyStore + server round snapshot | целые1…1000000; замораживаются на старте раунда |
| `economy.interstitialSessionGraceSec` | number | `180` | EconomyStore/AdsService | целые≥0; сборочные/возрастные ограничения сохраняются |
| `economy.interstitialSessionFreeRounds` | number | `10` | EconomyStore/AdsService | целые≥0; сборочные/возрастные ограничения сохраняются |
| `economy.interstitialGraceSec` | number | `210` | EconomyStore/AdsService | целые≥0; сборочные/возрастные ограничения сохраняются |
| `economy.interstitialCooldownSec` | number | `220` | EconomyStore/AdsService | целые≥0; сборочные/возрастные ограничения сохраняются |
| `economy.interstitialMinLives` | number | `6` | EconomyStore/AdsService | целые≥0; сборочные/возрастные ограничения сохраняются |
| `economy.initialLives` | number | `0` | Защитный fallback до профиля | 0/0/false: локальные старые валюты не начисляются |
| `economy.initialTokens` | number | `0` | Защитный fallback до профиля | 0/0/false: локальные старые валюты не начисляются |
| `economy.installBonusAutoClaim` | boolean | `false` | Защитный fallback до профиля | 0/0/false: локальные старые валюты не начисляются |
| `yandexMetrikaId` | string | `"112365078"` | Проверить потребителя при добавлении | Не заявлен активным без проверки |
| `mobileEnemies.startSpeedSteps` | number | `20` | MobileEnemyPace → MobileGameplayTuning | скорость0.01…250; ускорение0…50; variation0…0.5 |
| `mobileEnemies.accelerationSteps` | number | `4` | MobileEnemyPace → MobileGameplayTuning | скорость0.01…250; ускорение0…50; variation0…0.5 |
| `mobileEnemies.speedVariation` | number | `0.05` | MobileEnemyPace → MobileGameplayTuning | скорость0.01…250; ускорение0…50; variation0…0.5 |
| `mobileEnemies.accelerationVariation` | number | `0.08` | MobileEnemyPace → MobileGameplayTuning | скорость0.01…250; ускорение0…50; variation0…0.5 |

## Обоснованные исключения

- Графика, шрифты, геометрия согласованного UI141, pixel offsets и theme/GameUi — код/ресурсы приложения. Произвольная RC-перекомпоновка не поддерживается и нарушила бы сохранение интерфейса. Параметры поля/яркости/помощи/звука уже подключены отдельно.
- Неизменяемые SKU и их содержимое находятся в server product registry; новый объём требует нового SKU. RC выбирает доступные SKU и благоприятную политику8ч; цена/валюта/скидка рассчитываются по ответам Billing.
- Firebase project/appId, endpoint, база, OAuth clientId, signing cert, security rules, nonce format, idempotency и серверные сроки — технический контракт. Секреты/ключи платежей не публикуются в RC.
- TEST_TOOLS, DEMO/LIVE_ADS, Play Billing, production guard и согласие/возраст остаются сборочными или локальными ограничениями. RC не включает их за пользователя.
- Постоянный жест5тапов/≤1.5с/+20 — прямое продуктовое правило Алексея. Его сумма фиксирована доверенным сервером, не поступает из client payload.
- Размер аудиопула, throttling звуков, сеть/timeouts/backoff и алгоритмы столкновений — технические ограничения. Их безопасное изменение требует выпуска кода и профильной проверки.
- Telegram daily/lives/crystals/rentals/Stars и прежние avatar-cheats отсутствуют в новом Android snapshot. Telegram остаётся на своём сервере.
