import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/gameplay_config.dart';

/// SFX + лёгкий BGM. Флаги из Remote Config `audio`.
class GameSfx {
  GameSfx._();

  static AudioConfig _cfg = const AudioConfig();
  static bool _ready = false;
  static bool _loading = false;

  static final List<AudioPlayer> _wallPool = List.generate(
    3,
    (_) => AudioPlayer(),
  );
  static int _wallPoolIdx = 0;

  static final AudioPlayer _mobCollide = AudioPlayer();
  static final AudioPlayer _heroMob = AudioPlayer();
  static final AudioPlayer _heroWall = AudioPlayer();
  static final AudioPlayer _nearMiss = AudioPlayer();
  static final AudioPlayer _helmet = AudioPlayer();
  static final AudioPlayer _jump = AudioPlayer();
  static final AudioPlayer _start = AudioPlayer();
  static final AudioPlayer _music = AudioPlayer();

  static Uint8List? _mobWallBytes;
  static Uint8List? _mobCollideBytes;
  static Uint8List? _heroMobBytes;
  static Uint8List? _heroWallBytes;
  static Uint8List? _nearMissBytes;
  static Uint8List? _helmetBytes;
  static Uint8List? _jumpBytes;
  static Uint8List? _startBytes;

  static DateTime? _lastMobWallAt;
  static DateTime? _lastMobCollideAt;
  static DateTime? _lastNearMissAt;
  static bool _musicStarted = false;
  /// Приложение в фоне — не крутим музыку и не запускаем её заново.
  static bool _backgrounded = false;

  static Future<void> _ensureReady() async {
    if (_ready || _loading) return;
    _loading = true;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );

      _mobWallBytes = (await rootBundle.load('assets/sfx/mob_wall.wav'))
          .buffer
          .asUint8List();
      _mobCollideBytes = (await rootBundle.load('assets/sfx/mob_collide.wav'))
          .buffer
          .asUint8List();
      _heroMobBytes = (await rootBundle.load('assets/sfx/hero_mob.wav'))
          .buffer
          .asUint8List();
      _heroWallBytes = (await rootBundle.load('assets/sfx/hero_wall.wav'))
          .buffer
          .asUint8List();
      _nearMissBytes = (await rootBundle.load('assets/sfx/near_miss.wav'))
          .buffer
          .asUint8List();
      _helmetBytes = (await rootBundle.load('assets/sfx/helmet_break.wav'))
          .buffer
          .asUint8List();
      _jumpBytes =
          (await rootBundle.load('assets/sfx/jump.wav')).buffer.asUint8List();
      _startBytes = (await rootBundle.load('assets/sfx/game_start.wav'))
          .buffer
          .asUint8List();

      for (final p in [
        ..._wallPool,
        _mobCollide,
        _heroMob,
        _heroWall,
        _nearMiss,
        _helmet,
        _jump,
        _start,
      ]) {
        await p.setPlayerMode(PlayerMode.mediaPlayer);
        await p.setReleaseMode(ReleaseMode.stop);
      }
      await _music.setPlayerMode(PlayerMode.mediaPlayer);
      await _music.setReleaseMode(ReleaseMode.loop);
      _ready = true;
    } catch (e) {
      debugPrint('GameSfx._ensureReady: $e');
    } finally {
      _loading = false;
    }
  }

  static void applyConfig(AudioConfig config) {
    _cfg = config;
    if (!config.music) {
      stopMusic();
    } else if (_musicStarted) {
      unawaited(_music.setVolume(config.musicVolume.clamp(0.0, 1.0)));
    }
    unawaited(_ensureReady());
  }

  static Future<void> ensureMusic() async {
    await _ensureReady();
    if (!_cfg.music || _backgrounded) {
      if (!_cfg.music) await stopMusic();
      return;
    }
    final vol = _cfg.musicVolume.clamp(0.0, 1.0);
    if (_musicStarted) {
      try {
        await _music.setVolume(vol);
        // После паузы в фоне — продолжить.
        final st = _music.state;
        if (st == PlayerState.paused) {
          await _music.resume();
        }
      } catch (_) {}
      return;
    }
    try {
      await _music.setVolume(vol);
      await _music.play(AssetSource('sfx/bgm_loop.wav'));
      _musicStarted = true;
    } catch (e) {
      debugPrint('GameSfx.ensureMusic: $e');
    }
  }

  /// Свернули приложение / ушли с экрана — пауза BGM.
  static Future<void> onAppPaused() async {
    _backgrounded = true;
    try {
      await _music.pause();
    } catch (_) {}
  }

  /// Вернулись в приложение — продолжить BGM, если включён в RC.
  static Future<void> onAppResumed() async {
    _backgrounded = false;
    if (!_cfg.music) return;
    await ensureMusic();
  }

  static Future<void> stopMusic() async {
    try {
      await _music.stop();
    } catch (_) {}
    _musicStarted = false;
  }

  static double _sfxVol(double relative) =>
      (relative * _cfg.sfxVolume).clamp(0.0, 1.0);

  static Future<void> _playBytes(
    AudioPlayer player,
    Uint8List? bytes, {
    required double volume,
  }) async {
    await _ensureReady();
    if (bytes == null || bytes.isEmpty) return;
    try {
      await player.stop();
      await player.setVolume(_sfxVol(volume));
      // BytesSource надёжнее AssetSource на Android при частых one-shot.
      await player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (e) {
      debugPrint('GameSfx.playBytes: $e');
    }
  }

  static Future<void> mobWall() async {
    if (!_cfg.sfxMobWall) return;
    final now = DateTime.now();
    if (_lastMobWallAt != null &&
        now.difference(_lastMobWallAt!) < const Duration(milliseconds: 28)) {
      return;
    }
    _lastMobWallAt = now;
    final player = _wallPool[_wallPoolIdx % _wallPool.length];
    _wallPoolIdx++;
    unawaited(_playBytes(player, _mobWallBytes, volume: 0.7));
  }

  static Future<void> mobCollide() async {
    if (!_cfg.sfxMobCollide) return;
    final now = DateTime.now();
    if (_lastMobCollideAt != null &&
        now.difference(_lastMobCollideAt!) <
            const Duration(milliseconds: 45)) {
      return;
    }
    _lastMobCollideAt = now;
    unawaited(_playBytes(_mobCollide, _mobCollideBytes, volume: 0.55));
  }

  static Future<void> heroMob() async {
    if (!_cfg.sfxHeroMob) return;
    unawaited(_playBytes(_heroMob, _heroMobBytes, volume: 0.72));
  }

  static Future<void> heroWall() async {
    if (!_cfg.sfxHeroWall) return;
    unawaited(_playBytes(_heroWall, _heroWallBytes, volume: 0.7));
  }

  /// Risk / near-miss: лёгкий свист-скольжение.
  static Future<void> nearMiss() async {
    if (!_cfg.sfxNearMiss) return;
    final now = DateTime.now();
    if (_lastNearMissAt != null &&
        now.difference(_lastNearMissAt!) <
            const Duration(milliseconds: 90)) {
      return;
    }
    _lastNearMissAt = now;
    unawaited(_playBytes(_nearMiss, _nearMissBytes, volume: 0.42));
  }

  /// Шлем разбился — короткое стекло.
  static Future<void> helmetBreak() async {
    if (!_cfg.sfxHelmet) return;
    unawaited(_playBytes(_helmet, _helmetBytes, volume: 0.58));
  }

  /// Прыжок.
  static Future<void> jump() async {
    if (!_cfg.sfxJump) return;
    unawaited(_playBytes(_jump, _jumpBytes, volume: 0.45));
  }

  static Future<void> gameStart() async {
    if (!_cfg.sfxStart) return;
    unawaited(_playBytes(_start, _startBytes, volume: 0.5));
  }

  static Future<void> wallTick() => mobWall();

  static Future<void> wallHit() => heroWall();
}
