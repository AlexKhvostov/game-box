import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_analytics.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_sheet.dart';
import '../../ui/game_ui.dart';
import '../../ui/game_run_scene.dart';

/// Превью карточки для соцсетей + отправка (не скрин игрового UI).
Future<void> showShareSocialSheet(
  BuildContext context, {
  required int timeMs,
  int? betterPercent,
  int? riskCount,
  int? runSteps,
}) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: GameUi.windowAnimationStyle,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
      // Export the compact card only after its horizontal scene has
      // decoded and the frame has painted; a fast tap must not share a blank.
      await precacheImage(
        GameRunScene.provider(
          boundary.size.width - 3,
          MediaQuery.devicePixelRatioOf(context) > 3
              ? MediaQuery.devicePixelRatioOf(context)
              : 3,
        ),
        context,
      );
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
    final time = _timeLabel();

    return GameSheetChrome(
      heightFactor: .92,
      fitContent: true,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GameSheetHeader(title: l10n.shareSocial),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: _SocialShareCard(
                      appTitle: l10n.appTitle,
                      timeLabel: time,
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
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const ValueKey('share-feedback'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5E8),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        _feedback!,
                        style: const TextStyle(
                          color: Color(0xFF6E1935),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
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
                key: const ValueKey('share-send'),
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(GameUi.touchTarget(context)),
                ),
              ),
              const SizedBox(height: 4),
              OutlinedButton(
                onPressed: _sending ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(GameUi.touchTarget(context)),
                ),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shared PNG contains the complete game scene and readable real values.
class _SocialShareCard extends StatelessWidget {
  const _SocialShareCard({
    required this.appTitle,
    required this.timeLabel,
    required this.boast,
    this.riskCount,
    this.runSteps,
  });
  final String appTitle, timeLabel, boast;
  final int? riskCount, runSteps;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final time = '$timeLabel ${ru ? 'с' : 's'}';
    return Semantics(
      label: '$appTitle $timeLabel ${AppLocalizations.of(context).seconds}',
      child: Container(
        key: const ValueKey('share-preview'),
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF061B2B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF68D6E9), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appTitle.toLowerCase(),
                      style: const TextStyle(
                        color: GameUi.mint,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        time,
                        style: const TextStyle(
                          color: GameUi.text,
                          fontSize: 40,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) => AspectRatio(
                  aspectRatio: GameRunScene.aspectRatio,
                  child: Image(
                    key: const ValueKey('share-scene'),
                    image: GameRunScene.provider(constraints.maxWidth, 3),
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (riskCount != null && runSteps != null) ...[
                      Wrap(
                        spacing: 16,
                        runSpacing: 3,
                        children: [
                          Text(
                            '${ru ? 'Риск' : 'Risk'} $riskCount',
                            style: const TextStyle(
                              fontSize: 11,
                              color: GameUi.muted,
                            ),
                          ),
                          Text(
                            '${ru ? 'Шаги' : 'Steps'} $runSteps',
                            style: const TextStyle(
                              fontSize: 11,
                              color: GameUi.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      boast,
                      style: const TextStyle(
                        color: GameUi.text,
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
