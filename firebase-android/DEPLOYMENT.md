# Развёртывание Android Firebase

Состояние16.10.2026, продолжение после20:00: Алексей поручил выполнить все необходимые действия перехода. Исходники и эмуляторы подготовлены. В Chrome открыты личное подключение платёжного аккаунта Blaze и экран подтверждения OAuth официального Firebase CLI; ответы пользователя ожидаются. Облачное развёртывание не выполнено: последний проверенный тариф game-box-b30d4 — Spark. Не считать APK подключённым к готовому облаку.

## Что нужно согласовать

1. Подключить Blaze/платёжный аккаунт для **game-box-b30d4**. Новый named Firestore **android-v1**, регион **europe-west1**, оплачивается с первой операции: бесплатная квота относится только к одной `(default)` базе проекта. Functions требуют Blaze. Бюджетные уведомления не являются жёстким ограничителем расходов.
2. Разрешить вход Firebase CLI/ADC в этот проект с обычными OAuth-разрешениями развёртывания. Не копировать браузерные cookie, access/refresh tokens или service-account JSON в проект. Новые постоянные секреты не требуются.
3. Включить Google в Firebase Authentication существующего проекта, используя уже согласованный Web OAuth client. Anonymous уже включён. Проверить Android local/Play SHA из текущего signing key и зарегистрированных Play certificates. Это изменение способов входа; Google chooser проходит владелец.
4. Создать/назначить runtime service account с минимальными правами: доступ к новой Firestore, чтение Remote Config и Firebase Auth user records; выдать ему только нужные права Play Developer API для Untouch (просмотр покупок и управление подтверждением/расходованием). Не давать владельца Google Cloud или доступ к старой SQL-базе.
5. Новая тема Pub/Sub **untouch-android-play** и `androidPlayNotifications`: разрешить публикацию системному Google Play Notifications publisher **только в эту тему**, перевести RTDN этого Android-приложения с прежнего маршрута. Telegram не менять. Сам topic не предоставляет доступ к документам игроков.
6. Отдельный Firebase Hosting site **untouch-android-game-box-b30d4** для новых Android App Links, privacy и account deletion. Домен Firebase `untouch-android-game-box-b30d4.web.app`; старый сайт/DNS/Telegram не меняются. Это обычный Hosting в том же проекте, со своими квотами трафика/хранения.

## Проверяемый порядок после согласования

1. Войти Firebase CLI и настроить Application Default Credentials официальным Google login. Проверить projectId и billing. `firebase projects:list` — только просмотр.
2. Создать **новую** `android-v1` через Firebase/Google Cloud (Native mode, europe-west1). Не удалять и не менять `(default)`/старые scores. Никакого SQL import.
3. Проверить локальные исходники: `npm ci` в firebase-android и functions, Node22; Java21+ для emulator suite. `npm test` запускает demo-untouch-android, Auth/Functions/Firestore/Hosting на loopback.
4. Из firebase-android выполнить scoped deploy:

   ```powershell
   npx firebase deploy --project game-box-b30d4 --only firestore:android-v1,functions:untouch-android
   ```

   Поддержка selector проверена по коду установленного firebase-tools: выбирается только android-v1. В конфигурации явно задан europe-west1, чтобы исключить nam5 по умолчанию при автоматическом создании. Codebase отдельный; не удалять/перезаписывать чужие функции. Перед deploy проверить реальное наличие и регион новой базы. Деплой правил закрывает client reads/writes; Admin использует service account.

5. Проверить RC без публикации: `node publish-remote-config.js game-box-b30d4`. Этот скрипт требует ADC, сохраняет backup и меняет только параметр android_config_v1 в копии существующего template, сохраняя ETag/остальные параметры/условия. После проверки: та же команда с `--publish`. Не использовать whole-template replace поверх существующего проекта.
6. Проверить Cloud Logging/ошибки/индексы, максимальные instances2 на каждой функции, minInstances0, отсутствие логирования tokens/body. Настроить бюджетные уведомления выбранной суммы, срок хранения build artifacts. Нельзя обещать нулевой счёт или жёсткий лимит только по maxInstances.
7. Настроить Play RTDN и минимальные Play API права для нового runtime identity. Пройти тестовые purchase/restore/refund/replacement без настоящей оплаты; не отправлять пользователям сообщения.
8. Подписанный APK нового номера устанавливать через adb install -r только после проверки облака; не удалять141/не очищать данные. Проверить fresh50/bonus30/8h/5тапов+20/Google/round/ranking/restart/offline и привязку владельца. Между проверками force-stop. Main141 остаётся резервным артефактом.
9. Проверить отсутствие этого Hosting site ID и создать его через `npx firebase hosting:sites:create untouch-android-game-box-b30d4 --project game-box-b30d4`. Выполнить scoped `npx firebase deploy --project game-box-b30d4 --only hosting`. Проверить HTTPS `/.well-known/assetlinks.json`, `/privacy/`, `/delete-account/`, корректный Play referrer из `/a/CODE` и настоящую Android App Link verification. Старый PHP redirect не используется. Ссылка обрабатывается статическим JS с точным whitelist; установленное приложение открывается через App Link.

## Версии, данные и откат

- Cloud Function `androidApi`: Node22, europe-west1,256MiB, cpu gcf_gen1, concurrency1, maxInstances2, minInstances0, timeout60с. `androidPlayNotifications` отдельно в том же регионе, bounded instances, Pub/Sub retry для временных ошибок.
- `androidPlayReceiptFinalize` — Firestore2ndgen trigger новой named базы: подтверждает/расходует уже проверенную квитанцию даже после закрытия телефона или потерянного HTTP-ответа. Повтор проверяет статус Google и не начисляет баланс заново. В emulator event hook отключён для синтетических tokens; REST идемпотентность проверяется mock-тестом. Живой Eventarc/Play acceptance после разрешения.
- Server policy читает default `android_config_v1` без условий; cache5мин. Клиент fetch1ч, timeout5с, активация только при запуске. При rules_changed клиент принудительно обновляет конфиг при следующем запуске и прямо предлагает перезапуск.
- Не менять SKU contents: `product()` хранит original12ч для старых subscriptionSKU, публичная благоприятная политика8ч отражается в quote. Цены всегда Play Billing. DEFERRED сохраняет прежний tier до подтверждённой даты Google.
- Backup RC позволяет восстановить только новый Android-параметр с проверкой ETag. Историю данных новой базы не удалять при откате кода. Не включать обратно обработку старой локальной очереди: prefix — часть backend-контракта.
- Старые купленные токены с обфусцированным **SQL owner** не должны автоматически превратиться в подарок новому Firebase owner. Их безопасное восстановление требует дополнительного подтверждения владельца у Play; импорт SQL не выполняется и такой restore не заявлен проверенным.

Официальные источники: [Functions/Blaze](https://firebase.google.com/docs/functions/get-started), [Firestore billing](https://firebase.google.com/docs/firestore/pricing), [runtime](https://firebase.google.com/docs/functions/manage-functions), [Remote Config](https://firebase.google.com/docs/remote-config/flutter/get-started), [Play replacements](https://codelabs.developers.google.com/codelabs/play-billing-subs-replacement), [subscriptionsv2](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2).
