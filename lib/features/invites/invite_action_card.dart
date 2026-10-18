import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_target.dart';
import '../../data/mobile_invites.dart';
import '../../ui/game_ui.dart';
import '../../ui/game_sheet.dart';
import 'invitations_dialog.dart';

class InviteActionCard extends StatefulWidget {
  const InviteActionCard({super.key, this.actions});
  final InvitationActions? actions;

  @override
  State<InviteActionCard> createState() => _InviteActionCardState();
}

class _InviteActionCardState extends State<InviteActionCard> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final invites = context.watch<MobileInvites?>();
    if (invites?.enabled != true ||
        kIsWeb ||
        !AppTargetConfig.isMobile ||
        defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Material(
      key: const ValueKey('invite-action-card'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _opening
            ? null
            : () async {
                if (_opening) return;
                setState(() => _opening = true);
                try {
                  await showInvitationsDialog(context, actions: widget.actions);
                } finally {
                  if (mounted) setState(() => _opening = false);
                }
              },
        child: GamePanel(
          gradient: GameUi.coolPanelGradient,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.group_add_rounded, color: GameUi.ink, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ru ? 'Пригласи друга' : 'Invite a friend',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: GameUi.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ru
                          ? 'По 10 кристаллов обоим после 5 игр'
                          : '10 crystals each after 5 games',
                      style: const TextStyle(
                        fontSize: 11,
                        color: GameUi.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: GameUi.ink,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
