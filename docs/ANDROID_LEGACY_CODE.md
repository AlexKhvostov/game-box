# Границы действующего и исторического кода

18.10.2026, продолжение исправлений F14–F16.

Основное приложение не содержит Firebase Auth, Firestore, Firebase Analytics и Cupertino Icons. Firebase Core/Remote Config остаются действующими. Старые native-адаптеры перенесены в отдельный пакет legacy/flutter/lib, со своим pubspec и lockfile. Для прежней цели подключение явное: initializeLegacyFirebase и FirestoreScoresSource. ScoresStore использует интерфейс LegacyScoresSource, Android по-прежнему использует MobileAccount/Supabase.

Прежние BalanceScreen/GamePlayScreen/freeze_sheet/leaderboard и вспомогательные виджеты находятся в legacy/flutter/fixtures. Они доступны историческим регрессионным тестам и исключены из дерева main. Активные energy_services сохраняют подтверждения покупок, Billing и обратную связь; energy_sheet содержит навигацию. Полоса обратной связи при0/100 имеет пустую заливку и приглушённый фон.

12 ресурсов из ANDROID_ASSET_EXCLUSIONS.json исключены из Android bundle; исходники сохранены. Пять неиспользуемых вариантов GameArt убраны. Проверка: tools/verify_android_cleanup.py --apk <путь>. Floors/ENABLE_FLOORS и постоянный hidden+20 сохранены по решениям пользователя. Общие HTTP-пути других целей не удалены как якобы мёртвые.

Серверный Supabase core теперь является исходным кодом, который редактируется и тестируется непосредственно. Старый текстовый генератор и патчи сохранены в legacy/supabase-generation для истории; запуск prepare:core только проверяет модули и не перезаписывает исправления. Убраны недостижимые прежние scores/publicRows и их cache.

Проверки: tools/test_android.ps1 с лицензированными шрифтами test/fixtures/fonts; flutter analyze lib test; отдельный flutter analyze lib fixtures в legacy/flutter; серверные npm test. Исторические Telegram fixtures проверяют прежнюю физику, новая Android-физика имеет отдельные тесты и физическую проверку.
