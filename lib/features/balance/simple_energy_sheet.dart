import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../data/economy_store.dart';
import '../../data/ads_service.dart';
import '../../data/mobile_account.dart';
import '../../data/mobile_invites.dart';
import '../../data/play_billing_service.dart';
import '../../ui/billing_unavailable.dart';
import '../../ui/energy_reward_motion.dart';
import '../../ui/energy_widgets.dart';
import '../../ui/game_ui.dart';
import '../../ui/neon_chrome.dart';
export '../../ui/neon_chrome.dart' show NeonGlass;
import '../../ui/watch_rewarded_ad.dart';
import 'energy_services.dart'
    show EnergyBillingStatus, buySimpleEnergy, EnergyFeedbackForm;

const _cyan = Color(0xFF54E9FF);
const _muted = Color(0xFFA5CAE8);
String _tr(BuildContext c, String ru, String en) =>
    Localizations.localeOf(c).languageCode == 'ru' ? ru : en;
String bonusTime(Duration duration) {
  final seconds = (duration.inMilliseconds / 1000).ceil();
  return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

enum EnergyPage {
  energy,
  subscription,
  video,
  friends,
  feedback,
  packs,
  helmet,
  jump,
}

Future<void> showSimpleEnergyWindow(
  BuildContext context, {
  EnergyPage page = EnergyPage.energy,
}) => showDialog<void>(
  context: context,
  useRootNavigator: false,
  barrierColor: GameUi.modalBarrier,
  animationStyle: GameUi.windowAnimationStyle,
  builder: (_) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
    child: SimpleEnergyWindow(initialPage: page),
  ),
);

/// One route owns E01 and its children. Back returns to E01, never opens another
/// copy of it. All amounts are live server data; artwork contains no controls.
class SimpleEnergyWindow extends StatefulWidget {
  const SimpleEnergyWindow({super.key, this.initialPage = EnergyPage.energy});
  final EnergyPage initialPage;
  @override
  State<SimpleEnergyWindow> createState() => _SimpleEnergyWindowState();
}

class _SimpleEnergyWindowState extends State<SimpleEnergyWindow> {
  final _celebration = GlobalKey<EnergyRewardMotionState>();
  final _bonusOrigin = GlobalKey();
  late EnergyPage _page;
  Timer? _clock;
  Timer? _hiddenTapReset;
  int _hiddenTaps = 0;
  bool _busy = false, _friendsRequested = false;
  String? _error;
  String? _selectedSku;
  bool get _ability => _page == EnergyPage.helmet || _page == EnergyPage.jump;
  bool get _standalone => widget.initialPage != EnergyPage.energy;
  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _hiddenTapReset?.cancel();
    super.dispose();
  }

  void _back() {
    _celebration.currentState?.cancel();
    _resetHiddenTaps();
    if (_page == EnergyPage.energy || _standalone) {
      Navigator.pop(context);
    } else {
      setState(() {
        _page = EnergyPage.energy;
        _error = null;
      });
    }
  }

  void _open(EnergyPage page) {
    _resetHiddenTaps();
    if (_busy) return;
    _celebration.currentState?.cancel();
    setState(() {
      _page = page;
      _error = null;
    });
    if (page == EnergyPage.friends && !_friendsRequested) {
      _friendsRequested = true;
      final service = context.read<MobileInvites?>();
      if (service != null) unawaited(_act(service.refresh));
    }
  }

  void _resetHiddenTaps() {
    _hiddenTaps = 0;
    _hiddenTapReset?.cancel();
  }

  Future<void> _hiddenEnergyTap() async {
    if (_page != EnergyPage.energy || _busy) return;
    _hiddenTapReset?.cancel();
    if (++_hiddenTaps < 5) {
      _hiddenTapReset = Timer(
        const Duration(milliseconds: 1500),
        _resetHiddenTaps,
      );
      return;
    }
    _resetHiddenTaps();
    await _act(() async {
      await context.read<EconomyStore>().claimHiddenEnergy();
    });
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy || (_celebration.currentState?.isActive ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _tr(
            context,
            'Не удалось подтвердить. Проверьте связь и повторите.',
            'Could not confirm. Check your connection and retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claimBonus(EconomyStore e) => _act(e.claimSimpleEnergyBonus);

  Future<void> _watchVideo(EconomyStore e) => _act(
    () => watchRewardedAd(
      context,
      // The shared confirmed-wallet observer presents the reward exactly once.
      onReward: (_) async {},
    ),
  );

  Widget _text(
    String text, {
    double size = 14,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w500,
    TextAlign align = TextAlign.left,
  }) => Text(
    text,
    textAlign: align,
    style: TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: 1.22,
    ),
  );
  Widget _line() => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(vertical: 9),
    color: _cyan.withValues(alpha: .46),
  );
  String get _title => switch (_page) {
    EnergyPage.energy => _tr(context, 'Энергия', 'Energy'),
    EnergyPage.subscription => _tr(
      context,
      'Увеличить размер бонуса',
      'Increase the bonus amount',
    ),
    EnergyPage.video => _tr(context, 'Энергия за рекламу', 'Energy for ads'),
    EnergyPage.friends => _tr(context, 'Пригласить друга', 'Invite a friend'),
    EnergyPage.feedback => _tr(context, 'Обратная связь', 'Feedback'),
    EnergyPage.packs => _tr(context, 'Купить энергию', 'Buy energy'),
    EnergyPage.helmet => _tr(context, 'Шлем', 'Helmet'),
    EnergyPage.jump => _tr(context, 'Прыжок', 'Jump'),
  };
  @override
  Widget build(BuildContext context) {
    final e = context.watch<EconomyStore>();
    final showBalance = _page == EnergyPage.energy || _page == EnergyPage.packs;
    return PopScope(
      canPop: _page == EnergyPage.energy || _standalone,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: EnergyRewardMotion(
        key: _celebration,
        economy: e,
        sourceKey: _bonusOrigin,
        owner: e.energyOwner,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _ability ? 340 : 390),
          child: NeonGlass(
            key: const ValueKey('simple-energy-window'),
            radius: 20,
            padding: const EdgeInsets.fromLTRB(17, 10, 17, 15),
            child: LayoutBuilder(
              builder: (c, constraints) {
                final available = constraints.maxHeight;
                return SingleChildScrollView(
                  key: const ValueKey('energy-accessibility-scroll'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              key: const ValueKey('energy-hidden-title'),
                              behavior: HitTestBehavior.opaque,
                              onTap: _page == EnergyPage.energy
                                  ? _hiddenEnergyTap
                                  : null,
                              child: _text(
                                _title,
                                size:
                                    _page == EnergyPage.packs ||
                                        _page == EnergyPage.subscription
                                    ? 22
                                    : 24,
                                weight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (showBalance)
                            SizedBox(
                              key: const ValueKey('energy-window-balance'),
                              width: math.min(
                                (e.energy.toString().length * 17.0 + 30).clamp(
                                  70.0,
                                  145.0,
                                ),
                                constraints.maxWidth * .41,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: EnergyRewardCounter(
                                    economy: e,
                                    builder: (amount) =>
                                        EnergyRewardBalance(amount: amount),
                                  ),
                                ),
                              ),
                            ),
                          if (_page == EnergyPage.friends)
                            Tooltip(
                              triggerMode: TooltipTriggerMode.tap,
                              message: _tr(
                                context,
                                'Вы получите ${e.energyConfig.reward('invite')} энергии после 5 игр друга. У обоих должен быть подключён Google.',
                                'You receive ${e.energyConfig.reward('invite')} energy after your friend finishes 5 games. Both players need Google connected.',
                              ),
                              child: const SizedBox(
                                width: 32,
                                height: 44,
                                child: Icon(
                                  Icons.info_outline,
                                  color: _cyan,
                                  size: 23,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: 40,
                            height: 44,
                            child: IconButton(
                              key: const ValueKey('simple-energy-close'),
                              padding: EdgeInsets.zero,
                              tooltip: _tr(context, 'Закрыть', 'Close'),
                              onPressed: _back,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _cyan,
                                size: 29,
                              ),
                            ),
                          ),
                        ],
                      ),
                      _line(),
                      switch (_page) {
                        EnergyPage.energy => _energy(e),
                        EnergyPage.subscription => _subscription(e),
                        EnergyPage.video => _video(e),
                        EnergyPage.friends => _friends(e, available),
                        EnergyPage.feedback => EnergyFeedbackForm(
                          onBack: () => _open(EnergyPage.energy),
                        ),
                        EnergyPage.packs => _packs(e),
                        EnergyPage.helmet ||
                        EnergyPage.jump => _abilityContent(e),
                      },
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _text(
                            _error!,
                            size: 12,
                            color: const Color(0xFFFFBCAC),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _energy(EconomyStore e) {
    final bonus = e.simpleEnergyBonus;
    final remaining = bonus?.remainingAt(e.energyNow) ?? Duration.zero;
    final ready = e.simpleBonusReady;
    final tier = e.energyTier;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EnergyRewardDim(
          child: _text(
            _tr(
              context,
              'Бонус каждые ${bonus == null ? '8' : _hours(bonus.periodSec)} часов',
              'Bonus every ${bonus == null ? '8' : _hours(bonus.periodSec)} hours',
            ),
            size: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 7,
              child: AspectRatio(
                aspectRatio: 1,
                child: EnergyRewardDim(
                  source: true,
                  child: BonusOrb(
                    key: _bonusOrigin,
                    amount: bonus?.reward ?? 30,
                    multiplier: tier,
                    ready: ready,
                    pending: _busy || e.energyBusy,
                    remaining: remaining,
                    fraction: bonus?.remainingFraction(e.energyNow) ?? 1,
                    unavailable: bonus == null || !e.energyClockSynchronized,
                    serverUnsupported: bonus == null,
                    onTap: ready && !_busy && !e.energyBusy
                        ? () => _claimBonus(e)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: EnergyRewardDim(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EnergyBoostTile(
                      tier: tier,
                      onTap: tier < 5
                          ? () => _open(EnergyPage.subscription)
                          : null,
                    ),
                    const SizedBox(height: 7),
                    if (tier > 1)
                      TextButton(
                        key: const ValueKey('simple-manage-subscription'),
                        onPressed: () => _open(EnergyPage.subscription),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: _text(
                          _tr(context, 'Управлять', 'Manage'),
                          size: 11,
                          color: _muted,
                        ),
                      )
                    else
                      _text(
                        _tr(context, 'Подписка', 'Subscription'),
                        size: 11,
                        color: _muted,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (bonus == null)
          TextButton(
            key: const ValueKey('simple-energy-refresh'),
            onPressed: _busy
                ? null
                : () => _act(() async {
                    await context.read<MobileAccount?>()?.refreshProfile();
                  }),
            child: _text(
              _tr(
                context,
                'Бонус ждёт обновления сервера',
                'Bonus awaits server update',
              ),
              size: 12,
              color: _muted,
            ),
          ),
        if (e.energySubscriptionPending)
          _text(
            _tr(
              context,
              'Проверяем продление в Google Play',
              'Checking renewal with Google Play',
            ),
            size: 12,
            color: _muted,
          ),
        _line(),
        _rewardRow(
          Icons.ondemand_video_rounded,
          _tr(context, 'Смотреть\nрекламу', 'Watch\nad'),
          e.energyConfig.reward('watch_ad'),
          context.watch<AdsService?>()?.busy == true
              ? _tr(context, 'Загрузка…', 'Loading…')
              : context.watch<AdsService?>()?.rewardVerificationAvailable !=
                    true
              ? _tr(context, 'Недоступно', 'Unavailable')
              : e.watchAdCooldownRemaining == null
              ? _tr(context, 'Смотреть', 'Watch')
              : bonusTime(e.watchAdCooldownRemaining!),
          () => _watchVideo(e),
          'video',
        ),
        _line(),
        _rewardRow(
          Icons.person_add_alt_1_rounded,
          _tr(context, 'Пригласить\nдруга', 'Invite a\nfriend'),
          e.energyConfig.reward('invite'),
          _tr(context, 'Пригласить', 'Invite'),
          () => _open(EnergyPage.friends),
          'friends',
        ),
        _line(),
        _rewardRow(
          Icons.chat_bubble_outline_rounded,
          _tr(context, 'Ваш опыт\nигры', 'Your game\nexperience'),
          e.energyConfig.reward('feedback'),
          e.energyRewardClaimed('feedback')
              ? _tr(context, 'Получено', 'Received')
              : e.canSendEnergyFeedback
              ? _tr(context, 'Рассказать', 'Share')
              : '${e.feedbackSpentEnergy}/${e.feedbackMinimumSpend}',
          () => _open(EnergyPage.feedback),
          'feedback',
        ),
        _line(),
        NeonAction(
          key: const ValueKey('simple-energy-packs'),
          height: 50,
          onTap: () => _open(EnergyPage.packs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle, color: _cyan, size: 26),
              const SizedBox(width: 10),
              Flexible(
                child: _text(
                  _tr(context, 'Купить энергию', 'Buy energy'),
                  color: _cyan,
                  size: 17,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _hours(int sec) =>
      sec % 3600 == 0 ? '${sec ~/ 3600}' : (sec / 3600).toStringAsFixed(1);
  Widget _rewardRow(
    IconData icon,
    String title,
    int reward,
    String action,
    VoidCallback tap,
    String id,
  ) => Row(
    children: [
      Icon(icon, color: const Color(0xFF9DECFF), size: 32),
      const SizedBox(width: 9),
      Expanded(flex: 4, child: _text(title, size: 12)),
      Expanded(
        flex: 4,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: EnergyText(reward, prefix: '+', size: 26),
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        flex: 5,
        child: NeonAction(
          key: ValueKey('simple-energy-$id'),
          height: 44,
          onTap: tap,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _text(action, size: 13, weight: FontWeight.w800),
          ),
        ),
      ),
    ],
  );
  Widget _subscription(EconomyStore e) {
    final billing = context.watch<PlayBillingService?>();
    final offers = e.energyConfig.subscriptions;
    final chosen =
        offers.where((o) => o.id == _selectedSku).firstOrNull ??
        offers
            .where(
              (o) => o.totalBatteries == (e.energyTier > 1 ? e.energyTier : 5),
            )
            .firstOrNull ??
        offers.firstOrNull;
    final price = chosen == null ? null : billing?.energyOfferPrice(chosen.id);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(
          _tr(
            context,
            'Бонус с одной кнопки каждые ${_hours(e.simpleEnergyBonus?.periodSec ?? 28800)} часов',
            'One button, every ${_hours(e.simpleEnergyBonus?.periodSec ?? 28800)} hours',
          ),
          size: 13,
        ),
        const SizedBox(height: 14),
        for (final offer in offers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              selected: chosen?.id == offer.id,
              button: true,
              child: GestureDetector(
                key: ValueKey('simple-tier-${offer.totalBatteries}'),
                onTap: _busy
                    ? null
                    : () => setState(() => _selectedSku = offer.id),
                child: NeonGlass(
                  radius: 12,
                  selected: chosen?.id == offer.id,
                  padding: const EdgeInsets.all(9),
                  child: Row(
                    children: [
                      Icon(
                        chosen?.id == offer.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: _cyan,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 63,
                        height: 63,
                        child: GoldMedallion(label: '×${offer.totalBatteries}'),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: EnergyText(
                                e.simpleEnergyBonus?.rewardFor(
                                      offer.totalBatteries,
                                    ) ??
                                    offer.totalBatteries * 30,
                                size: 30,
                              ),
                            ),
                            _text(
                              _tr(context, 'за один бонус', 'per bonus'),
                              size: 11,
                            ),
                            if (e.energyTier == offer.totalBatteries)
                              _text(
                                _tr(context, 'Подключено', 'Active'),
                                size: 11,
                                color: const Color(0xFF8CFB95),
                              ),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 91),
                        child: _text(
                          '${billing?.energyOfferPrice(offer.id)?.price ?? _tr(context, 'Недоступно', 'Unavailable')}\n/ ${_tr(context, '7 дней', '7 days')}',
                          size: 14,
                          weight: FontWeight.w800,
                          align: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.eco, color: Color(0xFF68FFD7), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _text(
                    _tr(
                      context,
                      'Без автоматической рекламы',
                      'No automatic ads',
                    ),
                    size: 14,
                  ),
                  const SizedBox(height: 4),
                  _text(
                    _tr(
                      context,
                      'Доступность видео за энергию проверяется отдельно.',
                      'Rewarded video availability is checked separately.',
                    ),
                    size: 11,
                    color: _muted,
                  ),
                ],
              ),
            ),
          ],
        ),
        _line(),
        NeonAction(
          key: const ValueKey('simple-subscribe'),
          height: 60,
          primary: true,
          onTap:
              chosen != null &&
                  price != null &&
                  billing?.busy == false &&
                  !_busy &&
                  !e.energySubscriptionPending &&
                  chosen.totalBatteries != e.energyTier
              ? () => _act(() => buySimpleEnergy(context, chosen.id))
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _text(
                chosen?.totalBatteries == e.energyTier
                    ? _tr(context, 'Подключено', 'Active')
                    : _tr(
                        context,
                        'Подключить ×${chosen?.totalBatteries ?? 5}',
                        'Subscribe ×${chosen?.totalBatteries ?? 5}',
                      ),
                size: 20,
                weight: FontWeight.w800,
              ),
              if (price != null)
                _text(
                  '${price.price} / ${_tr(context, '7 дней', '7 days')}',
                  size: 13,
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _text(
          _tr(
            context,
            'Автопродление. Отмена в Google Play.\nСумма и условия подтверждаются в магазине.',
            'Auto-renews. Cancel in Google Play.\nConfirm price and terms in the store.',
          ),
          size: 11,
          color: _muted,
          align: TextAlign.center,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => _act(() => restoreGooglePurchases(context)),
                child: Text(
                  _tr(context, 'Восстановить', 'Restore'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => manageGoogleSubscription(context),
                child: Text(
                  _tr(context, 'Управлять', 'Manage'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        const EnergyBillingStatus(showRestore: false, collapseWhenIdle: true),
      ],
    );
  }

  Widget _video(EconomyStore e) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 8),
      const SizedBox(height: 170, child: CustomPaint(painter: _VideoPainter())),
      Center(
        child: EnergyText(
          e.energyConfig.reward('watch_ad'),
          prefix: '+',
          size: 45,
        ),
      ),
      const SizedBox(height: 9),
      _text(
        _tr(
          context,
          context.watch<AdsService?>()?.rewardVerificationAvailable == true
              ? 'Дождитесь награды и закройте рекламу.'
              : 'Видео за энергию временно недоступно.',
          context.watch<AdsService?>()?.rewardVerificationAvailable == true
              ? 'Finish the video to receive energy.'
              : 'Rewarded video is temporarily unavailable.',
        ),
        size: 15,
        align: TextAlign.center,
      ),
      const SizedBox(height: 18),
      NeonAction(
        key: const ValueKey('simple-watch-video'),
        height: 52,
        primary: true,
        onTap:
            !_busy &&
                e.canClaimWatchAd &&
                context.watch<AdsService?>()?.rewardVerificationAvailable ==
                    true
            ? () => _watchVideo(e)
            : null,
        child: _text(
          _busy
              ? _tr(context, 'Проверяем…', 'Checking…')
              : e.watchAdCooldownRemaining != null
              ? bonusTime(e.watchAdCooldownRemaining!)
              : _tr(context, 'Смотреть рекламу', 'Watch ad'),
          size: 19,
          weight: FontWeight.w800,
        ),
      ),
      TextButton(
        onPressed: _busy ? null : _back,
        child: Text(_tr(context, 'Не сейчас', 'Not now')),
      ),
      _text(
        _tr(context, 'Просмотр добровольный.', 'Watching is optional.'),
        size: 11,
        color: _muted,
        align: TextAlign.center,
      ),
    ],
  );
  Widget _friends(EconomyStore e, double available) {
    final service = context.watch<MobileInvites?>();
    final state = service?.state;
    final valid = state != null && state.profileId == service?.account.id;
    final rows = valid ? state.paidRows : <InvitePaidRow>[];
    final pending = valid ? state.pendingRows : <Map<String, dynamic>>[];
    Widget field(
      String title,
      String? value,
      String id, {
      bool share = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(title, size: 12, color: _muted),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF031A2F),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _cyan.withValues(alpha: .55)),
                ),
                child: _text(
                  value ?? _tr(context, 'Нет соединения', 'Offline'),
                  size: share ? 12 : 21,
                  color: share ? _muted : energyNeon,
                  weight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              key: ValueKey('simple-copy-$id'),
              tooltip: _tr(context, 'Копировать', 'Copy'),
              onPressed: value == null
                  ? null
                  : () => _act(
                      () => Clipboard.setData(ClipboardData(text: value)),
                    ),
              icon: const Icon(Icons.copy_rounded, color: _cyan, size: 21),
            ),
            if (share)
              IconButton(
                tooltip: _tr(context, 'Поделиться', 'Share'),
                onPressed: value == null
                    ? null
                    : () => _act(() async {
                        final box = context.findRenderObject() as RenderBox?;
                        await SharePlus.instance.share(
                          ShareParams(
                            text: 'Untouch\n$value',
                            sharePositionOrigin: box == null
                                ? const Rect.fromLTWH(0, 0, 48, 48)
                                : box.localToGlobal(Offset.zero) & box.size,
                          ),
                        );
                      }),
                icon: const Icon(Icons.share, color: _cyan, size: 22),
              ),
          ],
        ),
      ],
    );
    final count = rows.length + pending.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(
          _tr(context, 'Ваш код', 'Your code'),
          valid ? state.ownCode : null,
          'code',
        ),
        const SizedBox(height: 8),
        field(
          _tr(context, 'Ссылка', 'Link'),
          valid ? state.inviteUrl : null,
          'link',
          share: true,
        ),
        _line(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: Column(
                children: [
                  _text(
                    _tr(context, 'Приглашено', 'Invited'),
                    size: 12,
                    color: _muted,
                  ),
                  _text(
                    valid ? '${state.invitedCount ?? count}' : '—',
                    size: 25,
                    weight: FontWeight.w900,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _text(
                    _tr(context, 'Получено', 'Received'),
                    size: 12,
                    color: _muted,
                  ),
                  valid
                      ? EnergyText(state.energyRewardTotal, size: 25)
                      : _text('—', size: 25),
                ],
              ),
            ),
          ],
        ),
        _line(),
        _text(
          _tr(context, 'Приглашённые', 'Invited players'),
          size: 17,
          weight: FontWeight.w800,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: math.min(
            220.0,
            math.max(92.0, available.isFinite ? available - 295 : 220),
          ),
          child: ListView(
            key: const ValueKey('simple-invited-list'),
            padding: EdgeInsets.zero,
            children: [
              if (count == 0)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _text(
                    valid
                        ? _tr(
                            context,
                            'Приглашённых пока нет',
                            'No invitations yet',
                          )
                        : _tr(
                            context,
                            'Данные недоступны. Повторите загрузку.',
                            'Data unavailable. Retry loading.',
                          ),
                    size: 13,
                    color: _muted,
                  ),
                ),
              for (final row in rows)
                _friendRow(
                  row.nickname,
                  EnergyText(row.energyEquivalent, prefix: '+', size: 21),
                ),
              for (final row in pending)
                _friendRow(
                  row['nickname'] as String?,
                  _text(
                    '${row['games']} / 5\n${row['googleLinked'] == true ? 'Google ✓' : 'Google —'}',
                    size: 12,
                    color: _muted,
                  ),
                ),
              if (valid &&
                  (state.nextCursor != null || state.pendingNextCursor != null))
                TextButton(
                  onPressed: _busy ? null : () => _act(service!.loadMore),
                  child: Text(_tr(context, 'Ещё', 'More')),
                ),
            ],
          ),
        ),
        if (!valid || service?.error != null)
          TextButton(
            onPressed: service == null || _busy
                ? null
                : () => _act(service.refresh),
            child: Text(_tr(context, 'Повторить', 'Retry')),
          ),
      ],
    );
  }

  Widget _friendRow(String? name, Widget value) => Container(
    margin: const EdgeInsets.only(bottom: 5),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: const Color(0xFF0C324F),
      border: Border.all(color: const Color(0xFF14658C)),
    ),
    child: Row(
      children: [
        const Icon(Icons.account_circle, color: Color(0xFF7EB4DF), size: 29),
        const SizedBox(width: 8),
        Expanded(
          child: _text(name ?? _tr(context, 'Игрок', 'Player'), size: 13),
        ),
        value,
      ],
    ),
  );
  Widget _packs(EconomyStore e) {
    final billing = context.watch<PlayBillingService?>();
    final packs = e.energyConfig.packages;
    final baseline = packs.isEmpty
        ? null
        : packs.reduce((a, b) => a.amount < b.amount ? a : b);
    final basePrice = baseline == null
        ? null
        : billing?.energyOfferPrice(baseline.id);
    Widget pack(int index) {
      if (index >= packs.length) return const SizedBox.shrink();
      final p = packs[index],
          price = billing?.energyOfferPrice(packs[index].id);
      final beforeValue =
          baseline != null &&
              p.amount > baseline.amount &&
              basePrice != null &&
              price != null &&
              basePrice.currencyCode == price.currencyCode &&
              basePrice.reference == price.reference &&
              basePrice.rawPrice > 0
          ? basePrice.rawPrice * p.amount / baseline.amount
          : null;
      final discount = billing?.energyDiscount(p.id, e.energyConfig);
      final discounts = packs.map(
        (offer) => billing?.energyDiscount(offer.id, e.energyConfig) ?? 0,
      );
      final best = discount != null && discount == discounts.reduce(math.max);
      final beforePrice = beforeValue != null && beforeValue > price!.rawPrice
          ? NumberFormat.currency(
              locale: Localizations.localeOf(context).toString(),
              name: price.currencyCode,
              symbol: price.currencySymbol.isEmpty
                  ? price.currencyCode
                  : price.currencySymbol,
              decimalDigits: beforeValue % 1 == 0 ? 0 : 2,
            ).format(beforeValue)
          : null;
      return NeonGlass(
        key: ValueKey('simple-pack-tile-${p.id}'),
        radius: 11,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: EnergyText(p.amount, size: 29),
            ),
            SizedBox(
              height: 78,
              width: double.infinity,
              child: CustomPaint(
                painter: EnergyPackPainter(
                  beams: index == 0
                      ? 1
                      : index == 1
                      ? 3
                      : index == 2
                      ? 5
                      : 7,
                ),
              ),
            ),
            // A localized unit comparison is shown only with comparable actual
            // Play prices. No invented crossed-out USD in another currency.
            NeonAction(
              key: ValueKey('simple-pack-${p.id}'),
              height: 44,
              onTap: price != null && billing?.busy == false && !_busy
                  ? () => _act(() => buySimpleEnergy(context, p.id))
                  : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (beforePrice != null) ...[
                      Text(
                        beforePrice,
                        key: ValueKey('simple-pack-before-${p.id}'),
                        semanticsLabel: _tr(
                          context,
                          'По цене базового пакета: $beforePrice',
                          'At the base package rate: $beforePrice',
                        ),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: _muted,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      price?.price ?? _tr(context, 'Недоступно', 'Unavailable'),
                      key: ValueKey('simple-pack-price-${p.id}'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (discount != null) ...[
                      const SizedBox(width: 6),
                      EnergySavingsBadge(
                        percent: discount,
                        best: best,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 2; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row == 0 ? 9 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: pack(row * 2)),
                const SizedBox(width: 9),
                Expanded(child: pack(row * 2 + 1)),
              ],
            ),
          ),
        if (packs.any(
          (p) => billing?.energyDiscount(p.id, e.energyConfig) != null,
        ))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _text(
              _tr(
                context,
                'Выгода к цене ${baseline!.amount} энергии',
                'Savings vs. the ${baseline.amount} energy pack',
              ),
              size: 11,
              color: _muted,
              align: TextAlign.center,
            ),
          ),
        const SizedBox(height: 11),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, color: _muted, size: 17),
            const SizedBox(width: 7),
            Flexible(
              child: _text(
                _tr(
                  context,
                  'Оплата через Google Play',
                  'Payment via Google Play',
                ),
                size: 12,
                color: _muted,
              ),
            ),
          ],
        ),
        const EnergyBillingStatus(collapseWhenIdle: true),
      ],
    );
  }

  Widget _abilityContent(EconomyStore e) {
    final helmet = _page == EnergyPage.helmet;
    final selected = helmet ? e.helmetSelected : e.jumpSelected;
    final extra = helmet
        ? e.energyConfig.helmetExtraCost
        : e.energyConfig.jumpExtraCost;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset(
          'assets/branding/ui/simple-energy-${helmet ? 'helmet' : 'jump'}.png',
          key: ValueKey('simple-${helmet ? 'helmet' : 'jump'}-illustration'),
          fit: BoxFit.contain,
          height: 192,
        ),
        const SizedBox(height: 10),
        if (helmet) ...[
          _text(
            _tr(context, 'Защита от одного удара', 'Protection from one hit'),
            size: 20,
            weight: FontWeight.w800,
          ),
          const SizedBox(height: 7),
          _text(
            _tr(
              context,
              'Барьер принимает первый удар за попытку.',
              'The barrier absorbs the first hit of a run.',
            ),
            size: 14,
          ),
        ] else ...[
          _text(
            _tr(
              context,
              'Управляйте одним пальцем. Коснитесь экрана вторым — кубик подпрыгнет.',
              'Control with one finger. Touch with a second finger to jump.',
            ),
            size: 15,
          ),
          const SizedBox(height: 7),
          _text(
            _tr(
              context,
              'В прыжке защита от врагов. Опасные стены остаются опасными.',
              'Jumping protects from enemies. Dangerous walls remain dangerous.',
            ),
            size: 12,
            color: _muted,
          ),
        ],
        _line(),
        NeonGlass(
          radius: 9,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          child: Row(
            children: [
              Expanded(
                child: _text(
                  _tr(
                    context,
                    helmet ? 'Включить шлем' : 'Включить прыжок',
                    helmet ? 'Enable helmet' : 'Enable jump',
                  ),
                  size: 15,
                  weight: FontWeight.w700,
                ),
              ),
              Switch(
                key: ValueKey('simple-${helmet ? 'helmet' : 'jump'}-switch'),
                value: selected,
                activeThumbColor: const Color(0xFFD8FFFF),
                activeTrackColor: const Color(0xFF14DECC),
                onChanged: helmet ? e.setHelmetSelected : e.setJumpSelected,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: _text(
            _tr(
              context,
              '+$extra ⚡ к стоимости попытки',
              '+$extra ⚡ per attempt',
            ),
            size: 20,
            color: energyNeon,
            weight: FontWeight.w800,
          ),
        ),
        _line(),
        _text(
          _tr(
            context,
            'Следующая попытка стоит ${e.attemptEnergyCost} ⚡',
            'Next attempt costs ${e.attemptEnergyCost} ⚡',
          ),
          size: 14,
          color: _muted,
          align: TextAlign.center,
        ),
      ],
    );
  }
}

class NeonAction extends StatelessWidget {
  const NeonAction({
    super.key,
    required this.child,
    this.onTap,
    this.height = 48,
    this.primary = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double height;
  final bool primary;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: onTap == null ? .48 : 1,
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _cyan, width: 1.2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: primary
                    ? const [
                        Color(0xFF49EAFF),
                        Color(0xFF008DCF),
                        Color(0xFF005093),
                        Color(0xFF00BCEB),
                      ]
                    : const [
                        Color(0xFF176486),
                        Color(0xFF063553),
                        Color(0xFF00213D),
                        Color(0xFF125275),
                      ],
                stops: const [0, .12, .8, 1],
              ),
              boxShadow: onTap == null
                  ? []
                  : [
                      BoxShadow(
                        color: _cyan.withValues(alpha: primary ? .4 : .16),
                        blurRadius: primary ? 11 : 5,
                      ),
                      const BoxShadow(
                        color: Color(0xFF00101F),
                        offset: Offset(0, 3),
                        blurRadius: 2,
                      ),
                    ],
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// A compact game power-up. Its artwork is decorative; the entire tile opens
/// the existing subscription window and never buys anything directly.
class EnergyBoostTile extends StatelessWidget {
  const EnergyBoostTile({super.key, required this.tier, required this.onTap});
  final int tier;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext c) => Semantics(
    button: true,
    enabled: tier < 5 && onTap != null,
    label: _tr(
      c,
      tier >= 5
          ? 'Максимальный бонус. Подписка ×5'
          : tier == 2
          ? 'Увеличить бонус до ×5'
          : 'Увеличить размер бонуса. Подписка',
      tier >= 5
          ? 'Maximum bonus. Subscription ×5'
          : tier == 2
          ? 'Increase bonus to ×5'
          : 'Increase the bonus amount. Subscription',
    ),
    child: GestureDetector(
      key: const ValueKey('simple-energy-boost'),
      onTap: tier < 5 ? onTap : null,
      child: Container(
        height: 132,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: tier >= 5
                ? const [Color(0xFF152D40), Color(0xFF10283A)]
                : const [
                    Color(0xFF354485),
                    Color(0xFF132D56),
                    Color(0xFF06283F),
                  ],
          ),
          border: Border.all(
            color: tier >= 5
                ? _muted.withValues(alpha: .35)
                : tier > 1
                ? const Color(0xFF80F7C2)
                : const Color(0xFF8EF4FF),
            width: 1.4,
          ),
          boxShadow: tier >= 5
              ? const []
              : const [
                  BoxShadow(color: Color(0x665C66FF), blurRadius: 14),
                  BoxShadow(
                    color: Color(0xAA020E24),
                    offset: Offset(0, 4),
                    blurRadius: 5,
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CustomPaint(
            painter: tier >= 5 ? null : const _BoostPainter(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 90,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tier >= 5
                            ? Icons.check_circle_outline_rounded
                            : Icons.bolt_rounded,
                        color: tier >= 5 ? _muted : energyNeon,
                        size: 38,
                        shadows: tier >= 5
                            ? const []
                            : const [
                                Shadow(
                                  color: Color(0xFFFFAA35),
                                  blurRadius: 16,
                                ),
                              ],
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _tr(
                            c,
                            tier >= 5
                                ? 'Максимальный\nбонус'
                                : tier == 2
                                ? 'Увеличить\nдо ×5'
                                : 'Увеличить\nразмер\nбонуса',
                            tier >= 5
                                ? 'Maximum\nbonus'
                                : tier == 2
                                ? 'Increase\nto ×5'
                                : 'Increase\nthe bonus\namount',
                          ),
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: tier >= 5 ? _muted : const Color(0xFFF1FCFF),
                            fontSize: 15,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                            shadows: tier >= 5
                                ? const []
                                : const [
                                    Shadow(
                                      color: Color(0x6654E9FF),
                                      blurRadius: 5,
                                    ),
                                  ],
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
    ),
  );
}

class _BoostPainter extends CustomPainter {
  const _BoostPainter();
  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width / 2, s.height * .27);
    c.drawCircle(
      center,
      s.width * .47,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x777676FF), Color(0x007676FF)],
        ).createShader(Rect.fromCircle(center: center, radius: s.width * .47)),
    );
    // Twin rising chevrons frame the lightning without occupying its center.
    for (final x in [.15, .85]) {
      final p = Path()
        ..moveTo(s.width * x - 6, s.height * .32)
        ..lineTo(s.width * x, s.height * .25)
        ..lineTo(s.width * x + 6, s.height * .32);
      c.drawPath(
        p,
        Paint()
          ..color = const Color(0xFF83DFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      c.drawPath(
        p.shift(const Offset(0, -8)),
        Paint()
          ..color = const Color(0x7783DFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    c.drawLine(
      const Offset(10, 3),
      Offset(s.width - 10, 3),
      Paint()
        ..color = const Color(0x99D6F9FF)
        ..strokeWidth = 1,
    );
    for (var i = 0; i < 9; i++) {
      final x = (i * 31.0 + 9) % s.width, y = (i * 23.0 + 18) % s.height;
      c.drawCircle(
        Offset(x, y),
        i % 3 == 0 ? 1.3 : .7,
        Paint()..color = const Color(0x88AAE8FF),
      );
    }
  }

  @override
  bool shouldRepaint(_BoostPainter old) => false;
}

class EnergySavingsBadge extends StatelessWidget {
  const EnergySavingsBadge({
    super.key,
    required this.percent,
    this.best = false,
    this.compact = false,
  });
  final int percent;
  final bool best, compact;
  @override
  Widget build(BuildContext c) => Semantics(
    label: _tr(
      c,
      'Выгода $percent процентов к базовому пакету',
      'Save $percent percent vs. the base pack',
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        key: ValueKey('energy-savings-$percent'),
        padding: compact
            ? const EdgeInsets.fromLTRB(3, 3, 4, 3)
            : const EdgeInsets.fromLTRB(6, 3, 9, 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: best
                ? const [Color(0xFFFFD66B), Color(0xFFFF693D)]
                : const [Color(0xFFFFEE9A), Color(0xFFFFB83F)],
          ),
          border: Border.all(color: const Color(0xFFFFEDB0)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: best ? const Color(0x99FF7434) : const Color(0x55FFCA34),
              blurRadius: best ? 11 : 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: compact
                  ? 13
                  : best
                  ? 20
                  : 18,
              color: const Color(0xFF8F2B12),
            ),
            const SizedBox(width: 2),
            Text(
              '−$percent%',
              style: TextStyle(
                color: const Color(0xFF4A200D),
                fontSize: compact ? 12 : 16,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (best) ...[
              SizedBox(width: compact ? 2 : 4),
              Icon(
                Icons.star_rounded,
                color: Color(0xFF8F2B12),
                size: compact ? 10 : 15,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class BonusOrb extends StatelessWidget {
  const BonusOrb({
    super.key,
    required this.amount,
    required this.ready,
    required this.remaining,
    required this.fraction,
    this.multiplier = 1,
    this.pending = false,
    this.unavailable = false,
    this.serverUnsupported = false,
    this.onTap,
  });
  final int amount, multiplier;
  final bool ready, pending, unavailable, serverUnsupported;
  final Duration remaining;
  final double fraction;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext c) => Semantics(
    button: true,
    enabled: onTap != null,
    label: ready
        ? '$amount ${_tr(c, 'энергии. Забрать', 'energy. Claim')}'
        : bonusTime(remaining),
    child: GestureDetector(
      key: const ValueKey('simple-bonus-orb'),
      onTap: onTap,
      child: CustomPaint(
        painter: _OrbPainter(ready: ready, fraction: fraction),
        child: LayoutBuilder(
          builder: (c, b) => Stack(
            alignment: Alignment.center,
            children: [
              if (multiplier == 2 || multiplier == 5)
                Positioned(
                  top: b.maxHeight * (ready ? .16 : .12),
                  height: b.maxHeight * .10,
                  left: b.maxWidth * .2,
                  right: b.maxWidth * .2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '×$multiplier',
                      key: const ValueKey('simple-bonus-multiplier'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: energyCore,
                        fontSize: b.maxHeight * .10,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              if (ready)
                Positioned(
                  top: b.maxHeight * .255,
                  width: b.maxHeight * .145,
                  height: b.maxHeight * .21,
                  child: const CustomPaint(painter: _BonusBoltPainter()),
                ),
              Positioned(
                top: b.maxHeight * (ready ? .465 : .27),
                left: b.maxWidth * .16,
                right: b.maxWidth * .16,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: ready ? 0 : 1.3,
                    sigmaY: ready ? 0 : 1.3,
                  ),
                  child: Opacity(
                    opacity: ready ? 1 : .35,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            key: const ValueKey('simple-bonus-amount'),
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Symmetric space keeps the digits themselves on
                              // the circle axis; the currency icon cannot shift them.
                              SizedBox(width: b.maxHeight * .125),
                              Text(
                                '$amount',
                                key: const ValueKey('simple-bonus-value'),
                                style: TextStyle(
                                  color: energyNeon,
                                  fontSize: b.maxHeight * .225,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xAAFFD627),
                                      blurRadius: 9,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: b.maxHeight * .015),
                              SizedBox(
                                key: const ValueKey('simple-bonus-currency'),
                                width: b.maxHeight * .11,
                                height: b.maxHeight * .195,
                                child: const CustomPaint(
                                  painter: _BonusBoltPainter(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!ready)
                Positioned(
                  top: b.maxHeight * .48,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      Icon(
                        serverUnsupported
                            ? Icons.cloud_off_rounded
                            : Icons.schedule,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          unavailable ? '— : — : —' : bonusTime(remaining),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: b.maxHeight * .13,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (ready)
                Positioned(
                  top: b.maxHeight * .705,
                  left: 10,
                  right: 10,
                  child: Text(
                    pending
                        ? _tr(c, 'Проверяем…', 'Checking…')
                        : _tr(c, 'Забрать', 'Claim'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF061A2B),
                      fontSize: b.maxHeight * .105,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              if (pending)
                const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              if (!ready)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Text(
                    serverUnsupported
                        ? _tr(c, 'Ожидание сервера', 'Waiting for server')
                        : unavailable
                        ? _tr(c, 'Синхронизация', 'Synchronizing')
                        : _tr(c, 'Перезарядка', 'Recharging'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BonusBoltPainter extends CustomPainter {
  const _BonusBoltPainter();
  @override
  void paint(Canvas canvas, Size size) {
    // Tight bounds of the same lightning silhouette used by the reference kit.
    final path = Path()
      ..moveTo(size.width * 11 / 18, 0)
      ..lineTo(0, size.height * 13 / 24)
      ..lineTo(size.width * 7 / 18, size.height * 13 / 24)
      ..lineTo(size.width * 5 / 18, size.height)
      ..lineTo(size.width, size.height * 9 / 24)
      ..lineTo(size.width * 10 / 18, size.height * 9 / 24)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x88FFD627)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [energyCore, energyNeon, Color(0xFFFFD52C)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_BonusBoltPainter oldDelegate) => false;
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({required this.ready, required this.fraction});
  final bool ready;
  final double fraction;
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero),
        radius = s.shortestSide * (ready ? .405 : .43);
    final color = ready ? const Color(0xFFFFD83C) : _cyan;
    c.drawCircle(
      center,
      radius * 1.06,
      Paint()
        ..color = color.withValues(alpha: ready ? .36 : .12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
    );
    if (ready) {
      final rim = Rect.fromCircle(center: center, radius: radius * 1.14);
      c.drawCircle(
        center,
        radius * 1.14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.shortestSide * .05
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF7A6),
              Color(0xFF957016),
              Color(0xFF171A16),
              Color(0xFFFFDB42),
            ],
            stops: [0, .12, .57, 1],
          ).createShader(rim),
      );
      for (final width in [7.0, 1.8]) {
        c.drawCircle(
          center,
          radius * 1.14,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..color = width == 7
                ? const Color(0xFFFFC52A)
                : const Color(0xFFFFF6B2)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              width == 7 ? 5 : 0,
            ),
        );
      }
      for (var i = 0; i < 24; i++) {
        final a = i * math.pi / 12;
        final d = Offset(math.cos(a), math.sin(a));
        c.drawLine(
          center + d * radius * 1.065,
          center + d * radius * 1.105,
          Paint()
            ..color = const Color(0xFFC7A855)
            ..strokeWidth = i % 6 == 0 ? 2 : 1,
        );
      }
    }
    c.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.2, -.2),
          colors: ready
              ? const [
                  Color(0xFFB49B31),
                  Color(0xFF64571D),
                  Color(0xFF10252C),
                  Color(0xFFDDAC1D),
                ]
              : const [Color(0xFF0D3B62), Color(0xFF00101F), Color(0xFF0B3554)],
          stops: ready ? const [0, .24, .67, 1] : null,
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    if (ready) {
      c.save();
      c.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius - 2)),
      );
      c.drawOval(
        Rect.fromCenter(
          center: center + Offset(0, radius * .66),
          width: radius * 1.9,
          height: radius * .68,
        ),
        Paint()
          ..color = const Color(0xFFFFDC37)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .18),
      );
      c.drawOval(
        Rect.fromCenter(
          center: center + Offset(-radius * .15, -radius * .68),
          width: radius * 1.45,
          height: radius * .20,
        ),
        Paint()
          ..color = const Color(0x77FFF9BD)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .07),
      );
      c.restore();
      for (final width in [14.0, 6.0, 1.8]) {
        c.drawCircle(
          center,
          radius - 1,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..color = Color(
              width == 14
                  ? 0x77FFBA0A
                  : width == 6
                  ? 0xFFFFD529
                  : 0xFFFFFFCB,
            )
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              width == 14
                  ? 7
                  : width == 6
                  ? 2
                  : 0,
            ),
        );
      }
      // Tiny illuminated cardinal marks make the reward feel like a charged
      // game control, while keeping the text area unobstructed.
      for (var i = 0; i < 4; i++) {
        final angle = math.pi * i / 2;
        final direction = Offset(math.cos(angle), math.sin(angle));
        c.drawLine(
          center + direction * (radius - 5),
          center + direction * (radius - 1),
          Paint()
            ..color = const Color(0xFFFFFFCC)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
      for (final turn in [.05, .43, .73]) {
        c.drawArc(
          Rect.fromCircle(center: center, radius: radius - 4),
          turn * math.pi * 2,
          .63,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFFFFFC4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
        );
      }
    }
    for (var i = 0; i < 3; i++) {
      c.drawCircle(
        center,
        radius - i * 5,
        Paint()
          ..color = (ready ? const Color(0xFFFFED87) : const Color(0xFF567A95))
              .withValues(alpha: i == 1 ? .4 : 1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 1 ? 4 : 1.5,
      );
    }
    if (!ready) {
      // Remaining wedge starts at twelve; elapsed uncovering proceeds clockwise.
      final sweep = 2 * math.pi * fraction.clamp(0, 1),
          start = -math.pi / 2 + 2 * math.pi * (1 - fraction.clamp(0, 1));
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius - 10),
          start,
          sweep,
          false,
        )
        ..close();
      c.drawPath(path, Paint()..color = const Color(0x881E4565));
      final arc = Rect.fromCircle(center: center, radius: radius - 2);
      for (final width in [13.0, 7.0, 2.0]) {
        c.drawArc(
          arc,
          -math.pi / 2,
          2 * math.pi * (1 - fraction.clamp(0, 1)),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(
              alpha: width == 13
                  ? .23
                  : width == 7
                  ? .9
                  : 1,
            )
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              width == 13 ? 4 : 0,
            ),
        );
      }
      final marker =
          center + Offset(math.cos(start), math.sin(start)) * (radius - 2);
      c.drawCircle(
        marker,
        6,
        Paint()
          ..color = const Color(0xFFC4FFFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      c.drawCircle(marker, 4, Paint()..color = Colors.white);
    }
    final random = math.Random(13);
    for (var i = 0; i < (ready ? 35 : 14); i++) {
      final angle = random.nextDouble() * math.pi * 2,
          r = radius * (1.02 + random.nextDouble() * .16),
          p = center + Offset(math.cos(angle), math.sin(angle)) * r;
      c.drawCircle(
        p,
        i % 7 == 0 ? 2 : .8,
        Paint()
          ..color = color.withValues(alpha: .4 + random.nextDouble() * .6)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            i % 7 == 0 ? 1.5 : 0,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.ready != ready || old.fraction != fraction;
}

class GoldMedallion extends StatelessWidget {
  const GoldMedallion({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext c) => CustomPaint(
    painter: const _OrbPainter(ready: true, fraction: 0),
    child: Center(
      child: Text(
        label,
        style: const TextStyle(
          color: energyNeon,
          fontSize: 25,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _VideoPainter extends CustomPainter {
  const _VideoPainter();
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero), r = s.height * .29;
    for (var i = 0; i < 3; i++) {
      final path = Path();
      for (var x = 0.0; x <= s.width; x += 2) {
        final y =
            center.dy +
            math.sin(x / s.width * math.pi * 4 + i) *
                s.height *
                .08 *
                math.sin(x / s.width * math.pi);
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      c.drawPath(
        path,
        Paint()
          ..color = _cyan.withValues(alpha: .35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 5 : 1
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, i == 0 ? 4 : 0),
      );
    }
    c.drawCircle(
      center,
      r + 8,
      Paint()
        ..color = _cyan.withValues(alpha: .25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    c.drawCircle(center, r, Paint()..color = const Color(0xFF00243E));
    for (final inset in [0.0, 7.0]) {
      c.drawCircle(
        center,
        r - inset,
        Paint()
          ..color = _cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = inset == 0 ? 3 : 1,
      );
    }
    final p = Path()
      ..moveTo(center.dx - r * .22, center.dy - r * .44)
      ..lineTo(center.dx + r * .43, center.dy)
      ..lineTo(center.dx - r * .22, center.dy + r * .44)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0xFF81FAFF));
  }

  @override
  bool shouldRepaint(_VideoPainter old) => false;
}

class EnergyPackPainter extends CustomPainter {
  const EnergyPackPainter({required this.beams});
  final int beams;
  @override
  void paint(Canvas c, Size s) {
    final base = Offset(s.width / 2, s.height * .84);
    for (final scale in [1.0, .75, .5]) {
      c.drawOval(
        Rect.fromCenter(
          center: base,
          width: s.width * .88 * scale,
          height: 17 * scale,
        ),
        Paint()
          ..color = _cyan.withValues(alpha: scale == .75 ? .9 : .3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    for (var i = 0; i < beams; i++) {
      final x = base.dx + (i - (beams - 1) / 2) * 9,
          top = s.height * (.1 + (i % 3) * .1),
          r = Rect.fromLTRB(x - 6, top, x + 6, base.dy);
      c.drawOval(
        Rect.fromCenter(center: Offset(x, base.dy), width: 19, height: 6),
        Paint()
          ..color = energyNeon
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      c.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00FFCE25), Color(0xFFFFD228), Color(0xFFFFFFC0)],
          ).createShader(r)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      final path = Path()
        ..moveTo(x, top)
        ..lineTo(x + 2, base.dy)
        ..lineTo(x - 2, base.dy)
        ..close();
      c.drawPath(path, Paint()..color = const Color(0xFFFFF8B0));
    }
  }

  @override
  bool shouldRepaint(EnergyPackPainter old) => beams != old.beams;
}
