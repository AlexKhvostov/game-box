# Реклама и платежи

Документ для менеджера: **баннерная и rewarded-реклама**, **покупки кристалов**, **подписка Boost**.  
Формат: шаги, что нужно от вас, где это взять.

См. также: [ANALYTICS_AND_ADMIN.md](ANALYTICS_AND_ADMIN.md) · [GOOGLE_PLAY_PUBLISH.md](GOOGLE_PLAY_PUBLISH.md) · [FIREBASE_SETUP.md](FIREBASE_SETUP.md) · [GAMEPLAY_ADMIN.md](GAMEPLAY_ADMIN.md)

---

## 1. Текущее состояние Untouch

| Функция в UI | Сейчас | Цель |
|--------------|--------|------|
| Earn → «Смотреть рекламу» | Заглушка / локальная награда | Реальная **rewarded** реклама → кристаллы |
| Баннер | Нет | Опционально: маленький баннер вне активного геймплея (например, в шитах) |
| Interstitial (полноэкран) | Нет | Осторожно; в гиперказуале легко раздражает — не приоритет MVP |
| Магазин кристалов (Shop) | Цены-заглушки | Реальные **IAP** через Google Play |
| Boost | Локальный preview без списания | Реальная **подписка** Play Billing (`$1 / week`) |

Package приложения: `com.boxgame.game_box`.

---

## 2. Что нужно от вас — сводная таблица

### Реклама (AdMob)

| Что нужно от вас | Зачем | Где взять |
|------------------|-------|-----------|
| Аккаунт Google (лучше тот же, что Play Console) | Вход в AdMob | [ads.google.com](https://ads.google.com/) или [admob.google.com](https://admob.google.com/) |
| Аккаунт **AdMob** (одобрение может занять время) | Показ рекламы и выплаты | Зарегистрироваться в AdMob, указать платежные данные |
| Приложение добавлено в AdMob | Привязка к `com.boxgame.game_box` | AdMob → Apps → Add app → Android → package name |
| **App ID** AdMob | В манифест / Flutter | AdMob → Apps → ваше приложение → App ID (`ca-app-pub-XXXX~YYYY`) |
| **Ad unit IDs** | Баннер и Rewarded отдельно | AdMob → Ad units → Create (Banner, Rewarded) |
| Решение: где показывать баннер | Продукт | Рекомендация ниже |
| Privacy Policy URL с блоком про рекламу | Требование Play / GDPR | См. [GOOGLE_PLAY_PUBLISH.md](GOOGLE_PLAY_PUBLISH.md) |
| (Европа) согласие на персонализацию рекламы | UMP / GDPR | Включается SDK Google UMP вместе с Mobile Ads |

**Что передать разработчику:**  
`App ID`, `Banner ad unit id`, `Rewarded ad unit id`.  
Для разработки сначала используют **тестовые** id Google (их даёт документация) — боевые id только в релизе.

Тестовые id (официальные Google, можно использовать до своих):  
см. [Google Mobile Ads — test ads](https://developers.google.com/admob/android/test-ads).

### Платежи (Google Play Billing)

| Что нужно от вас | Зачем | Где взять |
|------------------|-------|-----------|
| Аккаунт **Google Play Console** | Магазин и биллинг | [play.google.com/console](https://play.google.com/console) — разовый взнос разработчика |
| Приложение создано в Console | Привязка package | Create app → `com.boxgame.game_box` |
| Продукты IAP (consumable) | Пакеты кристалов | Monetize → Products → In-app products |
| Подписка Boost | Еженедельная Boost ($1) | Monetize → Products → Subscriptions |
| Лицензии тестировщиков | Купить без реальных денег | Setup → License testing → добавить ваши Gmail |
| Закрытый/внутренний тест-трек с AAB | Billing работает только с установленным из Play (или лицензией) | См. документ про публикацию |
| Цены и валюты | Витрина | Задаёте в Console при создании продукта |

**Что передать разработчику:**  
Product IDs, например:

- `crystals_handful`, `crystals_stack`, `crystals_chest`, `crystals_vault`  
- `boost_weekly` (подписка, $1 / week)

Имена должны **точно** совпасть с кодом.

---

## 3. Реклама — как сделать (по шагам)

### 3.1. Типы рекламы в Game Box

| Тип | Что это | Куда в нашей игре |
|-----|---------|-------------------|
| **Rewarded** | Пользователь смотрит ролик → получает награду | Вкладка Earn → «Смотреть рекламу»; опционально «жизнь за рекламу» |
| **Banner** | Полоска 320×50 и т.п. | Низ экрана в меню/шитах; **не** поверх поля во время dodge |
| **Interstitial** | Полный экран между действиями | Только если очень редко (например, каждый N-й заход в магазин) — не в MVP |

### 3.2. Регистрация AdMob (вы)

1. Открыть [admob.google.com](https://admob.google.com/).  
2. Создать аккаунт / принять условия.  
3. Apps → Add app → Android.  
4. Package: `com.boxgame.game_box` (как в проекте).  
5. Скопировать **App ID**.  
6. Ad units → Create:  
   - Rewarded — имя `earn_rewarded`;  
   - Banner — имя `sheets_banner` (если решите делать баннер).  
7. Прислать id разработчику.

Пока приложение не в Play, AdMob может ограничивать «реальный» трафик — для разработки хватает тестовых объявлений.

### 3.3. В приложении (разработка)

1. Пакет Flutter: `google_mobile_ads` (официальный).  
2. Прописать App ID в AndroidManifest.  
3. Rewarded: загрузить → показать → по callback `onUserEarnedReward` начислить кристаллы через `EconomyStore`.  
4. Banner: `BannerAd` внизу шита (не на поле).  
5. Подключить **UMP** (Consent) для EU — [руководство Google](https://developers.google.com/admob/flutter/eu-consent).  
6. События аналитики: `ad_reward_shown`, `ad_reward_completed`, `ad_banner_impression` (см. [ANALYTICS_AND_ADMIN.md](ANALYTICS_AND_ADMIN.md)).

### 3.4. Правила продукта (важно для удержания)

- Rewarded — только по желанию игрока (кнопка).  
- Баннер не перекрывает тач во время игры.  
- Не крутить interstitial после каждого поражения.  
- Boost / «без рекламы» — отключает баннеры и (по решению) не предлагает rewarded, либо оставляет rewarded как опциональный заработок.

### 3.5. Приёмка рекламы (вы)

1. Сборка с **тестовыми** ad unit — ролик показывается, кристаллы капают один раз за просмотр.  
2. Повторный тап без просмотра — не даёт награду.  
3. На реальном устройстве с вашим Gmail в test devices — нет «Invalid request» в логах.

---

## 4. Платежи — как сделать (по шагам)

### 4.1. Два вида покупок

| Вид | Play Console | В Game Box |
|-----|--------------|------------|
| **Consumable (расходуемый)** | In-app product | Пакеты кристалов в Shop |
| **Subscription** | Subscription | Boost (неделя, $1), автопродление |

### 4.2. Создание продуктов (вы в Play Console)

1. [Play Console](https://play.google.com/console) → ваше приложение.  
2. Monetize with Play → Products → **In-app products** → Create:  
   - Product ID: например `crystals_handful`  
   - Name / description RU и EN  
   - Price  
   - Status: Active  
3. **Subscriptions** → Create:  
   - Product ID: `boost_weekly` (неделя, $1)  
   - Base plan: период 1 month, цена  
   - Benefits в тексте: без рекламы, Daily ×2  

Пока приложение не загружено хотя бы во **Internal testing**, часть настроек Billing может быть недоступна — см. [GOOGLE_PLAY_PUBLISH.md](GOOGLE_PLAY_PUBLISH.md).

### 4.3. Тестовые покупки (вы)

1. Play Console → Setup → **License testing**.  
2. Добавить Gmail телефонов, с которых тестируете.  
3. Установить билд из Internal testing (не произвольный APK с компьютера — иначе подписка часто не находится).  
4. Покупка пройдёт как тестовая (деньги не спишутся / сразу refund-поведение по правилам Google).

Документация: [License testing](https://support.google.com/googleplay/android-developer/answer/6062777).

### 4.4. В приложении (разработка)

1. Пакет Flutter: `in_app_purchase` (официальный).  
2. Загрузка списка продуктов по Product ID.  
3. Покупка пакета → после успешного `PurchaseDetails` начислить кристаллы, **acknowledge** покупку.  
4. Boost: вместо `activatePremiumPreview()` — реальная подписка; статус читать при старте (`restore` / query purchases).  
5. Отмена Boost — через Google Play подписки (кнопка в приложении ведёт в управление подпиской + локальный статус).  
6. (Позже) серверная проверка purchase token через Google Play Developer API + Cloud Function — против читов.

Связка с текущим кодом: `EconomyStore`, `ShopCatalog`, шит кристалов / Boost manage.

### 4.5. Приёмка платежей (вы)

1. Тестовый аккаунт видит цены из Play.  
2. Покупка пакета → кристаллы на балансе, повторная покупка того же consumable возможна.  
3. Оформление Boost → бейдж «Boost активен», Daily ×2.  
4. Отмена в Play → после обновления статуса Boost выключается.  
5. Переустановка → restore подписки работает.

---

## 5. Порядок внедрения (рекомендация)

```text
1. AdMob аккаунт + тестовый Rewarded в Earn
2. Internal testing в Play + License testers
3. IAP пакеты кристалов
4. Подписка Boost (заменить preview)
5. Баннер (если всё ещё нужен) + отключение рекламы для Boost
6. Боевые ad unit ids + Privacy / Data safety в Play
```

Не блокировать релиз магазина отсутствием баннера: **rewarded + IAP** важнее.

---

## 6. Юридическое и модерация Play (кратко)

От вас / юриста / шаблона политики:

- В Privacy Policy: рекламные SDK, идентификаторы устройства, покупки.  
- В Play Console → App content → **Advertising ID**, **Data safety**.  
- Если есть подписка — описать период, цену, как отменить (требование магазинов).

Где сделать политику: любой хостинг страницы (GitHub Pages, Notion public, свой сайт). URL понадобится и в витрине Play.

---

## 7. Что сделать вам прямо сейчас

1. Решить: реклама через **AdMob** (стандарт для Android) — да.  
2. Завести / проверить [AdMob](https://admob.google.com/) и [Play Console](https://play.google.com/console).  
3. Создать приложение в Play с package `com.boxgame.game_box` (если ещё нет).  
4. Когда будете готовы к разработке: создать Rewarded ad unit (можно тестовый этап) и черновики Product ID для кристалов + `boost_weekly`.  
5. Передать разработчику: App ID, ad unit ids, product ids, список тестовых Gmail.
