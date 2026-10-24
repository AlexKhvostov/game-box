import 'package:flutter/material.dart';
import '../../ui/game_ui.dart';

/// S03: only the scene is a bitmap; all result values remain live/exportable.
class SocialShareCard extends StatelessWidget {
  const SocialShareCard({
    super.key,
    required this.appTitle,
    required this.timeLabel,
    required this.boast,
    this.riskCount,
    this.runSteps,
  });
  static const asset = 'assets/branding/ui/share-scene-square-v1.png';
  static ImageProvider get imageProvider =>
      ResizeImage.resizeIfNeeded(1254, null, const AssetImage(asset));
  final String appTitle, timeLabel, boast;
  final int? riskCount, runSteps;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final padding = (width * .038).clamp(12.0, 17.0);
        final contentWidth = width - padding * 2;
        Widget metric(IconData icon, String label, int value, Color color) =>
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 23),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: '$label ',
                        children: [
                          TextSpan(
                            text: '$value',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        color: GameUi.text,
                        fontSize: (width * .043).clamp(13.0, 19.0),
                        height: 1.25,
                        shadows: const [
                          Shadow(color: Color(0xFF001020), blurRadius: 5),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
        return Container(
          key: const ValueKey('share-preview'),
          decoration: BoxDecoration(
            color: const Color(0xFF03182D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF04E4F3), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image(
                  key: const ValueKey('share-scene'),
                  image: imageProvider,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x2B00172A),
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xB8001428),
                      ],
                      stops: [0, .35, .68, 1],
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: width * .98),
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appTitle.toLowerCase(),
                            style: TextStyle(
                              color: const Color(0xFF4BEDFF),
                              fontSize: (width * .059).clamp(20.0, 26.0),
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                              shadows: const [
                                Shadow(color: Color(0x8800DFFF), blurRadius: 8),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$timeLabel ${ru ? 'с' : 's'}',
                              style: TextStyle(
                                color: const Color(0xFFFFF06A),
                                fontSize: (width * .122).clamp(35.0, 54.0),
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                shadows: const [
                                  Shadow(
                                    color: Color(0x77FFE74B),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: width * .42),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (riskCount != null || runSteps != null) ...[
                            Wrap(
                              spacing: width * .07,
                              runSpacing: 6,
                              children: [
                                if (riskCount != null)
                                  metric(
                                    Icons.warning_amber_rounded,
                                    ru ? 'Риск' : 'Risk',
                                    riskCount!,
                                    const Color(0xFFFF9EAE),
                                  ),
                                if (runSteps != null)
                                  metric(
                                    Icons.hiking_rounded,
                                    ru ? 'Шаги' : 'Steps',
                                    runSteps!,
                                    const Color(0xFF69EBFF),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 7),
                          ],
                          Text(
                            boast,
                            style: TextStyle(
                              color: GameUi.text,
                              fontSize: (width * .051).clamp(16.0, 23.0),
                              fontWeight: FontWeight.w900,
                              height: 1.18,
                              shadows: const [
                                Shadow(color: Color(0xFF001323), blurRadius: 5),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
