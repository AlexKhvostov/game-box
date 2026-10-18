# Android → Firebase: карта перехода

Состояние: 16.10.2026, реализация и проверки в работе. Основной отчёт:
[задача](../memory/tasks/2026-10-16-firebase-full-transition.md).

## Проверенные исходные факты

- База поведения: установленный APK1.0.140+141. Текущий рабочий каталог содержит важные tracked/untracked изменения; reset/clean не выполнялись.
- Firebase-проект `game-box-b30d4` существует, доступен в Chrome. Тариф **Spark**. Существующая `(default)` Firestore, регион `europe-west10`, содержит старые `scores`; её не меняем.
- Новая база Android: **`android-v1`**, без импорта старых игроков. Functions: `europe-west1` (близкий европейский регион, поддерживает выбранный runtime). Создание облачной базы/Functions ещё не выполнено. Нужен Blaze и конкретное согласование расходов; IAM/Play API могут потребовать отдельной настройки доступа.
- Huawei подключён по USB. Основная игра остановлена. Данные не очищались, старый сервер не менялся.
- В Firebase был только старый Android package com.boxgame.game_box.16.10.2026 зарегистрирован **Untouch Android / com.best4u.untouch**, AppID `1:332169968823:android:8307d5aa04c14140d4e132`; тариф Spark сохранён. SDK options обновлены по публичным настройкам консоли; старый client в google-services.json сохранён вместе с новым. Скачивание JSON из UI не сработало, параметры синхронизированы вручную по подтверждённым AppID/package/project.

## Полнота маршрутов

| Потребитель Android | Прежний путь | Новый путь | Проверка |
|---|---|---|---|
| Настройки запуска | `api/config.php`, общий кеш | `android_config_v1` Remote Config, отдельные defaults/cache | hash/тип/диапазоны, отказ сети, startup snapshot |
| Гость/профиль | `mobile.php guest/profile`, installation-secret | Firebase Auth anonymous + `androidApi`, `players/{uid}` | новый50, повтор регистрации, нельзя выбрать чужой UID |
| Google connect/restore/unlink | PHP Google token validation | Firebase Auth link/signIn/unlink + Admin getUser | сервер не доверяет client googleLinked; реальные Google/облако ещё впереди |
| Имя/приватность | `rename`, `google_privacy` | transaction + `names`, server wallet profile | уникальность имени, приватные поля не в scores |
| Энергия/бонус/жест/возраст/задачи/отзыв | wallet_operation | transaction + `players/{uid}/operations/{nonce}` | повтор/гонка/время/одноразовые задачи |
| Реклама | SDK reward → watch_ad | SDK reward → authenticated transaction |40, серверный cooldown; Yandex не предоставляет подписанную SSV-квитанцию |
| Покупка/restore/подписка | play_quote/verify/sync, MySQL receipts | immutable SKU + Play Developer REST + `purchases/{tokenHash}` | mock Google ответы, глобальный владелец/повтор/истечение; живой Play доступ ещё впереди |
| Старт/активация/отмена/завершение | round_* | `rounds/{hash(uid:nonce)}` + transaction | заморозка правил/стоимости, возврат до активации, повтор результата, серверное время |
| Личный результат/очередь | старый local/outbox | отдельный prefix `firebase_android_v1_`, owner-scoped delivery | старые балансы/операции/рекорды не читаются |
| Общий рейтинг | `api/scores.php` MySQL | authenticated `scores`, новая Firestore | один лучший результат/игрок, UTC-периоды, без старых данных |
| Приглашения | invites_state/bind/list | inviteCodes/invitations + cross-player transaction |5 завершённых игр + Google →60 пригласившему ровно один раз |
| Ссылка приглашения | `untouch.fun/a/CODE`, PHP redirect | новый Firebase Hosting `untouch-android-game-box-b30d4.web.app/a/CODE`, static redirect JS + App Links | Hosting/whitelist/Play referrer проверены локально; домен/OS verification после cloud deploy |
| Privacy/support/deletion страницы | старый Hostland сайт из Kotlin | privacy/delete-account на том же новом Firebase Hosting | статические страницы, ручной запрос удаления; сообщений агент не отправлял |
| Удаление аккаунта | в UI141/прежнем MobileAccount функции нет | не добавляется скрытым изменением backend | будущий отдельный продуктовый/Play пункт; не выдавать за готовую функцию |
| Старые daily/lives/crystals/rental/Telegram SKU | старые wallet операции | в Android EnergyV2 недоступны | Firebase отклоняет retired операции, Telegram остаётся прежним |

## Хранение и доступ

Все коллекции новой базы закрыты для прямого client SDK. HTTPS-функция проверяет Firebase ID token с отзывом, получает реального пользователя через Admin SDK и использует только его UID. Receipts, email и feedback не публикуются. Имя Google появляется в рейтинге только при прямом opt-in владельца; проверка приватности читает актуальный профиль поверх кеша результатов. Секретов в RC нет.

`players`, `players/{uid}/operations`, `players/{uid}/quotes`, `rounds`, `scores`, `names`, `inviteCodes`, `invitations`, `purchases`, `feedback` создаются только сервером. Схема не требует импорта SQL или копии старого Firestore. Обычный запуск не выполняет DDL/миграцию старой инфраструктуры.

Ключи старых SharedPreferences и SecureStorage сохраняются на месте. Новый backend использует собственные account credentials, energy snapshot, wallet journal, score history/outbox, invite delivery и Play journal. Игровые настройки звука/возраста/управления остаются на устройстве. Старую покупку новая база не считает новой только потому, что пользователь прислал token: Play должен подтвердить SKU/статус и obfuscated owner новой Firebase-идентичности. Восстановление старых несовместимых receipts требует отдельного доказательства владельца; SQL не импортируется.

## Remote Config

Единый JSON `android_config_v1` содержит полный snapshot и SHA256 от JSON `config`. Сервер получает **тот же default** из Admin Remote Config, запрещает conditionalValues для этого параметра и валидирует критические диапазоны. Клиент применяет только при запуске. Раунд хранит свою версию правил; quote хранит неизменяемые SKU-условия; бонус хранит дату/длительность начавшегося периода. Повтор nonce возвращает прежнюю квитанцию.

Fetch: timeout5с, minimum interval1ч; server template cache5мин. Нет автоматического включения Analytics или согласия на рекламу. Валидный отдельный cache/default позволяет открыть игру без Hostland. Новому аккаунту нельзя начислять серверные50 локально при отсутствии Firebase.

Версионируемые исходники: `firebase-android/functions/config/defaults.json`, `assets/config/android-firebase.json`, `firebase-android/remoteconfig.template.json`. Изменять их следует согласованно с генератором и проверками; реальную цену/валюту возвращает Google Play Billing.

## Ограничения, которые переход не устраняет

- Yandex MediaCodec на Huawei остаётся отдельным неисправленным дефектом. Награда не выдаётся за закрытие/таймер. Сервер может ограничить размер/частоту и повтор запроса, но без SSV не может криптографически доказать просмотр SDK-ролика.
- Проверка результата ограничивает время, типы, пределы и выданные усиления. Полная серверная симуляция траектории/античит не заявлена.
- Обычное удаление Android-приложения теряет анонимную идентичность. Для восстановления используется привязанный Google.
- Наличие исходников/эмулятора не означает развёрнутое облако. APK не заменяет141 до подтверждённой живой приёмки.
