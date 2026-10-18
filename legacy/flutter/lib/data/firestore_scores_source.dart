import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:game_box/data/legacy_scores_source.dart';
import 'package:game_box/domain/score_entry.dart';
import 'firebase_bootstrap.dart';

class FirestoreScoresSource implements LegacyScoresSource {
  static const _collection = 'scores';
  @override
  bool get ready => FirebaseBootstrap.ready;
  @override
  String? get uid => FirebaseBootstrap.uid;
  @override
  Future<List<ScoreEntry>> load() async {
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
    final since = DateTime.now().toUtc().subtract(const Duration(days: 31));
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
      riskCount:
          (data['riskCount'] as num?)?.toInt() ??
          (data['nearMissCount'] as num?)?.toInt() ??
          0,
      runDistance:
          (data['runDistance'] as num?)?.toInt() ??
          (data['playerDistance'] as num?)?.toInt() ??
          0,
      hadJump: data['hadJump'] as bool? ?? false,
      hadHelmet: data['hadHelmet'] as bool? ?? false,
    );
  }

  @override
  Future<ScoreEntry> save(ScoreEntry entry) async {
    final ref = await FirebaseFirestore.instance.collection(_collection).add({
      'uid': uid,
      'displayName': entry.displayName,
      'timeMs': entry.timeMs,
      'countryCode': entry.countryCode,
      'riskCount': entry.riskCount,
      'runDistance': entry.runDistance,
      'hadJump': entry.hadJump,
      'hadHelmet': entry.hadHelmet,
      'fair': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ScoreEntry(
      id: ref.id,
      displayName: entry.displayName,
      timeMs: entry.timeMs,
      createdAt: entry.createdAt,
      countryCode: entry.countryCode,
      uid: uid,
      riskCount: entry.riskCount,
      runDistance: entry.runDistance,
      hadJump: entry.hadJump,
      hadHelmet: entry.hadHelmet,
    );
  }
}
