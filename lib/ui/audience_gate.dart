import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/audience_policy.dart';
import 'game_sheet.dart';
import 'game_ui.dart';
import 'neon_chrome.dart';

final _activeAgePrompt = Expando<Future<void>>();

Future<void> showAudienceSelection(
  BuildContext context, {
  bool resourceAction = false,
  bool editing = false,
}) async {
  final policy = context.read<AudiencePolicy?>();
  if (policy == null ||
      (!editing && policy.band != null && policy.band != AgeBand.unknown)) {
    return;
  }
  var prompt = _activeAgePrompt[policy];
  if (prompt == null) {
    prompt = showDialog<void>(
      animationStyle: GameUi.windowAnimationStyle,
      context: context,
      useRootNavigator: false,
      barrierColor: GameUi.modalBarrier,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: _AgeScreen(resourceAction: resourceAction, editing: editing),
        ),
      ),
    );
    _activeAgePrompt[policy] = prompt;
  }
  await prompt;
  _activeAgePrompt[policy] = null;
}

class AudienceGate extends StatelessWidget {
  const AudienceGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

class AudienceProfileSetting extends StatelessWidget {
  const AudienceProfileSetting({
    super.key,
    this.compact = false,
    this.dark = false,
  });
  final bool compact;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final policy = context.watch<AudiencePolicy?>();
    if (policy == null) return const SizedBox.shrink();
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final answered = policy.band != null && policy.band != AgeBand.unknown;
    final label = !answered
        ? (ru ? 'Не указан' : 'Not specified')
        : policy.isAdEligibleAge
        ? '18+'
        : (ru ? 'До 18 лет' : 'Under 18');
    final row = TextButton(
      key: const ValueKey('profile-age-edit'),
      onPressed: () => showAudienceSelection(context, editing: answered),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        foregroundColor: dark ? GameUi.text : GameUi.ink,
      ),
      child: Row(
        children: [
          if (dark)
            const AccountArt('user', size: 20)
          else
            const Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: GameUi.ink,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ru ? 'Возраст' : 'Age',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                key: const ValueKey('profile-age-answer'),
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? GameUi.muted : GameUi.inkMuted,
                ),
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    );
    return KeyedSubtree(
      key: const ValueKey('profile-age-setting'),
      child: compact ? row : GamePanel(child: row),
    );
  }
}

/// Single awaited admission step. Cancel never calls the resource operation.
/// Repeated taps share the prompt; callers use a per-owner lock below.
Future<bool> ensureResourceAge(BuildContext context) async {
  final policy = context.read<AudiencePolicy?>();
  if (policy == null) return true; // Non-Android / legacy providers.
  if (policy.band != null && policy.band != AgeBand.unknown) return true;
  await showAudienceSelection(context, resourceAction: true);
  return context.mounted &&
      policy.band != null &&
      policy.band != AgeBand.unknown;
}

final _resourceBusy = Expando<Set<String>>();
Future<void> runResourceAction(
  BuildContext context,
  Object owner,
  String key,
  Future<void> Function() action,
) async {
  final busy = _resourceBusy[owner] ??= <String>{};
  // One owner cannot start a second pending action while choosing an age.
  if (busy.isNotEmpty) return;
  busy.add(key);
  try {
    if (await ensureResourceAge(context) && context.mounted) await action();
  } finally {
    busy.remove(key);
  }
}

class _AgeScreen extends StatefulWidget {
  const _AgeScreen({this.resourceAction = false, this.editing = false});
  final bool resourceAction;
  final bool editing;
  @override
  State<_AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends State<_AgeScreen> {
  AgeBand? _selection;
  bool _saving = false, _failed = false;
  bool _adult(AgeBand? band) =>
      band == AgeBand.age18to20 ||
      band == AgeBand.age21plus ||
      band == AgeBand.adult18plus;
  @override
  void initState() {
    super.initState();
    if (widget.editing) _selection = context.read<AudiencePolicy>().band;
  }

  Future<void> _save() async {
    if (_selection == null || _saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final policy = context.read<AudiencePolicy>();
      if (widget.editing) {
        await policy.correct(_selection!);
      } else {
        await policy.select(_selection!);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    Widget option(bool adult) => OutlinedButton(
      key: ValueKey(adult ? 'age-adult18plus' : 'age-under18'),
      onPressed: _saving
          ? null
          : () => setState(
              () => _selection = adult ? AgeBand.adult18plus : AgeBand.under18,
            ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        minimumSize: const Size(44, 50),
        side: BorderSide(
          color: _selection != null && _adult(_selection) == adult
              ? GameUi.cyan
              : const Color(0xFF376984),
          width: 1.3,
        ),
        backgroundColor: _selection != null && _adult(_selection) == adult
            ? const Color(0xFF07577A)
            : const Color(0xFF05283F),
      ),
      child: Row(
        children: [
          Icon(
            _selection != null && _adult(_selection) == adult
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: const Color(0xFF8FF5FF),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              adult
                  ? (ru ? 'Да, мне есть 18' : 'Yes, I am 18 or older')
                  : (ru ? 'Нет, я младше 18' : 'No, I am under 18'),
              textAlign: TextAlign.start,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
    return AccountGlass(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 14),
      child: SingleChildScrollView(
        key: const ValueKey('age-group-list'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NeonSheetHeader(
              title: ru
                  ? 'Вам уже исполнилось 18 лет?'
                  : 'Are you 18 or older?',
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, box) =>
                  box.maxWidth < 265 ||
                      MediaQuery.textScalerOf(context).scale(13) > 18
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        option(true),
                        const SizedBox(height: 8),
                        option(false),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: option(true)),
                        const SizedBox(width: 8),
                        Expanded(child: option(false)),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              ru
                  ? 'Можно играть и сохранять результат без ответа. Возраст потребуется перед получением ресурсов.'
                  : 'You can play and save scores without answering. A declaration is required before receiving resources.',
              style: const TextStyle(
                color: GameUi.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  ru
                      ? 'Не удалось сохранить. Попробуйте ещё раз.'
                      : 'Could not save. Please try again.',
                  style: const TextStyle(color: Color(0xFFFFBCAC)),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('age-continue'),
              onPressed: _selection == null || _saving ? null : _save,
              child: Text(
                _saving
                    ? (ru ? 'Сохраняем…' : 'Saving…')
                    : widget.resourceAction
                    ? (ru ? 'Подтвердить и продолжить' : 'Confirm and continue')
                    : (ru ? 'Подтвердить' : 'Confirm'),
              ),
            ),
            TextButton(
              key: const ValueKey('age-cancel'),
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(
                widget.editing
                    ? (ru ? 'Отмена' : 'Cancel')
                    : (ru ? 'Пока только играть' : 'Just play for now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
