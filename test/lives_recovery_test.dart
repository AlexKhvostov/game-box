import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_home_screen.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_viewport.dart';

class _Scores extends ScoresStore {
  int starts = 0;
  @override
  Future<bool> beginRound({
    bool helmet = false,
    bool jump = false,
    String? economyRevision,
  }) async {
    starts++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    // Screenshots use real async time; the UI test has no native audio plugin.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global/events'),
          (_) async => null,
        );
  });
  setUpAll(() async {
    if (Platform.environment['UI_EVIDENCE_DIR'] == null) return;
    for (final name in ['Roboto', 'Ahem', 'MaterialIcons']) {
      final loader = FontLoader(name)
        ..addFont(
          File(
            name == 'MaterialIcons'
                ? 'C:/Users/alexe/develop/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
                : 'C:/Windows/Fonts/segoeui.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await loader.load();
    }
  });
  for (final language in ['ru', 'en']) {
    for (final viewport in [const Size(320, 480), const Size(390, 844)]) {
      for (final scale in [1.0, 2.0]) {
        for (final available in [false, true]) {
          testWidgets(
            'recovery/gesture $language $viewport scale$scale lives$available',
            (tester) async {
              SharedPreferences.setMockInitialValues({});
              final economy = EconomyStore();
              await economy.load();
              economy.lives = available ? 2 : 0;
              economy.tokens = scale == 1 ? 0 : 999;
              final scores = _Scores();
              final originalErrorHandler = FlutterError.onError;
              String? layoutError;
              FlutterError.onError = (details) {
                layoutError = details.toString();
                originalErrorHandler?.call(details);
              };
              addTearDown(() => FlutterError.onError = originalErrorHandler);
              await tester.binding.setSurfaceSize(viewport);
              addTearDown(() => tester.binding.setSurfaceSize(null));
              await tester.pumpWidget(
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider.value(value: economy),
                    ChangeNotifierProvider<ScoresStore>.value(value: scores),
                    Provider.value(
                      value: const GameplayConfig(
                        audio: AudioConfig(
                          music: false,
                          sfxMobWall: false,
                          sfxMobCollide: false,
                          sfxHeroMob: false,
                          sfxHeroWall: false,
                          sfxNearMiss: false,
                          sfxHelmet: false,
                          sfxJump: false,
                          sfxStart: false,
                        ),
                        game: GameConfig(
                          idleEnemiesMove: false,
                          startInvulnSec: 60,
                        ),
                      ),
                    ),
                  ],
                  child: MaterialApp(
                    theme: buildGameTheme(),
                    locale: Locale(language),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: RepaintBoundary(
                        key: const ValueKey('recovery-evidence-screen'),
                        child: GameViewport(child: child!),
                      ),
                    ),
                    home: const GameHomeScreen(),
                  ),
                ),
              );
              await tester.pump();
              final field = find.byKey(const ValueKey('arcade-game-field'));
              final recovery = find.byKey(
                const ValueKey('lives-recovery-banner'),
              );
              final pad = find.byKey(const ValueKey('game-touchpad'));
              expect(recovery, available ? findsNothing : findsOneWidget);
              expect(pad, findsOneWidget);
              expect(
                tester.getRect(pad).width,
                greaterThan(tester.getRect(field).width),
              );
              expect(
                tester.getRect(pad).top,
                lessThan(tester.getRect(field).bottom),
              );
              expect(
                available
                    ? tester.getRect(field).bottom + 1
                    : tester.getRect(recovery).top,
                greaterThan(tester.getRect(field).bottom),
              );
              if (available) {
                // The visual pad remains part of the existing whole-screen input.
                await tester.tapAt(
                  tester.getRect(field).bottomCenter + const Offset(0, 25),
                );
                await tester.pump();
                expect(scores.starts, 1);
                expect(economy.lives, 1);
                expect(pad, findsOneWidget);
                expect(
                  find.text(
                    language == 'ru'
                        ? 'Коснись и уворачивайся'
                        : 'Tap and dodge',
                  ),
                  findsNothing,
                );
              } else {
                expect(
                  find.text(
                    language == 'ru'
                        ? 'Продолжим игру?'
                        : 'Ready to keep playing?',
                  ),
                  findsOneWidget,
                );
                expect(find.text('Кубик устал'), findsNothing);
                expect(find.text('Cube needs a break'), findsNothing);
                expect(
                  tester
                      .widget<Image>(
                        find.byKey(const ValueKey('lives-recovery-sofa')),
                      )
                      .image,
                  isA<ResizeImage>(),
                );
                expect(
                  find.text(
                    language == 'ru' ? 'Открыть обменник' : 'Open exchange',
                  ),
                  findsOneWidget,
                );
                final action = find.byKey(
                  const ValueKey('lives-recovery-action'),
                );
                await Scrollable.ensureVisible(
                  tester.element(action),
                  alignment: .5,
                );
                await tester.pump(const Duration(milliseconds: 300));
                expect(
                  tester.getRect(action).height,
                  greaterThanOrEqualTo(
                    52 * GameViewport.scaleFor(viewport.width) - .01,
                  ),
                );
                expect(
                  tester.getRect(action).width,
                  lessThan(tester.getRect(recovery).width * .85),
                );
                final evidence = Platform.environment['UI_EVIDENCE_DIR'];
                if (evidence != null) {
                  await tester.runAsync(() async {
                    for (final element in find.byType(Image).evaluate()) {
                      await precacheImage(
                        (element.widget as Image).image,
                        element,
                      );
                    }
                  });
                  await tester.runAsync(
                    () =>
                        Future<void>.delayed(const Duration(milliseconds: 50)),
                  );
                  await tester.pump();
                  expect(
                    tester
                        .widget<RawImage>(
                          find.descendant(
                            of: find.byKey(
                              const ValueKey('lives-recovery-sofa'),
                            ),
                            matching: find.byType(RawImage),
                          ),
                        )
                        .image,
                    isNotNull,
                  );
                  await tester.runAsync(() async {
                    final boundary = tester.renderObject<RenderRepaintBoundary>(
                      find.byKey(const ValueKey('recovery-evidence-screen')),
                    );
                    final image = await boundary.toImage(pixelRatio: 1);
                    final bytes = await image.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                    await Directory(evidence).create(recursive: true);
                    await File(
                      '$evidence/$language-${viewport.width.toInt()}-font$scale.png',
                    ).writeAsBytes(bytes!.buffer.asUint8List());
                    image.dispose();
                  });
                }
                await tester.tap(action);
                await tester.pump(const Duration(milliseconds: 400));
                // The parent field listener must not push another window on down.
                expect(
                  find.byKey(
                    const ValueKey('lives-floating-window'),
                    skipOffstage: false,
                  ),
                  findsOneWidget,
                );
                expect(
                  find.text(language == 'ru' ? 'ПОЛУЧИТЬ ЖИЗНИ' : 'GET LIVES'),
                  findsOneWidget,
                );
                expect(scores.starts, 0);
                expect(economy.lives, 0);
                expect(economy.tokens, scale == 1 ? 0 : 999);
                for (final position in [
                  tester.getCenter(field),
                  tester.getRect(field).bottomCenter + const Offset(0, 10),
                ]) {
                  // Close first, then tap the field or background below it.
                  await tester.tapAt(const Offset(2, 2));
                  await tester.pump(const Duration(milliseconds: 400));
                  expect(
                    find.byKey(const ValueKey('lives-floating-window')),
                    findsNothing,
                  );
                  await tester.tapAt(position);
                  await tester.pump(const Duration(milliseconds: 400));
                  expect(
                    find.byKey(
                      const ValueKey('lives-floating-window'),
                      skipOffstage: false,
                    ),
                    findsOneWidget,
                  );
                  expect(scores.starts, 0);
                  expect(economy.lives, 0);
                  expect(economy.tokens, scale == 1 ? 0 : 999);
                }
                await tester.tapAt(const Offset(2, 2));
                await tester.pump(const Duration(milliseconds: 400));
                await tester.tap(
                  find.byKey(const ValueKey('hud-crystals-card')),
                );
                await tester.pump(const Duration(milliseconds: 400));
                expect(
                  find.byKey(const ValueKey('shop-tab-menu')),
                  findsOneWidget,
                );
                expect(
                  find.byKey(const ValueKey('lives-floating-window')),
                  findsNothing,
                );
                expect(scores.starts, 0);
                expect(economy.tokens, scale == 1 ? 0 : 999);
              }
              expect(tester.takeException(), isNull, reason: layoutError);
              await tester.pumpWidget(const SizedBox());
              economy.dispose();
              scores.dispose();
            },
          );
        }
      }
    }
  }
}
