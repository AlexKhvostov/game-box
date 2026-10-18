import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// Remote Config needs Firebase Core, independently from game authorization.
/// No Firebase Auth session or Analytics consent is created here.
abstract final class RemoteConfigBootstrap {
  static Future<void>? _initializing;
  static Future<void> initialize() =>
      _initializing ??= _initialize().catchError((Object error) {
        _initializing = null;
        throw error;
      });
  static Future<void> _initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }
}
