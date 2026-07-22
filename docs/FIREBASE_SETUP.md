# Подключение Firebase (Game Box)

Статус: **Android подключён** (`google-services.json`, Auth, Firestore, Remote Config в коде).

## Что уже сделано в проекте

- Package: `com.boxgame.game_box`
- Плагин Google Services в Gradle
- `lib/firebase_options.dart` из вашего `google-services.json`
- Анонимный вход при старте
- Рейтинг → коллекция Firestore `scores`
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
  "lifePackSize": 10,
  "lifePackCostTokens": 5,
  "lifePacks": [
    {"lives": 10, "costTokens": 5},
    {"lives": 12, "costTokens": 10},
    {"lives": 20, "costTokens": 15}
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
