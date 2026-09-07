# Telegram Web App — Untouch (аркада)

См. также: [FLOORS_MODE.md](FLOORS_MODE.md) · [GAMEPLAY_ADMIN.md](GAMEPLAY_ADMIN.md)

## Продакшен

| Параметр | Значение |
|----------|----------|
| Бот | [@UntouchGameBot](https://t.me/UntouchGameBot) |
| URL | https://untouch.ballaball.xyz/ |
| Хостинг | HostLand, каталог поддомена `untouch` |
| Сборка | `tools/build_telegram_web.ps1` → `build/web/` |

Токен бота — **только в секретах / личке**, не в git.

## Идея

Один репозиторий, **две сборки**:

| Сборка | Команда | Стек | Что внутри |
|--------|---------|------|------------|
| Android APK | `tools/build_phone_apk.ps1` | Flutter | Аркада + Этажи (пока морозим) |
| Telegram Web | `tools/build_telegram_web.ps1` | **Canvas + JS** | Только аркада «на рекорд» |

Исходники Telegram Web: `telegram-web/` (не Flutter).  
Паритет с APK: [TELEGRAM_CANVAS_PARITY.md](TELEGRAM_CANVAS_PARITY.md).

Старый Flutter Web (`flutter build web`) **больше не используется** для Telegram — был тяжёлый и давал фризы.

## Как обновлять (ваш процесс)

1. Мы правим код в `telegram-web/` (и при необходимости `lib/` для APK).
2. Вы (или CI) запускаете:
   ```powershell
   powershell -File tools/build_telegram_web.ps1
   ```
3. Содержимое папки **`build/web/`** заливаете **в корень каталога поддомена**  
   `https://untouch.ballaball.xyz/`  
   (не папку `web` целиком — именно файлы внутри: `index.html`, `js/`, `css/`, `assets/`, …).
4. Обновление в Telegram: пользователи открывают бота заново (кэш браузера Telegram иногда держится — при странностях Hard Reload / очистка данных WebView).

Удобно: упаковать `build/web` в zip и распаковать на хостинге в каталог поддомена.

```
untouch.ballaball.xyz/          ← корень поддомена на HostLand
  index.html
  js/
  css/
  config/
  assets/
  icons/
  favicon.png
  manifest.json
```

## BotFather

После первой заливки (когда по HTTPS открывается игра):

1. [@BotFather](https://t.me/BotFather) → ваш бот `@UntouchGameBot`
2. `/setmenubutton` → текст **Играть** → URL `https://untouch.ballaball.xyz/`
3. Опционально: `/newapp` / Mini App с тем же URL

Проверка: открыть [@UntouchGameBot](https://t.me/UntouchGameBot) → кнопка меню → игра.

## Полноэкран и жесты

Игра управляется свайпами — Telegram не должен перехватывать вертикальный жест.

В `web/index.html` и `TelegramBridge.bootstrapFullscreen()` вызываются:

1. `ready()` / `expand()` — максимальная высота
2. `disableVerticalSwipes()` — не сворачивать Mini App свайпом вниз
3. `requestFullscreen()` — настоящий fullscreen (Bot API 8.0+)
4. CSS: `overflow: hidden`, `touch-action: none`, `overscroll-behavior: none`

### Safe area (не перекрывать статус-бар / шапку TG)

Telegram отдаёт два inset:

| Поле | Смысл |
|------|--------|
| `safeAreaInset` | вырез, статус-бар, home indicator |
| `contentSafeAreaInset` | зона без UI Telegram (кнопки Close / …) |

В fullscreen HUD сдвигается на **сумму** top-inset’ов (`TelegramBridge.viewPadding`).  
Если клиент отдал нули — запас ~54 px.

Закрыть приложение можно крестиком / кнопкой Back в шапке Telegram.

## Firebase на web

Сейчас **не подключён**: `FirebaseBootstrap` на web сразу возвращает offline.  
Игра идёт на локальных дефолтах (жизни/конфиг из APK defaults, рейтинг без сервера).  
Подключение Firebase Web + ник из Telegram — следующий этап после UI/лагов.

## Что уже сделано в коде

- `web/` — Flutter Web + `telegram-web-app.js` в `index.html`
- Telegram-сборка сразу открывает аркаду (без Этажей)
- `lib/telegram/telegram_bridge.dart` — заглушка SDK (ник / expand — следующий этап)
- Firebase на web пока выключен (офлайн-игра; рейтинг + ник из Telegram — дальше)

## Локальная проверка

```powershell
powershell -File tools/build_telegram_web.ps1
flutter run -d chrome --dart-define=APP_TARGET=telegram
```

## Дальнейшие этапы

1. Первая заливка на `untouch.ballaball.xyz` + Menu Button в BotFather
2. `TelegramBridge` — user id / @username, убрать ввод имени
3. Firebase Web + рейтинг с `telegram_user_id`
4. Валидация `initData` (backend) — по необходимости
5. Этажи в Telegram — когда аркада стабильна

## Структура

```
web/                      — исходники оболочки Web
lib/app/app_target.dart
lib/telegram/
tools/build_telegram_web.ps1
build/web/                — артефакт для HostLand (в git не коммитим)
```
