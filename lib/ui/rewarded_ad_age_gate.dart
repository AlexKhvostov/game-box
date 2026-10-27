import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/audience_policy.dart';
import '../data/economy_store.dart';
import 'audience_gate.dart';
import 'game_ui.dart';
import 'neon_chrome.dart';

/// No viewing instructions or SDK action before an adult declaration.
/// The one-time alternative credit is confirmed by the server wallet.
class RewardedAdAgeGate extends StatefulWidget {
  const RewardedAdAgeGate({
    super.key,
    required this.child,
    required this.onAlternatives,
  });
  final Widget child;
  final VoidCallback onAlternatives;

  @override
  State<RewardedAdAgeGate> createState() => _RewardedAdAgeGateState();
}

class _RewardedAdAgeGateState extends State<RewardedAdAgeGate> {
  bool _prompted = false, _checking = false, _claiming = false;
  bool _queued = false, _failed = false;
  String? _attemptedOwner;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final policy = context.watch<AudiencePolicy?>();
    final economy = context.watch<EconomyStore>();
    if (policy == null || policy.isAdEligibleAge || _queued) return;
    final needsPrompt = policy.needsSelection && !_prompted;
    final needsBonus =
        !policy.needsSelection &&
        !economy.adUnavailableBonusClaimed &&
        economy.energyOwner != null &&
        economy.energyOwner != _attemptedOwner;
    if (!needsPrompt && !needsBonus) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (mounted) _prepare();
    });
  }

  Future<void> _prepare() async {
    if (_checking || _claiming) return;
    final policy = context.read<AudiencePolicy?>();
    if (policy == null) return;
    final economy = context.read<EconomyStore>();
    final owner = economy.energyOwner;
    if (policy.needsSelection) {
      setState(() {
        _prompted = true;
        _checking = true;
      });
      await showAudienceSelection(context, resourceAction: true);
      if (!mounted) return;
      setState(() => _checking = false);
    }
    if (!mounted ||
        policy.needsSelection ||
        policy.isAdEligibleAge ||
        economy.energyOwner != owner ||
        owner == null ||
        economy.adUnavailableBonusClaimed) {
      return;
    }
    _attemptedOwner = owner;
    setState(() {
      _claiming = true;
      _failed = false;
    });
    try {
      await economy.claimAdUnavailableBonus();
    } catch (_) {
      if (mounted && economy.energyOwner == owner) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = context.watch<AudiencePolicy?>();
    if (policy == null || policy.isAdEligibleAge) return widget.child;
    final economy = context.watch<EconomyStore>();
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final unknown = policy.needsSelection;
    return Column(
      key: ValueKey(unknown ? 'ad-age-required' : 'ad-age-unavailable'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.ondemand_video_rounded, color: GameUi.cyan, size: 48),
        const SizedBox(height: 14),
        Text(
          unknown
              ? (ru ? 'Сначала уточним возраст' : 'First, confirm your age')
              : (ru
                    ? 'Реклама доступна только с 18 лет'
                    : 'Ads are for ages 18 and older'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          unknown
              ? (ru
                    ? 'Мы пока не знаем ваш возраст, поэтому не можем показать рекламу. Выберите возрастную группу, чтобы продолжить.'
                    : 'We do not know your age yet, so we cannot show ads. Choose your age group to continue.')
              : (ru
                    ? 'Извините, мы не можем показать вам рекламу. Энергию можно получить другими способами: забрать бесплатный бонус или пригласить друга.'
                    : 'Sorry, we cannot show you ads. You can get energy in other ways: collect the free bonus or invite a friend.'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: GameUi.muted,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        if (unknown)
          FilledButton(
            key: const ValueKey('ad-select-age'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
            ).copyWith(backgroundBuilder: accountButtonLayer),
            onPressed: _checking ? null : _prepare,
            child: Text(ru ? 'Указать возраст' : 'Confirm age'),
          )
        else ...[
          Text(
            economy.adUnavailableBonusClaimed
                ? (ru
                      ? 'Разовый бонус +20 энергии получен'
                      : 'One-time bonus of 20 energy received')
                : _claiming
                ? (ru
                      ? 'Получаем разовый бонус +20 энергии…'
                      : 'Collecting your one-time bonus of 20 energy…')
                : (ru
                      ? 'Разовый бонус: +20 энергии'
                      : 'One-time bonus: 20 energy'),
            key: const ValueKey('ad-unavailable-bonus-status'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFE47B),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_failed && !economy.adUnavailableBonusClaimed) ...[
            const SizedBox(height: 8),
            Text(
              ru
                  ? 'Не удалось подтвердить бонус. Проверьте связь и повторите.'
                  : 'Could not confirm the bonus. Check your connection and retry.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFBCAC), fontSize: 13),
            ),
            TextButton(
              key: const ValueKey('ad-unavailable-bonus-retry'),
              onPressed: _claiming ? null : _prepare,
              child: Text(ru ? 'Получить бонус' : 'Collect bonus'),
            ),
          ],
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('ad-energy-alternatives'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
          ).copyWith(backgroundBuilder: accountButtonLayer),
          onPressed: widget.onAlternatives,
          child: Text(
            ru ? 'Другие способы получить энергию' : 'Other ways to get energy',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
