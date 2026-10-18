import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/ui/energy_reward_motion.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'simple_energy_test.dart' as fixture;

class PermittedRewardAudience extends AudiencePolicy {
  @override
  bool get adsEnabled => true;
  @override
  AgeBand? get band => AgeBand.adult18plus;
}

// Animation/ACK fixture only: no real provider receipt or SDK is exercised.
class VerifiedFixtureAds extends AdsService {
  VerifiedFixtureAds(super.driver, {required super.audience});
  @override
  bool get rewardVerificationAvailable => true;
}

class ControlledRewardDriver implements AdsDriver {
  final result = Completer<AdOutcome>();
  int loads = 0;
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) {
    loads++;
    if (!(canShow?.call() ?? true)) return Future.value(AdOutcome.unavailable);
    return result.future;
  }

  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async =>
      false;
}

const effect = ValueKey('bonus-confirmed-celebration');
void main() {
  setUp(
    () => TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed),
  );
  test(
    'Final JS choreography: read until640ms, arc midpoint960, counter rolls1280–1600',
    () {
      final read = EnergyRewardFrame(.4, reduced: false);
      expect(read.flight, 0);
      expect(read.scale, closeTo(1, .0001));
      expect(read.opacity, 1);
      expect(read.roll, 0);
      final mid = EnergyRewardFrame(.6, reduced: false);
      final midpoint = mid.position(
        const Offset(100, 300),
        const Offset(300, 100),
      );
      expect(midpoint.dx, closeTo(200, .0001));
      expect(midpoint.dy, closeTo(170, .0001));
      expect(mid.scale, closeTo(.61, .0001));
      expect(EnergyRewardFrame(.75, reduced: false).roll, 0);
      expect(EnergyRewardFrame(.95, reduced: false).roll, closeTo(.75, .0001));
      final reduced = EnergyRewardFrame(.6, reduced: true);
      expect(
        reduced.position(const Offset(100, 300), const Offset(300, 100)),
        const Offset(100, 300),
      );
      expect(reduced.scale, 1);
      expect(reduced.hit, 0);
      expect(reduced.roll, .6);
    },
  );

  for (final outcome in [
    AdOutcome.rewarded,
    AdOutcome.dismissed,
    AdOutcome.unavailable,
  ]) {
    testWidgets(
      'Video $outcome: only SDK reward plus ACK returns to energy and celebrates once',
      (t) async {
        final e = await fixture.store(nextAt: fixture.stamp + 14400000);
        final audience = PermittedRewardAudience(),
            driver = ControlledRewardDriver();
        final ads = VerifiedFixtureAds(driver, audience: audience);
        addTearDown(() {
          ads.dispose();
          audience.dispose();
          e.dispose();
        });
        final ack = Completer<void>();
        var grants = 0;
        e.sendEnergyOperation = (kind, args) async {
          expect(kind, 'watch_ad');
          grants++;
          await ack.future;
          await e.applyServerWallet(
            {
              ...fixture.simpleWallet(
                balance: 90,
                nextAt: fixture.stamp + 14400000,
              ),
              'lastAdAt': fixture.stamp,
            },
            serverNow: fixture.stamp,
            owner: 'android:1',
          );
        };
        await t.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AudiencePolicy>.value(value: audience),
              ChangeNotifierProvider<AdsService>.value(value: ads),
            ],
            child: fixture.app(e, page: EnergyPage.energy),
          ),
        );
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('simple-energy-video')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('simple-energy-video')));
        await t.pump();
        expect(driver.loads, 1);
        expect(e.energy, 50);
        expect(find.byKey(effect), findsNothing);
        driver.result.complete(outcome);
        await t.pump();
        if (outcome == AdOutcome.rewarded) {
          expect(grants, 1);
          expect(e.energy, 50);
          expect(find.byKey(effect), findsNothing);
          ack.complete();
          await t.pump();
          await t.pump();
          await t.pump(const Duration(milliseconds: 200));
          expect(e.energy, 90);
          expect(find.byKey(effect), findsOneWidget);
          expect(
            find.byKey(const ValueKey('energy-reward-payout')),
            findsOneWidget,
          );
          expect(find.text('+40'), findsOneWidget);
          expect(find.text('Энергия получена!'), findsOneWidget);
          expect(find.text('Энергия за рекламу'), findsNothing);
          expect(e.simpleEnergyBonus!.nextAtMs, fixture.stamp + 14400000);
          expect(
            e.watchAdCooldownRemaining!.inSeconds,
            inInclusiveRange(118, 120),
          );
          await t.pumpAndSettle();
          expect(find.byKey(effect), findsNothing);
          expect(grants, 1);
        } else {
          expect(grants, 0);
          expect(e.energy, 50);
          expect(find.byKey(effect), findsNothing);
          expect(
            find.byKey(const ValueKey('simple-energy-video')),
            findsOneWidget,
          );
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('SDK success with failed ACK never celebrates/credits', (
    t,
  ) async {
    final e = await fixture.store();
    final a = PermittedRewardAudience(), d = ControlledRewardDriver();
    final ads = VerifiedFixtureAds(d, audience: a);
    addTearDown(() {
      ads.dispose();
      a.dispose();
      e.dispose();
    });
    e.sendEnergyOperation = (_, _) async => throw StateError('offline');
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AudiencePolicy>.value(value: a),
          ChangeNotifierProvider<AdsService>.value(value: ads),
        ],
        child: fixture.app(e, page: EnergyPage.video),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('simple-watch-video')));
    await t.pump();
    d.result.complete(AdOutcome.rewarded);
    await t.pumpAndSettle();
    expect(e.energy, 50);
    expect(find.byKey(effect), findsNothing);
    expect(ads.lastFailure, AdFailure.confirmation);
    expect(
      find.textContaining('Не удалось подтвердить награду'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Reward from old profile does not submit a claim in new profile',
    (t) async {
      final e = await fixture.store();
      final a = PermittedRewardAudience(), d = ControlledRewardDriver();
      final ads = VerifiedFixtureAds(d, audience: a);
      addTearDown(() {
        ads.dispose();
        a.dispose();
        e.dispose();
      });
      var claims = 0;
      e.sendEnergyOperation = (_, _) async {
        claims++;
      };
      final job = ads.watchAndClaim(e);
      await e.applyServerWallet(
        fixture.simpleWallet(balance: 123),
        serverNow: fixture.stamp,
        owner: 'android:2',
      );
      d.result.complete(AdOutcome.rewarded);
      final result = await job;
      expect(result.reward, 0);
      expect(claims, 0);
      expect(e.energy, 123);
    },
  );

  testWidgets('A dismissed window stays closed when rewarded ACK arrives', (
    t,
  ) async {
    final e = await fixture.store();
    final a = PermittedRewardAudience(), d = ControlledRewardDriver();
    final ads = VerifiedFixtureAds(d, audience: a);
    addTearDown(() {
      ads.dispose();
      a.dispose();
      e.dispose();
    });
    e.sendEnergyOperation = (_, _) => e.applyServerWallet(
      {...fixture.simpleWallet(balance: 90), 'lastAdAt': fixture.stamp},
      serverNow: fixture.stamp,
      owner: 'android:1',
    );
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AudiencePolicy>.value(value: a),
          ChangeNotifierProvider<AdsService>.value(value: ads),
        ],
        child: fixture.app(e, page: EnergyPage.video),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('simple-watch-video')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('simple-energy-close')));
    await t.pumpAndSettle();
    d.result.complete(AdOutcome.rewarded);
    await t.pumpAndSettle();
    expect(e.energy, 90);
    expect(find.byKey(effect), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(find.byKey(const ValueKey('simple-energy-window')), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Actual ACK amount replaces a stale configured advertisement amount',
    (t) async {
      final e = await fixture.store();
      final a = PermittedRewardAudience(), d = ControlledRewardDriver();
      final ads = VerifiedFixtureAds(d, audience: a);
      addTearDown(() {
        ads.dispose();
        a.dispose();
        e.dispose();
      });
      e.sendEnergyOperation = (_, _) => e.applyServerWallet(
        {...fixture.simpleWallet(balance: 87), 'lastAdAt': fixture.stamp},
        serverNow: fixture.stamp,
        owner: 'android:1',
      );
      final job = ads.watchAndClaim(e);
      d.result.complete(AdOutcome.rewarded);
      final result = await job;
      expect(result.reward, 37);
      expect(e.energy, 87);
    },
  );

  testWidgets(
    'Reduced180ms has no flight painter, no scale, and ends on time',
    (t) async {
      final key = GlobalKey<EnergyRewardMotionState>();
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              disableAnimations: true,
            ),
            child: Center(
              child: EnergyRewardMotion(
                key: key,
                child: const SizedBox(width: 320, height: 500),
              ),
            ),
          ),
        ),
      );
      key.currentState!.play(
        from: const Offset(200, 300),
        to: const Offset(270, 80),
        amount: 30,
        before: 50,
        after: 80,
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 179));
      expect(find.byKey(effect), findsOneWidget);
      expect(key.currentState!.frame.scale, 1);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_MotesPainter',
        ),
        findsNothing,
      );
      await t.pump(const Duration(milliseconds: 2));
      expect(find.byKey(effect), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      expect(t.takeException(), isNull);
    },
  );

  for (final cause in ['owner', 'background', 'resize', 'route', 'scroll']) {
    testWidgets(
      'Cancel $cause restores underlying UI and preserves settled value',
      (t) async {
        final key = GlobalKey<EnergyRewardMotionState>();
        var owner = 'one';
        var ticker = true;
        var size = const Size(800, 600);
        Widget app() => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: TickerMode(
              enabled: ticker,
              child: Center(
                child: EnergyRewardMotion(
                  key: key,
                  owner: owner,
                  child: SizedBox(
                    width: 320,
                    height: 500,
                    child: Column(
                      children: [
                        const EnergyRewardBalance(amount: 80),
                        const EnergyRewardDim(
                          source: true,
                          child: Text('old orb'),
                        ),
                        Expanded(
                          child: ListView(
                            children: List.generate(
                              20,
                              (i) => SizedBox(height: 50, child: Text('row$i')),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpWidget(app());
        expect(
          key.currentState!.play(
            from: const Offset(350, 350),
            to: const Offset(400, 100),
            amount: 30,
            before: 50,
            after: 80,
            operationId: 'operationA',
          ),
          isTrue,
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byKey(effect), findsOneWidget);
        final source = find.byType(EnergyRewardDim);
        expect(
          t
              .widget<Opacity>(
                find
                    .descendant(of: source, matching: find.byType(Opacity))
                    .first,
              )
              .opacity,
          1,
        );
        if (cause == 'owner') {
          owner = 'two';
          await t.pumpWidget(app());
        }
        if (cause == 'resize') {
          size = const Size(790, 600);
          await t.pumpWidget(app());
        }
        if (cause == 'route') {
          ticker = false;
          await t.pumpWidget(app());
        }
        if (cause == 'background') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        }
        if (cause == 'scroll') {
          await t.drag(find.byType(ListView), const Offset(0, -100));
        }
        await t.pump();
        expect(find.byKey(effect), findsNothing);
        expect(
          t
              .widget<EnergyRewardBalance>(find.byType(EnergyRewardBalance))
              .amount,
          80,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    '1600ms finish, replay is ignored; reduced180ms and one live region',
    (t) async {
      final semantics = t.ensureSemantics();
      final key = GlobalKey<EnergyRewardMotionState>();
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          home: Center(
            child: EnergyRewardMotion(
              key: key,
              child: const SizedBox(width: 320, height: 500),
            ),
          ),
        ),
      );
      bool play(String id) => key.currentState!.play(
        from: const Offset(200, 300),
        to: const Offset(270, 80),
        amount: 150,
        before: 50,
        after: 200,
        operationId: id,
      );
      expect(play('A'), isTrue);
      await t.pump();
      await t.pump(const Duration(milliseconds: 640));
      expect(find.text('+150'), findsOneWidget);
      expect(play('A'), isFalse);
      expect(play('B'), isFalse);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
      await t.pump(const Duration(milliseconds: 959));
      expect(find.byKey(effect), findsOneWidget);
      await t.pump(const Duration(milliseconds: 2));
      expect(find.byKey(effect), findsNothing);
      expect(play('B'), isTrue);
      key.currentState!.cancel();
      expect(play('A'), isFalse);
      await t.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
      expect(t.takeException(), isNull);
    },
  );
}
