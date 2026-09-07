import 'package:flutter/material.dart';

import '../app/app_target.dart';
import '../features/floors/floors_home_screen.dart';
import '../features/game/game_home_screen.dart';

/// Корень: выбор режима (mobile) или сразу аркада (telegram).
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

enum _AppMode { picker, arcade, floors }

class _ShellScreenState extends State<ShellScreen> {
  late _AppMode _mode = AppTargetConfig.isTelegram
      ? _AppMode.arcade
      : _AppMode.picker;

  void _backToPicker() {
    if (!AppTargetConfig.showModePicker) return;
    setState(() => _mode = _AppMode.picker);
  }

  @override
  Widget build(BuildContext context) {
    switch (_mode) {
      case _AppMode.arcade:
        return GameHomeScreen(
          onLeave: AppTargetConfig.showModePicker ? _backToPicker : null,
        );
      case _AppMode.floors:
        return FloorsHomeScreen(onBack: _backToPicker);
      case _AppMode.picker:
        return _ModePicker(
          onArcade: () => setState(() => _mode = _AppMode.arcade),
          onFloors: AppTargetConfig.showFloorsMode
              ? () => setState(() => _mode = _AppMode.floors)
              : null,
        );
    }
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({
    required this.onArcade,
    this.onFloors,
  });

  final VoidCallback onArcade;
  final VoidCallback? onFloors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0E1419),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Untouch',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Выберите режим',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const Spacer(),
              _ModeCard(
                title: 'Аркада · рекорд',
                subtitle: 'Основная игра. Уворачивайтесь и бейте рекорд.',
                accent: theme.colorScheme.primary,
                onTap: onArcade,
              ),
              if (onFloors != null) ...[
                const SizedBox(height: 14),
                _ModeCard(
                  title: 'Этажи',
                  subtitle:
                      'Черновик: одна комната, выходы на стенах, путь к выходу этажа.',
                  accent: const Color(0xFF3DDC97),
                  onTap: onFloors!,
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF12181E),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
