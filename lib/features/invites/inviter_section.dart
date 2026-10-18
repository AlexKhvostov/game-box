import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../app/app_target.dart';
import '../../data/invite_code.dart';
import '../../data/mobile_account.dart';
import '../../data/mobile_invites.dart';
import '../../ui/game_ui.dart';
import '../../ui/neon_chrome.dart';

/// The existing profile owns its panel and scroll; this section owns only invitations.
class InviterSection extends StatefulWidget {
  const InviterSection({super.key, this.compact = false});
  final bool compact;

  static bool available(BuildContext context) =>
      !kIsWeb &&
      AppTargetConfig.isMobile &&
      defaultTargetPlatform == TargetPlatform.android &&
      context.select<MobileInvites?, bool>(
        (service) => service?.enabled == true,
      );

  @override
  State<InviterSection> createState() => _InviterSectionState();
}

class _InviterSectionState extends State<InviterSection> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final MobileInvites _service;
  String? _owner, _error;
  int _epoch = 0;
  bool _applying = false, _refreshing = false, _infoOpen = false;

  String _tr(String ru, String en) =>
      Localizations.localeOf(context).languageCode == 'ru' ? ru : en;

  @override
  void initState() {
    super.initState();
    _service = context.read<MobileInvites>();
    _owner = _service.account.id;
    _service.addListener(_changed);
    _service.account.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  void _changed() {
    if (!mounted) return;
    if (_owner != _service.account.id) {
      _owner = _service.account.id;
      _epoch++;
      _code.clear();
      _focus.unfocus();
      _error = null;
      _applying = false;
      _refreshing = false;
    }
    if (_state?.inviterAssigned == true) {
      // An automatic link can fix the inviter after a failed manual draft.
      // Discard only obsolete input feedback; the service's current error stays visible.
      if ({
        'empty',
        'invite_code_invalid',
        'invite_not_found',
        'invite_self',
        'invite_already_bound',
      }.contains(_error)) {
        _error = null;
      }
      if (_code.text.isNotEmpty) _code.clear();
      _focus.unfocus();
    }
    setState(() {});
  }

  bool _current(String? owner, int epoch) =>
      mounted && _service.account.id == owner && _epoch == epoch;

  InviteState? get _state =>
      _service.state?.profileId == _service.account.id ? _service.state : null;

  bool get _blocked =>
      _applying ||
      _refreshing ||
      _service.busy ||
      _service.account.busy ||
      _service.account.googleStage != null ||
      !_service.account.ready ||
      !_service.account.onlineAllowed;

  Future<void> _refresh() async {
    if (_refreshing || _applying) return;
    final owner = _owner, epoch = _epoch;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await _service.refresh();
    } catch (_) {
      if (_current(owner, epoch)) setState(() => _error = 'network');
    } finally {
      if (_current(owner, epoch)) setState(() => _refreshing = false);
    }
  }

  Future<void> _apply(String? expectedOwner) async {
    // A saved pre-rebuild callback must never submit the previous owner's text.
    if (!mounted ||
        expectedOwner != _service.account.id ||
        _blocked ||
        _state?.inviterAssigned == true) {
      return;
    }
    final normalized = InviteCode.normalize(_code.text);
    if (normalized == null) {
      setState(
        () => _error = _code.text.trim().isEmpty
            ? 'empty'
            : 'invite_code_invalid',
      );
      return;
    }
    final owner = expectedOwner, epoch = _epoch;
    setState(() {
      _applying = true;
      _error = null;
    });
    try {
      await _service.bindManual(normalized);
      if (!_current(owner, epoch)) return;
      if (_state?.inviterAssigned == true) {
        _code.clear();
        _focus.unfocus();
      } else {
        setState(() => _error = 'network');
      }
    } catch (failure) {
      if (!_current(owner, epoch)) return;
      // A committed server binding remains fixed if a later local refresh/storage fails.
      if (_state?.inviterAssigned == true) {
        _code.clear();
        _focus.unfocus();
      } else {
        setState(
          () => _error = failure is MobileApiError ? failure.code : 'network',
        );
      }
    } finally {
      if (_current(owner, epoch)) setState(() => _applying = false);
    }
  }

  String _message(String error) => switch (error) {
    'empty' => _tr('Введите код пригласившего.', 'Enter your inviter’s code.'),
    'invite_code_invalid' => _tr(
      'Код состоит из 6 или 12 латинских букв и цифр. Проверьте его.',
      'The code has 6 or 12 Latin letters and digits. Please check it.',
    ),
    'invite_not_found' => _tr(
      'Такого кода нет. Уточните код у друга и попробуйте снова.',
      'This code does not exist. Check it with your friend and try again.',
    ),
    'invite_self' => _tr(
      'Это ваш собственный код. Введите код другого игрока.',
      'This is your own code. Enter another player’s code.',
    ),
    'invite_already_bound' => _tr(
      'Пригласивший уже закреплён. Обновите данные.',
      'Your inviter is already fixed. Refresh to see the details.',
    ),
    'profile_changed' || 'profile_unavailable' || 'online_disabled' => _tr(
      'Дождитесь загрузки текущего профиля и попробуйте снова.',
      'Wait for the current profile to load, then try again.',
    ),
    'invites_unavailable' ||
    'action_invalid' ||
    'invite_schema_not_ready' => _tr(
      'Приглашения пока недоступны. Попробуйте позже.',
      'Invitations are unavailable for now. Try again later.',
    ),
    _ => _tr(
      'Не удалось проверить код. Проверьте соединение и попробуйте снова.',
      'Could not check the code. Check your connection and try again.',
    ),
  };

  @override
  void dispose() {
    _service.removeListener(_changed);
    _service.account.removeListener(_changed);
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _showInfo() async {
    if (_infoOpen) return;
    _focus.unfocus();
    setState(() => _infoOpen = true);
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: false,
        barrierColor: GameUi.modalBarrier,
        animationStyle: GameUi.windowAnimationStyle,
        builder: (_) => Dialog(
          key: const ValueKey('inviter-info-dialog'),
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AccountGlass(
              radius: 20,
              padding: const EdgeInsets.all(6),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.2,
                      child: NeonSheetHeader(
                        title: _tr('Код пригласившего', 'Inviter code'),
                        titleSize: 19,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: SingleChildScrollView(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _service,
                            _service.account,
                          ]),
                          builder: (_, _) {
                            final current = _state;
                            final error = _error ?? _service.error;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Column(
                                  key: const ValueKey('inviter-rules'),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _tr(
                                        'Друг пригласил вас?',
                                        'Invited by a friend?',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: GameUi.text,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _tr(
                                        'Код состоит из 6 или 12 латинских букв и цифр и закрепляется один раз.',
                                        'The code has 6 or 12 Latin letters and digits and is fixed once.',
                                      ),
                                      style: const TextStyle(
                                        color: GameUi.text,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _InviteRuleStep(
                                      '1',
                                      _tr(
                                        'Введите код друга в аккаунте.',
                                        'Enter your friend’s code in your account.',
                                      ),
                                    ),
                                    _InviteRuleStep(
                                      '2',
                                      _tr(
                                        'Завершите 5 игр. Предыдущие игры учитываются.',
                                        'Finish 5 games. Previous finished games count.',
                                      ),
                                    ),
                                    _InviteRuleStep(
                                      '3',
                                      _tr(
                                        'Подключите Google — вы и друг.',
                                        'Both you and your friend connect Google.',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _tr(
                                        'Награда начисляется после выполнения действующих условий игры.',
                                        'The reward is granted after meeting the current game rules.',
                                      ),
                                      style: const TextStyle(
                                        color: GameUi.muted,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                                if (error != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _message(error),
                                    key: const ValueKey('inviter-info-error'),
                                    style: const TextStyle(
                                      color: GameUi.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    key: const ValueKey('inviter-retry'),
                                    onPressed: _blocked ? null : _refresh,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      foregroundColor: GameUi.text,
                                    ),
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                    ),
                                    label: Text(_tr('Повторить', 'Retry')),
                                  ),
                                ],
                                if (current?.inviterAssigned == true) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    current!.bonusStatus == 'rewarded'
                                        ? _tr(
                                            'Бонус начислен: по 10 кристаллов вам и другу.',
                                            'Reward credited: 10 crystals for you and your friend.',
                                          )
                                        : _tr(
                                            'Код закреплён и больше не меняется.',
                                            'This code is fixed and cannot be changed.',
                                          ),
                                    key: const ValueKey('inviter-success'),
                                    style: const TextStyle(
                                      color: GameUi.mint,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                FilledButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(_tr('Понятно', 'Got it')),
                                ),
                              ],
                            );
                          },
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
    } finally {
      if (mounted) setState(() => _infoOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final owner = _service.account.id;
    final error = _error;
    final loading = _refreshing || _service.busy || _applying;
    final assigned = state?.inviterAssigned == true;
    final hint = _tr('Введите код', 'Enter code');
    final decoration = InputDecoration(
      labelText: widget.compact
          ? null
          : _tr('Код пригласившего', 'Inviter code'),
      labelStyle: const TextStyle(color: GameUi.muted, fontSize: 13),
      floatingLabelBehavior: widget.compact || assigned || state == null
          ? FloatingLabelBehavior.always
          : FloatingLabelBehavior.auto,
      hintText: hint,
      hintStyle: const TextStyle(color: GameUi.muted, fontSize: 13),
      isDense: true,
      filled: true,
      fillColor: widget.compact
          ? const Color(0xFF001B30)
          : const Color(0xFF10364E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      constraints: const BoxConstraints(minHeight: 48),
      prefixIcon: loading
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                key: ValueKey('inviter-loading'),
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF37CBE9)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF37CBE9)),
      ),
    );
    final editor = assigned
        ? InputDecorator(
            decoration: decoration,
            child: SelectableText(
              state!.inviterCode!,
              key: const ValueKey('inviter-locked-code'),
              style: const TextStyle(
                color: GameUi.cyan,
                fontSize: 16,
                letterSpacing: .4,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        : TextField(
            key: const ValueKey('inviter-code-field'),
            controller: _code,
            focusNode: _focus,
            enabled: !_blocked,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            inputFormatters: [LengthLimitingTextInputFormatter(64)],
            style: const TextStyle(color: GameUi.text, fontSize: 16),
            decoration: decoration,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => unawaited(_apply(owner)),
          );
    // Independent of the editor: disabled/busy/readonly must keep info available.
    final info = IconButton(
      key: const ValueKey('inviter-info'),
      tooltip: _tr('О приглашениях', 'About invitations'),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: const EdgeInsets.all(8),
      onPressed: _infoOpen ? null : _showInfo,
      icon: const Icon(
        Icons.info_outline_rounded,
        color: GameUi.cyan,
        size: 20,
      ),
    );
    final apply = FilledButton(
      key: const ValueKey('inviter-apply'),
      style: FilledButton.styleFrom(
        foregroundColor: widget.compact ? GameUi.text : GameUi.ink,
        disabledForegroundColor: GameUi.muted,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: _blocked ? null : () => unawaited(_apply(owner)),
      child: widget.compact
          ? Tooltip(
              message: _tr(
                _applying ? 'Проверяем…' : 'Применить',
                _applying ? 'Checking…' : 'Apply',
              ),
              child: Icon(
                _applying ? Icons.hourglass_top_rounded : Icons.check_rounded,
                color: Colors.white,
                size: 22,
              ),
            )
          : Text(
              _tr(
                _applying ? 'Проверяем…' : 'Применить',
                _applying ? 'Checking…' : 'Apply',
              ),
            ),
    );
    return Column(
      key: const ValueKey('profile-inviter-section'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.compact)
          Row(
            children: [
              Expanded(
                child: Text(
                  _tr('Код пригласившего', 'Inviter code'),
                  style: const TextStyle(fontSize: 11, color: GameUi.muted),
                ),
              ),
              info,
            ],
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final inline =
                assigned ||
                ((widget.compact || constraints.maxWidth >= 300) &&
                    MediaQuery.textScalerOf(context).scale(14) <= 19.6);
            final fieldAndInfo = Row(
              children: [
                Expanded(child: editor),
                if (!widget.compact) info,
              ],
            );
            return inline
                ? Row(
                    children: [
                      Expanded(child: editor),
                      if (!widget.compact) info,
                      if (widget.compact && !assigned) const SizedBox(width: 7),
                      if (!assigned)
                        SizedBox(width: widget.compact ? 48 : 96, child: apply),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [fieldAndInfo, apply],
                  );
          },
        ),
        if (!assigned && error != null)
          Text(
            switch (error) {
              'empty' => _tr('Введите код.', 'Enter a code.'),
              'invite_code_invalid' => _tr(
                '6 или 12 латинских букв и цифр.',
                '6 or 12 Latin letters and digits.',
              ),
              'invite_not_found' => _tr('Такого кода нет.', 'Code not found.'),
              'invite_self' => _tr('Это ваш код.', 'This is your code.'),
              'invite_already_bound' => _tr(
                'Код уже закреплён. Обновите в i.',
                'Code already fixed. Refresh from i.',
              ),
              'profile_changed' || 'profile_unavailable' || 'online_disabled' =>
                _tr('Дождитесь профиля.', 'Wait for your profile.'),
              'invites_unavailable' ||
              'action_invalid' ||
              'invite_schema_not_ready' => _tr(
                'Недоступно в тесте',
                'Unavailable in this test',
              ),
              _ => _tr(
                'Нет связи. Повторить можно в i.',
                'No connection. Retry from i.',
              ),
            },
            key: const ValueKey('inviter-error'),
            style: const TextStyle(color: GameUi.muted, fontSize: 12),
          ),
      ],
    );
  }
}

class _InviteRuleStep extends StatelessWidget {
  const _InviteRuleStep(this.number, this.text);
  final String number, text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF075579),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GameUi.cyan),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: GameUi.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: GameUi.text,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
