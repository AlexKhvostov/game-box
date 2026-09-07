/**
 * Firebase Remote Config client for Telegram Web.
 * Connects directly to project game-box-b30d4 via Firebase REST API.
 */

const FIREBASE_RC = {
  apiKey: 'AIzaSyBQ5iCD9OAotliddp-j0Dp-GfbeyqSKTsY',
  projectId: 'game-box-b30d4',
  appId: '1:332169968823:android:a485d65569bb1269d4e132',
};

const CACHE_KEY = 'untouch_firebase_rc_cache_v1';

export class RemoteConfigService {
  constructor() {
    this.templateVersion = null;
    this.lastFetchMs = 0;
  }

  /**
   * Загружает конфигурацию:
   * 1. Базовый локальный JSON (гарантия быстрого запуска).
   * 2. Накладывает кэш из localStorage (если был).
   * 3. В фоне/асинхронно запрашивает свежий Firebase Remote Config.
   */
  async loadConfig() {
    let config = {};

    // 1. Базовый локальный файл
    try {
      const res = await fetch('config/gameplay-config.json');
      if (res.ok) {
        config = await res.json();
      }
    } catch (e) {
      console.warn('[RemoteConfig] Local config fetch failed:', e);
    }

    // 2. Накладываем сохранённый кэш Firebase
    const cached = this._readCache();
    if (cached && cached.entries) {
      config = this._mergeEntries(config, cached.entries);
      this.templateVersion = cached.version;
    }

    // 3. Запускаем фоновое обновление с Firebase Remote Config
    this.fetchRemote(config).catch(() => {});

    return config;
  }

  /**
   * Запрашивает свежие данные из Firebase Remote Config REST API.
   */
  async fetchRemote(targetConfigToUpdate = null) {
    try {
      const url = `https://firebaseremoteconfig.googleapis.com/v1/projects/${FIREBASE_RC.projectId}/namespaces/firebase:fetch?key=${FIREBASE_RC.apiKey}`;
      const ctrl = typeof AbortController !== 'undefined' ? new AbortController() : null;
      const t = ctrl ? setTimeout(() => ctrl.abort(), 4000) : null;

      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          appId: FIREBASE_RC.appId,
          appInstanceId: 'tg_web_' + (localStorage.getItem('untouch_tg_inst') || this._getOrCreateInstId()),
        }),
        signal: ctrl?.signal,
      });

      if (t) clearTimeout(t);
      if (!res.ok) {
        console.warn('[RemoteConfig] Firebase fetch returned HTTP', res.status);
        return null;
      }

      const data = await res.json();
      if (!data || !data.entries) return null;

      this.templateVersion = data.templateVersion;
      this.lastFetchMs = Date.now();

      const parsedEntries = {};
      for (const [key, rawVal] of Object.entries(data.entries)) {
        try {
          parsedEntries[key] = JSON.parse(rawVal);
        } catch (_) {
          parsedEntries[key] = rawVal;
        }
      }

      this._writeCache({
        version: data.templateVersion,
        timestamp: Date.now(),
        entries: parsedEntries,
      });

      if (targetConfigToUpdate) {
        this._mergeEntries(targetConfigToUpdate, parsedEntries);
      }

      console.log(`[RemoteConfig] Firebase Remote Config v${data.templateVersion} active.`);
      return parsedEntries;
    } catch (e) {
      console.log('[RemoteConfig] Firebase offline or unavailable, using cached config');
      return null;
    }
  }

  _mergeEntries(base, entries) {
    if (!entries) return base;
    for (const [k, val] of Object.entries(entries)) {
      if (val && typeof val === 'object' && !Array.isArray(val) && base[k] && typeof base[k] === 'object') {
        base[k] = { ...base[k], ...val };
      } else if (val !== undefined) {
        base[k] = val;
      }
    }
    return base;
  }

  _readCache() {
    try {
      const raw = localStorage.getItem(CACHE_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }

  _writeCache(data) {
    try {
      localStorage.setItem(CACHE_KEY, JSON.stringify(data));
    } catch (_) {}
  }

  _getOrCreateInstId() {
    const id = Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
    try {
      localStorage.setItem('untouch_tg_inst', id);
    } catch (_) {}
    return id;
  }
}

export const remoteConfig = new RemoteConfigService();
