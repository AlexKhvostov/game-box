import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/ui/game_ui.dart';

List<Color> core(WidgetTester t, Key key) {
  final containers = find.descendant(
    of: find.byKey(key),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).gradient is LinearGradient,
    ),
  );
  return ((t.widget<Container>(containers.last).decoration! as BoxDecoration)
              .gradient!
          as LinearGradient)
      .colors;
}

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

void main() {
  testWidgets(
    'Shared neon preserves default, explicit dark and disabled button contrast; links stay quiet',
    (t) async {
      var taps = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: buildGameTheme(),
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(
                  key: const ValueKey('default'),
                  onPressed: () => taps++,
                  child: const Text('Default'),
                ),
                OutlinedButton(
                  key: const ValueKey('dark'),
                  style: OutlinedButton.styleFrom(foregroundColor: GameUi.ink),
                  onPressed: () => taps++,
                  child: const Text('Dark foreground'),
                ),
                FilledButton(
                  key: const ValueKey('explicit'),
                  onPressed: () => taps++,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, color: GameUi.ink),
                      Text(
                        'Explicit text',
                        style: TextStyle(color: GameUi.ink),
                      ),
                    ],
                  ),
                ),
                const FilledButton(
                  key: ValueKey('disabled'),
                  onPressed: null,
                  child: Text('Disabled'),
                ),
                TextButton(
                  key: const ValueKey('quiet'),
                  style: TextButton.styleFrom(
                    foregroundColor: GameUi.muted,
                    backgroundColor: Colors.transparent,
                  ),
                  onPressed: () => taps++,
                  child: const Text('Отключить'),
                ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      for (final row in [
        ('default', GameUi.text),
        ('dark', GameUi.ink),
        ('explicit', GameUi.ink),
        ('disabled', GameUi.muted),
      ]) {
        for (final color in core(t, ValueKey(row.$1))) {
          expect(
            contrast(row.$2, color),
            greaterThanOrEqualTo(4.5),
            reason: '${row.$1} readable against every core gradient stop',
          );
        }
        final size = t.getSize(find.byKey(ValueKey(row.$1)));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      final quiet = t.widget<TextButton>(find.byKey(const ValueKey('quiet')));
      expect(quiet.style!.backgroundBuilder, isNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('quiet')),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).gradient != null,
          ),
        ),
        findsNothing,
      );
      await t.tap(find.byKey(const ValueKey('default')));
      await t.tap(find.byKey(const ValueKey('quiet')));
      expect(taps, 2);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Shared neon layer does not add layout around the former primary frame',
    (t) async {
      const oldStyle = ButtonStyle();
      Widget legacy(BuildContext c, Set<WidgetState> states, Widget? child) =>
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(border: Border.all(width: 1)),
            child: Center(child: child),
          );
      final theme = buildGameTheme();
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(
                  key: const ValueKey('new'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(100, 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () {},
                  child: const Text('Google connect'),
                ),
                FilledButton(
                  key: const ValueKey('old'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(100, 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ).copyWith(backgroundBuilder: legacy),
                  onPressed: () {},
                  child: const Text('Google connect'),
                ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.getSize(find.byKey(const ValueKey('new'))),
        t.getSize(find.byKey(const ValueKey('old'))),
      );
      expect(oldStyle.foregroundColor, isNull);
      expect(t.takeException(), isNull);
    },
  );
}
