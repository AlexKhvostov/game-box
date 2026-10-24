import 'dart:async';
import 'package:flutter/material.dart';
import '../data/android_updates.dart';
import 'android_update_neon.dart';
import 'game_ui.dart';

/// The game allows prompts before a round or while presenting its result.
/// Route/lifecycle checks also protect other windows, startup, and round start.
class AndroidUpdateHost extends StatefulWidget {
  const AndroidUpdateHost({
    super.key,
    required this.controller,
    required this.safeToInterrupt,
    required this.child,
  });
  final AndroidUpdates? controller;
  final bool safeToInterrupt;
  final Widget child;
  @override
  State<AndroidUpdateHost> createState() => _AndroidUpdateHostState();
}

class _AndroidUpdateHostState extends State<AndroidUpdateHost>
    with WidgetsBindingObserver {
  bool _scheduled = false, _promptOpen = false;
  bool _foreground = true;
  Timer? _successTimer;
  bool _successVisible = false, _successShown = false;
  bool get _safe =>
      mounted &&
      widget.safeToInterrupt &&
      _foreground &&
      ModalRoute.isCurrentOf(context) == true;
  bool get _ru => Localizations.localeOf(context).languageCode == 'ru';

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.controller?.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(AndroidUpdateHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_changed);
      widget.controller?.addListener(_changed);
    }
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(widget.controller?.refresh());
    if (mounted) setState(() {});
    _schedule();
  }

  void _changed() {
    if (mounted) {
      setState(() {});
      _schedule();
    }
  }

  void _schedule() {
    if (_scheduled || !mounted || widget.controller == null) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_safe || _promptOpen) return;
      final controller = widget.controller!;
      if (controller.successNotice && !_successShown) {
        _successShown = true;
        setState(() => _successVisible = true);
        _successTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _successVisible = false);
        });
      }
      final prompt = controller.prompt;
      if (prompt != null) unawaited(_open(prompt));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _open(UpdatePrompt prompt) async {
    final controller = widget.controller;
    if (controller == null || controller.busy || !_safe || _promptOpen) return;
    _promptOpen = true;
    controller.markPromptShown(prompt);
    final accepted = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xD9000C1A),
      animationStyle: GameUi.windowAnimationStyle,
      builder: (_) => AndroidUpdateDialog(prompt: prompt, russian: _ru),
    );
    _promptOpen = false;
    if (!mounted) return;
    if (accepted != true) {
      await controller.defer(prompt);
    } else if (_safe) {
      switch (prompt) {
        case UpdatePrompt.available:
          await controller.download();
        case UpdatePrompt.ready:
          await controller.install(isSafe: () => _safe);
        case UpdatePrompt.failed:
          await controller.retry();
      }
    }
    if (mounted) {
      setState(() {});
      _schedule();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    _successTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null) return widget.child;
    final safe = _safe;
    final locked =
        controller.busy || controller.phase == UpdatePhase.installing;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (safe &&
            !_promptOpen &&
            !locked &&
            (controller.phase == UpdatePhase.downloading ||
                controller.phase == UpdatePhase.ready ||
                controller.phase == UpdatePhase.available ||
                _successVisible))
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: AndroidUpdateBanner(
                    phase: controller.phase,
                    russian: _ru,
                    progress: controller.progress,
                    downloadedBytes: controller.info.downloadedBytes,
                    totalBytes: controller.info.totalBytes,
                    success: _successVisible,
                    onPressed: () => unawaited(
                      _open(
                        controller.phase == UpdatePhase.ready
                            ? UpdatePrompt.ready
                            : UpdatePrompt.available,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (safe && locked) ...[
          const ModalBarrier(dismissible: false, color: GameUi.modalBarrier),
          const Center(
            child: CircularProgressIndicator(
              key: ValueKey('update-working'),
              color: GameUi.cyan,
            ),
          ),
        ],
      ],
    );
  }
}

class AndroidUpdateDialog extends StatelessWidget {
  const AndroidUpdateDialog({
    super.key,
    required this.prompt,
    required this.russian,
  });
  final UpdatePrompt prompt;
  final bool russian;
  @override
  Widget build(BuildContext context) {
    final ru = russian;
    final title = switch (prompt) {
      UpdatePrompt.available =>
        ru ? 'Вышла новая версия' : 'A new version is available',
      UpdatePrompt.ready => ru ? 'Установить обновление?' : 'Install update?',
      UpdatePrompt.failed => ru ? 'Не удалось обновить' : 'Could not update',
    };
    final body = switch (prompt) {
      UpdatePrompt.available =>
        ru
            ? 'Обновите Untouch, чтобы получить последние улучшения. Загрузка пройдёт в фоне.'
            : 'Get the latest Untouch improvements. The update will download in the background.',
      UpdatePrompt.ready =>
        ru
            ? 'Новая версия загружена. Перезапустить игру и установить обновление?'
            : 'The new version is downloaded. Restart the game and install it?',
      UpdatePrompt.failed =>
        ru
            ? 'Проверьте интернет и свободное место, затем попробуйте ещё раз. Играть можно в текущей версии.'
            : 'Check your connection and free space, then try again. You can keep playing the current version.',
    };
    final primary = switch (prompt) {
      UpdatePrompt.available => ru ? 'Скачать' : 'Download',
      UpdatePrompt.ready =>
        ru ? 'Перезапустить и обновить' : 'Restart and update',
      UpdatePrompt.failed => ru ? 'Повторить' : 'Retry',
    };
    return Dialog(
      key: ValueKey('update-dialog-${prompt.name}'),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: UpdateNeonSurface(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 5, 9, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ru ? 'Обновление' : 'Update',
                          style: const TextStyle(
                            color: Color(0xFFF1F3FF),
                            fontFamily: 'Roboto',
                            fontSize: 20,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(color: Color(0x66397EFF), blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                      SizedBox.square(
                        dimension: 44,
                        child: IconButton(
                          key: const ValueKey('update-close'),
                          tooltip: ru ? 'Закрыть окно' : 'Close window',
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF55D5FF),
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UpdateNeonSeal(
                        ready: prompt == UpdatePrompt.ready,
                        failed: prompt == UpdatePrompt.failed,
                        size: MediaQuery.sizeOf(context).width < 350
                            ? 76
                            : prompt == UpdatePrompt.failed
                            ? 82
                            : 98,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 22,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF1F3FF),
                          shadows: [
                            Shadow(color: Color(0x66397EFF), blurRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFFB7D8E9),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _UpdateButton(
                        label: primary,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                      TextButton(
                        key: const ValueKey('update-later'),
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00DFFF),
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: Text(
                          ru ? 'Позже' : 'Later',
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFF00DFFF),
                          ),
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
    );
  }
}

class AndroidUpdateBanner extends StatelessWidget {
  const AndroidUpdateBanner({
    super.key,
    required this.phase,
    required this.russian,
    required this.onPressed,
    this.progress,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.success = false,
  });
  final UpdatePhase phase;
  final bool russian, success;
  final double? progress;
  final int downloadedBytes, totalBytes;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final ru = russian;
    final downloading = phase == UpdatePhase.downloading;
    final ready = phase == UpdatePhase.ready;
    if (!success && (downloading || ready)) {
      return Material(
        color: Colors.transparent,
        child: _UpdateProgressBanner(
          russian: ru,
          ready: ready,
          progress: progress,
          onPressed: onPressed,
        ),
      );
    }
    if (success) {
      return Material(
        key: const ValueKey('update-banner'),
        color: Colors.transparent,
        child: UpdateNeonSurface(
          radius: 14,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const UpdateNeonSeal(ready: true, failed: false, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ru ? 'Untouch обновлён' : 'Untouch updated',
                        style: const TextStyle(
                          color: Color(0xFFF1F3FF),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        ru ? 'Можно играть!' : 'Ready to play!',
                        style: const TextStyle(
                          color: Color(0xFFA9CFE1),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final title = success
        ? (ru ? 'Untouch обновлён' : 'Untouch updated')
        : (ru ? 'Доступна новая версия' : 'A new version is available');
    return Material(
      key: const ValueKey('update-banner'),
      color: Colors.transparent,
      child: UpdateNeonSurface(
        radius: 14,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF1F3FF),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                success
                    ? (ru ? 'Можно играть!' : 'Ready to play!')
                    : (ru
                          ? 'Установите, когда будет удобно'
                          : 'Update when it suits you'),
                style: const TextStyle(color: Color(0xFFA9CFE1), fontSize: 13),
              ),
              if (!success) ...[
                const SizedBox(height: 10),
                _UpdateButton(
                  label: ru ? 'Скачать' : 'Download',
                  onPressed: onPressed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The downloaded package retains the same quiet appearance as the download.
/// It opens a confirmation on tap; reaching100% never installs by itself.
class _UpdateProgressBanner extends StatelessWidget {
  const _UpdateProgressBanner({
    required this.russian,
    required this.ready,
    required this.progress,
    required this.onPressed,
  });
  final bool russian, ready;
  final double? progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final value = ready ? 1.0 : progress?.clamp(0.0, 1.0);
    final label = ready
        ? (russian ? 'Обновление загружено' : 'Update downloaded')
        : (russian ? 'Обновление' : 'Update');
    final content = Container(
      key: const ValueKey('update-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF06131F),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8CA5B7),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value == null ? '…' : '${(value * 100).floor()}%',
                style: const TextStyle(color: Color(0xFF8CA5B7), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            key: const ValueKey('update-download-progress'),
            value: value,
            minHeight: 2,
            color: const Color(0xFF4B8296),
            backgroundColor: const Color(0xFF1B3041),
            semanticsLabel: label,
          ),
        ],
      ),
    );
    if (!ready) return IgnorePointer(child: content);
    return Semantics(
      button: true,
      label: russian
          ? 'Обновление загружено. Открыть подтверждение установки'
          : 'Update downloaded. Open installation confirmation',
      child: GestureDetector(
        key: const ValueKey('update-ready-action'),
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: content,
        ),
      ),
    );
  }
}

class _UpdateButton extends StatelessWidget {
  const _UpdateButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) =>
      UpdateNeonButton(label: label, onPressed: onPressed);
}
