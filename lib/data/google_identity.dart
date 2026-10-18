import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'mobile_account.dart';

abstract interface class GoogleIdentity {
  bool get configured;
  Future<String> token();
}

abstract interface class GoogleIdentitySession {
  Future<void> signOut();
}

class NativeGoogleIdentity implements GoogleIdentity, GoogleIdentitySession {
  static const clientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  // GoogleSignIn.instance is shared and must be initialized exactly once,
  // including when the profile screen creates another identity wrapper.
  static Future<void>? _initializing;
  static GoogleSignInAccount? _lastAccount;

  /// Supabase's native Google flow uses the provider access token as well as
  /// the ID token. Request only the existing profile/email identity scopes.
  static Future<String> supabaseAccessToken(String idToken) async {
    final account = _lastAccount;
    if (account == null || account.authentication.idToken != idToken) {
      throw const MobileApiError('google_token_missing');
    }
    const scopes = ['email', 'profile'];
    final authorization =
        await account.authorizationClient.authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);
    return authorization.accessToken;
  }

  @override
  bool get configured =>
      clientId.isNotEmpty &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> signOut() async {
    if (!configured) return;
    _initializing ??= GoogleSignIn.instance.initialize(
      serverClientId: clientId,
    );
    await _initializing;
    await GoogleSignIn.instance.signOut();
    _lastAccount = null;
  }

  /// Refresh display details without opening an account chooser.
  Future<String?> cachedToken() async {
    if (!configured) return null;
    _initializing ??= GoogleSignIn.instance.initialize(
      serverClientId: clientId,
    );
    await _initializing;
    final user = await GoogleSignIn.instance.attemptLightweightAuthentication();
    _lastAccount = user;
    return user?.authentication.idToken;
  }

  @override
  Future<String> token() async {
    if (!configured) throw const MobileApiError('google_not_configured');
    _initializing ??= GoogleSignIn.instance.initialize(
      serverClientId: clientId,
    );
    await _initializing;
    final user = await GoogleSignIn.instance.authenticate();
    _lastAccount = user;
    final token = user.authentication.idToken;
    if (token == null) throw const MobileApiError('google_token_missing');
    return token;
  }
}
