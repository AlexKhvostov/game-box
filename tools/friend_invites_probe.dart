// Isolated invite UI/native QA only. Build with UNTOUCH_UI_PROBE=true.
// API/profile/Google/paid history are synthetic; native intents/clipboard/share/IME are real.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/android_invite_source.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/google_identity.dart';
import 'package:game_box/data/invite_code.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/invites/invitations_dialog.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_viewport.dart';

const codeA = 'ABCDEFGH2345', codeC = 'JKLMNPQR6789';
final errors = <String>[];

class ProbeVault implements AccountVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async => value = data;
}

class NoGoogle implements GoogleIdentity {
  @override
  bool get configured => false;
  @override
  Future<String> token() =>
      throw StateError('Real Google is prohibited in this probe');
}

class NativeSpy implements AndroidInviteSource {
  final delegate = NativeAndroidInviteSource();
  final received = <String>[];
  int acknowledgements = 0, events = 0;
  String? actualSdkStatus;
  @override
  void listen(VoidCallback onAvailable) => delegate.listen(() {
    events++;
    onAvailable();
  });
  @override
  Future<String?> peekAppLink() async {
    final value = await delegate.peekAppLink();
    if (value != null && !received.contains(value)) received.add(value);
    return value;
  }

  @override
  Future<void> acknowledgeAppLink(String url) async {
    await delegate.acknowledgeAppLink(url);
    acknowledgements++;
  }

  // UI/cold-warm intent cases do not claim a Play installation. Measure the actual sideload SDK separately.
  @override
  Future<InviteReferrer> readInstallReferrer() async =>
      const InviteReferrer(InviteReferrerStatus.absent);
  Future<void> measureSdk() async {
    actualSdkStatus = (await delegate.readInstallReferrer()).status.name;
  }

  @override
  void dispose() => delegate.dispose();
}

class Fixture {
  Fixture(this.prefs);
  final SharedPreferences prefs;
  String owner = 'android:900001', mode = 'empty';
  final bindings = <String, String>{};
  final calls = <String, int>{};
  int binds = 0, forbidden = 0;
  bool get linked => mode != 'guest';
  String get ownCode =>
      owner == 'android:900001' ? 'AAAAAAAAAAAA' : 'BBBBBBBBBBBB';
  Future<void> load() async {
    final stored =
        jsonDecode(prefs.getString('fi_probe_bindings') ?? '{}') as Map;
    bindings.addAll(stored.map((k, v) => MapEntry('$k', '$v')));
  }

  Map<String, dynamic> get profile => {
    'id': owner,
    'nickname': 'Invite QA',
    'googleLinked': linked,
    'googleName': linked ? 'Synthetic Friend' : null,
    'googleEmail': linked ? 'qa@example.invalid' : null,
    'hideGoogleAccount': true,
    'walletVersion': 1,
    'wallet': {
      'tokens': 64,
      'lives': 20,
      'bestTimeMs': 25000,
      'gamesStarted': 5,
      'claimed': ['install_bonus'],
      'unlocked': [],
      'plusUntil': 0,
    },
  };
  List<Map<String, Object?>> rows(int start, int count) => List.generate(
    count,
    (i) => {
      'id': '${100 - start - i}',
      'nickname': start + i == 1
          ? null
          : (start + i == 0
                ? 'Очень длинное имя приглашённого игрока Very long invited player'
                : 'Friend ${start + i + 1}'),
      'rewardedAt': DateTime(2026, 10, 13).millisecondsSinceEpoch,
      'amount': 10,
    },
  );
  Map<String, dynamic> invites({bool next = false}) => {
    'profileId': owner,
    'ownCode': ownCode,
    'inviteUrl': InviteCode.url(ownCode),
    'inviterAssigned': bindings[owner] != null,
    'inviterCode': bindings[owner],
    'googleLinked': linked,
    'completedGames': 5,
    'bonusStatus': bindings[owner] == null
        ? 'unbound'
        : linked
        ? 'rewarded'
        : 'waiting_google',
    'reward': 10,
    'requiredGames': 5,
    'rewardTotal': mode == 'paid' || mode == 'page-error' ? 120 : 0,
    'paidRows': mode == 'paid' || mode == 'page-error'
        ? rows(next ? 4 : 0, next ? 8 : 4)
        : [],
    'nextCursor': !next && (mode == 'paid' || mode == 'page-error')
        ? '96'
        : null,
  };
  Future<http.Response> request(http.Request request) async {
    final data = jsonDecode(request.body) as Map;
    final action = '${data['action']}';
    calls.update(action, (n) => n + 1, ifAbsent: () => 1);
    int status = 200;
    Map<String, dynamic> body = {'ok': true, 'profile': profile};
    if (action.startsWith('google_') ||
        action.startsWith('round_') ||
        action.startsWith('play_') ||
        action == 'wallet_operation') {
      forbidden++;
      return http.Response('{"ok":false,"error":"probe_forbidden"}', 400);
    }
    if (action.startsWith('invites_')) {
      if (mode == 'offline' || mode == 'unavailable') {
        return http.Response(
          jsonEncode({
            'ok': false,
            'error': mode == 'unavailable'
                ? 'action_invalid'
                : 'connection_failed',
          }),
          503,
        );
      }
      if (action == 'invites_list' && mode == 'page-error') {
        return http.Response('{"ok":false,"error":"connection_failed"}', 503);
      }
      if (action == 'invites_bind') {
        binds++;
        final code = InviteCode.normalize(data['code']);
        String? failure;
        if (code == null) {
          failure = 'invite_code_invalid';
        } else if (code == ownCode) {
          failure = 'invite_self';
        } else if (!{codeA, codeC}.contains(code)) {
          failure = 'invite_not_found';
        } else if (bindings[owner] != null && bindings[owner] != code) {
          failure = 'invite_already_bound';
        }
        if (failure != null) {
          body = {'ok': false, 'error': failure};
          status = 409;
        } else {
          bindings[owner] = code!;
          await prefs.setString('fi_probe_bindings', jsonEncode(bindings));
        }
      }
      if (status == 200) {
        body = {
          'ok': true,
          'profile': profile,
          'invites': invites(next: action == 'invites_list'),
        };
      }
    }
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

late Fixture fixture;
late NativeSpy native;
late MobileAccount account;
late MobileInvites invites;
late EconomyStore economy;
late PlayerPreferences preferences;
late AudiencePolicy audience;
late GameplayConfig gameplay;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
    FlutterError.presentError(details);
  };
  final prefs = await SharedPreferences.getInstance();
  fixture = Fixture(prefs);
  await fixture.load();
  native = NativeSpy();
  final shared = await SharedConfigLoader.load(allowNetwork: false);
  gameplay = shared.gameplay;
  economy = EconomyStore(config: shared.economy);
  await economy.load();
  economy.tokens = 64;
  economy.lives = 20;
  preferences = PlayerPreferences();
  await preferences.load();
  await preferences.setSound(false);
  await preferences.setMusic(false);
  audience = AudiencePolicy();
  await audience.load();
  await audience.select(AgeBand.age21plus);
  account = MobileAccount(
    vault: ProbeVault(),
    client: MockClient(fixture.request),
    endpoint: Uri.parse('http://127.0.0.1/fixture'),
  );
  await account.load();
  invites = MobileInvites(
    account: account,
    source: native,
    startupResolved: true,
  );
  invites.start();
  runApp(const ProbeApp());
}

class ProbeApp extends StatefulWidget {
  const ProbeApp({super.key});
  @override
  State<ProbeApp> createState() => ProbeAppState();
}

class ProbeAppState extends State<ProbeApp> {
  final nav = GlobalKey<NavigatorState>();
  String lang = 'ru', screen = 'home';
  HttpServer? server;
  @override
  void initState() {
    super.initState();
    unawaited(serve());
  }

  Element? element(String key) {
    Element? result;
    void visit(Element e) {
      if (e.widget.key == ValueKey(key)) result = e;
      e.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    return result;
  }

  Future<Map<String, double>> rect(String key) async {
    final e = element(key);
    if (e == null) throw StateError('Key absent: $key');
    await Scrollable.ensureVisible(
      e,
      alignment: .5,
      duration: const Duration(milliseconds: 150),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final box = e.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final end = box.localToGlobal(Offset(box.size.width, box.size.height));
    return {
      'x': offset.dx,
      'y': offset.dy,
      'width': end.dx - offset.dx,
      'height': end.dy - offset.dy,
    };
  }

  Future<void> show(Uri uri) async {
    nav.currentState?.popUntil((r) => r.isFirst);
    final q = uri.queryParameters;
    screen = q['screen'] ?? 'home';
    lang = q['lang'] ?? 'ru';
    fixture.mode = q['state'] ?? 'empty';
    if (q['reset'] == 'true') {
      fixture.bindings.clear();
      await fixture.prefs.remove('fi_probe_bindings');
      await fixture.prefs.remove(PreferencesInviteVault.key);
      invites.dispose();
      native = NativeSpy();
      invites = MobileInvites(
        account: account,
        source: native,
        startupResolved: true,
      );
    }
    if (fixture.mode == 'locked') fixture.bindings[fixture.owner] = codeA;
    await account.refreshProfile();
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (q['reset'] == 'true') invites.start();
    await invites.refresh();
    final context = nav.currentState!.overlay!.context;
    if (!context.mounted) return;
    if (!identical(context.read<MobileInvites?>(), invites)) {
      throw StateError('Probe provider differs from active invite service');
    }
    if (screen == 'earn') unawaited(showCrystalsSheet(context, initialTab: 3));
    if (screen == 'profile') {
      unawaited(showProfileSheet(context, googleIdentity: NoGoogle()));
    }
    if (screen == 'invites') unawaited(showInvitationsDialog(context));
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Map<String, dynamic> status() => {
    'errors': errors,
    'screen': screen,
    'profileId': account.id,
    'boundCode': invites.state?.inviterCode,
    'ownCode': invites.state?.ownCode,
    'pendingCode': invites.pendingCode,
    'busy': invites.busy,
    'providerIsCurrent': identical(
      nav.currentContext!.read<MobileInvites?>(),
      invites,
    ),
    'bindCalls': fixture.binds,
    'calls': fixture.calls,
    'forbiddenCalls': fixture.forbidden,
    'nativeReceived': native.received,
    'nativeEvents': native.events,
    'nativeAcknowledgements': native.acknowledgements,
    'actualSideloadSdkStatus': native.actualSdkStatus,
    'uiReferrerInput': 'absent fixture; actual SDK measured separately',
    'viewSize': [
      MediaQuery.sizeOf(nav.currentContext!).width,
      MediaQuery.sizeOf(nav.currentContext!).height,
    ],
    'dpr': MediaQuery.devicePixelRatioOf(nav.currentContext!),
    'screenDpr': View.of(nav.currentContext!).devicePixelRatio,
    'screenLogicalSize': [
      View.of(nav.currentContext!).physicalSize.width /
          View.of(nav.currentContext!).devicePixelRatio,
      View.of(nav.currentContext!).physicalSize.height /
          View.of(nav.currentContext!).devicePixelRatio,
    ],
    'keyboardInset': MediaQuery.viewInsetsOf(nav.currentContext!).bottom,
  };
  Future<void> serve() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8879);
    await for (final request in server!) {
      try {
        final q = request.uri.queryParameters;
        Map<String, dynamic> data = {};
        switch (request.uri.path) {
          case '/show':
            await show(request.uri);
          case '/rect':
            data = {'rect': await rect(q['key']!)};
          case '/clipboard':
            data = {'clipboard': (await Clipboard.getData('text/plain'))?.text};
          case '/sdk':
            await native.measureSdk();
          case '/back':
            nav.currentState?.maybePop();
            await Future<void>.delayed(const Duration(milliseconds: 180));
          case '/owner':
            fixture.owner = 'android:900002';
            await account.load();
            await invites.refresh();
          case '/status':
            break;
          default:
            throw StateError('Unknown probe route');
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({...status(), ...data}));
      } catch (error) {
        request.response.statusCode = 500;
        request.response.write(
          jsonEncode({'error': '$error', 'errors': errors}),
        );
      }
      await request.response.close();
    }
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: economy),
      ChangeNotifierProvider.value(value: preferences),
      ChangeNotifierProvider.value(value: audience),
      ChangeNotifierProvider.value(value: account),
      ChangeNotifierProvider<MobileInvites>.value(value: invites),
      Provider<GameplayConfig>.value(value: gameplay),
    ],
    child: MaterialApp(
      navigatorKey: nav,
      debugShowCheckedModeBanner: false,
      theme: buildGameTheme(),
      locale: Locale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (_, child) => GameViewport(child: child!),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Text(
              'Invite QA • Synthetic profiles only',
              style: TextStyle(color: Colors.cyan),
            ),
          ),
        ),
      ),
    ),
  );
}
