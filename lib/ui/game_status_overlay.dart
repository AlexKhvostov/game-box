import 'package:flutter/material.dart';

/// A status surface shared by action progress, errors and transient messages.
/// Its translucency does not require an expensive backdrop blur during play.
class GameStatusCard extends StatelessWidget {
  const GameStatusCard({
    super.key,
    required this.message,
    this.busy = false,
    this.isError = false,
    this.messageKey,
    this.action,
  });

  final String message;
  final bool busy, isError;
  final Key? messageKey;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final accent = isError ? const Color(0xFFFFBCAC) : const Color(0xFF9FEAFF);
    return Semantics(
      liveRegion: true,
      child: Material(
        color: Colors.transparent,
        child: Container(
          key: const ValueKey('game-status-card'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF062338).withValues(alpha: .92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: .4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      message,
                      key: messageKey,
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (action != null)
                Align(alignment: Alignment.centerRight, child: action!),
            ],
          ),
        ),
      ),
    );
  }
}

/// A route-owned bottom overlay. Status changes never participate in the
/// child's layout, and closing the route disposes its status immediately.
/// Touches pass through unless this status supplies a retry action. The
/// underlying operation retains its own disabled state.
class GameStatusOverlay extends StatefulWidget {
  const GameStatusOverlay({
    super.key,
    required this.child,
    this.message,
    this.busy = false,
    this.isError = false,
    this.messageKey,
    this.action,
  });

  final Widget child;
  final String? message;
  final bool busy, isError;
  final Key? messageKey;
  final Widget? action;

  @override
  State<GameStatusOverlay> createState() => _GameStatusOverlayState();
}

class _GameStatusOverlayState extends State<GameStatusOverlay> {
  final _controller = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    // Attach once while the controller is still detached. Calling show/hide
    // from didUpdateWidget would violate OverlayPortal's build-phase guard.
    // Empty statuses build no surface; the portal still belongs to this route.
    _controller.show();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _controller,
    overlayChildBuilder: (context) =>
        widget.message?.isNotEmpty != true ||
            ModalRoute.isCurrentOf(context) == false
        ? const SizedBox.shrink()
        : Positioned.fill(
            child: IgnorePointer(
              ignoring: widget.action == null,
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: GameStatusCard(
                        message: widget.message ?? '',
                        busy: widget.busy,
                        isError: widget.isError,
                        messageKey: widget.messageKey,
                        action: widget.action,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
    child: widget.child,
  );
}

/// Floating snack bars share the same appearance for short main-screen
/// messages. Floating behavior leaves the game and HUD geometry unchanged.
void showGameStatus(
  BuildContext context, {
  required String message,
  bool isError = false,
  Key? messageKey,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.all(16),
      duration: duration,
      content: GameStatusCard(
        message: message,
        isError: isError,
        messageKey: messageKey,
      ),
    ),
  );
}
