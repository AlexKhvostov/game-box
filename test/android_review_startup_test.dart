import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/android_firebase_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'startup uses one budget and late fetch caches without changing session',
    () async {
      SharedPreferences.setMockInitialValues({});
      final delayed = Completer<String>();
      final timer = Stopwatch()..start();
      final session = await AndroidFirebaseConfig.load(
        refreshBudget: const Duration(milliseconds: 30),
        remoteLoader: (_) => delayed.future,
      );
      expect(timer.elapsedMilliseconds, lessThan(1000));
      expect(session.source, 'firebase-bundled');
      final raw = await rootBundle.loadString(AndroidFirebaseConfig.assetPath);
      delayed.complete(raw);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        (await SharedPreferences.getInstance()).getString(
          AndroidFirebaseConfig.cacheKey,
        ),
        raw,
      );
      expect(session.source, 'firebase-bundled');
    },
  );
  test(
    'valid cache wins during outage; corrupt cache and late failure are safe',
    () async {
      final raw = await rootBundle.loadString(AndroidFirebaseConfig.assetPath);
      SharedPreferences.setMockInitialValues({
        AndroidFirebaseConfig.cacheKey: raw,
      });
      final cached = await AndroidFirebaseConfig.load(
        remoteLoader: (_) async => throw StateError('offline'),
      );
      expect(cached.source, 'firebase-cache');
      SharedPreferences.setMockInitialValues({
        AndroidFirebaseConfig.cacheKey: '{broken',
      });
      final fallback = await AndroidFirebaseConfig.load(
        remoteLoader: (_) async => '{invalid',
      );
      expect(fallback.source, 'firebase-bundled');
      expect(
        (await SharedPreferences.getInstance()).getString(
          AndroidFirebaseConfig.cacheKey,
        ),
        '{broken',
      );
    },
  );
}
