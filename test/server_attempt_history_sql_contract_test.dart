import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/domain/average_ranking.dart';
import 'package:game_box/domain/my_attempts.dart';
import 'package:game_box/domain/server_attempt_history.dart';

void main() {
  test(
    'Actual SQL response is the Android curve and current mean without schema translation',
    () {
      final reply = Map<String, dynamic>.from(
        jsonDecode(
              File(
                'test/fixtures/server_attempt_history_sql.json',
              ).readAsStringSync(),
            )
            as Map,
      );
      final history = ServerAttemptHistory.fromJson(
        reply,
        owner: 'supabase:tg_history_owner',
      );
      final data = MyAttemptsData(
        attempts: [],
        ranking: const AverageRanking(mine: AverageRankEntry(averageMs: 99999)),
        isPending: (_) => false,
        serverHistory: history,
      );
      expect(history.complete, true);
      expect(data.historyComplete, true);
      expect(data.rows.map((row) => row.id), [
        'tg_history_owner_0',
        'tg_history_owner_1',
        'tg_history_owner_2',
        'tg_history_owner_3',
        'tg_history_zero',
      ]);
      expect(data.rows.last.timeMs, 0);
      expect(data.averageMs, 5665.183990622241);
      expect(data.ranking!.mine.playerName, 'New history name');
      expect(data.averages['tg_history_owner_0'], 2000);
      expect(data.averages['tg_history_owner_1'], 3201.5621187164243);
      expect(data.averages['tg_history_owner_2'], 4422.457018947937);
      expect(data.averages['tg_history_owner_3'], data.averageMs);
      expect(data.averages['tg_history_zero'], data.averageMs);
      expect(data.referenceAverageMs, isNull);
      expect(data.best!.id, 'tg_history_owner_3');
      expect(data.bestTimeMs, 8000);
      expect(data.best!.runDistance, 3);
      expect(data.numberOf(data.best!.id), 4);
      expect(data.numberOf('tg_history_zero'), 5);
    },
  );
}
