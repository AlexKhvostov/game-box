import { motionProbe } from '../game/motion-probe';
export interface JsonStorage { get<T>(key: string, fallback: T): T; set(key: string, value: unknown): void }
export class DurableStorage implements JsonStorage {
  get<T>(key: string, fallback: T): T {
    try { const value = localStorage.getItem(`untouch_tg_v2:${key}`); return value === null ? fallback : JSON.parse(value); }
    catch { throw new Error('storage_unavailable'); }
  }
  set(key: string, value: unknown) {
    const started=motionProbe.clock();
    try { const text = JSON.stringify(value); localStorage.setItem(`untouch_tg_v2:${key}`, text); if (localStorage.getItem(`untouch_tg_v2:${key}`) !== text) throw new Error();motionProbe.persisted(motionProbe.clock()-started,text.length); }
    catch { throw new Error('storage_unavailable'); }
  }
}
export const operationId = () => [...crypto.getRandomValues(new Uint8Array(32))].map(b => b.toString(16).padStart(2, '0')).join('');
