import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'package:game_box/ui/energy_reward_motion.dart';
import 'simple_energy_test.dart' as fixture;
import 'energy_reward_motion_test.dart'
    show PermittedRewardAudience, ControlledRewardDriver;
import 'neon_account_hud_test.dart' show saveFrame;

void main() {
  setUp(
    () => TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed),
  );
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final folder = Platform.environment['RANKING_FONT_DIR'];
    if (folder == null) return;
    final loader = FontLoader('Roboto');
    for (final n in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$folder/$n').readAsBytes()),
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
  for (final mode in ['bonus30', 'video40', 'bonus150-large']) {
    testWidgets('Final1600ms Energy Burst capture $mode', (t) async {
      final large = mode.contains('large'), video = mode == 'video40';
      final amount = large
          ? 150
          : video
          ? 40
          : 30;
      await t.binding.setSurfaceSize(Size(large ? 320 : 360, 780));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final e = await fixture.store(
        tier: large ? 5 : 1,
        nextAt: video ? fixture.stamp + 14400000 : 0,
      );
      final a = PermittedRewardAudience(),
          d = ControlledRewardDriver(),
          key = GlobalKey();
      final ads = AdsService(d, audience: a);
      addTearDown(() {
        ads.dispose();
        a.dispose();
        e.dispose();
      });
      e.sendEnergyOperation = (_, _) => e.applyServerWallet(
        {
          ...fixture.simpleWallet(
            balance: 50 + amount,
            tier: large ? 5 : 1,
            nextAt: fixture.stamp + (video ? 14400000 : 28800000),
          ),
          if (video) 'lastAdAt': fixture.stamp,
        },
        serverNow: fixture.stamp,
        owner: 'android:1',
      );
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<AudiencePolicy>.value(value: a),
              ChangeNotifierProvider<AdsService>.value(value: ads),
            ],
            child: fixture.app(
              e,
              page: video ? EnergyPage.video : EnergyPage.energy,
              scale: large ? 2 : 1,
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await saveFrame(t, '$mode-before', find.byKey(key));
      await t.tap(
        find.byKey(ValueKey(video ? 'simple-watch-video' : 'simple-bonus-orb')),
      );
      if (video) d.result.complete(AdOutcome.rewarded);
      await t.pump();
      await t.pump();
      await t.pump();
      final motion = t.state<EnergyRewardMotionState>(
        find.byType(EnergyRewardMotion),
      );
      expect(motion.isActive, isTrue);
      var elapsed = 0;
      final records = <Map<String, dynamic>>[];
      for (final ms in [160, 640, 960, 1200, 1520, 1601]) {
        await t.pump(Duration(milliseconds: ms - elapsed));
        elapsed = ms;
        await saveFrame(t, '$mode-$ms', find.byKey(key));
        records.add({
          'ms': ms,
          'active': motion.isActive,
          'progress': motion.frame.p,
          'balance': e.energy,
        });
      }
      final folder = Platform.environment['ACCOUNT_HUD_EVIDENCE'];
      if (folder != null) {
        await t.runAsync(
          () => File(
            '$folder/$mode-timeline.json',
          ).writeAsString(jsonEncode(records)),
        );
      }
      expect(motion.isActive, isFalse);
      expect(e.energy, 50 + amount);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
}
