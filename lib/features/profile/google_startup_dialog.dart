import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import '../../data/google_identity.dart';
import '../../data/mobile_account.dart';
import '../../data/economy_store.dart';
import '../../ui/game_ui.dart';
import '../../ui/neon_chrome.dart';

Future<void> showGoogleStartupOffer(
  BuildContext context, {
  required MobileAccount account,
  required GoogleIdentity identity,
}) => showDialog<void>(
  context: context,
  useRootNavigator: false,
  barrierColor: GameUi.modalBarrier,
  animationStyle: GameUi.windowAnimationStyle,
  builder: (_) => GoogleStartupDialog(account: account, identity: identity),
);

class GoogleStartupDialog extends StatefulWidget {
  const GoogleStartupDialog({
    super.key,
    required this.account,
    required this.identity,
  });
  final MobileAccount account;
  final GoogleIdentity identity;

  @override
  State<GoogleStartupDialog> createState() => _GoogleStartupDialogState();
}

class _GoogleStartupDialogState extends State<GoogleStartupDialog> {
  bool _connecting = false;
  String? _message;

  Future<void> _connect() async {
    if (_connecting ||
        widget.account.busy ||
        widget.account.googleStage != null) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _connecting = true;
      _message = null;
    });
    try {
      await widget.account.linkGoogle(widget.identity);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      final code = error is MobileApiError
          ? error.code
          : error is GoogleSignInException
          ? switch (error.code) {
              GoogleSignInExceptionCode.canceled ||
              GoogleSignInExceptionCode.interrupted ||
              GoogleSignInExceptionCode.uiUnavailable => 'google_incomplete',
              GoogleSignInExceptionCode.clientConfigurationError =>
                'google_not_configured',
              GoogleSignInExceptionCode.providerConfigurationError =>
                'google_services_unavailable',
              _ => '',
            }
          : error is TimeoutException
          ? 'connection_failed'
          : '';
      setState(() {
        _message = switch (code) {
          'google_profile_exists' =>
            ru
                ? 'Не удалось открыть Google-профиль. Повторите подключение.'
                : 'Could not open your Google profile. Try connecting again.',
          'google_incomplete' =>
            ru
                ? 'Можно подключить Google позже в профиле.'
                : 'You can connect Google later in your profile.',
          'google_not_configured' || 'google_services_unavailable' =>
            ru
                ? 'Google сейчас недоступен. Продолжайте без него — подключить можно позже в профиле.'
                : 'Google is unavailable. Continue without it and connect later in your profile.',
          'profile_unavailable' ||
          'connection_failed' ||
          'service_unavailable' =>
            ru
                ? 'Проверьте интернет и попробуйте снова. Можно продолжить без Google.'
                : 'Check your connection and try again. You can continue without Google.',
          'round_delivery_pending' =>
            ru
                ? 'Сначала нужно отправить ваш результат. Проверьте интернет и повторите попытку.'
                : 'Your result needs to sync first. Check your connection and try again.',
          _ =>
            ru
                ? 'Не удалось подключить Google. Попробуйте снова или продолжайте без него.'
                : 'Could not connect Google. Retry or continue without it.',
        };
      });
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final usesEnergy = context.watch<EconomyStore?>()?.energyEnabled ?? false;
    return AnimatedBuilder(
      animation: widget.account,
      builder: (context, _) {
        final busy =
            _connecting ||
            widget.account.busy ||
            widget.account.googleStage != null;
        final status = switch (widget.account.googleStage) {
          GoogleConnectionStage.preparing =>
            ru ? 'Подготавливаем профиль…' : 'Preparing profile…',
          GoogleConnectionStage.choosingAccount =>
            ru ? 'Выберите аккаунт…' : 'Choose an account…',
          _ => ru ? 'Подключаем…' : 'Connecting…',
        };
        return PopScope(
          canPop: !busy,
          child: Dialog(
            key: const ValueKey('google-startup-dialog'),
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: AccountGlass(
                radius: 20,
                padding: const EdgeInsets.all(2),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NeonSheetHeader(
                        title: ru ? 'Сохраните прогресс' : 'Keep your progress',
                        closeEnabled: !busy,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 112,
                        child: Image.asset(
                          'assets/branding/account/progress-player.png',
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ru
                            ? 'Ваш прогресс — с вами'
                            : 'Your progress stays with you',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: GameUi.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        ru
                            ? 'Подключите Google, чтобы вернуться к своему профилю, рекордам и ${usesEnergy ? 'энергии' : 'кристаллам'} после переустановки или на другом телефоне.'
                            : 'Connect Google to recover your profile, records and ${usesEnergy ? 'energy' : 'crystals'} after reinstalling or on another phone.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: GameUi.muted,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ru
                            ? 'Ник можно изменить в профиле. Имя Google скрыто от других игроков по умолчанию.'
                            : 'You can change your nickname in Profile. Your Google name is hidden from other players by default.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: GameUi.muted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_message != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF12364E),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: const Color(0xFF287B98)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: GameUi.cyan,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _message!,
                                  key: const ValueKey('google-startup-message'),
                                  style: const TextStyle(
                                    color: GameUi.text,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      FilledButton(
                        key: const ValueKey('google-startup-connect'),
                        style: FilledButton.styleFrom(
                          backgroundColor: GameUi.mint,
                          foregroundColor: GameUi.text,
                          minimumSize: const Size(double.infinity, 52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: busy ? null : _connect,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const GoogleBrandMark(size: 24),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                busy
                                    ? status
                                    : (_message != null
                                          ? (ru
                                                ? 'Повторить подключение'
                                                : 'Try connecting again')
                                          : (ru
                                                ? 'Подключить Google'
                                                : 'Connect Google')),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('google-startup-skip'),
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF93B2C7),
                          minimumSize: const Size(48, 48),
                          textStyle: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        child: Text(ru ? 'Пока без Google' : 'Not now'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
