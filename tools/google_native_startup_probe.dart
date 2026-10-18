// Isolated Android package only. Native Google UI, no profile or token transfer.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart' show GoogleSignInException;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/google_startup.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/google_identity.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/player_preferences.dart';

class _NativeIdentityProbe implements GoogleIdentity {
  final native = NativeGoogleIdentity();
  int calls = 0;
  String status = 'not-started';
  @override
  bool get configured => native.configured;
  @override
  Future<String> token() async {
    calls++;
    status = 'native-choosing';
    try {
      final token = await native.token();
      status = 'native-completed';
      return token;
    } on GoogleSignInException catch (error) {
      status = error.code.name;
      rethrow;
    } catch (_) {
      status = 'native-error';
      rethrow;
    }
  }
}

class _AccountProbe extends MobileAccount {
  _AccountProbe() {
    id = 'qa:isolated';
    nickname = 'Guest';
    wallet = {'tokens': 25, 'lives': 20};
  }
  @override
  Future<void> linkGoogle(GoogleIdentity identity) async {
    // Do not send the returned credential to a server or log it.
    await identity.token();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await SharedPreferences.getInstance();
  await storage.remove('google_startup_seen_v1');
  final preferences = PlayerPreferences();
  await preferences.load();
  final identity = _NativeIdentityProbe();
  final account = _AccountProbe();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8877);
  server.listen((request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'nativeCalls': identity.calls,
        'nativeStatus': identity.status,
        'startupSeen': preferences.googleStartupSeen,
        'guestNickname': account.nickname,
        'guestWallet': account.wallet,
        'googleLinked': account.googleLinked,
        'realServerRequests': 0,
      }),
    );
    await request.response.close();
  });
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MobileAccount>.value(value: account),
        ChangeNotifierProvider.value(value: preferences),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildGameTheme(),
        home: GoogleStartupGate(
          identity: identity,
          child: const Scaffold(
            body: Center(
              child: Text(
                'Isolated Google UI test\nNo account or token is sent to a server.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
