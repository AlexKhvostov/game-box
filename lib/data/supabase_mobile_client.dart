import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'android_firebase_config.dart';
import 'google_identity.dart';

/// Android transport. Authority comes only from the Supabase Auth session;
/// the old SQL installation secret and Firebase UID never cross this boundary.
class SupabaseMobileClient extends http.BaseClient {
  SupabaseMobileClient({http.Client? client, this.supabase})
    : _client = client ?? http.Client();
  final http.Client _client;
  final SupabaseClient? supabase;
  static const storagePrefix = 'supabase_android_v1_';
  static const projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://exinizzxqtjnysgibide.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_xq8__vWI0vNCMtWibUTG3A_CG262El1',
  );
  static final endpoint = Uri.parse('$projectUrl/functions/v1/android-api');
  static Future<void>? _initializing;
  static Future<User>? _creatingGuest;
  static Future<void> initialize() =>
      _initializing ??= _initialize().catchError((Object error) {
        _initializing = null;
        throw error;
      });
  static Future<void> _initialize() async {
    await Supabase.initialize(
      url: projectUrl,
      publishableKey: publishableKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: _SecureSupabaseSession(),
        detectSessionInUri: false,
      ),
      debug: false,
    );
  }

  Future<SupabaseClient> _sdk() async {
    if (supabase != null) return supabase!;
    await initialize();
    return Supabase.instance.client;
  }

  Future<User> _user(SupabaseClient sdk) async {
    if (sdk.auth.currentUser case final user?) return user;
    // Simultaneous startup requests must not create separate guest accounts.
    return _creatingGuest ??= (sdk.auth
        .signInAnonymously()
        .then((result) {
          final user = result.user;
          if (user == null) {
            throw const AuthException('anonymous_session_missing');
          }
          return user;
        })
        .whenComplete(() => _creatingGuest = null));
  }

  Future<void> _unlinkGoogle(SupabaseClient sdk, User user) async {
    final refreshed = (await sdk.auth.getUser()).user;
    if (refreshed == null || refreshed.id != user.id) {
      throw const AuthException('wallet_owner_changed');
    }
    final google = refreshed.identities
        ?.where((i) => i.provider == 'google')
        .firstOrNull;
    if (google == null) return;
    // Keep the UID/session. The server can add only the existing primary email
    // already verified by Google, through the standard Auth Admin endpoint.
    // No hidden password or experimental Auth flag is needed.
    if ((refreshed.identities?.length ?? 0) < 2) {
      final token = sdk.auth.currentSession?.accessToken;
      if (token == null) throw const AuthException('wallet_owner_changed');
      final response = await _client.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'apikey': publishableKey,
        },
        body: jsonEncode({'action': 'prepare_google_unlink'}),
      );
      final prepared = jsonDecode(response.body) as Map;
      if (response.statusCode != 200 || prepared['ready'] != true) {
        throw const AuthException('google_unlink_preparation_failed');
      }
    }
    final identities = await sdk.auth.getUserIdentities();
    if (identities.length < 2) {
      throw const AuthException('google_unlink_requires_device_identity');
    }
    await sdk.auth.unlinkIdentity(google);
    final confirmed = (await sdk.auth.getUser()).user;
    if (confirmed?.id != user.id ||
        confirmed!.identities!.any((i) => i.provider == 'google')) {
      throw const AuthException('google_unlink_unconfirmed');
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final raw = jsonDecode(await request.finalize().bytesToString()) as Map;
    final payload = Map<String, dynamic>.from(raw);
    final expectedOwner = payload['expectedOwner'];
    try {
      final sdk = await _sdk();
      if (expectedOwner != null && sdk.auth.currentUser == null) {
        return _error('wallet_owner_changed', 409);
      }
      var user = await _user(sdk);
      if (payload['expectedOwner'] != null &&
          payload['expectedOwner'] != 'supabase:${user.id}') {
        return _error('wallet_owner_changed', 409);
      }
      payload.remove('expectedOwner');
      final action = payload['action'];
      if (action == 'google_link' || action == 'google_restore') {
        final idToken = payload['idToken'] as String;
        final accessToken = await NativeGoogleIdentity.supabaseAccessToken(
          idToken,
        );
        if (action == 'google_restore') {
          user = (await sdk.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          )).user!;
        } else {
          try {
            user = (await sdk.auth.linkIdentityWithIdToken(
              provider: OAuthProvider.google,
              idToken: idToken,
              accessToken: accessToken,
            )).user!;
          } on AuthException catch (error) {
            if (error.code == 'identity_already_exists' ||
                error.code == 'email_exists') {
              return _error('google_profile_exists', 409);
            }
            rethrow;
          }
        }
      } else if (action == 'google_unlink') {
        await _unlinkGoogle(sdk, user);
      }
      for (final key in [
        'secret',
        'installation',
        'idToken',
        'accessToken',
        'owner',
      ]) {
        payload.remove(key);
      }
      var session = sdk.auth.currentSession;
      if (session?.isExpired == true) {
        session = (await sdk.auth.refreshSession()).session;
      }
      if (session == null) return _error('unauthorized', 401);
      if (expectedOwner != null &&
          expectedOwner != 'supabase:${session.user.id}') {
        return _error('wallet_owner_changed', 409);
      }
      final response = await _client.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': publishableKey,
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode == 409 &&
          response.body.contains('rules_changed')) {
        await (await SharedPreferences.getInstance()).setBool(
          AndroidFirebaseConfig.forceFetchKey,
          true,
        );
      }
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
    } on AuthException catch (error) {
      const preserved = {
        'google_unlink_requires_device_identity',
        'google_unlink_preparation_failed',
        'wallet_owner_changed',
        'google_unlink_unconfirmed',
      };
      final code = preserved.contains(error.message)
          ? error.message
          : 'google_token_invalid';
      return _error(code, 401);
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

class _SecureSupabaseSession extends LocalStorage {
  const _SecureSupabaseSession();
  static const _storage = FlutterSecureStorage();
  static const _key = '${SupabaseMobileClient.storagePrefix}auth_session';
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => await _storage.read(key: _key) != null;
  @override
  Future<String?> accessToken() => _storage.read(key: _key);
  @override
  Future<void> persistSession(String value) =>
      _storage.write(key: _key, value: value);
  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}
