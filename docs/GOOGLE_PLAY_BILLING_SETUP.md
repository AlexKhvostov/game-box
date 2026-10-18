# Подключение покупок Android

10.10.2026 01:51: Web и три Android OAuth clients уже созданы. Google identity включён в кандидате APK/AAB1.0.47+48 и настроен в private server config; read-back/HTTPS/invalid token проверены. Actual Android login ещё не принят, Billing off и каталог не активирован. Публичный Web ID в [реестре](../store/google-play/google-signin-clients.json), [полный результат](../memory/tasks/2026-10-10-google-signin.md). Ожидания clients ниже — закрытая история.

Актуализация 10.10.2026 01:37: Google Auth Platform Untouch уже создана, User support email и Developer contact — skeptickdev@gmail.com; support@untouch.fun остаётся обычной поддержкой. OAuth clients пока отсутствуют, подготовлены Web/server и Android/upload/Play classic/Play PQ, их точные сертификаты и проверки в [Google sign-in](../memory/tasks/2026-10-10-google-signin.md). Инициализация GoogleSignIn исправлена. Billing и реклама не включены. Старые строки о несозданной конфигурации/ожидании Google support-аккаунта ниже сохранены как история, не текущий блокер.

Срез: 09.10.2026 17:23, Europe/Minsk. Код проверен изолированно; пять товаров и USD-цены сохранены в Play как черновики. Рабочая интеграция Google ещё не включена. Основной отчёт: [android-billing](../memory/tasks/2026-10-09-android-billing.md).

## Каталог и цены

| ID | Состав | Название EN / RU | Тип | Цена |
|---|---|---|---|---|
| pack_s | 30 кристаллов | 30 crystals / 30 кристаллов | Разовый расходуемый товар | USD 1.00 |
| pack_m | 80 кристаллов | 80 crystals / 80 кристаллов | Разовый расходуемый товар | USD 2.00 |
| pack_l | 200 кристаллов | 200 crystals / 200 кристаллов | Разовый расходуемый товар | USD 3.00 |
| pack_xl | 500 кристаллов | 500 crystals / 500 кристаллов | Разовый расходуемый товар | USD 5.00 |
| plus_weekly | Без межстраничной рекламы, удвоенная ежедневная награда | Untouch Plus | Подписка: base plan `weekly`, P1W, auto-renewing | USD 0.99 / неделя |

Цены и базовая валюта USD утверждены Алексеем 09.10.2026. Все пять товаров сохранены как черновики, не активированы. Суммы США вручную выровнены с утверждёнными после автоматического округления Google. Другие валюты — пересчёт Google Play; итоговую локальную цену приложение получает из ProductDetails. По последнему решению Алексея цены 1/2/3/5 USD; увеличение пакета снижает цену за кристалл. Временное предложение 500 за 4 USD отменено пользователем до сохранения. Цены можно изменять; существующие подписчики по умолчанию сохраняют прежнюю цену до отдельной миграции группы. Указанный license-test аккаунт совпадает с текущим издателем Best4U (проверено меню Play); издатель автоматически license tester. Отдельный список не сохранён, реальная тестовая транзакция ещё не выполнялась. Личную почту не публиковать в документации.

Для кристаллов purchase option `standard`, тип Buy, без аренды, предзаказа, скидок и multi-quantity на старте. Проверить совместимость standard с Billing 8 и выдачу ProductDetails. Цены/валюту/страны задаёт владелец. Не пересчитывать Telegram Stars как денежную цену. Пример EN: `30 in-game crystals for lives and ability rentals in Untouch. One-time purchase; no automatic renewal.` RU: `30 игровых кристаллов для жизней и аренды способностей в Untouch. Разовая покупка без автопродления.` Для остальных заменить только количество. Google требует цену даже при сохранении товара как проекта: попытка pack_s без цен 09.10 не сохранена.

Клиент принимает только недельный базовый тариф Plus без trial/offer/рассрочки: иначе первая льготная цена могла бы выдаваться за обычную недельную. Не активировать другие планы до поддержки их условий в интерфейсе.

## Подготовленные доступы — пока не выданы

Проверен проект `game-box-b30d4` (существующий проект этой игры в firebase_options.dart и старом google-services.json). OAuth не настроен; отдельного платёжного service account нет. Существующий firebase-adminsdk не использовать для этой задачи.

| Компонент | Предлагаемое имя | Минимальная область |
|---|---|---|
| Проверка/consume/ack через Play Developer API | `untouch-play-verifier` | В Play Console только Untouch: View financial data/orders и Manage orders/subscriptions. Без публикации/управления пользователями. В Cloud не давать Owner/Editor |
| Идентичность push RTDN | `untouch-play-push` | Только подпись запросов Pub/Sub к конкретному HTTPS endpoint; не предоставлять доступ к Play/БД |
| Pub/Sub topic | `untouch-play-events` | Google `google-play-developer-notifications@system.gserviceaccount.com`: Publisher только на этой теме |
| Push subscription | `untouch-play-events-push` | Аутентифицированный push, audience точно равна URL ниже; настроить повтор и мониторинг недоставленных сообщений |
| OAuth web client | `Untouch server` | Вход/проверка ID token; без Drive/Gmail scopes и redirect URI, не нужных native sign-in |
| OAuth Android | `Untouch Play` | com.best4u.untouch + SHA-1 Play App Signing, взять из консоли; SHA-256 из отчёта не подставлять в поле SHA-1 |
| OAuth Android для локального signed APK | `Untouch upload test` | Тот же package + SHA-1 upload key; это отдельный сертификат |

Включить Android Publisher API и Pub/Sub только после согласования новых доступов/учёта расходов. Для push Google service agent должен иметь `roles/iam.serviceAccountTokenCreator` на push identity, если Google этого требует; не выдавать роль на весь проект. Выпуск JSON key для verifier создаёт постоянный секрет и требует отдельного подтверждения. Сохранить его вне публичного webroot, не в Git. Ключи/токены не копировать в чат.

OAuth branding: Untouch, домен untouch.fun, privacy https://untouch.fun/privacy/, support@untouch.fun. Алексей разрешил использовать существующий support-контакт. В текущем выборе support email доступен только личный Gmail владельца, его подстановка не разрешена. По официальной справке support должен быть текущим Google-аккаунтом или управляемой Google Group; у владельца запрошено, зарегистрирован ли support как Google-аккаунт. Новый аккаунт/группу и права не создавать предположением. Условия Google User Data Policy подтверждает владелец в момент принятия.

## Сервер и включение

`mobile_config.example.php` содержит точный состав товаров, но не секреты. В приватной конфигурации нужны Google Web client ID, путь к JSON verifier вне webroot, package, каталог, независимый `play_token_key` (base64 32 случайных байтов), точные `play_rtdn_audience`, `play_rtdn_service_email`, `play_rtdn_subscription`.

Планируемый endpoint: `https://untouch.ballaball.xyz/api/mobile_play_rtdn.php`. Не считать его опубликованным. Endpoint проверяет Google RS256 сертификат, issuer, audience, срок, email/email_verified, Pub/Sub subscription и package. RTDN лишь инициирует запрос Google API; количество/доступ из уведомления не принимаются. Новая покупка может быть привязана к существующему профилю по Google-проверенному hash account ID до ответа приложения. Удалённый профиль из платежного события не воссоздаётся.

Сервер сериализует проверку одного токена MySQL GET_LOCK, фиксирует выдачу транзакцией до consume/ack. Кристаллы проверяются через purchases.productsv2, частичный возврат — через cumulative refundableQuantity; исходная стоимость пакета сохраняется в ledger. Повтор и старое событие не начисляют повторно. Возврат списывает до нуля, без отрицательного баланса/денежного долга (рабочий выбор агента, не отдельное решение Алексея). При наличии старых платёжных записей без grant metadata нужна явная миграция; текущее отсутствие записей в production ещё не проверено. Старый шифр от private key сервисного аккаунта не мигрируется автоматически.

Подписка: active/grace/canceled даёт доступ до действительного expiry; hold/pause/expired не даёт. Обычная отмена не отнимает уже оплаченный срок. Возврат и отзыв учитываются по текущему Google subscription state. HTTP 410 от Google для известной старой подписки завершает доступ и помечает её retired; чужой токен не привязывается.

Частный планировщик хостинга должен запускать CLI `mobile_play_maintenance.php` минимум раз в сутки и сигнализировать о ненулевом exit. Он сверяет 30-дневное окно возвратов и подписки, включая hold. Запуск и мониторинг ещё не настроены. HTTP административного запуска нет. Ошибки новой/неподдержанной RTDN возвращают 503, чтобы сообщение не было молча потеряно; уведомления pendingRefundReview требуют отдельной ручной проверки владельцем, автоматическое решение о chargeback не реализовано. Не заявлять полностью готовую эксплуатацию без мониторинга этих случаев и отказов Google.

Релиз через build_telegram_web.ps1 -MobileApiOnly, deploy только штатным инструментом с backup/хешами/HTTPS и отдельным разрешением production. До этого не устанавливать `GOOGLE_PLAY_BILLING=true` в распространяемой сборке. build_phone_apk.ps1 требует GoogleWebClientId для billing. Новая Android-версия координируется с задачей рекламы, которая меняет общий pubspec.

## Матрица приёмки Google — не выполнена

Нужны согласованный license tester, активные товары и внутренний тестовый выпуск с Billing. Только Google test instruments; при появлении обычной карты остановиться без оплаты.

1. Google-вход/привязка и восстановление того же профиля после переустановки.
2. Каждый пакет: локальная цена совпадает с Play, test approval, точное количество, повторная доставка без удвоения, повторная покупка после consume.
3. Cancel и test decline: ноль выдачи; pending approve/decline и перезапуск во время pending.
4. Потеря сети после оплаты и после выдачи до consume/ack: restore/retry, одно начисление.
5. Plus weekly: ack, accelerated renewal, cancel с сохранением срока, expiry, grace/hold/recover/revoke. Проверять сервер при закрытом приложении через RTDN.
6. Полный/частичный тестовый refund, повтор/обратный порядок RTDN, сверка пропущенного события планировщиком. Отдельно проверить Google HTTP 410 старой подписки.
7. Поддельная подпись/audience/email/package/subscription отклоняется; Google test notification проходит.
8. Физический телефон, поддерживаемый детский/Family Link сценарий с родителем, без настоящего списания. Нажатие текста «попросите родителя» не является проверкой возраста или юридическим согласием.

Важно: family payment method не оплачивает subscriptions; purchase requests без семейного метода не поддерживают non-prepaid subscriptions. Поэтому текущий auto-renewing Plus нельзя обещать всем детским аккаунтам. Предоплаченный Plus либо разовый срок — возможная отдельная продуктовая доработка, не принята пользователем.

## Передача для IARC, Data safety и privacy

Разовые покупки фиксированных количеств виртуальных кристаллов и недельная подписка, без случайных платных наград/loot boxes. Деньги проводит Google Play. Приложение/сервер не получают номер банковской карты. Клиент передаёт серверу purchase token и product ID; Google получает SHA-256 внутреннего игрового ID, сервер хранит hash токена, зашифрованный токен, связанный профиль, дату/товар/срок/данные выдачи и возврата. Это история покупок, привязанная к профилю; после включения должно быть отражено в декларациях и privacy для функциональности/проверки покупки. Google sub используется для восстановления профиля. Срок хранения и обработку удаления платёжного ledger согласовать с владельцем и задачей удаления; новые таблицы не добавлены. Не отмечать новые потоки как уже включённые: код не опубликован, каталог/Cloud не настроены, Google license tests не пройдены. Формы этой задачей не менялись.

## Первичные источники (проверены 09.10.2026)
- https://support.google.com/cloud/answer/15549049 — допустимый User support email (текущий Google-аккаунт или управляемая группа).
- https://developer.android.com/google/play/billing/price-changes — новые цены не переводят автоматически существующих подписчиков.
- https://support.google.com/googleplay/android-developer/answer/6062777 — аккаунт издателя автоматически считается license tester; остальные задаются списком/группой.
- https://developer.android.com/google/play/billing/backend
- https://developer.android.com/google/play/billing/rtdn-reference
- https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.productsv2
- https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.voidedpurchases/list
- https://developers.google.com/android-publisher/getting_started
- https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions
- https://developer.android.com/google/play/billing/test
- https://support.google.com/googleplay/android-developer/answer/9893335
- https://support.google.com/googleplay/answer/6294544
- https://support.google.com/googleplay/answer/7039872


## Публичная privacy — 09.10.2026 17:32 Minsk
Legal1.0.3 опубликован и проверен на https://untouch.fun/privacy/ и /delete-account/: 18+, будущие IDtoken/sub/recovery и purchase token/hash/зашифрованное хранение/RTDN/история покупок, Googleоплата без передачи номеракарты игре, weeklyauto-renew и отмена черезPlay. Состояние оплаты указаноoff до реального включения; при активации заменить этот срез. Data safety нужно сверить с purchasehistory, удаление/сроки минимального антифрод-хранения решить перед включением. Каталог, OAuth и Billing этой публикационной задачей не изменены. GooglePlay target18+ пока не сохранён из-за остановки UI-инструмента. [Отчёт](../memory/tasks/2026-10-09-adult-play-policy-publish.md).
