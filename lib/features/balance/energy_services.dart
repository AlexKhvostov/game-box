import '../../data/app_analytics.dart';
// Active energy services shared by the current and legacy UI.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/economy_store.dart';
import '../../data/mobile_account.dart';
import '../../data/play_billing_service.dart';
import '../../data/google_identity.dart';
import '../../ui/game_ui.dart';
import '../../ui/game_status_overlay.dart';
import '../../ui/energy_widgets.dart';
import '../../ui/billing_unavailable.dart';
import '../../ui/test_service_preview.dart';
import '../../ui/audience_gate.dart';
import '../profile/google_startup_dialog.dart';

String _tr(BuildContext c, String ru, String en) =>
    Localizations.localeOf(c).languageCode == 'ru' ? ru : en;
const _panel = Color(0xFF103E5C);
const _outline = Color(0xFF59C9DC);

class EnergyGlossAction extends StatelessWidget {
  const EnergyGlossAction({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext c) => EnergyNeonSurface(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: Center(child: child),
  );
}

ButtonStyle energyButtonStyle() =>
    OutlinedButton.styleFrom(
      backgroundColor: const Color(0xFF0C314B),
      foregroundColor: GameUi.cyan,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      side: const BorderSide(color: GameUi.cyan, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ).copyWith(
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.disabled)
              ? const Color(0xFF315169)
              : GameUi.cyan,
          width: 1.5,
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? const Color(0xFF0A2133)
            : const Color(0xFF0C314B),
      ),
      foregroundBuilder: (context, states, child) =>
          states.contains(WidgetState.disabled)
          ? Opacity(
              opacity: .48,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xFF91A9B9),
                  BlendMode.srcIn,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            )
          : child ?? const SizedBox.shrink(),
      backgroundBuilder: (context, states, child) => EnergyNeonSurface(
        enabled: !states.contains(WidgetState.disabled),
        padding: EdgeInsets.zero,
        child: child ?? const SizedBox.shrink(),
      ),
    );

class EnergyBillingStatus extends StatelessWidget {
  const EnergyBillingStatus({
    super.key,
    this.showRestore = true,
    this.collapseWhenIdle = false,
  });
  final bool showRestore, collapseWhenIdle;
  @override
  Widget build(BuildContext c) {
    final billing = c.watch<PlayBillingService?>();
    final pending = billing?.error == 'verification_pending';
    final text = billing?.busy == true
        ? _tr(
            c,
            'Покупка обрабатывается в Google Play…',
            'Processing your Google Play purchase…',
          )
        : pending
        ? _tr(
            c,
            'Проверяем покупку. Не оплачивайте повторно.',
            'Verifying purchase. Do not pay again.',
          )
        : billing?.error == 'purchase_failed'
        ? _tr(
            c,
            'Не удалось завершить оплату в Google Play.',
            'Could not complete payment in Google Play.',
          )
        : billing?.error != null
        ? _tr(
            c,
            'Покупка не завершена. Восстановите её.',
            'Purchase incomplete. Restore it.',
          )
        : testServicePreviewActive(c)
        ? _tr(
            c,
            'Тестовая версия · цены каталога',
            'Test version · catalog prices',
          )
        : '';
    if (collapseWhenIdle && text.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      key: const ValueKey('energy-billing-status'),
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              key: const ValueKey('energy-billing-status-text'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: GameUi.muted,
                fontSize: 10,
                height: 1.15,
              ),
            ),
          ),
          if (showRestore)
            TextButton(
              key: const ValueKey('energy-billing-restore'),
              onPressed: billing?.busy == true
                  ? null
                  : () => restoreGooglePurchases(c),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _tr(c, 'Восстановить', 'Restore'),
                style: const TextStyle(fontSize: 10, color: GameUi.cyan),
              ),
            ),
        ],
      ),
    );
  }
}

class EnergyFeedbackForm extends StatefulWidget {
  const EnergyFeedbackForm({super.key, this.onBack});
  final VoidCallback? onBack;
  @override
  State<EnergyFeedbackForm> createState() => _FeedbackContentState();
}

class _FeedbackContentState extends State<EnergyFeedbackForm> {
  final _text = TextEditingController();
  int? _rating;
  bool _busy = false, _sent = false, _ownerInitialized = false;
  String? _error, _owner;
  int _generation = 0;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !context.read<EconomyStore>().canSendEnergyFeedback) return;
    final e = context.read<EconomyStore>();
    final owner =
        '${context.read<MobileAccount?>()?.id ?? ''}|${e.energyOwner ?? ''}';
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await e.sendEnergyFeedback(_text.text.trim(), rating: _rating);
      if (!mounted ||
          generation != _generation ||
          '${context.read<MobileAccount?>()?.id ?? ''}|${e.energyOwner ?? ''}' !=
              owner) {
        return;
      }
      if (!e.energyRewardClaimed('feedback')) {
        throw StateError('feedback_unconfirmed');
      }
      AppAnalytics.event('feedback_result', {'status': 'confirmed'});
      setState(() => _sent = true);
    } catch (_) {
      AppAnalytics.event('feedback_result', {'status': 'unconfirmed'});
      if (mounted &&
          generation == _generation &&
          '${context.read<MobileAccount?>()?.id ?? ''}|${e.energyOwner ?? ''}' ==
              owner) {
        setState(
          () => _error = _tr(
            context,
            'Отзыв пока не подтверждён. Повторите отправку.',
            'Feedback is not confirmed yet. Please retry.',
          ),
        );
      }
    } finally {
      if (mounted &&
          generation == _generation &&
          '${context.read<MobileAccount?>()?.id ?? ''}|${e.energyOwner ?? ''}' ==
              owner) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    final e = c.watch<EconomyStore>();
    final accountOwner = c.watch<MobileAccount?>()?.id;
    final owner = '${accountOwner ?? ''}|${e.energyOwner ?? ''}';
    if (!_ownerInitialized || _owner != owner) {
      if (_ownerInitialized) {
        _generation++;
        _text.clear();
        _rating = null;
        _busy = false;
        _sent = false;
        _error = null;
      }
      _owner = owner;
      _ownerInitialized = true;
    }
    final count = _text.text.trim().runes.length;
    final ownerConfirmed =
        e.energyOwner == null ||
        c.read<MobileAccount?>()?.id == null ||
        e.energyOwner == c.read<MobileAccount?>()?.id;
    if (ownerConfirmed && (_sent || e.energyRewardClaimed('feedback'))) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            const Icon(
              Icons.mark_chat_read_rounded,
              size: 64,
              color: GameUi.mint,
            ),
            const SizedBox(height: 12),
            Text(
              _tr(
                c,
                'Спасибо! Ваш отзыв принят.',
                'Thank you! We received your feedback.',
              ),
              style: const TextStyle(color: GameUi.text, fontSize: 16),
            ),
            const SizedBox(height: 9),
            EnergyText(
              e.energyConfig.reward('feedback'),
              prefix: '+',
              size: 27,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('energy-feedback-back'),
                  onTap: widget.onBack ?? () => Navigator.pop(c),
                  borderRadius: BorderRadius.circular(9),
                  child: EnergyGlossAction(
                    child: Text(
                      _tr(c, 'К энергии', 'Back to energy'),
                      style: const TextStyle(
                        color: GameUi.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (!e.canSendEnergyFeedback) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.sports_esports_outlined,
            color: GameUi.cyan,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            _tr(
              c,
              'Сначала познакомьтесь с игрой',
              'Get to know the game first',
            ),
            style: const TextStyle(color: GameUi.text, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text(
            _tr(
              c,
              'Расскажите нам о своём опыте после того, как потратите ${e.feedbackMinimumSpend} энергии в игре. За первый рассказ — ${e.energyConfig.reward('feedback')} энергии. Любое честное мнение одинаково ценно.',
              'Share your experience after spending ${e.feedbackMinimumSpend} energy in the game. Your first feedback earns ${e.energyConfig.reward('feedback')} energy. Every honest opinion is equally welcome.',
            ),
            style: const TextStyle(color: GameUi.text, fontSize: 14),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            key: const ValueKey("energy-feedback-progress"),
            color: GameUi.mint,
            backgroundColor: GameUi.muted.withValues(alpha: .16),
            value:
                (e.feedbackSpentEnergy /
                        e.feedbackMinimumSpend.clamp(1, 1000000))
                    .clamp(0.0, 1.0),
          ),
          const SizedBox(height: 8),
          Text(
            _tr(
              c,
              'Потрачено: ${e.feedbackSpentEnergy} из ${e.feedbackMinimumSpend}',
              'Spent: ${e.feedbackSpentEnergy} of ${e.feedbackMinimumSpend}',
            ),
            style: const TextStyle(color: GameUi.muted, fontSize: 13),
          ),
        ],
      );
    }
    return GameStatusOverlay(
      message: _error ?? (_busy ? _tr(c, 'Отправляем…', 'Sending…') : null),
      busy: _busy && _error == null,
      isError: _error != null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _tr(
              c,
              'Что понравилось? Что можно улучшить?',
              'What did you enjoy? What could we improve?',
            ),
            style: const TextStyle(color: GameUi.text, fontSize: 14),
          ),
          const SizedBox(height: 7),
          Row(
            children: List.generate(5, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 4 ? 0 : 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _rating = i + 1),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _rating == i + 1
                              ? const Color(0xFF124D7D)
                              : GameUi.ink,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _rating == i + 1 ? energyNeon : _outline,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${i + 1} ★',
                            style: TextStyle(
                              color: _rating == i + 1
                                  ? energyNeon
                                  : GameUi.muted,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 7),
          Text(
            _tr(
              c,
              'Оценка по желанию. Награда одинакова.',
              'Rating is optional. The reward stays the same.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: GameUi.muted, fontSize: 11),
          ),
          const SizedBox(height: 9),
          Text(
            _tr(c, 'Впечатления', 'Your impressions'),
            style: const TextStyle(
              color: GameUi.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('energy-feedback-text'),
            controller: _text,
            minLines: 3,
            maxLines: 5,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: GameUi.text),
            decoration: InputDecoration(
              hintText: _tr(c, 'От 20 символов', 'At least 20 characters'),
              hintStyle: const TextStyle(color: GameUi.muted),
              filled: true,
              fillColor: _panel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              counterText: '$count / 20 · ${_tr(c, 'минимум', 'minimum')}',
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline),
              color: _panel,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _tr(c, 'За первый отзыв', 'For your first feedback'),
                    style: const TextStyle(color: GameUi.muted, fontSize: 12),
                  ),
                ),
                EnergyText(
                  e.energyConfig.reward('feedback'),
                  prefix: '+',
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const ValueKey('energy-feedback-send'),
            style: energyButtonStyle(),
            onPressed: count >= 20 && count <= 1000 && !_busy && !e.energyBusy
                ? _send
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _tr(c, 'Отправить ', 'Send '),
                  style: const TextStyle(color: GameUi.text),
                ),
                EnergyText(
                  e.energyConfig.reward('feedback'),
                  prefix: '+',
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _tr(
              c,
              'Это сообщение команде игры. Оно не публикуется в Google Play.',
              'This is a message to the game team. It is not posted to Google Play.',
            ),
            style: const TextStyle(color: GameUi.muted, fontSize: 10),
          ),
          TextButton(
            key: const ValueKey('energy-feedback-form-back'),
            onPressed: _busy ? null : widget.onBack ?? () => Navigator.pop(c),
            child: Text(
              _tr(c, '← К энергии', '← Back to energy'),
              style: const TextStyle(color: GameUi.cyan, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showEnergyPurchaseRecovery(
  BuildContext c,
  PlayBillingService billing,
) async {
  final connect = await showDialog<bool>(
    context: c,
    useRootNavigator: false,
    builder: (c) => AlertDialog(
      backgroundColor: _panel,
      title: Text(
        _tr(c, 'Google для покупок', 'Google for purchases'),
        style: const TextStyle(color: GameUi.text),
      ),
      content: Text(
        _tr(
          c,
          'Подключите существующий Google-профиль игры перед оплатой. Он сохраняет энергию и покупки после переустановки.',
          'Connect your existing game Google profile before paying. It keeps your energy and purchases recoverable after reinstalling.',
        ),
        style: const TextStyle(color: GameUi.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(_tr(c, 'Позже', 'Later')),
        ),
        TextButton(
          key: const ValueKey('energy-recovery-connect'),
          onPressed: () => Navigator.pop(c, true),
          child: Text(_tr(c, 'Подключить Google', 'Connect Google')),
        ),
      ],
    ),
  );
  if (connect == true && c.mounted) {
    await showGoogleStartupOffer(
      c,
      account: billing.account,
      identity: NativeGoogleIdentity(),
    );
  }
}

Future<void> buySimpleEnergy(BuildContext c, String id) => runResourceAction(
  c,
  c.read<PlayBillingService?>() ?? c.read<EconomyStore>(),
  'billing',
  () async {
    final billing = c.read<PlayBillingService?>();
    if (billing == null ||
        !billing.available ||
        billing.busy ||
        billing.price(id) == null) {
      showBillingUnavailable(c);
      return;
    }
    if (!billing.account.googleLinked) {
      await showEnergyPurchaseRecovery(c, billing);
      return;
    }
    try {
      await billing.buy(id);
    } on MobileApiError catch (error) {
      if (!c.mounted) return;
      if (error.code == 'purchase_requires_recovery') {
        await showEnergyPurchaseRecovery(c, billing);
        return;
      }
      rethrow;
    }
  },
);
