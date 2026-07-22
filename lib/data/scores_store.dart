import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/score_entry.dart';
import 'firebase_bootstrap.dart';

/// Онлайн-рейтинг (Firestore) с локальным кэшем на случай офлайна.
class ScoresStore extends ChangeNotifier {
  static const _kScores = 'local_scores_v1';
  static const _collection = 'scores';
  static const _maxTimeMs = 60 * 60 * 1000; // 1 час — античит-потолок

  late SharedPreferences _prefs;
  final List<ScoreEntry> _scores = [];
  bool online = false;

  List<ScoreEntry> get scores => scoresForPeriod(null);

  /// Сортировка по времени (убыв.). [since] — нижняя граница даты записи.
  List<ScoreEntry> scoresForPeriod(DateTime? since) {
    final copy = [
      for (final s in _scores)
        if (since == null || !s.createdAt.isBefore(since)) s,
    ];
    copy.sort((a, b) => b.timeMs.compareTo(a.timeMs));
    return copy;
  }

  /// День / неделя / месяц / год / всё время.
  List<ScoreEntry> scoresForNamedPeriod(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'day':
        return scoresForPeriod(DateTime(now.year, now.month, now.day));
      case 'week':
        return scoresForPeriod(now.subtract(const Duration(days: 7)));
      case 'month':
        return scoresForPeriod(DateTime(now.year, now.month, 1));
      case 'year':
        return scoresForPeriod(DateTime(now.year, 1, 1));
      default:
        return scoresForPeriod(null);
    }
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadLocal();

    if (!FirebaseBootstrap.ready) {
      online = false;
      notifyListeners();
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .where('fair', isEqualTo: true)
          .orderBy('timeMs', descending: true)
          .limit(100)
          .get();

      _scores
        ..clear()
        ..addAll(snap.docs.map(_fromDoc));
      online = true;
      await _persistLocal();
    } catch (e, st) {
      debugPrint('Firestore leaderboard load failed: $e\n$st');
      // Без индекса fair+timeMs — пробуем простой запрос
      try {
        final snap = await FirebaseFirestore.instance
            .collection(_collection)
            .orderBy('timeMs', descending: true)
            .limit(100)
            .get();
        _scores
          ..clear()
          ..addAll(snap.docs.map(_fromDoc));
        online = true;
        await _persistLocal();
      } catch (e2, st2) {
        debugPrint('Firestore fallback failed: $e2\n$st2');
        online = false;
      }
    }
    notifyListeners();
  }

  Future<void> _loadLocal() async {
    final raw = _prefs.getString(_kScores);
    _scores.clear();
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        _scores.add(ScoreEntry.fromJson(item as Map<String, dynamic>));
      }
    }
  }

  Future<void> _persistLocal() async {
    final encoded = jsonEncode(_scores.map((e) => e.toJson()).toList());
    await _prefs.setString(_kScores, encoded);
  }

  ScoreEntry _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final created = data['createdAt'];
    DateTime createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else {
      createdAt = DateTime.tryParse('$created') ?? DateTime.now();
    }
    return ScoreEntry(
      id: doc.id,
      displayName: (data['displayName'] as String?) ?? 'Player',
      timeMs: (data['timeMs'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      countryCode: (data['countryCode'] as String?)?.toUpperCase() ?? '--',
    );
  }

  RankInfo rankFor(int timeMs, {String period = 'all'}) {
    final list = scoresForNamedPeriod(period);
    final total = list.length;
    if (total == 0) {
      return const RankInfo(place: 1, percentile: 100, totalCount: 0);
    }
    final better = list.where((s) => s.timeMs > timeMs).length;
    final place = better + 1;
    final percentile = (100 * (1 - better / total)).round().clamp(0, 100);
    return RankInfo(place: place, percentile: percentile, totalCount: total);
  }

  /// Места результата по срезам: день / неделя / месяц / год / всё.
  PeriodRanks ranksByPeriod(int timeMs) {
    return PeriodRanks(
      day: rankFor(timeMs, period: 'day'),
      week: rankFor(timeMs, period: 'week'),
      month: rankFor(timeMs, period: 'month'),
      year: rankFor(timeMs, period: 'year'),
      all: rankFor(timeMs, period: 'all'),
    );
  }

  Future<RankInfo> saveScore({
    required String displayName,
    required int timeMs,
    String? countryCode,
  }) async {
    final safeTime = timeMs.clamp(0, _maxTimeMs);
    final cc = (countryCode ?? '--').toUpperCase();
    final entry = ScoreEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      displayName: displayName,
      timeMs: safeTime,
      createdAt: DateTime.now(),
      countryCode: cc,
    );

    if (FirebaseBootstrap.ready && FirebaseBootstrap.uid != null) {
      try {
        final ref = await FirebaseFirestore.instance.collection(_collection).add({
          'uid': FirebaseBootstrap.uid,
          'displayName': displayName,
          'timeMs': safeTime,
          'countryCode': cc,
          'fair': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        final onlineEntry = ScoreEntry(
          id: ref.id,
          displayName: displayName,
          timeMs: safeTime,
          createdAt: DateTime.now(),
          countryCode: cc,
        );
        _scores.add(onlineEntry);
        online = true;
        await _persistLocal();
        notifyListeners();
        await load();
        return rankFor(safeTime);
      } catch (e, st) {
        debugPrint('Firestore save failed: $e\n$st');
      }
    }

    _scores.add(entry);
    await _persistLocal();
    notifyListeners();
    return rankFor(safeTime);
  }
}
