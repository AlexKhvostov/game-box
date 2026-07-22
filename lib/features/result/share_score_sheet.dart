import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../data/scores_store.dart';
import '../../domain/score_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/game_sheet.dart';
import '../../ui/game_toast.dart';
import '../leaderboard/leaderboard_widgets.dart';

Future<void> showShareScoreSheet(
  BuildContext context, {
  required int timeMs,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ShareScoreBody(timeMs: timeMs),
  );
}

class _ShareScoreBody extends StatefulWidget {
  const _ShareScoreBody({required this.timeMs});

  final int timeMs;

  @override
  State<_ShareScoreBody> createState() => _ShareScoreBodyState();
}

class _ShareScoreBodyState extends State<_ShareScoreBody>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _name;
  late final TabController _tabs;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this, initialIndex: 4);
    _name = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _name.text = context.read<EconomyStore>().displayName ?? '';
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _periodKey {
    switch (_tabs.index) {
      case 0:
        return 'day';
      case 1:
        return 'week';
      case 2:
        return 'month';
      case 3:
        return 'year';
      default:
        return 'all';
    }
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
            // Шапка + вкладки (фиксированы)
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
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              onTap: (_) => setState(() {}),
              tabs: [
                Tab(text: l10n.periodDay, height: 34),
                Tab(text: l10n.periodWeek, height: 34),
                Tab(text: l10n.periodMonth, height: 34),
                Tab(text: l10n.periodYear, height: 34),
                Tab(text: l10n.periodAll, height: 34),
              ],
            ),
            // Лидерборд — единственная прокручиваемая зона
            Expanded(
              child: AnimatedBuilder(
                animation: _tabs,
                builder: (context, _) {
                  final list =
                      store.scoresForNamedPeriod(_periodKey).take(40).toList();
                  final insertAt =
                      store.rankFor(widget.timeMs, period: _periodKey).place -
                          1;
                  final ghost = ScoreEntry(
                    id: 'ghost',
                    displayName: l10n.youGhost,
                    timeMs: widget.timeMs,
                    createdAt: DateTime.now(),
                    countryCode: country,
                  );

                  if (list.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      children: [
                        LeaderboardRankRow(
                          place: 1,
                          entry: ghost,
                          ghost: true,
                          ghostLabel: l10n.youGhost,
                        ),
                        const SizedBox(height: 8),
                        Center(child: Text(l10n.leaderboardEmpty)),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: list.length + 1,
                    itemBuilder: (context, i) {
                      if (i == insertAt) {
                        return LeaderboardRankRow(
                          place: insertAt + 1,
                          entry: ghost,
                          ghost: true,
                          ghostLabel: l10n.youGhost,
                        );
                      }
                      final idx = i < insertAt ? i : i - 1;
                      final place = idx < insertAt ? idx + 1 : idx + 2;
                      return LeaderboardRankRow(
                        place: place,
                        entry: list[idx],
                        highlight: place <= 3,
                      );
                    },
                  );
                },
              ),
            ),
            // Низ: места + имя + кнопки — без прокрутки
            Material(
              color: const Color(0xFF12181E),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PeriodRanksCompact(ranks: periodRanks),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white12),
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
