import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/google_identity.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/profile_support.dart';

class ProfileTestAccount extends MobileAccount {
  int renames = 0;
  int restores = 0;
  Completer<void>? pendingRestore;
  String? restoreFailure;
  Object? linkFailure;
  Completer<void>? preparation;
  @override
  Future<void> linkGoogle(GoogleIdentity google) async {
    await preparation?.future;
    busy = true;
    notifyListeners();
    try {
      await Future<void>.delayed(Duration.zero);
      if (linkFailure != null) throw linkFailure!;
      if (pendingRestore != null || restoreFailure != null) {
        await restoreGoogle(google);
        return;
      }
      googleLinked = true;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  Future<void> restoreGoogle(GoogleIdentity google) async {
    restores++;
    busy = true;
    notifyListeners();
    try {
      await pendingRestore?.future;
      if (restoreFailure != null) throw MobileApiError(restoreFailure!);
      googleLinked = true;
      id = 'qa:restored';
      nickname = 'RestoredPlayer';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  Future<void> rename(String value) async {
    renames++;
    if (value == 'TakenName') throw const MobileApiError('nickname_taken');
    nickname = value;
    notifyListeners();
  }
}

class _FixtureGoogle implements GoogleIdentity {
  @override
  bool get configured => true;
  @override
  Future<String> token() =>
      throw StateError('Fixture must never access real Google');
}

Future<void> mountProfile(
  WidgetTester tester, {
  String language = 'ru',
  Size size = const Size(320, 560),
  double scale = 1,
  bool linked = false,
  EdgeInsets padding = EdgeInsets.zero,
  double keyboard = 0,
  ProfileTestAccount? fixtureAccount,
  GoogleIdentity? googleIdentity,
}) async {
  SharedPreferences.setMockInitialValues({});
  final economy = EconomyStore();
  await economy.load();
  final prefs = PlayerPreferences();
  await prefs.load();
  final policy = AudiencePolicy();
  await policy.load();
  final account =
      fixtureAccount ??
      (ProfileTestAccount()
        ..id = 'qa:profile'
        ..nickname = 'MintPlayer'
        ..googleLinked = linked);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider.value(value: policy),
        ChangeNotifierProvider<MobileAccount>.value(value: account),
      ],
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildGameTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: padding,
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showProfileSheet(context, googleIdentity: googleIdentity),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'short profile reports connection before preparation and success',
    (tester) async {
      final account = ProfileTestAccount()
        ..id = 'qa:google'
        ..nickname = 'MintPlayer'
        ..preparation = Completer<void>();
      await mountProfile(
        tester,
        fixtureAccount: account,
        googleIdentity: _FixtureGoogle(),
      );
      expect(find.text('Google не подключён'), findsOneWidget);
      final link = find.byKey(const ValueKey('profile-google-link'));
      await tester.tap(link);
      await tester.pump();
      expect(find.text('Подключаем…'), findsOneWidget);
      expect(account.busy, false);
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(of: link, matching: find.byType(OutlinedButton)),
            )
            .onPressed,
        isNull,
      );
      account.preparation!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Google подключён'), findsOneWidget);
      expect(link, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['ru', 'en']) {
    for (final failure in [
      const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      ),
      const MobileApiError('google_profile_exists'),
    ]) {
      testWidgets(
        '$language Google failure stays visible in sheet and retry connects $failure',
        (tester) async {
          final account = ProfileTestAccount()
            ..id = 'qa:google'
            ..nickname = 'MintPlayer'
            ..linkFailure = failure;
          await mountProfile(
            tester,
            language: language,
            size: const Size(390, 844),
            fixtureAccount: account,
            googleIdentity: _FixtureGoogle(),
          );
          final link = find.byKey(const ValueKey('profile-google-link'));
          await tester.tap(link);
          await tester.pumpAndSettle();
          final message = find.byKey(const ValueKey('profile-google-message'));
          expect(message, findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('profile-google-setting')),
              matching: message,
            ),
            findsOneWidget,
          );
          expect(account.googleLinked, false);
          expect(account.nickname, 'MintPlayer');
          expect(account.busy, false);
          await tester.ensureVisible(message);
          await tester.pumpAndSettle();
          expect(tester.getRect(message).bottom, lessThanOrEqualTo(844));
          account.linkFailure = null;
          await tester.ensureVisible(link);
          await tester.tap(link);
          await tester.pumpAndSettle();
          expect(account.googleLinked, true);
          expect(message, findsNothing);
          expect(link, findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'Connect automatically restores once and refreshes name without confirmation',
    (tester) async {
      final account = ProfileTestAccount()
        ..id = 'qa:restore'
        ..nickname = 'MintPlayer'
        ..pendingRestore = Completer<void>();
      await mountProfile(
        tester,
        size: const Size(390, 844),
        fixtureAccount: account,
        googleIdentity: _FixtureGoogle(),
      );
      final restore = find.byKey(const ValueKey('profile-google-link'));
      await tester.tap(restore);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-google-restore')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('profile-restore-confirm')),
        findsNothing,
      );
      expect(account.restores, 1);
      expect(account.busy, true);
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(
                of: restore,
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNull,
      );
      account.pendingRestore!.complete();
      await tester.pumpAndSettle();
      expect(account.restores, 1);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('profile-nickname-input')),
            )
            .controller!
            .text,
        'RestoredPlayer',
      );
      expect(find.byKey(const ValueKey('profile-google-link')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Restore missing profile error preserves guest and permits retry',
    (tester) async {
      final account = ProfileTestAccount()
        ..id = 'qa:restore'
        ..nickname = 'MintPlayer'
        ..restoreFailure = 'google_profile_not_found';
      await mountProfile(
        tester,
        size: const Size(390, 844),
        fixtureAccount: account,
        googleIdentity: _FixtureGoogle(),
      );
      final restore = find.byKey(const ValueKey('profile-google-link'));
      await tester.tap(restore);
      await tester.pumpAndSettle();
      expect(account.restores, 1);
      expect(account.nickname, 'MintPlayer');
      expect(
        find.text('С этим Google ещё не связан профиль Untouch.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-google-setting')),
          matching: find.text('С этим Google ещё не связан профиль Untouch.'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(
                of: restore,
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final language in ['ru', 'en']) {
    for (final reset in [false, true]) {
      testWidgets(
        '$language ${reset ? "reset" : "restore"} confirmation cancel/confirm/Back are isolated',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 560));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          bool? choice;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: buildGameTheme(),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      choice = await (reset
                          ? showProfileResetConfirmation(context)
                          : showProfileRestoreConfirmation(context));
                    },
                    child: const Text('Confirm'),
                  ),
                ),
              ),
            ),
          );
          final action = reset
              ? 'profile-reset-confirm'
              : 'profile-restore-confirm';
          await tester.tap(find.text('Confirm'));
          await tester.pumpAndSettle();
          final cancel = find.byKey(ValueKey('$action-cancel'));
          expect(tester.getRect(cancel).height, greaterThanOrEqualTo(48));
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(choice, false);
          await tester.tap(find.text('Confirm'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey(action)));
          await tester.pumpAndSettle();
          expect(choice, true);
          await tester.tap(find.text('Confirm'));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(choice, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final language in ['ru', 'en']) {
    testWidgets('$language compact account with Android safe areas', (
      tester,
    ) async {
      await mountProfile(
        tester,
        language: language,
        padding: const EdgeInsets.only(top: 24, bottom: 24),
      );
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('profile-content')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scroll.position.maxScrollExtent, 0);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      '$language linked account keeps settings without Restore; system Back closes',
      (tester) async {
        await mountProfile(tester, language: language, linked: true);
        expect(find.byKey(const ValueKey('profile-google-link')), findsNothing);
        expect(
          find.byKey(const ValueKey('profile-google-restore')),
          findsNothing,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    for (final size in [const Size(320, 560), const Size(390, 844)]) {
      testWidgets(
        '$language account no page scroll $size and settings allowed with unknown age',
        (tester) async {
          await mountProfile(tester, language: language, size: size);
          expect(tester.takeException(), isNull);
          final scroll = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('profile-content')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            scroll.position.maxScrollExtent,
            0,
            reason: 'All ordinary account actions must fit',
          );
          final input = find.byKey(const ValueKey('profile-nickname-input'));
          expect(tester.widget<TextField>(input).enabled, isTrue);
          await tester.tap(find.byType(Switch).first);
          await tester.pumpAndSettle();
          final context = tester.element(input);
          expect(context.read<PlayerPreferences>().sound, isFalse);
          expect(context.read<AudiencePolicy>().band, isNull);
          final soundRect = tester.getRect(find.byType(Switch).first);
          expect(soundRect.height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      '$language expanded help scrolls internally and retains public links',
      (tester) async {
        final calls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          ProfileSupport.channel,
          (call) async {
            calls.add(call);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            ProfileSupport.channel,
            null,
          ),
        );
        await mountProfile(tester, language: language);
        await tester.tap(find.byKey(const ValueKey('profile-support-expand')));
        await tester.pumpAndSettle();
        for (final page in ['privacy', 'deletion', 'support']) {
          final button = find.byKey(ValueKey('profile-$page'));
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(calls.last.method, 'openPage');
          expect(calls.last.arguments, {'page': page, 'language': language});
          expect(tester.getRect(button).height, greaterThanOrEqualTo(48));
        }
        expect(find.byKey(const ValueKey('profile-help-content')), findsOneWidget);
        expect(find.byType(Dialog), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$language large text preserves settings and help with internal scroll',
      (tester) async {
        await mountProfile(tester, language: language, scale: 2);
        final music = find.byKey(const ValueKey('profile-music-switch'));
        await tester.scrollUntilVisible(
          music,
          150,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('profile-content')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(music);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('profile-support-expand')),
          150,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('profile-content')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('profile-support-expand')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('profile-copy-support')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'nickname validation and conflicts retain draft; valid save runs once',
    (tester) async {
      await mountProfile(tester, size: const Size(390, 844));
      final input = find.byKey(const ValueKey('profile-nickname-input'));
      final save = find.byKey(const ValueKey('profile-nickname-save'));
      await tester.enterText(input, 'Mint');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(input, 'TakenName');
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Этот ник занят. Выберите другой.'), findsOneWidget);
      expect(tester.widget<TextField>(input).controller!.text, 'TakenName');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(input, 'BluePlayer');
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        tester.element(input).read<MobileAccount>().nickname,
        'BluePlayer',
      );
      expect(
        (tester.element(input).read<MobileAccount>() as ProfileTestAccount)
            .renames,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
