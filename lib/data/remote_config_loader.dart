import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../domain/economy_config.dart';
import '../domain/gameplay_config.dart';

class RemoteConfigs {
  const RemoteConfigs({
    required this.economy,
    required this.gameplay,
    this.forceLocale = '',
  });

  final EconomyConfig economy;
  final GameplayConfig gameplay;

  /// `en` | `ru` | пусто = язык устройства (fallback en).
  final String forceLocale;
}

class RemoteConfigLoader {
  static const _economyKey = 'economy';
  static const _enemiesKey = 'enemies';
  static const _playerKey = 'player';
  static const _fieldKey = 'field';
  static const _gameKey = 'game';
  static const _audioKey = 'audio';
  /// Старый единый ключ — читаем, если новых блоков ещё нет.
  static const _legacyGameplayKey = 'gameplay';
  static const _forceLocaleKey = 'forceLocale';

  static Future<RemoteConfigs> load() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 15),
          // Пока активно крутим админку — всегда тянем свежий RC.
          // Перед продом можно вернуть 1 час (меньше нагрузка / квоты Firebase).
          minimumFetchInterval: Duration.zero,
        ),
      );
      await rc.setDefaults({
        _economyKey: jsonEncode(const EconomyConfig().toJson()),
        _enemiesKey: jsonEncode(const EnemiesConfig().toJson()),
        _playerKey: jsonEncode(const PlayerConfig().toJson()),
        _fieldKey: jsonEncode(const FieldConfig().toJson()),
        _gameKey: jsonEncode(const GameConfig().toJson()),
        _audioKey: jsonEncode(const AudioConfig().toJson()),
        _legacyGameplayKey: '{}',
        _forceLocaleKey: '',
      });
      final activated = await rc.fetchAndActivate();
      debugPrint(
        'Remote Config fetchAndActivate=$activated '
        'lastFetch=${rc.lastFetchStatus} '
        'economyLen=${rc.getString(_economyKey).length} '
        'earnHint=${rc.getString(_economyKey).contains('install_bonus')}',
      );

      final economy = _parse(
        rc.getString(_economyKey),
        EconomyConfig.fromJson,
        const EconomyConfig(),
      );

      final enemiesRaw = rc.getString(_enemiesKey);
      final playerRaw = rc.getString(_playerKey);
      final fieldRaw = rc.getString(_fieldKey);
      final gameRaw = rc.getString(_gameKey);
      final audioRaw = rc.getString(_audioKey);
      final legacyRaw = rc.getString(_legacyGameplayKey);

      final hasBlocks = enemiesRaw.isNotEmpty ||
          playerRaw.isNotEmpty ||
          fieldRaw.isNotEmpty ||
          gameRaw.isNotEmpty ||
          audioRaw.isNotEmpty;

      late final GameplayConfig gameplay;
      if (hasBlocks) {
        gameplay = GameplayConfig.fromBlocks(
          enemies: _parse(
            enemiesRaw,
            EnemiesConfig.fromJson,
            const EnemiesConfig(),
          ),
          player: _parse(
            playerRaw,
            PlayerConfig.fromJson,
            const PlayerConfig(),
          ),
          field: _parse(
            fieldRaw,
            FieldConfig.fromJson,
            const FieldConfig(),
          ),
          game: _parse(
            gameRaw,
            GameConfig.fromJson,
            const GameConfig(),
          ),
          audio: _parse(
            audioRaw,
            AudioConfig.fromJson,
            const AudioConfig(),
          ),
        );
      } else if (legacyRaw.isNotEmpty && legacyRaw != '{}') {
        final map = jsonDecode(legacyRaw) as Map<String, dynamic>;
        gameplay = GameplayConfig.fromLegacyJson(map);
      } else {
        gameplay = const GameplayConfig();
      }

      return RemoteConfigs(
        economy: economy,
        gameplay: gameplay,
        forceLocale: rc.getString(_forceLocaleKey),
      );
    } catch (e, st) {
      debugPrint('Remote Config failed: $e\n$st');
      return const RemoteConfigs(
        economy: EconomyConfig(),
        gameplay: GameplayConfig(),
      );
    }
  }

  static T _parse<T>(
    String raw,
    T Function(Map<String, dynamic>) fromJson,
    T fallback,
  ) {
    if (raw.isEmpty || raw == '{}') return fallback;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Remote Config parse error: $e');
      return fallback;
    }
  }
}
