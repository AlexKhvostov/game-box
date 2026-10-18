import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/android_energy.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/energy_widgets.dart';

const stamp = 2000000000000;
Map<String, dynamic> simpleWallet({
  int balance = 50,
  int tier = 1,
  int nextAt = 0,
}) => {
  'energyVersion': 2,
  'energy': balance,
  'energyConfig': const AndroidEnergyConfig(
    enabled: true,
    initialEnergy: 50,
    rewards: {'ad': 40, 'invite': 60},
  ).toJson(),
  'simpleBonus': {
    'contract': 3,
    'nextAt': nextAt,
    'durationMs': 28800000,
    'reward': tier * 30,
    'tier': tier,
    'policy': {'periodSec': 28800, 'tier2Reward': 60, 'tier5Reward': 150},
  },
  if (tier > 1)
    'energySubscription': {
      'batteryCount': tier,
      'expiresAt': stamp + 86400000,
      'productId': 'energy_batteries_${tier}_v1',
    },
  'claimed': <String>[],
  'unlocked': <String>[],
  'batteries': [],
};
Future<EconomyStore> store({
  int balance = 50,
  int tier = 1,
  int nextAt = 0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final e = EconomyStore(storagePrefix: 'simple_tests_');
  await e.load();
  await e.applyServerWallet(
    simpleWallet(balance: balance, tier: tier, nextAt: nextAt),
    serverNow: stamp,
    owner: 'android:1',
  );
  return e;
}

Widget app(
  EconomyStore e, {
  EnergyPage page = EnergyPage.energy,
  double scale = 1,
}) => ChangeNotifierProvider.value(
  value: e,
  child: MaterialApp(
    theme: buildGameTheme(),
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: TextButton(
            onPressed: () => showSimpleEnergyWindow(c, page: page),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);
void main() {
  test('Bonus has an indivisible boundary and freezes period', () {
    final b = SimpleEnergyBonus.fromJson({
      'nextAt': stamp + 28800000,
      'durationMs': 28800000,
      'reward': 40,
      'tier': 2,
    });
    expect(
      b
          .remainingAt(DateTime.fromMillisecondsSinceEpoch(stamp + 28799999))
          .inMilliseconds,
      1,
    );
    expect(
      b.remainingAt(DateTime.fromMillisecondsSinceEpoch(stamp + 28800000)),
      Duration.zero,
    );
    expect(
      b.remainingAt(DateTime.fromMillisecondsSinceEpoch(stamp + 28800000 * 3)),
      Duration.zero,
    );
    expect(b.reward, 40);
    expect(bonusTime(const Duration(milliseconds: 1)), '00:00:01');
  });
  test(
    'Pending claim never changes confirmed balance before response',
    () async {
      final e = await store();
      final pending = Completer<void>();
      String? kind;
      e.sendEnergyOperation = (k, a) {
        kind = k;
        return pending.future;
      };
      final job = e.claimSimpleEnergyBonus();
      expect(e.energyBusy, isTrue);
      expect(e.energy, 50);
      expect(kind, 'energy_bonus_claim');
      pending.completeError(StateError('offline'));
      await expectLater(job, throwsStateError);
      expect(e.energy, 50);
      expect(e.energyBusy, isFalse);
      expect(e.energyError, isNotNull);
      e.dispose();
    },
  );
  test(
    'Subscriber can watch voluntary rewarded video; cooldown persists',
    () async {
      final e = await store(tier: 5);
      expect(e.energySubscribed, isTrue);
      expect(e.canClaimWatchAd, isTrue);
      await e.applyServerWallet(
        {...simpleWallet(tier: 5), 'lastAdAt': stamp},
        serverNow: stamp,
        owner: 'android:1',
      );
      expect(e.canClaimWatchAd, isFalse);
      expect(
        e.watchAdCooldownRemaining!.inMilliseconds,
        inInclusiveRange(119000, 120000),
      );
      expect(e.energyConfig.reward('watch_ad'), 40);
      e.dispose();
    },
  );
  for (final size in const [Size(393, 852), Size(320, 568), Size(320, 480)]) {
    for (final scale in [1.0, 2.0]) {
      for (final page in EnergyPage.values) {
        testWidgets(
          'Current window $page $size font$scale fits with fallback',
          (t) async {
            final e = await store(
              balance: 99999,
              tier: 5,
              nextAt: stamp + 14400000,
            );
            addTearDown(e.dispose);
            await t.binding.setSurfaceSize(size);
            addTearDown(() => t.binding.setSurfaceSize(null));
            await t.pumpWidget(app(e, page: page, scale: scale));
            await t.tap(find.text('open'));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            expect(
              find.byKey(const ValueKey('simple-energy-window')),
              findsOneWidget,
            );
            expect(find.text('Заряд'), findsNothing);
            expect(find.text('Задания'), findsNothing);
            expect(find.text('Батарейки'), findsNothing);
            final rect = t.getRect(
              find.byKey(const ValueKey('simple-energy-window')),
            );
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            if (page == EnergyPage.helmet) {
              expect(
                find.byKey(const ValueKey('simple-helmet-illustration')),
                findsOneWidget,
              );
              expect(find.byType(Image), findsOneWidget);
            }
            await t.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
  testWidgets('Children return using system Back; UI does not claim energy', (
    t,
  ) async {
    final e = await store();
    addTearDown(e.dispose);
    var claims = 0;
    e.sendEnergyOperation = (k, a) async {
      claims++;
    };
    await t.pumpWidget(app(e));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('simple-energy-friends')));
    await t.tap(find.byKey(const ValueKey('simple-energy-friends')));
    await t.pumpAndSettle();
    expect(find.text('Пригласить друга'), findsWidgets);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Энергия'), findsOneWidget);
    expect(find.byKey(const ValueKey('simple-bonus-orb')), findsOneWidget);
    expect(claims, 0);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('simple-energy-window')), findsNothing);
  });
  for (final balance in [50, 1500, 99999]) {
    testWidgets('H01 $balance keeps round plus', (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 144,
              height: 44,
              child: EnergyBalanceCapsule(amount: balance, showPlus: true),
            ),
          ),
        ),
      );
      final size = t.getSize(
        find.byKey(const ValueKey('energy-capsule-plus-disc')),
      );
      expect(size.width, size.height);
      expect(t.takeException(), isNull);
    });
  }
}
