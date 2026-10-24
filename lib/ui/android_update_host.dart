import 'dart:async';
import 'package:flutter/material.dart';
import '../data/android_updates.dart';
import 'game_ui.dart';

/// The game decides when it is idle. Route/lifecycle checks also protect other
/// windows, Google startup, result presentation, and a new round starting.
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
      barrierColor: GameUi.modalBarrier,
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
        if (locked) ...[
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
      UpdatePrompt.ready => ru ? 'Обновление готово' : 'Update ready',
      UpdatePrompt.failed => ru ? 'Не удалось обновить' : 'Could not update',
    };
    final body = switch (prompt) {
      UpdatePrompt.available =>
        ru
            ? 'Обновите Untouch, чтобы получить последние улучшения. Загрузка пройдёт в фоне.'
            : 'Get the latest Untouch improvements. The update will download in the background.',
      UpdatePrompt.ready =>
        ru
            ? 'Осталось перезапустить игру, чтобы установить новую версию.'
            : 'Restart the game to install the new version.',
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF123E57), Color(0xFF062337)],
            ),
            border: Border.all(
              color: prompt == UpdatePrompt.failed
                  ? const Color(0xFFCC9C72)
                  : GameUi.line,
            ),
            borderRadius: BorderRadius.circular(23),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D4B5C),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: GameUi.line),
                  ),
                  child: Icon(
                    switch (prompt) {
                      UpdatePrompt.available => Icons.download_rounded,
                      UpdatePrompt.ready => Icons.check_rounded,
                      UpdatePrompt.failed => Icons.priority_high_rounded,
                    },
                    color: GameUi.mint,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 23,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: GameUi.text,
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
                    color: GameUi.muted,
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
                    foregroundColor: GameUi.muted,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(ru ? 'Позже' : 'Later'),
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
    final title = success
        ? (ru ? 'Untouch обновлён' : 'Untouch updated')
        : downloading
        ? (ru ? 'Скачиваем обновление' : 'Downloading update')
        : ready
        ? (ru ? 'Обновление готово' : 'Update ready')
        : (ru ? 'Доступна новая версия' : 'A new version is available');
    return Material(
      key: const ValueKey('update-banner'),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A3047),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: GameUi.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: GameUi.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              success
                  ? (ru ? 'Можно играть!' : 'Ready to play!')
                  : downloading
                  ? (ru ? 'Можно продолжать играть' : 'You can keep playing')
                  : (ru
                        ? 'Установите, когда будет удобно'
                        : 'Update when it suits you'),
              style: const TextStyle(color: GameUi.muted, fontSize: 13),
            ),
            if (downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                color: GameUi.mint,
                backgroundColor: const Color(0xFF214A5C),
                minHeight: 5,
              ),
              if (progress != null) ...[
                const SizedBox(height: 7),
                Text(
                  '${(progress! * 100).floor()}% · '
                  '${(downloadedBytes / 1000000).toStringAsFixed(1)} / '
                  '${(totalBytes / 1000000).toStringAsFixed(1)} ${ru ? 'МБ' : 'MB'}',
                  style: const TextStyle(color: GameUi.muted, fontSize: 12),
                ),
              ],
            ] else if (!success) ...[
              const SizedBox(height: 10),
              _UpdateButton(
                label: ready
                    ? (ru ? 'Перезапустить и обновить' : 'Restart and update')
                    : (ru ? 'Скачать' : 'Download'),
                onPressed: onPressed,
              ),
            ],
          ],
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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5EE4D3), Color(0xFF1CBAA9)],
      ),
    ),
    child: TextButton(
      key: const ValueKey('update-primary'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF032839),
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
