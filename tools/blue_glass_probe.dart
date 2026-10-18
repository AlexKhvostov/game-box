import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/game/game_world.dart';
import 'package:game_box/ui/crystal_cost_badge.dart';
import '../lib/ui/game_viewport.dart';
// Isolated emulator QA: actual Flutter windows; every HTTP call uses fixtures.
// UNTOUCH_UI_PROBE=true creates its own Android package and storage.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' show FrameTiming;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/features/game/game_home_screen.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/game/game_debug_panel.dart';
import 'package:game_box/features/leaderboard/leaderboard_panel.dart';
import 'package:game_box/features/game/lives_sheet.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/features/leaderboard/player_result_sheet.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/domain/arcade_rules.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'package:game_box/features/result/share_social_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/audience_gate.dart';
import 'package:game_box/ui/billing_unavailable.dart';

class _Vault implements AccountVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

// Price is fixture text. No Google SDK or real purchase is reachable.
class _QaBilling extends PlayBillingService {
  _QaBilling(super.account) {
    available = true;
  }
  @override
  String? price(String id) => const bool.fromEnvironment('COMPACT_SHOP_QA') ? null : 'USD 2.34';
  @override
  Future<void> buy(String id) async =>
      throw StateError('Purchases disabled in QA');
  @override
  Future<void> restore() async => throw StateError('Restores disabled in QA');
}

final qaErrors = <String>[];
final qaFrames = <FrameTiming>[];
Map<String, Object> frameSummary() {
  Map<String, Object> stats(List<double> values) {
    values.sort();
    double at(double q) =>
        values.isEmpty ? 0 : values[((values.length - 1) * q).round()];
    return {
      'p50ms': at(.5),
      'p95ms': at(.95),
      'maxMs': at(1),
      'over16_7ms': values.where((v) => v > 16.7).length,
    };
  }

  return {
    'frames': qaFrames.length,
    'build': stats(
      qaFrames.map((f) => f.buildDuration.inMicroseconds / 1000).toList(),
    ),
    'raster': stats(
      qaFrames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList(),
    ),
  };
}

bool qaEmpty = false, qaOffline = false;
int qaRoundStarts = 0;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addTimingsCallback((frames) {
    qaFrames.addAll(frames);
    if (qaFrames.length > 10000)
      qaFrames.removeRange(0, qaFrames.length - 10000);
  });
  FlutterError.onError = (details) {
    qaErrors.add(details.exceptionAsString());
    FlutterError.presentError(details);
  };
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(AudiencePolicy.storageKey);
  final shared = await SharedConfigLoader.load(allowNetwork: false);
  final economy = EconomyStore(config: shared.economy);
  await economy.load();
  economy.lives = 20;
  economy.tokens = 64;
  economy.bestTimeMs = 21349;
  final audience = AudiencePolicy();
  await audience.load();
  final preferences = PlayerPreferences();
  await preferences.load();
  await preferences.setSound(false);
  await preferences.setMusic(false);
  final account = MobileAccount(
    vault: _Vault(),
    client: MockClient((request) async {
      final data = jsonDecode(request.body) as Map;
      if (data['action'] == 'round_start') {
        qaRoundStarts++;
        return http.Response(
          jsonEncode({'ok': true, 'roundId': data['requestId']}),
          200,
        );
      }
      if (data['action'] == 'round_finish')
        return http.Response('{"ok":true,"scoreId":"qa-score"}', 200);
      return http.Response(
        '{"ok":true,"profile":{"id":"android:90000000","nickname":"Alexey","googleLinked":false}}',
        200,
      );
    }),
  );
  await account.load();
  final scores = ScoresStore(
    account: account,
    client: MockClient((request) async {
      if (qaOffline) return http.Response('{"ok":false}', 503);
      return http.Response(
        jsonEncode({
          'ok': true,
          'source': 'mysql',
          'scores': qaEmpty
              ? []
              : List.generate(
                  12,
                  (i) => {
                    'id': 'qa-$i',
                    'userId': i == 2
                        ? 'android:90000000'
                        : 'android:${100 + i}',
                    'playerName': i == 4
                        ? 'AlexandertheVeryLongName123'
                        : 'Player ${i + 1}',
                    'timeMs': 21349 - i * 973,
                    'createdAt': 1791621000000,
                    'countryCode': i % 2 == 0 ? 'BY' : 'US',
                    'riskCount': 8 - i % 4,
                    'runDistance': 435 - i * 10,
                    'hadJump': i % 2 == 0,
                    'hadHelmet': i % 3 == 0,
                  },
                ),
        }),
        200,
      );
    }),
  );
  await scores.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: audience),
        ChangeNotifierProvider.value(value: preferences),
        ChangeNotifierProvider.value(value: account),
        ChangeNotifierProvider<PlayBillingService>(
          create: (_) => _QaBilling(account),
        ),
        ChangeNotifierProvider.value(value: scores),
        Provider.value(
          value: GameplayConfig(
            enemies: shared.gameplay.enemies,
            player: shared.gameplay.player,
            field: shared.gameplay.field,
            audio: shared.gameplay.audio,
            mobileEnemies: shared.gameplay.mobileEnemies,
            // Only the isolated UI fixture: enough time to capture a playing pad.
            game: GameConfig.fromJson({
              ...shared.gameplay.game.toJson(),
              'startInvulnSec': 10,
              'idleEnemiesMove': false,
            }),
          ),
        ),
      ],
      child: const _QaApp(),
    ),
  );
}

class _QaApp extends StatefulWidget {
  const _QaApp();
  @override
  State<_QaApp> createState() => _QaAppState();
}

class _QaAppState extends State<_QaApp> {
  final nav = GlobalKey<NavigatorState>();
  String language = 'ru', window = 'game';
  bool result = false, claim = false;
  double textScale = 1;
  int gameEpoch = 0;
  HttpServer? server;
  @override
  void initState() {
    super.initState();
    unawaited(_serve());
  }

  Future<void> _serve() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8877);
    await for (final request in server!) {
      try {
        if (request.uri.path == '/service') {
          final service = await developer.Service.getInfo();
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({'uri': service.serverUri?.toString()}),
          );
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/clear-frames') {
          qaFrames.clear();
          qaErrors.clear();
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"cleared":true}');
          await request.response.close();
          continue;
        }
        if (request.uri.path == '/export-share') {
          Element? preview;
          void visit(Element element) {
            if (element.widget.key == const ValueKey('share-preview'))
              preview = element;
            element.visitChildElements(visit);
          }

          visit(nav.currentContext! as Element);
          if (preview == null) throw StateError('Open the share preview first');
          final boundary = preview!
              .findAncestorRenderObjectOfType<RenderRepaintBoundary>()!;
          final image = await boundary.toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          request.response.headers.contentType = ContentType('image', 'png');
          request.response.add(bytes!.buffer.asUint8List());
          await request.response.close();
          continue;
        }
        if ({
          '/clear-enemies',
          '/hit-helmet',
          '/jump',
          '/fault-geometry',
        }.contains(request.uri.path)) {
          GameWorld? world;
          void findWorld(Element element) {
            final widget = element.widget;
            if (widget is CustomPaint && widget.painter is GameFieldPainter) {
              world = (widget.painter as GameFieldPainter).world;
            }
            element.visitChildElements(findWorld);
          }

          findWorld(nav.currentContext! as Element);
          if (world == null) throw StateError('Fixture world unavailable');
          if (request.uri.path == '/clear-enemies') world!.enemies.clear();
          if (request.uri.path == '/jump') world!.tryJump();
          if (request.uri.path == '/fault-geometry') {
            final e = world!.enemies.first;
            final tiny = request.uri.queryParameters['kind'] == 'tiny';
            final outside = request.uri.queryParameters['kind'] == 'offscreen';
            world!.enemies[0] =
                EnemyBody(
                    pos: outside ? const Offset(-500, -500) : e.pos,
                    vel: e.vel,
                    w: tiny ? 1 : e.w,
                    h: tiny ? 1 : e.h,
                    aspect: e.aspect,
                    angleDeg: e.angleDeg,
                    quadrantN: e.quadrantN,
                    fieldQuadrant: e.fieldQuadrant,
                    initialSpeed: e.initialSpeed,
                    acceleration: e.acceleration,
                  )
                  ..homePos = outside ? const Offset(-500, -500) : e.homePos
                  ..homeVel = e.homeVel;
          }

          if (request.uri.path == '/hit-helmet') {
            world!.enemies.add(
              EnemyBody(
                pos: world!.player + Offset(world!.playerSize - 2, 10),
                vel: const Offset(-100, 0),
                w: 20,
                h: 20,
                aspect: 1,
                angleDeg: 0,
                quadrantN: 0,
                fieldQuadrant: 0,
                initialSpeed: 100,
                acceleration: 0,
              ),
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 180));
        }
        if (request.uri.path == '/show') {
          qaErrors.clear();
          qaFrames.clear();
          qaRoundStarts = 0;
          final q = request.uri.queryParameters;
          nav.currentState?.popUntil((route) => route.isFirst);
          setState(() {
            gameEpoch++;
            language = q['lang'] ?? language;
            textScale = double.tryParse(q['scale'] ?? '') ?? 1;
            result = false;
            window = q['screen'] ?? 'game';
            claim = q['claim'] == 'true';
          });
          await Future<void>.delayed(const Duration(milliseconds: 300));
          final c = nav.currentState!.overlay!.context;
          ScaffoldMessenger.of(c).clearSnackBars();
          final audience = c.read<AudiencePolicy>();
          final prefs = await SharedPreferences.getInstance();
          if (q['age'] == 'unknown') {
            await prefs.remove(AudiencePolicy.storageKey);
            await audience.load();
          }
          if (q['age'] == 'known') await audience.select(AgeBand.age21plus);
          qaEmpty = q['state'] == 'empty';
          qaOffline = q['state'] == 'offline';
          if (window == 'ranking') await c.read<ScoresStore>().load();
          final economy = c.read<EconomyStore>();
          final account = c.read<MobileAccount>();
          account.googleLinked =
              window == 'purchase' ||
              window == 'subscription' ||
              q['state'] == 'linked';
          account.googleName = account.googleLinked ? 'Тестовый игрок' : null;
          account.googleEmail = account.googleLinked
              ? 'player@example.invalid'
              : null;
          account.hideGoogleAccount = true;
          account.betaFreeCrystals = true;
          economy.tokens = 64;
          economy.lives = 20;
          if (q['state'] == 'exhausted') {
            economy.lives = 0;
          }
          if (q['state'] == 'rich') {
            economy.lives = 999;
            economy.tokens = 999;
          }
          economy.jumpRentalUntil = null;
          economy.helmetRentalUntil = null;
          economy.hasPremium = false;
          economy.premiumNextChargeAt = null;
          economy.lastDailyClaimAt = null;
          economy.dailyStreak = 0;
          economy.lastTimedBonusClaimAt = null;
          if (q['state'] == 'active') {
            economy.jumpRentalUntil = DateTime.now().add(
              const Duration(minutes: 7),
            );
            economy.helmetRentalUntil = DateTime.now().add(
              const Duration(minutes: 19),
            );
            economy.hasPremium = true;
            economy.premiumNextChargeAt = DateTime.now().add(
              const Duration(days: 4),
            );
          }
          if (q['state'] == 'poor') economy.tokens = 0;
          if (q['state'] == 'claimed') {
            economy.lastDailyClaimAt = DateTime.now();
            economy.dailyStreak = 3;
            economy.lastTimedBonusClaimAt = DateTime.now();
          }
          economy.applyConfig(economy.config);
          switch (window) {
            case 'notice':
              ScaffoldMessenger.of(c).showSnackBar(
                SnackBar(
                  content: Text(language == 'ru' ? 'Скопировано' : 'Copied'),
                ),
              );
            case 'player':
              unawaited(
                showPlayerResultSheet(
                  c,
                  entry: ScoreEntry(
                    id: 'qa-player',
                    displayName: q['state'] == 'long'
                        ? 'AlexandertheVeryLongName123'
                        : 'Player 7',
                    timeMs: 21349,
                    createdAt: DateTime.now(),
                    riskCount: 8,
                    runDistance: 435,
                    hadJump: true,
                    hadHelmet: false,
                  ),
                  place: 7,
                  periodLabel: language == 'ru' ? 'Неделя' : 'Week',
                ),
              );
            case 'profile':
              unawaited(showProfileSheet(c));
            case 'lives':
              unawaited(showLivesSheet(c));
            case 'daily':
              unawaited(showCrystalsSheet(c));
            case 'purchases':
              unawaited(showCrystalsSheet(c, initialTab: 1));
            case 'rent':
              unawaited(showCrystalsSheet(c, initialTab: 2));
            case 'earn':
              unawaited(showCrystalsSheet(c, initialTab: 3));
            case 'plus':
              unawaited(showPlusSheet(c));
            case 'ranking':
              unawaited(showLeaderboardSheet(c));
            case 'age':
              unawaited(showAudienceSelection(c));
            case 'ageGate':
              unawaited(showAudienceSelection(c, resourceAction: true));
            case 'result':
              setState(() => result = true);
            case 'share':
              unawaited(
                showShareSocialSheet(
                  c,
                  timeMs: 21349,
                  betterPercent: 83,
                  riskCount: 8,
                  runSteps: 435,
                ),
              );
            case 'testGrant':
              showBillingUnavailable(c, productId: 'pack_s');
            case 'billing':
              showBillingUnavailable(c);
            case 'googlePurchase':
              unawaited(buyGoogleProduct(c, 'pack_s'));
            case 'purchase':
              unawaited(buyGoogleProduct(c, 'pack_s'));
            case 'subscription':
              unawaited(buyGoogleProduct(c, 'plus_weekly'));
            case 'restore':
              unawaited(showProfileRestoreConfirmation(c));
            case 'reset':
              unawaited(showProfileResetConfirmation(c));
          }
          await Future<void>.delayed(
            Duration(milliseconds: window == 'result' ? 3000 : 900),
          );
        }
        final c = nav.currentState!.overlay!.context;
        Offset? recoveryActionCenter;
        Offset? gameFieldCenter;
        var livesWindowCount = 0;
        var touchpadCount = 0;
        var startCaptionCount = 0;
        var gameTimeMs = 0;
        var resultOverlayCount = 0;
        var debugPanelCount = 0;
        int? rankingFilter;
        int? shopTab;
        var googleRestoreCount = 0;
        final targets = <String, Map<String, double>>{};
        // Economy acceptance uses synthetic balances in this isolated package.
        final economyGeometry = <String, Map<String, double>>{};
        final shopGeometry = <String, Map<String, double>>{};
        final visibleTexts = <String>[];
        double? heartScale;
        final hudGeometry = <String, Map<String, double>>{};
        final barrierColors = <int>[];
        final abilityStates = <String, Object>{};
        final costBadges = <Map<String, Object>>[];
        var resultCloseIcons = 0;
        var geometryErrors = 0;
        var resultReplayVisibleHeight = 0.0;

        void visitRecovery(Element element) {
          if (element.widget is ModalBarrier) {
            final color = (element.widget as ModalBarrier).color;
            if (color != null) barrierColors.add(color.toARGB32());
          }
          final geometryKey = element.widget.key;
          if (geometryKey is ValueKey<String> &&
              (geometryKey.value.startsWith('crystal-package-') ||
                  geometryKey.value.startsWith('daily-row-') ||
                  {
                    'shop-tab-content',
                    'shop-crystal-balance',
                    'shop-gift-material',
                    'daily-plus-card',
                  }.contains(geometryKey.value))) {
            final box = element.findRenderObject();
            if (box is RenderBox && box.hasSize) {
              final dpr = View.of(c).devicePixelRatio;
              final start = box.localToGlobal(Offset.zero) * dpr;
              final end =
                  box.localToGlobal(box.size.bottomRight(Offset.zero)) * dpr;
              shopGeometry[geometryKey.value] = {
                'left': start.dx,
                'top': start.dy,
                'width': end.dx - start.dx,
                'height': end.dy - start.dy,
              };
            }
          }
          if (element.widget is Text) {
            final value = (element.widget as Text).data;
            if (value != null) visibleTexts.add(value);
          }
          if (geometryKey == const ValueKey('lives-heart-pulse') &&
              element.widget is ScaleTransition) {
            heartScale = (element.widget as ScaleTransition).scale.value;
          }
          if (geometryKey == const ValueKey('lives-inventory') ||
              geometryKey == const ValueKey('lives-floating-window')) {
            final box = element.findRenderObject();
            if (box is RenderBox && box.hasSize) {
              final start = box.localToGlobal(Offset.zero);
              economyGeometry[geometryKey.toString()] = {
                'left': start.dx,
                'top': start.dy,
                'width': box.size.width,
                'height': box.size.height,
              };
            }
          }
          if (geometryKey is ValueKey<String> &&
              {
                'arcade-play-area',
                'arcade-hud-region',
                'arcade-game-field',
              }.contains(geometryKey.value)) {
            final box = element.findRenderObject();
            if (box is RenderBox && box.hasSize) {
              final start =
                  box.localToGlobal(Offset.zero) * View.of(c).devicePixelRatio;
              final end =
                  box.localToGlobal(box.size.bottomRight(Offset.zero)) *
                  View.of(c).devicePixelRatio;
              hudGeometry[geometryKey.value] = {
                'left': start.dx,
                'top': start.dy,
                'width': end.dx - start.dx,
                'height': end.dy - start.dy,
              };
            }
          }
          if (element.widget.key ==
              const ValueKey('game-start-technical-error'))
            geometryErrors++;
          if (element.widget is CrystalCostBadge) {
            final badge = element.widget as CrystalCostBadge;
            costBadges.add({
              'amount': badge.amount,
              'available': badge.available,
            });
          }
          if (element.widget is CustomPaint &&
              (element.widget as CustomPaint).foregroundPainter
                  is AbilityRingPainter) {
            final ring =
                (element.widget as CustomPaint).foregroundPainter
                    as AbilityRingPainter;
            abilityStates[element.widget.key.toString()] = {
              'active': ring.active,
              'broken': ring.broken,
              'progress': ring.value,
              'color': ring.color.toARGB32(),
            };
          }
          if (element.widget is Icon &&
              (element.widget as Icon).icon == Icons.close_rounded &&
              result) {
            resultCloseIcons++;
          }
          if (element.widget.key == const ValueKey('result-replay')) {
            final box = element.findRenderObject();
            if (box is RenderBox && box.hasSize)
              resultReplayVisibleHeight = box.size.height;
          }
          if (element.widget is GameDebugPanel) debugPanelCount++;
          if (element is StatefulElement &&
              element.state is LeaderboardPanelState) {
            rankingFilter = (element.state as LeaderboardPanelState).filter;
          }
          if (element.widget is TabBar)
            shopTab = (element.widget as TabBar).controller?.index;
          final key = element.widget.key;
          if (key == const ValueKey('profile-google-restore'))
            googleRestoreCount++;
          if (key is ValueKey<String> &&
              {
                'hud-record-button',
                'hud-debug-toggle',
                'hud-lives-card',
                'hud-crystals-card',
                'hud-account-card',
                'hud-ranking-card',
                'hud-helmet-button',
                'hud-jump-button',
                'shop-tab-0',
                'shop-tab-1',
                'shop-tab-2',
                'shop-tab-3',
                'shop-crystal-test-credit',
                'result-replay',
                'result-risk',
                'result-run',
                'leaderboard-filter-0',
                'leaderboard-filter-5',
              }.contains(key.value)) {
            final box = element.findRenderObject();
            if (box is RenderBox && box.hasSize) {
              final point =
                  box.localToGlobal(box.size.center(Offset.zero)) *
                  View.of(c).devicePixelRatio;
              targets[key.value] = {'x': point.dx, 'y': point.dy};
            }
          }
          if (element.widget is ArcadeHud) {
            gameTimeMs = (element.widget as ArcadeHud).timeMs();
          }
          if (element.widget is ResultOverlay) {
            resultOverlayCount++;
          }
          if (element.widget.key == const ValueKey('lives-recovery-action')) {
            final box = element.findRenderObject();
            if (box is RenderBox && box.hasSize) {
              recoveryActionCenter =
                  box.localToGlobal(box.size.center(Offset.zero)) *
                  View.of(c).devicePixelRatio;
            }
          }
          if (element.widget.key == const ValueKey('lives-floating-window')) {
            livesWindowCount++;
          }
          if (element.widget.key == const ValueKey('game-touchpad')) {
            touchpadCount++;
          }
          if (element.widget.key == const ValueKey('game-start-caption')) {
            startCaptionCount++;
          }
          if (element.widget.key == const ValueKey('arcade-game-field')) {
            final box = element.findRenderObject();
            if (box is RenderBox && box.hasSize) {
              gameFieldCenter =
                  box.localToGlobal(box.size.center(Offset.zero)) *
                  View.of(c).devicePixelRatio;
            }
          }
          element.visitChildElements(visitRecovery);
        }

        visitRecovery(nav.currentContext! as Element);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'window': window,
            'lang': language,
            'size': '${View.of(c).physicalSize / View.of(c).devicePixelRatio}',
            'logicalSize': '${MediaQuery.sizeOf(c)}',
            'viewportScale': GameViewport.scaleOf(c),
            'scale': textScale,
            'effectiveFont14': MediaQuery.textScalerOf(c).scale(14),
            'errors': qaErrors,
            'timings': frameSummary(),
            if (request.uri.queryParameters['raw'] == 'true')
              'frames': [
                for (final frame in qaFrames)
                  {
                    'vsyncUs': frame.timestampInMicroseconds(
                      ui.FramePhase.vsyncStart,
                    ),
                    'buildUs': frame.buildDuration.inMicroseconds,
                    'rasterUs': frame.rasterDuration.inMicroseconds,
                    'totalUs': frame.totalSpan.inMicroseconds,
                  },
              ],
            'age': c.read<AudiencePolicy>().band?.name,
            'tokens': c.read<EconomyStore>().tokens,
            'lives': c.read<EconomyStore>().lives,
            'livesWindowCount': livesWindowCount,
            'touchpadCount': touchpadCount,
            'startCaptionCount': startCaptionCount,
            'gameTimeMs': gameTimeMs,
            'resultOverlayCount': resultOverlayCount,
            'debugPanelCount': debugPanelCount,
            'rankingFilter': rankingFilter,
            'shopTab': shopTab,
            'googleRestoreCount': googleRestoreCount,
            'targets': targets,
            'economyGeometry': economyGeometry,
            'shopGeometry': shopGeometry,
            'visibleTexts': visibleTexts,
            'heartScale': heartScale,
            'hudGeometry': hudGeometry,
            'barrierColors': barrierColors,
            'modalCanPop': nav.currentState!.canPop(),
            'roundStarts': qaRoundStarts,
            'geometryErrors': geometryErrors,
            'abilityStates': abilityStates,
            'costBadges': costBadges,
            'resultCloseIcons': resultCloseIcons,
            'resultReplayHeight': resultReplayVisibleHeight,
            'gameFieldCenter': gameFieldCenter == null
                ? null
                : {'x': gameFieldCenter!.dx, 'y': gameFieldCenter!.dy},
            'recoveryActionCenter': recoveryActionCenter == null
                ? null
                : {
                    'x': recoveryActionCenter!.dx,
                    'y': recoveryActionCenter!.dy,
                  },
          }),
        );
      } catch (e) {
        request.response.statusCode = 500;
        request.response.write('$e');
      }
      await request.response.close();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: nav,
    debugShowCheckedModeBanner: false,
    theme: buildGameTheme(),
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: GameViewport(child: child!),
    ),
    home: Builder(
      builder: (c) => Stack(
        children: [
          GameHomeScreen(key: ValueKey('qa-game-$gameEpoch')),
          if (result)
            ResultOverlay(
              timeMs: 21349,
              runDistance: 435,
              riskCount: 8,
              rewardClaimed: !claim,
              onClaimReward: () async {
                if (!await ensureResourceAge(c)) return false;
                final economy = c.read<EconomyStore>();
                economy.grantCrystals(
                  ArcadeRules.roundReward(economy.config, 435, 8),
                );
                return true;
              },
              onOk: () => setState(() => result = false),
              onShare: () => showLeaderboardSheet(c),
            ),
        ],
      ),
    ),
  );
}
