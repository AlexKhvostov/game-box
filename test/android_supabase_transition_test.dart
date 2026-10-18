import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_box/data/android_firebase_config.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/supabase_mobile_client.dart';

const uid = '22345678-1234-4234-8234-123456789abc';
Map<String, dynamic> session() {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'sub': uid, 'exp': exp, 'role': 'authenticated'}),
        ),
      )
      .replaceAll('=', '');
  return {
    'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test-signature',
    'token_type': 'bearer',
    'refresh_token': 'test-refresh-token',
    'expires_in': 3600,
    'expires_at': exp,
    'user': {
      'id': uid,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': '',
      'is_anonymous': true,
      'app_metadata': {},
      'user_metadata': {},
      'identities': [],
      'created_at': '2026-10-16T12:00:00Z',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'replaying an owned run cannot create a replacement anonymous account',
    () async {
      var requests = 0;
      final sdk = SupabaseClient(
        'https://test.supabase.co',
        'public-test',
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 500);
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final transport = SupabaseMobileClient(supabase: sdk);
      final response = await transport.post(
        Uri.parse('https://unused.invalid'),
        body: jsonEncode({
          'action': 'round_start',
          'expectedOwner': 'supabase:$uid',
        }),
      );
      expect(response.statusCode, 409);
      expect(requests, 0);
      transport.close();
      await sdk.dispose();
    },
  );
  test('queued run cannot cross the current Supabase session owner', () async {
    final sdk = SupabaseClient(
      'https://test.supabase.co',
      'public-test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await sdk.auth.setInitialSession(jsonEncode(session()));
    var sent = 0;
    final client = SupabaseMobileClient(
      supabase: sdk,
      client: MockClient((_) async {
        sent++;
        return http.Response('{"ok":true}', 200);
      }),
    );
    final response = await client.post(
      Uri.parse('https://unused.invalid'),
      body: jsonEncode({
        'action': 'round_start',
        'expectedOwner': 'supabase:12345678-1234-4234-8234-123456789abc',
      }),
    );
    expect(response.statusCode, 409);
    expect(sent, 0);
    expect(jsonDecode(response.body)['error'], 'wallet_owner_changed');
    client.close();
    await sdk.dispose();
  });
  test(
    'Supabase owner namespace is strict and default server policy equals Remote Config asset',
    () {
      expect(MobileAccount.validOwner('supabase:$uid'), true);
      for (final owner in [
        'supabase:1',
        'supabase:../x',
        'supabase:$uid/other',
      ]) {
        expect(MobileAccount.validOwner(owner), false);
      }
      final client = jsonDecode(
        File(AndroidFirebaseConfig.assetPath).readAsStringSync(),
      );
      final server = jsonDecode(
        File(
          'supabase/functions/_shared/core/defaults.json',
        ).readAsStringSync(),
      );
      expect(server, client);
      expect(SupabaseMobileClient.storagePrefix, 'supabase_android_v1_');
    },
  );
  test(
    'transport uses Supabase bearer, strips legacy credentials and never calls SQL/Firebase endpoints',
    () async {
      final sdk = SupabaseClient(
        'https://test.supabase.co',
        'public-test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await sdk.auth.setInitialSession(jsonEncode(session()));
      var requests = 0;
      final transport = SupabaseMobileClient(
        supabase: sdk,
        client: MockClient((request) async {
          requests++;
          expect(request.url, SupabaseMobileClient.endpoint);
          expect(
            request.headers['Authorization'],
            'Bearer ${sdk.auth.currentSession!.accessToken}',
          );
          expect(jsonDecode(request.body), {
            'action': 'profile',
            'rulesRevision': 'test-revision',
          });
          return http.Response(
            jsonEncode({
              'ok': true,
              'profile': {'id': 'supabase:$uid'},
            }),
            200,
          );
        }),
      );
      final response = await transport.post(
        Uri.parse('https://unused.invalid/legacy'),
        body: jsonEncode({
          'action': 'profile',
          'rulesRevision': 'test-revision',
          'secret': 'old-secret',
          'installation': 'old-install',
          'owner': 'android:1',
          'idToken': 'old-token',
        }),
      );
      expect(response.statusCode, 200);
      expect(requests, 1);
      transport.close();
      await sdk.dispose();
    },
  );
  test(
    'Google unlink prepares verified email through server and keeps the same owner',
    () async {
      var prepared = false, unlinked = false;
      Map<String, dynamic> identity(String provider) => {
        'id': provider == 'google'
            ? '32345678-1234-4234-8234-123456789abc'
            : '42345678-1234-4234-8234-123456789abc',
        'identity_id': provider == 'google'
            ? '32345678-1234-4234-8234-123456789abc'
            : '42345678-1234-4234-8234-123456789abc',
        'user_id': uid,
        'provider': provider,
        'created_at': '2026-10-16T12:00:00Z',
        'identity_data': {
          'sub': uid,
          'email': 'test@example.invalid',
          'email_verified': true,
        },
      };
      Map<String, dynamic> user() => {
        ...session()['user'] as Map<String, dynamic>,
        'email': 'test@example.invalid',
        'is_anonymous': false,
        'identities': [
          if (!unlinked) identity('google'),
          if (prepared) identity('email'),
        ],
      };
      final sdk = SupabaseClient(
        'https://test.supabase.co',
        'public-test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          expect(
            request.method,
            isNot('PUT'),
            reason: 'No password or credential changes from the client',
          );
          if (request.method == 'DELETE') {
            unlinked = true;
            return http.Response('{}', 200);
          }
          return http.Response(
            jsonEncode(user()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }),
      );
      await sdk.auth.setInitialSession(
        jsonEncode({...session(), 'user': user()}),
      );
      final transport = SupabaseMobileClient(
        supabase: sdk,
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (body['action'] == 'prepare_google_unlink') {
            expect(body.keys.toList(), ['action']);
            prepared = true;
            return http.Response('{"ok":true,"ready":true}', 200);
          }
          expect(unlinked, true);
          expect(body['action'], 'google_unlink');
          return http.Response(
            jsonEncode({
              'ok': true,
              'profile': {'id': 'supabase:$uid', 'googleLinked': false},
            }),
            200,
          );
        }),
      );
      final response = await transport.post(
        Uri.parse('https://unused.invalid'),
        body: '{"action":"google_unlink"}',
      );
      expect(response.statusCode, 200);
      expect(prepared, true);
      expect(unlinked, true);
      expect(sdk.auth.currentUser!.id, uid);
      transport.close();
      await sdk.dispose();
    },
  );
  test(
    'simultaneous startup requests create one anonymous session and policy conflict forces RC fetch',
    () async {
      var signups = 0;
      final sdk = SupabaseClient(
        'https://test.supabase.co',
        'public-test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/auth/v1/signup');
          signups++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response(
            jsonEncode(session()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }),
      );
      final transport = SupabaseMobileClient(
        supabase: sdk,
        client: MockClient(
          (request) async =>
              http.Response('{"ok":false,"error":"rules_changed"}', 409),
        ),
      );
      await Future.wait(
        List.generate(
          5,
          (_) => transport.post(
            Uri.parse('https://unused.invalid'),
            body: '{"action":"guest"}',
          ),
        ),
      );
      expect(signups, 1);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          AndroidFirebaseConfig.forceFetchKey,
        ),
        true,
      );
      transport.close();
      await sdk.dispose();
    },
  );
}
