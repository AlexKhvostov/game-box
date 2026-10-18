import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import '../data/google_identity.dart';
import '../data/mobile_account.dart';
import '../data/mobile_invites.dart';
import '../data/player_preferences.dart';
import '../data/audience_policy.dart';
import '../ui/audience_gate.dart';
import 'app_target.dart';
import 'test_tools.dart';

/// Open Google's account chooser once when the first server profile arrives.
/// A slow connection must never interrupt a game or another window.
class GoogleStartupGate extends StatefulWidget {
  const GoogleStartupGate({
    super.key,
    required this.child,
    this.identity,
    this.enabled = true,
  });
  final Widget child;
  final GoogleIdentity? identity;
  final bool enabled;

  @override
  State<GoogleStartupGate> createState() => _GoogleStartupGateState();
}

class _GoogleStartupGateState extends State<GoogleStartupGate> {
  MobileAccount? _account;
  bool _interacted = false;
  bool _finished = false;
  bool _scheduled = false;
  bool _connecting = false;
  bool _agePromptOpen = false;
  late final GoogleIdentity _identity =
      widget.identity ?? NativeGoogleIdentity();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final account = context.read<MobileAccount?>();
    if (_account != account) {
      _account?.removeListener(_schedule);
      _account = account;
      _account?.addListener(_schedule);
    }
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _finished || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_start());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _start() async {
    if (_agePromptOpen) return;
    final preferences = context.read<PlayerPreferences?>();
    final audience = context.read<AudiencePolicy?>();
    // This device-only question also works before a server profile is ready.
    // It does not grant advertising permission or require Google sign-in.
    if (widget.enabled &&
        AppTargetConfig.isMobile &&
        !TestTools.enabled &&
        preferences != null &&
        audience != null &&
        !preferences.ageStartupSeen &&
        ModalRoute.of(context)?.isCurrent == true &&
        !_interacted) {
      _agePromptOpen = true;
      try {
        if (audience.needsSelection) await showAudienceSelection(context);
        await preferences.markAgeStartupSeen();
      } catch (_) {
        debugPrint('Startup: could not persist age prompt state');
      } finally {
        _agePromptOpen = false;
      }
      if (!mounted) return;
    }
    _openChooser();
  }

  void _openChooser() {
    final preferences = context.read<PlayerPreferences?>();
    final account = _account;
    if (!widget.enabled ||
        !AppTargetConfig.isMobile ||
        TestTools.enabled ||
        !_identity.configured ||
        preferences == null ||
        account == null ||
        preferences.googleStartupSeen ||
        !account.onlineAllowed ||
        _interacted) {
      _finished = true;
      context.read<MobileInvites?>()?.markStartupResolved();
      return;
    }
    if (account.googleLinked) {
      _finished = true;
      context.read<MobileInvites?>()?.markStartupResolved();
      return;
    }
    if (!account.ready || account.busy || account.googleStage != null) return;
    _finished = true;
    if (ModalRoute.of(context)?.isCurrent != true) {
      context.read<MobileInvites?>()?.markStartupResolved();
      return;
    }
    // Mark synchronously before opening native UI; cancellation keeps the guest.
    unawaited(
      preferences.markGoogleStartupSeen().catchError((Object _) {
        debugPrint('Google startup: could not persist chooser state');
      }),
    );
    setState(() => _connecting = true);
    unawaited(_connect(account));
  }

  Future<void> _connect(MobileAccount account) async {
    try {
      await account.linkGoogle(_identity);
    } catch (error) {
      if (!mounted) return;
      final canceled =
          error is GoogleSignInException &&
          (error.code == GoogleSignInExceptionCode.canceled ||
              error.code == GoogleSignInExceptionCode.interrupted);
      // The native Back/cancel action is the guest path. No second prompt.
      if (!canceled) {
        final ru = Localizations.localeOf(context).languageCode == 'ru';
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              ru
                  ? 'Google не подключён. Можно играть гостем и подключить его позже в профиле.'
                  : 'Google is not connected. Play as a guest and connect later in your profile.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
        context.read<MobileInvites?>()?.markStartupResolved();
      }
    }
  }

  @override
  void dispose() {
    _account?.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    key: const ValueKey('google-startup-navigation'),
    canPop: !_connecting,
    child: Stack(
      children: [
        AbsorbPointer(
          key: const ValueKey('google-startup-game-input'),
          absorbing: _connecting,
          child: Listener(
            onPointerDown: (_) => _interacted = true,
            child: widget.child,
          ),
        ),
        if (_connecting)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xB8061B2D),
              child: Center(
                child: CircularProgressIndicator(
                  key: ValueKey('google-startup-progress'),
                  semanticsLabel: 'Google',
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
