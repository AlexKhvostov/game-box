import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_config_bootstrap.dart';
import 'shared_config_loader.dart';
import '../domain/android_game_constraints.dart';

/// A whole immutable startup snapshot. No mid-round activation or Hostland
/// fallback. Cached values belong to this backend generation only.
abstract final class AndroidFirebaseConfig {
  static const key = 'android_config_v1';
  static const cacheKey = 'firebase_android_v1_config';
  static const assetPath = 'assets/config/android-firebase.json';
  static const forceFetchKey = 'firebase_android_v1_force_config_fetch';

  static SharedConfigs parse(String raw, String source) {
    final snapshot = jsonDecode(raw) as Map<String, dynamic>;
    final config = snapshot['config'] as Map<String, dynamic>;
    final revision = sha256.convert(utf8.encode(jsonEncode(config))).toString();
    if (snapshot['revision'] != revision) {
      throw const FormatException('Firebase config revision mismatch');
    }
    final energy = config['economy']['androidEnergyV2'] as Map;
    final bonus = energy['simpleBonus'] as Map;
    if (energy['enabled'] != true || bonus['enabled'] != true) {
      throw const FormatException('Firebase energy policy disabled');
    }
    for (final key in ['baseAttemptCost', 'helmetExtraCost', 'jumpExtraCost']) {
      final value = energy[key];
      if (value is! int ||
          value < (key == 'baseAttemptCost' ? 1 : 0) ||
          value > 1000) {
        throw const FormatException('Invalid attempt cost');
      }
    }
    for (final key in [
      'initialEnergy',
      'reward',
      'tier2Reward',
      'tier5Reward',
      'videoReward',
      'inviterReward',
    ]) {
      final value = bonus[key];
      if (value is! int || value < 0 || value > 100000) {
        throw const FormatException('Invalid bonus policy');
      }
    }
    final period = bonus['periodSec'];
    if (period is! int || period < 1 || period > 2592000) {
      throw const FormatException('Invalid bonus duration');
    }
    const ranges = <String, List<double>>{
      'player.size': [4, 200],
      'field.borderWidth': [0, 24],
      'field.brightness': [0, 2],
      'field.maxSide': [100, 2000],
      'field.cornerRadius': [0, 200],
      'enemies.areaMultiplier': [0.1, 20],
      'enemies.angleMinDeg': [0, 180],
      'enemies.angleMaxDeg': [0, 180],
      'game.jumpCooldownSec': [2, 60],
      'game.jumpDurationSec': [0.05, 5],
      'game.jumpScale': [1, 3],
      'game.startInvulnSec': [0, 30],
      'game.helmetInvulnSec': [0, 30],
      'game.idleSpeedMultiplier': [0, 2],
      'audio.musicVolume': [0, 1],
      'audio.sfxVolume': [0, 1],
    };
    for (final entry in ranges.entries) {
      final parts = entry.key.split('.');
      final value = config[parts[0]][parts[1]];
      if (value is! num ||
          !value.isFinite ||
          value < entry.value[0] ||
          value > entry.value[1]) {
        throw FormatException('Invalid Firebase config: ${entry.key}');
      }
    }
    final aspects = config['enemies']['aspects'];
    if (aspects is! List ||
        aspects.isEmpty ||
        aspects.length > 32 ||
        aspects.any((v) => v is! num || !v.isFinite || v <= 0 || v > 100)) {
      throw const FormatException('Invalid enemy geometry');
    }
    final parsed = SharedConfigs.fromSnapshot(snapshot, source);
    if (!AndroidGameConstraints.playable(parsed.gameplay)) {
      throw const FormatException(
        'Android configuration has unplayable geometry',
      );
    }
    return parsed;
  }

  static Future<SharedConfigs> load() async {
    final defaults = await rootBundle.loadString(assetPath);
    final fallback = parse(defaults, 'firebase-bundled');
    if (const String.fromEnvironment(
      'FIREBASE_AUTH_EMULATOR_HOST',
    ).isNotEmpty) {
      return fallback;
    }
    final prefs = await SharedPreferences.getInstance();
    String? cached = prefs.getString(cacheKey);
    try {
      await RemoteConfigBootstrap.initialize().timeout(
        const Duration(seconds: 8),
      );
      final rc = FirebaseRemoteConfig.instance;
      final forceFetch = prefs.getBool(forceFetchKey) == true;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval: forceFetch
              ? Duration.zero
              : const Duration(minutes: 1),
        ),
      );
      await rc.setDefaults({key: defaults});
      // fetchAndActivate at startup only; an active round/purchase keeps terms.
      try {
        await rc.fetchAndActivate();
        await prefs.setBool(forceFetchKey, false);
      } catch (_) {}
      final value = rc.getValue(key);
      final raw = value.asString();
      final config = parse(
        raw,
        value.source == ValueSource.valueRemote
            ? 'firebase-remote-config'
            : 'firebase-bundled',
      );
      await prefs.setString(cacheKey, raw);
      return config;
    } catch (_) {
      if (cached != null) {
        try {
          return parse(cached, 'firebase-cache');
        } catch (_) {}
      }
      return fallback;
    }
  }
}
