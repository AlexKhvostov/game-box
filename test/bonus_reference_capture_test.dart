import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'simple_energy_test.dart' as fixture;
import 'neon_account_hud_test.dart' show saveFrame;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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
    final icons = Platform.environment['RANKING_ICON_FONT'];
    if (icons != null) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(await File(icons).readAsBytes())),
          ))
          .load();
    }
  });

  testWidgets('Reference states and confirmed reward frames at real width', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final key = GlobalKey();
    final e = await fixture.store();
    addTearDown(e.dispose);
    e.sendEnergyOperation = (_, _) async => e.applyServerWallet(
      fixture.simpleWallet(balance: 80, nextAt: fixture.stamp + 28800000),
      serverNow: fixture.stamp,
      owner: 'android:1',
    );
    await t.pumpWidget(RepaintBoundary(key: key, child: fixture.app(e)));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await saveFrame(t, 'bonus-ready', find.byKey(key));
    await t.tap(find.byKey(const ValueKey('simple-bonus-orb')));
    await t.pump();
    for (final frame in [1, 2, 3, 4]) {
      await t.pump(const Duration(milliseconds: 250));
      await saveFrame(t, 'bonus-claim-$frame', find.byKey(key));
    }
    await t.pumpAndSettle();
    await saveFrame(t, 'bonus-cooldown', find.byKey(key));
    expect(e.energy, 80);
    expect(
      find.byKey(const ValueKey('bonus-confirmed-celebration')),
      findsNothing,
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
