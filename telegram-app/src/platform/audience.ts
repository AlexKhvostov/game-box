import { DurableStorage } from '../services/storage';
import { state, openScreen } from '../services/game-store';
export type AgeBand = 'under18' | 'adult18plus';
const storage = new DurableStorage();
// Declaration stays on this device. Consent always starts off in each session.
let resolvePrompt: ((allowed: boolean) => void) | null = null;
let prompt: Promise<boolean> | null = null;
let adsEnabled = false, rewardedRequested = false, revoked = false;
export function ageBand(): AgeBand | null { const value = storage.get<string | null>('ageBand', null); return value === 'under18' || value === 'adult18plus' ? value : null; }
export function saveAgeBand(value: AgeBand) { storage.set('ageBand', value); adsEnabled = false; rewardedRequested = false; }
export function allowAds() { if (ageBand() === 'adult18plus' && !revoked) adsEnabled = true; }
export function requestRewardedAds() { if (ageBand() === 'adult18plus' && !revoked) rewardedRequested = true; }
export function revokeAds() { adsEnabled = false; rewardedRequested = false; revoked = true; }
export const canShowAds = () => ageBand() === 'adult18plus' && !revoked && adsEnabled;
export const canShowRewardedAds = () => ageBand() === 'adult18plus' && !revoked && (adsEnabled || rewardedRequested);
export async function ensureResourceAge() {
  if (ageBand()) return true;
  if (!prompt) { prompt = new Promise<boolean>(resolve => resolvePrompt = resolve); openScreen('age', state.screen); }
  return prompt;
}
export function offerStartupAge(){
  if(ageBand()||storage.get('startupAgeAsked',false))return;
  storage.set('startupAgeAsked',true);openScreen('age');
}
export function finishAgePrompt(allowed: boolean) { const resolve = resolvePrompt; resolvePrompt = null; prompt = null; resolve?.(allowed); }
