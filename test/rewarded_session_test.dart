import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'simple_energy_test.dart' as fixture;

class RewardAudience extends AudiencePolicy {
  bool enabled = true;
  @override
  bool get rewardedAdsEnabled => enabled;
}

class SessionDriver implements AdsDriver {
  final result = Completer<AdOutcome>();
  int loads = 0;
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) {
    loads++;
    return result.future;
  }

  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final outcome in [
    AdOutcome.rewarded,
    AdOutcome.dismissed,
    AdOutcome.unavailable,
  ]) {
    test(
      'server session precedes SDK; $outcome only credits completed reward',
      () async {
        final e = await fixture.store();
        final audience = RewardAudience(), driver = SessionDriver();
        final ads = AdsService(driver, audience: audience);
        final events = <String>[];
        String? session;
        e.sendEnergyOperation = (kind, args) async {
          events.add(kind);
          expect(args.keys, ['sessionId']);
          if (kind == 'rewarded_ad_start') {
            expect(driver.loads, 0);
            session = args['sessionId'] as String;
            expect(session, matches(RegExp(r'^[a-f0-9]{64}$')));
          } else {
            expect(kind, 'watch_ad');
            expect(args['sessionId'], session);
            await e.applyServerWallet(
              {...fixture.simpleWallet(balance: 90), 'lastAdAt': fixture.stamp},
              serverNow: fixture.stamp,
              owner: 'android:1',
            );
          }
        };
        final pending = ads.watchAndClaim(e);
        await Future<void>.delayed(Duration.zero);
        expect(driver.loads, 1);
        expect((await ads.watchAndClaim(e)).outcome, AdOutcome.busy);
        driver.result.complete(outcome);
        final result = await pending;
        expect(result.reward, outcome == AdOutcome.rewarded ? 40 : 0);
        expect(events, [
          'rewarded_ad_start',
          if (outcome == AdOutcome.rewarded) 'watch_ad',
        ]);
        expect(e.energy, outcome == AdOutcome.rewarded ? 90 : 50);
        expect(ads.busy, false);
        ads.dispose();
        audience.dispose();
        e.dispose();
      },
    );
  }
  test('denied session never presents SDK; no balance change', () async {
    final e = await fixture.store(), d = SessionDriver(), a = RewardAudience();
    final ads = AdsService(d, audience: a);
    e.sendEnergyOperation = (_, _) async => throw StateError('offline');
    final result = await ads.watchAndClaim(e);
    expect(result.reward, 0);
    expect(d.loads, 0);
    expect(e.energy, 50);
    expect(ads.lastFailure, AdFailure.confirmation);
    expect(ads.busy, false);
    ads.dispose();
    a.dispose();
    e.dispose();
  });
  for (final change in ['owner', 'route', 'consent']) {
    test(
      '$change changed during session preparation prevents presentation',
      () async {
        final e = await fixture.store(),
            d = SessionDriver(),
            a = RewardAudience();
        final ads = AdsService(d, audience: a), gate = Completer<void>();
        var route = true;
        e.sendEnergyOperation = (_, _) => gate.future;
        final pending = ads.watchAndClaim(e, canShow: () => route);
        if (change == 'owner') {
          await e.applyServerWallet(
            fixture.simpleWallet(balance: 123),
            serverNow: fixture.stamp,
            owner: 'android:2',
          );
        } else if (change == 'route') {
          route = false;
        } else {
          a.enabled = false;
        }
        gate.complete();
        expect((await pending).reward, 0);
        expect(d.loads, 0);
        expect(e.energy, change == 'owner' ? 123 : 50);
        ads.dispose();
        a.dispose();
        e.dispose();
      },
    );
  }
}
