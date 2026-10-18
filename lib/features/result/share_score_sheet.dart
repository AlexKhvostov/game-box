import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../data/mobile_account.dart';
import '../../data/scores_store.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_sheet.dart';
import '../../ui/game_toast.dart';
import '../../ui/game_ui.dart';
import '../leaderboard/leaderboard_sheet.dart';

Future<void> showShareScoreSheet(
  BuildContext context, {
  required int timeMs,
  int riskCount = 0,
  int runDistance = 0,
  bool hadJump = false,
  bool hadHelmet = false,
}) {
  // Android has already recorded the round; every old entry point opens the
  // shared leaderboard rather than asking the player to submit it again.
  if (context.read<ScoresStore>().account != null) {
    return showLeaderboardSheet(context);
  }
  return showModalBottomSheet<void>(
    sheetAnimationStyle: GameUi.windowAnimationStyle,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ShareScoreBody(
      timeMs: timeMs,
      riskCount: riskCount,
      runDistance: runDistance,
      hadJump: hadJump,
      hadHelmet: hadHelmet,
    ),
  );
}

class _ShareScoreBody extends StatefulWidget {
  const _ShareScoreBody({
    required this.timeMs,
    this.riskCount = 0,
    this.runDistance = 0,
    this.hadJump = false,
    this.hadHelmet = false,
  });

  final int timeMs;
  final int riskCount;
  final int runDistance;
  final bool hadJump;
  final bool hadHelmet;

  @override
  State<_ShareScoreBody> createState() => _ShareScoreBodyState();
}

class _ShareScoreBodyState extends State<_ShareScoreBody> {
  late final TextEditingController _name;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _name.text =
          context.read<MobileAccount?>()?.nickname ??
          context.read<EconomyStore>().displayName ??
          '';
      context.read<ScoresStore>().refreshIfStale();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.enterName);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final economy = context.read<EconomyStore>();
    final scores = context.read<ScoresStore>();
    final account = context.read<MobileAccount?>();
    try {
      if (account != null && account.nickname != name) {
        await account.rename(name);
      }
      if (account == null) await economy.setDisplayName(name);
      final country =
          WidgetsBinding.instance.platformDispatcher.locale.countryCode ?? '--';
      final rank = await scores.saveScore(
        displayName: name,
        timeMs: widget.timeMs,
        countryCode: country,
        riskCount: widget.riskCount,
        runDistance: widget.runDistance,
        hadJump: widget.hadJump,
        hadHelmet: widget.hadHelmet,
      );
      if (!mounted) return;
      showGameToast(
        context,
        message: l10n.savedPlace(rank.place),
        accent: const Color(0xFF3DDC97),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = Localizations.localeOf(context).languageCode == 'ru'
            ? 'Результат ещё не подтверждён сервером. Проверьте соединение.'
            : 'The server has not confirmed this result. Check your connection.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom;
    final timeLabel = (widget.timeMs / 1000).toStringAsFixed(3);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: GameSheetChrome(
        fitContent: true,
        heightFactor: .9,
        heightLimit: (media.size.height - bottom - media.padding.top - 20)
            .clamp(0, double.infinity),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            key: const ValueKey('submit-content'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GameSheetHeader(
                title: ru ? 'Записать результат' : 'Submit result',
              ),
              const SizedBox(height: 8),
              Text(
                '$timeLabel ${ru ? 'с · общий рейтинг' : 's · shared leaderboard'}',
                style: const TextStyle(color: GameUi.inkMuted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Text(
                ru ? 'Игровой ник' : 'Game nickname',
                style: const TextStyle(
                  color: GameUi.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('submit-name'),
                controller: _name,
                enabled: !_saving,
                maxLength: 40,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: const TextStyle(color: GameUi.text, fontSize: 16),
                decoration: InputDecoration(
                  hintText: l10n.nameLabel,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  errorText: _error,
                  errorMaxLines: 4,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const ValueKey('submit-save'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.saving),
                        ],
                      )
                    : Text(ru ? 'Записать' : 'Submit'),
              ),
              OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
