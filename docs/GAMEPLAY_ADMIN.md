# Админка геймплея — блоки Remote Config

См. также: [FIREBASE_SETUP.md](FIREBASE_SETUP.md) · [ANALYTICS_AND_ADMIN.md](ANALYTICS_AND_ADMIN.md) · [ADS_AND_BILLING.md](ADS_AND_BILLING.md) · [GOOGLE_PLAY_PUBLISH.md](GOOGLE_PLAY_PUBLISH.md)

В Firebase Console → **Remote Config** заведите параметры **по блокам** (удобно сложить в Parameter groups с теми же именами).

| Ключ параметра | Смысл |
|----------------|--------|
| `enemies` | Враги |
| `player` | Игрок |
| `field` | Поле / среда |
| `game` | Общие правила партии |
| `audio` | Звуки и музыка (вкл/выкл) |
| `economy` | Жизни / кристалы / Daily / Earn |

После правок: **Save** → **Publish changes** → полностью закрыть приложение и открыть снова (RC подтягивается при старте).

Клиент всегда ходит за свежим RC при запуске (`minimumFetchInterval = 0`). Если Firebase не инициализировался — берутся встроенные дефолты из APK.  
Важно: параметр в консоли должен быть **опубликован** (Publish), не только сохранён как черновик. Ключи: `economy`, `enemies`, `player`, `field`, `game`, `audio` — JSON-строки.

Гиперказуальный UX: одно поле без нижнего меню; касание стартует партию; кристалы — тап по счётчику.

### Язык

Параметр Remote Config **`forceLocale`** (String):
- пусто / `system` — язык устройства; если не `en`/`ru` → **English**
- `en` — принудительно English  
- `ru` — принудительно русский  

Переключателя в приложении нет. В Google Play / App Store локализуются витрина (описание, скриншоты); APK один — строки выбираются по локали устройства.

---

## `enemies`

```json
{
  "areaMultiplier": 2,
  "aspects": [1, 0.25, 0.5, 3],
  "angleMinDeg": 30,
  "angleMaxDeg": 60,
  "speedMin": 75,
  "speedMax": 105,
  "accelMin": 9,
  "accelMax": 15,
  "collideWithEachOther": false
}
```

`aspects` — ширина/высота. Каждый враг спавнится в своём квадранте поля (TL/TR/BL/BR).

- `collideWithEachOther` — мобы сталкиваются и отскакивают друг от друга как от стены (`true` / `false`)

## `player`

```json
{
  "size": 36,
  "showFace": false
}
```

- `showFace` — A/B: милое аниме-личико на кубе (`true`). По умолчанию `false` — просто квадрат без мордочки.

## `field`

```json
{
  "borderWidth": 3,
  "brightness": 1.0,
  "shadowBrightness": 1.0,
  "color": ""
}
```

- `brightness` — яркость заливки поля: `1.0` как в теме; `1.2`–`1.4` светлее; `0.7` темнее
- `shadowBrightness` — осветление теней объектов (отдельно от поля): `1.0` как сейчас; `1.3`–`1.6` светлее/слабее; `0.8` темнее
- `color` — опциональный цвет поля в hex (`#1A2228` или `1A2228`). Пустая строка / нет ключа = цвет темы + brightness

Пример светлее поле + мягче тени:
```json
{ "borderWidth": 3, "brightness": 1.25, "shadowBrightness": 1.4 }
```

Пример свой цвет:
```json
{ "borderWidth": 3, "brightness": 1.0, "color": "#24303A" }
```

## `game`

```json
{
  "startHintEnabled": true,
  "idleSpeedMultiplier": 0.5,
  "idleEnemiesMove": true,
  "speedRampSeconds": 0.5,
  "jumpEnabled": true,
  "jumpDurationSec": 0.38,
  "jumpScale": 1.32,
  "helmetEnabled": true,
  "helmetInvulnSec": 0.3,
  "startInvulnSec": 1,
  "heartbeatHaptic": true,
  "hudSpeedScaleMax": 400,
  "wallsKillPlayer": true
}
```

- `idleSpeedMultiplier` — скорость врагов до касания (доля от стартовой), если `idleEnemiesMove` включён
- `idleEnemiesMove` — `true`: враги ходят по полю до старта. `false`: стоят на спавне и слегка шатаются (дремота); с касанием возвращаются на свои позиции и разгоняются в заданных направлениях
- `speedRampSeconds` — разгон до полной скорости после старта
- `jumpEnabled` — `false` убирает прыжок из HUD, Shop и игры (доступ при `true` — через аренду)
- `jumpDurationSec` / `jumpScale` — длительность и визуальный масштаб прыжка
- `helmetEnabled` — `false` убирает шлем из HUD, Shop и игры
- `helmetInvulnSec` — секунды неуязвимости (мигание) после разрушения шлема
- `startInvulnSec` — секунды неуязвимости в начале раунда (мигание). `0` — сразу можно погибнуть
- `timerHaptic` — вибро на 1.00, 2.00, 3.00… `false` выключает
- `timerHapticStyle` — сила обычных секунд: `success` тише, `warning` обычно, `error` как проигрыш
- `timerHapticStyle5` / `timerHapticStyle10` — сила на 5 и 10 сек (те же значения). Потом можно сделать тише без новой заливки
- `hudSpeedScaleMax` — верх шкалы скорости (полоска под полем); при 400 полоска заполняется быстрее, чем при 500
- `wallsKillPlayer` — `true`: касание границы/стены убивает героя, рамка поля того же цвета, что и враги; `false`: только блокирует проход, без смерти, рамка обычная. Работает в аркаде (Telegram Mini App и Android) и в Этажах.

Для теста аренды: `"jumpEnabled": true` / `"helmetEnabled": true` + купить в магазине.

## `audio`

```json
{
  "sfxMobWall": true,
  "sfxMobCollide": true,
  "sfxHeroMob": true,
  "sfxHeroWall": true,
  "sfxNearMiss": true,
  "sfxHelmet": true,
  "sfxJump": true,
  "sfxStart": true,
  "music": true,
  "sfxVolume": 1.0,
  "musicVolume": 0.08
}
```

Флаги — вкл/выкл (`true` / `false`). Громкости — число от `0` до `1`:

| Ключ | Когда играет / что делает |
|------|----------------|
| `sfxMobWall` | моб ударился о стену |
| `sfxMobCollide` | моб о моба (нужен ещё `enemies.collideWithEachOther`) |
| `sfxHeroMob` | герой врезался в моба (конец игры) |
| `sfxHeroWall` | герой врезался в стену (конец игры) |
| `sfxNearMiss` | опасный момент (risk) — лёгкий свист / скольжение |
| `sfxHelmet` | шлем разбился — короткое стекло |
| `sfxJump` | прыжок (double-tap) |
| `sfxStart` | старт партии (первое касание) |
| `music` | тихий фоновый луп |
| `sfxVolume` | общая громкость всех SFX (`1.0` = как сейчас, `0.5` = вдвое тише) |
| `musicVolume` | громкость фоновой музыки (`0.08` по умолчанию; `0` = тихо, `1` = максимум плеера) |

Пример: тише эффекты, чуть громче музыка:
```json
{ "sfxVolume": 0.7, "musicVolume": 0.12, "music": true }
```

Пример выключить музыку и столкновения-SFX:
```json
{ "sfxMobWall": true, "sfxMobCollide": false, "sfxHeroMob": true, "sfxHeroWall": true, "sfxNearMiss": true, "sfxHelmet": true, "sfxJump": true, "sfxStart": true, "music": false, "sfxVolume": 1.0, "musicVolume": 0.08 }
```

## `economy`

```json
{
  "initialLives": 8,
  "initialTokens": 15,
  "installBonusAutoClaim": true,
  "earnSurviveSeconds": 10,
  "earnRecordSeconds": 20,
  "earnRisksInRun": 5,
  "lifePacks": [
    {"lives": 8, "costTokens": 10},
    {"lives": 25, "costTokens": 28},
    {"lives": 80, "costTokens": 80},
    {"lives": 250, "costTokens": 220}
  ],
  "dailyRewardTokens": [3, 4, 5, 6, 8, 10, 12],
  "timedBonusTokens": 6,
  "timedBonusHours": 6,
  "watchAdCooldownSec": 180,
  "adsgramBlockId": "46825",
  "adsgramInterstitialBlockId": "int-46979",
  "interstitialGraceSec": 210,
  "interstitialCooldownSec": 180,
  "interstitialMinLives": 3,
  "avatarCheatEnabled": false,
  "avatarCheatTokens": 10,
  "premiumDailyMultiplier": 2,
  "jumpRentalCost": 12,
  "jumpRentalMinutes": 10,
  "jumpRentalHourCost": 36,
  "jumpRentalHourMinutes": 60,
  "helmetRentalCost": 20,
  "helmetRentalMinutes": 10,
  "helmetRentalHourCost": 60,
  "helmetRentalHourMinutes": 60,
  "riskRewardEvery": 8,
  "riskRewardTokens": 1,
  "runRewardEvery": 400,
  "runRewardTokens": 1,
  "starsShop": {
    "packs": [
      {"id": "pack_s", "title": "Горсть", "crystals": 30, "stars": 39},
      {"id": "pack_m", "title": "Стопка", "crystals": 80, "stars": 89, "badge": "deal"},
      {"id": "pack_l", "title": "Сундук", "crystals": 200, "stars": 199, "badge": "best"},
      {"id": "pack_xl", "title": "Сейф", "crystals": 500, "stars": 449, "badge": "max"}
    ],
    "plus": {"id": "plus_weekly", "title": "Plus", "stars": 49, "days": 7}
  },
  "earnActions": [
    {"id": "install_bonus", "reward": 15},
    {"id": "survive_10s", "reward": 4},
    {"id": "record_20s", "reward": 8},
    {"id": "risks_5", "reward": 4},
    {"id": "watch_ad", "reward": 3},
    {"id": "enable_notifications", "reward": 5},
    {"id": "invite_friend", "reward": 15}
  ]
}
```

- `lifePacks` — варианты обмена кристалов на жизни (окно по тапу на сердечко). Если массив задан и не пустой — клиент показывает **только его** (дефолты из APK не дописываются). Можно удалённо менять состав и цены без нового билда.  
- `starsShop` — пакеты кристаллов за Telegram Stars и Plus (Mini App). Android этот блок игнорирует.  
  Plus сейчас **недельный**: `plus_weekly`, 49 ⭐ / 7 дней. Telegram умеет автопродление Stars **только 30 дней**, поэтому неделя — разовая покупка, продлевается ещё одним платежом.  
  Калькулятор и предложенный баланс: вкладка **Монетизация** в админке и [MONETIZATION.md](MONETIZATION.md).  
  Править **внутри существующего** JSON `economy`, не публиковать `starsShop` отдельным параметром.  
  После Publish PHP (счёт Stars) и витрина Mini App берут те же числа; кэш PHP до 3 минут.
```json
"starsShop": {
  "packs": [
    { "id": "pack_s", "title": "Горсть", "crystals": 30, "stars": 39 },
    { "id": "pack_m", "title": "Стопка", "crystals": 80, "stars": 89, "badge": "deal" },
    { "id": "pack_l", "title": "Сундук", "crystals": 200, "stars": 199, "badge": "best" },
    { "id": "pack_xl", "title": "Сейф", "crystals": 500, "stars": 449, "badge": "max" }
  ],
  "plus": { "id": "plus_weekly", "title": "Plus", "stars": 49, "days": 7 }
}
```
  `badge`: `deal` (Выгодно), `best` (Лучшая цена), `max` (Максимум), или пусто.  
  `id` пакета лучше не менять у уже продающихся позиций — это ключ счёта. Новый пакет = новый `id`.  
- `lifePackSize` / `lifePackCostTokens` — legacy (если `lifePacks` нет)
- `initialTokens` — стартовые кристалы при первой установке (fallback, если в `earnActions` нет `install_bonus`)  
- `installBonusAutoClaim` — `true` (по умолч.): бонус за установку выдаётся сразу и сразу отмечен в Earn; `false`: игрок забирает сам во вкладке Earn  
- `earnSurviveSeconds` / `earnRecordSeconds` / `earnRisksInRun` — пороги one-shot бонусов Earn (`survive_10s`, `record_20s`, `risks_5`)  
- `jumpRentalCost` / `jumpRentalMinutes` — короткая аренда прыжка (фича: `game.jumpEnabled`)  
- `jumpRentalHourCost` / `jumpRentalHourMinutes` — часовой пакет прыжка со скидкой (по умолч. 60 вместо 120)  
- `helmetRentalCost` / `helmetRentalMinutes` — короткая аренда шлема (фича: `game.helmetEnabled`)  
- `helmetRentalHourCost` / `helmetRentalHourMinutes` — часовой пакет шлема со скидкой (по умолч. 120 вместо 240)  
- `riskRewardEvery` / `riskRewardTokens` — за каждые N рисков в раунде начисляется M кристалов (по умолч. 5 → 1); выдача на экране результата, по одному с полётом к HUD  
- `runRewardEvery` / `runRewardTokens` — за каждые N пробега начисляется M кристалов (по умолч. 1000 → 1); тоже на результате, по одному  
- `dailyRewardTokens` — только Daily-серия  
- `timedBonusTokens` — подарок (таймер `timedBonusHours`), **не** Daily  
- `timedBonusHours` — интервал подарка; при смене RC таймер пересчитывается от времени последнего забора (остаток не длиннее нового интервала)  
- `watchAdCooldownSec` — фриз кнопки «смотреть рекламу» после забора (секунды; `60` = 1 мин; `0` = без фриза)  
- `adsgramBlockId` — ID блока **Reward** из [partner.adsgram.ai](https://partner.adsgram.ai). Сейчас `46825`. Пусто = кнопка в магазине не выдаёт кристаллы (ролик не открывается). Plus **не** прячет эту кнопку. Правка — **внутри** JSON `economy`, затем Publish.
- `adsgramInterstitialBlockId` — ID блока **Interstitial** из AdsGram. Нужен вид `int-46979` (префикс `int-`). Если в RC случайно только цифры `46979`, клиент сам допишет `int-`. Пусто = на результате реклама не показывается. Не подставлять Reward `46825`. Plus **выключает** interstitial.
- `interstitialGraceSec` — невидимый фриз после **первого в жизни** забора дневной награды (секунды). Дефолт `210` (~3,5 мин). `0` = можно сразу после первого Daily.
- `interstitialCooldownSec` — пауза между interstitial на результате (секунды). Дефолт `180` (3 мин). Реклама только при входе на результат, не чаще этого интервала. `0` = можно каждую попытку после фриза.
- `interstitialMinLives` — не показывать interstitial, если на экране результата жизней **меньше** этого числа (жизнь за попытку уже списана). Дефолт `3`. `0` = порог выкл.
- `avatarCheatEnabled` — чит для беты: 5 тапов по аватарке в профиле дают кристаллы. По умолчанию выкл. Работает **только** если в RC явно `"avatarCheatEnabled": true`.
- `avatarCheatTokens` — сколько кристаллов за 5 тапов (по умолч. `10`). Правка — внутри JSON `economy`, затем Publish.  
- `earnActions` — заработок кристалов; `install_bonus` — приз за установку; `survive_10s` / `record_20s` / `risks_5` — one-shot за геймплей (сначала открываются в игре, потом забор во вкладке Earn).  
  `invite_friend` — личная ссылка `startapp=r<id>`. За **каждого** друга, который открыл игру, `reward` кристаллов (сейчас 15). Кнопка «Поделиться» не закрывается. Ниже — список пришедших.  
  `enable_notifications` — награда после согласия боту писать (`requestWriteAccess`).  
  `rate_app` в Mini App не показываем (в Telegram нечего оценивать в магазине).  
  Клиент **подмешивает** недостающие дефолтные id, даже если в RC старый список; совпадающие id берут `reward` из RC.  

- `forceLocale` — отдельный параметр Remote Config: `en` | `ru` | пусто  
  Пусто = язык устройства (fallback **en**). Переключателя в приложении нет.

Валюта в UI: **Crystals / Кристалы**.

---

### Как сгруппировать в консоли

Remote Config → **Add parameter group**:
- группа **enemies** → параметр `enemies`
- группа **player** → `player`
- и т.д.
