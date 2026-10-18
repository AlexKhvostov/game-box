import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/shared_config_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = File(SharedConfigLoader.assetPath).readAsStringSync();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'hosting snapshot preserves active Mini App rules and caches revision',
    () async {
      final result = await SharedConfigLoader.load(
        client: MockClient((request) async {
          expect(request.url.scheme, 'https');
          return http.Response(
            fixture,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(result.source, 'network');
      expect(result.gameplay.wallsKillPlayer, isFalse);
      expect(result.gameplay.idleEnemiesMove, isFalse);
      expect(result.gameplay.startInvulnSec, 0);
      expect(result.gameplay.jumpCooldownSec, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SharedConfigLoader.cacheKey), fixture);
    },
  );

  test('failed network loads cached snapshot', () async {
    SharedPreferences.setMockInitialValues({
      SharedConfigLoader.cacheKey: fixture,
    });
    final result = await SharedConfigLoader.load(
      client: MockClient((_) async => http.Response('', 503)),
    );
    expect(result.source, 'cache');
  });

  test('invalid network response does not replace known good cache', () async {
    SharedPreferences.setMockInitialValues({
      SharedConfigLoader.cacheKey: fixture,
    });
    final result = await SharedConfigLoader.load(
      client: MockClient((_) async => http.Response('{"ok":true}', 200)),
    );
    expect(result.source, 'cache');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SharedConfigLoader.cacheKey), fixture);
  });

  test('broken cache and no network load packaged public snapshot', () async {
    SharedPreferences.setMockInitialValues({
      SharedConfigLoader.cacheKey: '{broken',
    });
    final result = await SharedConfigLoader.load(
      client: MockClient((_) async => throw http.ClientException('offline')),
      readBundled: () async => fixture,
    );
    expect(result.source, 'bundled');
    expect(result.revision, isNotEmpty);
  });

  test('snapshot with invalid geometry is rejected', () {
    final snapshot = jsonDecode(fixture) as Map<String, dynamic>;
    snapshot['config']['player']['size'] = 0;
    expect(
      () => SharedConfigs.fromSnapshot(snapshot, 'network'),
      throwsFormatException,
    );
  });
}
