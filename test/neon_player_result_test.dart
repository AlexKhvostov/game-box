import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/leaderboard/player_result_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';

Future<void> resultCapture(WidgetTester tester, String name) async {
  final folder = Platform.environment['ACCOUNT_HUD_EVIDENCE'];
  if (folder == null) return;
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('player-result-frame')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(folder).create(recursive: true);
    await File('$folder/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final folder = Platform.environment['RANKING_FONT_DIR'];
    if (folder == null) return;
    final loader = FontLoader('Roboto');
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$folder/$name').readAsBytes()),
        ),
      );
    }
    await loader.load();
    await (FontLoader('Ahem')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('$folder/Roboto-Regular.ttf').readAsBytes(),
            ),
          ),
        ))
        .load();
    final icons = Platform.environment['RANKING_ICON_FONT'];
    if (icons != null) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(await File(icons).readAsBytes())),
          ))
          .load();
    }
  });
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final mode in ['both', 'one', 'none-long']) {
        testWidgets(
          'native result $width text$scale $mode passive values and four tips',
          (tester) async {
            final long = mode == 'none-long';
            final entry = ScoreEntry(
              id: 'local-fixture',
              displayName: long
                  ? 'ОченьДлинноеИгровоеИмя1234567890АБВГДЕЖЗИЙ'
                  : mode == 'both'
                  ? 'NeonFox'
                  : 'Вы',
              timeMs: long
                  ? 123456
                  : mode == 'both'
                  ? 31000
                  : 27108,
              createdAt: DateTime(2026, 10, 17, 0, 52),
              countryCode: long ? '--' : 'BY',
              riskCount: long ? 128 : 8,
              runDistance: long ? 123456 : 435,
              hadJump: mode != 'none-long',
              hadHelmet: mode == 'both',
            );
            await tester.binding.setSurfaceSize(Size(width, 740));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              MaterialApp(
                theme: buildGameTheme(),
                locale: const Locale('ru'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showPlayerResultSheet(
                        context,
                        entry: entry,
                        place: mode == 'one' ? 5 : 1,
                        periodLabel: 'День',
                        own: mode == 'one',
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('open'));
            await tester.pumpAndSettle();
            expect(
              find.text('${entry.timeSec.toStringAsFixed(3)} с'),
              findsOneWidget,
            );
            expect(find.text('Очки попытки: ${entry.score}'), findsOneWidget);
            expect(find.text('--'), findsNothing);
            expect(
              find.text('Это ваш личный результат'),
              mode == 'one' ? findsOneWidget : findsNothing,
            );
            for (final key in ['player-time', 'player-points']) {
              expect(
                find.ancestor(
                  of: find.byKey(ValueKey(key)),
                  matching: find.byType(ButtonStyleButton),
                ),
                findsNothing,
                reason: 'Time and points are passive',
              );
            }
            expect(tester.takeException(), isNull);
            await resultCapture(
              tester,
              'player-result-${width.toInt()}-$scale-$mode',
            );
            for (final name in ['run', 'risk', 'jump', 'helmet']) {
              final control = find.byKey(ValueKey('player-$name'));
              await tester.ensureVisible(control);
              await tester.pumpAndSettle();
              await tester.tap(control);
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('player-stat-tip')),
                findsOneWidget,
              );
              if (width == 320 && scale == 1 && mode == 'both') {
                await resultCapture(tester, 'player-result-tip-$name');
              }
              await tester.ensureVisible(control);
              await tester.pumpAndSettle();
              await tester.tap(control);
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('player-stat-tip')),
                findsNothing,
              );
              expect(tester.takeException(), isNull);
            }
            await tester.tap(find.byKey(const ValueKey('player-close')));
            await tester.pumpAndSettle();
            expect(find.byType(PlayerResultSheet), findsNothing);
          },
        );
      }
    }
  }
}
