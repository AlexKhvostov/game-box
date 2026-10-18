import 'package:flutter/material.dart';
import 'crystal_cube_icon.dart';
import 'game_ui.dart';

/// Crystal expenditure, consistently at the upper right of an offer.
/// Reward quantities and cash prices use their own presentation.
class CrystalCostBadge extends StatelessWidget {
  const CrystalCostBadge({
    super.key,
    required this.amount,
    this.available = true,
  });
  final int amount;
  final bool available;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Semantics(
      label: ru ? 'Стоимость: $amount кристаллов' : 'Cost: $amount crystals',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: available ? const Color(0xFF052D47) : const Color(0xFF263847),
          border: Border.all(
            color: available ? GameUi.cyan : const Color(0xFF687987),
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$amount',
              style: TextStyle(
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: available ? GameUi.text : const Color(0xFFBAC7D0),
              ),
            ),
            const SizedBox(width: 3),
            Opacity(
              opacity: available ? 1 : .5,
              child: const CrystalCubeIcon(
                size: 16,
                glow: false,
                onLightBackground: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
