import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool ready = false;
  static String? uid;

  /// Инициализация Firebase + анонимный вход. При ошибке приложение работает офлайн.
  static Future<bool> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final cred = await FirebaseAuth.instance.signInAnonymously();
      uid = cred.user?.uid;
      ready = uid != null;
      debugPrint('Firebase ready, uid=$uid');
      return ready;
    } catch (e, st) {
      debugPrint('Firebase init failed: $e\n$st');
      ready = false;
      uid = null;
      return false;
    }
  }
}
