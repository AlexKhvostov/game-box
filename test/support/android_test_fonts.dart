import 'dart:io';

import 'package:flutter/services.dart';

/// Use the Android review fonts even when the suite is run directly from an IDE
/// or `flutter test`, without the release runner's optional environment setup.
Future<void> loadAndroidTestFonts({
  bool replaceAhem = false,
  bool icons = true,
}) async {
  final directory =
      Platform.environment['RANKING_FONT_DIR'] ?? 'test/fixtures/fonts';
  final regular = ByteData.sublistView(
    await File('$directory/Roboto-Regular.ttf').readAsBytes(),
  );
  final bold = ByteData.sublistView(
    await File('$directory/Roboto-Bold.ttf').readAsBytes(),
  );
  await (FontLoader('Roboto')
        ..addFont(Future.value(regular))
        ..addFont(Future.value(bold)))
      .load();

  // Account fixtures also contain plain Material widgets that inherit Ahem in
  // widget tests. Preserve their existing Android-like fallback metrics.
  if (replaceAhem) {
    await (FontLoader('Ahem')..addFont(Future.value(regular))).load();
  }
  if (icons) {
    final path = Platform.environment['RANKING_ICON_FONT'];
    final bytes = path == null
        ? await rootBundle.load('fonts/MaterialIcons-Regular.otf')
        : ByteData.sublistView(await File(path).readAsBytes());
    await (FontLoader('MaterialIcons')..addFont(Future.value(bytes))).load();
  }
}
