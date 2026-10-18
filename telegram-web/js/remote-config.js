/** Hosting configuration. The Mini App no longer fetches Firebase. */
import { GameWorld } from './game-world.js?v=v1.0.22_20261003_233329_134';

const CACHE_KEY = 'untouch_hosting_config_v1';
const DEFAULT_MOBILE_PACE = Object.freeze({ startSpeedSteps: 34.72, accelerationSteps: 4.63 });
function mobilePace(config) {
  const raw = config.mobileEnemies;
  const pace = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : DEFAULT_MOBILE_PACE;
  if (!Number.isFinite(pace.startSpeedSteps) || pace.startSpeedSteps < 0.01 || pace.startSpeedSteps > 250 ||
      !Number.isFinite(pace.accelerationSteps) || pace.accelerationSteps < 0 || pace.accelerationSteps > 50) {
    throw new Error('Invalid mobile enemy pace');
  }
  return pace;
}
/** Same startup-only snapshot conversion as Android MobileGameplayTuning. */
export function applyMobileGameplayTuning(config) {
  const pace = mobilePace(config);
  const step = Math.max(1e-6, config.player.size * GameWorld.characterSizeScale * 0.1);
  const speed = pace.startSpeedSteps * step;
  const acceleration = pace.accelerationSteps * step;
  return {
    ...config,
    enemies: { ...config.enemies, speedMin: speed * 0.95, speedMax: speed * 1.05,
      accelMin: acceleration * 0.92, accelMax: acceleration * 1.08 },
    game: { ...config.game, speedRampSeconds: 0 },
    mobileEnemies: { ...pace },
  };
}
function isUsable(config) {
  const usable = config && ['theme', 'enemies', 'player', 'field', 'game', 'audio', 'economy'].every(key => config[key] && typeof config[key] === 'object')
    && Array.isArray(config.enemies.aspects) && config.enemies.aspects.length > 0
    && Number.isFinite(config.player.size) && config.player.size > 0;
  if (!usable) return false;
  try { mobilePace(config); return true; } catch (_) { return false; }
}
async function readJson(url, timeoutMs = 2500) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { signal: controller.signal, cache: 'no-cache' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } finally { clearTimeout(timer); }
}
export class RemoteConfigService {
  constructor() { this.templateVersion = null; this.lastFetchMs = 0; }
  async loadConfig() {
    try {
      const published = await readJson('api/config.php');
      if (!published.ok || !isUsable(published.config)) throw new Error('Invalid hosting config');
      this.templateVersion = published.revision;
      this.lastFetchMs = Date.now();
      try { localStorage.setItem(CACHE_KEY, JSON.stringify(published)); } catch (_) {}
      return applyMobileGameplayTuning(published.config);
    } catch (_) {
      try {
        const cached = JSON.parse(localStorage.getItem(CACHE_KEY) || 'null');
        if (isUsable(cached?.config)) { this.templateVersion = cached.revision; return applyMobileGameplayTuning(cached.config); }
      } catch (_) {}
      const defaults = await readJson('config/gameplay-config.json');
      if (!isUsable(defaults)) throw new Error('Не удалось загрузить настройки игры');
      return applyMobileGameplayTuning(defaults);
    }
  }
}
export const remoteConfig = new RemoteConfigService();
