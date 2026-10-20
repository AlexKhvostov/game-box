import { state } from '../services/game-store';
import { telegram } from './telegram';
const files: Record<string, string> = { start: 'game_start', wall: 'mob_wall', collide: 'mob_collide', hit: 'hero_mob', heroWall: 'hero_wall', helmet: 'helmet_break', jump: 'jump', risk: 'near_miss' };
const flags: Record<string, string> = { start: 'sfxStart', wall: 'sfxMobWall', collide: 'sfxMobCollide', hit: 'sfxHeroMob', heroWall: 'sfxHeroWall', helmet: 'sfxHelmet', jump: 'sfxJump', risk: 'sfxNearMiss' };
const gains: Record<string, number> = { wall: .7, collide: .55, hit: .8, heroWall: .8, helmet: .65, jump: .45, risk: .6, start: .5 };
const sounds = new Map<string, HTMLAudioElement[]>(), last = new Map<string, number>();
let music: HTMLAudioElement | undefined, enabled = false;
export function enableAudio() { enabled = true; syncMusic(); }
export function syncMusic() {
  if (!enabled || document.hidden || telegram()?.isActive === false || state.externalBusy || !state.preferences.music || state.config?.config.audio.music === false) { music?.pause(); return; }
  music ??= new Audio('/assets/sfx/bgm_loop.wav'); music.loop = true; music.volume = state.config?.config.audio.musicVolume ?? .35; void music.play().catch(() => {});
}
export function sound(name: string) {
  if (!enabled || document.hidden || telegram()?.isActive === false || state.externalBusy || !state.preferences.sound || state.config?.config.audio[flags[name]!] === false) return;
  const stamp = performance.now(), gap = name === 'wall' ? 70 : name === 'collide' ? 90 : name === 'risk' ? 140 : 0;
  if (stamp - (last.get(name) ?? -1000) < gap || !files[name]) return; last.set(name, stamp);
  if (!sounds.has(name)) sounds.set(name, Array.from({ length: name === 'wall' ? 3 : 1 }, () => new Audio(`/assets/sfx/${files[name]}.wav`)));
  const pool = sounds.get(name)!, item = pool.find(a => a.paused) ?? pool[0]!;
  item.currentTime = 0; item.volume = (state.config?.config.audio.sfxVolume ?? .85) * (gains[name] ?? .5); void item.play().catch(() => {});
}
export function stopAudio() { music?.pause(); for (const pool of sounds.values()) for (const a of pool) a.pause(); }
