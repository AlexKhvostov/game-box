import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/ui/game_status_overlay.dart';

import 'blue_glass_profile_test.dart' as profile;
import 'friend_invites_dialog_test.dart' as invitations;
import 'friend_invites_profile_test.dart' as inviter;
import 'friend_invites_delivery_test.dart' as invite_data;
import 'simple_energy_test.dart' as fixture;

class _PendingRename extends profile.ProfileTestAccount {
  final reply = Completer<void>();

  @override
  Future<void> rename(String value) => reply.future;
}

void main() {
  testWidgets(
    'Nickname transport error preserves editor and profile geometry',
    (t) async {
      final account = _PendingRename()
        ..id = 'qa:status'
        ..nickname = 'Player';
      await profile.mountProfile(
        t,
        fixtureAccount: account,
        size: const Size(390, 844),
      );
      final editor = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_NicknameEditor',
      );
      await t.enterText(
        find.byKey(const ValueKey('profile-nickname-input')),
        'NewPlayer',
      );
      await t.pumpAndSettle();
      final initial = t.getSize(editor);
      await t.tap(find.byKey(const ValueKey('profile-nickname-save')));
      await t.pump();
      expect(t.getSize(editor), initial);
      account.reply.completeError(StateError('network'));
      await t.pump();
      await t.pump();
      expect(
        find.text('Не удалось сохранить. Попробуйте ещё раз.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile-nickname-message')),
        findsNothing,
      );
      expect(t.getSize(editor), initial);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      account.dispose();
    },
  );

  testWidgets(
    'Invitation refresh status and retry leave both panels stationary',
    (t) async {
      final service = invitations.UiInvites()..state = invitations.paidState();
      await invitations.open(t, service);
      final panel = invitations.key('invitation-invite-group');
      final initial = t.getRect(panel);
      service.emit(value: service.state, failure: 'network');
      await t.pump();
      expect(invitations.key('invitations-error'), findsOneWidget);
      expect(t.getRect(panel), initial);
      final held = Completer<void>();
      service.refreshReply = () => held.future;
      await t.tap(find.text('Повторить'));
      await t.pump();
      expect(invitations.key('invitations-loading'), findsOneWidget);
      expect(t.getRect(panel), initial);
      service.emit(value: service.state);
      held.complete();
      await t.pumpAndSettle();
      expect(invitations.key('invitations-error'), findsNothing);
      expect(invitations.key('invitations-loading'), findsNothing);
      expect(t.getRect(panel), initial);
      expect(t.takeException(), isNull);
    },
  );

  inviter.inviteTest('Inviter network error preserves compact section height', (
    t,
  ) async {
    final account = inviter.BindAccount()..bindFailure = 'connection_failed';
    final service = inviter.ProfileInvites(account)..emit();
    await inviter.mount(t, service);
    await inviter.type(t, invite_data.codeA);
    final section = inviter.key('profile-inviter-section');
    final initial = t.getSize(section);
    await inviter.apply(t);
    expect(inviter.key('inviter-error'), findsOneWidget);
    expect(t.getSize(section), initial);
    expect(t.takeException(), isNull);
  });

  testWidgets('Transient main-screen status floats without moving the HUD', (
    t,
  ) async {
    const hud = ValueKey('status-hud');
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                const SizedBox(key: hud, width: 150, height: 40),
                TextButton(
                  onPressed: () => showGameStatus(
                    context,
                    message: 'Проверьте соединение',
                    isError: true,
                    duration: const Duration(seconds: 1),
                  ),
                  child: const Text('Сообщение'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final initial = t.getRect(find.byKey(hud));
    await t.tap(find.text('Сообщение'));
    await t.pumpAndSettle();
    expect(find.text('Проверьте соединение'), findsOneWidget);
    expect(t.getRect(find.byKey(hud)), initial);
    expect(
      t.widget<SnackBar>(find.byType(SnackBar)).behavior,
      SnackBarBehavior.floating,
    );
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.byType(GameStatusCard), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Busy and error statuses preserve geometry and pass touches', (
    t,
  ) async {
    String? message;
    var busy = false;
    var taps = 0;
    late StateSetter rebuild;
    const surface = ValueKey('status-underlying-surface');
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return GameStatusOverlay(
                message: message,
                busy: busy,
                isError: message == 'Ошибка',
                child: SizedBox.expand(
                  key: surface,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TextButton(
                      onPressed: () => taps++,
                      child: const Text('Действие'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    final baseline = t.getRect(find.byKey(surface));
    final button = t.getRect(find.text('Действие'));
    rebuild(() {
      message = 'Подтверждаем…';
      busy = true;
    });
    await t.pump();
    expect(find.text('Подтверждаем…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(t.getRect(find.byKey(surface)), baseline);
    expect(t.getRect(find.text('Действие')), button);
    // Tap the region covered by the non-blocking bottom status.
    await t.tap(find.text('Действие'));
    expect(taps, 1);
    rebuild(() {
      message = 'Ошибка';
      busy = false;
    });
    await t.pump();
    expect(find.text('Ошибка'), findsOneWidget);
    expect(t.getRect(find.byKey(surface)), baseline);
    expect(t.getRect(find.text('Действие')), button);
    rebuild(() => message = null);
    await t.pump();
    expect(find.byType(GameStatusCard), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Route-owned status disappears immediately when dialog closes', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => GameStatusOverlay(
                  message: 'Подтверждаем…',
                  busy: true,
                  child: AlertDialog(
                    content: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Закрыть'),
                    ),
                  ),
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Открыть'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Подтверждаем…'), findsOneWidget);
    await t.tap(find.text('Закрыть'));
    await t.pumpAndSettle();
    expect(find.byType(GameStatusCard), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Bottom status fits narrow screens, text scale and keyboard', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: const EdgeInsets.only(bottom: 220),
            padding: const EdgeInsets.only(bottom: 20),
            textScaler: TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: GameStatusOverlay(
            message: 'Не удалось подтвердить. Проверьте связь и повторите.',
            isError: true,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    await t.pump();
    final card = t.getRect(find.byType(GameStatusCard));
    expect(card.left, greaterThanOrEqualTo(16));
    expect(card.right, lessThanOrEqualTo(304));
    expect(card.bottom, lessThanOrEqualTo(568 - 220));
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'Energy bonus pending and failed request do not move its window',
    (t) async {
      final e = await fixture.store();
      addTearDown(e.dispose);
      final request = Completer<void>();
      e.sendEnergyOperation = (_, _) => request.future;
      await t.pumpWidget(fixture.app(e));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      final window = find.byKey(const ValueKey('simple-energy-window'));
      final initial = t.getRect(window);
      await t.tap(find.byKey(const ValueKey('simple-bonus-orb')));
      await t.pump();
      expect(find.text('Подтверждаем…'), findsOneWidget);
      expect(t.getRect(window), initial);
      request.completeError(StateError('offline'));
      await t.pump();
      await t.pump();
      expect(
        find.text('Не удалось подтвердить. Проверьте связь и повторите.'),
        findsOneWidget,
      );
      expect(t.getRect(window), initial);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
}
