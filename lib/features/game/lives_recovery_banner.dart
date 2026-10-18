import 'package:provider/provider.dart';
import '../../data/economy_store.dart';
import 'package:flutter/material.dart';

import '../../ui/game_ui.dart';

/// A positive invitation to exchange crystals, keeping the familiar sofa scene.
class LivesRecoveryBanner extends StatelessWidget {
  const LivesRecoveryBanner({super.key, required this.onGetLives});

  final VoidCallback onGetLives;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final energy = context.watch<EconomyStore?>()?.energyEnabled == true;
    return Container(
      key: const ValueKey('lives-recovery-banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xD9123D56),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF77C7E3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ru ? 'Продолжим игру?' : 'Ready to keep playing?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: GameUi.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      energy
                          ? (ru
                                ? 'Заберите заряд или получите энергию за задания и возвращайтесь в игру.'
                                : 'Collect your charge or earn energy with tasks to keep playing.')
                          : ru
                          ? 'Обменяйте кристаллы на жизни и возвращайтесь в игру.'
                          : 'Exchange crystals for lives and get back to the game.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Color(0xFFD7EDFA),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/branding/ui/lives-resting-sofa-v2.png',
                key: const ValueKey('lives-recovery-sofa'),
                width: 104,
                height: 104,
                cacheWidth: (104 * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
                excludeFromSemantics: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 248),
              child: FilledButton(
                key: const ValueKey('lives-recovery-action'),
                onPressed: onGetLives,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 9,
                  ),
                  backgroundColor: Colors.transparent,
                  foregroundColor: GameUi.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GameUi.radius),
                  ),
                ),
                child: Text(
                  energy
                      ? (ru ? 'Получить энергию' : 'Get energy')
                      : ru
                      ? 'Открыть обменник'
                      : 'Open exchange',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
