import { computed, reactive, shallowRef } from 'vue';
import { TelegramApi, ApiError } from './api';
import { DurableStorage, operationId } from './storage';
import { RoundJournal } from './journal';
import type { ApiResult, Profile, GameConfig, PlatformConfig, AverageBoard, InviteState, Attempt, Score } from './contracts';
import type { WorldState, RoundProof } from '../domain/kernel';
import { transportErrorText, type ConnectionStatus } from './connection';
import { telegram } from '../platform/telegram';
import {closeTopOverlay} from './ui-overlays';
import {readBootstrap,sessionHash,type Bootstrap,type OfflineIdentity} from './bootstrap-cache';
import {emitResultReward} from './reward-events';
import {ServerHistoryLoader} from '../domain/server-attempt-history';
import type {AttemptHistorySnapshot} from './contracts';
const storage = new DurableStorage();
export const state = reactive({ profile: null as Profile | null, config: null as GameConfig | null, platform: null as PlatformConfig | null,
  initialized: false, online: true, connection: 'unknown' as ConnectionStatus, busy: false, externalBusy: false, error: '', notice: '', screen: '' as string, parent: '',
  helmet: false, jump: false, history: [] as Attempt[], periods: {} as Record<string, Score[]>, average: null as AverageBoard | null,
  serverHistory: null as AttemptHistorySnapshot | null, historyLoading: false, historyError: '',
  invites: null as InviteState | null, period: 'all', rankingTab: 'record', locale: 'ru',
  preferences: { sound: true, music: true, vibration: true }, serverOffset: 0, resultId: '', selectedScore: null as Score | null, selectedPlayer:null as {userId:string;playerName:string}|null, rulesAccepted: false });
export const api = new TelegramApi(status => { state.connection = status; state.online = status !== 'offline'; });
export const world = shallowRef<WorldState | null>(null);
export const failedFinish = shallowRef<{ id: string; owner: string; result: NonNullable<Attempt['result']>; finishedAt: number } | null>(import.meta.hot?.data.failedFinish ?? null);
let journal: RoundJournal | null = null, flushing: Promise<void> | null = null, retryTimer: ReturnType<typeof setTimeout> | null = null;
let generation = 0;
let disposed = false;
let pendingConfig: GameConfig | null = null, serverAnchor = 0, monotonicAnchor = 0;
let requestSerial = 0, configSerial = 0;
let liveResultId='';
let bootstrapHash='',bootstrapIdentity:OfflineIdentity|null=null,profileReceivedAt=0;
let initializationFlight:Promise<void>|undefined;
let bootstrapRetry:ReturnType<typeof setTimeout>|undefined,bootstrapFlight:Promise<void>|undefined;
const serverHistory=new ServerHistoryLoader(body=>request(body),value=>{state.serverHistory=value.snapshot;state.historyLoading=value.loading;state.historyError=value.error;},storage);
export function refreshAttemptHistory(){serverHistory.setOwner(state.profile?.id??'');return serverHistory.refresh();}
export function moreAttemptHistory(){serverHistory.setOwner(state.profile?.id??'');return serverHistory.more();}
export function retryAttemptHistory(){serverHistory.setOwner(state.profile?.id??'');return serverHistory.retry();}
function cacheBootstrap(){
  if(!state.profile||!state.config||!bootstrapHash)return;
  const cached:Bootstrap={version:1,namespace:api.cacheNamespace(),profile:state.profile,config:state.config,platform:state.platform,identity:bootstrapIdentity,sessionHash:bootstrapHash,receivedAt:profileReceivedAt};
  try{storage.set('bootstrap:v1',cached);}catch{/* Optional startup cache must not prevent persisting a game proof. */}
}
const writerHost = window as Window & { __untouchWriter?: { owner: string; release: () => void } };
async function acquireWriter(owner: string) {
  if(disposed)return;
  if (writerHost.__untouchWriter?.owner === owner) return;
  if (!navigator.locks) throw new Error('browser_update_required');
  writerHost.__untouchWriter?.release();
  await new Promise<void>((resolve, reject) => {
    void navigator.locks.request(`untouch_tg_v2:writer:${owner}`, { ifAvailable: true }, async lock => {
      if (!lock) { reject(new Error('another_window_active')); return; }
      if(disposed){resolve();return;}
      let releaseCurrent!: () => void;
      await new Promise<void>(release => { releaseCurrent = release; writerHost.__untouchWriter = { owner, release }; resolve(); });
      if (writerHost.__untouchWriter?.release === releaseCurrent) writerHost.__untouchWriter = undefined;
    }).catch(reject);
  });
}
export const energy = computed(() => Math.max(0, (state.profile?.wallet.energy ?? 0) - state.history.filter(a => a.phase === 'prepared'||a.debitWalletVersion!==undefined&&a.debitWalletVersion>(state.profile?.walletVersion??0)).reduce((sum, a) => sum + a.cost, 0)));
export const attemptCost = computed(() => { const e = state.profile?.wallet.energyConfig; return e ? e.baseAttemptCost + (state.helmet ? e.helmetExtraCost : 0) + (state.jump ? e.jumpExtraCost : 0) : 0; });
export function now() { return serverAnchor ? serverAnchor + performance.now() - monotonicAnchor : Date.now(); }
export function applyPendingConfig() { if (pendingConfig) { state.config = pendingConfig; pendingConfig = null; } }
function history() { state.history = journal?.all ?? []; }
function accept(result: ApiResult, serial: number) {
  if(result.offlineIdentity?.environment==='production'&&/^\d{5,15}$/.test(result.offlineIdentity.botId??'')&&/^\d+$/.test(result.offlineIdentity.subject??''))bootstrapIdentity=result.offlineIdentity;
  if (result.profile) {
    if (state.profile && state.profile.id !== result.profile.id) { generation++; journal = null; serverHistory.setOwner(''); throw new Error('owner_changed'); }
    if (state.profile && (result.profile.walletVersion < state.profile.walletVersion ||
      (result.profile.walletVersion === state.profile.walletVersion && result.profile.serverNow < state.profile.serverNow))) return;
    if (!state.profile || result.profile.walletVersion >= state.profile.walletVersion) {
      storage.set(`profile:${result.profile.id}`, result.profile); state.profile = result.profile;profileReceivedAt=Date.now();
      state.serverOffset = result.profile.serverNow - Date.now();
      serverAnchor = result.profile.serverNow; monotonicAnchor = performance.now();
    }
  }
  if (serial >= configSerial && (result.gameConfig || result.platformConfig)) {
    configSerial = serial;
    if (result.gameConfig) { storage.set(`config:${result.profile?.id ?? state.profile!.id}`, result.gameConfig); if (world.value?.playing) pendingConfig = result.gameConfig; else { pendingConfig = null; state.config = result.gameConfig; } }
    if (result.platformConfig) state.platform = result.platformConfig;
  }
  cacheBootstrap();
}
export const errorText = (error: unknown) => {
  const code = error instanceof Error ? error.message : String(error);
  const transportMessage = transportErrorText(code,state.locale); if(transportMessage)return transportMessage;
  const english:Record<string,string>={
    native_telegram_required:'Open this game in the Telegram app.', api_not_configured:'The game connection is being configured.', qa_server_unavailable:'The local test server is not running.', insufficient_energy:'Not enough energy.', nickname_taken:'This name is already taken.', nickname_invalid:'Use 2–24 characters for your name.', nickname_prohibited:'Choose another name.', bonus_not_ready:'Your bonus is still recharging.', feedback_locked:'Feedback unlocks after spending 100 energy.', feedback_length:'Write 20–1000 characters.', invite_self:'You cannot invite yourself.', invite_not_found:'Invite code not found.', invite_already_bound:'Your inviter is already assigned.', invite_code_invalid:'Check the invite code.', invite_cursor_invalid:'The invitation list changed. Refresh and try again.', storage_unavailable:'Could not save data on this device. Free storage space and retry.', public_rules_required:'Accept the community rules first.', rules_changed:'Settings have changed. Wait for synchronization.', telegram_session_expired:'Your Telegram session expired. Close and reopen the game.', profile_disabled:'This profile is unavailable.', ad_daily_limit:'Today’s ad reward limit has been reached.', ad_not_ready:'Please wait before watching another video.', another_window_active:'The game is open in another window. Close it and retry.', browser_update_required:'Update Telegram: this browser does not support safe game storage.', ad_unavailable:'Ads are unavailable. Please try later.', ad_age_restricted:'Ads are available to adults only. Other energy sources remain available.', invoice_expired:'This invoice expired. Tap again to create a new one.', checkout_in_progress:'Another checkout is already in progress.', stars_unavailable:'Purchases are not available yet.', subscription_active:'You already have an active subscription.', qa_account_locked:'This temporary test is reserved for another account.'
  };
  if(state.locale==='en')return english[code]??'Could not confirm this action. Please retry.';
  const labels: Record<string, string> = { native_telegram_required: 'Откройте игру в приложении Telegram.', api_not_configured: 'Подключение игры ещё настраивается.', qa_server_unavailable: 'Локальный тестовый сервер не запущен.', insufficient_energy: 'Недостаточно энергии.', nickname_taken: 'Это имя уже занято.', nickname_invalid: 'Имя: от 2 до 24 символов.', nickname_prohibited: 'Выберите другое имя.', bonus_not_ready: 'Бонус ещё заряжается.', feedback_locked: 'Отзыв откроется после траты 100 энергии.', feedback_length: 'Напишите от 20 до 1000 символов.', invite_self: 'Нельзя пригласить самого себя.', invite_not_found: 'Код не найден.', invite_already_bound: 'Пригласивший уже указан.', invite_code_invalid: 'Проверьте код приглашения.', storage_unavailable: 'Не удалось сохранить данные на устройстве. Освободите место и повторите.', public_rules_required: 'Сначала примите правила сообщества.', rules_changed: 'Настройки обновились. Подождите синхронизации.', telegram_session_expired: 'Сессия Telegram закончилась. Закройте и откройте игру снова.', profile_disabled: 'Этот профиль недоступен.', ad_daily_limit: 'Лимит рекламных наград на сегодня исчерпан.', ad_not_ready: 'Подождите перед следующим просмотром.' };
  if (code === 'another_window_active') return 'Игра уже открыта в другом окне. Закройте его и повторите.';
  if (code === 'browser_update_required') return 'Обновите Telegram: текущая версия не поддерживает безопасное сохранение игры.';
  if(code==='invoice_expired')return 'Счёт устарел. Нажмите ещё раз, чтобы создать новый.';
  if(code==='checkout_in_progress')return 'Другая покупка ещё не завершена.';
  if (code === 'ad_unavailable') return 'Реклама пока недоступна. Попробуйте позже.';
  if (code === 'ad_age_restricted') return 'Реклама доступна только совершеннолетним. Другие способы получения энергии остаются доступны.';
  return labels[code] ?? 'Не удалось подтвердить действие. Повторите.';
};
export async function request(body: Record<string, unknown>,beforeAccept?:(result:ApiResult)=>void) {
  if(disposed)throw new Error('store_disposed');
  const serial=++requestSerial,epoch=generation;
  try{
    const result=await api.execute(body);
    if(disposed)throw new Error('store_disposed');
    if(epoch!==generation)throw new Error('store_session_changed');
    beforeAccept?.(result);accept(result,serial);return result;
  }catch(error){
    if(!disposed&&(epoch===generation||(error instanceof Error&&error.message==='owner_changed')))blockRevokedSession(error);
    throw error;
  }
}
function blockRevokedSession(error:unknown){
  const code=error instanceof Error?error.message:String(error);
  if(!['telegram_unauthorized','telegram_session_expired','profile_disabled','owner_changed','platform_owner_invalid','telegram_bot_namespace_invalid'].includes(code))return;
  generation++;state.initialized=false;serverHistory.setOwner('');
  if(bootstrapRetry){clearTimeout(bootstrapRetry);bootstrapRetry=undefined;}
  try{storage.set('bootstrap-revoked:v1',api.cacheNamespace());}catch{/* Current session remains blocked even if the marker cannot be saved. */}
  state.error=errorText(error);
}
async function openJournal(owner:string){if(disposed)return;await acquireWriter(owner);if(disposed)return;journal=new RoundJournal(storage,owner);journal.recoverUnfinished();history();serverHistory.setOwner(owner);state.initialized=true;}
function refreshBootstrap():Promise<void>{
  if(disposed)return Promise.resolve();
  if(bootstrapFlight)return bootstrapFlight;
  const epoch=generation;
  bootstrapFlight=(async()=>{
    try{
      const result=await request({action:'guest',includeGameConfig:true,nicknameAutoLocked:state.history.length>0});
      if(!state.initialized)await openJournal(result.profile!.id);
      if(disposed||epoch!==generation)return;
      storage.set('bootstrap-revoked:v1',null);cacheBootstrap();
      state.error='';if(result.inviteError)state.notice=errorText(new Error(result.inviteError));void flush();
    }catch(error){
      if(disposed||epoch!==generation)return;
      if(error instanceof ApiError&&(error.source==='transport'||error.code==='service_unavailable'))bootstrapRetry=setTimeout(()=>{bootstrapRetry=undefined;void refreshBootstrap();},5000);
      else {
        state.error=errorText(error);
      }
    }
  })().finally(()=>{bootstrapFlight=undefined;});return bootstrapFlight;
}
export function initialize():Promise<void>{
  if(initializationFlight)return initializationFlight;
  initializationFlight=initializeOnce().finally(()=>{initializationFlight=undefined;});return initializationFlight;
}
async function initializeOnce() {
  const epoch=generation,isCurrent=()=>!disposed&&epoch===generation;
  if(!isCurrent())return;
  try {
    const prefs = storage.get('preferences', null as null | Partial<typeof state.preferences>); state.preferences={sound:typeof prefs?.sound==='boolean'?prefs.sound:true,music:typeof prefs?.music==='boolean'?prefs.music:true,vibration:typeof prefs?.vibration==='boolean'?prefs.vibration:true};
    state.helmet = storage.get('helmet', false); state.jump = storage.get('jump', false);
    const locale=storage.get('locale','ru');state.locale=['ru','en'].includes(locale)?locale:'ru';
    await api.initialize();if(!isCurrent())return;bootstrapHash=await sessionHash(api.sessionMaterial());if(!isCurrent())return;
    const cached=await readBootstrap(storage,api.sessionMaterial(),api.cacheNamespace());if(!isCurrent())return;
    if(cached){await acquireWriter(cached.profile.id);if(!isCurrent())return;state.profile=cached.profile;state.config=cached.config;state.platform=cached.platform;bootstrapIdentity=cached.identity;profileReceivedAt=cached.receivedAt;serverAnchor=cached.profile.serverNow+Math.max(0,Date.now()-cached.receivedAt);monotonicAnchor=performance.now();await openJournal(cached.profile.id);if(isCurrent())void refreshBootstrap();}
    else await refreshBootstrap();
  } catch (error) { if (!disposed) state.error = errorText(error); }
}
export function setPreference(key: keyof typeof state.preferences, value: boolean) { const next = { ...state.preferences, [key]: value }; storage.set('preferences', next); state.preferences = next; }
export function setLocale(value:string) { if(!['ru','en'].includes(value))return;storage.set('locale',value);state.locale=value; }
export function selectAbility(key: 'helmet' | 'jump', value: boolean) { storage.set(key, value); state[key] = value; }
export function prepareAttempt(id: string) {
  if (failedFinish.value) throw new Error('storage_unavailable');
  if (!journal || !state.config || !state.profile) throw new Error('profile_unavailable');
  const entry = journal.prepare(id, state.config, state.helmet, state.jump, state.profile.wallet.energy, now(), state.profile.wallet.bestTimeMs,state.profile.walletVersion,3); history();
  void flush(); return entry;
}
export function finishAttempt(id: string, s: WorldState, proof: RoundProof) {
  const payload = { id, owner: state.profile!.id, finishedAt: now(), result: { timeMs: s.timeMs, runDistance: s.runDistance, riskCount: s.riskCount, proof } };
  try { journal!.update(id, { finishedAt: payload.finishedAt, result: payload.result }); }
  catch (error) { failedFinish.value = payload; throw error; }
  history();liveResultId=id; void flush();
}
export function presentResultReward(id:string){
  if(id!==liveResultId||state.screen!=='result'||state.resultId!==id||document.hidden||telegram()?.isActive===false||failedFinish.value||!journal||!state.profile)return;
  const entry=journal.all.find(a=>a.requestId===id);
  if(!entry?.result||entry.rewardVisualShown||entry.phase==='rejected')return;
  const r=entry.result,d=entry.rewardDivisors,amount=entry.phase==='confirmed'?entry.reward??0:
    d&&Number.isFinite(d.run)&&d.run>0&&Number.isFinite(d.risk)&&d.risk>0?Math.floor(r.runDistance/d.run)+Math.floor(r.riskCount/d.risk):0;
  if(!Number.isSafeInteger(amount)||amount<=0)return;
  // Persist before announcing: reopening a result or a late ACK cannot replay it.
  journal.update(id,{rewardVisualShown:true});history();
  emitResultReward({key:id,owner:entry.owner,amount,after:state.profile.wallet.energy,provisional:entry.phase!=='confirmed',kind:'round'});
}
export async function retryFailedFinish() {
  const pending = failedFinish.value; if (!pending) return;
  if (pending.owner !== state.profile?.id) throw new Error('owner_changed');
  journal!.update(pending.id, { finishedAt: pending.finishedAt, result: pending.result });
  failedFinish.value = null; history();liveResultId=pending.id; await flush();
}
let needsWork = false;
let retryAt = Infinity;
const finishNotBefore = new Map<string, number>();
const activationAge = new Map<string, number>();
const timeRefusals = new Map<string, number>();
function later(delay: number) {
  if (disposed) return;
  const deadline = performance.now() + Math.max(100, delay); if (retryTimer && retryAt <= deadline) return;
  if (retryTimer) clearTimeout(retryTimer); retryAt = deadline;
  retryTimer = setTimeout(() => { retryTimer = null; retryAt = Infinity; void flush(); }, Math.max(100, delay));
}
function deliveryNotice(error: unknown) {
  // Transport has its own verified status. A saved proof has its own pending
  // status in ResultWindow; a failed profile/start request is not a saved result.
  if (error instanceof ApiError && error.source === 'transport') return;
  state.notice = errorText(error);
}
export async function flush() {
  if (disposed||!state.initialized) return;
  needsWork = true;
  if (flushing || !journal) return flushing;
  const current = journal, owner = state.profile!.id, epoch = generation;
  flushing = (async () => {
    do {
    needsWork = false;
    for (let entry of current.pending) {
      if (disposed || epoch !== generation || owner !== state.profile?.id) return;
      try {
        if (entry.phase === 'prepared') {
          await request({ action: 'round_start', requestId: entry.requestId, proofVersion: entry.proofVersion??1, rulesRevision: entry.config.revision, revision: entry.config.config.economy.androidEnergyV2.revision, helmet: entry.helmet, jump: entry.jump },result=>{
            if(!result.profile||!Number.isSafeInteger(result.profile.walletVersion))throw new Error('profile_unavailable');
            current.update(entry.requestId,{phase:'started',roundId:result.roundId,debitWalletVersion:result.profile.walletVersion});history();
          });
        }
        entry = current.all.find(a => a.requestId === entry.requestId)!;
        if (entry.phase === 'started') { await request({ action: 'round_activate', requestId: entry.requestId }); current.update(entry.requestId, { phase: 'activated' }); activationAge.set(entry.requestId, now()); history(); }
        entry = current.all.find(a => a.requestId === entry.requestId)!;
        if (entry.abandoned && entry.phase === 'activated') { current.update(entry.requestId, { phase: 'abandoned' }); history(); continue; }
        if (entry.result && entry.phase === 'activated') {
          if (!entry.result.proof) throw new Error('journal_invalid');
          const notBefore = finishNotBefore.get(entry.requestId) ?? 0;
          if (notBefore > now()) { later(notBefore - now()); continue; }
          if (!activationAge.has(entry.requestId)) activationAge.set(entry.requestId, now());
          const remaining = entry.result.timeMs - (now() - activationAge.get(entry.requestId)!);
          if (remaining > 0) { later(remaining); continue; }
          const result = await request({ action: 'round_finish', roundId: entry.roundId, ...entry.result, hadHelmet: entry.helmet, hadJump: entry.jump });
          current.update(entry.requestId, { phase: 'confirmed', reward: result.energyReward }); history();
          void refreshBoards().catch(() => {});
          if(state.screen==='history'){serverHistory.invalidate(true);void refreshAttemptHistory();}
        }
      } catch (error) {
        if (disposed) return;
        if (error instanceof ApiError && error.code === 'result_time_invalid') {
          const refusals = (timeRefusals.get(entry.requestId) ?? 0) + 1; timeRefusals.set(entry.requestId, refusals);
          if (refusals < 8) { const wait = Math.min(3600000, error.retryAfterMs ?? 5000) + 100; finishNotBefore.set(entry.requestId, now() + wait); later(wait); continue; }
          current.update(entry.requestId, { phase: 'rejected', error: error.code }); history(); continue;
        }
        if (error instanceof ApiError && ['insufficient_energy', 'rules_changed', 'revision_mismatch', 'update_required', 'result_proof_invalid', 'round_canceled', 'result_metrics_invalid'].includes(error.code)) {
          if (['insufficient_energy','rules_changed','revision_mismatch','update_required'].includes(error.code)) {
            try { await request({ action: 'profile', includeGameConfig: true }); } catch (refreshError) { deliveryNotice(refreshError); later(5000); return; }
          }
          current.update(entry.requestId, { phase: 'rejected', error: error.code }); history();
        } else {
          const wait = error instanceof ApiError && error.retryAfterMs ? Math.min(3600000, error.retryAfterMs + 100) : 5000;
          later(wait);
          deliveryNotice(error); return;
        }
      }
    }
    } while (needsWork);
  })().catch(error => { if (!disposed) { deliveryNotice(error); later(5000); } }).finally(() => { flushing = null; if (!disposed && needsWork) { needsWork = false; queueMicrotask(() => { void flush(); }); } });
  return flushing;
}
export async function action(callback: () => Promise<unknown>) {
  if (state.busy) return;
  state.busy = true; state.error = ''; try { await callback(); } catch (error) { state.error = errorText(error); } finally { state.busy = false; }
}
export async function walletOperation(kind: string, args: Record<string, unknown> = {}, operation?: string) {
  const owner = state.profile!.id, key = `pending-op:${owner}:${kind}:${JSON.stringify(args)}`;
  const old = storage.get<string | null>(key, null), id = operation ?? old ?? operationId(); storage.set(key, id);
  const result = await request({ action: 'wallet_operation', kind, args, operationId: id });
  const grant=result.energyGrant??result.bonusClaim??result.adReward;
  if(grant?.operationId===id&&Number.isSafeInteger(grant.amount)&&grant.amount>0&&state.profile?.id===owner){
    const shown=storage.get<string[]>(`rewarded-operations:${owner}`,[]);
    if(!shown.includes(id)){
      storage.set(`rewarded-operations:${owner}`,[...shown,id].slice(-600));
      emitResultReward({key:id,owner,amount:grant.amount,after:state.profile.wallet.energy,provisional:false,kind:'wallet'});
    }
  }
  storage.set(key, null); return result;
}
let boardSerial = 0, inviteSerial = 0;
let invitePage: Promise<void> | null = null;
export async function refreshBoards() { const serial = ++boardSerial; const result = await request({ action: 'scores', period: 'allPeriods' }); if (serial === boardSerial) { state.periods = result.periods ?? {}; state.average = result.average ?? null; } }
export async function refreshInvites() { const serial = ++inviteSerial; const result = await request({ action: 'invites_state' }); if (serial === inviteSerial) state.invites = result.invites ?? null; }
export async function moreInvites() {
  if(invitePage)return invitePage;
  const current=state.invites,owner=state.profile?.id,serial=inviteSerial;
  if(!current?.nextCursor)return;
  invitePage=(async()=>{
    const result=await request({action:'invites_list',before:current.nextCursor}),page=result.invites;
    if(!page||serial!==inviteSerial||owner!==state.profile?.id||state.invites!==current)return;
    const unique=(rows:any[])=>Array.from(new Map(rows.map(row=>[row.inviteeUid??row.id??row.code, row])).values());
    state.invites={...page,paidRows:unique([...current.paidRows,...page.paidRows]),pendingRows:unique([...current.pendingRows,...page.pendingRows])};
  })().finally(()=>{invitePage=null;});
  return invitePage;
}
let navigation: string[] = [];
export function returnToPlay() {
  if (failedFinish.value) return;
  openScreen(energy.value < attemptCost.value ? 'energy' : '');
}
export function openScreen(screen: string, parent = '') {
  if (failedFinish.value && screen !== 'result') return;
  if (!parent) navigation = [];
  else if (parent === state.screen) navigation.push(parent);
  else navigation = [parent];
  state.error = ''; state.screen = screen; state.parent = navigation.at(-1) ?? '';
}
export function back() { if(closeTopOverlay())return; if (failedFinish.value) return; state.screen = navigation.pop() ?? ''; state.parent = navigation.at(-1) ?? ''; state.error = ''; }
const online = () => { if (!disposed) { void api.checkConnection(); void flush(); } };
const offline = () => { if (!disposed) void api.checkConnection(); };
const activity = () => { if (!disposed) { const active = !document.hidden && telegram()?.isActive !== false; api.setActive(active); if (active) void flush(); } };
const beforeUnload = (event: BeforeUnloadEvent) => { if (failedFinish.value) { event.preventDefault(); event.returnValue = ''; } };
window.addEventListener('online', online); window.addEventListener('offline', offline); window.addEventListener('beforeunload', beforeUnload);
document.addEventListener('visibilitychange',activity); telegram()?.onEvent('activated',activity); telegram()?.onEvent('deactivated',activity); activity();
export function disposeStore() {
  serverHistory.setOwner('');
  disposed = true; generation++; needsWork = false; if (retryTimer) clearTimeout(retryTimer);if(bootstrapRetry)clearTimeout(bootstrapRetry);
  api.dispose(); document.removeEventListener('visibilitychange',activity); telegram()?.offEvent('activated',activity); telegram()?.offEvent('deactivated',activity);
  window.removeEventListener('online', online); window.removeEventListener('offline', offline); window.removeEventListener('beforeunload', beforeUnload);
}
if (import.meta.hot) import.meta.hot.dispose(data => { data.failedFinish = failedFinish.value; disposeStore(); });
