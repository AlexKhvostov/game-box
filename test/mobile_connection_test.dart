import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_connection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'resume during Google preparation waits even before native busy',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final account = MobileAccount()
        ..googleStage = GoogleConnectionStage.preparing;
      var refreshes = 0;
      final connection = MobileConnection(
        account: account,
        synchronize: () async {
          refreshes++;
        },
      )..start();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(refreshes, 0);
      account.googleStage = null;
      account.notifyListeners();
      await tester.pump();
      expect(refreshes, 1);
      connection.dispose();
      account.dispose();
    },
  );
  testWidgets(
    'failed startup reconnects when network returns without restart',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var attempts = 0;
      var network = false;
      final connection = MobileConnection(
        account: MobileAccount(),
        retryDelay: const Duration(seconds: 5),
        synchronize: () async {
          attempts++;
          if (!network) throw const MobileApiError('connection_failed');
        },
      )..start();
      addTearDown(connection.dispose);
      await tester.pump();
      expect(attempts, 1);
      network = true;
      await tester.pump(const Duration(seconds: 5));
      expect(attempts, 2);
      await tester.pump(const Duration(seconds: 20));
      expect(attempts, 2);
      connection.dispose();
    },
  );

  testWidgets('pause stops retries and resume immediately reconnects', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var attempts = 0;
    final connection = MobileConnection(
      account: MobileAccount(),
      synchronize: () async {
        attempts++;
        throw const MobileApiError('connection_failed');
      },
    )..start();
    addTearDown(connection.dispose);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    expect(attempts, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(attempts, 2);
    connection.dispose();
  });

  testWidgets('native Google resume waits until identity operation finishes', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final account = MobileAccount()..busy = true;
    var refreshes = 0;
    final connection = MobileConnection(
      account: account,
      synchronize: () async {
        refreshes++;
      },
    )..start();
    addTearDown(connection.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(refreshes, 0);
    account.busy = false;
    account.notifyListeners();
    await tester.pump();
    expect(refreshes, 1);
    connection.dispose();
  });

  testWidgets('resume signals never run parallel synchronization', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final waiting = Completer<void>();
    var active = 0;
    var maxActive = 0;
    final connection = MobileConnection(
      account: MobileAccount(),
      synchronize: () async {
        active++;
        if (active > maxActive) maxActive = active;
        await waiting.future;
        active--;
      },
    )..start();
    addTearDown(connection.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    unawaited(connection.reconnect());
    await tester.pump();
    expect(maxActive, 1);
    waiting.complete();
    await tester.pump();
    expect(active, 0);
    expect(maxActive, 1);
    connection.dispose();
  });

  testWidgets('disposing pending retry cannot reconnect', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var attempts = 0;
    final connection = MobileConnection(
      account: MobileAccount(),
      synchronize: () async {
        attempts++;
        throw const MobileApiError('connection_failed');
      },
    )..start();
    await tester.pump();
    connection.dispose();
    await tester.pump(const Duration(seconds: 20));
    expect(attempts, 1);
  });
}
