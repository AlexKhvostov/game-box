// Local-only rendering/performance harness. Every server call is intercepted.
// Build with UNTOUCH_UI_PROBE=true, --profile and this target.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/app/android_audience_startup.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/mobile_wallet_bridge.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_home_screen.dart';
import 'package:game_box/features/game/lives_sheet.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'package:game_box/l10n/app_localizations.dart';

class _Vault implements AccountVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('PROBE_LOCAL_START')) {
    await _startAdmissionProbe();
    return;
  }
  final account = MobileAccount(
    vault: _Vault(),
    client: MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      if (body['action'] == 'round_start') {
        return http.Response(
          jsonEncode({'ok': true, 'roundId': body['requestId']}),
          200,
        );
      }
      if (body['action'] == 'round_finish') {
        return http.Response('{"ok":true,"scoreId":"probe-only"}', 200);
      }
      return http.Response(
        '{"ok":true,"profile":{"id":"android:90000000","nickname":"ProbePlayer","googleLinked":true}}',
        200,
      );
    }),
  );
  await account.load();
  final shared = await SharedConfigLoader.load(allowNetwork: false);
  final economy = EconomyStore(config: shared.economy);
  await economy.load();
  final audience = AudiencePolicy();
  await audience.load();
  if (audience.band == null) await audience.select(AgeBand.age6to8);
  final prefs = PlayerPreferences();
  await prefs.load();
  await prefs.setSound(false);
  await prefs.setMusic(false);
  final scores = ScoresStore(
    account: account,
    client: MockClient(
      (_) async =>
          http.Response('{"ok":true,"source":"mysql","scores":[]}', 200),
    ),
  );
  await scores.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: account),
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider.value(value: scores),
        ChangeNotifierProvider.value(value: audience),
        Provider.value(value: shared.gameplay),
      ],
      child: MaterialApp(
        theme: buildGameTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _Probe(),
      ),
    ),
  );
}

Future<void> _startAdmissionProbe() async {
  final audience = AudiencePolicy();
  await audience.load();
  runApp(
    ChangeNotifierProvider.value(
      value: audience,
      child: AndroidAudienceStartup(
        startGame: () async {
          const online = true;
          final economy = EconomyStore();
          await economy.load();
          final preferences = PlayerPreferences();
          await preferences.load();
          await preferences.setSound(false);
          await preferences.setMusic(false);
          final account = MobileAccount(
            vault: _Vault(),
            mayUseOnline: () => online,
            client: MockClient((request) async {
              final body = jsonDecode(request.body) as Map;
              // ignore: avoid_print
              print('AGE_PROBE_REQUEST ${body['action']}');
              if (body['action'] == 'round_start') {
                return http.Response(
                  jsonEncode({'ok': true, 'roundId': body['requestId']}),
                  200,
                );
              }
              if (body['action'] == 'round_finish') {
                return http.Response('{"ok":true,"scoreId":"probe-only"}', 200);
              }
              return http.Response(
                jsonEncode({
                  'ok': true,
                  'profile': {
                    'id': 'android:90000000',
                    'nickname': 'ProbePlayer',
                    'googleLinked': false,
                    'walletVersion': 0,
                    'wallet': {
                      'lives': 10,
                      'tokens': 40,
                      'bestTimeMs': 0,
                      'claimed': [],
                      'unlocked': [],
                    },
                  },
                }),
                200,
              );
            }),
          );
          if (online) {
            final bridge = MobileWalletBridge(account, economy);
            await bridge.load();
          }
          final scores = ScoresStore(
            account: account,
            client: MockClient((_) async {
              // ignore: avoid_print
              print('AGE_PROBE_REQUEST ranking');
              return http.Response(
                '{"ok":true,"source":"mysql","scores":[]}',
                200,
              );
            }),
          );
          await scores.loadLocal();
          if (online) {
            unawaited(() async {
              await account.load();
              await scores.load();
            }());
          }
          const String? window = null;
          // ignore: avoid_print
          print('AGE_PROBE_SESSION online window=$window');
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => economy),
              ChangeNotifierProvider(create: (_) => preferences),
              ChangeNotifierProvider(create: (_) => account),
              ChangeNotifierProvider(create: (_) => scores),
              Provider.value(value: GameplayConfig()),
            ],
            child: GameBoxApp(forceLocale: 'ru', initialWindow: window),
          );
        },
      ),
    ),
  );
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final _frames = <FrameTiming>[];
  String _stage = 'warmup';
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_timings);
    if (const bool.fromEnvironment('PROBE_AUTORUN')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  void _timings(List<FrameTiming> frames) => _frames.addAll(frames);
  void _report(String next) {
    final build =
        _frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()
          ..sort();
    final raster =
        _frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
          ..sort();
    double p(List<double> v, double n) =>
        v.isEmpty ? 0 : v[((v.length - 1) * n).round()];
    // ignore: avoid_print
    print(
      'UI_PROBE ${jsonEncode({'stage': _stage, 'frames': _frames.length, 'buildP95Ms': p(build, .95), 'rasterP95Ms': p(raster, .95), 'buildMaxMs': p(build, 1), 'rasterMaxMs': p(raster, 1), 'over16Build': build.where((v) => v > 16.67).length, 'over16Raster': raster.where((v) => v > 16.67).length})}',
    );
    _frames.clear();
    _stage = next;
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 4));
    _report('idle');
    await Future<void>.delayed(const Duration(seconds: 4));
    for (var pass = 0; pass < 2; pass++) {
      for (final item in <String, Future<void> Function()>{
        'profile': () => showProfileSheet(context),
        'lives': () => showLivesSheet(context),
        'daily': () => showCrystalsSheet(context),
        'shop': () => showCrystalsSheet(context, initialTab: 1),
        'rent': () => showCrystalsSheet(context, initialTab: 2),
        'rating': () => showLeaderboardSheet(context),
      }.entries) {
        _report('${item.key}-$pass');
        unawaited(item.value());
        await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        Navigator.of(context).pop();
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      _report('result-$pass');
      setState(() => _result = true);
      await Future<void>.delayed(const Duration(seconds: 3));
      setState(() => _result = false);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    _report('done');
    // ignore: avoid_print
    print('UI_PROBE_DONE');
  }

  bool _result = false;
  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const GameHomeScreen(),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Wrap(
            children: [
              TextButton(
                onPressed: () => showProfileSheet(context),
                child: const Text('Профиль'),
              ),
              TextButton(
                onPressed: () => showLivesSheet(context),
                child: const Text('Жизни'),
              ),
              TextButton(
                onPressed: () => showCrystalsSheet(context),
                child: const Text('Магазин'),
              ),
              TextButton(
                onPressed: () => showLeaderboardSheet(context),
                child: const Text('Рейтинг'),
              ),
              TextButton(
                onPressed: () => setState(() => _result = true),
                child: const Text('Результат'),
              ),
            ],
          ),
        ),
        if (_result)
          ResultOverlay(
            timeMs: 12345,
            runDistance: 240,
            riskCount: 5,
            onOk: () => setState(() => _result = false),
            onShare: () => showLeaderboardSheet(context),
          ),
      ],
    ),
  );
}
