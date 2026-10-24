import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/android_updates.dart';
import 'package:game_box/ui/android_update_host.dart';
import 'android_updates_test.dart'
    show FakePlayUpdates, downloaded, downloading;

class UpdateHarness extends StatefulWidget {
  const UpdateHarness({super.key, required this.updates, this.safe = true});
  final AndroidUpdates updates;
  final bool safe;
  @override
  State<UpdateHarness> createState() => UpdateHarnessState();
}

class UpdateHarnessState extends State<UpdateHarness> {
  late bool safe = widget.safe;
  void setSafe(bool value) => setState(() => safe = value);
  @override
  Widget build(BuildContext context) => AndroidUpdateHost(
    controller: widget.updates,
    safeToInterrupt: safe,
    child: Scaffold(
      body: Column(
        children: [
          TextButton(
            key: const ValueKey('play'),
            onPressed: () => setSafe(false),
            child: const Text('Play'),
          ),
          TextButton(
            key: const ValueKey('other-window'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                content: const Text('Other window'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            child: const Text('Open other window'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  late AndroidUpdates updates;
  late FakePlayUpdates source;
  late GlobalKey<UpdateHarnessState> key;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    source = FakePlayUpdates();
    key = GlobalKey();
    updates = AndroidUpdates(
      source: source,
      preferences: await SharedPreferences.getInstance(),
      prepareForRestart: () async {},
    );
  });
  tearDown(() async {
    updates.dispose();
    await source.stream.close();
  });
  Future<void> mount(WidgetTester t, {bool safe = true}) async {
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: UpdateHarness(key: key, updates: updates, safe: safe),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  Future<void> stop(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
  }

  testWidgets(
    'No offer, banner or restart during a party; ready waits for idle',
    (t) async {
      await updates.start();
      await mount(t, safe: false);
      expect(find.byType(AndroidUpdateDialog), findsNothing);
      source.send(downloading);
      await t.pump();
      expect(find.byType(AndroidUpdateBanner), findsNothing);
      source.send(downloaded);
      await t.pump();
      expect(find.byType(AndroidUpdateDialog), findsNothing);
      key.currentState!.setSafe(true);
      await t.pump();
      await t.pumpAndSettle();
      expect(find.text('Установить обновление?'), findsWidgets);
      expect(source.completions, 0);
      await stop(t);
    },
  );
  testWidgets('Download in background, Later leaves a manual ready button', (
    t,
  ) async {
    await updates.start();
    await mount(t);
    expect(
      find.byKey(const ValueKey('update-dialog-available')),
      findsOneWidget,
    );
    source.current = downloading;
    await t.tap(find.byKey(const ValueKey('update-primary')));
    await t.pumpAndSettle();
    expect(find.text('Обновление'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('play')));
    await t.pump();
    expect(find.byType(AndroidUpdateBanner), findsNothing);
    source.send(downloaded);
    await t.pump();
    expect(find.byType(AndroidUpdateDialog), findsNothing);
    key.currentState!.setSafe(true);
    await t.pump();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('update-later')));
    await t.pumpAndSettle();
    expect(find.byType(AndroidUpdateDialog), findsNothing);
    expect(find.text('Обновление загружено'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(
      t
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('update-download-progress')),
          )
          .value,
      1,
    );
    await updates.refresh(force: true);
    await t.pumpAndSettle();
    expect(find.byType(AndroidUpdateDialog), findsNothing);
    expect(source.completions, 0);
    await t.tap(find.byKey(const ValueKey('update-ready-action')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-dialog-ready')), findsOneWidget);
    await stop(t);
  });
  testWidgets('Another modal is not covered by update prompt', (t) async {
    await mount(t);
    await t.tap(find.byKey(const ValueKey('other-window')));
    await t.pumpAndSettle();
    source.current = downloaded;
    await updates.start();
    await t.pumpAndSettle();
    expect(find.text('Other window'), findsOneWidget);
    expect(find.byType(AndroidUpdateDialog), findsNothing);
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-dialog-ready')), findsOneWidget);
    await stop(t);
  });
  testWidgets('Ready event while backgrounded waits until foreground', (
    t,
  ) async {
    await updates.start();
    await mount(t, safe: false);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    source.send(downloaded);
    key.currentState!.setSafe(true);
    await t.pump();
    expect(find.byType(AndroidUpdateDialog), findsNothing);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(find.byType(AndroidUpdateDialog), findsOneWidget);
    await stop(t);
  });
  testWidgets('Back dismissal of ready prompt is Later, never an install', (
    t,
  ) async {
    source.current = downloaded;
    await updates.start();
    await mount(t);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(AndroidUpdateDialog), findsNothing);
    expect(updates.prompt, isNull);
    expect(source.completions, 0);
    await stop(t);
  });
  testWidgets('Neon close button defers a ready update without installing', (
    t,
  ) async {
    source.current = downloaded;
    await updates.start();
    await mount(t);
    await t.tap(find.byKey(const ValueKey('update-close')));
    await t.pumpAndSettle();
    expect(find.byType(AndroidUpdateDialog), findsNothing);
    expect(find.text('Обновление загружено'), findsOneWidget);
    expect(updates.prompt, isNull);
    expect(source.completions, 0);
    await stop(t);
  });
  testWidgets('Initial Later retains a manual Download action', (t) async {
    await updates.start();
    await mount(t);
    await t.tap(find.byKey(const ValueKey('update-later')));
    await t.pumpAndSettle();
    expect(find.byType(AndroidUpdateBanner), findsOneWidget);
    expect(source.starts, 0);
    await t.tap(find.text('Скачать'));
    await t.pumpAndSettle();
    expect(find.byType(AndroidUpdateDialog), findsOneWidget);
    await stop(t);
  });
  for (final size in [
    const Size(320, 480),
    const Size(360, 780),
    const Size(430, 900),
  ]) {
    for (final ru in [true, false]) {
      testWidgets(
        'All dialogs readable at $size, ${ru ? 'RU' : 'EN'}, enlarged text',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          for (final prompt in UpdatePrompt.values) {
            await t.pumpWidget(
              MaterialApp(
                builder: (c, child) => MediaQuery(
                  data: MediaQuery.of(
                    c,
                  ).copyWith(textScaler: const TextScaler.linear(1.6)),
                  child: child!,
                ),
                home: Scaffold(
                  body: AndroidUpdateDialog(prompt: prompt, russian: ru),
                ),
              ),
            );
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            final primary = find.byKey(const ValueKey('update-primary'));
            await t.ensureVisible(primary);
            expect(t.getRect(primary).width, greaterThan(200));
          }
          await stop(t);
        },
      );
    }
  }
  testWidgets(
    'Failed persistence keeps game and shows retry instead of restarting',
    (t) async {
      updates.dispose();
      updates = AndroidUpdates(
        source: source,
        preferences: await SharedPreferences.getInstance(),
        prepareForRestart: () async {
          throw StateError('disk');
        },
      );
      source.current = downloaded;
      await updates.start();
      await mount(t);
      await t.tap(find.byKey(const ValueKey('update-primary')));
      await t.pumpAndSettle();
      expect(find.text('Не удалось обновить'), findsOneWidget);
      expect(source.completions, 0);
      await t.tap(find.byKey(const ValueKey('update-later')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('play')), findsOneWidget);
      await stop(t);
    },
  );
}
