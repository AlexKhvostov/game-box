# Untouch · Telegram на Vue

Новый клиент — порт Android188 в отдельном каталоге. Исторический `telegram-web` не изменяется и не импортируется; старые Telegram-профили не мигрируют. Механика, выдача энергии, рейтинг и коды приглашений общие с Android; аккаунты, балансы, рекламные сервисы и цены платформ раздельные.

**Состояние на20.10.2026:** локальный клиент и общий backend реализованы и проверяются. Серверная регрессия138/138, клиент14/14, независимый объединённый прогон93/93. Это проверки изолированного кода и browser QA. Настоящий вход/управление/плавность Huawei и Windows ещё не приняты; реальная реклама, Telegram deep link и общая внешняя интеграция не проверены. Платёжный код проверен имитациями, продажи отключены. Render и настоящие тестовые платежи отложены Алексеем.

Подробности: [план](PORT_PLAN.md), [матрица](../docs/release-evidence/telegram-port/P0/PARITY_MATRIX.md), [отчёт](../memory/tasks/2026-10-20-telegram-port-implementation.md), [независимое ревью](../memory/tasks/2026-10-20-telegram-port-reviewer.md).

## Локальный запуск на Windows

Из корня Untouch откройте два окна PowerShell. Установка зависимостей один раз:

```powershell
powershell -ExecutionPolicy Bypass -File telegram-app/tools/run.ps1 -Task install
```

В первом окне запустите изолированный API с временной базой PGlite. Он не читает настоящий токен и не подключается к рабочей базе:

```powershell
powershell -ExecutionPolicy Bypass -File telegram-app/tools/run.ps1 -Task qa
```

Во втором окне запустите интерфейс:

```powershell
powershell -ExecutionPolicy Bypass -File telegram-app/tools/run.ps1 -Task dev
```

Адрес — `http://127.0.0.1:5175/`. На странице есть метка тестовых данных. Ctrl+C останавливает соответствующий процесс. Перезапуск API создаёт новую временную базу; это не восстановление реального профиля. Обычный browser production-вход запрещён, fixture-допуск ограничен DEV+loopback и отсутствует в release bundle.

Launcher использует совместимый Node20.19+/22.12+/24 и npm11.21.1 при установке. Системный Node22.11 для Vite8 недостаточен. Для runtime нужен WebView с Web Locks, structuredClone, Array.at — ориентир Chrome98+/Safari15.4+, с проверкой возможностей при старте. На Huawei найден WebView157, но это ещё не приёмка игры.

## Проверки и сборка

```powershell
powershell -ExecutionPolicy Bypass -File telegram-app/tools/run.ps1 -Task check
powershell -ExecutionPolicy Bypass -File tools/build_telegram_web.ps1 -VueTelegram -Version 0.2.6 -TelegramApiUrl /telegram-api -TelegramAppUrl https://t.me/TestUntouch_bot -TelegramQa
```

Каждая сборка получает новый каталог `releases/vue-v<version>_<UTC>/` с `site`, hash-манифестом и ZIP. Старые каталоги не перезаписываются. Это локальный QA-артефакт, не публикация. Для следующего выпуска увеличьте версию. `VITE_TELEGRAM_APP_URL` — публичный адрес для share; рабочий Main Mini App URL настраивается отдельно.

Браузерное ядро генерируется `python telegram-app/tools/build_kernel.py` из immutable Android baseline. Оно требует локальный Dart SDK и privateSnapshot из P0. После генерации обязательны `telegram-app/test/kernel.test.mjs` и сравнение server replay. Не переписывайте физику на JavaScript и не заменяйте frozen source текущим файлом без нового эталона.

`qa/chart.html` — отдельный DEV fixture настоящего графика (count/threshold/partial/locale/text); в production entry он не включается. Основные tests — `telegram-app/test/*.test.mjs`; backend — `supabase/test/*.test.mjs`; независимые fixtures и hashes находятся в `docs/release-evidence/telegram-port/reviewer/`.

## Интеграция

Общий сервер: Telegram HMAC identity, серверный кошелёк, proof start/activate/finish, combined record/RMS, invitations, platform RC. Новая SQL-миграция и Edge Functions пока локальные. Токен бота и webhook secret — только серверные секреты; их нельзя класть в `.env` клиента, Vite-переменные или ZIP. `.env.example` содержит только публичные адреса.

Native QA использует отдельный gateway и временный HTTPS, без fixture-session, рекламы и Stars. Алексей подтвердил первый запуск20.10.2026; Windows basic и первый Huawei confirmed flow пройдены, [полный фактический scope и ограничения](../docs/release-evidence/telegram-port/native/README.md). Временные адреса закрыты; продолжение требует стабильного QA origin и перевыпущенного тестового токена. При завершении теста вернуть menu бота из private backup через `tools/set_qa_menu.ps1 -Restore`, остановить tunnel/gateway и движущуюся игру. Не трогать данные основной Android-игры и USB stay-awake2.

Перед публичной доставкой остаются обязательная native/visual/performance приёмка, внешняя серверная интеграция, Main Mini App/referral link и актуальная публичная информация о данных Telegram. После этого — отдельный этап Render. Реальные Stars-тесты по последнему поручению подключаются позже.

Текущий принятый локальный кандидат: [QA0.2.5](../releases/vue-v0.2.5_20261020_073627_973/verification.json). Для новой сборки используйте следующую версию0.2.6. Проверка portable ZIP и текущих source hashes: `python telegram-app/tools/verify_release.py releases/vue-v0.2.5_20261020_073627_973`. Native gate/tunnel уже остановлены, меню бота восстановлено; DEV preview оставлен на5175 с синтетической базой4181. Общий P09/P10 ещё не принят; локальный QA verdict не означает готовый публичный выпуск.
