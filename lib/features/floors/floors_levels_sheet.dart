import 'package:flutter/material.dart';

import 'floors_data.dart';
import 'floors_map_widget.dart';
import 'floors_progress.dart';
import 'floors_session.dart';

/// Пирамида этажей: 1 снизу, выше вверху; выше defined — туман.
Future<void> showFloorsLevelsSheet({
  required BuildContext context,
  required FloorsProgress progress,
  required void Function(int floorNumber) onPlayFloor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0E1419),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scroll) {
          return _LevelsPyramid(
            progress: progress,
            scrollController: scroll,
            onPlayFloor: (n) {
              Navigator.pop(ctx);
              onPlayFloor(n);
            },
          );
        },
      );
    },
  );
}

class _LevelsPyramid extends StatefulWidget {
  const _LevelsPyramid({
    required this.progress,
    required this.scrollController,
    required this.onPlayFloor,
  });

  final FloorsProgress progress;
  final ScrollController scrollController;
  final void Function(int floorNumber) onPlayFloor;

  @override
  State<_LevelsPyramid> createState() => _LevelsPyramidState();
}

class _LevelsPyramidState extends State<_LevelsPyramid> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    final c = widget.scrollController;
    if (!c.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      return;
    }
    c.jumpTo(c.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final order = [
      for (var i = FloorCatalog.plannedFloors; i >= 1; i--) i,
    ];
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Башня этажей',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFFE8EEF4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Открыто до этажа ${widget.progress.unlockedFloor}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 28),
            itemCount: order.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return const _FogCap();
              final floor = order[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LevelRow(
                  floorNumber: floor,
                  progress: widget.progress,
                  onTap: () => _onTileTap(context, floor),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _onTileTap(BuildContext context, int floor) {
    if (!widget.progress.isUnlocked(floor)) return;
    if (!widget.progress.isDefined(floor)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Этажи выше пока в тумане')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => _LevelPreviewDialog(
        floorNumber: floor,
        progress: widget.progress,
        onPlay: () {
          Navigator.pop(ctx);
          widget.onPlayFloor(floor);
        },
      ),
    );
  }
}

class _FogCap extends StatelessWidget {
  const _FogCap();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF7EE0FF).withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Text(
        '… выше — туман …',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// Статус слева от карточки · карточка одной высоты · инфо справа.
class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.floorNumber,
    required this.progress,
    required this.onTap,
  });

  final int floorNumber;
  final FloorsProgress progress;
  final VoidCallback onTap;

  static const double _rowH = 56;

  @override
  Widget build(BuildContext context) {
    final unlocked = progress.isUnlocked(floorNumber);
    final defined = progress.isDefined(floorNumber);
    final stats = progress.statsFor(floorNumber);
    final size = FloorCatalog.sizeFor(floorNumber);
    final current = progress.currentFloor == floorNumber;
    // Нижние шире, но минимум достаточный для «Этаж 1».
    final widthFactor = (0.55 + floorNumber * 0.028).clamp(0.58, 0.96);

    return SizedBox(
      height: _rowH,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Center(
              child: _StatusGlyph(
                unlocked: unlocked,
                completed: stats.completed,
                defined: defined,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: unlocked ? onTap : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      height: _rowH,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: unlocked
                              ? (current
                                  ? const [
                                      Color(0xFF1A3A2E),
                                      Color(0xFF12241E),
                                    ]
                                  : const [
                                      Color(0xFF1A222C),
                                      Color(0xFF12181E),
                                    ])
                              : const [
                                  Color(0xFF0C1014),
                                  Color(0xFF080A0C),
                                ],
                        ),
                        border: Border.all(
                          color: current
                              ? const Color(0xFF3DDC97)
                              : (unlocked
                                  ? const Color(0xFF2A3540)
                                  : const Color(0xFF1A222C)),
                          width: current ? 1.6 : 1,
                        ),
                        boxShadow: unlocked
                            ? [
                                BoxShadow(
                                  color: (current
                                          ? const Color(0xFF3DDC97)
                                          : const Color(0xFF7EE0FF))
                                      .withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Этаж $floorNumber',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: unlocked
                                  ? const Color(0xFFE8EEF4)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            '$size×$size',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: unlocked
                                  ? const Color(0xFF7EE0FF)
                                      .withValues(alpha: 0.85)
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: _SideStats(unlocked: unlocked, stats: stats),
          ),
        ],
      ),
    );
  }
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({
    required this.unlocked,
    required this.completed,
    required this.defined,
  });

  final bool unlocked;
  final bool completed;
  final bool defined;

  @override
  Widget build(BuildContext context) {
    if (!unlocked) {
      return const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF4B5563));
    }
    if (completed) {
      return const Icon(
        Icons.check_circle_rounded,
        size: 16,
        color: Color(0xFF3DDC97),
      );
    }
    return Icon(
      defined ? Icons.stairs_rounded : Icons.cloud_rounded,
      size: 15,
      color: const Color(0xFF7EE0FF).withValues(alpha: 0.85),
    );
  }
}

class _SideStats extends StatelessWidget {
  const _SideStats({
    required this.unlocked,
    required this.stats,
  });

  final bool unlocked;
  final FloorStats stats;

  @override
  Widget build(BuildContext context) {
    if (!unlocked) {
      return Text(
        'закрыт',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.28),
        ),
      );
    }
    if (stats.completed && stats.bestTimeSec != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatFloorTime(stats.bestTimeSec!),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3DDC97),
            ),
          ),
          Text(
            '${stats.attempts} поп.',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      );
    }
    if (stats.attempts > 0) {
      return Text(
        '${stats.attempts} поп.',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      );
    }
    return Text(
      'новый',
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFFFC107).withValues(alpha: 0.75),
      ),
    );
  }
}

String formatFloorTime(double sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  if (m > 0) return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
  return '${s.toStringAsFixed(1)} с';
}

class _LevelPreviewDialog extends StatelessWidget {
  const _LevelPreviewDialog({
    required this.floorNumber,
    required this.progress,
    required this.onPlay,
  });

  final int floorNumber;
  final FloorsProgress progress;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final def = FloorCatalog.byNumber(floorNumber)!;
    final stats = progress.statsFor(floorNumber);
    final preview = FloorsSession(def);
    final n = def.size;
    final maxSide = MediaQuery.sizeOf(context).shortestSide * 0.7;
    final cell = ((maxSide - 8) / n).clamp(12.0, 40.0);

    return Dialog(
      backgroundColor: const Color(0xFF12181E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: const Color(0xFF3DDC97).withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    def.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFFE8EEF4),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white70,
                ),
              ],
            ),
            // Характеристики карты — над картой.
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Chip(label: '${def.size}×${def.size}'),
                  _Chip(label: 'кристаллов ~${def.totalCrystals}'),
                  if (def.tutorial) const _Chip(label: 'обучение'),
                  if (def.allowWalls) const _Chip(label: 'стены'),
                  if (def.allowMovingExits) const _Chip(label: 'ходы'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FloorsMapWidget(
              session: preview,
              cellSize: cell,
              showTitle: false,
            ),
            const SizedBox(height: 10),
            // Результаты прохождения — под картой.
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stats.completed && stats.bestTimeSec != null)
                    Text(
                      'Лучшее время: ${formatFloorTime(stats.bestTimeSec!)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3DDC97),
                      ),
                    )
                  else
                    Text(
                      'Ещё не пройден',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    'Попыток: ${stats.attempts}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onPlay,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3DDC97),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text(
                'Играть на этом этаже',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF7EE0FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: c,
        ),
      ),
    );
  }
}
