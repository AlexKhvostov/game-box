import 'package:flutter/material.dart';
import 'game_ui.dart';

const energyNeon = Color(0xFFFFEE73);
const energyCore = Color(0xFFFFFAD2);

/// One shared currency treatment, without a badge around the number.
class EnergyText extends StatelessWidget {
  const EnergyText(
    this.amount, {
    super.key,
    this.size = 22,
    this.prefix = '',
    this.glow = true,
    this.leadingBolt = false,
  });
  final Object amount;
  final double size;
  final String prefix;
  final bool glow;
  final bool leadingBolt;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$prefix$amount ${Localizations.localeOf(context).languageCode == 'ru' ? 'энергии' : 'energy'}',
    child: ExcludeSemantics(
      child: Text(
        leadingBolt ? '⚡ $prefix$amount' : '$prefix$amount ⚡',
        maxLines: 1,
        style: TextStyle(
          color: energyNeon,
          fontSize: size,
          height: 1.15,
          fontWeight: FontWeight.w900,
          shadows: glow
              ? const [Shadow(color: Color(0x66FFE02F), blurRadius: 9)]
              : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ),
  );
}

/// Shared energy core, no percentages or charge limits. The home card alone
/// shows the plus; its entire existing card remains the single action target.
class EnergyBalanceCapsule extends StatelessWidget {
  const EnergyBalanceCapsule({
    super.key,
    required this.amount,
    this.showPlus = false,
    this.amountKey,
    this.plusKey,
  });
  final int amount;
  final bool showPlus;
  final Key? amountKey, plusKey;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${Localizations.localeOf(context).languageCode == 'ru' ? 'Энергия' : 'Energy'}: $amount',
    child: LayoutBuilder(
      builder: (context, bounds) {
        final diameter = (bounds.maxHeight * .86).clamp(12.0, 34.0);
        final endInset = showPlus ? diameter + 4 : bounds.maxHeight * .29;
        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _EnergyCapsulePainter()),
              ),
              Positioned(
                left: endInset,
                right: endInset,
                top: 3,
                bottom: 3,
                child: FittedBox(
                  key: amountKey,
                  fit: BoxFit.scaleDown,
                  child: EnergyText(amount, size: 28, leadingBolt: true),
                ),
              ),
              if (showPlus)
                Positioned(
                  right: 1,
                  top: 0,
                  bottom: 0,
                  width: diameter,
                  child: Center(
                    child: Container(
                      key: const ValueKey('energy-capsule-plus-disc'),
                      width: diameter,
                      height: diameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF7DF6FF),
                          width: 1.1,
                        ),
                        gradient: const RadialGradient(
                          center: Alignment(-.3, -.4),
                          colors: [Color(0xFF14587A), Color(0xFF032238)],
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x5545E5FF), blurRadius: 5),
                        ],
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        key: plusKey,
                        color: GameUi.cyan,
                        size: diameter * .70,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Draw in logical pixels: horizontal growth extends the glass tube, while
/// bevels/end rings retain their height-based physical proportions.
class _EnergyCapsulePainter extends CustomPainter {
  const _EnergyCapsulePainter();
  @override
  void paint(Canvas c, Size s) {
    if (s.width < 24 || s.height < 12) return;
    final rect = Rect.fromLTWH(2, s.height * .07, s.width - 4, s.height * .86);
    final r = RRect.fromRectAndRadius(rect, Radius.circular(s.height / 2));
    c.drawRRect(
      r,
      Paint()
        ..color = const Color(0x7757EFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    c.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E85AD),
            Color(0xFF063958),
            Color(0xFF001A30),
            Color(0xFF0C5A79),
          ],
          stops: [0, .18, .72, 1],
        ).createShader(rect),
    );
    for (final inset in [0.0, 3.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(inset),
          Radius.circular(s.height / 2),
        ),
        Paint()
          ..color = inset == 0
              ? const Color(0xFF80F6FF)
              : const Color(0xFF1E9AC3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = inset == 0 ? 1.3 : .7,
      );
    }
    c.drawLine(
      Offset(s.height * .48, rect.top + 2),
      Offset(s.width - s.height * .48, rect.top + 2),
      Paint()
        ..color = const Color(0xFFD8FFFF)
        ..strokeWidth = .7,
    );
  }

  @override
  bool shouldRepaint(_EnergyCapsulePainter old) => false;
}

/// Local surface for the energy window, never a global theme override.
class EnergyNeonSurface extends StatelessWidget {
  const EnergyNeonSurface({
    super.key,
    required this.child,
    this.enabled = true,
    this.radius = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  });
  final Widget child;
  final bool enabled;
  final double radius;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => GameUi.neonSurface(
    enabled: enabled,
    cornerRadius: radius,
    padding: padding,
    child: child,
  );
}

class EnergyBatteryTile extends StatelessWidget {
  const EnergyBatteryTile({
    super.key,
    required this.percent,
    required this.amount,
    required this.capacity,
    this.active = true,
    this.onConnect,
    this.compact = false,
    this.paused = false,
  });
  final int percent, amount, capacity;
  final bool active, compact, paused;
  final VoidCallback? onConnect;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final full = active && percent >= 100;
    return Semantics(
      label: active
          ? '$percent%, $amount / $capacity'
          : (ru ? 'Подключить батарейку' : 'Connect battery'),
      button: !active,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onConnect,
                borderRadius: BorderRadius.circular(compact ? 12 : 19),
                child: LayoutBuilder(
                  builder: (context, bounds) => RepaintBoundary(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _AccumulatorPainter(
                              percent: percent,
                              active: active,
                              compact: compact,
                            ),
                          ),
                        ),
                        if (active)
                          Positioned(
                            left: bounds.maxWidth * (compact ? .12 : .215),
                            right: bounds.maxWidth * (compact ? .12 : .215),
                            top: bounds.maxHeight * (compact ? .50 : .665),
                            bottom: bounds.maxHeight * (compact ? .10 : .105),
                            child: compact
                                ? _CompactBatteryReadout(
                                    percent: percent,
                                    amount: amount,
                                    capacity: capacity,
                                  )
                                : Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: compact ? 1 : 3,
                                      vertical: 1,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '$percent%',
                                            style: TextStyle(
                                              color: GameUi.text,
                                              fontWeight: FontWeight.w900,
                                              fontSize: compact ? 15 : 22,
                                              height: 1.02,
                                              shadows: const [
                                                Shadow(
                                                  color: Color(0x445AF4FF),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '$amount',
                                                style: TextStyle(
                                                  color: energyNeon,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: compact ? 9 : 11,
                                                  shadows: const [
                                                    Shadow(
                                                      color: Color(0x66FFE02F),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                ' / $capacity',
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xFFD3D79B,
                                                  ),
                                                  fontSize: compact ? 9 : 11,
                                                ),
                                              ),
                                              Icon(
                                                Icons.bolt_rounded,
                                                color: energyNeon,
                                                size: compact ? 10 : 13,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        if (!active)
                          Positioned(
                            left: bounds.maxWidth * .20,
                            right: bounds.maxWidth * .20,
                            top: bounds.maxHeight * .67,
                            bottom: bounds.maxHeight * .155,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                ru ? 'Подключить' : 'Connect',
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Color(0xFFFFD16B),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x554DAED1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (full && !MediaQuery.disableAnimationsOf(context))
                          Positioned(
                            left: bounds.maxWidth * .07,
                            right: bounds.maxWidth * .07,
                            top: bounds.maxHeight * .34,
                            bottom: bounds.maxHeight * .1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: const _FullChargePulse(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 16,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                active
                    ? (full
                          ? (ru ? 'Заряжен' : 'Fully charged')
                          : paused
                          ? (ru ? 'Проверяем' : 'Verifying')
                          : (ru ? 'Заряжается' : 'Charging'))
                    : (ru ? 'Не подключён' : 'Not connected'),
                style: TextStyle(
                  color: const Color(0xFF89EBFF),
                  fontSize: compact ? 8 : 10,
                  fontWeight: FontWeight.w700,
                  shadows: const [
                    Shadow(color: Color(0x4456E8FF), blurRadius: 5),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Each compact line fits independently: the amount must not shrink the percent,
/// and neither line shares the small full-size battery display's height budget.
class _CompactBatteryReadout extends StatelessWidget {
  const _CompactBatteryReadout({
    required this.percent,
    required this.amount,
    required this.capacity,
  });
  final int percent, amount, capacity;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        flex: 56,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$percent%',
            key: const ValueKey('energy-battery-compact-percent'),
            maxLines: 1,
            style: const TextStyle(
              color: GameUi.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              height: 1.02,
              shadows: [Shadow(color: Color(0x445AF4FF), blurRadius: 4)],
            ),
          ),
        ),
      ),
      Expanded(
        flex: 44,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$amount',
                      style: const TextStyle(
                        color: energyNeon,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Color(0x66FFE02F), blurRadius: 3),
                        ],
                      ),
                    ),
                    TextSpan(
                      text: '/$capacity',
                      style: const TextStyle(color: Color(0xFFD3D79B)),
                    ),
                  ],
                ),
                key: const ValueKey('energy-battery-compact-amount'),
                maxLines: 1,
                style: const TextStyle(fontSize: 10, height: 1),
              ),
              const Icon(Icons.bolt_rounded, color: energyNeon, size: 6),
            ],
          ),
        ),
      ),
    ],
  );
}

/// The approved illustration rebuilt as live vector layers, not a raster face.
/// All dimensions share one 200-unit shell for both connected and inactive cells.
class _AccumulatorPainter extends CustomPainter {
  const _AccumulatorPainter({
    required this.percent,
    required this.active,
    required this.compact,
  });
  final int percent;
  final bool active, compact;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 200);
    final shell = RRect.fromRectAndRadius(
      const Rect.fromLTRB(4, 37, 196, 192),
      const Radius.circular(24),
    );
    final shellPath = Path()..addRRect(shell);
    canvas.drawRRect(
      shell.shift(const Offset(4, 4)),
      Paint()..color = const Color(0x99021020),
    );
    canvas.drawPath(
      shellPath,
      Paint()
        ..color = const Color(0x8853E8FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(
      shell,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF9BEFFF),
            Color(0xFF087CA6),
            Color(0xFF062741),
            Color(0xFF021B30),
            Color(0xFF21D3E5),
          ],
          stops: [0, .13, .36, .79, 1],
        ).createShader(shell.outerRect),
    );
    canvas.drawRRect(
      shell,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFBAFFFF),
            Color(0xFF04E6FF),
            Color(0xFF007299),
            Color(0xFF37FBFF),
          ],
        ).createShader(shell.outerRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    final bevel = RRect.fromRectAndRadius(
      const Rect.fromLTRB(8, 42, 192, 188),
      const Radius.circular(21),
    );
    canvas.drawRRect(
      bevel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF116A95),
            Color(0xFF082E4C),
            Color(0xFF001A2E),
            Color(0xFF075B75),
          ],
          stops: [0, .26, .76, 1],
        ).createShader(bevel.outerRect),
    );
    canvas.drawRRect(
      bevel,
      Paint()
        ..color = const Color(0xAA67D8ED)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    // Moulded lid and reflective shoulders.
    final lid = RRect.fromRectAndRadius(
      const Rect.fromLTRB(15, 38, 185, 68),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      lid,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0AA8D1), Color(0xFF075585), Color(0xFF031F35)],
        ).createShader(lid.outerRect),
    );
    canvas.drawLine(
      const Offset(23, 41),
      const Offset(177, 41),
      Paint()
        ..color = const Color(0x9900E7FF)
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(35, 56, 164, 70),
        const Radius.circular(7),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF003050), Color(0xFF06243E), Color(0xFF001F37)],
        ).createShader(const Rect.fromLTRB(35, 56, 164, 70)),
    );
    _shoulder(canvas, false);
    _shoulder(canvas, true);
    // Open carry handle, with a dark interior and a thin cyan bevel.
    final handle = Path()
      ..moveTo(70, 40)
      ..lineTo(70, 24)
      ..quadraticBezierTo(70, 10, 84, 10)
      ..lineTo(116, 10)
      ..quadraticBezierTo(130, 10, 130, 24)
      ..lineTo(130, 40);
    canvas.drawPath(
      handle,
      Paint()
        ..color = const Color(0xFF001324)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
    canvas.drawPath(
      handle,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0FE4FF), Color(0xFF135B87), Color(0xFF032A47)],
        ).createShader(const Rect.fromLTRB(64, 8, 136, 44))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    final innerHandle = Path()
      ..moveTo(70, 38)
      ..lineTo(70, 24)
      ..quadraticBezierTo(70, 10, 84, 10)
      ..lineTo(116, 10)
      ..quadraticBezierTo(130, 10, 130, 24)
      ..lineTo(130, 38);
    canvas.drawPath(
      innerHandle,
      Paint()
        ..color = const Color(0xFF7AF5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9,
    );
    // Negative/positive metal posts are deliberately distinct, on the same shell.
    _terminal(canvas, 40, false);
    _terminal(canvas, 160, true);
    final glass = RRect.fromRectAndRadius(
      const Rect.fromLTRB(13, 70, 187, 175),
      const Radius.circular(17),
    );
    canvas.drawRRect(
      glass.inflate(3),
      Paint()..color = const Color(0xFF001B2B),
    );
    canvas.drawRRect(
      glass.inflate(1),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF93F5FA),
            Color(0xFF002D41),
            Color(0xFF16CCDF),
            Color(0xFF001629),
          ],
        ).createShader(glass.outerRect),
    );
    canvas.drawRRect(
      glass,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3D55), Color(0xFF02263C), Color(0xFF00182C)],
        ).createShader(glass.outerRect),
    );
    canvas.save();
    canvas.clipRRect(glass);
    if (active && percent > 0) {
      final level = 175 - 105 * (percent.clamp(0, 100) / 100);
      final fill = Rect.fromLTRB(13, level, 187, 176);
      canvas.drawRect(
        fill,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF99FFDD),
              Color(0xFF0EF9C7),
              Color(0xFF00DDB2),
              Color(0xFF009D9B),
            ],
            stops: [0, .2, .68, 1],
          ).createShader(fill),
      );
      canvas.drawRect(
        Rect.fromLTRB(14, level, 185, 176),
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0xBB98FFF4),
              Color(0x001EFADE),
              Color(0x0030DDBA),
              Color(0xAA76FFF3),
            ],
            stops: [0, .2, .8, 1],
          ).createShader(glass.outerRect),
      );
      final surface = Rect.fromLTRB(13, level - 3, 187, level + 6);
      canvas.drawOval(surface, Paint()..color = const Color(0x779CFFF5));
      canvas.drawOval(
        surface,
        Paint()
          ..color = const Color(0xAAE4FFF5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
      if (!compact) {
        for (var i = 0; i < 9; i++) {
          final x = 24.0 + (i * 37) % 151;
          final y = 83.0 + (i * 23) % 83;
          if (y > level + 9) {
            canvas.drawCircle(
              Offset(x, y),
              i % 3 == 0 ? 2.0 : 1.2,
              Paint()..color = const Color(0x663AFFF0),
            );
            canvas.drawCircle(
              Offset(x - .6, y - .7),
              .6,
              Paint()..color = const Color(0x99D2FFF2),
            );
          }
        }
      }
    }

    // Broad vertical glass reflection and curved dark edge, like the concept.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(15, 71, 34, 176),
        const Radius.circular(10),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0x00D8FFFF),
            Color(0xAADDFFFF),
            Color(0x22D8FFFF),
            Color(0x00D8FFFF),
          ],
          stops: [0, .25, .7, 1],
        ).createShader(const Rect.fromLTRB(15, 70, 34, 176)),
    );
    final right = Path()
      ..moveTo(171, 71)
      ..lineTo(180, 71)
      ..quadraticBezierTo(187, 75, 187, 89)
      ..lineTo(187, 160)
      ..quadraticBezierTo(186, 174, 174, 175)
      ..lineTo(168, 175)
      ..quadraticBezierTo(177, 164, 177, 148)
      ..lineTo(177, 91)
      ..quadraticBezierTo(178, 78, 171, 71)
      ..close();
    canvas.drawPath(
      right,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x005BEBFF), Color(0x883BAECC), Color(0x11002030)],
        ).createShader(const Rect.fromLTRB(168, 70, 187, 176)),
    );
    canvas.restore();
    canvas.drawRRect(
      glass,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFCCFFFF),
            Color(0xFF12DBC8),
            Color(0xFF02617A),
            Color(0xFF65F8FF),
          ],
        ).createShader(glass.outerRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Compact cells reserve a genuinely larger readout; keep their bolt above it.
    canvas.save();
    if (compact && active) {
      canvas.translate(54, 34);
      canvas.scale(.48);
    }
    // Sharply defined charged bolt with a restrained halo.
    final bolt = Path()
      ..moveTo(110, 77)
      ..lineTo(87, 111)
      ..lineTo(104, 111)
      ..lineTo(96, 132)
      ..lineTo(121, 97)
      ..lineTo(105, 97)
      ..lineTo(112, 78)
      ..close();
    if (active) {
      canvas.drawPath(
        bolt,
        Paint()
          ..color = const Color(0xCCF5E900)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawPath(
      bolt,
      Paint()
        ..shader =
            (active
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFFFD6),
                          Color(0xFFFFFF39),
                          Color(0xFFFFDE08),
                        ],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF5B9AB8), Color(0xFF285572)],
                      ))
                .createShader(const Rect.fromLTRB(86, 77, 122, 132)),
    );
    canvas.drawPath(
      bolt,
      Paint()
        ..color = active ? const Color(0xFFFFFF9A) : const Color(0xFF5792AF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
    // Separate recessed data display; same empty-shell button in the inactive unit.
    final display = RRect.fromRectAndRadius(
      active
          ? (compact
                ? const Rect.fromLTRB(22, 98, 178, 182)
                : const Rect.fromLTRB(43, 133, 157, 178))
          : const Rect.fromLTRB(39, 135, 161, 169),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      display.shift(const Offset(1, 2)),
      Paint()..color = const Color(0x66001120),
    );
    canvas.drawRRect(
      display,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: compact && active
              ? const [Color(0xC814516A), Color(0xC0001F30), Color(0xD0001729)]
              : const [Color(0xFF14516A), Color(0xFF001F30), Color(0xFF001729)],
        ).createShader(display.outerRect),
    );
    canvas.drawRRect(
      display,
      Paint()
        ..color = active ? const Color(0xAA42DACE) : const Color(0xAA5795AE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // Bottom charging socket and a connected glowing cable.
    if (active) {
      if (!compact) {
        final cable = Path()
          ..moveTo(100, 195)
          ..cubicTo(99, 214, 51, 212, -10, 196);
        canvas.drawPath(
          cable,
          Paint()
            ..color = const Color(0xFF002F42)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawPath(
          cable,
          Paint()
            ..color = const Color(0xAA00FCE4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawPath(
          cable,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFF0B7F9E), Color(0xFF0EFFE6), Color(0xFFBAFFF5)],
            ).createShader(const Rect.fromLTRB(0, 193, 103, 215))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.1
            ..strokeCap = StrokeCap.round,
        );
      }
      final socket = RRect.fromRectAndRadius(
        const Rect.fromLTRB(88, 180, 112, 198),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        socket,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFADFFFC), Color(0xFF0BDBC9), Color(0xFF00758F)],
          ).createShader(socket.outerRect),
      );
      canvas.drawRRect(
        socket,
        Paint()
          ..color = const Color(0xFF00F6F4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(92, 182, 108, 191),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xAA99FFF9),
      );
    }
    canvas.restore();
  }

  void _terminal(Canvas canvas, double x, bool positive) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, 38), width: 34, height: 9),
      Paint()..color = const Color(0xFF001627),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, 36), width: 32, height: 8),
      Paint()..color = const Color(0xFF1386A9),
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(x - 13, 20, x + 13, 37),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF44CDF2),
            Color(0xFF0F527E),
            Color(0xFF082B47),
            Color(0xFF0C638A),
          ],
          stops: [0, .25, .8, 1],
        ).createShader(body.outerRect),
    );
    canvas.drawLine(
      Offset(x - 11, 22),
      Offset(x - 11, 34),
      Paint()
        ..color = const Color(0xFFADF9FF)
        ..strokeWidth = 1.2,
    );
    final cap = Rect.fromLTRB(x - 11, 15, x + 11, 23);
    canvas.drawOval(
      cap.shift(const Offset(0, 1)),
      Paint()..color = const Color(0xFF001628),
    );
    canvas.drawOval(
      cap,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: positive
              ? const [Color(0xFFFFEFDB), Color(0xFFE88F7C), Color(0xFF8F4C48)]
              : const [Color(0xFFECFFFF), Color(0xFF4DE8FF), Color(0xFF006B9E)],
        ).createShader(cap),
    );
    canvas.drawOval(
      cap,
      Paint()
        ..color = const Color(0xCCCDFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    final mark = Paint()
      ..color = positive ? const Color(0xFFFFD76B) : const Color(0xFF7CF1FF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x - 4, 29), Offset(x + 4, 29), mark);
    if (positive) canvas.drawLine(Offset(x, 25), Offset(x, 33), mark);
  }

  void _shoulder(Canvas canvas, bool right) {
    canvas.save();
    if (right) {
      canvas.translate(200, 0);
      canvas.scale(-1, 1);
    }
    final path = Path()
      ..moveTo(8, 75)
      ..lineTo(8, 60)
      ..quadraticBezierTo(10, 43, 24, 43)
      ..lineTo(32, 48)
      ..quadraticBezierTo(20, 51, 20, 67)
      ..lineTo(20, 85)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF37C8F3),
            Color(0xFFCBFFFF),
            Color(0xFF087BA8),
            Color(0xFF02233E),
          ],
          stops: [0, .35, .6, 1],
        ).createShader(const Rect.fromLTRB(8, 43, 32, 85)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AccumulatorPainter oldDelegate) =>
      oldDelegate.percent != percent ||
      oldDelegate.active != active ||
      oldDelegate.compact != compact;
}

/// This animation owns a tiny isolated layer, never the whole game scene.
class _FullChargePulse extends StatefulWidget {
  const _FullChargePulse();
  @override
  State<_FullChargePulse> createState() => _FullChargePulseState();
}

class _FullChargePulseState extends State<_FullChargePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: GameUi.mint.withValues(alpha: .04 + .12 * _pulse.value),
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ),
    ),
  );
}
