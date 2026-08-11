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
  "speedRampSeconds": 0.5,
  "jumpEnabled": true,
  "jumpDurationSec": 0.38,
  "jumpScale": 1.32,
  "helmetEnabled": true,
  "helmetInvulnSec": 0.3,
  "hudSpeedScaleMax": 400,
  "wallsKillPlayer": true
}
```

- `idleSpeedMultiplier` — скорость врагов до касания (доля от стартовой)
- `speedRampSeconds` — разгон до полной скорости после старта
- `jumpEnabled` — `false` убирает прыжок из HUD, Shop и игры (доступ при `true` — через аренду)
- `jumpDurationSec` / `jumpScale` — длительность и визуальный масштаб прыжка
- `helmetEnabled` — `false` убирает шлем из HUD, Shop и игры
- `helmetInvulnSec` — секунды неуязвимости (мигание) после разрушения шлема
- `hudSpeedScaleMax` — верх шкалы скорости (полоска под полем); при 400 полоска заполняется быстрее, чем при 500
- `wallsKillPlayer` — `true`: касание границы/стены убивает героя; `false`: только блокирует проход, без смерти

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
  "initialLives": 10,
  "initialTokens": 40,
  "installBonusAutoClaim": true,
  "earnSurviveSeconds": 10,
  "earnRecordSeconds": 20,
  "earnRisksInRun": 5,
  "lifePackSize": 5,
  "lifePackCostTokens": 5,
  "lifePacks": [
    {"lives": 5, "costTokens": 5},
    {"lives": 15, "costTokens": 12},
    {"lives": 50, "costTokens": 30},
    {"lives": 250, "costTokens": 99}
  ],
  "dailyRewardTokens": [2, 4, 9, 16, 32, 64, 81],
  "timedBonusTokens": 22,
  "timedBonusHours": 1,
  "watchAdCooldownSec": 60,
  "premiumDailyMultiplier": 2,
  "jumpRentalCost": 20,
  "jumpRentalMinutes": 10,
  "jumpRentalHourCost": 60,
  "jumpRentalHourMinutes": 60,
  "helmetRentalCost": 40,
  "helmetRentalMinutes": 10,
  "helmetRentalHourCost": 120,
  "helmetRentalHourMinutes": 60,
  "riskRewardEvery": 5,
  "riskRewardTokens": 1,
  "runRewardEvery": 1000,
  "runRewardTokens": 1,
  "earnActions": [
    {"id": "install_bonus", "title": "Бонус за установку", "subtitle": "Приз за скачивание игры", "reward": 40},
    {"id": "survive_10s", "title": "Продержаться 10 секунд", "subtitle": "10 секунд в одной партии", "reward": 5},
    {"id": "record_20s", "title": "Рекорд 20 секунд", "subtitle": "Личный рекорд от 20 секунд", "reward": 10},
    {"id": "risks_5", "title": "5 рисков за партию", "subtitle": "Набрать 5 рисков в одной игре", "reward": 5},
    {"id": "watch_ad", "title": "Смотреть рекламу", "subtitle": "Короткий ролик", "reward": 5},
    {"id": "social_post", "title": "Пост в соцсети", "subtitle": "Расскажите друзьям", "reward": 10},
    {"id": "enable_notifications", "title": "Уведомления", "subtitle": "Разрешить пуши", "reward": 5},
    {"id": "rate_app", "title": "Оценить игру", "subtitle": "Звёзды в магазине", "reward": 5},
    {"id": "invite_friend", "title": "Пригласить друга", "subtitle": "Поделиться ссылкой", "reward": 10}
  ]
}
```

- `lifePacks` — варианты обмена кристалов на жизни (окно по тапу на сердечко). Если массив задан и не пустой — клиент показывает **только его** (дефолты из APK не дописываются). Можно удалённо менять состав и цены без нового билда.  
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
- `earnActions` — заработок кристалов; `install_bonus` — приз за установку; `survive_10s` / `record_20s` / `risks_5` — one-shot за геймплей (сначала открываются в игре, потом забор во вкладке Earn).  
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
