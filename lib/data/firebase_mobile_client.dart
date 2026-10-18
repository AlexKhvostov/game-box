import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

/// Only the Firebase identity is sent to Cloud Functions. Legacy installation
/// secrets remain local and cannot authorize any Firebase operation.
class FirebaseMobileClient extends http.BaseClient {
  FirebaseMobileClient({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  static const storagePrefix = 'firebase_android_v1_';
  static final endpoint = Uri.parse(
    const String.fromEnvironment(
      'FIREBASE_ANDROID_API',
      defaultValue:
          'https://europe-west1-game-box-b30d4.cloudfunctions.net/androidApi',
    ),
  );
  static Future<void>? _initializing;
  static Future<void> initialize() =>
      _initializing ??= _initialize().catchError((Object error) {
        _initializing = null;
        throw error;
      });
  static Future<void> _initialize() async {
    const emulator = String.fromEnvironment('FIREBASE_AUTH_EMULATOR_HOST');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: emulator.isNotEmpty
            ? FirebaseOptions(
                apiKey: 'fake-api-key',
                appId: DefaultFirebaseOptions.android.appId,
                messagingSenderId:
                    DefaultFirebaseOptions.android.messagingSenderId,
                projectId: 'demo-untouch-android',
              )
            : DefaultFirebaseOptions.currentPlatform,
      );
    }
    if (emulator.isNotEmpty) {
      final parts = emulator.split(':');
      await FirebaseAuth.instance.useAuthEmulator(
        parts[0],
        int.parse(parts[1]),
        automaticHostMapping: false,
      );
    }
    // Core/Auth/Remote Config work without enabling Analytics or ad consent.
  }

  Future<User> _user() async {
    await initialize();
    return FirebaseAuth.instance.currentUser ??
        (await FirebaseAuth.instance.signInAnonymously()).user!;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = jsonDecode(await request.finalize().bytesToString()) as Map;
    final payload = Map<String, dynamic>.from(body);
    try {
      var user = await _user();
      final action = payload['action'];
      if (action == 'google_link' || action == 'google_restore') {
        final credential = GoogleAuthProvider.credential(
          idToken: payload['idToken'] as String,
        );
        if (action == 'google_restore') {
          user = (await FirebaseAuth.instance.signInWithCredential(
            credential,
          )).user!;
        } else {
          try {
            user = (await user.linkWithCredential(credential)).user!;
          } on FirebaseAuthException catch (error) {
            if (error.code == 'credential-already-in-use' ||
                error.code == 'account-exists-with-different-credential') {
              return _error('google_profile_exists', 409);
            }
            if (error.code != 'provider-already-linked') rethrow;
          }
        }
      } else if (action == 'google_unlink') {
        // Keep this installation's Firebase UID and its energy; only remove
        // Google recovery. Repeating after a lost response is harmless.
        if (user.providerData.any((p) => p.providerId == 'google.com')) {
          user = await user.unlink('google.com');
        }
      }
      payload.remove('secret');
      payload.remove('installation');
      payload.remove('idToken');
      payload.remove('owner');
      final token = await user.getIdToken('$action'.startsWith('google_'));
      final response = await _client.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode == 409 &&
          response.body.contains('rules_changed')) {
        await (await SharedPreferences.getInstance()).setBool(
          'firebase_android_v1_force_config_fetch',
          true,
        );
      }
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
    } on FirebaseAuthException catch (error) {
      return _error(
        error.code == 'network-request-failed'
            ? 'connection_failed'
            : error.code == 'requires-recent-login'
            ? 'google_reauthentication_required'
            : 'google_token_invalid',
        401,
      );
    }
  }

  http.StreamedResponse _error(String code, int status) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'ok': false, 'error': code}))),
        status,
      );

  @override
  void close() => _client.close();
}
