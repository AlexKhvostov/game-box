import '../domain/score_entry.dart';

/// Optional adapter for retained desktop/demo targets. Android supplies its
/// authenticated MobileAccount and never installs a legacy score source.
abstract interface class LegacyScoresSource {
  bool get ready;
  String? get uid;
  Future<List<ScoreEntry>> load();
  Future<ScoreEntry> save(ScoreEntry entry);
}
