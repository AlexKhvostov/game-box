# Админка геймплея — блоки Remote Config

В Firebase Console → **Remote Config** заведите параметры **по блокам** (удобно сложить в Parameter groups с теми же именами).

| Ключ параметра | Смысл |
|----------------|--------|
| `enemies` | Враги |
| `player` | Игрок |
| `field` | Поле / среда |
| `game` | Общие правила партии |
| `economy` | Жизни / кристалы / Daily / Earn |

После правок: **Save** → **Publish changes** → перезапуск приложения.

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
  "accelMax": 15
}
```

`aspects` — ширина/высота. Каждый враг спавнится в своём квадранте поля (TL/TR/BL/BR).

## `player`

```json
{
  "size": 36
}
```

## `field`

```json
{
  "borderWidth": 3
}
```

## `game`

```json
{
  "startHintEnabled": true,
  "idleSpeedMultiplier": 0.5,
  "speedRampSeconds": 0.5
}
```

- `idleSpeedMultiplier` — скорость врагов до касания (доля от стартовой)
- `speedRampSeconds` — разгон до полной скорости после старта

## `economy`

```json
{
  "initialLives": 10,
  "lifePackSize": 10,
  "lifePackCostTokens": 5,
  "lifePacks": [
    {"lives": 10, "costTokens": 5},
    {"lives": 12, "costTokens": 10},
    {"lives": 20, "costTokens": 15}
  ],
  "dailyRewardTokens": [2, 4, 9, 16, 32, 64, 81],
  "timedBonusTokens": 22,
  "timedBonusHours": 1,
  "premiumDailyMultiplier": 2,
  "earnActions": [
    {"id": "watch_ad", "title": "Смотреть рекламу", "subtitle": "Короткий ролик", "reward": 5},
    {"id": "social_post", "title": "Пост в соцсети", "subtitle": "Расскажите друзьям", "reward": 10},
    {"id": "enable_notifications", "title": "Уведомления", "subtitle": "Разрешить пуши", "reward": 5},
    {"id": "rate_app", "title": "Оценить игру", "subtitle": "Звёзды в магазине", "reward": 5},
    {"id": "invite_friend", "title": "Пригласить друга", "subtitle": "Поделиться ссылкой", "reward": 10}
  ]
}
```

- `lifePacks` — варианты обмена кристалов на жизни (окно по тапу на сердечко)  
- `lifePackSize` / `lifePackCostTokens` — legacy (если `lifePacks` нет)  
- `dailyRewardTokens` — только Daily-серия  
- `timedBonusTokens` — подарок (таймер `timedBonusHours`), **не** Daily  
- `timedBonusHours` — интервал подарка; при смене RC таймер пересчитывается от времени последнего забора (остаток не длиннее нового интервала)  
- `earnActions` — заработок кристалов (пока stubs в клиенте)

- `forceLocale` — отдельный параметр Remote Config: `en` | `ru` | пусто  
  Пусто = язык устройства (fallback **en**). Переключателя в приложении нет.

Валюта в UI: **Crystals / Кристалы** (Cubyx).

---

### Как сгруппировать в консоли

Remote Config → **Add parameter group**:
- группа **enemies** → параметр `enemies`
- группа **player** → `player`
- и т.д.
