import 'dart:ui' show ViewFocusEvent, ViewFocusState, ViewFocusDirection;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/data/ad_presentation_lease.dart';
import 'package:game_box/data/ads_service.dart';

void main() {
  testWidgets(
    'native ad kept open beyond deadline still returns its SDK reward once',
    (tester) async {
      final lease = AdPresentationLease<AdOutcome>(
        fallback: AdOutcome.unavailable,
      );
      AdOutcome? result;
      lease.result.then((v) => result = v);
      lease.didChangeAppLifecycleState(AppLifecycleState.paused);
      lease.didChangeViewFocus(
        const ViewFocusEvent(
          viewId: 0,
          state: ViewFocusState.unfocused,
          direction: ViewFocusDirection.undefined,
        ),
      );
      await tester.pump(const Duration(minutes: 4));
      expect(result, isNull);
      expect(lease.safeToDispose, false);
      lease.finish(AdOutcome.rewarded);
      lease.finish(AdOutcome.dismissed);
      await tester.pump();
      expect(result, AdOutcome.rewarded);
      expect(lease.safeToDispose, true);
    },
  );

  testWidgets(
    'native return without callback recovers even after a long end card',
    (tester) async {
      final lease = AdPresentationLease<AdOutcome>(
        fallback: AdOutcome.unavailable,
      );
      lease.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 4));
      expect(lease.safeToDispose, false);
      lease.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      expect(await lease.result, AdOutcome.unavailable);
      await tester.tapAt(const Offset(1, 1));
      await tester.pump();
      expect(lease.safeToDispose, true);
    },
  );
  testWidgets(
    'lost callback returns unavailable at deadline, retains native window and never rewards',
    (tester) async {
      final lease = AdPresentationLease<AdOutcome>(
        fallback: AdOutcome.unavailable,
        deadline: const Duration(seconds: 10),
      );
      AdOutcome? result;
      var released = false;
      lease.result.then((v) => result = v);
      lease.released.then((_) => released = true);
      await tester.pump(const Duration(seconds: 10));
      expect(result, AdOutcome.unavailable);
      expect(released, false);
      expect(lease.safeToDispose, false);
      lease.finish(AdOutcome.rewarded);
      await tester.pump();
      expect(result, AdOutcome.unavailable);
      expect(released, true);
    },
  );
  testWidgets(
    'return from native activity releases after grace; late reward cannot turn fallback into credit',
    (tester) async {
      final lease = AdPresentationLease<AdOutcome>(
        fallback: AdOutcome.unavailable,
      );
      AdOutcome? result;
      lease.result.then((v) => result = v);
      lease.didChangeAppLifecycleState(AppLifecycleState.paused);
      lease.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(result, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(result, AdOutcome.unavailable);
      expect(lease.safeToDispose, false);
      await tester.tapAt(const Offset(1, 1));
      await tester.pump();
      expect(lease.safeToDispose, true);
      lease.finish(AdOutcome.rewarded);
      await tester.pump();
      expect(result, AdOutcome.unavailable);
    },
  );
  testWidgets(
    'losing Flutter focus cancels return timer until view actually regains focus',
    (tester) async {
      final lease = AdPresentationLease<bool>(fallback: false);
      lease.didChangeViewFocus(
        const ViewFocusEvent(
          viewId: 0,
          state: ViewFocusState.unfocused,
          direction: ViewFocusDirection.undefined,
        ),
      );
      lease.didChangeAppLifecycleState(AppLifecycleState.paused);
      lease.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 3));
      expect(lease.safeToDispose, false);
      lease.didChangeViewFocus(
        const ViewFocusEvent(
          viewId: 0,
          state: ViewFocusState.focused,
          direction: ViewFocusDirection.undefined,
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(lease.safeToDispose, false);
      await tester.tapAt(const Offset(1, 1));
      await tester.pump();
      expect(lease.safeToDispose, true);
      expect(await lease.result, false);
    },
  );
  testWidgets('normal SDK dismissal wins once and cancels watchdog timers', (
    tester,
  ) async {
    final lease = AdPresentationLease<AdOutcome>(
      fallback: AdOutcome.unavailable,
    );
    lease.finish(AdOutcome.rewarded);
    lease.finish(AdOutcome.dismissed);
    expect(await lease.result, AdOutcome.rewarded);
    expect(lease.safeToDispose, true);
    await tester.pump(const Duration(minutes: 4));
  });
}
