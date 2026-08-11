import 'dart:math';

import 'package:flutter/material.dart';

import 'floors_loadout.dart';

/// Клетка карты этажа.
class FloorCell {
  const FloorCell({
    required this.difficulty,
    this.isStart = false,
    this.isFloorExit = false,
  });

  final int difficulty;
  final bool isStart;
  final bool isFloorExit;

  int get clampedDifficulty => difficulty.clamp(0, 100);
}

/// Настройки этажа целиком + карта сложностей.
class FloorDefinition {
  const FloorDefinition({
    required this.floorNumber,
    required this.size,
    required this.cells,
    this.maxEnemies = 4,
    this.allowWalls = false,
    this.allowBonusDrops = false,
    this.allowDebuffDrops = false,
    this.allowMovingExits = false,
    this.title = 'Этаж',
    this.tutorial = false,
  });

  final int floorNumber;
  final int size;
  final List<List<FloorCell>> cells;
  final int maxEnemies;
  final bool allowWalls;
  final bool allowBonusDrops;
  final bool allowDebuffDrops;
  final bool allowMovingExits;
  final String title;
  final bool tutorial;

  int get startRow => size ~/ 2;
  int get startCol => size ~/ 2;

  int get totalCrystals {
    var sum = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        sum += crystalAmountAt(r, c);
      }
    }
    return sum;
  }

  FloorCell cellAt(int row, int col) => cells[row][col];

  bool inBounds(int row, int col) =>
      row >= 0 && col >= 0 && row < size && col < size;

  int crystalAmountAt(int row, int col) {
    final cell = cellAt(row, col);
    if (cell.isStart && !tutorial) return 0;
    if (tutorial) return row == 0 && col == 0 ? 1 : 0;
    final roll =
        (Object.hash(floorNumber, row, col, 0xC2A57) & 0x7fffffff) % 100;
    if (roll < 48) return 0;
    if (roll < 76) return 1;
    if (roll < 90) return 2;
    return 5;
  }

  /// Клетка с ключом. На 1×1 — та же клетка (старт+выход).
  (int, int) get keyCell {
    final candidates = <(int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final cell = cellAt(r, c);
        if (cell.isStart || cell.isFloorExit) continue;
        candidates.add((r, c));
      }
    }
    if (candidates.isEmpty) {
      return (startRow, startCol);
    }
    final i =
        (Object.hash(floorNumber, 'floor_key') & 0x7fffffff) % candidates.length;
    return candidates[i];
  }

  bool isKeyCell(int row, int col) {
    final k = keyCell;
    return k.$1 == row && k.$2 == col;
  }

  RoomLoadout loadoutFor(int row, int col) {
    final cell = cellAt(row, col);
    if (tutorial) {
      return const RoomLoadout(
        enemyCount: 1,
        speedMult: 0.42,
        accelMult: 0.35,
      );
    }
    if (cell.isStart) {
      return const RoomLoadout(
        enemyCount: 0,
        speedMult: 0.65,
        accelMult: 0.55,
      );
    }
    final rng = Random(
      Object.hash(floorNumber, row, col, cell.clampedDifficulty),
    );
    return RoomLoadoutCatalog.compose(
      targetD: cell.clampedDifficulty,
      maxEnemies: maxEnemies,
      allowWalls: allowWalls,
      allowMovingExits: allowMovingExits,
      allowBonusDrops: allowBonusDrops,
      allowDebuffDrops: allowDebuffDrops,
      rng: rng,
    );
  }

  static Color colorForCell(FloorCell cell) {
    if (cell.isStart) return const Color(0xFF6B7280);
    final t = cell.clampedDifficulty / 100.0;
    if (t < 0.5) {
      return Color.lerp(
        const Color(0xFF3DDC97),
        const Color(0xFFFFC107),
        t * 2,
      )!;
    }
    return Color.lerp(
      const Color(0xFFFFC107),
      const Color(0xFFFF3D4A),
      (t - 0.5) * 2,
    )!;
  }

  static Color fieldColorForCell(FloorCell cell, Color base) {
    final tint = colorForCell(cell);
    final amount = cell.isStart ? 0.38 : 0.48;
    return Color.lerp(base, tint, amount)!;
  }
}

/// Каталог этажей кампании.
class FloorCatalog {
  FloorCatalog._();

  /// Реально играбельные сейчас.
  static const definedFloors = 5;

  /// План башни (остальное — «в тумане»).
  static const plannedFloors = 20;

  static int sizeFor(int floorNumber) => (2 * floorNumber - 1).clamp(1, 99);

  static FloorDefinition? byNumber(int n) {
    if (n < 1 || n > definedFloors) return null;
    return switch (n) {
      1 => floor1,
      2 => _gridFloor(2, allowMoving: false, allowWalls: false, maxEnemies: 2),
      3 => _gridFloor(3, allowMoving: true, allowWalls: true, maxEnemies: 3),
      4 => _gridFloor(4, allowMoving: true, allowWalls: true, maxEnemies: 4),
      5 => _gridFloor(5, allowMoving: true, allowWalls: true, maxEnemies: 4),
      _ => null,
    };
  }

  static FloorDefinition? nextAfter(int floorNumber) =>
      byNumber(floorNumber + 1);

  /// Этаж 1: 1×1, ознакомительный.
  static FloorDefinition get floor1 {
    return const FloorDefinition(
      floorNumber: 1,
      size: 1,
      title: 'Этаж 1',
      maxEnemies: 1,
      allowWalls: false,
      allowMovingExits: false,
      tutorial: true,
      cells: [
        [
          FloorCell(difficulty: 8, isStart: true, isFloorExit: true),
        ],
      ],
    );
  }

  static FloorDefinition _gridFloor(
    int floorNumber, {
    required bool allowMoving,
    required bool allowWalls,
    required int maxEnemies,
  }) {
    final n = sizeFor(floorNumber);
    final mid = n ~/ 2;
    final cells = List<List<FloorCell>>.generate(n, (r) {
      return List<FloorCell>.generate(n, (c) {
        if (r == mid && c == mid) {
          return const FloorCell(difficulty: 0, isStart: true);
        }
        if (r == 0 && c == mid) {
          final exitD = (55 + floorNumber * 8).clamp(60, 95);
          return FloorCell(difficulty: exitD, isFloorExit: true);
        }
        final dist = (r - mid).abs() + (c - mid).abs();
        final d = (8 + dist * (6 + floorNumber) + ((r + c) % 3) * 3)
            .clamp(5, 100);
        return FloorCell(difficulty: d);
      });
    });
    return FloorDefinition(
      floorNumber: floorNumber,
      size: n,
      title: 'Этаж $floorNumber',
      maxEnemies: maxEnemies,
      allowWalls: allowWalls,
      allowBonusDrops: false,
      allowDebuffDrops: false,
      allowMovingExits: allowMoving,
      cells: cells,
    );
  }
}
