/** Web Audio SFX (lightweight, no audioplayers overhead). */

export class GameAudio {
  constructor(config) {
    this.config = config.audio;
    this.ctx = null;
    this.buffers = new Map();
    this._musicNode = null;
    this._musicGain = null;
    this.userMusicEnabled = true;
    this._lastWall = 0;
    this._lastNear = 0;
  }

  async init() {
    if (this.ctx) return;
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return;
    this.ctx = new Ctx();
    this._master = this.ctx.createGain();
    this._master.connect(this.ctx.destination);
    const files = {
      mob_wall: 'assets/sfx/mob_wall.wav',
      mob_collide: 'assets/sfx/mob_collide.wav',
      hero_mob: 'assets/sfx/hero_mob.wav',
      hero_wall: 'assets/sfx/hero_wall.wav',
      near_miss: 'assets/sfx/near_miss.wav',
      helmet_break: 'assets/sfx/helmet_break.wav',
      jump: 'assets/sfx/jump.wav',
      game_start: 'assets/sfx/game_start.wav',
      bgm_loop: 'assets/sfx/bgm_loop.wav',
    };
    await Promise.all(
      Object.entries(files).map(async ([k, url]) => {
        try {
          const res = await fetch(url);
          const ab = await res.arrayBuffer();
          this.buffers.set(k, await this.ctx.decodeAudioData(ab));
        } catch (e) {
          console.warn('audio load', k, e);
        }
      }),
    );
  }

  async resume() {
    if (this.ctx?.state === 'suspended') await this.ctx.resume();
  }

  _play(key, volume = 1) {
    if (!this.ctx) return;
    const buf = this.buffers.get(key);
    if (!buf) return;
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    const g = this.ctx.createGain();
    g.gain.value = volume * (this.config.sfxVolume ?? 0.85);
    src.connect(g);
    g.connect(this._master);
    src.start(0);
  }

  mobWall() {
    if (!this.config.sfxMobWall) return;
    const now = performance.now();
    if (now - this._lastWall < 70) return;
    this._lastWall = now;
    this._play('mob_wall');
  }

  mobCollide() {
    if (!this.config.sfxMobCollide) return;
    this._play('mob_collide', 0.7);
  }

  nearMiss() {
    if (!this.config.sfxNearMiss) return;
    const now = performance.now();
    if (now - this._lastNear < 140) return;
    this._lastNear = now;
    this._play('near_miss');
  }

  jump() {
    if (!this.config.sfxJump) return;
    this._play('jump');
  }

  heroMob() {
    if (!this.config.sfxHeroMob) return;
    this._play('hero_mob');
  }

  heroWall() {
    if (!this.config.sfxHeroWall) return;
    this._play('hero_wall');
  }

  helmetBreak() {
    if (!this.config.sfxHelmet) return;
    this._play('helmet_break');
  }

  gameStart() {
    if (!this.config.sfxStart) return;
    this._play('game_start');
  }

  stopMusic() {
    if (this._musicNode) {
      try { this._musicNode.stop(); } catch (_) {}
      try { this._musicNode.disconnect(); } catch (_) {}
      this._musicNode = null;
    }
    if (this._musicGain) {
      try { this._musicGain.disconnect(); } catch (_) {}
      this._musicGain = null;
    }
  }

  setUserMusicEnabled(on) {
    this.userMusicEnabled = Boolean(on);
    if (this.userMusicEnabled) {
      this.resume();
      this.ensureMusic();
    } else {
      this.stopMusic();
    }
  }

  async ensureMusic() {
    if (!this.userMusicEnabled || !this.config.music || !this.ctx) return;
    if (this._musicNode) return;
    const buf = this.buffers.get('bgm_loop');
    if (!buf) return;
    this._musicGain = this.ctx.createGain();
    this._musicGain.gain.value = this.config.musicVolume ?? 0.35;
    this._musicGain.connect(this._master);
    this._musicNode = this.ctx.createBufferSource();
    this._musicNode.buffer = buf;
    this._musicNode.loop = true;
    this._musicNode.connect(this._musicGain);
    this._musicNode.start(0);
  }
}
