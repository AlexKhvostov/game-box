import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/economy_config.dart';
import 'package:game_box/ui/between_round_ad_break.dart';

class _Driver implements AdsDriver {
  final loaded = Completer<void>();
  int loads = 0, shown = 0, rewarded = 0;
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async {
    rewarded++;
    return AdOutcome.dismissed;
  }

  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async {
    loads++;
    await loaded.future;
    if (!canShow()) return false;
    shown++;
    return true;
  }
}

void main() {
  for (final mode in [
    'shown',
    'skip',
    'background',
    'new-round',
    'revoke',
    'navigation',
  ]) {
    testWidgets(
      'between-round break: $mode; no late ad or reward',
      (t) async {
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        SharedPreferences.setMockInitialValues({});
        final policy = AudiencePolicy();
        await policy.load();
        await policy.select(AgeBand.adult18plus);
        await policy.setAdDataConsent(true);
        final economy = EconomyStore(
          config: const EconomyConfig(
            interstitialGraceSec: 0,
            interstitialSessionFreeRounds: 0,
            interstitialSessionGraceSec: 0,
            interstitialCooldownSec: 9,
          ),
        );
        await economy.load();
        economy.lives = 30;
        economy.interstitialArmedAt = DateTime(2000);
        economy.recordCompletedRound();
        final driver = _Driver();
        final ads = AdsService(driver, audience: policy);
        var sameRound = true, returned = false;
        await t.pumpWidget(
          ChangeNotifierProvider.value(
            value: policy,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      await showBetweenRoundAdBreak(
                        context,
                        ads: ads,
                        economy: economy,
                        canShow: () => sameRound,
                      );
                      returned = true;
                    },
                    child: const Text('Finish results'),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Finish results'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 250));
        expect(driver.loads, 1);
        expect(returned, false);
        if (mode == 'skip') {
          await t.tap(find.byKey(const ValueKey('ad-break-skip')));
          await t.pumpAndSettle();
          expect(returned, true);
        } else if (mode == 'background') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        } else if (mode == 'new-round') {
          sameRound = false;
        } else if (mode == 'revoke') {
          await policy.setAdDataConsent(false);
          await policy.setAdDataConsent(true);
        } else if (mode == 'navigation') {
          unawaited(
            Navigator.of(
              t.element(find.byKey(const ValueKey('between-round-ad-break'))),
            ).push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Different screen')),
              ),
            ),
          );
          await t.pumpAndSettle();
        }
        driver.loaded.complete();
        await t.pumpAndSettle();
        expect(driver.shown, mode == 'shown' ? 1 : 0);
        expect(economy.lastInterstitialAt != null, mode == 'shown');
        expect(driver.rewarded, 0);
        expect(returned, true);
        expect(
          find.byKey(const ValueKey('between-round-ad-break')),
          findsNothing,
        );
        expect(t.takeException(), null);
        if (mode == 'navigation') {
          expect(find.text('Different screen'), findsOneWidget);
        }
        await t.pumpWidget(const SizedBox());
        ads.dispose();
        economy.dispose();
        policy.dispose();
      },
      skip: !AudiencePolicy.adsBuildEnabled,
    );
  }
}
