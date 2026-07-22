// File generated manually from android/app/google-services.json (Android first).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for Game Box.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS Firebase options are not configured yet.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBQ5iCD9OAotliddp-j0Dp-GfbeyqSKTsY',
    appId: '1:332169968823:android:a485d65569bb1269d4e132',
    messagingSenderId: '332169968823',
    projectId: 'game-box-b30d4',
    storageBucket: 'game-box-b30d4.firebasestorage.app',
  );
}
