# Подключение Firebase (Untouch)

Бренд приложения: **Untouch**. Package Android: `com.boxgame.game_box`.

Статус: **Android подключён** (`google-services.json`, Auth, Firestore, Remote Config, Analytics в коде).

См. также операционные гайды:

- [ANALYTICS_AND_ADMIN.md](ANALYTICS_AND_ADMIN.md) — сбор данных, админка, Amplitude  
- [ADS_AND_BILLING.md](ADS_AND_BILLING.md) — реклама и платежи  
- [GOOGLE_PLAY_PUBLISH.md](GOOGLE_PLAY_PUBLISH.md) — публикация в Google Play  

## Что уже сделано в проекте

- Package: `com.boxgame.game_box`
- Плагин Google Services в Gradle
- `lib/firebase_options.dart` из вашего `google-services.json`
- Анонимный вход при старте
- Рейтинг → коллекция Firestore `scores`
- Firebase Analytics → события MVP (`lib/data/app_analytics.dart`)
- Параметры Remote Config блоками: `enemies`, `player`, `field`, `game`, `economy`  
  (см. [GAMEPLAY_ADMIN.md](GAMEPLAY_ADMIN.md))

## Что проверить в консоли

1. **Authentication** → Anonymous включён  
2. **Firestore** создан (test mode ок на старте)  
3. **Remote Config** → параметр `economy` → **Publish changes**

### Параметр `economy` (пример)

```json
{
  "initialLives": 10,
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
  "timedBonusHours": 8
}
```

`lifePacks` — пакеты обмена кристалов на жизни.  
`timedBonusTokens` — подарок у кристалов (не Daily). Кристалы открываются тапом по счётчику.

## Индекс Firestore (если консоль попросит)

При первом запросе топа Firebase может показать ссылку «создать индекс» для `fair` + `timeMs`. Откройте ссылку и создайте индекс.

## Параметр `gameplay` (админка механики)

Создайте второй параметр Remote Config с ключом `gameplay` (JSON), см. [GAMEPLAY_ADMIN.md](GAMEPLAY_ADMIN.md).
