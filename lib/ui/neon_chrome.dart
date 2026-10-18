import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _cyan = Color(0xFF54E9FF);

class NeonSheetHeader extends StatelessWidget {
  const NeonSheetHeader({
    super.key,
    required this.title,
    this.closeEnabled = true,
    this.titleSize = 24,
    this.showDivider = true,
  });
  final String title;
  final bool closeEnabled;
  final double titleSize;
  final bool showDivider;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                height: 1.15,
                shadows: const [
                  Shadow(color: Color(0x66198AFF), blurRadius: 7),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              padding: EdgeInsets.zero,
              onPressed: closeEnabled
                  ? () => Navigator.of(context).pop()
                  : null,
              icon: const Icon(Icons.close_rounded, color: _cyan, size: 28),
            ),
          ),
        ],
      ),
      if (showDivider)
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 8),
          color: _cyan.withValues(alpha: .5),
        ),
    ],
  );
}

class NeonGlass extends StatelessWidget {
  const NeonGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
    this.selected = false,
    this.accountStyle = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool selected;
  final bool accountStyle;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: (selected ? const Color(0xFF34FFD2) : _cyan).withValues(
            alpha: .2,
          ),
          blurRadius: 13,
          spreadRadius: 1,
        ),
        const BoxShadow(
          color: Color(0xDD000B19),
          blurRadius: 8,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: CustomPaint(
      painter: accountStyle
          ? _AccountGlassPainter(radius)
          : _GlassPainter(radius: radius, selected: selected),
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Scoped to account windows; energy's established material is unchanged.
class AccountGlass extends StatelessWidget {
  const AccountGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 20,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final button = FilledButton.styleFrom(
      foregroundColor: Colors.white,
      disabledForegroundColor: const Color(0xFF72BED0),
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ).copyWith(backgroundBuilder: accountButtonLayer);
    return NeonGlass(
      accountStyle: true,
      radius: radius,
      padding: padding,
      child: Theme(
        data: base.copyWith(
          filledButtonTheme: FilledButtonThemeData(style: button),
          outlinedButtonTheme: OutlinedButtonThemeData(style: button),
          textButtonTheme: TextButtonThemeData(
            style:
                TextButton.styleFrom(
                  foregroundColor: const Color(0xFF91D7F2),
                  minimumSize: const Size(48, 48),
                  textStyle: const TextStyle(fontFamily: 'Roboto'),
                ).copyWith(
                  backgroundBuilder: (context, states, child) =>
                      child ?? const SizedBox.shrink(),
                ),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.all(const Color(0xFFEFFFFF)),
            trackOutlineColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFFA8FFF2)
                  : const Color(0xFF678DA7),
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFF00BAAA)
                  : const Color(0xFF233F58),
            ),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Color(0xFFE4F2FF)),
          child: child,
        ),
      ),
    );
  }
}

Widget accountButtonLayer(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) {
  final disabled = states.contains(WidgetState.disabled);
  return CustomPaint(
    foregroundPainter: _AccountButtonEdge(disabled),
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: disabled ? const Color(0xFF347F97) : const Color(0xFF94F8FF),
          width: states.contains(WidgetState.focused) ? 2 : 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: disabled
              ? const [Color(0xFF07516C), Color(0xFF022C47)]
              : const [Color(0xFF0987B0), Color(0xFF00376B), Color(0xFF0079A1)],
        ),
        boxShadow: disabled
            ? null
            : const [BoxShadow(color: Color(0x5000BFFF), blurRadius: 5)],
      ),
      child: child,
    ),
  );
}

class _AccountButtonEdge extends CustomPainter {
  const _AccountButtonEdge(this.disabled);
  final bool disabled;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..color = (disabled ? const Color(0xFF347F97) : const Color(0xFF3DEAFF))
            .withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    if (!disabled) {
      final shine = Rect.fromLTWH(size.width * .18, 2.5, size.width * .64, 1);
      canvas.drawRect(
        shine,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x008BF1FF), Color(0xFFD9FFFF), Color(0x008BF1FF)],
          ).createShader(shine),
      );
    }
  }

  @override
  bool shouldRepaint(_AccountButtonEdge old) => old.disabled != disabled;
}

class AccountArt extends StatelessWidget {
  const AccountArt(this.name, {super.key, this.size = 24});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => name.endsWith('.png')
      ? Image.asset(
          'assets/branding/account/$name',
          width: size,
          height: size,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        )
      : SvgPicture.asset(
          'assets/branding/account/$name.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        );
}

class GoogleBrandMark extends StatelessWidget {
  const GoogleBrandMark({super.key, this.size = 24});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ShaderMask(
      shaderCallback: (rect) => const SweepGradient(
        colors: [
          Color(0xFF4285F4),
          Color(0xFF34A853),
          Color(0xFFFBBC05),
          Color(0xFFEA4335),
          Color(0xFF4285F4),
        ],
        stops: [0, .27, .5, .75, 1],
      ).createShader(rect),
      child: Text(
        'G',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: 1,
          color: Colors.white,
        ),
      ),
    ),
  );
}

/// Existing artistic fallback. No remote/user avatar is overwritten.
class AccountPortrait extends StatelessWidget {
  const AccountPortrait({super.key, this.size = 64});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF82F6FF), width: 1.4),
      gradient: const RadialGradient(
        center: Alignment(-.2, -.3),
        colors: [Color(0xFF0A668C), Color(0xFF02182F)],
      ),
      boxShadow: const [BoxShadow(color: Color(0x7000BBFF), blurRadius: 8)],
    ),
    child: ClipOval(
      child: Image.asset(
        'assets/branding/ui/hud-player-portrait-v1.png',
        fit: BoxFit.contain,
      ),
    ),
  );
}

class _AccountGlassPainter extends CustomPainter {
  const _AccountGlassPainter(this.radius);
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF063957), Color(0xFF00172C), Color(0xFF012039)],
          stops: [0, .64, 1],
        ).createShader(rect),
    );
    for (final (inset, color, width) in const [
      (0.7, Color(0xFF5DEAFF), 1.2),
      (3.3, Color(0xFF13D7FF), 1.5),
      (6.0, Color(0xFFA0FBFF), 1.1),
      (8.0, Color(0x7000D7FF), .6),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(inset),
          Radius.circular(math.max(1, radius - inset)),
        ),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }
    final shine = Path()
      ..moveTo(size.width * .24, 9)
      ..lineTo(size.width * .38, 9)
      ..lineTo(9, size.height * .38)
      ..lineTo(9, size.height * .26)
      ..close();
    canvas.drawPath(shine, Paint()..color = const Color(0x075FDDFF));
    for (final x in [.11, .88]) {
      final line = Rect.fromLTWH(size.width * x - 14, 4, 28, 1.5);
      canvas.drawRect(
        line,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x0010DCFF), Color(0xFFDDFFFF), Color(0x0010DCFF)],
          ).createShader(line),
      );
    }
  }

  @override
  bool shouldRepaint(_AccountGlassPainter old) => old.radius != radius;
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter({required this.radius, this.selected = false});
  final double radius;
  final bool selected;
  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    final r = RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(radius));
    c.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF10516F),
            Color(0xFF00223A),
            Color(0xFF001426),
            Color(0xFF053957),
          ],
          stops: [0, .16, .72, 1],
        ).createShader(rect),
    );
    for (final inset in [1.0, 6.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(inset),
          Radius.circular(math.max(1, radius - inset)),
        ),
        Paint()
          ..color = selected ? const Color(0xFF57FFE0) : _cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = inset == 1 ? 1.4 : .7,
      );
    }
    c.drawLine(
      Offset(radius + 5, 5),
      Offset(s.width - radius - 5, 5),
      Paint()
        ..color = const Color(0xFFD6FFFF)
        ..strokeWidth = .8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    final random = math.Random(17);
    for (var i = 0; i < 26; i++) {
      final p = Offset(
        random.nextDouble() * s.width,
        random.nextDouble() * s.height,
      );
      c.drawCircle(p, .7, Paint()..color = _cyan.withValues(alpha: .12));
    }
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.radius != radius || old.selected != selected;
}
