/// Флаг страны из ISO alpha-2 через emoji regional indicators.
String countryFlagEmoji(String code) {
  final cc = code.trim().toUpperCase();
  if (cc.length != 2 || cc == '--' || !RegExp(r'^[A-Z]{2}$').hasMatch(cc)) {
    return '🌐';
  }
  final a = 0x1F1E6 + (cc.codeUnitAt(0) - 0x41);
  final b = 0x1F1E6 + (cc.codeUnitAt(1) - 0x41);
  return String.fromCharCodes([a, b]);
}
