import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_analytics.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/resting_cube_icon.dart';

/// Превью карточки для соцсетей + отправка (не скрин игрового UI).
Future<void> showShareSocialSheet(
  BuildContext context, {
  required int timeMs,
  int? betterPercent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareSocialSheet(
      timeMs: timeMs,
      betterPercent: betterPercent,
    ),
  );
}

class _ShareSocialSheet extends StatefulWidget {
  const _ShareSocialSheet({
    required this.timeMs,
    this.betterPercent,
  });

  final int timeMs;
  final int? betterPercent;

  @override
  State<_ShareSocialSheet> createState() => _ShareSocialSheetState();
}

class _ShareSocialSheetState extends State<_ShareSocialSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sending = false;

  String _timeLabel() {
    final s = widget.timeMs / 1000.0;
    if (s >= 10) return s.toStringAsFixed(1);
    return s.toStringAsFixed(2);
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/untouch_share.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final time = _timeLabel();
      final caption = l10n.shareScoreCaption(l10n.appTitle, time);
      AppAnalytics.shareSocial();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: caption,
          subject: l10n.appTitle,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('ShareSocialSheet: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = _timeLabel();
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          RepaintBoundary(
            key: _cardKey,
            child: _SocialShareCard(
              appTitle: l10n.appTitle,
              timeLabel: time,
              boast: l10n.shareBoast(time, l10n.appTitle),
              percentileText: widget.betterPercent == null
                  ? null
                  : l10n.rankToday(widget.betterPercent!),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded, size: 20),
            label: Text(l10n.shareSend),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}

/// Карточка 1:1 под сторис / ленту — фон в духе иконки Untouch.
class _SocialShareCard extends StatelessWidget {
  const _SocialShareCard({
    required this.appTitle,
    required this.timeLabel,
    required this.boast,
    this.percentileText,
  });

  final String appTitle;
  final String timeLabel;
  final String boast;
  final String? percentileText;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF3DDC97);
    const cyan = Color(0xFF7EE0FF);

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cyan.withValues(alpha: 0.85), width: 3),
          boxShadow: [
            BoxShadow(
              color: cyan.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Фон — иконка игры (голубой куб убегает от красного).
              Image.asset(
                'assets/branding/app_icon.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.15),
              ),
              // Затемнение: сверху легче (персонажи), снизу темнее (текст).
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.35, 0.62, 1.0],
                    colors: [
                      Color(0x660A1014),
                      Color(0x4D0A1014),
                      Color(0xCC070B0E),
                      Color(0xF2070B0E),
                    ],
                  ),
                ),
              ),
              // Мягкое свечение по краям в духе рамки иконки.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.35),
                    radius: 1.15,
                    colors: [
                      cyan.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0xFF0C1218).withValues(alpha: 0.72),
                        border: Border.all(
                          color: cyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 7, 16, 7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const RestingCubeIcon(size: 20),
                            const SizedBox(width: 8),
                            Text(
                              appTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: cyan.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -1.5,
                        color: accent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(context).seconds,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(flex: 2),
                    Text(
                      boast,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: const Color(0xFFF2F7FA),
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.65),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    if (percentileText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        percentileText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
