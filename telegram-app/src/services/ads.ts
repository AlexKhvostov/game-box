import { reactive, watch } from 'vue';
import { state, walletOperation, now, energy, request } from './game-store';
import { DurableStorage, operationId } from './storage';
import { ensureResourceAge, requestRewardedAds, canShowRewardedAds, canShowAds } from '../platform/audience';
import { adPresenter } from '../platform/adsgram';
import { isNativeTelegram, telegram } from '../platform/telegram';
import { stopAudio, syncMusic } from '../platform/audio';
import { ApiError } from './api';
export const adsState = reactive({ showing: false, pending: false });
const storage = new DurableStorage();
interface AdReceipt { owner: string; sessionId: string; watched: boolean; claimId: string }
let volatileReceipt: AdReceipt | null = null;
const deliveries = new Map<string, Promise<void>>();
export const adsAvailable = () => isNativeTelegram() && state.platform?.ads.enabled === true && /^\d+$/.test(state.platform.ads.rewardedBlockId);
export function deliverAdReward(): Promise<void> {
  const owner=state.profile?.id;if(!owner)return Promise.resolve();
  const active=deliveries.get(owner);if(active)return active;
  const job=deliverForOwner(owner).finally(()=>{if(deliveries.get(owner)===job)deliveries.delete(owner);});deliveries.set(owner,job);return job;
}
async function deliverForOwner(owner: string) {
  const key = `ad-receipt:${owner}`, receipt = volatileReceipt?.owner===owner ? volatileReceipt : storage.get<AdReceipt | null>(key, null);
  if (!receipt?.watched || receipt.owner !== owner) { adsState.pending = false; return; }
  adsState.pending = true;
  // Save callback before sending. Failed storage/HTTP keeps retryable receipt.
  storage.set(key, receipt); if(volatileReceipt?.claimId===receipt.claimId)volatileReceipt = null;
  if(state.profile?.id!==owner)throw Error('owner_changed');
  try { await walletOperation('watch_ad', { sessionId: receipt.sessionId }, receipt.claimId); }
  catch(error) {
    if (!(error instanceof ApiError) || !['ad_session_expired','ad_session_invalid','ad_session_claimed'].includes(error.code)) throw error;
    if(error.code==='ad_session_claimed') {
      // The server may have committed a previous claim before the reply was lost.
      // Refresh the authoritative wallet; never grant locally.
      await request({action:'profile'});
    } else state.notice=state.locale==='ru'?'Срок получения этой награды истёк. Можно посмотреть новое видео.':'This viewing reward has expired. You can watch another video.';
  }
  const current=storage.get<AdReceipt | null>(key,null);
  if(current?.claimId===receipt.claimId&&current.sessionId===receipt.sessionId)storage.set(key,null);
  adsState.pending = !!volatileReceipt?.watched || !!storage.get<AdReceipt | null>(key,null)?.watched;
}
export async function watchRewardedAd() {
  if (adsState.showing) return;
  const initiatingOwner=state.profile?.id;
  if(!initiatingOwner)throw Error('owner_changed');
  adsState.showing=true;
  try{
  await deliverAdReward();
  if(state.profile?.id!==initiatingOwner)throw Error('owner_changed');
  if (!adsAvailable()) throw Error('ad_unavailable');
  if (!await ensureResourceAge()) return;
  if(state.profile?.id!==initiatingOwner)throw Error('owner_changed');
  if(!adsAvailable()||state.screen!=='video'||document.hidden||telegram()?.isActive===false)throw Error('ad_unavailable');
  requestRewardedAds(); if (!canShowRewardedAds()) throw Error('ad_age_restricted');
  const owner = state.profile!.id, sessionId = operationId(), blockId=state.platform!.ads.rewardedBlockId;
  await walletOperation('rewarded_ad_start', { sessionId });
  const receipt = { owner, sessionId, watched: false, claimId: operationId() }; storage.set(`ad-receipt:${owner}`, receipt);
  adsState.showing = true; state.externalBusy = true; stopAudio();
  const cancel=()=>adPresenter.destroy();telegram()?.onEvent('deactivated',cancel);
  try {
    const canShow = () => adsAvailable() && state.platform?.ads.rewardedBlockId===blockId && canShowRewardedAds() && state.profile?.id === owner && state.screen==='video' && !document.hidden && telegram()?.isActive !== false;
    if(!canShow())return;
    const watched = await adPresenter.show(blockId, true, false, canShow);
    if (watched && state.profile?.id === owner) { volatileReceipt = { ...receipt, watched: true }; adsState.pending = true; await deliverAdReward(); }
    else state.notice = state.locale === 'ru' ? 'Просмотр не завершён. Энергия не начислена.' : 'Viewing was not completed. No energy was added.';
  } finally { telegram()?.offEvent('deactivated',cancel); adsState.showing = false; state.externalBusy = false; if (!document.hidden && telegram()?.isActive !== false) syncMusic(); }
  }finally{adsState.showing=false;}
}
let sessionStarted = performance.now(), lastInterstitial = -Infinity, completedRounds = 0;
let interstitialOwner: string | null = null, ownerEpoch = 0, interstitialInFlight = false;
let latestRound: string | null = null, attemptedRound: string | null = null;
const completedIds = new Set<string>();
watch(() => state.profile?.id ?? null, owner => {
  interstitialOwner = owner; ownerEpoch++;
  sessionStarted = performance.now(); lastInterstitial = -Infinity; completedRounds = 0;
  latestRound = attemptedRound = null; completedIds.clear();
  if (interstitialInFlight) adPresenter.destroy();
}, {immediate:true, flush:'sync'});
watch(() => state.platform?.ads.interstitialEnabled, enabled => {
  if (enabled !== true && interstitialInFlight) adPresenter.destroy();
}, {flush:'sync'});
export function completedRound(id: string) {
  if (state.profile?.id !== interstitialOwner || !id || completedIds.has(id)) return;
  completedIds.add(id); completedRounds++; latestRound = id;
}
function interstitialReady() {
  const config = state.config?.config.economy, profile = state.profile, ads = state.platform?.ads;
  if (!config || !profile || profile.id !== interstitialOwner || !ads || ads.enabled !== true || ads.interstitialEnabled !== true ||
      !/^int-\d+$/.test(ads.interstitialBlockId) || !canShowAds() || !isNativeTelegram() || document.hidden ||
      telegram()?.isActive === false || state.screen !== 'result' || !latestRound || state.resultId !== latestRound) return false;
  const keys = ['interstitialSessionGraceSec','interstitialSessionFreeRounds','interstitialGraceSec','interstitialCooldownSec','interstitialMinLives'];
  if (keys.some(key => !Number.isFinite(config[key]) || config[key] < 0)) return false;
  const stamp = performance.now(), wallNow = now(), wallet = profile.wallet, subscription = wallet.energySubscription;
  if (subscription && (subscription.expiresAt > wallNow || subscription.awaitingReconciliation)) return false;
  // Energy-v2 records the actual simple-bonus receipt. Before the first receipt,
  // use this account's session clock instead of requiring a legacy daily claim.
  const claimed = wallet.simpleBonus?.lastClaimAt;
  const graceElapsed = typeof claimed === 'number' && Number.isFinite(claimed) && claimed > 0 ? wallNow - claimed : stamp - sessionStarted;
  return stamp - sessionStarted >= Math.max(180,config.interstitialSessionGraceSec)*1000 &&
    completedRounds > Math.max(10,config.interstitialSessionFreeRounds) &&
    Number.isFinite(energy.value) && energy.value >= config.interstitialMinLives &&
    stamp - lastInterstitial >= config.interstitialCooldownSec*1000 && graceElapsed >= config.interstitialGraceSec*1000;
}
export async function maybeResultInterstitial() {
  if (adsState.showing || attemptedRound === latestRound || !interstitialReady()) return;
  // At most one automatic SDK attempt for a result, including no-fill/errors.
  attemptedRound = latestRound;
  adsState.showing = true; state.externalBusy = true; stopAudio();
  interstitialInFlight = true;
  const epoch=ownerEpoch,roundId=latestRound,blockId=state.platform!.ads.interstitialBlockId,revision=state.config?.revision;
  const canShow=()=>epoch===ownerEpoch&&latestRound===roundId&&state.platform?.ads.interstitialBlockId===blockId&&state.config?.revision===revision&&interstitialReady();
  const cancel=()=>adPresenter.destroy();telegram()?.onEvent('deactivated',cancel);
  try {
    if (await adPresenter.show(blockId, false, false, canShow) && epoch===ownerEpoch) {
      lastInterstitial = performance.now();
    }
  } finally { telegram()?.offEvent('deactivated',cancel);interstitialInFlight=false;adsState.showing=false;state.externalBusy=false;if(!document.hidden&&telegram()?.isActive!==false)syncMusic(); }
}
window.addEventListener('online', () => { void deliverAdReward().catch(() => {}); });
