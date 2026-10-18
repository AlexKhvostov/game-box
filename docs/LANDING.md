# Лендинг Untouch

## Неоновый лендинг — 13.10.2026 13:58 Europe/Minsk

Опубликована и проверена https://untouch.fun/ —1.0.67. Старый сайт1.0.52 сохранён:24 публичных файла/ZIP/SHA-256. Демо сразу сверху, квадратное поле, native Android темп/размеры и7 цветов с градиентами;4 кейса, Google Play closed test и App Store «Пока в разработке». Все6 больших изображений декодированы на домене; contain без обрезки, правильные пропорции скриншотов. FTPS12 изменённых файлов; пакет71 файл/966727байт и HTTPS build/entry files подтверждены; browser desktop/mobile и управление осмотрены. Основной Android/Telegram, юридические страницы и сервер не менялись. [Задача](../memory/tasks/2026-10-13-neon-landing.md).

Предыдущие публикации ниже — история, не актуальный статус.

## Публикация 06.10.2026

Актуальная 1.0.52 (`landing-v1.0.52_20261005_230321_367`) загружена на предоставленный FTPS в `/www` с исправленным логином. Реквизиты хранятся Windows DPAPI вне репозитория. Использован `tools/deploy_telegram_web.ps1`: резервная запись до загрузки, SHA-256 всех 19 переданных файлов подтверждены повторным чтением. Существующие `index.htm` и `cgi-bin` сохранены. Запись `predeploy-20261005_230830_333967/deployment.json` содержит `uploaded-and-verified`.

Домен пользователя — `untouch.fun`. На момент проверки он не разрешался через DNS с текущего компьютера; HTTPS-проверка release.json не выполнена из-за `Could not resolve host`. Файлы на хостинге проверены, публичную страницу и HTTPS-версию ещё требуется подтвердить после применения DNS.

06.10.2026. Источник: `telegram-web/landing/index.html`, стили `landing.css`. Отдельная страница `/landing/`, существующий корневой вход игры не изменён. Запуск — `https://t.me/UntouchGameBot/untouch` из `ADS_GROWTH.md`.

Страница: первый экран, интерактивное демо на три жизни, три причины играть, описание управления, два скриншота интерфейса, четыре бытовые ситуации, FAQ и кнопки Telegram. Только портретный режим игры. Без сторонних шрифтов, скриптов и счётчиков. Картинки в WebP, отложенная загрузка, размеры заданы. Учитывается reduced motion, есть ссылка к основному содержимому и видимый фокус клавиатуры.

## Демо LP7

### Удаление лишних кнопок LP15

В актуальной 1.0.52 удалены кнопки «Начать демо» и «Пауза». Старт — перетаскивание кубика или стрелки; после проигрыша сохраняется «Ещё попытку?». Автоматическая пауза при скрытии вкладки/потере фокуса/прокрутке и Escape сохранены, продолжение — движение кубика или стрелки. Вместе с этим в релиз включена текстовая правка LP14 о полноэкранном управлении основной игры. Не опубликовано.

### Текст об управлении LP14

По уточнению пользователя описание основной игры исправлено: область управления — весь экран. В блоке скриншотов, правилах и FAQ удалено указание на управление только под полем. Это редакционная правка лендинга, код основной игры и встроенного демо не менялся. Отдельная сборка 1.0.51, не опубликована.

### Актуальный запас LP13

По последнему решению пользователя возвращены три попытки. Счётчик, начальные и итоговые подписи обновлены; скрытый сброс по «Ещё» возвращает три жизни. Ключ localStorage v3 отделяет новый запас от прежней версии с пятью попытками. Ожидание, запуск движением, ускорение ×1,5 и центральный результат сохранены. Итоговая отдельная сборка 1.0.50 прошла браузерные проверки трёх проигрышей, однократного списания, сброса, перезагрузки, результата, неподвижности поля, управления и паузы; 19 файлов сайта/ZIP сверены с манифестом. Не опубликовано.

### Ожидание, запуск движением и результат LP11–LP12

Актуальная версия 1.0.49: до старта враги колеблются около исходных позиций, максимум ±8 по x и ±6 по y, без перемещения через поле. Нажатие или кнопка подготавливают управление; секундомер и движение врагов по направлению начинаются после перетаскивания кубика (порог 1 единица) либо стрелки. Повтор возвращает подготовленное поле с подсказкой, затем снова ожидает движения. Продолжение уже начатой паузы сохраняет попытку.

Множитель ускорения теперь 1,5: на 25% выше предыдущего 1,2, эффективное ускорение 13,5–22,5 единиц/с². Пять попыток и скрытый сброс сохранены. При проигрыше центральная карточка показывает результат в секундах и «Ещё попытку?»; при исчерпании попыток показывает лучший результат и переход в Telegram. Под текст и действия выделено постоянное место, поэтому наклонённое поле не смещается при смене состояния. Проверены ограниченная амплитуда ожидания, отсутствие отсчёта при удержании без движения, запуск мышью/стрелками/эмулированным касанием, пять проигрышей и положение поля до/после каждого, формат результата, сброс и перезагрузка. Четыре ширины страницы и SHA-256 19 файлов сайта/ZIP проверены. 1.0.48 сохранена как промежуточная сборка поведения ожидания; финальная 1.0.49 не опубликована.

### Ускорение LP10

По запросу пользователя ускорение врагов в демо увеличено на 20%: время для расчёта скорости GameWorld умножается на 1,2. Начальная скорость, спокойное движение до старта и фактический секундомер не меняются. При базовых ускорениях 9–15 эффективные значения — 10,8–18 единиц/с². Изменение только для демо, основная Mini App не меняется. Сборка 1.0.47 прошла браузерную проверку игрового цикла, пяти попыток, сброса, управления и паузы; файлы сайта и ZIP сверены с манифестом. Не опубликовано.

### Актуальные изменения LP9

Демо теперь даёт пять попыток. Нажатие на слово «Ещё» в главном h1 полностью сбрасывает попытки, лучший результат, время, состояние игры и локальное сохранение. У слова сохранён обычный текстовый курсор, нет стиля ссылки или кнопки; это временный скрытый сброс для просмотра лендинга. Новый ключ localStorage v2 отделяет запас пяти попыток от старых трёх.

В ожидании враги плавно движутся через tickIdle, игрок слегка покачивается, рядом показан SVG-силуэт пальца с движением в стороны. Подсказка пропадает при старте. Мерцание неуязвимого игрока отключено в демо-отрисовке, стартовая защита столкновений сохраняется. После проигрыша кнопка «Ещё попытка» расположена в центре поверх поля, после пятой попытки там же появляется ссылка Telegram. Поворот поля сохранён, кнопки повернуты обратно для удобного чтения. Финальная сборка 1.0.46; 1.0.45 сохранена как промежуточная, в ней при визуальной проверке замечена оставшаяся SVG-подсказка после старта, исправленная в 1.0.46. Публикации не было.

### Актуальное размещение LP8

Демо перенесено в наклонённое поле первого экрана; отдельный нижний блок удалён. Сохранены поворот −9°, сетка, орбиты и плашка-вызов; реальный игрок окрашен в зелёный цвет лендинга и имеет лицо. До старта слегка двигается только игрок, враги неподвижны. Нажатие на кубик запускает попытку и сразу захватывает перетаскивание; нажатие вне кубика в ожидании не запускает игру. Координаты касания и мыши переводятся обратной матрицей поворота, поэтому направление на экране совпадает с движением указателя. Отдельной нижней площадки управления больше нет. Стрелки работают при фокусе; Enter/пробел или кнопка позволяют начать без мыши. Три жизни, пауза, локальное сохранение и итоговая ссылка сохранены. Анимация ожидания отключается при reduced motion, скрытии вкладки и уходе поля из области просмотра.

Проверены запуск мышью и эмулированным касанием непосредственно по игроку, неподвижные враги до старта, движение врагов после старта и управление с учётом наклона. Итоговый релиз 1.0.44 проходит прежние проверки трёх жизней, паузы, перезагрузки, ссылок и адаптивной страницы. Публикация ожидает решения LP3.

Первый CTA ведёт к игре на странице. Демо использует текущие GameWorld и FieldRenderer, базовую конфигурацию поля, врагов и игрока; сборщик обновляет эти модули из исходников игры и ставит версию импортам. Экономика, покупки, способности и серверные API в демо не входят. Три столкновения расходуют три жизни, после последнего появляется «Продолжить в Telegram» со ссылкой на Mini App. Лучшее время показывается локально, не переносится в общий рейтинг.

Пробный запас сохраняется в localStorage этого браузера; перезагрузка начатой попытки расходует жизнь. Это ограничение знакомства, не серверная защита: другой браузер или очистка хранилища дадут новый запас. Управление: относительное движение пальца по полю или нижней площадке, мышь с зажатой кнопкой, стрелки при фокусе на поле. Пауза по кнопке, потере фокуса, скрытию вкладки, отмене касания или уходу поля из видимой области. На паузе и после исчерпания жизней анимация не работает.

Проверены три столкновения и однократное списание жизни, мышь, клавиатура, эмулированные касания, пауза и возобновление, пауза при прокрутке, расход прерванной попытки при перезагрузке, сохранение нулевого запаса и итоговая кнопка. Нет ошибок JS и запросов к игровым API или внешним сервисам. Проверка браузерная, физический телефон не проверялся.

## Содержание после LP4

Основной мотив: превратить свободные минуты в маленький игровой вызов. Аргументы: понятная цель и запуск из Telegram; улучшение собственного результата; сравнение попыток с друзьями и общий рейтинг. Личные рекорды описаны как прогресс внутри игры. Текст не обещает обучение мозга, снижение стресса, офлайн-режим, гарантированные награды или синхронный мультиплеер.

Ситуации связаны с конкретным действием: друзья показывают результат; сидящий пассажир играет между станциями; посетительница ждёт кофе; человек отдыхает на диване вечером. FAQ объясняет установку, портретную ориентацию, область управления и сравнение отдельных попыток. Количество CTA осталось прежним: 4 ссылки запуска.

Проверка LP4: браузер 320/390/768/1440, 4 истории, 3 причины, все изображения и ссылки, раскрытие и закрытие FAQ, отсутствие горизонтального переполнения и ошибок JS. Соотношение высоты/ширины двух скриншотов в вёрстке совпадает с исходниками с допуском 0,02. Пропорции телефонов на фото проверены визуально относительно рук и головы; исправлены три сцены с избыточно крупными устройствами. Это визуальная проверка сгенерированных фотографий, не физическое измерение аппарата.

## Изображения и происхождение

- `telegram-web/landing/assets/friends-portrait.webp`: друзья в кафе с видимым вертикальным экраном Untouch.
- `telegram-web/landing/assets/metro-portrait-v2.webp`: пассажир метро с видимым вертикальным экраном Untouch и исправленным масштабом корпуса. Предыдущий `metro-portrait.webp` сохранён как вариант.
- `telegram-web/landing/assets/coffee-portrait.webp`: ожидание заказа в кафе; портретный телефон обычного масштаба.
- `telegram-web/landing/assets/sofa-portrait.webp`: вечерний отдых на диване; портретный телефон обычного масштаба.
- `telegram-web/landing/assets/interface-home.webp`: стартовый интерфейс.
- `telegram-web/landing/assets/interface-game.webp`: интерфейс активной попытки.

Фото созданы встроенным ImageGen. Реальные скриншоты сняты с текущих исходников локально в браузере: 390×844 CSS-пикселей, масштаб 2. Конфигурация локальная, лицо включено; API подменён локальными ответами, реальные данные игроков и платежи не использовались. Это снимки браузера, не проверка физического телефона. В сгенерированных фото интерфейс воспроизведён по скриншоту как визуальный референс. Исходные PNG скриншотов и промежуточные варианты лежат в `tmp/landing/` и в релиз не входят.

## Групповой кадр и HTML-вызовы LP6

Групповая сцена переработана по замечанию пользователя: естественное положение предплечий у стола, участница играет на собственном вертикальном телефоне, друзья наблюдают и улыбаются. Без указательного жеста и демонстративного разворота телефона к зрителю. Новый вариант сохраняется отдельно как `telegram-web/landing/assets/friends-candid-v2.webp`.

Поверх трёх фото добавлены HTML-плашки: «10 секунд. Думаешь, легко?», «12 секунд. Дотянешь?», «15 секунд. А друг сможет?». Это игровые вызовы и цели для новых попыток; они не обозначают подтверждённые чужие рекорды, средние результаты или измеренную сложность. Текст не впечатывается в изображение: доступен для чтения и редактирования в HTML, шрифты подбираются для мобильного экрана.

Фото создано встроенным ImageGen. Первый референс — предыдущая групповая сцена, второй — настоящий игровой интерфейс.

### Финальный промпт

undefined

### Дополнительная коррекция направления экрана

Precise edit of Image 1. Preserve all three people, faces, clothes, cafe, body positions and warm light. Correct ONLY the woman's hands and phone orientation to be physically believable. The current screen faces viewer while woman sits behind it, so she cannot actually play. Lower her hands near the tabletop and tilt the small portrait smartphone almost flat with screen facing UPWARD and toward HER eyes, about 25 degrees above the table, like a normal person looking down to play. She looks down at its screen. Screen bottom/control area must be closest to the woman and top edge farther away from her; from camera across table game interface can naturally be seen obliquely and UPSIDE-DOWN. Do NOT force screen text to face camera. Game green cube and red rectangular obstacles remain recognizable. A natural two-handed grip around edges, left hand supports lower back, right thumb on control area nearest her, normal wrists and fingers, no pointing and no presenting device. Phone ordinary small 6.1-inch, not tablet. Keep the woman's portrait orientation game (long device axis directed away from her across table), no landscape game rotation. The viewer is observing real friends playing, not an advertisement demonstration. All remaining details and image dimensions unchanged. No overlays or watermark.

## Разные ракурсы LP5

По уточнению пользователя кафе и дом получили новые композиции: `telegram-web/landing/assets/coffee-topdown-v2.webp` — вид сверху на стойку, руки и работу бариста; `telegram-web/landing/assets/sofa-wide-v2.webp` — общий план спереди с человеком, диваном, пледом и лампой. Метро сохраняет ракурс через плечо, друзья — фронтальную групповую сцену. Прежние варианты сохранены. Телефоны вертикальные, нормального масштаба относительно рук; в широком домашнем кадре телефон является деталью сцены, экран не увеличен искусственно. Оба новых изображения созданы встроенным ImageGen.

### Кафе: вид сверху

Edit target Image 1 (woman waiting for coffee). Image 2 is actual Untouch portrait game UI reference. Completely change camera composition to distinguish this scene from over-shoulder lifestyle portraits: a direct TOP-DOWN BIRD'S-EYE photograph from above the cafe's wooden counter. Woman's olive cardigan sleeves, natural hands and partial lap occupy lower edge; NO face or shoulder close-up. She holds a small normal 6.1-inch phone upright in portrait orientation just above the counter, left hand supporting and right thumb playing in lower control area. Device realistic 14.7 by 7.1 cm, width narrower than palm, ratio about 2.05:1, not tablet; phone occupies only about 20% of image width. Recognizable game screen with green square hero and red rectangles using reference; tiny UI text need not be legible. Cafe context is visible: countertop grain, small order-number ticket WITHOUT readable text, napkin, a handbag strap near lower edge and barista preparing a cup at upper edge; her coffee is not served yet. Natural warm window light, documentary photography, tactile everyday details, broad table composition, not another shot from behind someone's head. Landscape 4:3 image, phone and hands crop-safe centered. Preserve same relaxed everyday story and authentic look. No overlays, logos, watermark or horizontal phone.

### Дом: широкий план

Edit target Image 1 (man enjoying Untouch at home). Supporting Image 2 is real Untouch game screen. Completely change camera position and composition: WIDE ENVIRONMENTAL LIFESTYLE photograph taken from the FRONT at a slightly elevated three-quarter angle across living room, not over shoulder. Show the same man comfortably curled up sideways on sage green sofa, full upper body and relaxed legs in frame, feet in socks, soft blanket over knees, warm lamp and side table/books/plant as contextual detail. This is an everyday comfortable evening moment, unposed, gentle concentration on game. Hold ordinary small 6.1-inch smartphone in portrait orientation near lap, left hand supporting and right thumb in lower touch area; screen angled upward so camera can see green cube and red rectangles, using reference screen. Phone normal 14.7 by 7.1 cm and ratio about 2.05:1, narrower than his palm, NOT giant, NOT a tablet. Person, sofa and lamp are primary subject; phone is a natural small contextual object, approximately 10% of image width, not enlarged for an advertisement. Keep all hands anatomically natural. Make couch, blanket and room clearly visible and visually different from cafe or metro. Landscape 4:3 photograph, composition crop-safe centered, warm evening light, realistic fabric and skin. No text overlays, logos, watermark. Do not show a close-up of head from behind.

## Промпты уточнения пропорций LP4

Новые фото кафе и дома сгенерированы встроенным ImageGen по референсу настоящего интерфейса. Затем размеры устройств скорректированы отдельными редактированиями; фото метро также отредактировано. Для каждого финального редактирования первое изображение — фото-сцена, второе — настоящий игровой скриншот.

### Кафе — коррекция размера телефона

Edit target Image 1 (woman in cafe with phone). Supporting reference Image 2 is real game UI. Correct ONLY smartphone physical size and hand grip, preserving face, cafe, light and overall photograph. The current smartphone is OVERSIZED. Shrink the phone by approximately 30 percent relative to the woman's existing hands and head. It must look like a normal 6.1-inch consumer phone, approximately 14.7 cm tall and 7.1 cm wide, NOT a tablet or oversized prop. Maintain portrait device aspect ratio about 2.05:1 and proper natural perspective. Repose fingers naturally to hold the smaller device with palm around its back; thumb rests in touch area below game board. Do not shrink or enlarge the hands or head. Preserve clearly visible recognizable Untouch dark UI, green cube, red rectangles, with all content fitting into smaller screen; exact tiny text need not be legible. Remove the takeaway cup immediately beside her because she is waiting for her order; keep cafe equipment and barista. Keep camera, composition, mood, photo dimensions, realistic proportions. No logos, overlays or watermark.

### Дома — коррекция размера телефона

Edit target Image 1 (man at home on sofa with smartphone). Supporting Image 2 is real game UI. Correct only smartphone scale and matching grip. Current phone is visibly too large. Shrink device by about 30 percent relative to his existing head and hands so it is a realistic 6.1-inch smartphone, approximately 14.7 cm tall and 7.1 cm wide, NOT a tablet or giant phone. Physical device portrait aspect ratio about 2.05:1. Keep hands and head unchanged in scale, repose fingers naturally around smaller device with right thumb on lower control area below game board. Keep recognizable Untouch dark screen, top timer, green smiling cube and red rectangular obstacles, fitting screen without stretching; tiny text need not be legible. Preserve man, sofa, room, cozy warm lighting, camera angle, photography and image dimensions. Screen upright vertical. No new objects, no overlays, no watermark.

### Метро — коррекция размера телефона

Edit target Image 1 (metro passenger playing). Supporting reference Image 2 is actual game UI. Correct only the oversized phone and matching hand grip. Reduce smartphone physical size by about 25 percent relative to existing hands and man's head. Realistic standard 6.1-inch phone about 14.7 cm by 7.1 cm, portrait aspect ratio about 2.05:1, naturally fits palm, NOT tablet. Do not resize the head or hands. Repose fingers naturally to hold smaller phone, with playing thumb BELOW the square game board in lower control area. Preserve recognizable Untouch dark portrait UI, green cube, red rectangular obstacles and timer, fitting screen without distortion. Tiny labels need not be readable. Keep metro, face, light, composition, photographic realism and wide image format. No overlays or watermark.

## Финальные промпты ImageGen

Оба вызова редактировали первоначальное lifestyle-фото и использовали второй картинкой настоящий `interface-game.png`.

### Друзья

Edit target Image 1, lifestyle photograph of three friends comparing scores at cafe. Image 2 is the actual Untouch game interface reference; reproduce its recognizable dark portrait UI, green smiling square player, coral red rectangular obstacles, top timer and resource row on the phone screens. Revise scene so at least one friend proudly holds a smartphone upright in PORTRAIT / VERTICAL orientation with screen facing camera and slightly toward friends; other friends look at the screen smiling, another holds their own portrait phone. Phone screen must be clearly visible and large enough to recognize this specific game, natural perspective, NOT a generic app. Preserve warm lighting, realistic faces, cafe, friendships and photographic style. Reframe a little wider if required to give hands and phone space; hands anatomically natural. All phones vertical. No overlaid text, no extra branding, no watermark. Keep landscape photo format. Crucial: visible portrait Untouch screen from reference, with green cube and RED RECTANGLES rather than circles or triangles.

### Метро

Edit target Image 1: young man enjoying a game seated in metro. Correct the smartphone to be held upright in PORTRAIT / VERTICAL orientation, since this game only plays vertically. Change camera viewpoint to a candid three-quarter over-shoulder side angle so both the relaxed man's face in profile and the phone SCREEN are clearly visible, tilted slightly to camera. Image 2 is the actual Untouch interface: faithfully reproduce recognizable portrait screen with dark background, green smiling square hero, bright coral RED RECTANGULAR obstacles and top timer/resource row. No circles or triangles as obstacles. Screen is a focal detail, visible enough to identify the game; not a generic app. Preserve metro, warm lighting, authentic photographic look, person's appearance and relaxed mood. Natural hands, no distorted fingers. Phone supported in one hand, other thumb playing below game field. Keep wide landscape image, no text overlays or watermark.

## 18.10.2026 01:19 Europe/Minsk — короткие Android приглашения
Добавлены только .htaccess, invite.php, .well-known/assetlinks.json и invite-route-release.json: https://untouch.fun/a/CODE принимает6/12, fixed302 наPlay с referrer=invite%3DCODE. При установленной167 AppLink открывает игру. Лендинг1.0.68/index SHA76756283… неизменён; не добавлялась обязательная страница/кнопка. Пакет releases/invite-domain-v1.0.1_20261017_220118_015574, FTPS backup/readback/HTTPS22 PASS. Реестр/привязка/бонусы остаются Supabase. [Итог](release-evidence/invite-short-20261018/FINAL.md).