import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_analytics.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/neon_chrome.dart';
import '../../ui/game_ui.dart';
import 'social_share_card.dart';

/// Превью карточки для соцсетей + отправка (не скрин игрового UI).
Future<void> showShareSocialSheet(
  BuildContext context, {
  required int timeMs,
  int? betterPercent,
  int? riskCount,
  int? runSteps,
}) {
  return showDialog<void>(
    animationStyle: GameUi.windowAnimationStyle,
    context: context,
    useRootNavigator: false,
    barrierColor: GameUi.modalBarrier,
    builder: (_) => _ShareSocialSheet(
      timeMs: timeMs,
      betterPercent: betterPercent,
      riskCount: riskCount,
      runSteps: runSteps,
    ),
  );
}

class _ShareSocialSheet extends StatefulWidget {
  const _ShareSocialSheet({
    required this.timeMs,
    this.betterPercent,
    this.riskCount,
    this.runSteps,
  });

  final int timeMs;
  final int? betterPercent;
  final int? riskCount, runSteps;

  @override
  State<_ShareSocialSheet> createState() => _ShareSocialSheetState();
}

class _ShareSocialSheetState extends State<_ShareSocialSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sending = false;
  String? _feedback;

  String _timeLabel() => (widget.timeMs / 1000).toStringAsFixed(3);

  String _tr(String ru, String en) =>
      Localizations.localeOf(context).languageCode == 'ru' ? ru : en;

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _feedback = null;
    });
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('share_card_unavailable');
      // Wait for the same full-card scene used by the preview and PNG export.
      await precacheImage(SocialShareCard.imageProvider, context);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw StateError('share_image_unavailable');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/untouch_share.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final time = _timeLabel();
      final caption = l10n.shareScoreCaption(l10n.appTitle, time);
      AppAnalytics.shareSocial();
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: caption,
          subject: l10n.appTitle,
        ),
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        Navigator.pop(context);
      } else {
        setState(
          () => _feedback = result.status == ShareResultStatus.dismissed
              ? _tr('Отправка отменена', 'Sharing canceled')
              : _tr(
                  'Отправка недоступна на этом устройстве.',
                  'Sharing is unavailable on this device.',
                ),
        );
      }
    } catch (e) {
      debugPrint('ShareSocialSheet: $e');
      if (mounted) {
        setState(
          () => _feedback = _tr(
            'Не удалось подготовить карточку. Попробуйте ещё раз.',
            'Could not prepare the card. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    const actionStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w800);
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: (media.size.height - media.padding.vertical - 24).clamp(
            0,
            double.infinity,
          ),
        ),
        child: AccountGlass(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeonSheetHeader(
                title: l10n.shareSocial,
                titleSize: media.size.width < 340 ? 23 : 27,
              ),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  key: const ValueKey('share-content'),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: SocialShareCard(
                      appTitle: l10n.appTitle,
                      timeLabel: _timeLabel(),
                      riskCount: widget.riskCount,
                      runSteps: widget.runSteps,
                      boast: _tr(
                        'Сколько продержитесь вы?',
                        'How long can you survive?',
                      ),
                    ),
                  ),
                ),
              ),
              if (_feedback != null)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const ValueKey('share-feedback'),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF072D43),
                        border: Border.all(color: const Color(0xFFF58AA1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _feedback!,
                        style: const TextStyle(
                          color: Color(0xFFFFBCCD),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final label = TextPainter(
                    text: TextSpan(text: l10n.shareSend, style: actionStyle),
                    textDirection: Directionality.of(context),
                    textScaler: media.textScaler,
                  )..layout();
                  final width = (label.width + 64).clamp(
                    constraints.maxWidth * .64,
                    constraints.maxWidth,
                  );
                  label.dispose();
                  return Align(
                    child: SizedBox(
                      width: width,
                      child: FilledButton(
                        key: const ValueKey('share-send'),
                        onPressed: _sending ? null : _send,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          foregroundColor: GameUi.text,
                          textStyle: actionStyle,
                        ).copyWith(backgroundBuilder: accountButtonLayer),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_sending)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              const Icon(Icons.share_rounded, size: 21),
                            const SizedBox(width: 8),
                            Flexible(child: Text(l10n.shareSend)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Align(
                child: TextButton(
                  key: const ValueKey('share-cancel'),
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(100, 44),
                    foregroundColor: const Color(0xFF82DBEF),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(l10n.cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
