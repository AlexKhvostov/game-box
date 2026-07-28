import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../data/scores_store.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_sheet.dart';
import '../../ui/game_toast.dart';
import '../leaderboard/leaderboard_panel.dart';
import '../leaderboard/leaderboard_widgets.dart';

Future<void> showShareScoreSheet(
  BuildContext context, {
  required int timeMs,
  int riskCount = 0,
  int runDistance = 0,
  bool hadJump = false,
  bool hadHelmet = false,
}) {
  return showModalBottomSheet<void>(
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

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _name.text = context.read<EconomyStore>().displayName ?? '';
      context.read<ScoresStore>().refreshIfStale();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      showGameToast(
        context,
        message: l10n.enterName,
        accent: const Color(0xFFFF5A5F),
      );
      return;
    }
    setState(() => _saving = true);
    final economy = context.read<EconomyStore>();
    final scores = context.read<ScoresStore>();
    await economy.setDisplayName(name);
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final store = context.watch<ScoresStore>();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final timeLabel = (widget.timeMs / 1000).toStringAsFixed(3);
    final periodRanks = store.ranksByPeriod(widget.timeMs);
    final country =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode ?? '--';

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: GameSheetChrome(
        heightFactor: 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.saveScoreTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    l10n.saveScoreSubtitle(timeLabel),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            // Тот же лидерборд, что и по клику на рекорд
            Expanded(
              child: LeaderboardPanel(
                ghostTimeMs: widget.timeMs,
                ghostCountryCode: country,
                ghostRiskCount: widget.riskCount,
                ghostRunDistance: widget.runDistance,
                ghostHadJump: widget.hadJump,
                ghostHadHelmet: widget.hadHelmet,
                listPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1C2A32),
                    Color(0xFF141C22),
                    Color(0xFF0F151A),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF7EE0FF).withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7EE0FF).withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, -6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF7EE0FF).withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    PeriodRanksCompact(ranks: periodRanks),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _name,
                              maxLength: 16,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.nameLabel,
                                counterText: '',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.28),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: const Color(0xFF7EE0FF)
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: const Color(0xFF7EE0FF)
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7EE0FF),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 44,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(_saving ? l10n.saving : l10n.save),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Text(l10n.cancel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
