import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/google_startup.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/google_identity.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_viewport.dart';

class FixtureIdentity implements GoogleIdentity {
  @override
  bool configured = true;
  Object? failure;
  Completer<String>? pending;
  int calls = 0;
  @override
  Future<String> token() async {
    calls++;
    if (failure != null) throw failure!;
    return pending == null ? 'fixture-token' : pending!.future;
  }
}

class Vault implements AccountVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class FixtureAccount extends MobileAccount {
  FixtureAccount({bool online = true}) : super(mayUseOnline: () => online) {
    id = 'android:1';
    nickname = 'Guest';
    wallet = {'tokens': 23};
  }
  String? failure;
  int links = 0, restores = 0;
  @override
  Future<void> linkGoogle(GoogleIdentity google) async {
    links++;
    await google.token();
    if (failure != null) throw MobileApiError(failure!);
    googleLinked = true;
    notifyListeners();
  }

  @override
  Future<void> restoreGoogle(GoogleIdentity google) async {
    restores++;
    await google.token();
    id = 'android:2';
    nickname = 'Returning';
    googleLinked = true;
    notifyListeners();
  }
}

const dialog = ValueKey('google-startup-dialog');
const connect = ValueKey('google-startup-connect');
const skip = ValueKey('google-startup-skip');
const boundary = ValueKey('startup-qa-boundary');

Future<PlayerPreferences> mount(
  WidgetTester tester, {
  required MobileAccount account,
  required GoogleIdentity identity,
  String language = 'ru',
  Size size = const Size(390, 844),
  double textScale = 1,
  bool enabled = true,
  Map<String, Object> initial = const {},
}) async {
  await tester.pumpWidget(const SizedBox());
  SharedPreferences.setMockInitialValues(initial);
  final preferences = PlayerPreferences();
  await preferences.load();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MobileAccount>.value(value: account),
        ChangeNotifierProvider.value(value: preferences),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildGameTheme(),
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: GameViewport(child: child!),
          ),
          home: GoogleStartupGate(
            enabled: enabled,
            identity: identity,
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const ValueKey('fixture-play'),
                  onPressed: () {},
                  child: const Text('Play'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return preferences;
}

Future<void> screenshot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('STARTUP_VISUAL_QA')) return;
  final render = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundary),
  );
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      'docs/release-evidence/google-startup-20261013/$name.png',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('STARTUP_VISUAL_QA')) return;
    for (final font in {
      'Roboto': 'C:/Windows/Fonts/segoeui.ttf',
      'MaterialIcons':
          'C:/Users/alexe/develop/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(font.key);
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File(font.value).readAsBytes()),
        ),
      );
      await loader.load();
    }
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('direct chooser persists once; cancellation preserves guest', (
    tester,
  ) async {
    final account = FixtureAccount();
    final identity = FixtureIdentity()
      ..failure = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
    final prefs = await mount(tester, account: account, identity: identity);
    expect(find.byKey(dialog), findsNothing);
    expect(find.byKey(connect), findsNothing);
    expect(prefs.googleStartupSeen, true);
    final disk = await SharedPreferences.getInstance();
    expect(disk.getBool('google_startup_seen_v1'), true);
    expect(account.id, 'android:1');
    expect(account.wallet!['tokens'], 23);
    expect(account.googleLinked, false);
    expect(identity.calls, 1);
    account.notifyListeners();
    await tester.pumpAndSettle();
    expect(identity.calls, 1);
    await mount(
      tester,
      account: account,
      identity: identity,
      initial: {'google_startup_seen_v1': true},
    );
    expect(identity.calls, 1);
  });

  for (final scenario in ['linked', 'unconfigured', 'disabled', 'offline']) {
    testWidgets('direct chooser skips $scenario', (tester) async {
      final account = FixtureAccount(online: scenario != 'offline')
        ..googleLinked = scenario == 'linked';
      final identity = FixtureIdentity()
        ..configured = scenario != 'unconfigured';
      final prefs = await mount(
        tester,
        account: account,
        identity: identity,
        enabled: scenario != 'disabled',
      );
      expect(identity.calls, 0);
      expect(prefs.googleStartupSeen, false);
      expect(find.byKey(dialog), findsNothing);
    });
  }

  testWidgets('ready notifications call chooser exactly once', (tester) async {
    final account = FixtureAccount()
      ..id = null
      ..busy = true;
    final identity = FixtureIdentity()..pending = Completer<String>();
    await mount(tester, account: account, identity: identity);
    expect(identity.calls, 0);
    account.id = 'android:1';
    account.busy = false;
    account.notifyListeners();
    account.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(identity.calls, 1);
    expect(find.byKey(dialog), findsNothing);
    expect(
      find.byKey(const ValueKey('google-startup-progress')),
      findsOneWidget,
    );
    identity.pending!.complete('fixture-token');
    await tester.pumpAndSettle();
    expect(account.googleLinked, true);
    expect(find.byKey(const ValueKey('google-startup-progress')), findsNothing);
  });

  testWidgets('late response never interrupts a user interaction', (
    tester,
  ) async {
    final account = FixtureAccount()..id = null;
    final identity = FixtureIdentity();
    final prefs = await mount(tester, account: account, identity: identity);
    await tester.tap(find.byKey(const ValueKey('fixture-play')));
    account.id = 'android:1';
    account.notifyListeners();
    await tester.pumpAndSettle();
    expect(identity.calls, 0);
    expect(prefs.googleStartupSeen, false);
    await mount(tester, account: account, identity: identity);
    expect(identity.calls, 1);
  });

  testWidgets('delayed linked profile never invokes Google', (tester) async {
    final account = FixtureAccount()..id = null;
    final identity = FixtureIdentity();
    await mount(tester, account: account, identity: identity);
    account.id = 'android:1';
    account.googleLinked = true;
    account.notifyListeners();
    await tester.pumpAndSettle();
    expect(identity.calls, 0);
  });

  testWidgets('server failure releases game and leaves guest unchanged', (
    tester,
  ) async {
    final account = FixtureAccount()..failure = 'connection_failed';
    final identity = FixtureIdentity();
    await mount(tester, account: account, identity: identity);
    expect(identity.calls, 1);
    expect(account.googleLinked, false);
    expect(account.nickname, 'Guest');
    expect(find.byKey(dialog), findsNothing);
    expect(find.byKey(const ValueKey('google-startup-progress')), findsNothing);
    expect(find.textContaining('Можно играть гостем'), findsOneWidget);
    account.failure = null;
    account.notifyListeners();
    await tester.pumpAndSettle();
    expect(identity.calls, 1);
  });

  testWidgets('direct startup restores existing profile with same token', (
    tester,
  ) async {
    final actions = <String>[];
    final identity = FixtureIdentity();
    final account = MobileAccount(
      vault: Vault(),
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final action = body['action'] as String;
        actions.add(action);
        if (action == 'google_link') {
          return http.Response(
            '{"ok":false,"error":"google_profile_exists"}',
            409,
          );
        }
        if (action == 'google_restore') {
          expect(body['idToken'], 'fixture-token');
        }
        return http.Response(
          jsonEncode({
            'ok': true,
            'profile': {
              'id': action == 'google_restore' ? 'android:2' : 'android:1',
              'nickname': action == 'google_restore' ? 'Returning' : 'Guest',
              'googleLinked': action == 'google_restore',
            },
          }),
          200,
        );
      }),
    );
    await account.load();
    await mount(tester, account: account, identity: identity);
    expect(actions, ['guest', 'google_link', 'google_restore']);
    expect(identity.calls, 1);
    expect(account.id, 'android:2');
    expect(find.byKey(const ValueKey('profile-restore-confirm')), findsNothing);
    expect(find.byKey(dialog), findsNothing);
  });

  testWidgets('real account link flushes first and keeps identity/wallet', (
    tester,
  ) async {
    final calls = <String>[];
    final vault = Vault();
    final account = MobileAccount(
      vault: vault,
      client: MockClient((request) async {
        final action = (jsonDecode(request.body) as Map)['action'] as String;
        calls.add(action);
        return http.Response(
          jsonEncode({
            'ok': true,
            'profile': {
              'id': 'android:7',
              'nickname': 'GuestSeven',
              'googleLinked': action == 'google_link',
              'googleEmail': action == 'google_link'
                  ? 'fixture@example.invalid'
                  : null,
              'walletVersion': 1,
              'wallet': {'tokens': 23, 'lives': 6},
            },
          }),
          200,
        );
      }),
    );
    await account.load();
    final credentials = vault.value;
    account.beforeRound = () async {
      calls.add('flush');
    };
    await mount(tester, account: account, identity: FixtureIdentity());
    expect(calls, ['guest', 'flush', 'google_link']);
    expect(account.id, 'android:7');
    expect(account.nickname, 'GuestSeven');
    expect(account.wallet!['tokens'], 23);
    expect(account.wallet!['lives'], 6);
    expect(account.googleEmail, 'fixture@example.invalid');
    expect(vault.value, credentials);
    expect(find.byKey(dialog), findsNothing);
  });

  for (final language in ['ru', 'en']) {
    for (final size in [const Size(390, 844), const Size(320, 480)]) {
      testWidgets('native waiting blocks play $language $size', (tester) async {
        final account = FixtureAccount()..id = null;
        final identity = FixtureIdentity()..pending = Completer<String>();
        await mount(
          tester,
          account: account,
          identity: identity,
          language: language,
          size: size,
          textScale: 2,
        );
        account.id = 'android:1';
        account.notifyListeners();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(identity.calls, 1);
        expect(find.byKey(dialog), findsNothing);
        expect(find.byKey(connect), findsNothing);
        expect(find.byKey(skip), findsNothing);
        expect(
          find.byKey(const ValueKey('google-startup-progress')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<AbsorbPointer>(
                find.byKey(const ValueKey('google-startup-game-input')),
              )
              .absorbing,
          true,
        );
        expect(
          tester
              .widget<PopScope>(
                find.byKey(const ValueKey('google-startup-navigation')),
              )
              .canPop,
          false,
        );
        expect(tester.takeException(), isNull);
        identity.pending!.complete('fixture-token');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AbsorbPointer>(
                find.byKey(const ValueKey('google-startup-game-input')),
              )
              .absorbing,
          false,
        );
      });
    }
  }
}
