import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/legacy_scores_source.dart';
import 'package:game_box/data/app_analytics.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/balance/energy_services.dart';
import 'simple_energy_test.dart' as energy;

class FixtureLegacy implements LegacyScoresSource {
  final entries = <ScoreEntry>[];
  @override
  bool get ready => true;
  @override
  String get uid => 'fixture-legacy';
  @override
  Future<List<ScoreEntry>> load() async => List.of(entries);
  @override
  Future<ScoreEntry> save(ScoreEntry entry) async {
    entries.add(entry);
    return entry;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'retained legacy source saves and reads without a native Firebase dependency',
    () async {
      SharedPreferences.setMockInitialValues({});
      final source = FixtureLegacy();
      final scores = ScoresStore(legacySource: source);
      await scores.load();
      expect(scores.online, isTrue);
      await scores.saveScore(displayName: 'Old fixture', timeMs: 2000);
      expect(source.entries.single.timeMs, 2000);
      expect(scores.scores.single.uid, 'fixture-legacy');
      scores.dispose();
    },
  );
  test(
    'optional telemetry is silent by default and sink failure never breaks game',
    () async {
      AppAnalytics.sink = null;
      await AppAnalytics.gameStart();
      final received = <String>[];
      AppAnalytics.sink = (name, _) async {
        received.add(name);
        throw StateError('unavailable');
      };
      await AppAnalytics.gameStart();
      expect(received, ['game_start']);
      AppAnalytics.sink = null;
    },
  );
  testWidgets('zero feedback spend has zero progress and a distinct track', (
    tester,
  ) async {
    final store = await energy.store();
    await tester.pumpWidget(
      ChangeNotifierProvider<EconomyStore>.value(
        value: store,
        child: const MaterialApp(home: Scaffold(body: EnergyFeedbackForm())),
      ),
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('energy-feedback-progress')),
    );
    expect(bar.value, 0);
    expect(bar.backgroundColor, isNot(bar.color));
    expect(bar.backgroundColor!.a, lessThan(.3));
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
