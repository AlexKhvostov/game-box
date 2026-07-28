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

  SharedPreferences? _prefs;
  final List<ScoreEntry> _scores = [];
  final List<LocalAttempt> _attempts = [];
  bool online = false;
  bool loading = false;
  bool _localReady = false;
  DateTime? _lastRemoteOkAt;
  Future<void>? _inFlightLoad;

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

  /// Обновить с сервера, если кэш устарел или офлайн.
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {
    final last = _lastRemoteOkAt;
    if (online &&
        last != null &&
        DateTime.now().difference(last) < maxAge) {
      return;
    }
    await load();
  }

  Future<void> load() async {
    // Не запускаем параллельные load — ждём текущий.
    if (_inFlightLoad != null) return _inFlightLoad!;
    _inFlightLoad = _loadBody();
    try {
      await _inFlightLoad;
    } finally {
      _inFlightLoad = null;
    }
  }

  Future<void> _loadBody() async {
    loading = true;
    notifyListeners();

    _prefs ??= await SharedPreferences.getInstance();
    if (!_localReady) {
      await _loadLocal();
      await _loadAttempts();
      _localReady = true;
      notifyListeners();
    }

    if (!FirebaseBootstrap.ready) {
      online = false;
      loading = false;
      notifyListeners();
      return;
    }

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final remote = await _fetchRemoteMerged();
        _scores
          ..clear()
          ..addAll(remote);
        online = true;
        _lastRemoteOkAt = DateTime.now();
        await _persistLocal();
        loading = false;
        notifyListeners();
        return;
      } catch (e, st) {
        lastError = e;
        debugPrint('Firestore leaderboard load attempt ${attempt + 1}: $e\n$st');
        await Future<void>.delayed(
          Duration(milliseconds: 350 * (attempt + 1)),
        );
      }
    }

    debugPrint('Firestore leaderboard load gave up: $lastError');
    online = false;
    loading = false;
    notifyListeners();
  }

  /// Top по времени + свежие записи за ~31 день (для вкладок day/week/month).
  Future<List<ScoreEntry>> _fetchRemoteMerged() async {
    final byId = <String, ScoreEntry>{};

    Future<void> take(QuerySnapshot<Map<String, dynamic>> snap) async {
      for (final doc in snap.docs) {
        byId[doc.id] = _fromDoc(doc);
      }
    }

    // 1) All-time top
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .where('fair', isEqualTo: true)
          .orderBy('timeMs', descending: true)
          .limit(150)
          .get();
      await take(snap);
    } catch (e) {
      debugPrint('fair+timeMs query failed, fallback: $e');
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .orderBy('timeMs', descending: true)
          .limit(150)
          .get();
      await take(snap);
    }

    // 2) Recent window — иначе Day/Week пустые, если свежие не в all-time top
    final since =
        DateTime.now().toUtc().subtract(const Duration(days: 31));
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .where('fair', isEqualTo: true)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('createdAt', descending: true)
          .limit(300)
          .get();
      await take(snap);
    } catch (e) {
      debugPrint('fair+createdAt recent query failed, fallback: $e');
      try {
        final snap = await FirebaseFirestore.instance
            .collection(_collection)
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(since),
            )
            .orderBy('createdAt', descending: true)
            .limit(300)
            .get();
        await take(snap);
      } catch (e2) {
        debugPrint('createdAt recent query failed: $e2');
        // Не валим весь load — all-time уже может быть
        if (byId.isEmpty) rethrow;
      }
    }

    if (byId.isEmpty) {
      // Пустая коллекция — нормально для нового проекта.
      return const [];
    }
    return byId.values.toList();
  }

  Future<void> _loadLocal() async {
    final prefs = _prefs!;
    final raw = prefs.getString(_kScores);
    _scores.clear();
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        _scores.add(ScoreEntry.fromJson(item as Map<String, dynamic>));
      }
    }
  }

  Future<void> _persistLocal() async {
    final prefs = _prefs!;
    final encoded = jsonEncode(_scores.map((e) => e.toJson()).toList());
    await prefs.setString(_kScores, encoded);
  }

  Future<void> _loadAttempts() async {
    _attempts.clear();
    final raw = _prefs!.getString(_kAttempts);
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
    await _prefs!.setString(_kAttempts, encoded);
  }

  /// Сброс локальных очков и попыток (тех. сброс «как после установки»).
  Future<void> clearLocalData() async {
    _prefs ??= await SharedPreferences.getInstance();
    _scores.clear();
    _attempts.clear();
    _lastRemoteOkAt = null;
    await _prefs!.remove(_kScores);
    await _prefs!.remove(_kAttempts);
    notifyListeners();
    await load();
  }

  /// Каждая партия (даже без Share) попадает в «Мои попытки».
  Future<void> recordAttempt(
    int timeMs, {
    int riskCount = 0,
    int runDistance = 0,
    bool hadJump = false,
    bool hadHelmet = false,
  }) async {
    final safeTime = timeMs.clamp(0, _maxTimeMs);
    _attempts.insert(
      0,
      LocalAttempt(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        timeMs: safeTime,
        createdAt: DateTime.now(),
        riskCount: riskCount.clamp(0, 99999),
        runDistance: runDistance.clamp(0, 9999999),
        hadJump: hadJump,
        hadHelmet: hadHelmet,
      ),
    );
    if (_attempts.length > _maxAttempts) {
      _attempts.removeRange(_maxAttempts, _attempts.length);
    }
    await _persistAttempts();
    notifyListeners();
  }

  Future<void> _markNearestAttemptShared(
    int timeMs, {
    String? displayName,
  }) async {
    final safe = timeMs.clamp(0, _maxTimeMs);
    final i = _attempts.indexWhere((a) => !a.shared && a.timeMs == safe);
    if (i < 0) return;
    _attempts[i] = _attempts[i].copyWith(
      shared: true,
      displayName: displayName,
    );
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
      uid: data['uid'] as String?,
      riskCount: (data['riskCount'] as num?)?.toInt() ??
          (data['nearMissCount'] as num?)?.toInt() ??
          0,
      runDistance: (data['runDistance'] as num?)?.toInt() ??
          (data['playerDistance'] as num?)?.toInt() ??
          0,
      hadJump: data['hadJump'] as bool? ?? false,
      hadHelmet: data['hadHelmet'] as bool? ?? false,
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
    int riskCount = 0,
    int runDistance = 0,
    bool hadJump = false,
    bool hadHelmet = false,
  }) async {
    final safeTime = timeMs.clamp(0, _maxTimeMs);
    final cc = (countryCode ?? '--').toUpperCase();
    final risk = riskCount.clamp(0, 99999);
    final run = runDistance.clamp(0, 9999999);
    final myUid = FirebaseBootstrap.uid;
    final entry = ScoreEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      displayName: displayName,
      timeMs: safeTime,
      createdAt: DateTime.now(),
      countryCode: cc,
      uid: myUid,
      riskCount: risk,
      runDistance: run,
      hadJump: hadJump,
      hadHelmet: hadHelmet,
    );

    if (FirebaseBootstrap.ready && myUid != null) {
      try {
        final ref = await FirebaseFirestore.instance.collection(_collection).add({
          'uid': myUid,
          'displayName': displayName,
          'timeMs': safeTime,
          'countryCode': cc,
          'riskCount': risk,
          'runDistance': run,
          'hadJump': hadJump,
          'hadHelmet': hadHelmet,
          'fair': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        final onlineEntry = ScoreEntry(
          id: ref.id,
          displayName: displayName,
          timeMs: safeTime,
          createdAt: DateTime.now(),
          countryCode: cc,
          uid: myUid,
          riskCount: risk,
          runDistance: run,
          hadJump: hadJump,
          hadHelmet: hadHelmet,
        );
        // Временно добавим себя, пока ждём полный refresh
        if (!_scores.any((s) => s.id == onlineEntry.id)) {
          _scores.add(onlineEntry);
        }
        await _markNearestAttemptShared(safeTime, displayName: displayName);
        await _persistLocal();
        notifyListeners();
        _lastRemoteOkAt = null; // форсируем полный reload
        await load();
        return rankFor(safeTime);
      } catch (e, st) {
        debugPrint('Firestore save failed: $e\n$st');
      }
    }

    _scores.add(entry);
    await _markNearestAttemptShared(safeTime, displayName: displayName);
    await _persistLocal();
    notifyListeners();
    return rankFor(safeTime);
  }
}
