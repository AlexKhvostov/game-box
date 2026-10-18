import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/arcade_rules.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/game/game_world.dart';
import 'package:game_box/l10n/app_localizations.dart';

class _Preferences extends InMemorySharedPreferencesStore {
  _Preferences() : super.empty();
  final writes = <String>[];
  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    writes.add(key);
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) {
    writes.add(key);
    return super.remove(key);
  }
}

class _Painter extends GameFieldPainter {
  _Painter({
    required super.world,
    required super.repaint,
    required super.frameValue,
  }) : super(
         accent: Colors.green,
         danger: Colors.red,
         fieldColor: Colors.black,
         borderColor: Colors.green,
       );
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    super.paint(canvas, size);
  }
}

void main() {
  testWidgets('jump progress samples subsecond changes without HUD rebuild', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final economy = EconomyStore();
    await economy.load();
    economy.grantCrystals(100);
    expect(economy.rentJump(), true);
    final hudFrame = ValueNotifier<int>(0);
    final animation = ValueNotifier<int>(0);
    var progress = .01;
    var reads = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: economy),
          Provider.value(value: GameplayConfig()),
        ],
        child: MaterialApp(
          theme: buildGameTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ArcadeHud(
              frame: hudFrame,
              animationFrame: animation,
              timeMs: () => 0,
              jumpProgress: () {
                reads++;
                return progress;
              },
              onLivesTap: () {},
              onCrystalsTap: () {},
              onRecordTap: () {},
              onProfileTap: () {},
            ),
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('hud-jump-button'));
    final ring = find.descendant(
      of: button,
      matching: find.byType(CustomPaint),
    );
    final original = tester.widget<CustomPaint>(ring);
    final firstReads = reads;
    for (var i = 1; i <= 5; i++) {
      progress += .005;
      animation.value++;
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(tester.widget<CustomPaint>(ring), original), true);
      expect(reads, greaterThan(firstReads + i - 1));
    }
    expect(hudFrame.value, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    economy.dispose();
    hudFrame.dispose();
    animation.dispose();
  });

  testWidgets(
    'jump readiness and cooldown remain distinct from rental duration',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final economy = EconomyStore();
      await economy.load();
      economy.grantCrystals(100);
      expect(economy.rentJump(), true);
      final frame = ValueNotifier<int>(0);
      var remainingMs = 1400.0;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: economy),
            Provider.value(value: GameplayConfig()),
          ],
          child: MaterialApp(
            theme: buildGameTheme(),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ArcadeHud(
                frame: frame,
                timeMs: () => 0,
                jumpProgress: () => 1 - remainingMs / 2000,
                jumpRemainingMs: () => remainingMs,
                onLivesTap: () {},
                onCrystalsTap: () {},
                onRecordTap: () {},
                onProfileTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('1,4 с'), findsOneWidget);
      expect(find.byKey(const ValueKey('jump-ready-status')), findsNothing);
      final rentalTooltip = find.ancestor(
        of: find.byKey(const ValueKey('hud-jump-button')),
        matching: find.byType(Tooltip),
      );
      expect(
        tester.widget<Tooltip>(rentalTooltip).message,
        contains('аренда '),
      );
      remainingMs = 0;
      frame.value++;
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Готов'), findsOneWidget);
      expect(find.text('1,4 с'), findsNothing);
      expect(
        tester.widget<Tooltip>(rentalTooltip).message,
        contains('аренда '),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      economy.dispose();
      frame.dispose();
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'completed round persists three changed values with one notification and unchanged reward rules',
    () async {
      final preferences = _Preferences();
      SharedPreferencesStorePlatform.instance = preferences;
      final economy = EconomyStore();
      await economy.load();
      final before = economy.tokens;
      var notifications = 0;
      economy.addListener(() => notifications++);
      preferences.writes.clear();
      final unlocked = economy.completeRound(
        timeMs: 12000,
        runDistance: 240,
        riskCount: 5,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        economy.tokens,
        before + ArcadeRules.roundReward(economy.config, 240, 5),
      );
      expect(economy.bestTimeMs, 12000);
      expect(unlocked, containsAll(['survive_10s', 'risks_5']));
      expect(preferences.writes.toSet(), {
        'flutter.best_time_ms',
        'flutter.tokens',
        'flutter.earn_unlocked_ids',
      });
      expect(preferences.writes, hasLength(3));
      expect(notifications, 1);
      preferences.writes.clear();
      final wallet = {
        'lives': economy.lives,
        'tokens': economy.tokens,
        'bestTimeMs': economy.bestTimeMs,
        'unlocked': economy.unlockedEarnIds.toList(),
        'claimed': economy.claimedEarnIds.toList(),
      };
      await economy.applyServerWallet(wallet);
      expect(preferences.writes, isEmpty);
      economy.dispose();
    },
  );
  testWidgets(
    'timer changes without rebuilding resource text/avatar; balances still refresh',
    (tester) async {
      final economy = EconomyStore();
      await economy.load();
      final frame = ValueNotifier<int>(0);
      var time = 0;
      await tester.binding.setSurfaceSize(const Size(320, 560));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: economy),
            Provider.value(value: GameplayConfig()),
          ],
          child: MaterialApp(
            theme: buildGameTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ArcadeHud(
                frame: frame,
                timeMs: () => time,
                jumpProgress: () => 1,
                onLivesTap: () {},
                onCrystalsTap: () {},
                onRecordTap: () {},
                onProfileTap: () {},
              ),
            ),
          ),
        ),
      );
      final resource = tester.widget<Text>(find.text('${economy.tokens}'));
      final accountFinder = find.byKey(const ValueKey('hud-player-icon'));
      final account = tester.widget<Container>(accountFinder);
      for (var i = 1; i <= 5; i++) {
        time = i * 40;
        frame.value++;
        await tester.pump();
        expect(
          identical(
            resource,
            tester.widget<Text>(find.text('${economy.tokens}')),
          ),
          true,
        );
        expect(
          identical(account, tester.widget<Container>(accountFinder)),
          true,
        );
      }
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('arcade-top-timer')))
            .data,
        arcadeTimer(200),
      );
      economy.grantCrystals(1);
      await tester.pumpAndSettle();
      expect(find.text('${economy.tokens}'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      economy.dispose();
      frame.dispose();
    },
  );
  testWidgets(
    'mutable field repaints from ticker without recreating CustomPaint or its painter',
    (tester) async {
      final frame = ValueNotifier<int>(0);
      final world = GameWorld(
        config: GameplayConfig(),
        field: const Size(240, 240),
        wallInset: 3,
      )..resetLayout();
      final painter = _Painter(
        world: world,
        repaint: frame,
        frameValue: () => frame.value,
      );
      final widget = CustomPaint(size: const Size(240, 240), painter: painter);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: widget)),
        ),
      );
      final first = painter.paints;
      world.tickIdle(.02);
      frame.value++;
      await tester.pump();
      expect(painter.paints, greaterThan(first));
      expect(
        identical(tester.widget<CustomPaint>(find.byWidget(widget)), widget),
        true,
      );
      expect(
        identical(
          tester.widget<CustomPaint>(find.byWidget(widget)).painter,
          painter,
        ),
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );
}
