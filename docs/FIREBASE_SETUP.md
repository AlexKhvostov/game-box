# Подключение Firebase (Game Box)

Firebase нужен для: анонимного входа, онлайн-рейтинга, профиля и **Remote Config** (параметры жизней/жетонов без нового билда).

## Что сделать вам (один раз)

1. Откройте [Firebase Console](https://console.firebase.google.com/) и создайте проект (например `game-box`).
2. Добавьте приложение **Android** с package name: `com.boxgame.game_box`  
   (он уже в нашем Flutter-проекте).
3. Скачайте `google-services.json` и положите в:
   `android/app/google-services.json`
4. В консоли включите:
   - **Authentication** → Anonymous
   - **Firestore Database** (режим production + правила позже)
   - **Remote Config**
5. Напишите мне: «Firebase проект готов» — допишу код (Auth, рейтинг, Remote Config) и закоммичу.

Либо установите FlutterFire CLI и выполните у себя:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Это создаст `lib/firebase_options.dart` автоматически.

## Зачем Remote Config

Там можно менять без обновления приложения в сторе:

- стартовые жизни, размер пака, цена в жетонах;
- Daily Reward и награда за 8 часов;
- позже — параметры сложности.

Удобно тестировать баланс «на живых» игроках.
