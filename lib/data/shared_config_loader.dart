import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/economy_config.dart';
import '../domain/gameplay_config.dart';

/// Immutable startup snapshot: active rounds never change their rules.
class SharedConfigs {
  const SharedConfigs({
    required this.economy,
    required this.gameplay,
    this.forceLocale = '',
    this.revision = '',
    this.source = 'bundled',
  });

  final EconomyConfig economy;
  final GameplayConfig gameplay;
  final String forceLocale;
  final String revision;
  final String source;

  static SharedConfigs fromSnapshot(
    Map<String, dynamic> snapshot,
    String source,
  ) {
    if (snapshot['ok'] != true ||
        snapshot['revision'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(snapshot['revision'] as String)) {
      throw const FormatException('Invalid published revision');
    }
    final raw = snapshot['config'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Missing game configuration');
    }
    for (final key in [
      'theme',
      'enemies',
      'player',
      'field',
      'game',
      'audio',
      'economy',
    ]) {
      if (raw[key] is! Map<String, dynamic>) {
        throw FormatException('Missing configuration block: $key');
      }
    }
    final enemies = raw['enemies'] as Map<String, dynamic>;
    final aspects = enemies['aspects'];
    final size = raw['player']['size'];
    if (aspects is! List ||
        aspects.isEmpty ||
        aspects.any((v) => v is! num || !v.isFinite || v <= 0) ||
        size is! num ||
        !size.isFinite ||
        size <= 0) {
      throw const FormatException('Invalid field geometry');
    }
    return SharedConfigs(
      economy: EconomyConfig.fromJson(raw['economy']),
      gameplay: GameplayConfig.fromBlocks(
        enemies: EnemiesConfig.fromJson(enemies),
        player: PlayerConfig.fromJson(raw['player']),
        field: FieldConfig.fromJson(raw['field']),
        game: GameConfig.fromJson(raw['game']),
        audio: AudioConfig.fromJson(raw['audio']),
        mobileEnemies: raw['mobileEnemies'] is Map<String, dynamic>
            ? MobileEnemyPace.fromJson(raw['mobileEnemies'])
            : const MobileEnemyPace(),
      ),
      forceLocale: raw['forceLocale'] is String
          ? raw['forceLocale'] as String
          : '',
      revision: snapshot['revision'] as String,
      source: source,
    );
  }
}

/// Same HTTPS publication as the Mini App, independent of Firebase availability.
class SharedConfigLoader {
  static const cacheKey = 'untouch_shared_config_v1';
  static const endpoint = String.fromEnvironment(
    'GAME_CONFIG_URL',
    defaultValue: 'https://untouch.ballaball.xyz/api/config.php',
  );
  static const assetPath = 'assets/config/published-gameplay.json';

  static Future<SharedConfigs> load({
    http.Client? client,
    SharedPreferences? preferences,
    Future<String> Function()? readBundled,
    Duration timeout = const Duration(milliseconds: 2500),
    bool allowNetwork = true,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final transport = client ?? http.Client();
    try {
      if (!allowNetwork) throw const FormatException('Local session');
      final uri = Uri.parse(endpoint);
      if (uri.scheme != 'https') throw const FormatException('HTTPS required');
      final response = await transport
          .get(uri, headers: {'Cache-Control': 'no-cache'})
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw FormatException('HTTP ${response.statusCode}');
      }
      final raw = utf8.decode(response.bodyBytes);
      final snapshot = jsonDecode(raw) as Map<String, dynamic>;
      final config = SharedConfigs.fromSnapshot(snapshot, 'network');
      // A storage failure must not discard a valid server response.
      try {
        await prefs.setString(cacheKey, raw);
      } catch (_) {}
      return config;
    } catch (_) {
      try {
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          return SharedConfigs.fromSnapshot(
            jsonDecode(cached) as Map<String, dynamic>,
            'cache',
          );
        }
      } catch (_) {}
      final raw =
          await (readBundled ?? () => rootBundle.loadString(assetPath))();
      return SharedConfigs.fromSnapshot(
        jsonDecode(raw) as Map<String, dynamic>,
        'bundled',
      );
    } finally {
      if (client == null) transport.close();
    }
  }
}
