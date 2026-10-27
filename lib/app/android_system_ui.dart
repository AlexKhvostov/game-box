import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One system-inset contract for Android startup and native acceptance probes.
/// The existing SafeArea widgets keep controls clear of bars and cutouts.
Future<void> configureAndroidSystemUi() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
}
