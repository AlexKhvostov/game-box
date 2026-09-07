# Telegram Canvas — критерии паритета с Android / Flutter

Чеклист приёмки: **Telegram Web (Canvas+JS)** vs **APK аркада**.

## Статус этапов

| Этап | Статус | Комментарий |
|------|--------|-------------|
| 1. Поле + физика + жесты | ✅ MVP | `game-world.js`, `renderer.js`, `main.js` |
| 2. HUD + info bar + старт | ✅ | секундомер MM:SS.mmm в info bar + strip под TG header |
| 3. Звук Web Audio | ✅ MVP | `audio.js` |
| 4. Экран результата | ✅ MVP | упрощённый overlay |
| 5. Telegram SDK + safe area | ✅ MVP | `telegram.js` |
| 6. Листы жизней / кристаллы | ✅ MVP | `sheets.js` — покупка жизней, daily, аренда |
| 7. Рейтинг | ✅ MVP | MySQL HostLand `api/scores.php` |
| 8. Share | ✅ MVP | `telegram.js` share в Telegram |
| 9. Stars | ✅ Бета | пакеты кристаллов + Plus 30 дней |

## Визуал поля

- [x] Размер поля до 380×380, скругление 18
- [x] Цвета темы: `#0E1419`, `#172028`, `#3DDC97`, `#FF5A5F`
- [x] Игрок, враги, тени, рамка, уголки
- [x] Near-miss вспышки
- [x] Impact burst при смерти
- [x] Шлем / неуязвимость после шлема
- [ ] Аниме-лицо (`showFace`) — порт есть, по умолчанию выкл
- [ ] Пульс полоски скорости при высокой скорости (glow)

## Управление

- [x] 1-й палец — движение (delta)
- [x] 2-й палец — прыжок
- [x] Старт с idle по касанию
- [x] Касание работает на поле и touch-pad

## HUD

- [x] Жизни, кристаллы, рекорд
- [x] Таймеры аренды прыжка / шлема
- [x] Открытие листов (жизни, кристаллы, рейтинг) по тапу
- [ ] CrystalCubeIcon / RestingCubeIcon — пока CSS-заглушки

## Экономика

- [x] localStorage: lives, tokens, bestTime, daily, rentals
- [x] Stars: пакеты кристаллов + Plus 30 дней (`api/payments.php`, webhook)
- [ ] Полный паритет EconomyStore (earn in-run, реальная реклама)

## Конфиг

- [x] `telegram-web/config/gameplay-config.json` — дефолты как Flutter RC
- [ ] Общий JSON для APK + Web (следующий рефакторинг)

## Сборка

```powershell
powershell -File tools/build_telegram_web.ps1
```

Результат: `build/web/` и `releases/untouch-telegram-web.zip`

## Side-by-side тест

1. Открыть APK аркаду и Telegram Web рядом.
2. Сравнить: поле, скорость разгона, жесты, звук, HUD цифры.
3. Зафиксировать расхождения в этом файле.
