import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/score_entry.dart';

/// Локальный рейтинг до подключения Firebase.
class LocalScoresStore extends ChangeNotifier {
  static const _kScores = 'local_scores_v1';

  late SharedPreferences _prefs;
  final List<ScoreEntry> _scores = [];

  List<ScoreEntry> get scores {
    final copy = [..._scores];
    copy.sort((a, b) => b.timeMs.compareTo(a.timeMs));
    return copy;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_kScores);
    _scores.clear();
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        _scores.add(ScoreEntry.fromJson(item as Map<String, dynamic>));
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_scores.map((e) => e.toJson()).toList());
    await _prefs.setString(_kScores, encoded);
    notifyListeners();
  }

  RankInfo rankFor(int timeMs) {
    final total = _scores.length;
    if (total == 0) {
      return const RankInfo(place: 1, percentile: 100, totalCount: 0);
    }
    final better = _scores.where((s) => s.timeMs > timeMs).length;
    final place = better + 1;
    final percentile = (100 * (1 - better / total)).round().clamp(0, 100);
    return RankInfo(place: place, percentile: percentile, totalCount: total);
  }

  Future<RankInfo> saveScore({
    required String displayName,
    required int timeMs,
  }) async {
    final entry = ScoreEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      displayName: displayName,
      timeMs: timeMs,
      createdAt: DateTime.now(),
    );
    _scores.add(entry);
    await _persist();
    return rankFor(timeMs);
  }
}
