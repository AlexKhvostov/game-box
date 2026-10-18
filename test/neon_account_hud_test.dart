import 'dart:async';
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
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/features/profile/google_startup_dialog.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/neon_hud_capsule.dart';
import 'package:game_box/ui/neon_chrome.dart';
import 'package:game_box/ui/ad_privacy_settings.dart';
import 'friend_invites_profile_test.dart' as profile;
import 'blue_glass_profile_test.dart' as google;
import 'simple_energy_test.dart' as energy;

Future<void> saveFrame(WidgetTester tester, String name, Finder finder) async {
  final folder = Platform.environment['ACCOUNT_HUD_EVIDENCE'];
  if (folder == null) return;
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
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

  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final linked in [false, true]) {
        testWidgets('approved account width$width text$scale linked$linked', (
          tester,
        ) async {
          final account = profile.BindAccount(linked: linked)
            ..nickname = 'NeonPilot'
            ..googleName = 'Игрок'
            ..googleEmail = 'player@example.invalid';
          final invites = profile.ProfileInvites(account)..emit();
          await profile.mount(
            tester,
            invites,
            size: Size(width, 740),
            scale: scale,
            seekSection: false,
          );
          final context = tester.element(find.byType(ProfileScreen));
          context.read<EconomyStore>().bestTimeMs = 12154;
          context.read<EconomyStore>().dailyStreak = 3;
          context.read<EconomyStore>().notifyListeners();
          await tester.pumpAndSettle();
          expect(find.byType(AccountPortrait), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            final help = find.byKey(const ValueKey('profile-support-expand'));
            final viewport = tester.getRect(
              find.byKey(const ValueKey('profile-content')),
            );
            expect(
              tester.getRect(help).bottom,
              lessThanOrEqualTo(viewport.bottom),
            );
            expect(
              Scrollable.of(tester.element(help)).position.maxScrollExtent,
              0,
              reason:
                  'All normal profile actions fit at320/360 without scrolling',
            );
          }
          await saveFrame(
            tester,
            'account-${width.toInt()}-$scale-$linked',
            find.byKey(profile.boundary),
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('profile-age-edit')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('profile-age-edit')));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('age-adult18plus')), findsOneWidget);
          expect(find.byKey(const ValueKey('age-under18')), findsOneWidget);
          await saveFrame(
            tester,
            'age-${width.toInt()}-$scale',
            find.byKey(profile.boundary),
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('inviter-info')),
          );
          await tester.tap(find.byKey(const ValueKey('inviter-info')));
          await tester.pumpAndSettle();
          await saveFrame(
            tester,
            'invite-info-${width.toInt()}-$scale',
            find.byKey(profile.boundary),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('account child windows preserve actions and complete copy', (
    tester,
  ) async {
    final owner = profile.BindAccount()
      ..googleName = 'Игрок'
      ..googleEmail = 'player@example.invalid';
    final invites = profile.ProfileInvites(owner)..emit();
    await profile.mount(
      tester,
      invites,
      size: const Size(360, 740),
      seekSection: false,
    );
    final context = tester.element(find.byType(ProfileScreen));
    await context.read<EconomyStore>().applyServerWallet(
      energy.simpleWallet(balance: 50),
      serverNow: energy.stamp,
      owner: owner.id,
    );
    final nickname = find.byKey(const ValueKey('profile-nickname-input'));
    await tester.enterText(nickname, 'N');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('profile-nickname-save')),
          )
          .onPressed,
      isNull,
    );
    await saveFrame(
      tester,
      'account-invalid-name',
      find.byKey(profile.boundary),
    );
    await tester.enterText(nickname, List.filled(24, 'N').join());
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(nickname).controller!.text.length, 24);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('profile-nickname-save')),
          )
          .onPressed,
      isNotNull,
    );
    await saveFrame(
      tester,
      'account-long-name24',
      find.byKey(profile.boundary),
    );
    await tester.enterText(nickname, owner.nickname!);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    owner.inviters['android:1'] = 'ABCDEFGH2345';
    invites.emit();
    await tester.pumpAndSettle();
    final locked = find.byKey(const ValueKey('inviter-locked-code'));
    await tester.ensureVisible(locked);
    await tester.pumpAndSettle();
    expect(locked, findsOneWidget);
    expect(find.byKey(const ValueKey('inviter-apply')), findsNothing);
    await saveFrame(
      tester,
      'account-code-locked',
      find.byKey(profile.boundary),
    );
    final login = google.ProfileTestAccount()
      ..id = 'visual-google'
      ..linkFailure = const MobileApiError('network');
    unawaited(
      showGoogleStartupOffer(
        context,
        account: login,
        identity: profile.NoGoogle(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as dynamic).assetName ==
                'assets/branding/account/progress-player.png',
      ),
      findsOneWidget,
    );
    await saveFrame(tester, 'google-offer', find.byKey(profile.boundary));
    await tester.tap(find.byKey(const ValueKey('google-startup-connect')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('google-startup-message')),
      findsOneWidget,
    );
    expect(find.text('Повторить подключение'), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('google-startup-message')))
          .bottom,
      lessThan(
        tester
            .getRect(find.byKey(const ValueKey('google-startup-connect')))
            .top,
      ),
    );
    await saveFrame(tester, 'google-error', find.byKey(profile.boundary));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    login.dispose();
    for (final (name, open) in <(String, Future<bool?> Function())>[
      (
        'confirm-disconnect',
        () => showProfileGoogleDisconnectConfirmation(context),
      ),
      ('confirm-restore', () => showProfileRestoreConfirmation(context)),
      ('confirm-reset', () => showProfileResetConfirmation(context)),
    ]) {
      final action = open();
      await tester.pumpAndSettle();
      await saveFrame(tester, name, find.byKey(profile.boundary));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await action, isNull);
    }
    await tester.ensureVisible(
      find.byKey(const ValueKey('profile-support-expand')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-support-expand')));
    await tester.pumpAndSettle();
    await saveFrame(tester, 'help-privacy', find.byKey(profile.boundary));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    if (AudiencePolicy.adsBuildEnabled) {
      // The public consent function only asks. Decline never starts an SDK.
      await context.read<AudiencePolicy>().select(AgeBand.adult18plus);
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-support-expand')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-support-expand')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ad-privacy-compact')), findsOneWidget);
      await saveFrame(tester, 'help-privacy-ads', find.byKey(profile.boundary));
      await tester.tap(find.byKey(const ValueKey('ad-privacy-compact')));
      await tester.pumpAndSettle();
      await saveFrame(
        tester,
        'ads-session-settings',
        find.byKey(profile.boundary),
      );
      await tester.tap(find.text('Без рекламы'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final consent = ensureAdsForSession(context);
      await tester.pumpAndSettle();
      expect(find.text('Включить рекламу?'), findsOneWidget);
      await saveFrame(tester, 'ads-consent', find.byKey(profile.boundary));
      await tester.tap(find.text('Без рекламы'));
      await tester.pumpAndSettle();
      expect(await consent, false);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new HUD keeps long values and three actions stable at320/360 and text200',
    (tester) async {
      final e = await energy.store();
      final frame = ValueNotifier(0);
      for (final width in [320.0, 360.0]) {
        for (final scale in [1.0, 2.0]) {
          await tester.binding.setSurfaceSize(Size(width, 740));
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: e),
                Provider.value(value: const GameplayConfig()),
              ],
              child: MaterialApp(
                theme: buildGameTheme(),
                locale: const Locale('ru'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: RepaintBoundary(
                    key: const ValueKey('hud-matrix-render'),
                    child: SizedBox(
                      height: 104,
                      child: ArcadeHud(
                        frame: frame,
                        timeMs: () => 0,
                        jumpProgress: () => 1,
                        onLivesTap: () {},
                        onCrystalsTap: () {},
                        onRecordTap: () {},
                        onProfileTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final plus = tester.getRect(
            find.byKey(const ValueKey('hud-energy-plus')),
          );
          final cards = [
            for (final n in ['energy', 'ranking', 'account'])
              tester.getRect(find.byKey(ValueKey('hud-$n-card'))),
          ];
          expect(
            cards.every((r) => (r.height - cards.first.height).abs() < .01),
            true,
          );
          final disc = tester.getSize(
            find.byKey(const ValueKey('energy-capsule-plus-disc')),
          );
          expect(disc.width, closeTo(disc.height, .01));
          for (final balance in [50, 1500, 99999]) {
            await e.applyServerWallet(
              energy.simpleWallet(
                balance: balance,
                nextAt: energy.stamp + 14400000,
              ),
              serverNow: energy.stamp,
              owner: 'android:1',
            );
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.byKey(const ValueKey('hud-energy-plus'))),
              plus,
            );
            expect([
              for (final n in ['energy', 'ranking', 'account'])
                tester.getRect(find.byKey(ValueKey('hud-$n-card'))),
            ], cards);
            final amount = tester.getRect(
              find.byKey(const ValueKey('hud-energy-amount')),
            );
            expect(amount.center.dx, closeTo(cards.first.center.dx, .5));
            expect(amount.right, lessThanOrEqualTo(plus.left));
            expect(
              tester
                      .widget<CustomPaint>(
                        find.byKey(const ValueKey('hud-bonus-ring')),
                      )
                      .painter!
                  as HudBonusRingPainter,
              isA<HudBonusRingPainter>(),
            );
            await saveFrame(
              tester,
              'hud-${width.toInt()}-$scale-$balance',
              find.byKey(const ValueKey('hud-matrix-render')),
            );
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
      await tester.binding.setSurfaceSize(null);
      frame.dispose();
      e.dispose();
    },
  );

  testWidgets(
    'HUD uses shared clock, claim acknowledgement, reset, resume and unknown cache',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      var clock = energy.stamp;
      final e = EconomyStore(
        now: () => DateTime.fromMillisecondsSinceEpoch(clock),
        storagePrefix: 'hud_shared_',
      );
      await e.load();
      Future<void> wallet(
        int remaining, {
        bool cache = false,
        int tier = 1,
        int duration = 28800000,
      }) async {
        final data = energy.simpleWallet(nextAt: clock + remaining, tier: tier);
        (data['simpleBonus'] as Map)['durationMs'] = duration;
        await e.applyServerWallet(
          data,
          serverNow: clock,
          owner: 'android:1',
          fromCache: cache,
        );
      }

      await wallet(28800000);
      final frame = ValueNotifier(0);
      final taps = [0, 0];
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: e),
            Provider.value(value: const GameplayConfig()),
          ],
          child: MaterialApp(
            theme: buildGameTheme(),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: RepaintBoundary(
                  key: const ValueKey('hud-test-render'),
                  child: SizedBox(
                    height: 104,
                    child: ArcadeHud(
                      frame: frame,
                      timeMs: () => 0,
                      jumpProgress: () => 1,
                      onLivesTap: () {},
                      onCrystalsTap: () => showSimpleEnergyWindow(context),
                      onRecordTap: () => taps[0]++,
                      onProfileTap: () => taps[1]++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      HudBonusRingPainter ring() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('hud-bonus-ring')),
                  )
                  .painter!
              as HudBonusRingPainter;
      final initialPlus = tester.getRect(
        find.byKey(const ValueKey('hud-energy-plus')),
      );
      final initialCards = [
        for (final n in ['energy', 'ranking', 'account'])
          tester.getRect(find.byKey(ValueKey('hud-$n-card'))),
      ];
      for (final (remaining, progress) in [
        (28800000, 0.0),
        (14400000, .5),
        (900000, .96875),
        (0, 1.0),
      ]) {
        await wallet(remaining);
        await tester.pumpAndSettle();
        expect(ring().progress, closeTo(progress, .00001));
        expect(ring().ready, remaining == 0);
        expect(
          tester.getRect(find.byKey(const ValueKey('hud-energy-plus'))),
          initialPlus,
        );
        expect([
          for (final n in ['energy', 'ranking', 'account'])
            tester.getRect(find.byKey(ValueKey('hud-$n-card'))),
        ], initialCards);
        await saveFrame(
          tester,
          'hud-ring-$remaining',
          find.byKey(const ValueKey('hud-test-render')),
        );
      }
      final ack = Completer<void>();
      var calls = 0;
      e.sendEnergyOperation = (kind, args) async {
        expect(kind, 'energy_bonus_claim');
        calls++;
        await ack.future;
        final data = energy.simpleWallet(balance: 80, nextAt: clock + 28800000);
        await e.applyServerWallet(data, serverNow: clock, owner: 'android:1');
      };
      await tester.tap(find.byKey(const ValueKey('hud-energy-plus')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('simple-bonus-orb')), findsOneWidget);
      expect(calls, 0, reason: 'Opening the plus never claims a bonus');
      await tester.tap(find.byKey(const ValueKey('simple-bonus-orb')));
      await tester.pump();
      expect(calls, 1);
      expect(e.energy, 50);
      ack.complete();
      await tester.pumpAndSettle();
      expect(e.energy, 80);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(ring().progress, 0);
      expect(ring().ready, false);
      clock += 14400000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(ring().progress, .5);
      await wallet(0, cache: true);
      await tester.pumpAndSettle();
      expect(ring().known, false);
      expect(ring().ready, false);
      await wallet(7200000, tier: 5, duration: 14400000);
      await tester.pumpAndSettle();
      expect(ring().known, true);
      expect(ring().progress, .5);
      await tester.tap(find.byKey(const ValueKey('hud-ranking-card')));
      await tester.tap(find.byKey(const ValueKey('hud-account-card')));
      expect(taps, [1, 1]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
      e.dispose();
    },
  );
}
