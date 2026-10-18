import 'package:flutter/material.dart';

import '../../domain/score_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/neon_chrome.dart';
import 'ranking_art.dart';
import '../../ui/game_ui.dart';
import 'leaderboard_widgets.dart';

/// Local inspection of the selected record; no account lookup or social action.
Future<void> showPlayerResultSheet(
  BuildContext context, {
  required ScoreEntry entry,
  required int place,
  String? periodLabel,
  bool own = false,
}) => showDialog<void>(
  animationStyle: GameUi.windowAnimationStyle,
  context: context,
  builder: (_) => PlayerResultSheet(
    entry: entry,
    place: place,
    periodLabel: periodLabel,
    own: own,
  ),
);

class PlayerResultSheet extends StatefulWidget {
  const PlayerResultSheet({
    super.key,
    required this.entry,
    required this.place,
    this.periodLabel,
    this.own = false,
  });
  final ScoreEntry entry;
  final int place;
  final String? periodLabel;
  final bool own;
  @override
  State<PlayerResultSheet> createState() => _PlayerResultSheetState();
}

class _PlayerResultSheetState extends State<PlayerResultSheet> {
  String? tip;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final entry = widget.entry;
    final large = MediaQuery.textScalerOf(context).scale(11) > 16.5;
    final tipText = switch (tip) {
      'risk' => l10n.riskTipHow,
      'run' => l10n.runTipHow,
      'jump' =>
        ru
            ? (entry.hadJump
                  ? 'Прыжок использовался в этой попытке.'
                  : 'Прыжок в этой попытке не использовался.')
            : (entry.hadJump
                  ? 'Jump was used in this run.'
                  : 'Jump was not used in this run.'),
      'helmet' =>
        ru
            ? (entry.hadHelmet
                  ? 'Шлем использовался в этой попытке.'
                  : 'Шлем в этой попытке не использовался.')
            : (entry.hadHelmet
                  ? 'Helmet was used in this run.'
                  : 'Helmet was not used in this run.'),
      _ => null,
    };
    Widget action(
      String id,
      String label, {
      String? value,
      required String art,
      bool? used,
    }) => OutlinedButton(
      key: ValueKey('player-$id'),
      style:
          OutlinedButton.styleFrom(
            foregroundColor: GameUi.text,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            minimumSize: Size(48, used == null ? 48 : 55),
            side: BorderSide.none,
          ).copyWith(
            backgroundBuilder: (context, states, child) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: tip == id
                      ? const Color(0xFF94E7F7)
                      : const Color(0xFF236E8D),
                ),
                gradient: const LinearGradient(
                  colors: [Color(0xFF06324B), Color(0xFF031C30)],
                ),
              ),
              child: child,
            ),
          ),
      onPressed: () => setState(() => tip = tip == id ? null : id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Opacity(
                opacity: used == false ? .3 : 1,
                child: RankingArt(
                  art,
                  width: used == null ? 20 : 23,
                  height: 24,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: used == null ? 10 : 11,
                        fontWeight: used == null
                            ? FontWeight.w400
                            : FontWeight.w700,
                        color: used == null ? GameUi.muted : GameUi.text,
                      ),
                    ),
                    if (value != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 3),
              SizedBox(
                height: used == null ? 34 : 24,
                child: const Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: Color(0xFF9DE6F4),
                  ),
                ),
              ),
            ],
          ),
          if (used != null) ...[
            const SizedBox(height: 5),
            Text(
              used
                  ? (ru ? 'Использовался' : 'Used in this run')
                  : (ru ? 'Не использовался' : 'Not used'),
              style: TextStyle(
                fontSize: 9,
                height: 1.25,
                color: used ? const Color(0xFFA5CCE7) : const Color(0xFF7B9FB9),
              ),
            ),
          ],
        ],
      ),
    );
    final runActions = [
      action(
        'run',
        ru ? 'Шаги' : 'Steps',
        value: '${entry.runDistance}',
        art: 'footsteps',
      ),
      action(
        'risk',
        ru ? 'Риск' : 'Risk',
        value: '${entry.riskCount}',
        art: 'risk',
      ),
      action('jump', ru ? 'Прыжок' : 'Jump', art: 'jump', used: entry.hadJump),
      action(
        'helmet',
        ru ? 'Шлем' : 'Helmet',
        art: 'helmet',
        used: entry.hadHelmet,
      ),
    ];
    Widget pair(int first) => large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              runActions[first],
              const SizedBox(height: 6),
              runActions[first + 1],
            ],
          )
        : Row(
            children: [
              Expanded(child: runActions[first]),
              const SizedBox(width: 9),
              Expanded(child: runActions[first + 1]),
            ],
          );
    final contextLabel =
        '${widget.periodLabel ?? (ru ? "Попытка" : "Run")} · #${widget.place}';
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 350,
          maxHeight: MediaQuery.sizeOf(context).height - 48,
        ),
        child: RepaintBoundary(
          key: const ValueKey('player-result-frame'),
          child: AccountGlass(
            radius: 19,
            padding: const EdgeInsets.fromLTRB(13, 8, 13, 13),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NeonSheetHeader(
                  title: ru ? 'Результат игрока' : 'Player result',
                  titleSize: MediaQuery.sizeOf(context).width < 340 ? 19 : 22,
                  showDivider: false,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    key: const ValueKey('player-result-content'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF032C3B),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: const Color(0xFF52DBE8),
                                ),
                              ),
                              child: const GameArtwork(
                                GameArt.avatar,
                                size: 37,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.displayName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                      color: GameUi.text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 3,
                                    children: [
                                      if (entry.countryCode != '--')
                                        Text(
                                          entry.countryCode,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: GameUi.muted,
                                          ),
                                        ),
                                      Text(
                                        contextLabel,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: GameUi.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          key: const ValueKey('player-time-info'),
                          margin: const EdgeInsets.symmetric(vertical: 11),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFF166580)),
                              bottom: BorderSide(color: Color(0xFF167B9E)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ru ? 'Время попытки' : 'Run time',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: GameUi.muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${entry.timeSec.toStringAsFixed(3)} ${ru ? "с" : "s"}',
                                    key: const ValueKey('player-time'),
                                    style: const TextStyle(
                                      fontSize: 43,
                                      height: 1.1,
                                      fontWeight: FontWeight.w900,
                                      color: GameUi.text,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                      shadows: [
                                        Shadow(
                                          color: Color(0x6600BEFF),
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${ru ? "Очки попытки" : "Run points"}: ${entry.score}',
                                key: const ValueKey('player-points'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: GameUi.muted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pair(0),
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 7),
                          child: Text(
                            ru
                                ? 'Усиления в этой попытке'
                                : 'Abilities used in this run',
                            style: const TextStyle(
                              fontSize: 10,
                              color: GameUi.muted,
                            ),
                          ),
                        ),
                        pair(2),
                        if (tipText != null)
                          Container(
                            margin: const EdgeInsets.only(top: 9),
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0B3146),
                              border: Border(
                                left: BorderSide(
                                  color: Color(0xFF42B5D3),
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              tipText,
                              key: const ValueKey('player-stat-tip'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: GameUi.text,
                                height: 1.4,
                              ),
                            ),
                          ),
                        Container(
                          margin: const EdgeInsets.only(top: 11),
                          padding: const EdgeInsets.only(top: 8),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFF174764)),
                            ),
                          ),
                          child: Text(
                            scoreDateLabel(entry.createdAt, full: true),
                            style: const TextStyle(
                              fontSize: 10,
                              color: GameUi.muted,
                            ),
                          ),
                        ),
                        if (widget.own)
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              ru
                                  ? 'Это ваш личный результат'
                                  : 'This is your own result',
                              style: const TextStyle(
                                fontSize: 11,
                                color: GameUi.mint,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const ValueKey('player-close'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GameUi.text,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(ru ? 'Закрыть' : 'Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
