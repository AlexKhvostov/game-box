import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'friend_invites_profile_test.dart' as profile;
import 'simple_energy_test.dart' as wallet;
import 'support/android_test_fonts.dart';

class _RecordingDriver implements AdsDriver {
  int calls = 0;
  bool? savedConsentAtLaunch;

  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async {
    final stored = AudiencePolicy();
    await stored.load();
    savedConsentAtLaunch = stored.adDataConsent;
    stored.dispose();
    if (canShow?.call() == false) return AdOutcome.unavailable;
    calls++;
    return AdOutcome.dismissed;
  }

  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async =>
      false;
}

void main() {
  setUpAll(() => loadAndroidTestFonts(replaceAhem: true, icons: true));

  testWidgets(
    'Help privacy revoke → energy guide launch → durable consent before ads',
    (t) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final account = profile.BindAccount();
      final invites = profile.ProfileInvites(account)..emit();
      await profile.mount(t, invites, seekSection: false);
      final firstContext = t.element(find.byType(ProfileScreen));
      final audience = firstContext.read<AudiencePolicy>();
      final economy = firstContext.read<EconomyStore>();
      await audience.select(AgeBand.adult18plus);
      await audience.setAdDataConsent(true);
      await economy.applyServerWallet(
        wallet.simpleWallet(),
        owner: 'android:1',
        serverNow: wallet.stamp,
      );
      final operations = <String>[];
      bool? savedConsentAtAuthorization;
      economy.sendEnergyOperation = (kind, args) async {
        operations.add(kind);
        savedConsentAtAuthorization = (await SharedPreferences.getInstance())
            .getBool(AudiencePolicy.adDataConsentKey);
      };
      final driver = _RecordingDriver();
      final ads = AdsService(driver, audience: audience);
      final originalTree = t.widget<MultiProvider>(
        find.byType(MultiProvider).first,
      );
      await t.pumpWidget(
        ChangeNotifierProvider<AdsService>.value(
          value: ads,
          child: originalTree,
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      addTearDown(ads.dispose);

      final help = find.byKey(const ValueKey('profile-support-expand'));
      await t.ensureVisible(help);
      await t.tap(help);
      await t.pumpAndSettle();
      final privacy = find.byKey(const ValueKey('ad-privacy-compact'));
      expect(privacy, findsOneWidget);
      await t.ensureVisible(privacy);
      await t.tap(privacy);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('ad-data-revoke')));
      await t.pumpAndSettle();
      expect(audience.adDataConsent, false);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          AudiencePolicy.adDataConsentKey,
        ),
        false,
      );
      expect(driver.calls, 0);
      expect(operations, isEmpty);

      await t.binding.handlePopRoute(); // Help → profile.
      await t.pumpAndSettle();
      await t.binding.handlePopRoute(); // Profile → home.
      await t.pumpAndSettle();
      final home = t.element(find.text('Open'));
      unawaited(showSimpleEnergyWindow(home));
      await t.pumpAndSettle();
      final videoEntry = find.byKey(const ValueKey('simple-energy-video'));
      await t.ensureVisible(videoEntry);
      await t.tap(videoEntry);
      await t.pumpAndSettle();
      expect(audience.adDataConsent, false); // Entering the guide cannot grant.
      final watch = find.byKey(const ValueKey('simple-watch-video'));
      await t.ensureVisible(watch);
      await t.tap(watch);
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ad-data-consent-dialog')),
        findsNothing,
      );
      expect(operations, ['rewarded_ad_start']);
      expect(savedConsentAtAuthorization, true);
      expect(driver.calls, 1);
      expect(driver.savedConsentAtLaunch, true);
      final restored = AudiencePolicy();
      await restored.load();
      expect(restored.adDataConsent, true);
      restored.dispose();
      expect(
        economy.energy,
        50,
      ); // A dismissed test presentation never grants energy.
      expect(t.takeException(), null);
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );
}
