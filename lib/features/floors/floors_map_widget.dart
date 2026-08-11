import 'package:flutter/material.dart';

import 'floors_data.dart';
import 'floors_session.dart';

/// Радар 5×5: игрок в центре, по 2 клетки вокруг.
class FloorsRadarMap extends StatelessWidget {
  const FloorsRadarMap({
    super.key,
    required this.session,
    this.cellSize = 18,
  });

  final FloorsSession session;
  final double cellSize;

  static const _radius = 2;

  @override
  Widget build(BuildContext context) {
    const n = _radius * 2 + 1;
    return SizedBox(
      width: cellSize * n + 4,
      height: cellSize * n + 4,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: n,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: n * n,
        itemBuilder: (context, i) {
          final dr = i ~/ n - _radius;
          final dc = i % n - _radius;
          final r = session.row + dr;
          final c = session.col + dc;
          final inBounds = session.floor.inBounds(r, c);
          if (!inBounds) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }
          return _MapCell(
            session: session,
            row: r,
            col: c,
            here: dr == 0 && dc == 0,
            compact: true,
          );
        },
      ),
    );
  }
}

/// Полная карта этажа (для модалки).
class FloorsMapWidget extends StatelessWidget {
  const FloorsMapWidget({
    super.key,
    required this.session,
    this.cellSize = 22,
    this.showTitle = true,
  });

  final FloorsSession session;
  final double cellSize;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final floor = session.floor;
    final n = floor.size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle) ...[
          Text(
            '${floor.title} · карта',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: cellSize * n + 4,
          height: cellSize * n + 4,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: n,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: n * n,
            itemBuilder: (context, i) {
              final r = i ~/ n;
              final c = i % n;
              return _MapCell(
                session: session,
                row: r,
                col: c,
                here: r == session.row && c == session.col,
                compact: cellSize < 18,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MapCell extends StatelessWidget {
  const _MapCell({
    required this.session,
    required this.row,
    required this.col,
    required this.here,
    this.compact = false,
  });

  final FloorsSession session;
  final int row;
  final int col;
  final bool here;
  final bool compact;

  static const _fog = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final floor = session.floor;
    final cell = floor.cellAt(row, col);
    final visited = session.isVisited(row, col);
    final tintD = !visited
        ? cell.clampedDifficulty
        : cell.isStart
            ? 0
            : floor.loadoutFor(row, col).difficultyPercent;
    final tintCell = FloorCell(
      difficulty: tintD,
      isStart: cell.isStart,
      isFloorExit: cell.isFloorExit,
    );
    final fill = visited ? FloorDefinition.colorForCell(tintCell) : _fog;
    final crystals = session.crystalRemainingAt(row, col);
    final showKey = visited && session.isKeyAt(row, col);
    final label = !visited
        ? ''
        : cell.isStart
            ? 'S'
            : cell.isFloorExit
                ? '↑'
                : showKey
                    ? 'K'
                    : '';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill.withValues(alpha: visited ? 1 : 0.5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: here
              ? Colors.white
              : (visited && cell.isFloorExit)
                  ? const Color(0xFF7EE0FF)
                  : (visited && showKey)
                      ? const Color(0xFFFFC107)
                      : Colors.black26,
          width: here ||
                  (visited && cell.isFloorExit) ||
                  (visited && showKey)
              ? 1.6
              : 0.5,
        ),
      ),
      child: Stack(
        children: [
          if (label.isNotEmpty)
            Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: compact
                      ? (showKey ? 8 : 7)
                      : (showKey ? 11 : 9),
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          if (crystals > 0 && visited)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: compact ? 5 : 7,
                height: compact ? 5 : 7,
                decoration: BoxDecoration(
                  color: const Color(0xFF7EE0FF),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7EE0FF).withValues(alpha: 0.5),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
