import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/mobile_invites.dart';
import '../../data/app_analytics.dart';
import '../../ui/energy_widgets.dart';
import '../../ui/game_ui.dart';
import '../../ui/neon_chrome.dart';
import '../../ui/public_name_controls.dart';
import 'inviter_section.dart';

String _tr(BuildContext c, String ru, String en) =>
    Localizations.localeOf(c).languageCode == 'ru' ? ru : en;
const _muted = Color(0xFFA5CAE8);

Future<void> showInvitationHelp(
  BuildContext context,
  int reward,
) => showDialog<void>(
  context: context,
  useRootNavigator: false,
  barrierColor: GameUi.modalBarrier,
  animationStyle: GameUi.windowAnimationStyle,
  builder: (c) => Dialog(
    key: const ValueKey('invitation-help'),
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 390),
      child: NeonGlass(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _tr(
                      c,
                      'Как получить +$reward энергии',
                      'How to earn +$reward energy',
                    ),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(c),
                  tooltip: _tr(c, 'Закрыть', 'Close'),
                  icon: const Icon(Icons.close, color: GameUi.cyan),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final step in [
                      _tr(
                        c,
                        'Передайте другу свой код. Друг введёт его в «Кто пригласил вас».',
                        'Give your friend your code to enter in “Who invited you”.',
                      ),
                      _tr(
                        c,
                        'Друг завершает 5 игр.',
                        'Your friend finishes 5 games.',
                      ),
                      _tr(
                        c,
                        'У обоих подтверждён вход: Google в Android или Telegram в Mini App.',
                        'Both players verify sign-in: Google on Android or Telegram in the Mini App.',
                      ),
                    ].indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: const Color(0xFF075579),
                              child: Text(
                                '${step.$1 + 1}',
                                style: const TextStyle(
                                  color: GameUi.cyan,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                step.$2,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Text(
                      _tr(
                        c,
                        'Награда начисляется автоматически. Пригласившего можно выбрать только один раз.',
                        'Rewards are credited automatically. Choose your inviter only once.',
                      ),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: Text(_tr(c, 'Понятно', 'Got it')),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// E04.A. Values/actions come from the same MobileInvites used by the account.
class CompactInvitations extends StatefulWidget {
  const CompactInvitations({super.key, required this.availableHeight});
  final double availableHeight;
  @override
  State<CompactInvitations> createState() => _CompactInvitationsState();
}

class _CompactInvitationsState extends State<CompactInvitations> {
  bool _expanded = false;
  String? _failure;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run(() async => context.read<MobileInvites?>()?.refresh());
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _failure = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => _failure = _tr(
            context,
            'Нет связи. Повторите загрузку.',
            'No connection. Retry loading.',
          ),
        );
      }
    }
  }

  Widget _box(Widget child) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF042237),
      border: Border.all(color: const Color(0xFF22627B)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );
  Widget _field(String label, String? value, String id, {bool share = false}) =>
      Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ),
          Expanded(
            child: SelectableText(
              value ?? '—',
              maxLines: 1,
              style: TextStyle(
                fontSize: share ? 12 : 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            key: ValueKey('simple-copy-$id'),
            tooltip: _tr(context, 'Копировать', 'Copy'),
            visualDensity: VisualDensity.compact,
            onPressed: value == null
                ? null
                : () => _run(() {
                    AppAnalytics.event('invite_action', {
                      'action': 'copy',
                      'placement': id,
                    });
                    return Clipboard.setData(ClipboardData(text: value));
                  }),
            icon: const Icon(Icons.copy_rounded, color: GameUi.cyan, size: 20),
          ),
          if (share)
            IconButton(
              key: const ValueKey('simple-share-link'),
              tooltip: _tr(context, 'Поделиться', 'Share'),
              visualDensity: VisualDensity.compact,
              onPressed: value == null
                  ? null
                  : () => _run(() async {
                      AppAnalytics.event('invite_action', {
                        'action': 'open_system_share',
                        'placement': 'friends',
                      });
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
              icon: const Icon(Icons.share, color: GameUi.cyan, size: 20),
            ),
        ],
      );
  Widget _row(String? name, String? uid, {int? reward, String? progress}) {
    final display = publicPlayerName(
      context,
      uid,
      name ?? _tr(context, 'Игрок', 'Player'),
    );
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF164158))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: const Color(0xFF155161),
            child: Text(
              display.isEmpty ? '?' : display.characters.first,
              style: const TextStyle(color: GameUi.cyan, fontSize: 12),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: InkWell(
              onTap: () =>
                  showPublicNameActions(context, uid: uid, name: name ?? ''),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (progress != null)
                    Text(
                      progress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: _muted),
                    ),
                ],
              ),
            ),
          ),
          if (reward != null)
            EnergyText(reward, prefix: '+', size: 17)
          else
            Text(
              _tr(context, 'Ожидается', 'Pending'),
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          PublicNameActions(uid: uid, name: name ?? '', compact: true),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MobileInvites?>();
    final state = service?.state;
    final current = state != null && state.profileId == service?.account.id
        ? state
        : null;
    final count = current == null
        ? 0
        : current.paidRows.length + current.pendingRows.length;
    final height = math.min(
      264.0,
      math.max(88.0, widget.availableHeight - (_expanded ? 450 : 330)),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _box(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Column(
              children: [
                _field(_tr(context, 'Код', 'Code'), current?.ownCode, 'code'),
                const Divider(height: 1),
                _field(
                  _tr(context, 'Ссылка', 'Link'),
                  current?.inviteUrl,
                  'link',
                  share: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        _box(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        Text(
                          _tr(context, 'Приглашено ', 'Invited '),
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                        Text(
                          '${current?.invitedCount ?? (current == null ? '—' : count)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: const Color(0xFF22627B),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        Text(
                          _tr(context, 'Получено ', 'Received '),
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                        if (current != null)
                          EnergyText(current.energyRewardTotal, size: 18)
                        else
                          const Text('—'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _tr(context, 'Приглашённые друзья', 'Invited friends'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        _box(
          SizedBox(
            height: height,
            child: ListView(
              key: const ValueKey('simple-invited-list'),
              padding: EdgeInsets.zero,
              children: [
                if (count == 0)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      current == null
                          ? _tr(
                              context,
                              service?.busy == true
                                  ? 'Загрузка…'
                                  : 'Данные недоступны. Повторите загрузку.',
                              service?.busy == true
                                  ? 'Loading…'
                                  : 'Data unavailable. Retry loading.',
                            )
                          : _tr(
                              context,
                              'Приглашённых пока нет',
                              'No invitations yet',
                            ),
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                  ),
                for (final row in current?.paidRows ?? <InvitePaidRow>[])
                  _row(row.nickname, row.userId, reward: row.energyEquivalent),
                for (final row
                    in current?.pendingRows ?? <Map<String, dynamic>>[])
                  _row(
                    row['nickname'] as String?,
                    row['userId'] as String?,
                    progress:
                        '${row['games'] ?? 0} / ${current!.requiredGames} · ${_tr(context, row['identityReady'] == true || row['googleLinked'] == true
                            ? 'Вход подтверждён'
                            : row['bonusStatus'] == 'inviter_unavailable'
                            ? 'Пригласивший недоступен'
                            : 'Нужен вход', row['identityReady'] == true || row['googleLinked'] == true
                            ? 'Sign-in verified'
                            : row['bonusStatus'] == 'inviter_unavailable'
                            ? 'Inviter unavailable'
                            : 'Sign-in needed')}',
                  ),
                if (current != null &&
                    (current.nextCursor != null ||
                        current.pendingNextCursor != null))
                  TextButton(
                    key: const ValueKey('invites-more'),
                    onPressed: service!.busy
                        ? null
                        : () => _run(service.loadMore),
                    child: Text(_tr(context, 'Показать ещё', 'Show more')),
                  ),
              ],
            ),
          ),
        ),
        if (_failure != null || service?.error != null || current == null)
          TextButton(
            key: const ValueKey('invites-retry'),
            onPressed: service == null || service.busy
                ? null
                : () => _run(service.refresh),
            child: Text(_failure ?? _tr(context, 'Повторить', 'Retry')),
          ),
        const SizedBox(height: 7),
        if (service != null)
          _box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  key: const ValueKey('invites-inviter-toggle'),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                          size: 17,
                          color: GameUi.cyan,
                        ),
                        Expanded(
                          child: Text(
                            _tr(
                              context,
                              'Кто пригласил вас',
                              'Who invited you',
                            ),
                            style: const TextStyle(
                              color: GameUi.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: GameUi.cyan,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_expanded)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(9, 0, 9, 8),
                    child: InviterSection(invitations: true),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
