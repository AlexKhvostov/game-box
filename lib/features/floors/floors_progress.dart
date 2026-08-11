import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'floors_data.dart';

/// Статистика одного этажа.
class FloorStats {
  const FloorStats({
    this.completed = false,
    this.bestTimeSec,
    this.attempts = 0,
  });

  final bool completed;
  final double? bestTimeSec;
  final int attempts;

  FloorStats copyWith({
    bool? completed,
    double? bestTimeSec,
    int? attempts,
  }) {
    return FloorStats(
      completed: completed ?? this.completed,
      bestTimeSec: bestTimeSec ?? this.bestTimeSec,
      attempts: attempts ?? this.attempts,
    );
  }
}

/// Прогресс кампании «Этажи» (локально).
class FloorsProgress extends ChangeNotifier {
  FloorsProgress._();

  static final FloorsProgress instance = FloorsProgress._();

  static const _kUnlocked = 'floors_unlocked';
  static const _kCurrent = 'floors_current';
  static const _kStatsPrefix = 'floors_stats_';

  SharedPreferences? _prefs;
  int unlockedFloor = 1;
  int currentFloor = 1;
  final Map<int, FloorStats> _stats = {};

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    unlockedFloor =
        (_prefs!.getInt(_kUnlocked) ?? 1).clamp(1, FloorCatalog.plannedFloors);
    currentFloor =
        (_prefs!.getInt(_kCurrent) ?? unlockedFloor).clamp(1, unlockedFloor);
    _stats.clear();
    for (var i = 1; i <= FloorCatalog.plannedFloors; i++) {
      final raw = _prefs!.getString('$_kStatsPrefix$i');
      if (raw == null || raw.isEmpty) continue;
      final parts = raw.split('|');
      if (parts.length < 3) continue;
      _stats[i] = FloorStats(
        completed: parts[0] == '1',
        bestTimeSec: double.tryParse(parts[1]),
        attempts: int.tryParse(parts[2]) ?? 0,
      );
    }
    notifyListeners();
  }

  FloorStats statsFor(int floor) => _stats[floor] ?? const FloorStats();

  bool isUnlocked(int floor) => floor >= 1 && floor <= unlockedFloor;

  bool isDefined(int floor) => FloorCatalog.byNumber(floor) != null;

  Future<void> selectFloor(int floor) async {
    if (!isUnlocked(floor)) return;
    currentFloor = floor;
    await _prefs?.setInt(_kCurrent, currentFloor);
    notifyListeners();
  }

  Future<void> registerAttempt(int floor) async {
    final s = statsFor(floor);
    _stats[floor] = s.copyWith(attempts: s.attempts + 1);
    await _persistFloor(floor);
    notifyListeners();
  }

  Future<void> registerClear(int floor, double timeSec) async {
    final s = statsFor(floor);
    final best = s.bestTimeSec;
    final nextBest =
        best == null ? timeSec : (timeSec < best ? timeSec : best);
    _stats[floor] = s.copyWith(completed: true, bestTimeSec: nextBest);
    final nextUnlock = (floor + 1).clamp(1, FloorCatalog.plannedFloors);
    if (nextUnlock > unlockedFloor) {
      unlockedFloor = nextUnlock;
      await _prefs?.setInt(_kUnlocked, unlockedFloor);
    }
    // После прохождения остаёмся / переходим на следующий открытый.
    currentFloor = unlockedFloor.clamp(1, FloorCatalog.definedFloors);
    if (FloorCatalog.byNumber(currentFloor) == null) {
      currentFloor = floor;
    }
    await _prefs?.setInt(_kCurrent, currentFloor);
    await _persistFloor(floor);
    notifyListeners();
  }

  Future<void> _persistFloor(int floor) async {
    final s = statsFor(floor);
    final best = s.bestTimeSec?.toStringAsFixed(3) ?? '';
    await _prefs?.setString(
      '$_kStatsPrefix$floor',
      '${s.completed ? 1 : 0}|$best|${s.attempts}',
    );
  }
}
