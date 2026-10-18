// Historical UI: kept for legacy targets and regression tests. Android uses energy_sheet.dart.
import 'dart:math' as math;
import 'package:game_box/features/balance/energy_services.dart';
export 'package:game_box/features/balance/energy_services.dart' show EnergyBillingStatus, EnergyFeedbackForm;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/mobile_invites.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/google_identity.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/ui/game_ui.dart';
import 'package:game_box/ui/game_sheet.dart';
import 'package:game_box/ui/energy_widgets.dart';
import 'package:game_box/ui/audience_gate.dart';
import 'package:game_box/ui/watch_rewarded_ad.dart';
import 'package:game_box/ui/billing_unavailable.dart';
import 'package:game_box/ui/test_service_preview.dart';
import 'package:game_box/features/profile/google_startup_dialog.dart';

String _tr(BuildContext c, String ru, String en) =>
    Localizations.localeOf(c).languageCode == 'ru' ? ru : en;
const _panel = Color(0xFF103E5C);
const _outline = Color(0xFF59C9DC);

Future<void> showLegacyEnergySheet(
  BuildContext context, {
  int initialTab = 0,
}) => showDialog<void>(
  context: context,
  useRootNavigator: false,
  barrierColor: GameUi.modalBarrier,
  animationStyle: GameUi.windowAnimationStyle,
  builder: (_) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: LegacyEnergySheet(initialTab: initialTab),
    ),
  ),
);

class _EnergyDesignHeader extends StatelessWidget {
  const _EnergyDesignHeader({
    required this.title,
    this.balance,
    this.balanceWidth = 112,
    this.fitTitle = false,
    this.edgeToEdge = false,
  });
  final String title;
  final int? balance;
  final double balanceWidth;
  final bool fitTitle;
  final bool edgeToEdge;
  Widget get _title => Text(
    title,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      color: GameUi.text,
      fontSize: 19,
      fontWeight: FontWeight.w800,
    ),
  );
  @override
  Widget build(BuildContext c) => Container(
    height: 64,
    padding: EdgeInsets.symmetric(horizontal: edgeToEdge ? 12 : 0),
    clipBehavior: Clip.antiAlias,
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF367F9F), Color(0xFF155976), Color(0xFF082E4C)],
        stops: [0, .2, 1],
      ),
      border: Border(bottom: BorderSide(color: Color(0x6659C9DC))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: fitTitle
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _title,
                  )
                : _title,
          ),
        ),
        if (balance != null)
          SizedBox(
            key: const ValueKey('energy-balance'),
            width: balanceWidth,
            height: 43,
            child: EnergyBalanceCapsule(amount: balance!),
          ),
        IconButton(
          key: const ValueKey('energy-close'),
          onPressed: () => Navigator.pop(c),
          tooltip: MaterialLocalizations.of(c).closeButtonTooltip,
          icon: const Icon(Icons.close_rounded, color: GameUi.muted, size: 23),
        ),
      ],
    ),
  );
}

class LegacyEnergySheet extends StatefulWidget {
  const LegacyEnergySheet({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<LegacyEnergySheet> createState() => _LegacyEnergySheetState();
}

class _LegacyEnergySheetState extends State<LegacyEnergySheet> {
  late int _tab;
  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 3);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final e = context.read<EconomyStore>();
      final policy = context.read<AudiencePolicy?>();
      if (policy?.band != null &&
          policy!.band != AgeBand.unknown &&
          !e.energyRewardClaimed('age') &&
          !e.energyRewardReady('age')) {
        try {
          await e.completeEnergyAge();
        } catch (_) {
          /* Retry remains available on the age task. */
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return SizedBox(
      key: const ValueKey('energy-sheet'),
      height: 512 * scale.clamp(1.0, 1.3),
      child: LayoutBuilder(
        builder: (context, bounds) => FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: bounds.maxWidth,
            height: math.min(512, bounds.maxHeight),
            child: Container(
              decoration: BoxDecoration(
                gradient: GameUi.navySheetGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: GameUi.line, width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0x1A79F1F5), blurRadius: 12),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  children: [
                    _EnergyDesignHeader(
                      title: _tr(context, 'Энергия', 'Energy'),
                      balance: economy.energy,
                      fitTitle: true,
                      // Keep the title and close target, then give the wallet
                      // the remaining room. Secondary windows keep their size.
                      balanceWidth: (bounds.maxWidth - 20 - 48 - 88)
                          .clamp(112.0, 170.0)
                          .toDouble(),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(
                        4,
                        (i) => Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _tab = i),
                            child: Semantics(
                              button: true,
                              selected: _tab == i,
                              child: Container(
                                key: ValueKey('energy-tab-$i'),
                                height: 49,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _tab == i
                                      ? _panel
                                      : const Color(0xFF061A2B),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(10),
                                  ),
                                  boxShadow: _tab == i
                                      ? [
                                          BoxShadow(
                                            color: i == 3
                                                ? energyNeon
                                                : GameUi.cyan,
                                            offset: const Offset(0, -3),
                                          ),
                                        ]
                                      : null,
                                  border: Border(
                                    top: BorderSide(
                                      color: _tab == i
                                          ? (i == 3 ? energyNeon : GameUi.cyan)
                                          : _outline,
                                      width: 1.5,
                                    ),
                                    left: BorderSide(
                                      color: _tab == i
                                          ? (i == 3 ? energyNeon : GameUi.cyan)
                                          : _outline,
                                      width: 1.5,
                                    ),
                                    right: BorderSide(
                                      color: _tab == i
                                          ? (i == 3 ? energyNeon : GameUi.cyan)
                                          : _outline,
                                      width: 1.5,
                                    ),
                                    bottom: _tab == i
                                        ? BorderSide.none
                                        : const BorderSide(
                                            color: _outline,
                                            width: 1.5,
                                          ),
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          [
                                            _tr(context, 'Заряд', 'Charge'),
                                            _tr(context, 'Задания', 'Tasks'),
                                            _tr(context, 'Друзья', 'Friends'),
                                            _tr(context, 'Купить', 'Buy'),
                                          ][i],
                                          key: ValueKey('energy-tab-label-$i'),
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(
                                            color: _tab == i
                                                ? (i == 3
                                                      ? energyNeon
                                                      : GameUi.text)
                                                : GameUi.muted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (i < 3)
                                      Positioned(
                                        top: 1,
                                        right: 2,
                                        child: SizedBox(
                                          height: 9,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'FREE',
                                              key: ValueKey(
                                                'energy-tab-free-$i',
                                              ),
                                              style: const TextStyle(
                                                color: GameUi.mint,
                                                fontSize: 7,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: .5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        key: const ValueKey('energy-content'),
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                        decoration: BoxDecoration(
                          color: _panel,
                          border: const Border(
                            left: BorderSide(color: GameUi.cyan, width: 1.5),
                            right: BorderSide(color: GameUi.cyan, width: 1.5),
                            bottom: BorderSide(color: GameUi.cyan, width: 1.5),
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(11),
                          ),
                        ),
                        child: IndexedStack(
                          index: _tab,
                          children: [
                            _ChargePane(visible: _tab == 0),
                            const _TasksPane(),
                            _EnergyFriendsPane(visible: _tab == 2),
                            const _BuyPane(),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 2,
                      child: economy.energyBusy
                          ? const LinearProgressIndicator(minHeight: 2)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChargePane extends StatefulWidget {
  const _ChargePane({required this.visible});
  final bool visible;
  @override
  State<_ChargePane> createState() => _ChargePaneState();
}

class _ChargePaneState extends State<_ChargePane> {
  Timer? _clock;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.visible) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _claim() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<EconomyStore>().claimEnergy();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _tr(
            context,
            'Не удалось забрать. Повторите.',
            'Could not collect. Retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<EconomyStore>();
    final slots = e.energyBatteries;
    final now = e.energyNow;
    final total = e.accumulatedEnergy;
    final cap = e.energyCapacity;
    final full = total >= cap && cap > 0;
    final remaining = e.energyUntilFull;
    return LayoutBuilder(
      builder: (context, bounds) {
        final short = bounds.maxHeight < 330;
        return Column(
          children: [
            SizedBox(
              height: slots.length > 2 ? 103 : (short ? 116 : 151),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < slots.length; i++) ...[
                    if (i > 0) SizedBox(width: slots.length > 2 ? 6 : 36),
                    Flexible(
                      child: SizedBox(
                        width: slots.length > 2 ? 70 : 126,
                        child: EnergyBatteryTile(
                          key: ValueKey('energy-battery-$i'),
                          percent: slots[i].percentAt(now),
                          amount: slots[i].unitsAt(now),
                          capacity: slots[i].capacity,
                          compact: slots.length > 2,
                          paused: e.energySubscriptionPending && i > 0,
                        ),
                      ),
                    ),
                  ],
                  if (slots.length == 1) ...[
                    const SizedBox(width: 36),
                    Flexible(
                      child: SizedBox(
                        width: 126,
                        child: EnergyBatteryTile(
                          percent: 0,
                          amount: 0,
                          capacity: slots.first.capacity,
                          active: false,
                          onConnect: () =>
                              showLegacyEnergySubscriptionSheet(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: short ? 9 : 15),
            SizedBox(
              key: const ValueKey('energy-charge-summary'),
              height: 43,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tr(context, 'Накоплено', 'Collected'),
                        style: const TextStyle(
                          color: GameUi.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$total',
                              style: const TextStyle(
                                color: energyNeon,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Color(0x99FFE02F),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              ' / $cap ',
                              style: const TextStyle(
                                color: Color(0xFFADA794),
                                fontSize: 19,
                              ),
                            ),
                            const Icon(
                              Icons.bolt_rounded,
                              color: energyNeon,
                              size: 23,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                height: 48,
                width: math.min(
                  bounds.maxWidth,
                  math.max(184, math.min(248, bounds.maxWidth * .78)),
                ),
                child: OutlinedButton(
                  key: const ValueKey('energy-claim'),
                  onPressed:
                      total > 0 &&
                          !_busy &&
                          !e.energyBusy &&
                          !e.energySubscriptionPending
                      ? () => runResourceAction(
                          context,
                          e,
                          'energy-claim',
                          _claim,
                        )
                      : null,
                  style: energyButtonStyle(),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_busy) ...[
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _tr(context, 'Забрать ', 'Collect '),
                          style: const TextStyle(
                            color: GameUi.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        EnergyText(total, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(fontSize: 10, color: GameUi.heart),
              ),
            const SizedBox(height: 9),
            SizedBox(
              height: 26,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _tr(
                        context,
                        'От 0 до 100% — ${e.energyConfig.chargeHours.toStringAsFixed(0)} часов',
                        '0 to 100% — ${e.energyConfig.chargeHours.toStringAsFixed(0)} hours',
                      ),
                      style: const TextStyle(color: GameUi.muted, fontSize: 9),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.energySubscriptionPending
                          ? _tr(
                              context,
                              'Проверяем подписку',
                              'Verifying subscription',
                            )
                          : !e.energyClockSynchronized
                          ? _tr(
                              context,
                              'Обновится при подключении',
                              'Updates when connected',
                            )
                          : full
                          ? _tr(context, 'Заряд полный', 'Fully charged')
                          : _tr(
                              context,
                              'До полного — ${remaining.inHours} ч ${remaining.inMinutes.remainder(60)} мин',
                              'Full in ${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m',
                            ),
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: GameUi.muted, fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
            if (e.energySubscribed && !e.energySubscriptionPending)
              SizedBox(
                height: 48,
                child: TextButton(
                  key: const ValueKey('energy-subscription-manage'),
                  onPressed: () => showLegacyEnergySubscriptionSheet(context),
                  child: Text(
                    _tr(
                      context,
                      slots.length == 2
                          ? 'Подключить ещё батарейки →'
                          : 'Условия подключения',
                      slots.length == 2
                          ? 'Connect more batteries →'
                          : 'Connection terms',
                    ),
                    style: const TextStyle(color: GameUi.cyan, fontSize: 11),
                  ),
                ),
              ),
            if (e.energySubscriptionPending)
              SizedBox(
                height: 48,
                child: TextButton(
                  key: const ValueKey('energy-charge-restore'),
                  onPressed: () => restoreGooglePurchases(context),
                  child: Text(_tr(context, 'Восстановить', 'Restore')),
                ),
              ),
            const Spacer(),
          ],
        );
      },
    );
  }
}

class _TasksPane extends StatefulWidget {
  const _TasksPane();
  @override
  State<_TasksPane> createState() => _TasksPaneState();
}

class _TasksPaneState extends State<_TasksPane> {
  Timer? _clock;
  bool _wasCooling = false;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final cooling =
          context.read<EconomyStore>().watchAdCooldownRemaining != null;
      if (cooling || _wasCooling) setState(() {});
      _wasCooling = cooling;
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _google(BuildContext c, EconomyStore e) async {
    if (e.energyRewardReady('google')) {
      await e.claimEnergyReward('google');
      return;
    }
    final account = c.read<MobileAccount?>();
    if (account == null) return;
    await showGoogleStartupOffer(
      c,
      account: account,
      identity: NativeGoogleIdentity(),
    );
  }

  Future<void> _age(BuildContext c, EconomyStore e) async {
    if (e.energyRewardReady('age')) {
      await e.claimEnergyReward('age');
      return;
    }
    await showAudienceSelection(c);
    if (!c.mounted) return;
    final policy = c.read<AudiencePolicy?>();
    if (policy?.band != null && policy!.band != AgeBand.unknown) {
      await e.completeEnergyAge();
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<EconomyStore>();
    final ads = context.watch<AdsService?>();
    final cooldown = e.watchAdCooldownRemaining;
    _wasCooling = _wasCooling || cooldown != null;
    final seconds = cooldown == null
        ? 0
        : (cooldown.inMilliseconds / 1000).ceil();
    final cooldownLabel =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    Widget task(
      String id,
      IconData icon,
      String title,
      int reward,
      FutureOr<void> Function() action, {
      String? detail,
      bool enabled = true,
      String? actionLabel,
    }) {
      final done = e.energyRewardClaimed(id);
      final ready = e.energyRewardReady(id);
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: const Color(0xFF102E45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: _outline),
            ),
            child: InkWell(
              key: ValueKey('energy-task-$id'),
              borderRadius: BorderRadius.circular(9),
              onTap: !done && enabled && !e.energyBusy
                  ? () => _guard(context, action)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: done ? GameUi.muted : GameUi.cyan,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: GameUi.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (detail != null || ready || done)
                              Text(
                                done
                                    ? _tr(context, 'Получено', 'Collected')
                                    : ready
                                    ? _tr(
                                        context,
                                        'Забрать награду',
                                        'Collect reward',
                                      )
                                    : detail!,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: GameUi.muted,
                                  fontSize: 9,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    done
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: GameUi.mint,
                            size: 23,
                          )
                        : EnergyText(reward, prefix: '+', size: 19),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 62,
                      height: 34,
                      child: Opacity(
                        opacity: done || !enabled ? .55 : 1,
                        child: EnergyGlossAction(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              actionLabel ??
                                  (done
                                      ? _tr(context, 'Получено', 'Collected')
                                      : ready
                                      ? _tr(context, 'Забрать', 'Collect')
                                      : id == 'achievements'
                                      ? _tr(context, 'Открыть', 'Open')
                                      : id == 'watch_ad'
                                      ? _tr(context, 'Смотреть', 'Watch')
                                      : id == 'google'
                                      ? _tr(context, 'Подключить', 'Connect')
                                      : _tr(context, 'Ответить', 'Answer')),
                              style: const TextStyle(
                                color: GameUi.text,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, bounds) {
        final full = bounds.maxHeight >= 335;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: full ? 328 : bounds.maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 14,
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _tr(
                          context,
                          'Получайте энергию бесплатно',
                          'Get energy for free',
                        ),
                        style: const TextStyle(
                          color: GameUi.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  task(
                    'achievements',
                    Icons.emoji_events_outlined,
                    _tr(context, 'Достижения', 'Achievements'),
                    3 * e.energyConfig.reward('achievement'),
                    () => showEnergyAchievementsSheet(context),
                    detail: _tr(
                      context,
                      '3 цели · по ${e.energyConfig.reward('achievement')} энергии',
                      '3 goals · ${e.energyConfig.reward('achievement')} energy each',
                    ),
                  ),
                  if (!e.energySubscribed)
                    task(
                      'watch_ad',
                      Icons.ondemand_video_rounded,
                      _tr(context, 'Посмотреть видео', 'Watch a video'),
                      e.energyConfig.reward('watch_ad'),
                      () => watchRewardedAd(context),
                      actionLabel: cooldown != null ? cooldownLabel : null,
                      detail: cooldown != null
                          ? _tr(
                              context,
                              'Повтор через $cooldownLabel',
                              'Available in $cooldownLabel',
                            )
                          : ads == null && !testServicePreviewActive(context)
                          ? _tr(
                              context,
                              'Сейчас недоступно',
                              'Currently unavailable',
                            )
                          : _tr(
                              context,
                              'Награда после просмотра',
                              'Reward after watching',
                            ),
                      enabled:
                          e.canClaimWatchAd &&
                          (ads != null || testServicePreviewActive(context)),
                    ),
                  task(
                    'google',
                    Icons.cloud_done_outlined,
                    _tr(context, 'Google аккаунт', 'Google account'),
                    e.energyConfig.reward('google'),
                    () => _google(context, e),
                  ),
                  task(
                    'age',
                    Icons.person_outline_rounded,
                    _tr(context, 'Возрастная группа', 'Age group'),
                    e.energyConfig.reward('age'),
                    () => _age(context, e),
                  ),
                  task(
                    'feedback',
                    Icons.chat_bubble_outline_rounded,
                    _tr(context, 'Обратная связь', 'Feedback'),
                    e.energyConfig.reward('feedback'),
                    () => showEnergyFeedbackSheet(context),
                    detail: _tr(
                      context,
                      'Комментарий от 20 символов',
                      'A comment of 20+ characters',
                    ),
                  ),
                  if (full)
                    SizedBox(
                      height: 18,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _tr(
                            context,
                            'Награды сразу пополняют ваш баланс.',
                            'Rewards go straight to your balance.',
                          ),
                          style: const TextStyle(
                            color: GameUi.muted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (full) const Spacer(),
          ],
        );
      },
    );
  }
}

Future<void> _guard(BuildContext c, FutureOr<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    if (c.mounted) {
      ScaffoldMessenger.maybeOf(c)?.showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              c,
              'Не удалось выполнить. Проверьте подключение.',
              'Could not complete. Check your connection.',
            ),
          ),
        ),
      );
    }
  }
}

class _BuyPane extends StatelessWidget {
  const _BuyPane();
  @override
  Widget build(BuildContext context) {
    final e = context.watch<EconomyStore>();
    final billing = context.watch<PlayBillingService?>();
    final packs = e.energyConfig.packages;
    final maxAmount = packs.fold<int>(
      1,
      (maximum, p) => math.max(maximum, p.amount),
    );
    final basePack = packs.isEmpty
        ? null
        : packs.reduce((a, b) => a.amount <= b.amount ? a : b);
    final baseProduct = basePack == null
        ? null
        : billing?.energyOfferPrice(basePack.id);
    Widget pack(int i) {
      if (i >= packs.length) return const SizedBox.shrink();
      final p = packs[i];
      final discount = billing?.energyDiscount(p.id, e.energyConfig);
      final product = billing?.energyOfferPrice(p.id);
      final comparable =
          discount != null &&
          basePack != null &&
          basePack.amount > 0 &&
          baseProduct != null &&
          product != null &&
          baseProduct.rawPrice.isFinite &&
          baseProduct.rawPrice > 0 &&
          product.rawPrice.isFinite &&
          product.rawPrice > 0 &&
          product.currencyCode.isNotEmpty &&
          product.currencyCode == baseProduct.currencyCode;
      final beforeValue = comparable
          ? baseProduct.rawPrice * p.amount / basePack.amount
          : null;
      final beforePrice = beforeValue == null
          ? null
          : NumberFormat.currency(
              locale: Localizations.localeOf(context).toString(),
              name: product!.currencyCode,
              symbol: product.currencySymbol.isEmpty
                  ? product.currencyCode
                  : product.currencySymbol,
              decimalDigits: beforeValue % 1 == 0 ? 0 : 2,
            ).format(beforeValue);
      final available =
          billing?.busy != true &&
          (testServicePreviewActive(context) ||
              (billing?.available == true && product != null));
      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('energy-pack-${p.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: available
              ? () => showEnergyPurchaseSheet(context, p.id, p.amount)
              : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF79DBE9)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF19516B), Color(0xFF0D2A40)],
              ),
            ),
            child: LayoutBuilder(
              builder: (c, bounds) => Column(
                children: [
                  SizedBox(
                    height: 16,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: discount == null
                          ? null
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: GameUi.ink,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: _outline),
                              ),
                              child: Text(
                                '−$discount%',
                                style: const TextStyle(
                                  color: GameUi.text,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EnergyText(p.amount, size: 27, leadingBolt: true),
                          Text(
                            _tr(context, 'энергии', 'energy'),
                            style: const TextStyle(
                              color: GameUi.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    key: ValueKey('energy-buy-${p.id}'),
                    height: bounds.maxHeight < 100 ? 38 : 60,
                    width: double.infinity,
                    child: EnergyGlossAction(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (beforePrice != null) ...[
                                    Text(
                                      beforePrice,
                                      semanticsLabel: _tr(
                                        context,
                                        'По цене базового пакета: $beforePrice',
                                        'At the base package rate: $beforePrice',
                                      ),
                                      key: ValueKey('energy-before-${p.id}'),
                                      style: const TextStyle(
                                        color: GameUi.muted,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                        height: 1,
                                        decoration: TextDecoration.lineThrough,
                                        decorationColor: GameUi.muted,
                                        decorationThickness: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    product?.price ??
                                        _tr(
                                          context,
                                          'Недоступно',
                                          'Unavailable',
                                        ),
                                    key: ValueKey(
                                      'energy-current-price-${p.id}',
                                    ),
                                    style: const TextStyle(
                                      color: GameUi.text,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            _PackBattery(
                              ratio: (p.amount / maxAmount).clamp(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _tr(context, 'Покупка энергии', 'Buy energy'),
          style: const TextStyle(color: GameUi.muted, fontSize: 12),
        ),
        const SizedBox(height: 9),
        Expanded(
          child: Row(
            children: [
              Expanded(child: pack(0)),
              const SizedBox(width: 10),
              Expanded(child: pack(1)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(child: pack(2)),
              const SizedBox(width: 10),
              Expanded(child: pack(3)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _tr(
            context,
            'Бесплатная энергия — в соседних вкладках.',
            'Free energy is available in the other tabs.',
          ),
          style: const TextStyle(color: GameUi.muted, fontSize: 10),
        ),
        const EnergyBillingStatus(),
      ],
    );
  }
}

class _PackBattery extends StatelessWidget {
  const _PackBattery({required this.ratio});
  final double ratio;
  @override
  Widget build(BuildContext c) => SizedBox(
    width: 89,
    height: 10,
    child: Row(
      children: [
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFD4F8FF),
              border: Border.all(color: GameUi.ink),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [energyCore, energyNeon, Color(0xFFC4A21D)],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(
                    10,
                    (_) => Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Color(0x55082E4C),
                              width: .7,
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
        ),
        Container(width: 3, height: 5, color: GameUi.ink),
      ],
    ),
  );
}

/// Its reserved height is constant for idle, pending, success and errors.
Future<void> _energyDialog(
  BuildContext context,
  String title,
  WidgetBuilder body, {
  String? key,
}) => showDialog<void>(
  context: context,
  useRootNavigator: false,
  barrierColor: GameUi.modalBarrier,
  animationStyle: GameUi.windowAnimationStyle,
  builder: (context) => Dialog(
    key: key == null ? null : ValueKey(key),
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: key == 'energy-helmet-dialog' || key == 'energy-jump-dialog'
            ? 310
            : 390,
      ),
      child: GameSheetChrome(
        key: const ValueKey('energy-modal-surface'),
        modal: true,
        fitContent: true,
        backgroundGradient: GameUi.navySheetGradient,
        glass: GameGlass.none,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EnergyDesignHeader(
                title: title,
                edgeToEdge: true,
                balance:
                    key == 'energy-helmet-dialog' || key == 'energy-jump-dialog'
                    ? null
                    : context.watch<EconomyStore>().energy,
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: body(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

Future<void> showLegacyEnergyAbilitySheet(
  BuildContext context, {
  required bool helmet,
}) => _energyDialog(
  context,
  _tr(context, helmet ? 'Шлем' : 'Прыжок', helmet ? 'Helmet' : 'Jump'),
  (context) => _AbilityContent(helmet: helmet),
  key: helmet ? 'energy-helmet-dialog' : 'energy-jump-dialog',
);

class _EnergyAbilityArt extends StatelessWidget {
  const _EnergyAbilityArt({required this.helmet});
  final bool helmet;
  @override
  Widget build(BuildContext c) => Container(
    height: 78,
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF153F58), Color(0xFF0D2A40)],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _outline),
    ),
    child: LayoutBuilder(
      builder: (c, b) => Stack(
        children: [
          Positioned(
            left: 10,
            right: 10,
            bottom: 14,
            child: Container(height: 1, color: const Color(0x553B7C90)),
          ),
          if (helmet)
            Positioned(
              top: 5,
              left: b.maxWidth / 2 - 32,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFAAF7F3),
                    width: 1.5,
                  ),
                  gradient: const RadialGradient(
                    colors: [Color(0x5543ECC0), Color(0x1143ECC0)],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x6679F1F5), blurRadius: 12),
                  ],
                ),
              ),
            ),
          if (!helmet) ...[
            Positioned(
              left: b.maxWidth / 2 - 48,
              top: 10,
              child: const Text(
                '↑',
                style: TextStyle(color: Color(0xFF65D4C4), fontSize: 35),
              ),
            ),
            Positioned(
              left: b.maxWidth / 2 + 24,
              bottom: 15,
              child: Container(
                width: 23,
                height: 11,
                decoration: BoxDecoration(
                  color: GameUi.heart,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Positioned(
              left: b.maxWidth / 2 - 9,
              top: 42,
              child: Transform.rotate(
                angle: .22,
                child: Text(
                  '╎    ╎',
                  style: TextStyle(
                    color: GameUi.mint.withValues(alpha: .5),
                    fontSize: 23,
                  ),
                ),
              ),
            ),
          ],
          Positioned(
            top: helmet ? 22 : 4,
            left: b.maxWidth / 2 - 22,
            child: Transform.rotate(
              angle: helmet ? 0 : -.10,
              child: const GameArtwork(GameArt.ready, size: 46),
            ),
          ),
          if (helmet)
            Positioned(
              top: 4,
              left: b.maxWidth / 2 - 19,
              child: Image.asset(
                'assets/branding/ui/ability-helmet.png',
                width: 38,
                height: 35,
                fit: BoxFit.contain,
              ),
            ),
          Positioned(
            right: 7,
            bottom: 3,
            child: Text(
              _tr(
                c,
                helmet ? 'Защитный барьер' : 'Неуязвимость в прыжке',
                helmet ? 'Protective barrier' : 'Invulnerable while jumping',
              ),
              style: const TextStyle(color: GameUi.muted, fontSize: 9),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AbilityContent extends StatelessWidget {
  const _AbilityContent({required this.helmet});
  final bool helmet;
  @override
  Widget build(BuildContext c) {
    final e = c.watch<EconomyStore>();
    final enabled = helmet ? e.helmetSelected : e.jumpSelected;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EnergyAbilityArt(helmet: helmet),
        const SizedBox(height: 9),
        Text(
          _tr(
            c,
            helmet
                ? 'Барьер защитит кубик от одного удара. После первого удара защита исчезнет до следующей попытки.'
                : 'Удерживайте один палец для управления. Коснитесь экрана вторым пальцем — кубик подпрыгнет и перепрыгнет врагов.',
            helmet
                ? 'A barrier protects your cube from one hit. It breaks on impact and returns next run.'
                : 'Keep one finger down to move. Touch the screen with a second finger to jump over enemies.',
          ),
          style: const TextStyle(color: GameUi.text, fontSize: 14, height: 1.4),
        ),
        if (!helmet) ...[
          const SizedBox(height: 7),
          Text(
            _tr(
              c,
              'Это второе одновременное касание, а не двойной тап. Опасные стены по-прежнему опасны.',
              'Use a simultaneous second touch, not a double tap. Dangerous walls remain dangerous.',
            ),
            style: const TextStyle(
              color: GameUi.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr(
                        c,
                        enabled ? 'Включено' : 'Выключено',
                        enabled ? 'Enabled' : 'Disabled',
                      ),
                      style: const TextStyle(
                        color: GameUi.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          EnergyText(
                            helmet
                                ? e.energyConfig.helmetExtraCost
                                : e.energyConfig.jumpExtraCost,
                            prefix: '+',
                            size: 17,
                          ),
                          Text(
                            _tr(c, ' за попытку', ' per run'),
                            style: const TextStyle(
                              color: GameUi.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: ValueKey(
                  helmet ? 'energy-helmet-switch' : 'energy-jump-switch',
                ),
                value: enabled,
                activeThumbColor: GameUi.mint,
                onChanged: (v) =>
                    helmet ? e.setHelmetSelected(v) : e.setJumpSelected(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _tr(
            c,
            'Сейчас попытка стоит ${e.attemptEnergyCost} энергии',
            'A run now costs ${e.attemptEnergyCost} energy',
          ),
          style: const TextStyle(color: GameUi.muted, fontSize: 12),
        ),
      ],
    );
  }
}

Future<void> showEnergyAchievementsSheet(BuildContext context) => _energyDialog(
  context,
  _tr(context, 'Достижения', 'Achievements'),
  (context) => const _AchievementsContent(),
  key: 'energy-achievements-dialog',
);

class _AchievementsContent extends StatelessWidget {
  const _AchievementsContent();
  @override
  Widget build(BuildContext c) {
    final e = c.watch<EconomyStore>();
    const ids = ['survive_10s', 'record_20s', 'risks_5'];
    final titles = [
      _tr(
        c,
        'Продержаться ${e.config.earnSurviveSeconds} секунд',
        'Survive for ${e.config.earnSurviveSeconds} seconds',
      ),
      _tr(
        c,
        'Рекорд ${e.config.earnRecordSeconds} секунд',
        'Reach a ${e.config.earnRecordSeconds} second record',
      ),
      _tr(
        c,
        'Собрать ${e.config.earnRisksInRun} рисков за игру',
        'Take ${e.config.earnRisksInRun} risks in one run',
      ),
    ];
    final targets = [
      e.config.earnSurviveSeconds,
      e.config.earnRecordSeconds,
      e.config.earnRisksInRun,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _tr(
            c,
            'Играйте и забирайте энергию за достижения.',
            'Play and collect energy for achievements.',
          ),
          style: const TextStyle(color: GameUi.muted, fontSize: 12),
        ),
        for (var i = 0; i < ids.length; i++)
          Builder(
            builder: (c) {
              final done = e.energyRewardClaimed(ids[i]);
              final ready = e.energyRewardReady(ids[i]);
              final value = done || ready
                  ? targets[i]
                  : (i < 2
                        ? (e.bestTimeMs / 1000).floor().clamp(0, targets[i])
                        : 0);
              return Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF153F58), Color(0xFF0D2A40)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _outline),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titles[i],
                            style: const TextStyle(
                              color: GameUi.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (done)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: GameUi.mint,
                          )
                        else
                          OutlinedButton(
                            key: ValueKey('energy-achievement-${ids[i]}'),
                            style: energyButtonStyle(),
                            onPressed: ready
                                ? () => _guard(
                                    c,
                                    () => e.claimEnergyReward(ids[i]),
                                  )
                                : null,
                            child: EnergyText(
                              e.energyConfig.reward(ids[i]),
                              prefix: '+',
                              size: 17,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: targets[i] > 0 ? value / targets[i] : 0,
                        color: GameUi.mint,
                        backgroundColor: GameUi.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        done
                            ? _tr(c, 'Получено', 'Collected')
                            : ready
                            ? _tr(c, 'Награда готова', 'Reward ready')
                            : i < 2
                            ? '$value / ${targets[i]} ${_tr(c, 'сек', 'sec')}'
                            : _tr(
                                c,
                                'Цель — ${targets[i]} за одну попытку',
                                'Target — ${targets[i]} in one run',
                              ),
                        style: const TextStyle(
                          color: GameUi.muted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 10),
        Text(
          _tr(
            c,
            'Каждое достижение приносит ${e.energyConfig.reward('achievement')} энергии. Готовую награду можно забрать здесь.',
            'Each achievement grants ${e.energyConfig.reward('achievement')} energy. Collect completed rewards here.',
          ),
          style: const TextStyle(
            color: GameUi.muted,
            fontSize: 11,
            height: 1.35,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(
            _tr(c, '← К заданиям', '← Back to tasks'),
            style: const TextStyle(color: GameUi.cyan, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

Future<void> showEnergyFeedbackSheet(BuildContext context) => _energyDialog(
  context,
  _tr(context, 'Обратная связь', 'Feedback'),
  (context) => const EnergyFeedbackForm(),
  key: 'energy-feedback-dialog',
);

Future<void> showLegacyEnergySubscriptionSheet(BuildContext context) =>
    _energyDialog(
      context,
      _tr(context, 'Батарейки', 'Batteries'),
      (context) => const _SubscriptionContent(),
      key: 'energy-subscription-dialog',
    );

class _SubscriptionContent extends StatelessWidget {
  const _SubscriptionContent();
  @override
  Widget build(BuildContext c) {
    final e = c.watch<EconomyStore>();
    final b = c.watch<PlayBillingService?>();
    final current = e.energyBatteries.length;
    Widget option(dynamic offer) {
      final chosen = current == offer.totalBatteries;
      final product = b?.energyOfferPrice(offer.id);
      final price = product?.price ?? _tr(c, 'Недоступно', 'Unavailable');
      final unit = product == null
          ? null
          : NumberFormat.currency(
              locale: Localizations.localeOf(c).toString(),
              name: product.currencyCode,
              symbol: product.currencySymbol,
              decimalDigits: product.rawPrice % offer.additionalBatteries == 0
                  ? 0
                  : 2,
            ).format(product.rawPrice / offer.additionalBatteries);
      final discount = b?.batteryDiscount(offer.id, e.energyConfig);
      final daily =
          (e.energyConfig.batteryCapacity * 24 / e.energyConfig.chargeHours +
                  offer.additionalBatteries *
                      offer.batteryCapacity *
                      24 /
                      offer.chargeHours)
              .floor();
      final capacity =
          (e.energyConfig.batteryCapacity *
                      offer.chargeHours /
                      e.energyConfig.chargeHours +
                  offer.additionalBatteries * offer.batteryCapacity)
              .floor();
      return Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: offer.additionalBatteries == 4
                ? energyNeon
                : chosen
                ? GameUi.mint
                : _outline,
            width: 1.3,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: offer.additionalBatteries == 4
                ? const [Color(0xFF1F485D), Color(0xFF102F47)]
                : const [Color(0xFF153F58), Color(0xFF0D2A40)],
          ),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+${offer.additionalBatteries}',
                    style: const TextStyle(
                      color: Color(0xFFFFDC86),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Icon(
                    Icons.battery_full_outlined,
                    color: Color(0xFFFFDC86),
                    size: 25,
                  ),
                  Text(
                    ' = $price',
                    style: const TextStyle(
                      color: Color(0xFFFFDC86),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _tr(
                  c,
                  'на ${offer.periodDays} дней${unit == null ? '' : ' · $unit за один'}',
                  'for ${offer.periodDays} days${unit == null ? '' : ' · $unit each'}',
                ),
                style: const TextStyle(color: GameUi.muted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 28,
              child: Row(
                children: List.generate(
                  5,
                  (i) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: i < offer.totalBatteries
                              ? (i < current
                                    ? GameUi.mint
                                    : const Color(0xFFFFDC86))
                              : _outline.withValues(alpha: .45),
                        ),
                        color: const Color(0xFF123448),
                      ),
                      child: Stack(
                        children: [
                          if (i < offer.totalBatteries)
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: .7,
                                widthFactor: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: i < current
                                          ? const [
                                              Color(0xFFA5FFE5),
                                              Color(0xFF25C9A5),
                                            ]
                                          : const [
                                              Color(0xFFFFE7B0),
                                              Color(0xFFE2BD60),
                                            ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Center(
                            child: Text(
                              i < offer.totalBatteries
                                  ? (i < current ? '✓' : '+')
                                  : '',
                              style: const TextStyle(
                                color: GameUi.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                _tr(
                  c,
                  'Всего ${offer.totalBatteries} батарейки',
                  '${offer.totalBatteries} batteries total',
                ),
                style: const TextStyle(
                  color: GameUi.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 30,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  discount == null
                      ? _tr(c, 'Базовый вариант', 'Standard option')
                      : _tr(c, 'Выгода $discount%', 'Save $discount%'),
                  style: TextStyle(
                    color: discount == null ? GameUi.muted : GameUi.mint,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (current == 2 && offer.totalBatteries == 5)
              Text(
                _tr(c, 'Добавятся ещё 3', 'Adds 3 more'),
                style: const TextStyle(color: Color(0xFFFFDC86), fontSize: 10),
              ),
            const SizedBox(height: 12),
            FittedBox(child: EnergyText(capacity, size: 31)),
            const SizedBox(height: 4),
            Text(
              _tr(
                c,
                'за ${offer.chargeHours.toStringAsFixed(0)} часов',
                'per ${offer.chargeHours.toStringAsFixed(0)} hours',
              ),
              style: const TextStyle(color: GameUi.muted, fontSize: 11),
            ),
            const SizedBox(height: 9),
            Container(
              height: 38,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF0B2538),
                border: Border.all(color: const Color(0xFFFFE24D)),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Color(0x45E8C82E), blurRadius: 12),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _tr(c, 'до $daily за сутки', 'up to $daily per day'),
                  style: const TextStyle(
                    color: energyNeon,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    shadows: [Shadow(color: Color(0x99FFE02F), blurRadius: 7)],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _tr(c, 'Без рекламы', 'No ads'),
              style: const TextStyle(color: GameUi.muted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey(
                    'energy-subscribe-${offer.additionalBatteries}',
                  ),
                  borderRadius: BorderRadius.circular(9),
                  onTap:
                      b?.busy != true &&
                          !chosen &&
                          (testServicePreviewActive(c) ||
                              (b?.available == true && product != null))
                      ? () => _confirmEnergyPurchase(
                          c,
                          offer.id,
                          subscription: true,
                        )
                      : null,
                  child: chosen
                      ? Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: _outline),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            _tr(c, 'Ваш вариант', 'Current plan'),
                            style: const TextStyle(
                              color: GameUi.muted,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : EnergyGlossAction(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _tr(c, '$price / неделю', '$price / week'),
                              style: const TextStyle(
                                color: GameUi.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
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

    final offers = e.energyConfig.subscriptions;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _tr(
            c,
            '●  Сейчас работает $current из 5',
            '●  $current of 5 connected',
          ),
          style: const TextStyle(color: GameUi.mint, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          _tr(
            c,
            'Подключите дополнительные батарейки',
            'Connect additional batteries',
          ),
          style: const TextStyle(color: GameUi.muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (c, bounds) => bounds.maxWidth < 250
              ? Column(
                  children: [
                    for (final offer in offers) ...[
                      option(offer),
                      const SizedBox(height: 10),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < offers.length; i++) ...[
                      if (i > 0) const SizedBox(width: 9),
                      Expanded(child: option(offers[i])),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Text(
          _tr(
            c,
            'Один вариант на выбор. Суточный максимум — при сборе после каждого полного заряда. Полный заряд ждёт сбора. Новые батарейки начинают с нуля.',
            'Choose one plan. Daily maximum requires collecting after every full charge. Full batteries wait for collection. New batteries start empty.',
          ),
          style: const TextStyle(
            color: GameUi.muted,
            fontSize: 10,
            height: 1.4,
          ),
        ),
        const Divider(height: 23, color: _outline),
        Text(
          _tr(c, 'Подписка на 7 дней', '7-day subscription'),
          style: const TextStyle(
            color: GameUi.text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _tr(
            c,
            'Продлевается автоматически в Google Play каждую неделю. Отмена — в подписках Google Play до следующего продления. Доступ остаётся до конца оплаченного периода.',
            'Renews automatically in Google Play every week. Cancel in Google Play subscriptions before renewal. Access remains until the paid period ends.',
          ),
          style: const TextStyle(
            color: GameUi.muted,
            fontSize: 10,
            height: 1.4,
          ),
        ),
        const EnergyBillingStatus(),
        TextButton(
          onPressed: () => manageGoogleSubscription(c),
          child: Text(
            _tr(c, 'Управлять в Google Play', 'Manage in Google Play'),
            style: const TextStyle(color: GameUi.cyan, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _EnergyReceiptRow extends StatelessWidget {
  const _EnergyReceiptRow(this.label, this.value, {this.energy = false});
  final String label, value;
  final bool energy;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _outline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: GameUi.muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: energy ? energyNeon : GameUi.text,
              shadows: energy
                  ? const [Shadow(color: Color(0x88FFE02F), blurRadius: 7)]
                  : null,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> showEnergyPurchaseSheet(BuildContext c, String id, int amount) =>
    _confirmEnergyPurchase(c, id, amount: amount);
Future<void> _confirmEnergyPurchase(
  BuildContext c,
  String id, {
  bool subscription = false,
  int? amount,
}) {
  if (testServicePreviewActive(c)) {
    return showTestServiceUnavailable(
      c,
      productId: subscription ? null : id,
      amount: subscription ? null : amount,
    );
  }
  return runResourceAction(
    c,
    c.read<PlayBillingService?>() ?? c.read<EconomyStore>(),
    'billing',
    () => _performEnergyPurchase(
      c,
      id,
      subscription: subscription,
      amount: amount,
    ),
  );
}

Future<void> _performEnergyPurchase(
  BuildContext c,
  String id, {
  bool subscription = false,
  int? amount,
}) async {
  if (testServicePreviewActive(c)) {
    await showTestServiceUnavailable(
      c,
      productId: subscription ? null : id,
      amount: subscription ? null : amount,
    );
    return;
  }
  final billing = c.read<PlayBillingService?>();
  final price = billing?.price(id);
  if (billing == null || price == null || !billing.available || billing.busy) {
    return;
  }
  if (!billing.account.googleLinked) {
    await showEnergyPurchaseRecovery(c, billing);
    return;
  }
  final owner = billing.account.id;
  final e = c.read<EconomyStore>();
  final offer = e.energyConfig.subscriptions
      .where((o) => o.id == id)
      .firstOrNull;
  final current = e.energyBatteries.length;
  final target = offer?.totalBatteries ?? current;
  final period = offer?.periodDays ?? 7;
  final upgrade = subscription && current > 1 && target > current;
  final downgrade = subscription && target < current;
  final terms = !subscription
      ? _tr(
          c,
          '$amount энергии за $price. Разовая покупка.',
          '$amount energy for $price. One-time purchase.',
        )
      : upgrade
      ? _tr(
          c,
          'Новый тариф: $price каждые $period дней. Батарейки подключатся после подтверждения Google. Google рассчитает доплату с учётом оставшегося периода и покажет сумму и дату следующего списания. Текущий заряд сохранится; новые батарейки начнут с нуля.',
          'New plan: $price every $period days. Batteries connect after Google confirms. Google calculates the prorated charge and shows the amount and next billing date. Existing charge stays; new batteries start empty.',
        )
      : downgrade
      ? _tr(
          c,
          'Новый тариф: $price каждые $period дней. Переход на $target батарейки — со следующего оплаченного периода. До этого работают все $current. При отключении их остаток заряда сохранится на балансе.',
          'New plan: $price every $period days. The change to $target batteries starts next billing period. All $current stay active until then. Charge left in disconnected batteries moves to your balance.',
        )
      : _tr(
          c,
          '$price каждые $period дней. Подписка автоматически продлевается до отмены в Google Play. Новые батарейки начинают с нуля.',
          '$price every $period days. The subscription renews automatically until cancelled in Google Play. New batteries start empty.',
        );
  final confirmed = await showDialog<bool>(
    context: c,
    useRootNavigator: false,
    builder: (c) => Dialog(
      key: const ValueKey('energy-purchase-confirm'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: GameSheetChrome(
          key: const ValueKey('energy-modal-surface'),
          modal: true,
          fitContent: true,
          backgroundGradient: GameUi.navySheetGradient,
          glass: GameGlass.none,
          child: Padding(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EnergyDesignHeader(
                  edgeToEdge: true,
                  title: _tr(
                    c,
                    subscription ? 'Подключение' : 'Покупка энергии',
                    subscription ? 'Connection' : 'Buy energy',
                  ),
                  balance: c.watch<EconomyStore>().energy,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF123B44),
                              border: Border.all(color: GameUi.mint, width: 2),
                            ),
                            child: Icon(
                              subscription
                                  ? Icons.battery_charging_full_rounded
                                  : Icons.bolt_rounded,
                              color: energyNeon,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _tr(
                              c,
                              subscription
                                  ? 'Подключить батарейки'
                                  : 'Пополнить энергию',
                              subscription ? 'Connect batteries' : 'Add energy',
                            ),
                            style: const TextStyle(
                              color: GameUi.text,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!subscription)
                            EnergyText(amount ?? 0, prefix: '+', size: 34),
                          if (!subscription)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: GameUi.ink,
                                  border: Border.all(color: _outline),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _tr(c, 'Стоимость', 'Price'),
                                        style: const TextStyle(
                                          color: GameUi.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      price,
                                      style: const TextStyle(
                                        color: GameUi.text,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (subscription && offer != null) ...[
                            SizedBox(
                              height: 30,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  5,
                                  (i) => Container(
                                    width: 22,
                                    height: 28,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: i < target
                                            ? GameUi.mint
                                            : _outline,
                                      ),
                                      color: i < target
                                          ? GameUi.mint.withValues(alpha: .35)
                                          : GameUi.ink,
                                    ),
                                    child: Text(
                                      i < target
                                          ? (i < current ? '✓' : '+')
                                          : '',
                                      style: const TextStyle(
                                        color: GameUi.text,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _tr(
                                c,
                                'Всего $target батарейки',
                                'Total: $target batteries',
                              ),
                              style: const TextStyle(
                                color: GameUi.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _EnergyReceiptRow(
                              _tr(
                                c,
                                'За ${offer.chargeHours.toStringAsFixed(0)} часов',
                                'Per ${offer.chargeHours.toStringAsFixed(0)} hours',
                              ),
                              '${(e.energyConfig.batteryCapacity * offer.chargeHours / e.energyConfig.chargeHours + offer.additionalBatteries * offer.batteryCapacity).floor()} ⚡',
                              energy: true,
                            ),
                            _EnergyReceiptRow(
                              _tr(c, 'За сутки — до', 'Per day — up to'),
                              '${(e.energyConfig.batteryCapacity * 24 / e.energyConfig.chargeHours + offer.additionalBatteries * offer.batteryCapacity * 24 / offer.chargeHours).floor()} ⚡',
                              energy: true,
                            ),
                            _EnergyReceiptRow(
                              _tr(c, 'Реклама', 'Ads'),
                              _tr(c, 'Отключена', 'Disabled'),
                            ),
                            _EnergyReceiptRow(
                              _tr(c, 'Стоимость', 'Price'),
                              '$price / $period ${_tr(c, 'дней', 'days')}',
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            terms,
                            key: const ValueKey('energy-purchase-terms'),
                            style: const TextStyle(
                              color: GameUi.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: energyButtonStyle(),
                                  onPressed: () => Navigator.pop(c, false),
                                  child: Text(
                                    _tr(c, 'Отмена', 'Cancel'),
                                    style: const TextStyle(color: GameUi.text),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => Navigator.pop(c, true),
                                      borderRadius: BorderRadius.circular(9),
                                      child: EnergyGlossAction(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            _tr(c, 'Продолжить', 'Continue'),
                                            style: const TextStyle(
                                              color: GameUi.text,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (confirmed != true || !c.mounted || billing.account.id != owner) return;
  try {
    await billing.buy(id);
  } on MobileApiError catch (error) {
    if (!c.mounted || billing.account.id != owner) return;
    if (error.code == 'purchase_requires_recovery') {
      await showEnergyPurchaseRecovery(c, billing);
      return;
    }
    final text =
        error.code == 'rules_changed' || error.code == 'play_quote_expired'
        ? _tr(
            c,
            'Условия обновились. Откройте покупку ещё раз.',
            'The offer changed. Open the purchase again.',
          )
        : _tr(
            c,
            'Google Play не завершил покупку. Проверьте её состояние ниже или восстановите покупки.',
            'Google Play did not complete the purchase. Check its status below or restore purchases.',
          );
    ScaffoldMessenger.maybeOf(c)?.showSnackBar(SnackBar(content: Text(text)));
  } catch (_) {
    if (c.mounted && billing.account.id == owner) {
      ScaffoldMessenger.maybeOf(c)?.showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              c,
              'Покупка не подтверждена. Используйте «Восстановить».',
              'Purchase not confirmed. Use Restore.',
            ),
          ),
        ),
      );
    }
  }
}

Future<void> _showEnergyFriendsHelp(
  BuildContext c,
  int reward,
) => showDialog<void>(
  context: c,
  useRootNavigator: false,
  barrierColor: GameUi.modalBarrier,
  builder: (c) => Dialog(
    key: const ValueKey('energy-friends-help'),
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    insetPadding: const EdgeInsets.all(24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        key: const ValueKey('energy-modal-surface'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: GameUi.cyan),
          gradient: GameUi.navySheetGradient,
          boxShadow: const [
            BoxShadow(color: Color(0x88000000), blurRadius: 30),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _tr(c, 'Как пригласить друга', 'How to invite a friend'),
              style: const TextStyle(
                color: GameUi.mint,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _tr(
                c,
                'Отправьте другу ссылку или код. Друг вводит код один раз в своём аккаунте.',
                'Share your link or code. Your friend enters the code once in their account.',
              ),
              style: const TextStyle(
                color: GameUi.text,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                EnergyText(reward, prefix: '+', size: 25),
                const SizedBox(width: 5),
                Text(
                  _tr(c, 'каждому', 'each'),
                  style: const TextStyle(
                    color: energyNeon,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _tr(
                c,
                'После 5 завершённых игр друга. У обоих должен быть подключён Google. Само нажатие «Поделиться» не даёт награду.',
                'After your friend completes 5 games. Both players must connect Google. Sharing alone does not grant a reward.',
              ),
              style: const TextStyle(
                color: GameUi.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(c),
                  borderRadius: BorderRadius.circular(9),
                  child: EnergyGlossAction(
                    child: Text(
                      _tr(c, 'Понятно', 'Got it'),
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
      ),
    ),
  ),
);

class _EnergyFriendsPane extends StatefulWidget {
  const _EnergyFriendsPane({required this.visible});
  final bool visible;
  @override
  State<_EnergyFriendsPane> createState() => _EnergyFriendsPaneState();
}

class _EnergyFriendsPaneState extends State<_EnergyFriendsPane> {
  bool _requested = false, _busy = false;
  String? _error;
  final _share = GlobalKey();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant _EnergyFriendsPane old) {
    super.didUpdateWidget(old);
    _load();
  }

  void _load() {
    if (!widget.visible || _requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = context.read<MobileInvites?>();
      if (service?.enabled == true) {
        try {
          await service!.refresh();
        } catch (_) {
          if (mounted) {
            setState(
              () => _error = _tr(
                context,
                'Нет соединения. Повторите.',
                'Offline. Please retry.',
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _tr(
            context,
            'Не удалось выполнить действие',
            'Could not complete this action',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final service = c.watch<MobileInvites?>();
    final state = service?.state;
    final valid = state != null && state.profileId == service?.account.id;
    final e = c.watch<EconomyStore>();
    final reward = e.energyConfig.rewards['invite'] ?? 20;
    Widget copy(
      String label,
      String? value,
      String key, {
      bool share = false,
    }) => Row(
      children: [
        Text(label, style: const TextStyle(color: GameUi.muted, fontSize: 10)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            key: ValueKey('energy-invite-$key'),
            style: TextStyle(
              color: GameUi.text,
              fontWeight: FontWeight.w700,
              fontSize: share ? 10 : 13,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            key: ValueKey('energy-copy-$key'),
            tooltip: _tr(c, 'Копировать', 'Copy'),
            onPressed: valid && !_busy
                ? () =>
                      _act(() => Clipboard.setData(ClipboardData(text: value!)))
                : null,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
            ),
            icon: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: _outline),
                borderRadius: BorderRadius.circular(8),
                color: GameUi.ink,
              ),
              child: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: GameUi.cyan,
              ),
            ),
          ),
        ),
        if (share)
          SizedBox(
            width: 65,
            child: TextButton(
              key: _share,
              onPressed: valid && !_busy
                  ? () => _act(() async {
                      final owner = service!.account.id;
                      if (state.profileId != owner) return;
                      final box =
                          _share.currentContext?.findRenderObject()
                              as RenderBox?;
                      await SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Untouch\n${state.inviteUrl}\n${_tr(c, 'Код', 'Code')}: ${state.ownCode}',
                          sharePositionOrigin: box == null
                              ? const Rect.fromLTWH(0, 0, 48, 48)
                              : box.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    })
                  : null,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: SizedBox(
                height: 30,
                child: EnergyGlossAction(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _tr(c, 'Поделиться', 'Share'),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: GameUi.text,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _tr(c, 'Мои приглашения', 'My invitations'),
                style: const TextStyle(
                  color: GameUi.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            EnergyText(reward, prefix: '+', size: 18),
            IconButton(
              key: const ValueKey('energy-friends-info'),
              tooltip: _tr(c, 'Как это работает', 'How it works'),
              onPressed: () => _showEnergyFriendsHelp(c, reward),
              icon: const Text(
                'i',
                style: TextStyle(
                  color: GameUi.cyan,
                  fontStyle: FontStyle.italic,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        Container(
          key: const ValueKey('energy-friends-fixed'),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF102E45),
            border: Border.all(color: _outline),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              copy(_tr(c, 'Код', 'Code'), valid ? state.ownCode : null, 'code'),
              const Divider(height: 1, color: _outline),
              copy(
                _tr(c, 'Ссылка', 'Link'),
                valid ? state.inviteUrl : null,
                'link',
                share: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Expanded(
          child: Container(
            key: const ValueKey('energy-friends-history'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              border: Border.all(color: _outline),
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF153F58), Color(0xFF0D2A40)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const ValueKey('energy-friends-history-head'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF123E58),
                    border: Border(bottom: BorderSide(color: _outline)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tr(c, 'Начисленные бонусы', 'Earned bonuses'),
                          style: const TextStyle(
                            color: GameUi.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      EnergyText(valid ? state.energyRewardTotal : 0, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: GameUi.heart, fontSize: 10),
                  ),
                Expanded(
                  child: !valid
                      ? Center(
                          child: TextButton(
                            onPressed: () => _act(
                              () => service?.refresh() ?? Future.value(),
                            ),
                            child: Text(
                              _tr(
                                c,
                                'Обновить приглашения',
                                'Refresh invitations',
                              ),
                              style: const TextStyle(
                                color: GameUi.cyan,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      : state.paidRows.isEmpty
                      ? Center(
                          child: Text(
                            _tr(
                              c,
                              'Здесь появятся приглашённые друзья',
                              'Your invited friends will appear here',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: GameUi.muted,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ListView.builder(
                          key: const ValueKey('energy-friends-list'),
                          padding: EdgeInsets.zero,
                          itemCount:
                              state.paidRows.length +
                              (state.nextCursor != null ? 1 : 0),
                          itemBuilder: (c, i) {
                            if (i == state.paidRows.length) {
                              return TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _act(() => service!.loadMore()),
                                child: Text(
                                  _tr(c, 'Показать ещё', 'Show more'),
                                ),
                              );
                            }
                            final row = state.paidRows[i];
                            return Container(
                              key: ValueKey('energy-friend-${row.id}'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: _outline),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.account_circle_rounded,
                                    color: GameUi.cyan,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      row.nickname ??
                                          _tr(
                                            c,
                                            'Игрок удалён',
                                            'Deleted player',
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: GameUi.text,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  EnergyText(
                                    row.energyEquivalent,
                                    prefix: '+',
                                    size: 15,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Contract 3 is the application surface. Legacy widgets above are retained for
// old-contract regression probes; no live navigation opens their tabbed window.
