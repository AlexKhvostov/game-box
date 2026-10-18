import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/google_identity.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'friend_invites_delivery_test.dart' as fixture;

const visual = bool.fromEnvironment('FRIEND_INVITES_PROFILE_VISUAL_QA');
const evidencePrefix = String.fromEnvironment(
  'FRIEND_INVITES_EVIDENCE_PREFIX',
  defaultValue: 'executor-preview1',
);
const boundary = ValueKey('inviter-profile-capture');
Finder key(String text) => find.byKey(ValueKey(text));

class BindAccount extends fixture.Account {
  BindAccount({super.linked});
  final submitted = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? heldBind;
  String? bindFailure;
  @override
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> payload, {
    bool guest = false,
  }) async {
    if (payload['action'] == 'invites_bind') {
      submitted.add({'owner': id, ...payload});
      if (heldBind != null) return heldBind!.future;
      if (bindFailure != null) throw MobileApiError(bindFailure!);
      if (payload['code'] == fixture.ownGuest) {
        throw const MobileApiError('invite_self');
      }
    }
    return super.request(payload, guest: guest);
  }
}

/// The source/refresh is controlled; manual delivery uses the unchanged real B3 service.
class ProfileInvites extends MobileInvites {
  ProfileInvites(BindAccount account, {super.enabled = true})
    : super(
        account: account,
        source: fixture.Source(),
        vault: fixture.Vault(),
        startupResolved: true,
      );
  int refreshes = 0;
  Completer<void>? heldRefresh;
  @override
  Future<void> refresh() async {
    refreshes++;
    await heldRefresh?.future;
    if (error != null) {
      notifyListeners();
      return;
    }
    emit();
  }

  void emit({String? owner, String? failure, bool clear = false}) {
    if (owner != null) account.id = owner;
    error = failure;
    state = clear
        ? null
        : InviteState.fromJson(
            (account as BindAccount).data(account.id!)['invites']
                as Map<String, dynamic>,
          );
    notifyListeners();
  }
}

class NoGoogle implements GoogleIdentity {
  @override
  bool get configured => true;
  @override
  Future<String> token() => throw StateError('UI fixture cannot access Google');
}

void inviteTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(
      name,
      body,
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

Future<void> mount(
  WidgetTester tester,
  ProfileInvites service, {
  Size size = const Size(390, 844),
  String lang = 'ru',
  double scale = 1,
  ValueNotifier<double>? keyboard,
  bool seekSection = true,
  ScoresStore? scores,
}) async {
  SharedPreferences.setMockInitialValues({});
  final economy = EconomyStore();
  await economy.load();
  economy.tokens = 100;
  final prefs = PlayerPreferences();
  await prefs.load();
  final policy = AudiencePolicy();
  await policy.load();
  final insets = keyboard ?? ValueNotifier(0.0);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    service.dispose();
    service.account.dispose();
    prefs.dispose();
    policy.dispose();
    economy.dispose();
    if (keyboard == null) insets.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider.value(value: policy),
        ChangeNotifierProvider<MobileAccount>.value(value: service.account),
        ChangeNotifierProvider<MobileInvites>.value(value: service),
        if (scores != null)
          ChangeNotifierProvider<ScoresStore>.value(value: scores),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildGameTheme(),
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => ValueListenableBuilder<double>(
            valueListenable: insets,
            builder: (context, bottom, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: bottom),
              ),
              child: child!,
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showProfileSheet(context, googleIdentity: NoGoogle()),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (seekSection) await scrollTo(tester, key('profile-inviter-section'));
}

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find
          .descendant(
            of: key('profile-content'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pump();
}

Future<void> type(WidgetTester tester, String code) async {
  await scrollTo(tester, key('inviter-code-field'));
  await tester.enterText(key('inviter-code-field'), code);
  // Let EditableText's caret reveal finish before positioning the button.
  await tester.pump(const Duration(milliseconds: 350));
  await scrollTo(tester, key('inviter-apply'));
}

Future<void> apply(WidgetTester tester) async {
  await scrollTo(tester, key('inviter-apply'));
  expect(key('inviter-apply').hitTestable(), findsOneWidget);
  await tester.tap(key('inviter-apply'));
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!visual) return;
  await tester.pump();
  final render = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundary),
  );
  final section = key('profile-inviter-section');
  final metrics = <String, dynamic>{
    'rendering': 'widget Segoe-as-Roboto, not phone',
  };
  if (section.evaluate().isNotEmpty) {
    metrics['sectionHeight'] = tester.getSize(section).height;
    final panel = find
        .ancestor(
          of: section,
          matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_ProfilePanel',
          ),
        )
        .first;
    metrics['panelHeight'] = tester.getSize(panel).height;
  }
  await tester.runAsync(() async {
    final image = await render.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      'docs/release-evidence/friend-invites-live-layout-20261014/$evidencePrefix/$name.png',
    );
    if (!RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(evidencePrefix) ||
        await file.exists()) {
      throw StateError(
        'Use a fresh safe evidence prefix; PNG overwrite refused',
      );
    }
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    await File(
      file.path.replaceFirst('.png', '.geometry.json'),
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(metrics));
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!visual) return;
    for (final font in {
      'Roboto': 'C:/Windows/Fonts/segoeui.ttf',
      'MaterialIcons':
          'C:/Users/alexe/develop/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(font.key)
        ..addFont(
          Future.value(
            ByteData.sublistView(await File(font.value).readAsBytes()),
          ),
        );
      await loader.load();
    }
  });

  for (final lang in ['ru', 'en']) {
    for (final small in [false, true]) {
      inviteTest(
        'null profile keeps editable draft and info $lang small$small',
        (tester) async {
          final account = BindAccount();
          final service = ProfileInvites(account)
            ..error = 'invites_unavailable';
          final keyboard = ValueNotifier(0.0);
          addTearDown(keyboard.dispose);
          await mount(
            tester,
            service,
            lang: lang,
            size: small ? const Size(320, 480) : const Size(390, 844),
            scale: small ? 2 : 1,
            keyboard: keyboard,
          );
          expect(
            tester.widget<TextField>(key('inviter-code-field')).enabled,
            true,
          );
          expect(
            tester.widget<FilledButton>(key('inviter-apply')).onPressed,
            isNotNull,
          );
          expect(key('inviter-error'), findsNothing);
          await capture(tester, 'null-profile-$lang-small$small');
          await type(tester, 'ABCD');
          if (small) {
            keyboard.value = 160;
            await tester.pump();
            await scrollTo(tester, key('inviter-apply'));
            await capture(tester, 'null-profile-$lang-small-ime');
          }
          await scrollTo(tester, key('inviter-info'));
          await tester.tap(key('inviter-info'));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextField>(key('inviter-code-field'))
                .controller!
                .text,
            'ABCD',
          );
          expect(account.submitted, isEmpty);
          expect(service.state, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final failure in ['action_invalid', 'connection_failed']) {
    inviteTest(
      'null state uses real bind handler and preserves failed draft $failure',
      (tester) async {
        final account = BindAccount()..bindFailure = failure;
        final service = ProfileInvites(account)..error = 'invites_unavailable';
        await mount(tester, service);
        expect(service.state, isNull);
        expect(
          tester.widget<TextField>(key('inviter-code-field')).enabled,
          true,
        );
        expect(
          tester
              .widget<TextField>(key('inviter-code-field'))
              .decoration!
              .hintText,
          'Введите код',
        );
        expect(key('inviter-error'), findsNothing);
        await type(tester, 'bad');
        await apply(tester);
        expect(account.submitted, isEmpty);
        expect(key('inviter-error'), findsOneWidget);
        await type(tester, fixture.codeA);
        await apply(tester);
        expect(account.submitted.single['code'], fixture.codeA);
        expect(service.state, isNull);
        expect(key('inviter-error'), findsOneWidget);
        expect(
          tester.widget<TextField>(key('inviter-code-field')).controller!.text,
          fixture.codeA,
        );
        expect(
          tester.widget<Text>(key('inviter-error')).data,
          failure == 'action_invalid'
              ? 'Недоступно в тесте'
              : 'Нет связи. Повторить можно в i.',
        );
        expect(find.textContaining(failure), findsNothing);
        await tester.tap(key('inviter-info'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(key('inviter-code-field')).controller!.text,
          fixture.codeA,
        );
        account.bindFailure = null;
        await apply(tester);
        expect(account.submitted.length, 2);
        expect(key('inviter-locked-code'), findsOneWidget);
        expect(key('inviter-code-field'), findsNothing);
        expect(key('inviter-success'), findsNothing);
      },
    );
  }

  for (final mode in ['ready', 'unavailable', 'readonly', 'busy']) {
    inviteTest('dense row keeps independent info active $mode', (tester) async {
      final account = BindAccount();
      if (mode == 'readonly') account.inviters['android:1'] = fixture.codeA;
      final service = ProfileInvites(account);
      if (mode == 'unavailable') {
        service.error = 'invites_unavailable';
      } else {
        service.emit();
      }
      await mount(tester, service);
      if (mode == 'busy') {
        service.busy = true;
        service.notifyListeners();
        await tester.pump();
      }
      final panel = find
          .ancestor(
            of: key('profile-inviter-section'),
            matching: find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_ProfilePanel',
            ),
          )
          .first;
      expect(tester.getSize(panel).height, lessThanOrEqualTo(96));
      expect(
        tester.getRect(key('inviter-info')).bottom,
        lessThanOrEqualTo(
          tester
              .getRect(
                mode == 'readonly'
                    ? key('inviter-locked-code')
                    : key('inviter-code-field'),
              )
              .top,
        ),
      );
      expect(
        tester.widget<IconButton>(key('inviter-info')).onPressed,
        isNotNull,
      );
      if (mode == 'busy') {
        expect(
          tester.widget<TextField>(key('inviter-code-field')).enabled,
          false,
        );
      }
      if (mode == 'readonly') {
        expect(key('inviter-apply'), findsNothing);
        expect(find.text(fixture.codeA), findsOneWidget);
      }
      final initial = service.refreshes;
      await capture(tester, 'dense-account-$mode-ru-390');
      await tester.tap(key('inviter-info'));
      await tester.pump(const Duration(milliseconds: 400));
      if (mode == 'busy') {
        service.busy = false;
        service.notifyListeners();
      }
      await tester.pumpAndSettle();
      expect(key('inviter-info-dialog'), findsOneWidget);
      expect(service.refreshes, initial);
      expect(account.submitted, isEmpty);
      if (mode == 'unavailable') {
        expect(key('inviter-retry'), findsOneWidget);
        service.error = null;
        await tester.tap(key('inviter-retry'));
        await tester.pumpAndSettle();
        expect(service.refreshes, initial + 1);
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(key('inviter-info-dialog'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  inviteTest(
    'new block is before unchanged Help and privacy and Google privacy remains',
    (tester) async {
      final account = BindAccount();
      final service = ProfileInvites(account)..emit();
      await mount(tester, service);
      expect(
        tester.getRect(key('profile-inviter-section')).top,
        lessThan(tester.getRect(key('profile-support-expand')).top),
      );
      expect(find.byType(TextField), findsWidgets);
      expect(key('inviter-rules'), findsNothing);
      expect(key('inviter-success'), findsNothing);
      expect(
        tester.getSize(key('profile-inviter-section')).height,
        lessThan(126),
      );
      await capture(tester, 'profile-unbound-ru-390');
      await scrollTo(tester, key('profile-google-private'));
      expect(
        find.descendant(
          of: key('profile-google-setting'),
          matching: key('profile-google-private'),
        ),
        findsOneWidget,
      );
      expect(key('profile-ranking-privacy'), findsNothing);
    },
  );

  inviteTest(
    'same-owner assignment clears old manual error but retains service error',
    (tester) async {
      final account = BindAccount();
      final service = ProfileInvites(account)..emit();
      await mount(tester, service);
      await type(tester, 'CCCCCCCCCCCC');
      await apply(tester);
      expect(find.textContaining('Такого кода нет'), findsOneWidget);
      account.inviters['android:1'] = fixture.codeC;
      service.emit(failure: 'connection_failed');
      await tester.pumpAndSettle();
      expect(find.text(fixture.codeC), findsOneWidget);
      expect(key('inviter-code-field'), findsNothing);
      expect(find.textContaining('Такого кода нет'), findsNothing);
      expect(service.error, 'connection_failed');
      await scrollTo(tester, key('inviter-info'));
      await tester.tap(key('inviter-info'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Проверьте соединение'), findsOneWidget);
      service.emit();
      await tester.pumpAndSettle();
      expect(key('inviter-error'), findsNothing);
    },
  );

  inviteTest('disabled provider adds no panel or field to Android profile', (
    tester,
  ) async {
    final service = ProfileInvites(BindAccount(), enabled: false);
    await mount(tester, service, seekSection: false);
    expect(key('profile-inviter-section'), findsNothing);
    expect(key('inviter-code-field'), findsNothing);
    expect(service.refreshes, 0);
  });
  testWidgets(
    'non Android profile adds no invitation panel',
    (tester) async {
      final service = ProfileInvites(BindAccount());
      await mount(tester, service, seekSection: false);
      expect(key('profile-inviter-section'), findsNothing);
      expect(service.refreshes, 0);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  inviteTest('server already bound response refreshes to its immutable code', (
    tester,
  ) async {
    final account = BindAccount()..bindFailure = 'invite_already_bound';
    final service = ProfileInvites(account)..emit();
    await mount(tester, service);
    await type(tester, fixture.codeA);
    account.inviters['android:1'] = fixture.codeC;
    await apply(tester);
    expect(key('inviter-error'), findsOneWidget);
    await scrollTo(tester, key('inviter-info'));
    await tester.tap(key('inviter-info'));
    await tester.pumpAndSettle();
    await scrollTo(tester, key('inviter-retry'));
    await tester.tap(key('inviter-retry'));
    await tester.pumpAndSettle();
    expect(find.text(fixture.codeC), findsOneWidget);
    expect(key('inviter-code-field'), findsNothing);
    expect(account.submitted.length, 1);
  });

  for (final input in ['', 'bad!', 'XYZ']) {
    inviteTest(
      'empty or malformed input remains editable without request $input',
      (tester) async {
        final account = BindAccount();
        final service = ProfileInvites(account)..emit();
        await mount(tester, service);
        await type(tester, input);
        await apply(tester);
        expect(key('inviter-error'), findsOneWidget);
        expect(key('inviter-locked-code'), findsNothing);
        expect(account.submitted, isEmpty);
        await type(tester, fixture.codeA.toLowerCase());
        await apply(tester);
        expect(account.submitted.single['code'], fixture.codeA);
        expect(key('inviter-code-field'), findsNothing);
        expect(find.text(fixture.codeA), findsOneWidget);
      },
    );
  }
  for (final input in ['CCCCCCCCCCCC', fixture.ownGuest]) {
    inviteTest('unknown or own code is not fixed and can be retried $input', (
      tester,
    ) async {
      final account = BindAccount();
      final service = ProfileInvites(account)..emit();
      await mount(tester, service);
      await type(tester, input);
      await apply(tester);
      expect(key('inviter-error'), findsOneWidget);
      expect(key('inviter-locked-code'), findsNothing);
      expect(account.inviters, isEmpty);
      await capture(
        tester,
        'error-${input == fixture.ownGuest ? 'self' : 'unknown'}-ru-390',
      );
      await type(tester, fixture.codeA);
      await apply(tester);
      expect(account.inviters['android:1'], fixture.codeA);
      expect(key('inviter-code-field'), findsNothing);
    });
  }
  inviteTest('network failure retains draft and retry applies once', (
    tester,
  ) async {
    final account = BindAccount()..bindFailure = 'connection_failed';
    final service = ProfileInvites(account)..emit();
    await mount(tester, service);
    await type(tester, fixture.codeA);
    await apply(tester);
    expect(
      tester.widget<TextField>(key('inviter-code-field')).controller!.text,
      fixture.codeA,
    );
    expect(find.textContaining('connection_failed'), findsNothing);
    account.bindFailure = null;
    await apply(tester);
    expect(account.submitted.length, 2);
    expect(key('inviter-locked-code'), findsOneWidget);
  });
  inviteTest('locked code has no input or second bind action', (tester) async {
    final account = BindAccount()..inviters['android:1'] = fixture.codeA;
    final service = ProfileInvites(account)..emit();
    await mount(tester, service);
    expect(key('inviter-code-field'), findsNothing);
    expect(key('inviter-apply'), findsNothing);
    expect(find.text(fixture.codeA), findsOneWidget);
    expect(account.submitted, isEmpty);
    await capture(tester, 'profile-locked-ru-390');
  });
  for (final linked in [true, false]) {
    inviteTest(
      'five historical rounds response or guest Google condition linked$linked',
      (tester) async {
        final account = BindAccount(linked: linked);
        final service = ProfileInvites(account)..emit();
        await mount(tester, service);
        await type(tester, fixture.codeA);
        await apply(tester);
        expect(service.state!.completedGames, 5);
        expect(
          service.state!.bonusStatus,
          linked ? 'rewarded' : 'waiting_google',
        );
        expect(account.submitted.length, 1);
        expect(account.refreshes, 1);
        expect(find.textContaining('Бонус начислен'), findsNothing);
        expect(
          find.descendant(
            of: key('profile-inviter-section'),
            matching: key('profile-google-link'),
          ),
          findsNothing,
        );
        expect(
          find.textContaining('Предыдущие игры учитываются'),
          findsNothing,
        );
        await capture(
          tester,
          'profile-applied-${linked ? 'rewarded' : 'guest'}-ru-390',
        );
        await scrollTo(tester, key('inviter-info'));
        await tester.tap(key('inviter-info'));
        await tester.pumpAndSettle();
        expect(key('inviter-info-dialog'), findsOneWidget);
        expect(
          find.textContaining('Предыдущие игры учитываются'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Бонус начислен'),
          linked ? findsOneWidget : findsNothing,
        );
        expect(account.submitted.length, 1);
      },
    );
  }

  inviteTest('repeated button and keyboard submission dispatch one held bind', (
    tester,
  ) async {
    final held = Completer<Map<String, dynamic>>();
    final account = BindAccount()..heldBind = held;
    final service = ProfileInvites(account)..emit();
    await mount(tester, service);
    await type(tester, fixture.codeA);
    final tap = tester.widget<FilledButton>(key('inviter-apply')).onPressed!;
    final submit = tester
        .widget<TextField>(key('inviter-code-field'))
        .onSubmitted!;
    tap();
    tap();
    submit(fixture.codeA);
    await tester.pump();
    expect(account.submitted.length, 1);
    expect(tester.widget<FilledButton>(key('inviter-apply')).onPressed, isNull);
    account.inviters['android:1'] = fixture.codeA;
    held.complete(account.data('android:1'));
    await tester.pumpAndSettle();
    expect(key('inviter-locked-code'), findsOneWidget);
    tap();
    submit(fixture.codeC);
    await tester.pumpAndSettle();
    expect(account.submitted.length, 1);
  });
  inviteTest('busy Google or stale callback cannot bind before rebuilt owner', (
    tester,
  ) async {
    final account = BindAccount();
    final service = ProfileInvites(account)..emit();
    await mount(tester, service);
    await type(tester, fixture.codeA);
    final callback = tester
        .widget<FilledButton>(key('inviter-apply'))
        .onPressed!;
    account.googleStage = GoogleConnectionStage.choosingAccount;
    account.notifyListeners();
    callback();
    await tester.pump();
    expect(tester.widget<FilledButton>(key('inviter-apply')).onPressed, isNull);
    expect(account.submitted, isEmpty);
    account.googleStage = null;
    account.busy = true;
    callback();
    expect(account.submitted, isEmpty);
    account.busy = false;
    service.emit(owner: 'android:2');
    callback();
    await tester.pumpAndSettle();
    expect(account.submitted, isEmpty);
    expect(
      tester.widget<TextField>(key('inviter-code-field')).controller!.text,
      isEmpty,
    );
  });
  for (final rejected in [false, true]) {
    inviteTest(
      'old ${rejected ? 'rejected' : 'successful'} bind is ignored after restore',
      (tester) async {
        final held = Completer<Map<String, dynamic>>();
        final account = BindAccount()..heldBind = held;
        final service = ProfileInvites(account)..emit();
        await mount(tester, service);
        await type(tester, fixture.codeA);
        await tester.tap(key('inviter-apply'));
        await tester.pump();
        service.emit(owner: 'android:2');
        await tester.pump();
        // The unchanged service serializes requests and remains busy until the
        // old reply drains. A retained new draft must survive that completion.
        tester.widget<TextField>(key('inviter-code-field')).controller!.text =
            fixture.codeC;
        if (rejected) {
          held.completeError(const MobileApiError('invite_self'));
        } else {
          account.inviters['android:1'] = fixture.codeA;
          held.complete(account.data('android:1'));
        }
        await tester.pumpAndSettle();
        expect(key('inviter-locked-code'), findsNothing);
        expect(key('inviter-error'), findsNothing);
        expect(
          tester.widget<TextField>(key('inviter-code-field')).controller!.text,
          fixture.codeC,
        );
        expect(find.textContaining('Бонус начислен'), findsNothing);
      },
    );
  }
  inviteTest('closing during pending bind does not update disposed widget', (
    tester,
  ) async {
    final held = Completer<Map<String, dynamic>>();
    final account = BindAccount()..heldBind = held;
    final service = ProfileInvites(account)..emit();
    await mount(tester, service);
    await type(tester, fixture.codeA);
    await tester.tap(key('inviter-apply'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    account.inviters['android:1'] = fixture.codeA;
    held.complete(account.data('android:1'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(key('profile-inviter-section'), findsNothing);
  });
  for (final failure in ['invites_unavailable', 'connection_failed']) {
    inviteTest('initial unavailable loading and retry $failure', (
      tester,
    ) async {
      final service = ProfileInvites(BindAccount())..error = failure;
      await mount(tester, service);
      expect(key('inviter-error'), findsNothing);
      expect(key('inviter-code-field'), findsOneWidget);
      expect(tester.widget<TextField>(key('inviter-code-field')).enabled, true);
      expect(
        tester.widget<FilledButton>(key('inviter-apply')).onPressed,
        isNotNull,
      );
      expect(key('inviter-rules'), findsNothing);
      expect(key('inviter-success'), findsNothing);
      expect(
        tester.getSize(key('profile-inviter-section')).height,
        lessThanOrEqualTo(96),
      );
      await capture(tester, 'compact-account-$failure-ru-390');
      final initial = service.refreshes;
      await tester.tap(key('inviter-info'));
      await tester.pumpAndSettle();
      expect(service.refreshes, initial);
      expect(key('inviter-info-error'), findsOneWidget);
      service.error = null;
      await tester.tap(key('inviter-retry'));
      await tester.pumpAndSettle();
      expect(key('inviter-code-field'), findsOneWidget);
      expect(key('inviter-error'), findsNothing);
    });
  }
  inviteTest(
    'loading shows a disabled placeholder before canonical state arrives',
    (tester) async {
      final held = Completer<void>();
      final service = ProfileInvites(BindAccount())..heldRefresh = held;
      await mount(tester, service);
      expect(key('inviter-loading'), findsOneWidget);
      expect(
        tester.widget<TextField>(key('inviter-code-field')).enabled,
        false,
      );
      expect(
        tester.widget<FilledButton>(key('inviter-apply')).onPressed,
        isNull,
      );
      held.complete();
      await tester.pumpAndSettle();
      expect(key('inviter-code-field'), findsOneWidget);
    },
  );

  for (final lang in ['ru', 'en']) {
    for (final compact in [false, true]) {
      inviteTest(
        'tap info keeps rules out of account and draft intact $lang compact$compact',
        (tester) async {
          final account = BindAccount();
          final service = ProfileInvites(account)..emit();
          await mount(
            tester,
            service,
            lang: lang,
            size: compact ? const Size(320, 480) : const Size(390, 844),
            scale: compact ? 2 : 1,
          );
          await type(tester, fixture.codeA);
          expect(key('inviter-rules'), findsNothing);
          expect(key('inviter-success'), findsNothing);
          await scrollTo(tester, key('inviter-info'));
          final info = tester
              .widget<IconButton>(key('inviter-info'))
              .onPressed!;
          final refreshes = service.refreshes;
          info();
          info();
          await tester.pumpAndSettle();
          expect(key('inviter-info-dialog'), findsOneWidget);
          expect(key('inviter-rules'), findsOneWidget);
          final rules = tester
              .widgetList<Text>(
                find.descendant(
                  of: key('inviter-rules'),
                  matching: find.byType(Text),
                ),
              )
              .map((w) => w.data ?? '')
              .join(' ');
          expect(rules, contains('5'));
          expect(rules, contains(lang == 'ru' ? 'Награда' : 'reward'));
          expect(rules, isNot(contains(lang == 'ru' ? 'кристалл' : 'crystal')));
          expect(rules, contains('Google'));
          expect(rules, contains(lang == 'ru' ? 'один раз' : 'once'));
          expect(account.submitted, isEmpty);
          expect(service.refreshes, refreshes);
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            'compact-info-$lang-${compact ? 320 : 390}-font${compact ? 2 : 1}',
          );
          await tester.tap(
            find.byTooltip(lang == 'ru' ? 'Закрыть' : 'Close').last,
          );
          await tester.pumpAndSettle();
          expect(key('inviter-info-dialog'), findsNothing);
          expect(key('inviter-rules'), findsNothing);
          expect(
            tester
                .widget<TextField>(key('inviter-code-field'))
                .controller!
                .text,
            fixture.codeA,
          );
          await tester.tap(key('inviter-info'));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(key('inviter-info-dialog'), findsNothing);
          expect(key('profile-inviter-section'), findsOneWidget);
          expect(account.submitted, isEmpty);
        },
      );
    }
  }
  inviteTest(
    'open info never keeps previous owner rewarded status after restore',
    (tester) async {
      final account = BindAccount()..inviters['android:1'] = fixture.codeA;
      final service = ProfileInvites(account)..emit();
      await mount(tester, service);
      expect(key('inviter-success'), findsNothing);
      await tester.tap(key('inviter-info'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Бонус начислен'), findsOneWidget);
      service.emit(owner: 'android:2');
      await tester.pumpAndSettle();
      expect(find.textContaining('Бонус начислен'), findsNothing);
      expect(key('inviter-rules'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(key('inviter-locked-code'), findsNothing);
      expect(
        tester.widget<TextField>(key('inviter-code-field')).controller!.text,
        isEmpty,
      );
      expect(account.submitted, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final lang in ['ru', 'en']) {
    for (final size in [const Size(390, 844), const Size(320, 480)]) {
      for (final scale in [1.0, 2.0]) {
        inviteTest('field error and keyboard scroll $lang $size font$scale', (
          tester,
        ) async {
          final account = BindAccount();
          final service = ProfileInvites(account)..emit();
          final keyboard = ValueNotifier(0.0);
          addTearDown(keyboard.dispose);
          await mount(
            tester,
            service,
            size: size,
            lang: lang,
            scale: scale,
            keyboard: keyboard,
          );
          if (size.width == 390 && scale == 1) {
            await type(tester, 'XYZ');
            await apply(tester);
            expect(
              find.textContaining(
                lang == 'ru'
                    ? '6 или 12 латинских букв и цифр'
                    : '6 or 12 Latin letters and digits',
              ),
              findsOneWidget,
            );
            await capture(tester, 'format-error-$lang-390');
          }
          await type(tester, 'CCCCCCCCCCCC');
          await apply(tester);
          expect(key('inviter-error'), findsOneWidget);
          await scrollTo(tester, key('inviter-code-field'));
          await capture(
            tester,
            'profile-$lang-${size.width.toInt()}-font${scale.toInt()}-field',
          );
          await tester.tap(key('inviter-code-field'));
          keyboard.value = size.height == 480 ? 180 : 280;
          await tester.pump();
          await scrollTo(tester, key('inviter-apply'));
          final button = tester.getRect(key('inviter-apply'));
          expect(button.height, greaterThanOrEqualTo(48));
          expect(
            button.bottom,
            lessThanOrEqualTo(size.height - keyboard.value + 1),
          );
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            'profile-$lang-${size.width.toInt()}-font${scale.toInt()}-keyboard',
          );
          keyboard.value = 0;
          await tester.pump();
          await type(tester, fixture.codeA);
          await apply(tester);
          await scrollTo(tester, key('inviter-locked-code'));
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            'profile-$lang-${size.width.toInt()}-font${scale.toInt()}-locked',
          );
        });
      }
    }
  }
}
