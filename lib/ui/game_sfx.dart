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
  static Future<void>? _preparing;

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

  /// Уже привязанный источник — на web не пересоздаём BytesSource каждый hit.
  static final Expando<Object> _boundSource = Expando<Object>('sfxSrc');
  static final Expando<double> _boundVolume = Expando<double>('sfxVolume');

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
  static bool _backgrounded = false;

  /// На web частые one-shot сильнее дают микрофризы.
  static Duration get _wallGap => kIsWeb
      ? const Duration(milliseconds: 70)
      : const Duration(milliseconds: 28);
  static Duration get _collideGap => kIsWeb
      ? const Duration(milliseconds: 90)
      : const Duration(milliseconds: 45);
  static Duration get _nearMissGap => kIsWeb
      ? const Duration(milliseconds: 140)
      : const Duration(milliseconds: 90);

  static Future<void> _ensureReady() {
    if (_ready) return Future<void>.value();
    return _preparing ??= _prepare();
  }

  static Future<void> _prepare() async {
    try {
      if (!kIsWeb) {
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
              // Ambient уже смешивается с другим звуком; явная опция
              // mixWithOthers недопустима для этой категории.
              options: {},
            ),
          ),
        );
      }

      _mobWallBytes = (await rootBundle.load(
        'assets/sfx/mob_wall.wav',
      )).buffer.asUint8List();
      _mobCollideBytes = (await rootBundle.load(
        'assets/sfx/mob_collide.wav',
      )).buffer.asUint8List();
      _heroMobBytes = (await rootBundle.load(
        'assets/sfx/hero_mob.wav',
      )).buffer.asUint8List();
      _heroWallBytes = (await rootBundle.load(
        'assets/sfx/hero_wall.wav',
      )).buffer.asUint8List();
      _nearMissBytes = (await rootBundle.load(
        'assets/sfx/near_miss.wav',
      )).buffer.asUint8List();
      _helmetBytes = (await rootBundle.load(
        'assets/sfx/helmet_break.wav',
      )).buffer.asUint8List();
      _jumpBytes = (await rootBundle.load(
        'assets/sfx/jump.wav',
      )).buffer.asUint8List();
      _startBytes = (await rootBundle.load(
        'assets/sfx/game_start.wav',
      )).buffer.asUint8List();

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
        await p.setPlayerMode(
          kIsWeb ? PlayerMode.mediaPlayer : PlayerMode.lowLatency,
        );
        await p.setReleaseMode(ReleaseMode.stop);
        // SFX have no position UI. SoundPool doesn't report playback position
        // or completion; polling it every frame can otherwise continue even
        // after a short sound has ended and flood the platform/UI thread.
        p.positionUpdater = null;
      }
      await _music.setPlayerMode(PlayerMode.mediaPlayer);
      await _music.setReleaseMode(ReleaseMode.loop);
      _music.positionUpdater = null;
      if (!kIsWeb) {
        // Prepare native SoundPool samples before the first bounce/jump. A
        // cached byte buffer alone did not load the native playback source.
        final effects = <AudioPlayer, (String, Uint8List?)>{
          for (final p in _wallPool) p: ('sfx/mob_wall.wav', _mobWallBytes),
          _mobCollide: ('sfx/mob_collide.wav', _mobCollideBytes),
          _heroMob: ('sfx/hero_mob.wav', _heroMobBytes),
          _heroWall: ('sfx/hero_wall.wav', _heroWallBytes),
          _nearMiss: ('sfx/near_miss.wav', _nearMissBytes),
          _helmet: ('sfx/helmet_break.wav', _helmetBytes),
          _jump: ('sfx/jump.wav', _jumpBytes),
          _start: ('sfx/game_start.wav', _startBytes),
        };
        for (final entry in effects.entries) {
          await entry.key.setSource(AssetSource(entry.value.$1));
          _boundSource[entry.key] = entry.value.$2;
        }
      }
      _ready = true;
    } catch (e) {
      debugPrint('GameSfx._ensureReady: $e');
    } finally {
      _preparing = null;
    }
  }

  static void applyConfig(AudioConfig config) {
    if (identical(_cfg, config) ||
        (_cfg.music == config.music &&
            _cfg.musicVolume == config.musicVolume &&
            _cfg.sfxVolume == config.sfxVolume &&
            _cfg.sfxMobWall == config.sfxMobWall &&
            _cfg.sfxMobCollide == config.sfxMobCollide &&
            _cfg.sfxHeroMob == config.sfxHeroMob &&
            _cfg.sfxHeroWall == config.sfxHeroWall &&
            _cfg.sfxNearMiss == config.sfxNearMiss &&
            _cfg.sfxHelmet == config.sfxHelmet &&
            _cfg.sfxJump == config.sfxJump &&
            _cfg.sfxStart == config.sfxStart)) {
      // Тот же конфиг — не трогаем audio pipeline.
      if (!_ready) unawaited(_ensureReady());
      return;
    }
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

  static Future<void> onAppPaused() async {
    _backgrounded = true;
    try {
      await _music.pause();
    } catch (_) {}
  }

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
    required String asset,
  }) async {
    await _ensureReady();
    if (bytes == null || bytes.isEmpty) return;
    try {
      final effectiveVolume = _sfxVol(volume);
      if (_boundVolume[player] != effectiveVolume) {
        await player.setVolume(effectiveVolume);
        _boundVolume[player] = effectiveVolume;
      }
      // На web stop()+новый BytesSource каждый кадр → микрофризы.
      // Держим источник и переигрываем через seek/resume.
      final Source source = kIsWeb
          ? BytesSource(bytes, mimeType: 'audio/wav')
          : AssetSource(asset);
      if (!identical(_boundSource[player], bytes)) {
        // Android SoundPool rejects BytesSource in low-latency mode. Bundled
        // assets resolve to a cached local file supported by SoundPool.
        await player.setSource(source);
        _boundSource[player] = bytes;
      }
      if (kIsWeb) {
        await player.seek(Duration.zero);
      } else {
        // Keep the loaded source, restart its stream; SoundPool has no normal
        // position/seek-complete contract like the web media player.
        await player.stop();
      }
      await player.resume();
    } catch (e) {
      // Fallback: полный play (старые/капризные плееры).
      try {
        await player.stop();
        await player.setVolume(_sfxVol(volume));
        await player.play(
          kIsWeb
              ? BytesSource(bytes, mimeType: 'audio/wav')
              : AssetSource(asset),
        );
        _boundSource[player] = bytes;
      } catch (e2) {
        debugPrint('GameSfx.playBytes: $e2');
      }
    }
  }

  static Future<void> mobWall() async {
    // На web/Telegram WebView one-shot при каждом ударе моба о стену
    // даёт периодические микрофризы кадра — отключаем.
    if (kIsWeb || !_cfg.sfxMobWall) return;
    final now = DateTime.now();
    if (_lastMobWallAt != null && now.difference(_lastMobWallAt!) < _wallGap) {
      return;
    }
    _lastMobWallAt = now;
    final player = _wallPool[_wallPoolIdx % _wallPool.length];
    _wallPoolIdx++;
    unawaited(
      _playBytes(player, _mobWallBytes, volume: 0.7, asset: 'sfx/mob_wall.wav'),
    );
  }

  static Future<void> mobCollide() async {
    if (kIsWeb || !_cfg.sfxMobCollide) return;
    final now = DateTime.now();
    if (_lastMobCollideAt != null &&
        now.difference(_lastMobCollideAt!) < _collideGap) {
      return;
    }
    _lastMobCollideAt = now;
    unawaited(
      _playBytes(
        _mobCollide,
        _mobCollideBytes,
        volume: 0.55,
        asset: 'sfx/mob_collide.wav',
      ),
    );
  }

  static Future<void> heroMob() async {
    if (!_cfg.sfxHeroMob) return;
    unawaited(
      _playBytes(
        _heroMob,
        _heroMobBytes,
        volume: 0.72,
        asset: 'sfx/hero_mob.wav',
      ),
    );
  }

  static Future<void> heroWall() async {
    if (!_cfg.sfxHeroWall) return;
    unawaited(
      _playBytes(
        _heroWall,
        _heroWallBytes,
        volume: 0.7,
        asset: 'sfx/hero_wall.wav',
      ),
    );
  }

  static Future<void> nearMiss() async {
    if (!_cfg.sfxNearMiss) return;
    final now = DateTime.now();
    if (_lastNearMissAt != null &&
        now.difference(_lastNearMissAt!) < _nearMissGap) {
      return;
    }
    _lastNearMissAt = now;
    unawaited(
      _playBytes(
        _nearMiss,
        _nearMissBytes,
        volume: 0.42,
        asset: 'sfx/near_miss.wav',
      ),
    );
  }

  static Future<void> helmetBreak() async {
    if (!_cfg.sfxHelmet) return;
    unawaited(
      _playBytes(
        _helmet,
        _helmetBytes,
        volume: 0.58,
        asset: 'sfx/helmet_break.wav',
      ),
    );
  }

  static Future<void> jump() async {
    if (!_cfg.sfxJump) return;
    unawaited(
      _playBytes(_jump, _jumpBytes, volume: 0.45, asset: 'sfx/jump.wav'),
    );
  }

  static Future<void> gameStart() async {
    if (!_cfg.sfxStart) return;
    unawaited(
      _playBytes(_start, _startBytes, volume: 0.5, asset: 'sfx/game_start.wav'),
    );
  }

  static Future<void> wallTick() => mobWall();

  static Future<void> wallHit() => heroWall();
}
