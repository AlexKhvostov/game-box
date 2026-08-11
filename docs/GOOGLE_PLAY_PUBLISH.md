# Публикация в Google Play

Документ для менеджера: **как выложить Untouch**, что нужно от вас и где это взять.  
Сейчас в проекте release-сборка ещё может быть подписана **debug-ключом** — для магазина так нельзя; нужен свой keystore и **AAB**.

Бренд (витрина / имя на устройстве): **Untouch**  
Package: `com.boxgame.game_box`  
См. также: [ADS_AND_BILLING.md](ADS_AND_BILLING.md) · [ANALYTICS_AND_ADMIN.md](ANALYTICS_AND_ADMIN.md) · [FIREBASE_SETUP.md](FIREBASE_SETUP.md) · [GAMEPLAY_ADMIN.md](GAMEPLAY_ADMIN.md)

---

## 1. Карта процесса

```text
Аккаунт разработчика
    → Создать приложение в Console
    → Иконка, описания, скриншоты, Privacy Policy
    → Подпись (keystore) + сборка AAB
    → Internal testing
    → (Закрытый тест) → Production
```

Рекламу и IAP удобно подключать уже на этапе **Internal testing** (см. [ADS_AND_BILLING.md](ADS_AND_BILLING.md)).

---

## 2. Что нужно от вас (чеклист)

| Что нужно от вас | Зачем | Где взять / сделать |
|------------------|-------|---------------------|
| Аккаунт **Google Play Console** | Публикация | [play.google.com/console](https://play.google.com/console) — разовый взнос (~$25, от Google) |
| Решение: имя приложения в сторе | Витрина | **Untouch** |
| Краткое и полное описание **RU и EN** | Витрина | Пишете вы (маркетинг) |
| Иконка 512×512 PNG | Витрина + адаптивная в приложении | Дизайн / Figma → экспорт |
| Feature graphic 1024×500 | Шапка витрины | Дизайн |
| Скриншоты телефона (минимум 2, лучше 4–8) | Витрина | С реального устройства или эмулятора |
| **Privacy Policy URL** (обязательно) | Модерация | Своя страница / Notion public / GitHub Pages |
| Контакты разработчика (email) | Витрина и поддержка | Ваш рабочий email |
| Возрастной рейтинг (опросник) | App content | Play Console → пройдите опрос IARC |
| Решение по странам / цене (бесплатно) | Дистрибуция | Обычно Free + IAP |
| Keystore / пароли подписи **или** поручить разработчику создать и отдать вам бэкап | Подпись AAB | См. раздел 4 — **хранить пароли у себя** |
| Список email тестировщиков | Internal / closed test | Gmail коллег и ваш |

Разработчик готовит техническую часть (AAB, манифест, версию).  
Вы — аккаунт, тексты, картинки, политику, нажатие «Отправить на проверку».

---

## 3. Play Console — первые шаги (вы)

1. Зайти в [Play Console](https://play.google.com/console), оплатить регистрацию разработчика, если ещё нет.  
2. **Create app** → название, язык по умолчанию, тип App, Free.  
3. Package name должен совпасть с проектом: **`com.boxgame.game_box`**  
   (его нельзя сменить после первой загрузки артефакта — проверьте до релиза).  
4. Заполнить Dashboard-чеклист:  
   - Store listing (описания, графики);  
   - App content (privacy, ads, target audience, news apps и т.д.);  
   - Data safety.  
5. Создать канал **Internal testing** (достаточно для Billing и закрытых проверок).

Официально: [Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152).

---

## 4. Подпись приложения (критично)

### 4.1. Зачем

Google Play принимает **Android App Bundle (.aab)**, подписанный вашим upload-ключом.  
APK с debug-подписью в Production не примут.

### 4.2. Что сделать

**Вариант А (рекомендуется):** разработчик генерирует keystore один раз, передаёт вам файлы и пароли в надёжное место (1Password / сейф). Вы храните бэкап.

**Вариант Б:** вы создаёте keystore сами по [документации Android](https://developer.android.com/studio/publish/app-signing) и отдаёте разработчику путь + пароли для CI/сборки.

Команда (пример, выполнит разработчик):

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

В проекте появятся (не коммитить в публичный git):

- `android/key.properties` (пароли, alias, путь к `.jks`);  
- настройка `signingConfigs` в `android/app/build.gradle.kts`.

Дополнительно в Play Console включить **Play App Signing** (Google хранит app signing key — стандарт сейчас).

### 4.3. Что нужно от вас на этом шаге

- Подтвердить, кто хранит keystore (лучше вы + копия у разработчика по договору).  
- Записать пароли вне чата Telegram.

---

## 5. Сборка для магазина (разработка)

```bash
flutter build appbundle --release
```

Файл: `build/app/outputs/bundle/release/app-release.aab`

Версия в [pubspec.yaml](../pubspec.yaml): `version: 1.0.0+1`  
- `1.0.0` → versionName (то, что видит пользователь);  
- `+1` → versionCode (целое, каждый аплоад в Play **больше** предыдущего).

Загрузка: Play Console → Testing → Internal testing → Create release → Upload AAB.

---

## 6. Материалы витрины (вы)

| Материал | Требование (ориентир) | Где загружать |
|----------|----------------------|---------------|
| App icon | 512×512 PNG, 32-bit | Store listing |
| Feature graphic | 1024×500 | Store listing |
| Phone screenshots | мин. 2; без тяжёлых рамок с чужим UI | Store listing |
| Short description | до ~80 символов | Store listing |
| Full description | до 4000 символов | Store listing |
| Privacy Policy | публичный HTTPS URL | App content + listing |

**Идеи для скриншотов Untouch:** поле с кубиком, HUD, экран результата с местом, Daily/кристаллы, рейтинг.

Локализации: минимум RU + EN (как в приложении).

---

## 7. App content и Data safety (вы + подсказки разработчика)

В Play Console → **App content** пройти анкеты:

| Анкета | Что указать (типично для Untouch) |
|--------|-------------------------------------|
| Privacy policy | Ваш URL |
| Ads | Да, если подключили AdMob; иначе Нет |
| Target audience | Возраст по факту контента (казуал без насилия 18+) |
| News app | Нет |
| Data safety | Какие данные собираете: Firebase Auth/Analytics, реклама, покупки |
| Financial features | Если есть IAP / подписка — отметить |

Если подключаете аналитику или рекламу — см. [ANALYTICS_AND_ADMIN.md](ANALYTICS_AND_ADMIN.md) и [ADS_AND_BILLING.md](ADS_AND_BILLING.md), чтобы анкета совпадала с реальностью.

---

## 8. Треки тестирования

| Трек | Для чего | Кто ставит |
|------|----------|------------|
| **Internal testing** | Быстро, до 100 тестеров, Billing | Вы добавляете email → ссылка на вступление |
| Closed testing | Шире бета | Списки / открытая ссылка с лимитом |
| Open testing | Публичная бета | Осторожно |
| **Production** | Все в Play | После проверки Google |

Рекомендация: неделю гонять Internal (вы + 2–3 человека), потом Production.

---

## 9. Чеклист перед Production

- [ ] AAB подписан release-ключом, versionCode увеличен  
- [ ] Установка с Internal test работает на телефоне ARM  
- [ ] Анонимный вход Firebase, рейтинг, Daily / жизни без крашей  
- [ ] Если есть реклама — тестовая/боевая настроена, Data safety обновлён  
- [ ] Если есть IAP — license testers проверили покупку  
- [ ] Privacy Policy открывается с телефона  
- [ ] Описания и скриншоты без чужих брендов / обмана  
- [ ] Контактный email рабочий  

Отправка: Production → Review → ждать статус (обычно от часов до нескольких дней).

---

## 10. Связка с Firebase / AdMob / Billing

| Сервис | Что проверить после первого AAB |
|--------|----------------------------------|
| Firebase | Тот же `google-services.json`, package совпадает |
| AdMob | Приложение связано с тем же package; после публикации в Play — «реальный» трафик |
| Play Billing | Продукты Active; тесты только с тестовых аккаунтов / лицензий |

---

## 11. Частые ошибки

| Ошибка | Как избежать |
|--------|--------------|
| Залили APK вместо AAB | `flutter build appbundle` |
| versionCode не вырос | Поднять `+N` в pubspec |
| Package другой, чем в Console | Только `com.boxgame.game_box` |
| Нет Privacy Policy | Сделать простую страницу до сабмита |
| Keystore потеряли | Бэкап сразу; с Play App Signing восстановление upload key возможно через поддержку, но больно |
| Billing «не видит продукты» | Ставить билд из Play Internal, не сырой APK |

---

## 12. Что сделать вам прямо сейчас

1. Завести / открыть [Play Console](https://play.google.com/console).  
2. Создать приложение с package **`com.boxgame.game_box`**.  
3. Набросать тексты RU/EN и заказать/сделать иконку + 4 скриншота.  
4. Опубликовать черновик Privacy Policy (можно короткий шаблон + доработать перед ads/analytics).  
5. Договориться с разработчиком: кто создаёт keystore и где лежит бэкап.  
6. Когда AAB готов — Internal testing → ваша установка по ссылке.
