import 'package:flutter/material.dart';

/// Общий «стеклянный» стиль шитов: тёмный градиент, мягкая рамка.
class GameSheetChrome extends StatelessWidget {
  const GameSheetChrome({
    super.key,
    required this.child,
    this.heightFactor = 0.82,
  });

  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * heightFactor;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF182228), Color(0xFF0E1419), Color(0xFF11181E)],
        ),
        border: Border(
          top: BorderSide(color: Color(0x33FFFFFF)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Карточка внутри шита — лёгкая, без «дашбордности».
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.accent,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final border = accent ?? Colors.white12;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF151C22),
        border: Border.all(color: border.withValues(alpha: 0.45)),
      ),
      child: child,
    );
  }
}
