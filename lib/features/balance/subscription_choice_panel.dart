import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../ui/energy_widgets.dart';

const _mint = Color(0xFF78F5E0);
const _muted = Color(0xFFA1E8F4);

class SubscriptionTileData {
  const SubscriptionTileData({
    required this.id,
    required this.multiplier,
    required this.reward,
    required this.baseEnergy,
    required this.daily,
    required this.price,
    required this.periodDays,
    this.discount,
    this.comparisonPrice,
    this.active = false,
  });
  final String id, price;
  final int multiplier, reward, baseEnergy, daily, periodDays;
  final int? discount;
  final String? comparisonPrice;
  final bool active;
}

/// E02 content only. The existing energy route owns closing, billing and errors.
class SubscriptionChoicePanel extends StatelessWidget {
  const SubscriptionChoicePanel({
    super.key,
    required this.offers,
    required this.selected,
    required this.onSelect,
    required this.onBuy,
    required this.onRestore,
    required this.onManage,
    required this.showAds,
    required this.periodHours,
    required this.ru,
    this.busy = false,
  });
  final List<SubscriptionTileData> offers;
  final SubscriptionTileData? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback? onBuy, onRestore;
  final VoidCallback onManage;
  final bool showAds, ru, busy;
  final String periodHours;
  String tr(String a, String b) => ru ? a : b;
  Text _text(
    String value, {
    double size = 14,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w600,
    TextAlign align = TextAlign.center,
  }) => Text(
    value,
    textAlign: align,
    style: TextStyle(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: 1.2,
    ),
  );

  Widget _price(SubscriptionTileData data, {double size = 16}) => Text.rich(
    TextSpan(
      children: [
        if (data.comparisonPrice != null)
          TextSpan(
            text: '${data.comparisonPrice}  ',
            style: TextStyle(
              color: const Color(0xFFA4C1C9),
              fontSize: size * .8,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        TextSpan(
          text: '${data.price} / ${data.periodDays} ${tr('дней', 'days')}',
        ),
      ],
    ),
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Colors.white,
      fontSize: size,
      height: 1.25,
      fontWeight: FontWeight.w800,
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final large = MediaQuery.textScalerOf(context).scale(14) > 18;
      final narrow = bounds.maxWidth < 310;
      final picked = selected;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _text(
            tr('Выберите размер бонуса', 'Choose your bonus'),
            color: _muted,
            size: 15,
          ),
          const SizedBox(height: 16),
          if (offers.isEmpty)
            _text(
              tr('Подписки пока недоступны', 'Subscriptions are unavailable'),
            ),
          if (offers.isNotEmpty)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < offers.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _tile(offers[i], narrow, large)),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          _text(
            tr(
              'Бонус каждые $periodHours часов',
              'Bonus every $periodHours hours',
            ),
            color: _muted,
            size: 13,
          ),
          if (showAds)
            Padding(
              key: const ValueKey('subscription-ad-benefit'),
              padding: const EdgeInsets.symmetric(vertical: 17),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SubscriptionAdShield(size: 42),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _text(
                          tr('Блокировка рекламы', 'Ad blocking'),
                          size: 15,
                          weight: FontWeight.w800,
                          align: TextAlign.left,
                        ),
                        const SizedBox(height: 4),
                        _text(
                          tr(
                            'Включено в оба варианта',
                            'Included in both options',
                          ),
                          size: 12,
                          color: _muted,
                          align: TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 16),
          Semantics(
            button: true,
            enabled: onBuy != null,
            label: tr(
              'Подписка с бонусом ×${picked?.multiplier ?? 5}',
              'Subscription bonus ×${picked?.multiplier ?? 5}',
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('simple-subscribe'),
                onTap: onBuy,
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 66),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: const Color(0xFF8CF4FF)),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0784CC), Color(0xFF034F98)],
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x55029EFA), blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SubscriptionEnergyMedallion(
                        size: 39,
                        label: '×${picked?.multiplier ?? 5}',
                      ),
                      if (showAds) ...[
                        const SizedBox(width: 6),
                        const SubscriptionAdShield(
                          key: ValueKey('subscription-cta-shield'),
                          size: 27,
                        ),
                      ],
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (large)
                              _text(
                                picked?.active == true
                                    ? tr('Подключено', 'Active')
                                    : tr('Подключить подписку', 'Subscribe'),
                                size: narrow ? 16 : 18,
                                weight: FontWeight.w900,
                              ),
                            if (!large)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _text(
                                  picked?.active == true
                                      ? tr('Подключено', 'Active')
                                      : tr('Подключить подписку', 'Subscribe'),
                                  size: narrow ? 16 : 18,
                                  weight: FontWeight.w900,
                                ),
                              ),
                            const SizedBox(height: 3),
                            if (picked != null) _price(picked, size: 13),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _text(
            tr(
              '${picked?.periodDays ?? 7} дней · автопродление\nУправление и отмена в Google Play',
              '${picked?.periodDays ?? 7} days · auto-renews\nManage and cancel in Google Play',
            ),
            size: 10,
            color: const Color(0xFF9BC6DB),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onRestore,
                  child: _text(
                    tr('Восстановить покупки', 'Restore purchases'),
                    size: 11,
                    color: _muted,
                  ),
                ),
              ),
              Flexible(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onManage,
                  child: _text(
                    tr('Управлять', 'Manage'),
                    size: 11,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  Widget _tile(SubscriptionTileData data, bool narrow, bool large) {
    final chosen = data.id == selected?.id;
    return Semantics(
      selected: chosen,
      button: true,
      label: tr(
        'Бонус ${data.baseEnergy} ×${data.multiplier} = ${data.reward} энергии',
        'Bonus ${data.baseEnergy} ×${data.multiplier} = ${data.reward} energy',
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('simple-tier-${data.multiplier}'),
          onTap: busy ? null : () => onSelect(data.id),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: chosen
                    ? const Color(0xFF3EAAA8)
                    : const Color(0xFF1C6383),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: chosen
                    ? const [
                        Color(0xFF0D525B),
                        Color(0xFF073643),
                        Color(0xFF09515A),
                      ]
                    : const [Color(0xFF073454), Color(0xFF042037)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 20,
                  child: Row(
                    children: [
                      if (data.discount != null)
                        Flexible(
                          child: Container(
                            key: ValueKey(
                              'subscription-discount-${data.multiplier}',
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: energyNeon,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _text(
                                tr(
                                  'Скидка ${data.discount}%',
                                  'Save ${data.discount}%',
                                ),
                                size: 10,
                                color: const Color(0xFF352602),
                                weight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Icon(
                        chosen
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: chosen ? _mint : const Color(0xFFA5B8EF),
                        size: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 78,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SubscriptionEnergyMedallion(
                          size: 60,
                          baseEnergy: data.baseEnergy,
                        ),
                        const SizedBox(width: 9),
                        SubscriptionEnergyMedallion(
                          size: 48,
                          label: '×${data.multiplier}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _text(
                  tr('${data.reward} энергии', '${data.reward} energy'),
                  size: narrow ? 14 : 17,
                  weight: FontWeight.w900,
                ),
                const SizedBox(height: 3),
                _text(
                  tr('за один бонус', 'per bonus'),
                  size: 11,
                  color: _muted,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x44075083),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Column(
                    children: [
                      _text(
                        tr(
                          'До ${data.daily} энергии',
                          'Up to ${data.daily} energy',
                        ),
                        size: narrow ? 12 : 14,
                        color: energyCore,
                        weight: FontWeight.w800,
                      ),
                      const SizedBox(height: 3),
                      _text(tr('в сутки', 'per day'), size: 11, color: _muted),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _price(data, size: narrow ? 13 : 16),
                if (data.active)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _text(
                      tr('Подключено', 'Active'),
                      size: 10,
                      color: _mint,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SubscriptionAdShield extends StatelessWidget {
  const SubscriptionAdShield({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size,
      height: size * 1.1,
      child: CustomPaint(painter: _ShieldPainter()),
    ),
  );
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 64, s.height / 70);
    final p = Paint()
      ..color = _mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
      Path()
        ..moveTo(32, 4)
        ..lineTo(57, 14)
        ..lineTo(57, 34)
        ..quadraticBezierTo(56, 53, 32, 66)
        ..quadraticBezierTo(7, 53, 7, 34)
        ..lineTo(7, 14)
        ..close(),
      p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 22, 29, 22),
        const Radius.circular(3),
      ),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(28, 28)
        ..lineTo(38, 33)
        ..lineTo(28, 38)
        ..close(),
      p,
    );
    c.drawLine(const Offset(14, 13), const Offset(52, 56), p);
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => false;
}

class SubscriptionEnergyMedallion extends StatefulWidget {
  const SubscriptionEnergyMedallion({
    super.key,
    required this.size,
    this.label,
    this.baseEnergy,
  });
  final double size;
  final String? label;
  final int? baseEnergy;
  @override
  State<SubscriptionEnergyMedallion> createState() => _MedallionState();
}

class _MedallionState extends State<SubscriptionEnergyMedallion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _light = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) &&
        _light.status == AnimationStatus.dismissed) {
      _light.forward();
    }
  }

  @override
  void dispose() {
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseEnergy;
    final textStyle = TextStyle(
      fontSize: widget.size * .58,
      height: 1,
      fontWeight: FontWeight.w900,
      color: energyCore,
      shadows: const [Shadow(color: Color(0xAAFFD023), blurRadius: 5)],
    );
    Widget? content;
    if (base != null) {
      content = Center(
        child: SizedBox(
          width: widget.size * .72,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$base',
                  textScaler: TextScaler.noScaling,
                  style: textStyle.copyWith(
                    fontSize: widget.size * .4,
                    shadows: const [
                      Shadow(color: Color(0xFF503300), blurRadius: 3),
                    ],
                  ),
                ),
                Icon(
                  Icons.bolt_rounded,
                  size: widget.size * .26,
                  color: energyCore,
                ),
              ],
            ),
          ),
        ),
      );
    } else if (widget.label != null) {
      content = Center(
        child: Text(
          widget.label!,
          textScaler: TextScaler.noScaling,
          style: textStyle,
        ),
      );
    }
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _MedallionPainter(
              _light,
              widget.label == null,
              drawBolt: base == null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _MedallionPainter extends CustomPainter {
  _MedallionPainter(this.light, this.bolt, {this.drawBolt = true})
    : super(repaint: light);
  final Animation<double> light;
  final bool bolt, drawBolt;
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero), r = s.shortestSide * .42;
    c.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0x99FFB800)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    c.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.4),
          colors: bolt
              ? const [
                  Color(0xFFFFF0A2),
                  Color(0xFFBA7A08),
                  Color(0xFF654009),
                  Color(0xFFFFDA36),
                ]
              : const [
                  Color(0xFFB98521),
                  Color(0xFF483007),
                  Color(0xFF211A04),
                  Color(0xFFD39B20),
                ],
          stops: const [0, .35, .7, 1],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    final ring = Paint()
      ..color = energyCore
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    c.drawCircle(center, r, ring);
    c.drawCircle(
      center,
      r + 3,
      ring
        ..color = const Color(0xFFFFD43E)
        ..strokeWidth = 1,
    );
    for (var i = 0; i < 18; i++) {
      final a = i * math.pi * 2 / 18 + .13;
      final d = r + 6 + (i % 3) * 1.2;
      final point = center + Offset(math.cos(a), math.sin(a)) * d;
      final glow = Paint()
        ..color = Color.lerp(
          const Color(0xFFFFBD16),
          energyCore,
          .5 + .25 * math.sin(light.value * math.pi * 3 + i),
        )!;
      c.drawCircle(point, i % 3 == 0 ? 1.25 : .7, glow);
      c.drawCircle(
        point,
        2,
        Paint()
          ..color = const Color(0x77FFD329)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    if (bolt && drawBolt) {
      final path = Path()
        ..moveTo(center.dx + r * .16, center.dy - r * .7)
        ..lineTo(center.dx - r * .45, center.dy + r * .1)
        ..lineTo(center.dx, center.dy + r * .1)
        ..lineTo(center.dx - r * .12, center.dy + r * .7)
        ..lineTo(center.dx + r * .48, center.dy - r * .12)
        ..lineTo(center.dx + r * .04, center.dy - r * .12)
        ..close();
      c.drawPath(
        path,
        Paint()
          ..color = energyCore
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      c.drawPath(path, Paint()..color = energyCore);
    }
  }

  @override
  bool shouldRepaint(_MedallionPainter old) =>
      old.bolt != bolt || old.drawBolt != drawBolt || old.light != light;
}
