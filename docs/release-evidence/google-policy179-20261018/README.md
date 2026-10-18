# Доказательства аудита Google Play179

18.10.2026 19:06 Europe/Minsk. [Основной отчёт](../../reviews/GOOGLE_PLAY_COMPLIANCE_20261018.md).

- `aab-recheck.json`: повторная проверка неизменённого AAB179; прежний SHA256, package/version/target36/permissions/16KiB.
- `privacy-policy-console.txt`, `data-collection.txt`: полные видимые тексты Console с URL legal и старым описанием installation secret.
- `custom-privacy-browser.txt`: политика untouch.fun, успешно открытая обычным Chrome после двух timeout публичного HTTPS-запроса. Не считать timeout доказательством постоянной недоступности.
- `custom-deletion.txt`, `firebase-privacy.txt`, `firebase-deletion.txt`: публичные тексты страниц через HTTPS, без браузерных cookies или авторизации; параметры ответов в `public-links.json`/`custom-privacy-retry.json`.
- `app-access.txt`: сохранённое «Нет» при вопросе о закрытых разделах; инструкции отсутствуют.
- `target-audience.txt`:18+ и запрет скачивания известным несовершеннолетним; `content-rating.txt`: действующая сводка IARC.
- `data-safety-preview.txt`: полная развёрнутая сохранённая декларация, просмотр без изменения ответов.
- `publication-final.txt`: актуальные5изменений «ещё не отправленные на проверку». Аудит не выполнял новых попыток Send.
- `report-checks.json`:24 локальных ссылки существуют, семь основных текстовых доказательств содержат ожидаемые факты.

Исходники программы, данные игроков, публикация, разрешения и финансы не менялись. Предыдущие проверки подписи/совпадения с физическим APK и диагностика Send находятся в [Google Play179](../google-play179-20261018/README.md). Текущий аудит не повторял физический запуск и полные тесты кода.
