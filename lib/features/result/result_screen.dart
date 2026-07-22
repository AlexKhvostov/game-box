import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/scores_store.dart';
import '../../l10n/app_localizations.dart';

/// Результат: подложка + появление + Hero таймера.
class ResultOverlay extends StatefulWidget {
  const ResultOverlay({
    super.key,
    required this.timeMs,
    required this.onOk,
    required this.onShare,
  });

  final int timeMs;
  final VoidCallback onOk;
  final VoidCallback onShare;

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.15, 0.85, curve: Curves.easeOutBack),
      ),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.2, 1, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _formatTime(int ms) => (ms / 1000.0).toStringAsFixed(3);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final rank = context.watch<ScoresStore>().rankFor(widget.timeMs);

    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Затемнение + blur-like градиент
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.82),
                    const Color(0xFF0A1014).withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SlideTransition(
                  position: _slide,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.lerp(
                                theme.colorScheme.primary,
                                const Color(0xFF1A242C),
                                0.72,
                              )!,
                              const Color(0xFF12181E),
                              const Color(0xFF0E1419),
                            ],
                          ),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.28),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.newScore.toUpperCase(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                letterSpacing: 3,
                                fontWeight: FontWeight.w800,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _formatTime(widget.timeMs),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 58,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.primary,
                                height: 1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.seconds,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                letterSpacing: 2,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.black.withValues(alpha: 0.28),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Text(
                                rank.totalCount == 0
                                    ? l10n.newScore
                                    : l10n.rankFaster(
                                        rank.place,
                                        rank.percentile,
                                      ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: widget.onShare,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.55),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(l10n.share),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: widget.onOk,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(l10n.ok),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
