import 'dart:async';
import '../../ui/game_ui.dart';
import '../../ui/game_status_overlay.dart';
import '../../ui/ad_privacy_settings.dart';
import '../../ui/audience_gate.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../data/player_preferences.dart';
import '../../data/audience_policy.dart';
import '../../data/mobile_account.dart';
import '../../data/scores_store.dart';
import '../../data/google_identity.dart';
import '../../ui/neon_chrome.dart';
import '../../ui/profile_support.dart';
import '../../ui/public_name_controls.dart';
import '../invites/inviter_section.dart';
import '../leaderboard/leaderboard_sheet.dart';

Future<void> showProfileSheet(
  BuildContext context, {
  GoogleIdentity? googleIdentity,
}) => showDialog<void>(
  animationStyle: GameUi.windowAnimationStyle,
  context: context,
  useRootNavigator: false,
  barrierColor: GameUi.modalBarrier,
  builder: (_) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
    insetAnimationDuration: Duration.zero,
    child: ProfileScreen(googleIdentity: googleIdentity),
  ),
);

/// Confirmation only: the caller retains ownership of the account operation.
Future<bool?> showProfileRestoreConfirmation(BuildContext context) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  return showDialog<bool>(
    animationStyle: GameUi.windowAnimationStyle,
    context: context,
    builder: (_) => _ProfileConfirmation(
      title: ru ? 'Восстановить профиль?' : 'Restore profile?',
      description: ru
          ? 'Откроется профиль, ранее связанный с выбранным Google. Текущий гостевой профиль останется отдельным; прогресс не объединяется.'
          : 'Open the profile previously linked to this Google account. The current guest remains separate; progress is not merged.',
      confirmLabel: ru ? 'Восстановить' : 'Restore',
      confirmationKey: 'profile-restore-confirm',
    ),
  );
}

/// The destructive work is deliberately kept outside this visual confirmation.
Future<bool?> showProfileResetConfirmation(BuildContext context) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  return showDialog<bool>(
    animationStyle: GameUi.windowAnimationStyle,
    context: context,
    builder: (_) => _ProfileConfirmation(
      title: ru ? 'Сбросить данные?' : 'Reset data?',
      description: ru
          ? 'Будут сброшены локальные игровые данные на этом устройстве. Это действие нельзя отменить.'
          : 'Local game data on this device will be reset. This action cannot be undone.',
      confirmLabel: ru ? 'Сбросить' : 'Reset',
      confirmationKey: 'profile-reset-confirm',
      danger: true,
    ),
  );
}

Future<bool?> showProfileGoogleDisconnectConfirmation(BuildContext context) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  return showDialog<bool>(
    animationStyle: GameUi.windowAnimationStyle,
    context: context,
    builder: (_) => _ProfileConfirmation(
      title: ru ? 'Отключить Google?' : 'Disconnect Google?',
      description: ru
          ? 'Прогресс и баланс останутся в текущем профиле игры. Чтобы снова восстанавливать его через Google, подключите аккаунт заново.'
          : 'Your progress and balance stay in your current game profile. Connect Google again to restore this profile with Google.',
      confirmLabel: ru ? 'Отключить' : 'Disconnect',
      confirmationKey: 'profile-google-disconnect-confirm',
    ),
  );
}

class _ProfileConfirmation extends StatefulWidget {
  const _ProfileConfirmation({
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.confirmationKey,
    this.danger = false,
  });
  final String title, description, confirmLabel, confirmationKey;
  final bool danger;
  @override
  State<_ProfileConfirmation> createState() => _ProfileConfirmationState();
}

class _ProfileConfirmationState extends State<_ProfileConfirmation> {
  bool _decided = false;
  void _finish(bool approved) {
    if (_decided) return;
    setState(() => _decided = true);
    Navigator.pop(context, approved);
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final touch = GameUi.touchTarget(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 358),
      child: AccountGlass(
        radius: 20,
        padding: const EdgeInsets.all(6),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeonSheetHeader(title: widget.title),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Center(
                  child: widget.danger
                      ? const Icon(
                          Icons.warning_rounded,
                          color: GameUi.heart,
                          size: 48,
                        )
                      : const AccountArt('cloud-v1.png', size: 48),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: GameUi.text,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: ValueKey('${widget.confirmationKey}-cancel'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(touch, touch),
                        foregroundColor: GameUi.text,
                        side: const BorderSide(color: GameUi.cyan),
                      ),
                      onPressed: _decided ? null : () => _finish(false),
                      child: Text(ru ? 'Отмена' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: ValueKey(widget.confirmationKey),
                      style: widget.danger
                          ? FilledButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.transparent,
                              minimumSize: Size(touch, touch),
                            ).copyWith(backgroundBuilder: _profileDangerLayer)
                          : FilledButton.styleFrom(
                              minimumSize: Size(touch, touch),
                            ),
                      onPressed: _decided ? null : () => _finish(true),
                      child: Text(widget.confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Approved coral material; the shared button still owns its 48dp hit area.
Widget _profileDangerLayer(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => Container(
  alignment: Alignment.center,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(9),
    border: Border.all(
      color: states.contains(WidgetState.focused)
          ? const Color(0xFFFFF1E8)
          : const Color(0xFFFFB8C8),
      width: states.contains(WidgetState.focused) ? 2 : 1,
    ),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFDF8398), Color(0xFFAD365D)],
    ),
    boxShadow: const [BoxShadow(color: Color(0x40F55193), blurRadius: 5)],
  ),
  child: child,
);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.googleIdentity});
  final GoogleIdentity? googleIdentity;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _googleMessage;
  bool _connecting = false;
  bool _disconnecting = false;
  GoogleIdentity get _identity =>
      widget.googleIdentity ?? NativeGoogleIdentity();
  bool _privacySaving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final scores = context.read<ScoresStore?>();
      if (scores?.supportsAverage == true) {
        unawaited(scores!.refreshIfStale());
      }
      final account = context.read<MobileAccount?>();
      final identity = _identity;
      if (account != null && identity is NativeGoogleIdentity) {
        try {
          await account.refreshGoogleDetails(identity);
        } catch (_) {
          // Existing verified linking stays intact if a silent refresh fails.
        }
      }
    });
  }

  Future<void> _privacy(MobileAccount account, bool hide, bool ru) async {
    if (_privacySaving) return;
    setState(() => _privacySaving = true);
    try {
      if (!hide && !await ensureCommunityRules(context, account)) return;
      await account.setGooglePrivacy(hide);
      if (mounted) setState(() => _googleMessage = null);
    } catch (error) {
      if (mounted) {
        setState(
          () => _googleMessage =
              error is MobileApiError && error.code == 'nickname_prohibited'
              ? (ru
                    ? 'Имя Google содержит запрещённое слово. Оставьте его скрытым или измените имя в Google.'
                    : 'Your Google name contains a prohibited word. Keep it hidden or change it in Google.')
              : ru
              ? 'Не удалось сохранить. Проверьте сеть и повторите.'
              : 'Could not save. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _privacySaving = false);
    }
  }

  Future<void> _google(
    BuildContext context,
    MobileAccount account,
    bool ru,
  ) async {
    if (_connecting) return;
    if (!mounted) return;
    setState(() {
      _googleMessage = null;
      _connecting = true;
    });
    try {
      await account.linkGoogle(_identity);
    } catch (e) {
      if (!context.mounted) return;
      final code = e is MobileApiError
          ? e.code
          : e is GoogleSignInException
          ? switch (e.code) {
              GoogleSignInExceptionCode.clientConfigurationError =>
                'google_client_invalid',
              GoogleSignInExceptionCode.providerConfigurationError =>
                'google_services_unavailable',
              GoogleSignInExceptionCode.canceled ||
              GoogleSignInExceptionCode.interrupted ||
              GoogleSignInExceptionCode.uiUnavailable => 'google_incomplete',
              _ => '',
            }
          : e is TimeoutException
          ? 'connection_failed'
          : '';
      final message = switch (code) {
        'google_incomplete' =>
          ru
              ? 'Вход через Google не завершён. Повторите подключение.'
              : 'Google sign-in did not finish. Try connecting again.',
        'google_client_invalid' || 'google_not_configured' =>
          ru
              ? 'Google не принимает эту версию приложения. Сообщите об этом в поддержку.'
              : 'Google cannot sign in with this app version. Contact support.',
        'google_services_unavailable' =>
          ru
              ? 'Сервисы Google недоступны. Проверьте Google Play на устройстве.'
              : 'Google services are unavailable. Check Google Play on this device.',
        'google_token_invalid' || 'google_token_missing' =>
          ru
              ? 'Не удалось подтвердить вход Google. Повторите подключение.'
              : 'Google sign-in could not be verified. Try connecting again.',
        'google_not_linked' =>
          ru
              ? 'Сервер не подтвердил подключение Google. Повторите попытку.'
              : 'The server did not confirm Google linking. Try again.',
        'profile_unavailable' || 'connection_failed' || 'service_unavailable' =>
          ru
              ? 'Нет связи с игровым сервером. Проверьте интернет и повторите подключение.'
              : 'The game server is unavailable. Check your connection and retry.',
        'google_profile_exists' =>
          ru
              ? 'Не удалось открыть Google-профиль. Повторите подключение.'
              : 'Could not open your Google profile. Try connecting again.',
        'google_profile_not_found' =>
          ru
              ? 'С этим Google ещё не связан профиль Untouch.'
              : 'No Untouch profile is linked to this Google account.',
        'round_delivery_pending' =>
          ru
              ? 'Результат ещё ожидает отправки. Подключитесь к сети и повторите восстановление — так ваш рекорд сохранится.'
              : 'A result is waiting to sync. Connect to the network and retry restoring to keep your record.',
        _ =>
          ru
              ? 'Не удалось подключить Google. Попробуйте позже.'
              : 'Could not connect Google. Try again later.',
      };
      // A root snackbar is covered by this modal sheet. Keep the result beside
      // the Google controls so failure/cancellation is visible on return.
      setState(() => _googleMessage = message);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnectGoogle(MobileAccount account, bool ru) async {
    if (_disconnecting || account.busy || account.googleStage != null) return;
    final owner = account.id;
    final approved = await showProfileGoogleDisconnectConfirmation(context);
    if (approved != true || !mounted || account.id != owner) return;
    setState(() {
      _disconnecting = true;
      _googleMessage = null;
    });
    try {
      await account.unlinkGoogle(_identity);
      if (mounted) {
        setState(
          () =>
              _googleMessage = ru ? 'Google отключён.' : 'Google disconnected.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _googleMessage = ru
              ? 'Не удалось подтвердить отключение. Проверьте сеть и повторите.'
              : 'Could not confirm disconnection. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _disconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final prefs = context.watch<PlayerPreferences?>();
    final account = context.watch<MobileAccount?>();
    final scores = context.watch<ScoresStore?>();
    final mine = account?.id != null && scores?.account?.id == account?.id
        ? scores?.averageRanking?.mine
        : null;
    final ownStats = mine?.userId == null || mine?.userId == account?.id
        ? mine
        : null;
    final audience = context.watch<AudiencePolicy?>();
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final nickname =
        account?.nickname ??
        economy.displayName ??
        (ru ? 'Гостевой профиль' : 'Guest profile');
    final googleAvailable = _identity.configured;
    final connecting = _connecting || account?.googleStage != null;
    final googleStatus = _disconnecting
        ? (ru ? 'Отключаем Google…' : 'Disconnecting Google…')
        : switch (account?.googleStage) {
            GoogleConnectionStage.preparing =>
              ru ? 'Подготавливаем профиль…' : 'Preparing profile…',
            GoogleConnectionStage.choosingAccount =>
              ru ? 'Выберите Google-аккаунт…' : 'Choose a Google account…',
            GoogleConnectionStage.verifying =>
              ru ? 'Подтверждаем подключение…' : 'Verifying connection…',
            null =>
              connecting
                  ? (ru ? 'Подключаем…' : 'Connecting…')
                  : account?.googleLinked == true
                  ? (ru ? 'Google подключён' : 'Google linked')
                  : googleAvailable
                  ? (ru ? 'Google не подключён' : 'Google not linked')
                  : (ru ? 'Google пока недоступен' : 'Google unavailable yet'),
          };
    final connectingOrBusy = connecting || account?.busy == true;
    final linked = account?.googleLinked == true;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 352,
        maxHeight: (MediaQuery.sizeOf(context).height - 36).clamp(
          0,
          scale > 1.4 ? 740 : 620,
        ),
      ),
      child: AccountGlass(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(14, 7, 14, 10),
        child: SafeArea(
          top: false,
          bottom: false,
          child: ListView(
            key: const ValueKey('profile-content'),
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              NeonSheetHeader(title: ru ? 'Аккаунт' : 'Account'),
              Padding(
                key: const ValueKey('profile-player'),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const AccountPortrait(size: 64),
                    const SizedBox(width: 10),
                    Expanded(
                      child: account != null && account.onlineAllowed
                          ? _NicknameEditor(account: account, ru: ru)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ru ? 'Игровой ник' : 'Game nickname',
                                  style: const TextStyle(
                                    color: GameUi.text,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  nickname,
                                  style: const TextStyle(
                                    color: GameUi.text,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _ProfilePanel(
                key: const ValueKey('profile-stats'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: Row(
                  children: [
                    Expanded(
                      child: _ProfileStat(
                        key: const ValueKey('profile-stat-record'),
                        actionKey: const ValueKey('profile-stat-record-action'),
                        onTap: scores == null
                            ? null
                            : () =>
                                  showLeaderboardSheet(context, allTime: true),
                        label: ru ? 'Рекорд' : 'Best',
                        value: economy.bestTimeMs > 0
                            ? '${(economy.bestTimeMs / 1000).toStringAsFixed(3)} ${ru ? 'с' : 's'}'
                            : '—',
                      ),
                    ),
                    const _ProfileStatDivider(),
                    Expanded(
                      child: _ProfileStat(
                        key: const ValueKey('profile-stat-average'),
                        actionKey: const ValueKey(
                          'profile-stat-average-action',
                        ),
                        onTap: scores?.supportsAverage != true
                            ? null
                            : () => showLeaderboardSheet(
                                context,
                                initialTab: LeaderboardTab.average,
                                allTime: true,
                              ),
                        label: ru ? 'Среднее' : 'Average',
                        value: ownStats?.averageMs == null
                            ? '—'
                            : '${(ownStats!.averageMs! / 1000).toStringAsFixed(3)} ${ru ? 'с' : 's'}',
                      ),
                    ),
                    const _ProfileStatDivider(),
                    Expanded(
                      child: _ProfileStat(
                        key: const ValueKey('profile-stat-attempts'),
                        actionKey: const ValueKey(
                          'profile-stat-attempts-action',
                        ),
                        onTap: scores == null
                            ? null
                            : () => showMyAttemptsSheet(context),
                        label: ru ? 'Попыток' : 'Attempts',
                        value: '${ownStats?.totalAttempts ?? '—'}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _ProfilePanel(
                key: const ValueKey('profile-google-setting'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (linked)
                          const Padding(
                            padding: EdgeInsets.only(top: 4, right: 7),
                            child: AccountArt('cloud-v1.png', size: 36),
                          ),
                        if (!linked)
                          const Padding(
                            padding: EdgeInsets.only(top: 11, right: 7),
                            child: GoogleBrandMark(size: 21),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    googleStatus,
                                    key: const ValueKey(
                                      'profile-google-status',
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                      color: linked ? GameUi.mint : GameUi.text,
                                    ),
                                  ),
                                ),
                                if (linked) ...[
                                  if (account!.googleName?.isNotEmpty == true)
                                    Text(
                                      account.googleName!,
                                      key: const ValueKey(
                                        'profile-google-name',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: GameUi.text,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  if (account.googleEmail?.isNotEmpty == true)
                                    Text(
                                      account.googleEmail!,
                                      key: const ValueKey(
                                        'profile-google-email',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: GameUi.muted,
                                      ),
                                    )
                                  else
                                    TextButton(
                                      key: const ValueKey(
                                        'profile-google-details-refresh',
                                      ),
                                      onPressed: connectingOrBusy
                                          ? null
                                          : () => _google(context, account, ru),
                                      child: Text(
                                        ru
                                            ? 'Уточнить подключённый аккаунт'
                                            : 'Confirm linked account details',
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (linked)
                          SizedBox(
                            width: ru ? 74 : 82,
                            child: TextButton(
                              key: const ValueKey('profile-google-disconnect'),
                              style: TextButton.styleFrom(
                                foregroundColor: GameUi.muted,
                                backgroundColor: Colors.transparent,
                                side: BorderSide.none,
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              onPressed:
                                  connectingOrBusy ||
                                      _privacySaving ||
                                      _disconnecting
                                  ? null
                                  : () => _disconnectGoogle(account!, ru),
                              child: Text(ru ? 'Отключить' : 'Disconnect'),
                            ),
                          )
                        else
                          _ProfileButton(
                            key: const ValueKey('profile-google-link'),
                            width: 100,
                            label: ru ? 'Подключить' : 'Connect',
                            onPressed:
                                account == null ||
                                    connectingOrBusy ||
                                    !googleAvailable
                                ? null
                                : () => _google(context, account, ru),
                          ),
                      ],
                    ),
                    if (linked) ...[
                      const SizedBox(height: 5),
                      const Divider(height: 1, color: Color(0xFF24536D)),
                      Column(
                        key: const ValueKey('profile-google-privacy-group'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile(
                            key: const ValueKey('profile-google-private'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -2),
                            value: account!.hideGoogleAccount,
                            onChanged: _privacySaving || connectingOrBusy
                                ? null
                                : (value) => _privacy(account, value, ru),
                            title: Row(
                              children: [
                                const AccountArt('eye', size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    ru
                                        ? 'Скрыть Google в рейтинге'
                                        : 'Hide Google on leaderboard',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: GameUi.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              account.hideGoogleAccount
                                  ? (ru
                                        ? 'Виден только игровой ник.'
                                        : 'Only your game nickname is visible.')
                                  : (ru
                                        ? 'Видно имя Google. Почта не показывается.'
                                        : 'Google name is visible. Your email stays private.'),
                              key: const ValueKey(
                                'profile-google-privacy-hint',
                              ),
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: GameUi.muted,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_googleMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _googleMessage!,
                            key: const ValueKey('profile-google-message'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: GameUi.text,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const HiddenNamesSetting(),
              if (audience != null) ...[
                const SizedBox(height: 6),
                const _ProfilePanel(
                  key: ValueKey('profile-age-panel'),
                  padding: EdgeInsets.symmetric(horizontal: 9),
                  child: AudienceProfileSetting(compact: true, dark: true),
                ),
              ],
              if (prefs != null) ...[
                const SizedBox(height: 6),
                Row(
                  key: const ValueKey('profile-game-settings'),
                  children: [
                    Expanded(
                      child: _ProfilePanel(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _ProfileSetting(
                          art: 'sound',
                          title: ru ? 'Звуки' : 'Sounds',
                          trailing: Switch(
                            key: const ValueKey('profile-sound-switch'),
                            value: prefs.sound,
                            onChanged: prefs.setSound,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _ProfilePanel(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _ProfileSetting(
                          art: 'music',
                          title: ru ? 'Музыка' : 'Music',
                          trailing: Switch(
                            key: const ValueKey('profile-music-switch'),
                            value: prefs.music,
                            onChanged: prefs.setMusic,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (InviterSection.available(context)) ...[
                const SizedBox(height: 5),
                const _ProfilePanel(
                  padding: EdgeInsets.zero,
                  plain: true,
                  child: InviterSection(compact: true),
                ),
              ],
              const SizedBox(height: 6),
              _ProfilePanel(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton(
                  key: const ValueKey('profile-support-expand'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: GameUi.text,
                  ),
                  onPressed: () => showDialog<void>(
                    context: context,
                    useRootNavigator: false,
                    barrierColor: GameUi.modalBarrier,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(14),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: AccountGlass(
                          child: SingleChildScrollView(
                            key: const ValueKey('profile-help-content'),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                NeonSheetHeader(
                                  titleSize: 19,
                                  title: ru
                                      ? 'Помощь и приватность'
                                      : 'Help and privacy',
                                ),
                                const AdPrivacySettings(compact: true),
                                ProfileSupport(
                                  playerId: account?.id,
                                  dark: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const AccountArt('help', size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ru
                              ? 'Помощь и конфиденциальность'
                              : 'Help and privacy',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: GameUi.cyan,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.plain = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool plain;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Container(
      padding: padding,
      decoration: plain
          ? null
          : BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF07364E), Color(0xFF021D33)],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1B7096)),
            ),
      child: Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
            onSurface: GameUi.text,
            primary: GameUi.mint,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: GameUi.cyan,
              minimumSize: const Size(48, 48),
            ),
          ),
          checkboxTheme: base.checkboxTheme.copyWith(
            side: const BorderSide(color: GameUi.muted, width: 1.5),
            checkColor: WidgetStateProperty.all(GameUi.background),
            fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? GameUi.mint
                  : Colors.transparent,
            ),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: GameUi.text),
          child: child,
        ),
      ),
    );
  }
}

Widget _profileSecondaryLayer(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => accountButtonLayer(context, states, child);
Widget _profileSaveLayer(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => accountButtonLayer(context, states, child);

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    super.key,
    this.width = 108,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final double width;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: GameUi.cyan,
        disabledForegroundColor: GameUi.muted,
        minimumSize: Size(
          GameUi.touchTarget(context),
          GameUi.touchTarget(context),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ).copyWith(backgroundBuilder: _profileSecondaryLayer),
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    ),
  );
}

class _ProfileSetting extends StatelessWidget {
  const _ProfileSetting({
    required this.art,
    required this.title,
    required this.trailing,
  });
  final String art, title;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      AccountArt(art, size: MediaQuery.sizeOf(context).width < 340 ? 17 : 21),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 11, color: GameUi.text),
        ),
      ),
      SizedBox(width: 44, height: 48, child: trailing),
    ],
  );
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    super.key,
    required this.label,
    required this.value,
    required this.actionKey,
    this.onTap,
  });
  final String label, value;
  final Key actionKey;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    button: onTap != null,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 10, color: GameUi.muted),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 12,
                        color: GameUi.cyan,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.1,
                    color: GameUi.text,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
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

class _ProfileStatDivider extends StatelessWidget {
  const _ProfileStatDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 25,
    margin: const EdgeInsets.symmetric(horizontal: 5),
    color: const Color(0xFF24536D),
  );
}

class _NicknameEditor extends StatefulWidget {
  const _NicknameEditor({required this.account, required this.ru});
  final MobileAccount account;
  final bool ru;
  @override
  State<_NicknameEditor> createState() => _NicknameEditorState();
}

class _NicknameEditorState extends State<_NicknameEditor> {
  late final TextEditingController _controller;
  String? _error, _actionError;
  bool _saving = false;
  bool _rejected = false;
  late String _committedName;
  String? _profileId;
  bool get _changed =>
      _controller.text.trim() != (widget.account.nickname ?? '');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.account.nickname ?? '');
    _committedName = widget.account.nickname ?? '';
    _profileId = widget.account.id;
  }

  @override
  void didUpdateWidget(_NicknameEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh an untouched field after restore; retain unsaved drafts on errors.
    if (_profileId != widget.account.id ||
        (_controller.text.trim() == _committedName && !_saving)) {
      _controller.text = widget.account.nickname ?? '';
      _error = null;
      _actionError = null;
      _rejected = false;
    }
    _profileId = widget.account.id;
    _committedName = widget.account.nickname ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validation() {
    final name = _controller.text.trim();
    if (name.runes.length < 2 || name.runes.length > 24) {
      return widget.ru ? 'От 2 до 24 символов' : 'Use 2–24 characters';
    }
    if (RegExp(r'[<>\x00-\x1F\x7F]').hasMatch(name)) {
      return widget.ru
          ? 'Уберите служебные символы и < >'
          : 'Remove control characters and < >';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_changed || _saving || _rejected || widget.account.busy) return;
    final invalid = _validation();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _actionError = null;
    });
    try {
      if (!await ensureCommunityRules(context, widget.account)) return;
      if (!mounted) return;
      await widget.account.rename(_controller.text.trim());
      if (!mounted) return;
      _controller.text = widget.account.nickname ?? '';
      _committedName = widget.account.nickname ?? '';
    } catch (e) {
      if (!mounted) return;
      final code = e is MobileApiError ? e.code : '';
      _rejected =
          code == 'nickname_taken' ||
          code == 'nickname_invalid' ||
          code == 'nickname_prohibited';
      if (!_rejected) {
        _error = null;
        _actionError = widget.ru
            ? 'Не удалось сохранить. Попробуйте ещё раз.'
            : 'Could not save. Please try again.';
        return;
      }
      _error = switch (code) {
        'nickname_taken' =>
          widget.ru
              ? 'Этот ник занят. Выберите другой.'
              : 'Nickname taken. Choose another.',
        'nickname_invalid' =>
          widget.ru
              ? 'От 2 до 24 символов без служебных символов и < >'
              : 'Use 2–24 characters without control characters or < >',
        'nickname_prohibited' =>
          widget.ru
              ? 'Выберите имя без оскорблений и запрещённых слов.'
              : 'Choose a name without offensive or prohibited words.',
        _ =>
          widget.ru
              ? 'Не удалось сохранить. Попробуйте ещё раз.'
              : 'Could not save. Please try again.',
      };
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invalid = _changed && (_validation() != null || _rejected);
    final canSave = _changed && !invalid && !_saving && !widget.account.busy;
    const mint = GameUi.mint;
    final touch = GameUi.touchTarget(context);
    final fieldHeight = touch * MediaQuery.textScalerOf(context).scale(16) / 16;
    return GameStatusOverlay(
      message:
          _actionError ??
          (_saving ? (widget.ru ? 'Сохраняем…' : 'Saving…') : null),
      messageKey: const ValueKey('profile-nickname-action-error'),
      busy: _saving && _actionError == null,
      isError: _actionError != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                widget.ru ? 'Игровой ник' : 'Game nickname',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: GameUi.text,
                ),
              ),
              Text(
                widget.ru ? '2–24 символа' : '2–24 characters',
                style: const TextStyle(fontSize: 9, color: GameUi.muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (widget.account.publicNameRestricted)
            Text(
              widget.ru
                  ? 'Публичное имя скрыто модератором. Сохраните новый ник по правилам; игра и баланс доступны.'
                  : 'Your public name was hidden by a moderator. Save a new name that follows the rules; gameplay and your balance remain available.',
              key: const ValueKey('public-name-restricted'),
              style: const TextStyle(fontSize: 11, color: GameUi.muted),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: fieldHeight,
                  child: TextField(
                    key: const ValueKey('profile-nickname-input'),
                    controller: _controller,
                    enabled: widget.account.ready && !_saving,
                    textInputAction: TextInputAction.done,
                    maxLength: 24,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      labelStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF001B30),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 14,
                      ),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: invalid
                              ? const Color(0xFFB95771)
                              : const Color(0xFFB9F0FF),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: invalid ? const Color(0xFFB95771) : mint,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {
                      _rejected = false;
                      _error = _validation();
                      _actionError = null;
                    }),
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: touch,
                height: fieldHeight,
                child: FilledButton(
                  key: const ValueKey('profile-nickname-save'),
                  style: FilledButton.styleFrom(
                    minimumSize: Size(touch, touch),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: GameUi.text,
                    disabledForegroundColor: GameUi.muted,
                  ).copyWith(backgroundBuilder: _profileSaveLayer),
                  onPressed: canSave ? _save : null,
                  child: Tooltip(
                    message: widget.ru ? 'Сохранить ник' : 'Save nickname',
                    child: Icon(
                      _saving
                          ? Icons.hourglass_top_rounded
                          : Icons.check_rounded,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null)
            SizedBox(
              key: const ValueKey('profile-nickname-message'),
              height: 32 * MediaQuery.textScalerOf(context).scale(11) / 11,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, left: 2),
                child: Text(
                  _error ?? '',
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: _error != null ? GameUi.heart : GameUi.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
