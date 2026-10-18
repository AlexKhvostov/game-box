import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:game_box/data/google_identity.dart';
import 'package:game_box/data/mobile_account.dart';

class SignInPlatformFixture extends GoogleSignInPlatform {
  final initialized = Completer<void>();
  int initializations = 0;
  int authentications = 0;
  String? token = 'test-id-token';
  GoogleSignInException? failure;

  @override
  Future<void> init(InitParameters params) {
    initializations++;
    expect(params.serverClientId, NativeGoogleIdentity.clientId);
    return initialized.future;
  }

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    expect(initialized.isCompleted, true);
    authentications++;
    if (failure != null) throw failure!;
    return AuthenticationResults(
      user: const GoogleSignInUserData(
        email: 'fixture@example.invalid',
        id: '123',
      ),
      authenticationTokens: AuthenticationTokenData(idToken: token),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'identity wrappers share initialization and preserve sign-in failures',
    () async {
      final previous = GoogleSignInPlatform.instance;
      final platform = SignInPlatformFixture();
      GoogleSignInPlatform.instance = platform;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        GoogleSignInPlatform.instance = previous;
        debugDefaultTargetPlatformOverride = null;
      });
      final first = NativeGoogleIdentity(), second = NativeGoogleIdentity();
      if (!first.configured) {
        await expectLater(first.token(), throwsA(isA<MobileApiError>()));
        expect(platform.initializations, 0);
        return;
      }
      final a = first.token(), b = second.token();
      await Future<void>.delayed(Duration.zero);
      expect(platform.initializations, 1);
      expect(platform.authentications, 0);
      platform.initialized.complete();
      expect(await Future.wait([a, b]), ['test-id-token', 'test-id-token']);
      platform.failure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      await expectLater(
        NativeGoogleIdentity().token(),
        throwsA(isA<GoogleSignInException>()),
      );
      platform.failure = null;
      platform.token = null;
      await expectLater(
        second.token(),
        throwsA(
          isA<MobileApiError>().having(
            (e) => e.code,
            'code',
            'google_token_missing',
          ),
        ),
      );
      platform.token = 'retry-id-token';
      expect(await first.token(), 'retry-id-token');
      expect(platform.initializations, 1);
    },
  );
}
