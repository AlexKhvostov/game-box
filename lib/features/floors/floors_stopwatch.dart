import 'package:flutter/material.dart';

/// Компактный секундомер: крупные равные цифры, минимум хрома.
class FloorsStopwatch extends StatelessWidget {
  const FloorsStopwatch({
    super.key,
    required this.label,
    required this.seconds,
    required this.accent,
  });

  final String label;
  final double seconds;
  final Color accent;

  static const _digitStyle = TextStyle(
    fontSize: 22,
    height: 1.0,
    fontWeight: FontWeight.w900,
    fontFeatures: [FontFeature.tabularFigures()],
    color: Color(0xFFE8EEF4),
    letterSpacing: 0.5,
  );

  @override
  Widget build(BuildContext context) {
    final totalMs = (seconds.clamp(0.0, 35999.999) * 1000).floor();
    final m = totalMs ~/ 60000;
    final s = (totalMs % 60000) ~/ 1000;
    final ms = totalMs % 1000;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF12181E),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              height: 1.0,
              color: accent.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _col('мин', m.toString().padLeft(2, '0')),
              _sep(':'),
              _col('сек', s.toString().padLeft(2, '0')),
              _sep('.'),
              _col('мс', ms.toString().padLeft(3, '0')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _col(String caption, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          caption,
          style: TextStyle(
            fontSize: 7,
            height: 1.0,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.32),
          ),
        ),
        Text(value, style: _digitStyle),
      ],
    );
  }

  Widget _sep(String char) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1, left: 1, right: 1),
      child: Text(
        char,
        style: _digitStyle.copyWith(
          color: accent.withValues(alpha: 0.5),
          fontSize: 20,
        ),
      ),
    );
  }
}

class FloorsTimersBar extends StatelessWidget {
  const FloorsTimersBar({
    super.key,
    required this.floorSec,
    required this.lifeSec,
  });

  final double floorSec;
  final double lifeSec;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FloorsStopwatch(
            label: 'ЭТАЖ',
            seconds: floorSec,
            accent: const Color(0xFF3DDC97),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FloorsStopwatch(
            label: 'ЖИЗНЬ',
            seconds: lifeSec,
            accent: const Color(0xFF7EE0FF),
          ),
        ),
      ],
    );
  }
}
