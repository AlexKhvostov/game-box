import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_sheet.dart';
import 'game_ui.dart';

/// Public links only. The ID is copied deliberately, never sent in a URL.
class ProfileSupport extends StatelessWidget {
  const ProfileSupport({super.key, this.playerId, this.dark = false});
  final String? playerId;
  final bool dark;
  static const channel = MethodChannel('untouch/support');

  Future<void> _open(BuildContext context, String page, bool ru) async {
    try {
      await channel.invokeMethod<void>('openPage', {
        'page': page,
        'language': ru ? 'ru' : 'en',
      });
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ru
                ? 'Не удалось открыть браузер. Поддержка: support@untouch.fun'
                : 'Could not open the browser. Support: support@untouch.fun',
          ),
        ),
      );
    }
  }

  Future<void> _copy(BuildContext context, String value, bool ru) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ru ? 'Скопировано' : 'Copied')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ru ? 'Не удалось скопировать' : 'Could not copy'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    if (dark) {
      Widget link(String page, IconData icon, String label) => TextButton(
        key: ValueKey('profile-$page'),
        onPressed: () => _open(context, page, ru),
        style: TextButton.styleFrom(
          foregroundColor: GameUi.text,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
        child: Row(
          children: [
            Icon(icon, color: GameUi.cyan, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 12),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: GameUi.cyan,
              size: 18,
            ),
          ],
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (playerId != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ru ? 'ID игрока' : 'Player ID'}: $playerId',
                    style: const TextStyle(fontSize: 11, color: GameUi.muted),
                  ),
                ),
                IconButton(
                  key: const ValueKey('profile-copy-id'),
                  tooltip: ru ? 'Скопировать ID' : 'Copy ID',
                  onPressed: () => _copy(context, playerId!, ru),
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: GameUi.cyan,
                    size: 18,
                  ),
                ),
              ],
            ),
          link(
            'privacy',
            Icons.privacy_tip_outlined,
            ru ? 'Политика конфиденциальности' : 'Privacy policy',
          ),
          link(
            'deletion',
            Icons.person_remove_outlined,
            ru ? 'Запрос удаления профиля' : 'Request profile deletion',
          ),
          Text(
            ru
                ? 'Откроется инструкция. Удаление выполняется после проверки владельца.'
                : 'Opens the instructions. Deletion follows ownership verification.',
            style: const TextStyle(
              fontSize: 11,
              height: 1.3,
              color: GameUi.muted,
            ),
          ),
          link(
            'support',
            Icons.help_outline_rounded,
            ru ? 'Поддержка' : 'Support',
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'support@untouch.fun',
                  style: TextStyle(fontSize: 12, color: GameUi.cyan),
                ),
              ),
              IconButton(
                key: const ValueKey('profile-copy-support'),
                tooltip: ru
                    ? 'Скопировать адрес поддержки'
                    : 'Copy support address',
                onPressed: () => _copy(context, 'support@untouch.fun', ru),
                icon: const Icon(
                  Icons.copy_rounded,
                  color: GameUi.cyan,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GamePanel(
        glass: dark ? GameGlass.none : GameGlass.card,
        gradient: dark ? GameUi.deepPanelGradient : null,
        accent: dark ? const Color(0xFF376984) : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Theme(
          data: Theme.of(context).copyWith(
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: dark ? GameUi.cyan : GameUi.ink,
                minimumSize: Size(
                  GameUi.touchTarget(context),
                  GameUi.touchTarget(context),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (playerId != null) ...[
                Text(
                  ru ? 'ID игрока: $playerId' : 'Player ID: $playerId',
                  style: TextStyle(
                    fontSize: 11,
                    color: dark ? GameUi.muted : GameUi.inkMuted,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('profile-copy-id'),
                  onPressed: () => _copy(context, playerId!, ru),
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(ru ? 'Скопировать ID' : 'Copy player ID'),
                ),
              ],
              TextButton.icon(
                key: const ValueKey('profile-privacy'),
                onPressed: () => _open(context, 'privacy', ru),
                icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                label: Text(
                  ru ? 'Политика конфиденциальности' : 'Privacy policy',
                ),
              ),
              TextButton.icon(
                key: const ValueKey('profile-deletion'),
                onPressed: () => _open(context, 'deletion', ru),
                icon: const Icon(Icons.person_remove_outlined, size: 18),
                label: Text(
                  ru ? 'Запрос удаления профиля' : 'Request profile deletion',
                ),
              ),
              Text(
                ru
                    ? 'Откроется инструкция. Удаление выполняется после проверки владельца.'
                    : 'Opens the instructions. Deletion follows ownership verification.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: dark ? GameUi.muted : GameUi.inkMuted,
                ),
              ),
              TextButton.icon(
                key: const ValueKey('profile-support'),
                onPressed: () => _open(context, 'support', ru),
                icon: const Icon(Icons.help_outline, size: 18),
                label: Text(ru ? 'Поддержка' : 'Support'),
              ),
              TextButton(
                key: const ValueKey('profile-copy-support'),
                onPressed: () => _copy(context, 'support@untouch.fun', ru),
                child: const Text('support@untouch.fun'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
