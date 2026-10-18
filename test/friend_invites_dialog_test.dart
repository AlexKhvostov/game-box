import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/invites/invite_action_card.dart';
import 'package:game_box/features/invites/invitations_dialog.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_viewport.dart';
import 'friend_invites_delivery_test.dart' as fixture;

const captureKey = ValueKey('invites-capture');
const visual = bool.fromEnvironment('FRIEND_INVITES_VISUAL_QA');
const evidencePrefix = String.fromEnvironment(
  'FRIEND_INVITES_EVIDENCE_PREFIX',
  defaultValue: 'executor-preview1',
);
Finder key(String value) => find.byKey(ValueKey(value));

class UiInvites extends MobileInvites {
  UiInvites({super.enabled = true})
    : super(
        account: fixture.Account(),
        source: fixture.Source(),
        vault: fixture.Vault(),
      );
  int refreshCalls = 0, pageCalls = 0;
  Future<void> Function()? refreshReply, pageReply;
  @override
  Future<void> refresh() async {
    refreshCalls++;
    if (refreshReply != null) await refreshReply!();
    notifyListeners();
  }

  @override
  Future<void> loadMore() async {
    pageCalls++;
    if (pageReply != null) await pageReply!();
    notifyListeners();
  }

  void emit({String? owner, InviteState? value, String? failure}) {
    if (owner != null) account.id = owner;
    state = value;
    error = failure;
    notifyListeners();
  }
}

InviteState paidState({
  String owner = 'android:1',
  int rows = 0,
  bool paging = false,
  bool longNames = false,
}) {
  final account = fixture.Account()..id = owner;
  final data = account.data(owner)['invites'] as Map<String, dynamic>;
  data['rewardTotal'] = rows * 10;
  data['nextCursor'] = paging ? '20' : null;
  data['paidRows'] = List.generate(
    rows,
    (i) => {
      'id': '${i + 1}',
      'nickname': i == 1
          ? null
          : longNames
          ? 'Александр Очень Длинное Имя Игрока Alexander very long player name $i'
          : 'Friend ${i + 1}',
      'rewardedAt': DateTime(2026, 10, 13).millisecondsSinceEpoch,
      'amount': 10,
    },
  );
  return InviteState.fromJson(data);
}

Future<EconomyStore> open(
  WidgetTester tester,
  UiInvites service, {
  InvitationActions actions = const InvitationActions(),
  Size size = const Size(390, 844),
  String lang = 'ru',
  double scale = 1,
  bool shop = false,
  bool card = false,
  bool viewport = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final economy = EconomyStore();
  await economy.load();
  economy.tokens = 999;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    economy.dispose();
    service.dispose();
    service.account.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider<MobileInvites>.value(value: service),
      ],
      child: RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildGameTheme(),
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: viewport ? GameViewport(child: child!) : child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: card
                  ? InviteActionCard(actions: actions)
                  : TextButton(
                      onPressed: () => shop
                          ? showCrystalsSheet(context, initialTab: 3)
                          : showInvitationsDialog(context, actions: actions),
                      child: const Text('Open'),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  if (!card) await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return economy;
}

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find.descendant(
        of: key('invitations-scroll'),
        matching: find.byType(Scrollable),
      ),
    );
  }
  await tester.ensureVisible(target);
  await tester.pump();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!visual) return;
  await tester.pump();
  final render = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  final metrics = <String, dynamic>{
    'rendering': 'widget Segoe-as-Roboto, not phone',
  };
  for (final item in [
    'invitations-dialog',
    'invitation-invite-group',
    'invitation-history-group',
  ]) {
    if (key(item).evaluate().isNotEmpty) {
      metrics[item == 'invitations-dialog'
          ? 'dialogRouteHeight'
          : '${item}Height'] = tester
          .getSize(key(item))
          .height;
    }
  }
  final chrome = find.descendant(
    of: key('invitations-dialog'),
    matching: find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'GameSheetChrome',
    ),
  );
  if (chrome.evaluate().isNotEmpty) {
    metrics['sheetHeight'] = tester.getSize(chrome).height;
  }
  await tester.runAsync(() async {
    final image = await render.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      'docs/release-evidence/friend-invites-order-20261014/$evidencePrefix/$name.png',
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
      testWidgets('compact inline share and info $lang small$small', (
        tester,
      ) async {
        final service = UiInvites()..error = 'invites_unavailable';
        await open(
          tester,
          service,
          lang: lang,
          size: small ? const Size(320, 480) : const Size(390, 844),
          scale: small ? 2 : 1,
        );
        expect(key('invitation-rules-card'), findsNothing);
        final link = tester.getRect(key('invitation-copy-link'));
        final share = tester.getRect(
          find.ancestor(
            of: key('invitation-share'),
            matching: find.byType(IconButton),
          ),
        );
        expect(link.center.dy, closeTo(share.center.dy, .001));
        expect(share.width, 36);
        expect(share.height, 36);
        await capture(tester, 'inline-modal-$lang-small$small');
        final requests = service.refreshCalls;
        service.busy = true;
        service.notifyListeners();
        await tester.pump();
        final info = tester
            .widget<IconButton>(key('invitation-info'))
            .onPressed!;
        info();
        info();
        service.busy = false;
        service.notifyListeners();
        await tester.pumpAndSettle();
        expect(key('invitation-info-dialog'), findsOneWidget);
        final rules = tester.widget<Text>(key('invitation-info-rules')).data!;
        for (final word in [
          '5',
          '10',
          'Google',
          'Untouch',
          lang == 'ru' ? 'один раз' : 'once',
        ]) {
          expect(rules, contains(word));
        }
        expect(service.refreshCalls, requests);
        expect(service.pageCalls, 0);
        expect(service.state, isNull);
        await capture(tester, 'inline-info-$lang-small$small');
        final close = find.descendant(
          of: key('invitation-info-dialog'),
          matching: find.byType(IconButton),
        );
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(key('invitation-info-dialog'), findsNothing);
        expect(key('invitations-dialog'), findsOneWidget);
        await tester.tap(key('invitation-info'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(key('invitation-info-dialog'), findsNothing);
        expect(service.refreshCalls, requests);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'one Android earn card preserves four tabs and opens one modal',
    (tester) async {
      final service = UiInvites()..state = paidState();
      await open(tester, service, shop: true, viewport: true);
      expect(key('invite-action-card'), findsOneWidget);
      expect(tester.widget<TabBar>(find.byType(TabBar)).tabs.length, 4);
      expect(
        tester.getSize(key('invite-action-card')).height,
        greaterThanOrEqualTo(48),
      );
      await capture(tester, 'earn-ru-390');
      final openCallback = tester
          .widget<InkWell>(
            find.descendant(
              of: key('invite-action-card'),
              matching: find.byType(InkWell),
            ),
          )
          .onTap!;
      openCallback();
      openCallback();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(key('invitations-dialog'), findsOneWidget);
      await tester.tap(find.byTooltip('Закрыть').last);
      await tester.pumpAndSettle();
      expect(key('invitations-dialog'), findsNothing);
      expect(key('invite-action-card'), findsOneWidget);
      await tester.tap(key('invite-action-card'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(key('invitations-dialog'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'disabled or non Android card hidden $platform',
      (tester) async {
        final service = UiInvites(enabled: platform != TargetPlatform.android);
        await open(tester, service, card: true);
        expect(key('invite-action-card'), findsNothing);
        expect(key('invitations-dialog'), findsNothing);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
  testWidgets('missing provider card is harmless', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: InviteActionCard()));
    expect(key('invite-action-card'), findsNothing);
  });

  testWidgets(
    'saved null callbacks do not toast after owner or epoch changes',
    (tester) async {
      final service = UiInvites()..error = 'invites_unavailable';
      await open(tester, service);
      final copyCode = tester
          .widget<IconButton>(key('invitation-copy-code'))
          .onPressed!;
      final copyLink = tester
          .widget<IconButton>(key('invitation-copy-link'))
          .onPressed!;
      final share = tester
          .widget<IconButton>(
            find.ancestor(
              of: key('invitation-share'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed!;
      service.emit(owner: 'android:2');
      copyCode();
      copyLink();
      share();
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_GameToastHost',
        ),
        findsNothing,
      );
      service.emit(owner: 'android:1');
      copyCode();
      copyLink();
      share();
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_GameToastHost',
        ),
        findsNothing,
      );
      expect(service.state, isNull);
    },
  );

  testWidgets('cached current code and link survive refresh error', (
    tester,
  ) async {
    final service = UiInvites()
      ..state = paidState()
      ..error = 'network';
    final copied = <String>[];
    await open(
      tester,
      service,
      actions: InvitationActions(
        copy: (text) async {
          copied.add(text);
        },
      ),
    );
    expect(
      tester.widget<Text>(key('invitation-own-code')).data,
      fixture.ownGuest,
    );
    expect(
      tester.widget<Text>(key('invitation-own-link')).data,
      service.state!.inviteUrl,
    );
    expect(find.text('Недоступно в тесте'), findsNothing);
    await scrollTo(tester, key('invitation-copy-link'));
    await tester.tap(key('invitation-copy-link'));
    await tester.pumpAndSettle();
    expect(copied, [service.state!.inviteUrl]);
    expect(service.refreshCalls, 1);
  });

  for (final lang in ['ru', 'en']) {
    for (final small in [false, true]) {
      testWidgets(
        'null layout actions have no fake payload $lang small$small',
        (tester) async {
          final service = UiInvites()..error = 'invites_unavailable';
          final copied = <String>[], shared = <String>[];
          await open(
            tester,
            service,
            lang: lang,
            size: small ? const Size(320, 480) : const Size(390, 844),
            scale: small ? 2 : 1,
            actions: InvitationActions(
              copy: (text) async {
                copied.add(text);
              },
              share: (text, _) async {
                shared.add(text);
                return ShareResultStatus.success;
              },
            ),
          );
          final marker = lang == 'ru'
              ? 'Недоступно в тесте'
              : 'Unavailable in this test';
          expect(tester.widget<Text>(key('invitation-own-code')).data, marker);
          expect(tester.widget<Text>(key('invitation-own-link')).data, marker);
          expect(key('invitations-error'), findsNothing);
          expect(key('invitation-reward-total'), findsNothing);
          expect(key('invitation-paid-1'), findsNothing);
          await capture(tester, 'null-modal-$lang-small$small');
          final requests = service.refreshCalls;
          for (final button in [
            'invitation-copy-code',
            'invitation-copy-link',
            'invitation-share',
          ]) {
            await scrollTo(tester, key(button));
            await tester.tap(key(button));
            await tester.pump();
            expect(find.text(marker), findsWidgets);
            await tester.pumpAndSettle();
          }
          await scrollTo(tester, key('invitation-history-group'));
          expect(
            find.descendant(
              of: key('invitation-history-group'),
              matching: find.text('—'),
            ),
            findsOneWidget,
          );
          expect(copied, isEmpty);
          expect(shared, isEmpty);
          expect(service.refreshCalls, requests);
          expect(service.state, isNull);
          expect(service.pageCalls, 0);
          service.emit(value: paidState());
          await tester.pumpAndSettle();
          await tester.drag(key('invitations-scroll'), const Offset(0, 1000));
          await tester.pumpAndSettle();
          expect(
            tester.widget<Text>(key('invitation-own-code')).data,
            fixture.ownGuest,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final mode in ['empty', 'unavailable', 'paid']) {
    testWidgets('dense groups shrink for a short history $mode', (
      tester,
    ) async {
      final service = UiInvites();
      if (mode == 'unavailable') {
        service.error = 'invites_unavailable';
      } else {
        service.state = paidState(
          rows: mode == 'paid' ? 2 : 0,
          longNames: true,
        );
      }
      await open(tester, service);
      final first = key('invitation-invite-group'),
          second = key('invitation-history-group');
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      final chrome = find.descendant(
        of: key('invitations-dialog'),
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'GameSheetChrome',
        ),
      );
      expect(tester.getSize(chrome).height, lessThan(500));
      expect(
        tester.getRect(second).top,
        greaterThan(tester.getRect(first).bottom),
      );
      if (mode != 'unavailable') {
        for (final name in [
          'invitation-own-code',
          'invitation-own-link',
          'invitation-share',
        ]) {
          expect(
            find.descendant(of: first, matching: key(name)),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(of: second, matching: key('invitation-reward-total')),
          findsOneWidget,
        );
        if (mode == 'paid') {
          expect(
            find.descendant(of: second, matching: key('invitation-paid-1')),
            findsOneWidget,
          );
        }
      }
      await capture(tester, 'dense-modal-$mode-ru-390');
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(key('invitations-dialog'), findsNothing);
    });
  }

  testWidgets('loading then empty history without fabricated invite code', (
    tester,
  ) async {
    final held = Completer<void>();
    final service = UiInvites()..refreshReply = () => held.future;
    await open(tester, service);
    expect(key('invitations-loading'), findsOneWidget);
    expect(key('invitation-copy-code'), findsOneWidget);
    expect(key('invitation-share'), findsOneWidget);
    await capture(tester, 'loading-ru-390');
    service.emit(value: paidState());
    held.complete();
    await tester.pumpAndSettle();
    expect(key('invitations-loading'), findsNothing);
    expect(key('invitation-history-empty'), findsOneWidget);
    expect(key('invitation-reward-total'), findsOneWidget);
    await capture(tester, 'empty-ru-390');
  });

  for (final failure in ['invites_unavailable', 'network']) {
    testWidgets('unavailable full layout receives real state $failure', (
      tester,
    ) async {
      final service = UiInvites()..error = failure;
      await open(tester, service);
      expect(key('invitations-error'), findsNothing);
      expect(key('invitation-share'), findsOneWidget);
      await capture(tester, 'error-$failure-ru-390');
      service.emit(value: paidState());
      await tester.pumpAndSettle();
      expect(service.refreshCalls, 1);
      expect(key('invitations-error'), findsNothing);
      expect(key('invitation-own-code'), findsOneWidget);
    });
  }

  testWidgets(
    'native clipboard receives exactly code then link, no wallet/API operation',
    (tester) async {
      final service = UiInvites()..state = paidState();
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final economy = await open(tester, service);
      await tester.tap(key('invitation-copy-code'));
      await tester.pumpAndSettle();
      await tester.tap(key('invitation-copy-link'));
      await tester.pumpAndSettle();
      expect(copied, [
        fixture.ownGuest,
        'https://untouch.fun/a/${fixture.ownGuest}',
      ]);
      expect(economy.tokens, 999);
      expect(service.refreshCalls, 1);
      expect(service.pageCalls, 0);
      expect((service.account as fixture.Account).bindings, isEmpty);
    },
  );

  testWidgets(
    'share dispatches bounded public payload and does not claim delivery or reward',
    (tester) async {
      final service = UiInvites()..state = paidState();
      final shared = <String>[];
      final economy = await open(
        tester,
        service,
        actions: InvitationActions(
          share: (text, origin) async {
            expect(origin.width, greaterThanOrEqualTo(36));
            expect(origin.height, greaterThanOrEqualTo(36));
            shared.add(text);
            return ShareResultStatus.dismissed;
          },
        ),
      );
      await tester.tap(key('invitation-share'));
      await tester.pumpAndSettle();
      expect(shared.single, contains(service.state!.inviteUrl));
      expect(shared.single, contains(service.state!.ownCode));
      expect(shared.single, contains('5 игр'));
      expect(shared.single, contains('10 кристаллов'));
      expect(shared.single, contains('должен быть подключён Google'));
      expect(shared.single, isNot(contains('android:1')));
      expect(key('invitations-error'), findsNothing);
      expect(find.text('Приглашение отправлено'), findsNothing);
      expect(economy.tokens, 999);
      expect(service.refreshCalls, 1);
    },
  );

  testWidgets(
    'default SharePlus invokes existing native channel with text and origin only',
    (tester) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return 'dev.fluttercommunity.plus/share/dismissed';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final service = UiInvites()..state = paidState();
      final economy = await open(tester, service);
      await tester.tap(key('invitation-share'));
      await tester.pumpAndSettle();
      expect(calls.length, 1);
      expect(calls.single.method, 'share');
      final args = calls.single.arguments as Map;
      expect(args['subject'], 'Untouch');
      expect(args['text'], contains(service.state!.inviteUrl));
      expect(args.keys.toSet(), {
        'text',
        'subject',
        'originX',
        'originY',
        'originWidth',
        'originHeight',
      });
      expect(economy.tokens, 999);
      expect(service.refreshCalls, 1);
    },
  );

  testWidgets(
    'old callback cannot share invalidated cached code on same profile',
    (tester) async {
      final service = UiInvites()..state = paidState();
      var calls = 0;
      await open(
        tester,
        service,
        actions: InvitationActions(
          copy: (_) async {
            calls++;
          },
          share: (_, _) async {
            calls++;
            return ShareResultStatus.success;
          },
        ),
      );
      final copy = tester
          .widget<IconButton>(key('invitation-copy-code'))
          .onPressed!;
      final share = tester
          .widget<IconButton>(
            find.ancestor(
              of: key('invitation-share'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed!;
      service.emit(value: paidState());
      // Invalidate the cached payload without changing the account ID.
      service.state = null;
      copy();
      share();
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(
        tester.widget<Text>(key('invitation-own-code')).data,
        'Недоступно в тесте',
      );
    },
  );

  testWidgets('copy and share failures retry only the same external action', (
    tester,
  ) async {
    final service = UiInvites()..state = paidState();
    var copies = 0, shares = 0;
    await open(
      tester,
      service,
      actions: InvitationActions(
        copy: (_) async {
          if (++copies == 1) throw StateError('clipboard');
        },
        share: (_, _) async {
          shares++;
          return ShareResultStatus.unavailable;
        },
      ),
    );
    await tester.tap(key('invitation-copy-link'));
    await tester.pumpAndSettle();
    expect(key('invitations-error'), findsOneWidget);
    await scrollTo(tester, find.text('Повторить'));
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(copies, 2);
    expect(key('invitations-error'), findsNothing);
    await scrollTo(tester, key('invitation-share'));
    await tester.tap(key('invitation-share'));
    await tester.pumpAndSettle();
    expect(key('invitations-error'), findsOneWidget);
    await scrollTo(tester, find.text('Повторить'));
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(shares, 2);
    expect(service.refreshCalls, 1);
  });

  testWidgets(
    'paging loading and rejection retain paid history; retry appends rows',
    (tester) async {
      final service = UiInvites()..state = paidState(rows: 2, paging: true);
      final held = Completer<void>();
      service.pageReply = () => held.future;
      await open(tester, service);
      await scrollTo(tester, key('invitation-load-more'));
      await tester.tap(key('invitation-load-more'));
      await tester.pump();
      expect(
        tester.widget<OutlinedButton>(key('invitation-load-more')).onPressed,
        isNull,
      );
      expect(key('invitation-paid-1'), findsOneWidget);
      held.completeError(StateError('network'));
      await tester.pumpAndSettle();
      expect(key('invitation-page-error'), findsOneWidget);
      expect(key('invitation-paid-1'), findsOneWidget);
      await capture(tester, 'paging-error-ru-390');
      service.pageReply = () async => service.emit(value: paidState(rows: 3));
      await scrollTo(tester, find.text('Повторить'));
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(service.pageCalls, 2);
      expect(key('invitation-paid-3'), findsOneWidget);
      expect(key('invitation-page-error'), findsNothing);
      expect(key('invitation-load-more'), findsNothing);
    },
  );

  testWidgets(
    'old callbacks cannot copy or share after owner changes before rebuild',
    (tester) async {
      final service = UiInvites()..state = paidState(rows: 1);
      var copies = 0, shares = 0;
      await open(
        tester,
        service,
        actions: InvitationActions(
          copy: (_) async {
            copies++;
          },
          share: (_, _) async {
            shares++;
            return ShareResultStatus.success;
          },
        ),
      );
      final copy = tester
          .widget<IconButton>(key('invitation-copy-code'))
          .onPressed!;
      final link = tester
          .widget<IconButton>(key('invitation-copy-link'))
          .onPressed!;
      final share = tester
          .widget<IconButton>(
            find.ancestor(
              of: key('invitation-share'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed!;
      service.emit(
        owner: 'android:2',
        value: paidState(owner: 'android:2'),
      );
      copy();
      link();
      share();
      await tester.pumpAndSettle();
      expect(copies, 0);
      expect(shares, 0);
      expect(find.text(fixture.ownGuest), findsNothing);
      expect(find.text(fixture.ownRestored), findsOneWidget);
      expect(key('invitation-paid-1'), findsNothing);
    },
  );

  for (final action in ['copy', 'share', 'page']) {
    testWidgets(
      'stale $action completion cannot show old toast/error in restored profile',
      (tester) async {
        final service = UiInvites()..state = paidState(rows: 1, paging: true);
        final held = Completer<void>();
        service.pageReply = () => held.future;
        await open(
          tester,
          service,
          actions: InvitationActions(
            copy: (_) => held.future,
            share: (_, _) async {
              await held.future;
              return ShareResultStatus.unavailable;
            },
          ),
        );
        final target = key(
          action == 'copy'
              ? 'invitation-copy-code'
              : action == 'share'
              ? 'invitation-share'
              : 'invitation-load-more',
        );
        await scrollTo(tester, target);
        await tester.tap(target);
        await tester.pump();
        service.emit(
          owner: 'android:2',
          value: paidState(owner: 'android:2'),
        );
        if (action == 'copy') {
          held.complete();
        } else {
          held.completeError(StateError('old owner'));
        }
        await tester.pumpAndSettle();
        expect(key('invitations-error'), findsNothing);
        expect(key('invitation-page-error'), findsNothing);
        expect(find.text('Код скопирован'), findsNothing);
        expect(find.text(fixture.ownGuest), findsNothing);
      },
    );
  }

  for (final lang in ['ru', 'en']) {
    for (final size in [const Size(390, 844), const Size(320, 480)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('scrollable localized paid only UI $lang $size font$scale', (
          tester,
        ) async {
          final service = UiInvites()
            ..state = paidState(rows: 12, longNames: true, paging: true);
          await open(tester, service, size: size, lang: lang, scale: scale);
          for (final name in ['invitation-copy-code', 'invitation-copy-link']) {
            await scrollTo(tester, key(name));
            final rect = tester.getRect(key(name));
            // Scrolled global coordinates can differ by floating-point epsilon.
            // Keep the compact 36 reference-unit icon bounds, allowing 1e-6 rounding.
            expect(rect.width, greaterThanOrEqualTo(36 - 1e-6));
            expect(rect.height, greaterThanOrEqualTo(36 - 1e-6));
          }
          final close = find.byTooltip(lang == 'ru' ? 'Закрыть' : 'Close');
          expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
          expect(
            tester
                .getSize(
                  find.text(lang == 'ru' ? 'ПРИГЛАШЕНИЯ' : 'INVITATIONS'),
                )
                .height,
            // The default test Ahem font has intentionally uniform wide glyphs.
            // Single-line typography is checked with the real visual QA font.
            lessThanOrEqualTo(visual ? 28 : 84),
          );
          expect(tester.takeException(), isNull);
          await tester.drag(key('invitations-scroll'), const Offset(0, 2000));
          await tester.pumpAndSettle();
          await capture(
            tester,
            'paid-$lang-${size.width.toInt()}-font${scale.toInt()}-top',
          );
          await scrollTo(tester, key('invitation-paid-2'));
          expect(
            find.text(lang == 'ru' ? 'Игрок удалён' : 'Deleted player'),
            findsOneWidget,
          );
          expect(find.text('+10'), findsWidgets);
          await capture(
            tester,
            'paid-$lang-${size.width.toInt()}-font${scale.toInt()}-history',
          );
          await scrollTo(tester, key('invitation-load-more'));
          expect(
            tester.getSize(key('invitation-load-more')).height,
            greaterThanOrEqualTo(48),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(key('invitations-dialog'), findsNothing);
        });
      }
    }
  }
}
