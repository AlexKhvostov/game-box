import 'floors_config.dart';
import 'floors_data.dart';

/// Состояние прохождения текущего этажа.
class FloorsSession {
  FloorsSession(this.floor)
      : row = floor.startRow,
        col = floor.startCol {
    _markVisited();
  }

  FloorDefinition floor;
  int row;
  int col;
  final Set<String> visited = {};

  /// Сколько кристаллов уже взято с клетки (`floor:r,c` → count).
  final Map<String, int> _crystalTaken = {};

  /// Ключ текущего этажа (нужен для лестницы вверх).
  bool hasFloorKey = false;

  double floorElapsedSec = 0;
  double lifeElapsedSec = 0;
  double lifeRampT = 0;

  FloorCell get currentCell => floor.cellAt(row, col);

  void tickActiveTimers(double dt) {
    if (dt <= 0) return;
    floorElapsedSec += dt;
    lifeElapsedSec += dt;
  }

  void resetLifeProgress() {
    lifeElapsedSec = 0;
    lifeRampT = 0;
  }

  void resetFloorTimers() {
    floorElapsedSec = 0;
    resetLifeProgress();
  }

  String get _key => '${floor.floorNumber}:$row,$col';

  String _cellKey(int r, int c) => '${floor.floorNumber}:$r,$c';

  void _markVisited() => visited.add(_key);

  bool isVisited(int r, int c) =>
      visited.contains('${floor.floorNumber}:$r,$c');

  int crystalAmountAt(int r, int c) => floor.crystalAmountAt(r, c);

  int crystalTakenAt(int r, int c) => _crystalTaken[_cellKey(r, c)] ?? 0;

  int crystalRemainingAt(int r, int c) =>
      (crystalAmountAt(r, c) - crystalTakenAt(r, c)).clamp(0, 99);

  bool hasCrystalsAt(int r, int c) => crystalRemainingAt(r, c) > 0;

  bool takeCrystalAt(int r, int c) {
    if (crystalRemainingAt(r, c) <= 0) return false;
    final k = _cellKey(r, c);
    _crystalTaken[k] = crystalTakenAt(r, c) + 1;
    return true;
  }

  bool get keyStillOnMap => !hasFloorKey;

  bool isKeyAt(int r, int c) => floor.isKeyCell(r, c) && !hasFloorKey;

  bool tryPickKeyAt(int r, int c) {
    if (hasFloorKey || !floor.isKeyCell(r, c)) return false;
    hasFloorKey = true;
    return true;
  }

  (int, int)? neighbor(WallSide side) {
    final r = row +
        (side == WallSide.top
            ? -1
            : side == WallSide.bottom
                ? 1
                : 0);
    final c = col +
        (side == WallSide.left
            ? -1
            : side == WallSide.right
                ? 1
                : 0);
    if (!floor.inBounds(r, c)) return null;
    return (r, c);
  }

  List<WallSide> openSides() {
    return [
      for (final s in WallSide.values)
        if (neighbor(s) != null) s,
    ];
  }

  WallSide? moveThrough(WallSide side) {
    final n = neighbor(side);
    if (n == null) return null;
    row = n.$1;
    col = n.$2;
    _markVisited();
    return switch (side) {
      WallSide.top => WallSide.bottom,
      WallSide.bottom => WallSide.top,
      WallSide.left => WallSide.right,
      WallSide.right => WallSide.left,
    };
  }

  void respawnAtStart() {
    row = floor.startRow;
    col = floor.startCol;
    _markVisited();
  }

  bool enterNextFloor() {
    final next = FloorCatalog.nextAfter(floor.floorNumber);
    if (next == null) return false;
    floor = next;
    row = floor.startRow;
    col = floor.startCol;
    visited.clear();
    _crystalTaken.clear();
    hasFloorKey = false;
    resetFloorTimers();
    _markVisited();
    return true;
  }

  void resetCampaign() {
    floor = FloorCatalog.floor1;
    row = floor.startRow;
    col = floor.startCol;
    visited.clear();
    _crystalTaken.clear();
    hasFloorKey = false;
    resetFloorTimers();
    _markVisited();
  }
}
