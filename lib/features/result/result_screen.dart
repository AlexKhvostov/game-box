import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../data/local_scores_store.dart';
import '../../domain/score_entry.dart';
import '../game/game_play_screen.dart';
import '../game/widgets/freeze_sheet.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.timeMs});

  final int timeMs;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  RankInfo _rank = const RankInfo(place: 1, percentile: 100, totalCount: 0);
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scores = context.read<LocalScoresStore>();
      setState(() => _rank = scores.rankFor(widget.timeMs));
      context.read<EconomyStore>().recordBestTime(widget.timeMs);
    });
  }

  Future<void> _save() async {
    final economy = context.read<EconomyStore>();
    final scores = context.read<LocalScoresStore>();
    var name = economy.displayName;
    if (name == null || name.isEmpty) {
      name = await _askName(context);
      if (name == null || name.isEmpty || !mounted) return;
      await economy.setDisplayName(name);
    }
    final rank = await scores.saveScore(
      displayName: name,
      timeMs: widget.timeMs,
    );
    setState(() {
      _rank = rank;
      _saved = true;
    });
  }

  Future<String?> _askName(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ваше имя'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 16,
            decoration: const InputDecoration(hintText: 'Ник в рейтинге'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _playAgain() async {
    final economy = context.read<EconomyStore>();
    if (!economy.canPlay) {
      await showFreezeSheet(context);
      return;
    }
    if (!economy.tryStartGame() || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const GamePlayScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sec = (widget.timeMs / 1000).toStringAsFixed(1);
    final percentileLabel = _rank.totalCount == 0 && !_saved
        ? 'Станьте первым в рейтинге'
        : 'Вы быстрее ${_rank.percentile}% игроков';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text('Результат', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                '$sec с',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontSize: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Место #${_rank.place}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(percentileLabel, style: theme.textTheme.bodyLarge),
              if (_saved) ...[
                const SizedBox(height: 8),
                Text(
                  'Результат сохранён',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ],
              const Spacer(),
              if (!_saved)
                FilledButton(
                  onPressed: _save,
                  child: const Text('Сохранить результат'),
                ),
              if (!_saved) const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _playAgain,
                child: const Text('Ещё раз'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('В меню'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
