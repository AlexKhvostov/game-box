import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/score_entry.dart';
import 'firebase_bootstrap.dart';

/// Онлайн-рейтинг (Firestore) с локальным кэшем на случай офлайна.
class ScoresStore extends ChangeNotifier {
  static const _kScores = 'local_scores_v1';
  static const _kAttempts = 'local_attempts_v1';
  static const _collection = 'scores';
  static const _maxTimeMs = 60 * 60 * 1000; // 1 час — античит-потолок
  static const _maxAttempts = 200;

  late SharedPreferences _prefs;
  final List<ScoreEntry> _scores = [];
  final List<LocalAttempt> _attempts = [];
  bool online = false;

  List<ScoreEntry> get scores => scoresForPeriod(null);

  /// Мои попытки (сохранённые и нет), новые сверху.
  List<LocalAttempt> get myAttempts {
    final copy = [..._attempts];
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

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
    await _loadAttempts();

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

  Future<void> _loadAttempts() async {
    _attempts.clear();
    final raw = _prefs.getString(_kAttempts);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        _attempts.add(LocalAttempt.fromJson(item as Map<String, dynamic>));
      }
    } catch (e, st) {
      debugPrint('Local attempts load failed: $e\n$st');
    }
  }

  Future<void> _persistAttempts() async {
    final encoded = jsonEncode(_attempts.map((e) => e.toJson()).toList());
    await _prefs.setString(_kAttempts, encoded);
  }

  /// Сброс локальных очков и попыток (тех. сброс «как после установки»).
  Future<void> clearLocalData() async {
    _scores.clear();
    _attempts.clear();
    await _prefs.remove(_kScores);
    await _prefs.remove(_kAttempts);
    notifyListeners();
  }

  /// Каждая партия (даже без Share) попадает в «Мои попытки».
  Future<void> recordAttempt(int timeMs) async {
    final safeTime = timeMs.clamp(0, _maxTimeMs);
    _attempts.insert(
      0,
      LocalAttempt(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        timeMs: safeTime,
        createdAt: DateTime.now(),
      ),
    );
    if (_attempts.length > _maxAttempts) {
      _attempts.removeRange(_maxAttempts, _attempts.length);
    }
    await _persistAttempts();
    notifyListeners();
  }

  Future<void> _markNearestAttemptShared(int timeMs) async {
    final safe = timeMs.clamp(0, _maxTimeMs);
    final i = _attempts.indexWhere((a) => !a.shared && a.timeMs == safe);
    if (i < 0) return;
    _attempts[i] = _attempts[i].copyWith(shared: true);
    await _persistAttempts();
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
        await _markNearestAttemptShared(safeTime);
        await _persistLocal();
        notifyListeners();
        await load();
        return rankFor(safeTime);
      } catch (e, st) {
        debugPrint('Firestore save failed: $e\n$st');
      }
    }

    _scores.add(entry);
    await _markNearestAttemptShared(safeTime);
    await _persistLocal();
    notifyListeners();
    return rankFor(safeTime);
  }
}
