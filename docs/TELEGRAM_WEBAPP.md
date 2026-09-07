# Telegram Web App — Untouch (аркада)

См. также: [TELEGRAM_CANVAS_PARITY.md](TELEGRAM_CANVAS_PARITY.md) · [GAMEPLAY_ADMIN.md](GAMEPLAY_ADMIN.md)

Этажи в Mini App **на паузе**. Работаем только с аркадой.

## Продакшен

| Параметр | Значение |
|----------|----------|
| Бот | [@UntouchGameBot](https://t.me/UntouchGameBot) |
| URL | https://untouch.ballaball.xyz/ |
| Хостинг | HostLand, каталог поддомена `untouch` |
| Сборка | `tools/build_telegram_web.ps1` → папка **`hosting/`** (для FTP) |
| Рейтинг / профиль | MySQL `api/scores.php` |
| Stars | `api/payments.php` + webhook `api/telegram_webhook.php` |

Токен бота и пароль БД — **только на хостинге**, не в git (`api/db_config.php`, `api/bot_config.php`).

## Админка бота

Адрес: [https://untouch.ballaball.xyz/admin/](https://untouch.ballaball.xyz/admin/)

Это отдельная web-страница, не внутри игры. Там видно, кто писал боту, и срезы: сегодня / неделя / 30 дней, новые, активные, /start, кто уже играл.

1. В `api/bot_config.php` на HostLand добавьте строку `'admin_key' => 'длинный-секрет',` — не токен бота. Если `admin_key` пустой, подойдёт уже существующий `diag_key`.
2. Залейте свежие `api/admin.php`, `api/tg_common.php`, `api/telegram_webhook.php` и папку `admin/`.
3. Откройте `/admin/`, введите ключ. Cookie живёт 30 дней.

Список начинает копиться **после заливки**: каждый апдейт webhook пишется в таблицы `bot_users` и `bot_daily`. Старых игроков админка один раз подтянет из рейтинга, рефералов и кошельков. Кто написал боту до заливки и больше ничего не делал — в истории нет.

## Идея

Один репозиторий, **две сборки**:

| Сборка | Команда | Стек | Что внутри |
|--------|---------|------|------------|
| Android APK | `tools/build_phone_apk.ps1` | Flutter | Аркада (+ Этажи заморожены) |
| Telegram Web | `tools/build_telegram_web.ps1` | **Canvas + JS** | Только аркада «на рекорд» |

Исходники Telegram: `telegram-web/` (не Flutter Web).

## Как обновлять

1. Правим код в `telegram-web/`.
2. Сборка:
   ```powershell
   powershell -File tools/build_telegram_web.ps1
   ```
3. Содержимое папки **`hosting/`** (её собирает скрипт) заливаете по FTP в корень `https://untouch.ballaball.xyz/`  
   Не папку `web/` — это старый шаблон Flutter, не Mini App.
4. Секреты на хосте не перезаписывать: `api/db_config.php`, `api/bot_config.php`.
5. В Telegram при странном кэше — закрыть Mini App и открыть снова.

```
untouch.ballaball.xyz/
  index.html
  js/
  css/
  config/
  api/          ← PHP: scores, payments, webhook
  assets/
  icons/
```

## Telegram Stars (бета)

Каталог живёт в Remote Config, ключ `economy` → объект `starsShop` (не отдельный параметр).  
Дефолты — в [`telegram-web/config/gameplay-config.json`](../telegram-web/config/gameplay-config.json).

Сейчас: Горсть 40кр / 49⭐, Стопка 120/149, Сундук 350/349, Сейф 900/749, Plus 199⭐ / 30 дней.

Цена счёта и выдача кристаллов берутся **с сервера** (PHP читает тот же RC). Витрина в Mini App — для отображения.

Plus: ×2 daily, без навязчивого баннера (если появится). Ролик за кристаллы у Plus **остаётся**.

### Что сделать один раз на HostLand / BotFather

1. Скопировать [`api/bot_config.example.php`](../telegram-web/api/bot_config.example.php) → `api/bot_config.php`, вписать токен `@UntouchGameBot`.
2. BotFather: включить платежи / Stars для бота.
3. Поставить webhook на **Cloudflare Worker**, не на HostLand.  
   Telegram часто не достучаться до РФ-хостинга (`Connection timed out` в `ping.php` → `webhook.last_error`).
   ```
   https://untouch-tg-api.lihach-ok.workers.dev/bot<TOKEN>/setWebhook?url=https://untouch-tg-api.lihach-ok.workers.dev/webhook
   ```
   Код Worker: [`tools/telegram-api-proxy.worker.js`](../tools/telegram-api-proxy.worker.js).  
   В Cloudflare у Worker должен быть secret `BOT_TOKEN`. Worker отвечает на `/start` сам и пытается переслать платежи на HostLand.
4. PHP на хосте: `pdo_mysql`, `curl`.
5. Проверка: `https://untouch.ballaball.xyz/api/ping.php`  
   - `"telegram":{"ok":true}` — HostLand пишет в Telegram через Worker.  
   - `"webhook":{"url":"...workers.dev/webhook"}` и пустой `last_error` — команды доходят.
6. Проверка оплаты: открыть игру в боте → магазин → купить тестовый пак → кристаллы после оплаты; Plus → daily ×2; перезапуск Mini App — баланс на месте.

Отмена Plus — в платежах Telegram (Stars), не кнопкой в игре.

## BotFather (игра)

Картинки: [`telegram-web/assets/branding/`](../telegram-web/assets/branding/).

1. `/newapp` → title `Untouch`, short name `untouch`, URL `https://untouch.ballaball.xyz/`  
   Фото Web App: `botfather_webapp_640x360.jpg` (ровно 640×360).
2. `/setuserpic` → `bot_avatar_640.jpg` (640×640).
3. `/setabouttext` → `Аркада: уводите кубик от красных и бейте рекорд.`
4. `/setdescription` → текст приветствия (см. `tg_start_text()` в `api/tg_common.php`).
5. `/setmenubutton` → **Играть** → `https://untouch.ballaball.xyz/`
6. `/setinline` → любой placeholder, например `Untouch` — нужно для красивой ссылки в приглашении.

Ответ на `/start` шлёт webhook (`api/telegram_webhook.php`) — кнопка Mini App «Играть». Нужна заливка PHP на хост.

## Полноэкран и жесты

`telegram-web/js/telegram.js`: `ready` / `expand` / `disableVerticalSwipes` / `requestFullscreen` / safe area.

## Приглашения и уведомления

Личная ссылка игрока: `https://t.me/UntouchGameBot?start=r<telegramUserId>`. В сообщении она показывается как фраза **«Перейти в бот с игрой»** (HTML-ссылка + кнопка), а не длинный URL.

Для этого один раз в BotFather: `/setinline` → `@UntouchGameBot` → любой placeholder, например `Untouch`. Без inline-режима Mini App не сможет открыть красивый шаринг: бот пришлёт то же сообщение в чат, его нужно переслать.

Когда друг открывает бота по этой ссылке (`/start r…`), PHP пишет пару «кто пригласил → кто пришёл» в таблицу `referrals`. У пригласившего во вкладке **Действия** ниже кнопки — список тех, кто открыл игру. За каждого друга `reward` кристаллов (сейчас 20), не за нажатие «Поделиться».

Уведомления: `requestWriteAccess`. Награда `enable_notifications` только после согласия писать в чат. Флаг хранится в `user_flags`.

После заливки PHP таблицы создаются сами. Код Worker (`tools/telegram-api-proxy.worker.js`) тоже обновить: если друг пришёл через `/start r123`, кнопка «Играть» сохраняет тот же код.

## Рейтинг

Онлайн через HostLand MySQL (`scores.php`). На сервере хранится **лучший заезд игрока за календарный день**.  
Локально на телефоне — только свои попытки (вкладка «Мои»). Чужой рейтинг не кэшируется: при открытии таблицы игра заново читает БД.  
Пробег в рейтинге — в **шагах** (не метры). При первой заливке этого кода таблица `scores` один раз очищается.  
POST рекорда и профиля проверяет HMAC `initData`, если настроен `bot_config.php`.  
Публичный `?diag=1` закрыт; диагностика только с `diag_key` из `bot_config.php`.

## Яндекс.Метрика

Счётчик `112365078` — в `config/gameplay-config.json`, поле `yandexMetrikaId`. Отчёты: [metrika.yandex.ru](https://metrika.yandex.ru/).

## Локальная проверка UI

```powershell
powershell -File tools/build_telegram_web.ps1
```

Открыть `build/web/` локально можно для вёрстки; **оплата Stars работает только внутри Telegram**.

## Не в этой бете

- Этажи
- Rewarded-реклама
- Google Play IAP / Flutter billing
- Firebase как платёжный бэкенд
