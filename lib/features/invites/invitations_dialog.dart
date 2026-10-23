import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/public_name_controls.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/mobile_invites.dart';
import '../../ui/crystal_cube_icon.dart';
import '../../ui/game_sheet.dart';
import '../../ui/game_toast.dart';
import '../../ui/game_ui.dart';
import '../../ui/game_status_overlay.dart';

/// Injectable only for verification; normal gameplay uses Clipboard and the native share sheet.
class InvitationActions {
  const InvitationActions({this.copy, this.share});
  final Future<void> Function(String text)? copy;
  final Future<ShareResultStatus> Function(String text, Rect origin)? share;

  Future<void> copyText(String text) =>
      copy?.call(text) ?? Clipboard.setData(ClipboardData(text: text));
  Future<ShareResultStatus> shareText(String text, Rect origin) async {
    if (share != null) return share!(text, origin);
    return (await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Untouch', sharePositionOrigin: origin),
    )).status;
  }
}

Future<void> showInvitationsDialog(
  BuildContext context, {
  InvitationActions? actions,
}) {
  final invites = context.read<MobileInvites?>();
  if (invites?.enabled != true) return Future.value();
  return showDialog<void>(
    context: context,
    useRootNavigator: false,
    barrierColor: GameUi.modalBarrier,
    animationStyle: GameUi.windowAnimationStyle,
    builder: (_) => InvitationsDialog(
      invites: invites!,
      actions: actions ?? const InvitationActions(),
    ),
  );
}

class InvitationsDialog extends StatefulWidget {
  const InvitationsDialog({
    super.key,
    required this.invites,
    this.actions = const InvitationActions(),
  });
  final MobileInvites invites;
  final InvitationActions actions;
  @override
  State<InvitationsDialog> createState() => _InvitationsDialogState();
}

class _InvitationsDialogState extends State<InvitationsDialog> {
  static final _compactIconStyle = IconButton.styleFrom(
    minimumSize: const Size.square(36),
    maximumSize: const Size.square(36),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
  final _shareKey = GlobalKey();
  String? _owner, _pageError, _actionError;
  int _viewEpoch = 0;
  bool _refreshing = false,
      _paging = false,
      _sharing = false,
      _infoOpen = false;
  bool _lastCopyWasCode = true;

  String _tr(String ru, String en) =>
      Localizations.localeOf(context).languageCode == 'ru' ? ru : en;

  @override
  void initState() {
    super.initState();
    _owner = widget.invites.account.id;
    widget.invites.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (_owner != widget.invites.account.id) {
        _owner = widget.invites.account.id;
        _viewEpoch++;
        _pageError = null;
        _actionError = null;
        _paging = false;
        _sharing = false;
        _refreshing = false;
      }
    });
  }

  bool _current(String? owner, int epoch) =>
      mounted && epoch == _viewEpoch && widget.invites.account.id == owner;

  bool _payloadCurrent(InviteState expected) {
    final actual = widget.invites.state;
    return mounted &&
        expected.profileId == widget.invites.account.id &&
        actual?.profileId == expected.profileId &&
        actual?.ownCode == expected.ownCode &&
        actual?.inviteUrl == expected.inviteUrl;
  }

  void _unavailable(String? expectedOwner, int expectedEpoch) {
    if (!_current(expectedOwner, expectedEpoch)) return;
    showGameToast(
      context,
      message: _tr('Недоступно в тесте', 'Unavailable in this test'),
      icon: const Icon(
        Icons.info_outline_rounded,
        color: GameUi.cyan,
        size: 26,
      ),
    );
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final owner = _owner, epoch = _viewEpoch;
    setState(() {
      _refreshing = true;
      _actionError = null;
    });
    try {
      await widget.invites.refresh();
    } catch (_) {
      if (_current(owner, epoch)) setState(() => _actionError = 'refresh');
    } finally {
      if (_current(owner, epoch)) setState(() => _refreshing = false);
    }
  }

  Future<void> _more() async {
    if (_paging) return;
    final owner = _owner, epoch = _viewEpoch;
    setState(() {
      _paging = true;
      _pageError = null;
    });
    try {
      await widget.invites.loadMore();
    } catch (_) {
      if (_current(owner, epoch)) setState(() => _pageError = 'page');
    } finally {
      if (_current(owner, epoch)) setState(() => _paging = false);
    }
  }

  Future<void> _copy(InviteState expected, {required bool code}) async {
    if (!_payloadCurrent(expected)) return;
    final value = code ? expected.ownCode : expected.inviteUrl;
    final owner = _owner, epoch = _viewEpoch;
    setState(() {
      _actionError = null;
      _lastCopyWasCode = code;
    });
    try {
      await widget.actions.copyText(value);
      if (!mounted || !_current(owner, epoch)) return;
      showGameToast(
        context,
        message: code
            ? _tr('Код скопирован', 'Code copied')
            : _tr('Ссылка скопирована', 'Link copied'),
        icon: const Icon(Icons.copy_rounded, color: GameUi.cyan, size: 26),
      );
    } catch (_) {
      if (_current(owner, epoch)) setState(() => _actionError = 'copy');
    }
  }

  Future<void> _share(InviteState state) async {
    if (_sharing || !_payloadCurrent(state)) return;
    final owner = _owner, epoch = _viewEpoch;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final text = ru
        ? 'Присоединяйтесь к Untouch!\n${state.inviteUrl}\nКод: ${state.ownCode}\nПо 10 кристаллов каждому: друг завершает 5 игр. Для бонуса у обоих должен быть подключён Google.'
        : 'Join me in Untouch!\n${state.inviteUrl}\nCode: ${state.ownCode}\n10 crystals each: your friend finishes 5 games. Both players need Google connected to receive the bonus.';
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 48, 48)
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _sharing = true;
      _actionError = null;
    });
    try {
      final status = await widget.actions.shareText(text, origin);
      if (_current(owner, epoch) && status == ShareResultStatus.unavailable) {
        setState(() => _actionError = 'share');
      }
      // A successful share-sheet result is not a delivered/activated invitation or a reward.
    } catch (_) {
      if (_current(owner, epoch)) setState(() => _actionError = 'share');
    } finally {
      if (_current(owner, epoch)) setState(() => _sharing = false);
    }
  }

  Future<void> _showInfo() async {
    if (_infoOpen) return;
    setState(() => _infoOpen = true);
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: false,
        barrierColor: GameUi.modalBarrier,
        animationStyle: GameUi.windowAnimationStyle,
        builder: (_) => Dialog(
          key: const ValueKey('invitation-info-dialog'),
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: GameSheetChrome(
              modal: true,
              fitContent: true,
              glass: GameGlass.none,
              backgroundGradient: GameUi.navySheetGradient,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.2,
                      child: GameSheetHeader(
                        title: _tr('Как пригласить', 'Invite a friend'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          _tr(
                            'Отправьте другу ссылку или код. Друг устанавливает Untouch и при необходимости вводит код в аккаунте. Код закрепляется один раз. После 5 завершённых игр друга — по 10 кристаллов каждому, если Google подключён у обоих. Уже завершённые игры учитываются.',
                            'Send your friend the link or code. They install Untouch and, if needed, enter the code in Account. A valid code is fixed once. After your friend finishes 5 games, you each receive 10 crystals if both players have Google connected. Previous finished games count.',
                          ),
                          key: const ValueKey('invitation-info-rules'),
                          style: const TextStyle(
                            color: GameUi.text,
                            fontSize: 13,
                            height: 1.35,
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
    } finally {
      if (mounted) setState(() => _infoOpen = false);
    }
  }

  @override
  void dispose() {
    widget.invites.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.invites;
    final cached = service.state;
    final state = cached?.profileId == service.account.id ? cached : null;
    final loading = _refreshing || service.busy;
    final error = _actionError ?? (state == null ? null : service.error);
    final owner = service.account.id;
    final epoch = _viewEpoch;
    final unavailable = _tr('Недоступно в тесте', 'Unavailable in this test');
    final pageError = error == null && _pageError != null;
    final pending = loading || _paging;
    final statusMessage = pending
        ? _tr('Обновляем…', 'Refreshing…')
        : error == 'invites_unavailable'
        ? _tr(
            'Приглашения пока недоступны.',
            'Invitations are unavailable for now.',
          )
        : error == 'copy'
        ? _tr('Не удалось скопировать.', 'Could not copy.')
        : error == 'share'
        ? _tr(
            'Не удалось открыть отправку. Можно скопировать ссылку.',
            'Could not open sharing. You can copy the link.',
          )
        : error != null
        ? _tr(
            'Не удалось обновить. Проверьте соединение.',
            'Could not refresh. Check your connection.',
          )
        : pageError
        ? _tr(
            'Не удалось загрузить ещё. Бонусы сохранены.',
            'Could not load more. Your earned rewards are still here.',
          )
        : null;
    final retry = error == 'copy' && state != null
        ? () => unawaited(_copy(state, code: _lastCopyWasCode))
        : error == 'share' && state != null
        ? () => unawaited(_share(state))
        : pageError
        ? _more
        : _refresh;
    return GameStatusOverlay(
      message: statusMessage,
      messageKey: ValueKey(
        pending
            ? 'invitations-loading'
            : pageError
            ? 'invitation-page-error'
            : 'invitations-error',
      ),
      busy: pending,
      isError: !pending && statusMessage != null,
      action: !pending && statusMessage != null
          ? TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_tr('Повторить', 'Retry')),
            )
          : null,
      child: Dialog(
        key: const ValueKey('invitations-dialog'),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: GameSheetChrome(
            modal: true,
            fitContent: true,
            glass: GameGlass.none,
            backgroundGradient: GameUi.navySheetGradient,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.2,
                    child: GameSheetHeader(
                      title: _tr('Приглашения', 'Invitations'),
                      trailing: IconButton(
                        key: const ValueKey('invitation-info'),
                        tooltip: _tr(
                          'Как пригласить друга',
                          'How to invite a friend',
                        ),
                        padding: const EdgeInsets.all(4),
                        style: _compactIconStyle,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: _infoOpen ? null : _showInfo,
                        icon: const Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: GameUi.cyan,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: ListView(
                      key: const ValueKey('invitations-scroll'),
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        _InvitePanel(
                          key: const ValueKey('invitation-invite-group'),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _tr('Пригласить', 'Invite'),
                                style: const TextStyle(
                                  color: GameUi.cyan,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _tr('Ваш код', 'Your code'),
                                          style: const TextStyle(
                                            color: GameUi.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            state?.ownCode ?? unavailable,
                                            key: const ValueKey(
                                              'invitation-own-code',
                                            ),
                                            style: const TextStyle(
                                              color: GameUi.text,
                                              fontSize: 18,
                                              letterSpacing: .5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    key: const ValueKey('invitation-copy-code'),
                                    tooltip: _tr('Копировать код', 'Copy code'),
                                    padding: const EdgeInsets.all(4),
                                    style: _compactIconStyle,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    onPressed: () => state == null
                                        ? _unavailable(owner, epoch)
                                        : _copy(state, code: true),
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      color: GameUi.cyan,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 4, color: GameUi.line),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _tr('Ваша ссылка', 'Your link'),
                                          style: const TextStyle(
                                            color: GameUi.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          state?.inviteUrl ?? unavailable,
                                          key: const ValueKey(
                                            'invitation-own-link',
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: GameUi.text,
                                            fontSize: 12,
                                            height: 1.15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    key: const ValueKey('invitation-copy-link'),
                                    tooltip: _tr(
                                      'Копировать ссылку',
                                      'Copy link',
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    style: _compactIconStyle,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    onPressed: () => state == null
                                        ? _unavailable(owner, epoch)
                                        : _copy(state, code: false),
                                    icon: const Icon(
                                      Icons.link_rounded,
                                      color: GameUi.cyan,
                                      size: 20,
                                    ),
                                  ),
                                  IconButton(
                                    key: _shareKey,
                                    tooltip: _tr('Поделиться', 'Share'),
                                    padding: const EdgeInsets.all(4),
                                    style: _compactIconStyle,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    onPressed: _sharing
                                        ? null
                                        : () => state == null
                                              ? _unavailable(owner, epoch)
                                              : _share(state),
                                    icon: const Icon(
                                      Icons.ios_share_rounded,
                                      key: ValueKey('invitation-share'),
                                      color: GameUi.cyan,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        _InvitePanel(
                          key: const ValueKey('invitation-history-group'),
                          accent: GameUi.mint,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _tr(
                                        'Начисленные бонусы',
                                        'Reward history',
                                      ),
                                      style: const TextStyle(
                                        color: GameUi.mint,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const CrystalCubeIcon(
                                    size: 16,
                                    glow: false,
                                    onLightBackground: false,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        state == null
                                            ? '—'
                                            : '${state.rewardTotal}',
                                        key: state == null
                                            ? null
                                            : const ValueKey(
                                                'invitation-reward-total',
                                              ),
                                        style: const TextStyle(
                                          color: GameUi.text,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (state == null)
                                Text(
                                  _tr(
                                    'История пока недоступна.',
                                    'History is not available yet.',
                                  ),
                                  style: const TextStyle(
                                    color: GameUi.muted,
                                    fontSize: 12,
                                  ),
                                )
                              else ...[
                                if (state.paidRows.isEmpty)
                                  Text(
                                    _tr(
                                      'Пока нет начисленных бонусов.',
                                      'No invitation rewards yet.',
                                    ),
                                    key: const ValueKey(
                                      'invitation-history-empty',
                                    ),
                                    style: const TextStyle(
                                      color: GameUi.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                for (final row in state.paidRows)
                                  _PaidRow(
                                    row: row,
                                    removedLabel: _tr(
                                      'Игрок удалён',
                                      'Deleted player',
                                    ),
                                  ),
                                if (state.nextCursor != null)
                                  OutlinedButton.icon(
                                    key: const ValueKey('invitation-load-more'),
                                    onPressed: _paging ? null : _more,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: GameUi.ink,
                                      minimumSize: const Size.fromHeight(48),
                                      side: const BorderSide(
                                        color: GameUi.line,
                                      ),
                                    ),
                                    icon: _paging
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.expand_more_rounded),
                                    label: Text(
                                      _tr(
                                        _paging ? 'Загружаем…' : 'Показать ещё',
                                        _paging ? 'Loading…' : 'Load more',
                                      ),
                                    ),
                                  ),
                              ],
                            ],
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
      ),
    );
  }
}

class _PaidRow extends StatelessWidget {
  const _PaidRow({required this.row, required this.removedLabel});
  final InvitePaidRow row;
  final String removedLabel;
  @override
  Widget build(BuildContext context) => _InvitePanel(
    key: ValueKey('invitation-paid-${row.id}'),
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        const Icon(Icons.person_outline_rounded, color: GameUi.cyan, size: 22),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                publicPlayerName(
                  context,
                  row.userId,
                  row.nickname ?? removedLabel,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GameUi.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                MaterialLocalizations.of(context).formatMediumDate(
                  DateTime.fromMillisecondsSinceEpoch(row.rewardedAt).toLocal(),
                ),
                style: const TextStyle(color: GameUi.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        const CrystalCubeIcon(size: 16, glow: false, onLightBackground: false),
        const SizedBox(width: 4),
        Text(
          '+${row.amount}',
          style: const TextStyle(
            color: GameUi.mint,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        PublicNameActions(
          uid: row.userId,
          name: row.nickname ?? removedLabel,
          compact: true,
        ),
      ],
    ),
  );
}

/// Like crystal package cards: an opaque navy surface protects every label
/// from the window underneath, with a restrained accent border and no sheen.
class _InvitePanel extends StatelessWidget {
  const _InvitePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(6),
    this.margin,
    this.accent = GameUi.cyan,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    margin: margin,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF143B53), Color(0xFF0A2B43), Color(0xFF071F34)],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: .55)),
    ),
    child: child,
  );
}
