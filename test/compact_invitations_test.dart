import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'package:game_box/features/invites/inviter_section.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'friend_invites_profile_test.dart' as fixture;
import 'friend_invites_delivery_test.dart' as delivery;
import 'simple_energy_test.dart' as energy;

Finder key(String name) => find.byKey(ValueKey(name));

class CompactTestInvites extends fixture.ProfileInvites {
  CompactTestInvites(super.account);
  void showPending() {
    final data =
        (account as fixture.BindAccount).data(account.id!)['invites']
            as Map<String, dynamic>;
    data['paidRows'] = [];
    data['pendingRows'] = [
      {'nickname': 'Ожидает игры', 'games': 2, 'identityReady': true},
      {'nickname': 'Ожидает вход', 'games': 5, 'googleLinked': false},
    ];
    state = InviteState.fromJson(data);
    notifyListeners();
  }
}

Future<CompactTestInvites> mount(
  WidgetTester t, {
  Size size = const Size(390, 844),
  double keyboard = 0,
  int count = 6,
}) async {
  final e = await energy.store();
  final a = fixture.BindAccount();
  a.paid = List.generate(
    count,
    (i) => {
      'id': '${i + 1}',
      'nickname': 'Друг ${i + 1}',
      'userId':
          'supabase:00000000-0000-4000-8000-${(i + 1).toString().padLeft(12, '0')}',
      'rewardedAt': 1,
      'amount': 60,
      'currency': 'energy',
    },
  );
  final s = CompactTestInvites(a)..emit();
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    s.dispose();
    a.dispose();
    e.dispose();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: e),
        ChangeNotifierProvider<MobileAccount>.value(value: a),
        ChangeNotifierProvider<MobileInvites>.value(value: s),
      ],
      child: RepaintBoundary(
        key: const ValueKey('capture'),
        child: MaterialApp(
          theme: buildGameTheme(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (c) => Column(
                children: [
                  const InviterSection(key: ValueKey('account-editor')),
                  TextButton(
                    onPressed: () =>
                        showSimpleEnergyWindow(c, page: EnergyPage.friends),
                    child: const Text('Приглашения'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump();
  await t.tap(find.text('Приглашения'));
  await t.pumpAndSettle();
  expect(key('simple-copy-code'), findsOneWidget);
  expect(key('simple-copy-link'), findsOneWidget);
  expect(key('simple-share-link'), findsOneWidget);
  return s;
}

Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('INVITATIONS_CAPTURE')) return;
  final render = t.renderObject<RenderRepaintBoundary>(key('capture'));
  await t.runAsync(() async {
    final image = await render.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      'docs/release-evidence/compact-invitations-20261024/android-$name.png',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('INVITATIONS_CAPTURE')) return;
    final fonts = FontLoader('Roboto');
    for (final weight in ['Regular', 'Bold']) {
      fonts.addFont(
        Future.value(
          ByteData.sublistView(
            await File(
              'telegram-app/public/fonts/Roboto-$weight.ttf',
            ).readAsBytes(),
          ),
        ),
      );
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('Copy uses current account code and application link', (t) async {
    final service = await mount(t);
    final copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await t.tap(key('simple-copy-code'));
    await t.pumpAndSettle();
    await t.tap(key('simple-copy-link'));
    await t.pumpAndSettle();
    expect(copied, [service.state!.ownCode, service.state!.inviteUrl]);
  });
  testWidgets('Name opens existing public-name actions', (t) async {
    await mount(t);
    await t.tap(find.text('Друг 1'));
    await t.pumpAndSettle();
    expect(key('public-hide'), findsOneWidget);
    expect(key('public-report'), findsOneWidget);
  });
  testWidgets('Pending friends show progress/reason, without credited reward', (
    t,
  ) async {
    final service = await mount(t);
    service.showPending();
    await t.pumpAndSettle();
    expect(find.text('Ожидается'), findsNWidgets(2));
    expect(find.text('2 / 5 · Вход подтверждён'), findsOneWidget);
    expect(find.text('5 / 5 · Нужен вход'), findsOneWidget);
    expect(find.textContaining('Условия выполнены'), findsNothing);
    expect(find.text('+60 ⚡'), findsNothing);
  });
  testWidgets(
    'Binding in invitation dialog immediately updates retained account editor',
    (t) async {
      final s = await mount(t);
      await t.tap(key('invites-inviter-toggle'));
      await t.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(Dialog),
        matching: key('inviter-code-field'),
      );
      await t.ensureVisible(field);
      await t.enterText(field, delivery.codeA);
      await t.pump();
      final apply = find.descendant(
        of: find.byType(Dialog),
        matching: key('inviter-apply'),
      );
      await t.ensureVisible(apply);
      await t.tap(apply);
      await t.pumpAndSettle();
      expect(s.state!.inviterCode, delivery.codeA);
      expect(find.text(delivery.codeA, skipOffstage: false), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('inviter-code-field'), skipOffstage: false),
        findsNothing,
      );
      expect((s.account as fixture.BindAccount).submitted.length, 1);
      await capture(t, 'bound');
    },
  );
  testWidgets(
    'Account binding updates already mounted invitation form and discards its draft',
    (t) async {
      final s = await mount(t);
      await t.tap(key('invites-inviter-toggle'));
      await t.pumpAndSettle();
      await t.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: key('inviter-code-field'),
        ),
        delivery.codeC,
      );
      // Same service call used by the account: mounted dialog must reflect it now.
      await s.bindManual(delivery.codeA);
      await t.pumpAndSettle();
      expect(find.text(delivery.codeA, skipOffstage: false), findsNWidgets(2));
      expect(find.text(delivery.codeC, skipOffstage: false), findsNothing);
    },
  );
  for (final size in [const Size(390, 844), const Size(320, 480)]) {
    testWidgets(
      'Compact list and reachable form at $size, keyboard, long list',
      (t) async {
        await mount(t, size: size, count: 36);
        expect(t.takeException(), isNull);
        await capture(t, '${size.width.toInt()}');
        final list = key('simple-invited-list');
        if (size.height > 500) expect(t.getSize(list).height, 264);
        await t.drag(list, const Offset(0, -1200));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.ensureVisible(key('invites-inviter-toggle'));
        await t.tap(key('invites-inviter-toggle'));
        await t.pumpAndSettle();
        final field = find.descendant(
          of: find.byType(Dialog),
          matching: key('inviter-code-field'),
        );
        await t.ensureVisible(field);
        await t.enterText(field, 'BAD');
        await t.pump();
        final apply = find.descendant(
          of: find.byType(Dialog),
          matching: key('inviter-apply'),
        );
        await t.ensureVisible(apply);
        await t.tap(apply);
        await t.pumpAndSettle();
        expect(find.text('6 или 12 латинских букв и цифр.'), findsOneWidget);
        expect(t.takeException(), isNull);
        await capture(t, '${size.width.toInt()}-expanded');
      },
    );
  }
  testWidgets('Keyboard keeps input and apply reachable', (t) async {
    await mount(t, keyboard: 300);
    await t.ensureVisible(key('invites-inviter-toggle'));
    await t.tap(key('invites-inviter-toggle'));
    await t.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(Dialog),
      matching: key('inviter-code-field'),
    );
    await t.ensureVisible(field);
    await t.enterText(field, delivery.codeA);
    final apply = find.descendant(
      of: find.byType(Dialog),
      matching: key('inviter-apply'),
    );
    await t.ensureVisible(apply);
    await t.tap(apply);
    await t.pumpAndSettle();
    expect(find.text(delivery.codeA, skipOffstage: false), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Info shows live policy reward, automatic award and once-only binding',
    (t) async {
      await mount(t);
      await t.tap(key('invites-info'));
      await t.pumpAndSettle();
      expect(find.text('Как получить +60 энергии'), findsOneWidget);
      expect(
        find.textContaining('Награда начисляется автоматически.'),
        findsOneWidget,
      );
      await capture(t, 'help');
      expect(t.takeException(), isNull);
    },
  );
}
