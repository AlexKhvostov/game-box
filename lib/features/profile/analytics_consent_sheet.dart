import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../ui/profile_support.dart';
import '../../data/analytics_consent.dart';
import '../../ui/game_ui.dart';
import '../../ui/neon_chrome.dart';

Future<void> showAnalyticsFirstQuestion(BuildContext context) async {
  final consent = context.read<AnalyticsConsent?>();
  if (consent == null || !consent.needsPrompt) return;
  try {
    await consent.markPromptSeen();
  } catch (_) {
    // Storage failure never grants permission or blocks starting the game.
    return;
  }
  if (!context.mounted || !consent.eligible) return;
  await _showAnalytics(context, first: true, consent: consent);
}

Future<void> showAnalyticsSettings(BuildContext context) async {
  final consent = context.read<AnalyticsConsent?>();
  if (consent == null) return;
  await _showAnalytics(context, first: false, consent: consent);
}

Future<void> _showAnalytics(
  BuildContext context, {
  required bool first,
  required AnalyticsConsent consent,
}) => showDialog<void>(
  context: context,
  useRootNavigator: false,
  barrierColor: GameUi.modalBarrier,
  animationStyle: GameUi.windowAnimationStyle,
  builder: (_) => _AnalyticsSheet(first: first, consent: consent),
);

Future<void> showAnalyticsInformation(BuildContext context) => showDialog<void>(
  context: context,
  useRootNavigator: false,
  barrierColor: GameUi.modalBarrier,
  animationStyle: GameUi.windowAnimationStyle,
  builder: (_) => const _AnalyticsInformation(),
);

const _art = 'assets/branding/analytics/';
bool _ru(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ru';
TextStyle _body({bool muted = false}) => TextStyle(
  color: muted ? GameUi.muted : GameUi.text,
  fontSize: 15,
  height: 1.45,
);
Widget _details(BuildContext context) => TextButton(
  key: const ValueKey('analytics-details-open'),
  onPressed: () => showAnalyticsInformation(context),
  style: TextButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: const Size(48, 48),
  ),
  child: Row(
    children: [
      Expanded(
        child: Text(
          _ru(context) ? 'Подробности об аналитике' : 'About analytics',
          style: const TextStyle(
            color: GameUi.cyan,
            fontSize: 15,
            decoration: TextDecoration.underline,
            decorationColor: GameUi.cyan,
          ),
        ),
      ),
      const Icon(Icons.chevron_right_rounded, color: GameUi.cyan),
    ],
  ),
);

class _AnalyticsSheet extends StatefulWidget {
  const _AnalyticsSheet({required this.first, required this.consent});
  final bool first;
  final AnalyticsConsent consent;
  @override
  State<_AnalyticsSheet> createState() => _AnalyticsSheetState();
}

class _AnalyticsSheetState extends State<_AnalyticsSheet> {
  bool _saving = false, _failed = false;
  Future<void> _change(bool value) async {
    if (_saving || !mounted) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.consent.setEnabled(value);
      if (!mounted) return;
      if (widget.first) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.consent,
    builder: (context, _) {
      final consent = widget.consent, ru = _ru(context), on = consent.enabled;
      if (widget.first && !consent.eligible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ModalRoute.of(context)?.isCurrent == true) {
            Navigator.pop(context);
          }
        });
      }
      final height = MediaQuery.sizeOf(context).height;
      final large = MediaQuery.textScalerOf(context).scale(16) > 20;
      final short = height < 600;
      final artHeight = widget.first
          ? (short ? (large ? 0.0 : 80.0) : 180.0)
          : (short ? 100.0 : 210.0);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 360,
            maxHeight: (height - 36).clamp(0, 760),
          ),
          child: AccountGlass(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NeonSheetHeader(
                  title: ru ? 'Аналитика' : 'Analytics',
                  closeEnabled: !_saving,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    key: ValueKey(
                      widget.first
                          ? 'analytics-first-scroll'
                          : 'analytics-state-scroll',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (artHeight > 0)
                          Image.asset(
                            _art +
                                (widget.first
                                    ? 'consent-hero-v1.png'
                                    : on
                                    ? 'cube-on-v1.png'
                                    : 'cube-off-v1.png'),
                            key: ValueKey(
                              widget.first
                                  ? 'analytics-hero'
                                  : on
                                  ? 'analytics-cube-on'
                                  : 'analytics-cube-off',
                            ),
                            height: artHeight,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        if (widget.first) ...[
                          Text(
                            ru
                                ? 'Поможете улучшить игру?'
                                : 'Help improve the game?',
                            key: const ValueKey('analytics-first-question'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ru
                                ? 'Разрешите передавать игровые события и технические данные стороннему сервису для улучшения Untouch.'
                                : 'Allow game events and technical data to be sent to a third-party service to improve Untouch.',
                            style: _body(),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            ru
                                ? 'Отказ не ограничивает игру.'
                                : 'You can decline and still play the full game.',
                            style: _body(),
                          ),
                        ] else ...[
                          Container(
                            key: const ValueKey('analytics-state-row'),
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: on
                                    ? GameUi.cyan
                                    : const Color(0xFFD66D78),
                              ),
                              gradient: LinearGradient(
                                colors: on
                                    ? const [
                                        Color(0xFF07334B),
                                        Color(0xFF052035),
                                      ]
                                    : const [
                                        Color(0xFF321F32),
                                        Color(0xFF132439),
                                      ],
                              ),
                            ),
                            child: MergeSemantics(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      on
                                          ? (ru ? 'Включена' : 'On')
                                          : (ru ? 'Выключена' : 'Off'),
                                      key: const ValueKey(
                                        'analytics-state-label',
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Semantics(
                                    label: ru
                                        ? 'Сбор аналитики'
                                        : 'Analytics collection',
                                    child: Switch(
                                      key: const ValueKey(
                                        'analytics-consent-switch',
                                      ),
                                      value: on,
                                      onChanged:
                                          _saving ||
                                              consent.busy ||
                                              !consent.eligible
                                          ? null
                                          : _change,
                                      activeThumbColor: Colors.white,
                                      activeTrackColor: const Color(0xFF00C8CC),
                                      inactiveThumbColor: const Color(
                                        0xFFE1EDF5,
                                      ),
                                      inactiveTrackColor: const Color(
                                        0xFF4B2434,
                                      ),
                                      trackOutlineColor:
                                          WidgetStateProperty.all(
                                            on
                                                ? GameUi.cyan
                                                : const Color(0xFFB65265),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            !consent.eligible
                                ? (ru
                                      ? 'Аналитика выключена. Она доступна только пользователям 18 лет и старше.'
                                      : 'Analytics is off. It is only available to users aged 18 or older.')
                                : on
                                ? (ru
                                      ? 'Данные об игре и работе приложения помогают улучшать Untouch.'
                                      : 'Gameplay and app performance data help improve Untouch.')
                                : (ru
                                      ? 'Новые данные аналитики не отправляются. Игра доступна без ограничений.'
                                      : 'No new analytics data is sent. The full game remains available.'),
                            style: _body(),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ru
                                ? 'Ранее переданные данные не удаляются автоматически.'
                                : 'Previously sent data is not automatically deleted.',
                            style: _body(muted: true),
                          ),
                        ],
                        const SizedBox(height: 5),
                        _details(context),
                        if (_failed)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              ru
                                  ? 'Не удалось сохранить выбор. Аналитика выключена. Попробуйте ещё раз.'
                                  : 'Could not save your choice. Analytics is off. Please try again.',
                              key: const ValueKey('analytics-save-error'),
                              style: const TextStyle(
                                color: Color(0xFFFFB8AC),
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (widget.first) ...[
                  const SizedBox(height: 10),
                  FilledButton(
                    key: const ValueKey('analytics-consent-allow'),
                    onPressed: _saving || !consent.eligible
                        ? null
                        : () => _change(true),
                    child: Text(
                      ru ? 'Разрешить' : 'Allow',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('analytics-consent-decline'),
                    onPressed: _saving ? null : () => _change(false),
                    child: Text(
                      ru ? 'Без аналитики' : 'No analytics',
                      style: const TextStyle(
                        color: GameUi.cyan,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: GameUi.cyan,
                      ),
                    ),
                  ),
                  Text(
                    ru
                        ? 'Выбор можно изменить в аккаунте.'
                        : 'Change your choice in Account.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: GameUi.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AnalyticsInformation extends StatelessWidget {
  const _AnalyticsInformation();
  @override
  Widget build(BuildContext context) {
    final ru = _ru(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: (MediaQuery.sizeOf(context).height - 36).clamp(0, 780),
        ),
        child: AccountGlass(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('analytics-info-back-arrow'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: GameUi.cyan,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ru ? 'О данных' : 'About your data',
                      style: const TextStyle(
                        fontSize: 23,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF24738C)),
              const Flexible(
                child: SingleChildScrollView(
                  key: ValueKey('analytics-info-scroll'),
                  child: AnalyticsDataBlock(),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                key: const ValueKey('analytics-info-back'),
                onPressed: () => Navigator.pop(context),
                child: Text(ru ? 'Назад' : 'Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared readable content: never an image containing the disclosure text.
class AnalyticsDataBlock extends StatelessWidget {
  const AnalyticsDataBlock({super.key});
  @override
  Widget build(BuildContext context) {
    final ru = _ru(context);
    final sections = ru
        ? <List<String>>[
            ['Кто получает данные', 'AppMetrica — сервис Яндекса.'],
            [
              'Что передаётся',
              'Игровые события, результаты, способности, время в окнах, настройки и результаты операций.',
              'ID установки, хеш ID аккаунта, данные устройства и IP-адрес.',
              'Это не полностью анонимные данные.',
            ],
            [
              'Что не входит в события',
              'Ник, имя Google, email, тексты отзывов, пароли и коды приглашений.',
              'Геопозиция Android и рекламные ID выключены.',
            ],
            [
              'После отключения',
              'Новая аналитика не отправляется. Ранее переданные данные не удаляются автоматически.',
            ],
          ]
        : <List<String>>[
            ['Who receives the data', 'AppMetrica, a Yandex service.'],
            [
              'What is sent',
              'Game events, results, ability use, time in screens, settings and operation results.',
              'An installation ID, a hash of your account ID, device information and your IP address.',
              'This data is not fully anonymous.',
            ],
            [
              'Not included in events',
              'Nickname, Google name, email, feedback text, passwords and invitation codes.',
              'Android location access and advertising IDs are disabled.',
            ],
            [
              'After turning analytics off',
              'No new analytics is sent. Previously sent data is not automatically deleted.',
            ],
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Divider(color: Color(0xFF24738C)),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (i == 0) ...[
                SvgPicture.asset(
                  '${_art}data-document.svg',
                  width: 42,
                  height: 58,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      sections[i].first,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    for (final paragraph in sections[i].skip(1))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(paragraph, style: _body()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
        TextButton(
          key: const ValueKey('analytics-policy-link'),
          onPressed: () async {
            try {
              await ProfileSupport.channel.invokeMethod<void>('openPage', {
                'page': 'privacy',
                'language': ru ? 'ru' : 'en',
              });
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(
                    ru
                        ? 'Не удалось открыть политику. Попробуйте ещё раз.'
                        : 'Could not open the privacy policy. Please try again.',
                  ),
                ),
              );
            }
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          child: Text(
            ru ? 'Политика конфиденциальности ↗' : 'Privacy policy ↗',
            style: const TextStyle(
              color: GameUi.cyan,
              decoration: TextDecoration.underline,
              decorationColor: GameUi.cyan,
            ),
          ),
        ),
      ],
    );
  }
}

class AnalyticsProfileButton extends StatelessWidget {
  const AnalyticsProfileButton({super.key});
  @override
  Widget build(BuildContext context) {
    if (context.watch<AnalyticsConsent?>() == null) {
      return const SizedBox.shrink();
    }
    return TextButton(
      key: const ValueKey('profile-analytics-open'),
      onPressed: () => showAnalyticsSettings(context),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(48, 48),
        foregroundColor: GameUi.text,
      ),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded, size: 22, color: GameUi.cyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _ru(context) ? 'Аналитика' : 'Analytics',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: GameUi.cyan),
        ],
      ),
    );
  }
}
