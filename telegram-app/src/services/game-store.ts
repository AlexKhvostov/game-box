import { computed, reactive, shallowRef, ref, toRaw, watch } from 'vue';
import {parseLevelRanking,parsePublicPlayerMedals,type LevelRankEntry} from '../domain/level-ranking';
import {DailyBestRead,emptyDailyBest,utcDay} from '../domain/daily-best-read';
import {LocalAwardsLedger} from '../domain/local-awards';
import {achievementLevel,levelCounts,emptyAchievementSnapshot} from '../domain/achievements';
import {completedRecord,roundReward,parseRecordRead,recordCommand,recordDay,recordDays,recordFloors,recordPrefix,recordWinners,type DayMaxima,type RecordAck} from '../domain/daily-records';
import {knownRecordTime} from '../domain/my-attempts';
import type {AchievementPanelModel} from '../domain/achievement-presentation';
import {InviteRewardJournal,parseInviteRewards} from '../domain/invite-rewards';
import { TelegramApi, ApiError } from './api';
import { DurableStorage, operationId } from './storage';
import { RoundJournal } from './journal';
import type { ApiResult, Profile, GameConfig, PlatformConfig, InviteState, Attempt, Score } from './contracts';
import type { WorldState, RoundProof } from '../domain/kernel';
import { transportErrorText, type ConnectionStatus } from './connection';
import { telegram } from '../platform/telegram';
import {closeTopOverlay} from './ui-overlays';
import {readBootstrap,sessionHash,type Bootstrap,type OfflineIdentity} from './bootstrap-cache';
import {emitResultReward} from './reward-events';
const storage = new DurableStorage();
const awardRevision=ref(0),awardLedgers=new Map<string,LocalAwardsLedger>();
let pendingAwardResponse:ApiResult|null=null,awardSync:Promise<void>|null=null;
function awardLedger(owner=state.profile?.id){if(!owner)return null;const key=`${api.cacheNamespace()}:${owner}`;let ledger=awardLedgers.get(key);if(!ledger){ledger=new LocalAwardsLedger(storage,api.cacheNamespace(),owner);awardLedgers.set(key,ledger);}return ledger;}
function awardsChanged(){awardRevision.value++;}
export const achievementSnapshot=computed(()=>{awardRevision.value;return awardLedger()?.snapshot??emptyAchievementSnapshot(state.profile?.id??'');});
export const pendingAwards=computed(()=>{awardRevision.value;return awardLedger()?.pending??[];});
export const pendingLevels=computed(()=>{awardRevision.value;return awardLedger()?.pendingLevels??[];});
export const localAwardCredits=computed(()=>{awardRevision.value;return awardLedger()?.creditTotal??0;});
export const achievementPanel=computed<AchievementPanelModel>(()=>{
 const a=achievementSnapshot.value,profile=state.profile;
 const bestTimeMs=knownRecordTime(state.history,profile,Math.round((a.metrics.time??0)*1000));
 const metrics={...a.metrics,...(profile?{time:bestTimeMs/1000}:{}),
  ...(profile?.completedAttempts!==undefined?{attempts:Math.max(a.metrics.attempts??0,profile.completedAttempts)}:{})};
 return {earnedIds:a.earned,earnedRewards:a.earnedRewards,energyByTier:a.rewards,bestTimeMs,totalAttempts:metrics.attempts??0,
  level:achievementLevel(a.earned),levelCounts:levelCounts(a.earned),recordRank:a.recordPlace,confirmed:a.confirmed,metrics};
});
export function markAwardPresented(id:string,owner:string){if(owner!==state.profile?.id)return;awardLedger()?.markPresented(id);awardsChanged();}
export function markLevelPresented(level:number,owner:string){if(owner!==state.profile?.id)return;awardLedger()?.markLevelPresented(level,owner);awardsChanged();}
export async function refreshAchievements():Promise<void>{
 if(awardSync)return awardSync;if(disposed||!state.initialized||!state.localAwardsSupported||roundInProgress()||document.hidden||telegram()?.isActive===false)return;
 const owner=state.profile!.id,epoch=generation,current=journal,ledger=awardLedger(owner)!;
 awardSync=(async()=>{
  while(ledger.pendingAcknowledgements.length){const ids=ledger.pendingAcknowledgements.slice(0,50);await request({action:'achievements_ack',ack:ids});if(epoch!==generation||owner!==state.profile?.id)return;ledger.confirmAcknowledgements(ids);awardsChanged();}
  const drained=!!current&&current.pending.length===0;
  await request({action:'achievements_state',...(drained?ledger.backfillRequest:{personalMedalsVersion:3})});
 })().finally(()=>{awardSync=null;});return awardSync;
}
function projectFinishedRun(entry:Attempt){if(!entry.result||!entry.localAwards)return;const ledger=awardLedger(entry.owner);ledger?.completeRun({requestId:entry.requestId,roundId:entry.roundId,owner:entry.owner,...entry.result,hadJump:entry.jump,hadHelmet:entry.helmet,frozen:entry.localAwards});if(!state.presentation.cupAutoCelebrationsEnabled)ledger?.suppressCupCeremonies();awardsChanged();}

export const state = reactive({ profile: null as Profile | null, config: null as GameConfig | null, platform: null as PlatformConfig | null,
  initialized: false, online: true, connection: 'unknown' as ConnectionStatus, busy: false, externalBusy: false, error: '', notice: '',windowClosing:false, screen: '' as string, parent: '',
  inviteNoticeOpen:false,
  helmet: false, jump: false, history: [] as Attempt[], periods: {} as Record<string, Score[]>,
  dailyBest:emptyDailyBest(),dailyBestReady:false,
  recordSending:false,recordError:'',recordMaxima:{} as DayMaxima,recordStreamId:'',
  resultPreviewKind:'best' as 'best'|'history'|'ranking',resultPreviewPhase:null as Attempt['phase']|null,bestResult: null as Score | null, invites: null as InviteState | null, period: 'all', rankingTab:'record' as 'record'|'levels', levelRows:null as LevelRankEntry[]|null, locale: 'ru',
  presentation:{enemyReactionsEnabled:true,characterSettingsEnabled:true,cupAutoCelebrationsEnabled:false,startupLoadingMinMs:2000}, localAwardsSupported:false,
  preferences: { sound: true, music: true, vibration: true,controlSensitivity:1,showPlayerFace:true,enemyReactionsEnabled:true }, serverOffset: 0, resultId: '', selectedScore: null as Score | null, selectedPlayer:null as {userId:string;playerName:string}|null, rulesAccepted: false });
export const api = new TelegramApi(status => { state.connection = status; state.online = status !== 'offline'; });
export const world = shallowRef<WorldState | null>(null);
export const impactActive=ref(false);
const roundInProgress=()=>!!world.value?.playing||impactActive.value;
const inviteRevision=ref(0),inviteJournals=new Map<string,InviteRewardJournal>(),invitePresentedMemory=new Set<string>();
function inviteJournal(owner=state.profile?.id){
  if(!owner)return null;
  const key=`${api.cacheNamespace()}:${owner}`;
  if(!inviteJournals.has(key))inviteJournals.set(key,new InviteRewardJournal(storage,api.cacheNamespace(),owner));
  return inviteJournals.get(key)!;
}
export const pendingInviteRewards=computed(()=>{
  inviteRevision.value;
  const journal=inviteJournal();
  return parseInviteRewards(state.profile?.wallet.inviteRewardNotices).filter(n=>!journal?.seen(n.id));
});
export const heldInviteEnergy=computed(()=>pendingInviteRewards.value.filter(n=>!inviteWasPresented(n.id)).reduce((sum,n)=>sum+n.amount,0));
export function inviteWasPresented(id:string){inviteRevision.value;return invitePresentedMemory.has(`${api.cacheNamespace()}:${state.profile?.id}:${id}`)||(inviteJournal()?.presented(id)??false);}
export function markInvitePresented(id:string,owner:string){if(owner!==state.profile?.id)return;try{inviteJournal(owner)?.markPresented(id);}finally{invitePresentedMemory.add(`${api.cacheNamespace()}:${owner}:${id}`);inviteRevision.value++;}}
export function acknowledgeInviteReward(id:string){inviteJournal()?.acknowledge(id);inviteRevision.value++;void syncInviteRewards({refreshProfile:false}).catch(()=>{});}
let inviteSync:Promise<void>|null=null,lastRulesPrefetch=0;
export function syncInviteRewards(options:{refreshProfile?:boolean}={}):Promise<void>{
  if(disposed||!state.initialized||document.hidden||roundInProgress()||telegram()?.isActive===false)return Promise.resolve();
  if(inviteSync)return inviteSync;
  const owner=state.profile!.id,epoch=generation,journal=inviteJournal(owner)!;
  inviteSync=(async()=>{
    for(const id of journal.pending){
      try{await request({action:'invite_reward_ack',eventId:id});}
      catch(error){if(!(error instanceof ApiError)||error.code!=='invite_reward_not_found')throw error;}
      if(disposed||epoch!==generation||owner!==state.profile?.id)return;
      journal.confirm(id);inviteRevision.value++;
    }
    // Match AndroidConfigSession: one idle rules/profile prefetch per 30s.
    // ACK responses already carry the updated wallet; startup has a fresh guest.
    if(options.refreshProfile!==false&&Date.now()-lastRulesPrefetch>=30000){
      lastRulesPrefetch=Date.now();
      await request({action:'profile',includeGameConfig:true});
    }
  })().finally(()=>{inviteSync=null;});
  return inviteSync;
}
export const failedFinish = shallowRef<{ id: string; owner: string; result: NonNullable<Attempt['result']>; finishedAt: number } | null>(import.meta.hot?.data.failedFinish ?? null);
let journal: RoundJournal | null = null, flushing: Promise<void> | null = null, retryTimer: ReturnType<typeof setTimeout> | null = null;
let generation = 0;
let disposed = false;
let pendingConfig: GameConfig | null = null, serverAnchor = 0, monotonicAnchor = 0;
let requestSerial = 0, configSerial = 0, platformSerial = 0,presentationPinned=false;
let liveResultId='';
let bootstrapHash='',bootstrapIdentity:OfflineIdentity|null=null,profileReceivedAt=0;
let initializationFlight:Promise<void>|undefined;
let bootstrapRetry:ReturnType<typeof setTimeout>|undefined,bootstrapFlight:Promise<void>|undefined;
function dailyBestAllowed(){return !disposed&&state.initialized&&state.dailyBestReady&&!!state.profile&&state.online&&!document.hidden&&telegram()?.isActive!==false&&!roundInProgress()&&!state.screen&&!state.windowClosing&&!state.busy&&!state.externalBusy&&!state.inviteNoticeOpen;}
const dailyHead=new DailyBestRead(async()=>{const epoch=generation;try{return await api.execute({action:'daily_best'});}catch(error){if(!disposed&&epoch===generation)blockRevokedSession(error);throw error;}},value=>{state.dailyBest=value;},dailyBestAllowed);
const stopDailyOwner=watch(()=>state.profile?.id??'',owner=>dailyHead.setOwner(owner),{flush:'sync'});
export function refreshDailyBest(force=false){dailyHead.setOwner(state.profile?.id??'');return dailyHead.refresh(force);}
// Called by the existing HUD second tick only on UTC-day changes, never as TTL polling.
export function observeDailyBestDay(){if(!disposed&&dailyHead.observeDay())void refreshDailyBest();}
const stopDailyIdle=watch([dailyBestAllowed,()=>state.profile?.id],([allowed])=>{if(allowed)void refreshDailyBest();},{flush:'post'});
function cacheBootstrap(){
  if(!state.profile||!state.config||!bootstrapHash)return;
  const cached:Bootstrap={version:1,namespace:api.cacheNamespace(),profile:state.profile,config:pendingConfig??state.config,platform:state.platform,identity:bootstrapIdentity,sessionHash:bootstrapHash,receivedAt:profileReceivedAt};
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
export const recordThrough=computed(()=>state.profile?.recordStreams?.[state.recordStreamId]??0);
const localRunCredits=computed(()=>{
  awardRevision.value;
  const owner=state.profile?.id,through=recordThrough.value,projected=new Set(awardLedger()?.pendingRunIds??[]);
  return state.history.reduce((total,a)=>total+(
    a.owner===owner&&a.recordSequence!==undefined&&a.recordSequence>through&&a.phase!=='confirmed'&&
    completedRecord(a)&&!projected.has(a.requestId)?roundReward(a):0),0);
});
const usableBalance=computed(()=>(state.profile?.wallet.energy??0)+localAwardCredits.value+localRunCredits.value);
export const energy = computed(() => {
  state.history; // Recalculate only after a durable journal change or a wallet ACK.
  const version=state.profile?.walletVersion??0;
  return Math.max(0,usableBalance.value-(journal?.reserved(version,recordThrough.value)??0));
});
const confirmedRecordFloors=computed(()=>recordFloors(state.history,state.recordMaxima));
export const pendingRecordIds=computed(()=>recordWinners(state.history.filter(a=>a.recordSequence!==undefined&&
  !['confirmed','rejected','abandoned'].includes(a.phase)),confirmedRecordFloors.value));
export const attemptCost = computed(() => { const e = state.profile?.wallet.energyConfig; return e ? e.baseAttemptCost + (state.helmet ? e.helmetExtraCost : 0) + (state.jump ? e.jumpExtraCost : 0) : 0; });
export function now() { return serverAnchor ? serverAnchor + performance.now() - monotonicAnchor : Date.now(); }
export function applyPendingConfig() { if (pendingConfig && !world.value?.playing) { const next=pendingConfig;pendingConfig=null;state.config=next; } }
function history() { state.history = journal?.all ?? []; }
function accept(result: ApiResult, serial: number) {
  if(result.telegramPresentation&&!presentationPinned&&!world.value?.playing){presentationPinned=true;const p=result.telegramPresentation;state.presentation={enemyReactionsEnabled:p.enemyReactionsEnabled===true,characterSettingsEnabled:p.characterSettingsEnabled===true,cupAutoCelebrationsEnabled:p.cupAutoCelebrationsEnabled===true,startupLoadingMinMs:Number.isFinite(p.startupLoadingMinMs)?Math.max(0,Math.min(10000,p.startupLoadingMinMs)):2000};}
  const owner=result.profile?.id??state.profile?.id;
  if(owner&&journal?.owner===owner){
    const ledger=awardLedger(owner)!,through=result.profile?.recordStreams?.[journal.recordStreamId]??0;
    const accounted=journal.accountedRecordIds(through);
    ledger.accept(result,accounted);
    if(!state.presentation.cupAutoCelebrationsEnabled)ledger.suppressCupCeremonies();
    awardsChanged();
  }else if(owner)pendingAwardResponse=result;
  if(result.localAwardsSupported===true)state.localAwardsSupported=true;

  if(result.offlineIdentity?.environment==='production'&&/^\d{5,15}$/.test(result.offlineIdentity.botId??'')&&/^\d+$/.test(result.offlineIdentity.subject??''))bootstrapIdentity=result.offlineIdentity;
  if (result.profile) {
    if (state.profile && state.profile.id !== result.profile.id) { generation++; journal = null; throw new Error('owner_changed'); }
    const stale=state.profile && (result.profile.walletVersion < state.profile.walletVersion ||
      (result.profile.walletVersion === state.profile.walletVersion && result.profile.serverNow < state.profile.serverNow));
    // Wallet versions and rules are independent: a stale wallet must not hide
    // a fresh rules snapshot returned by a later request.
    if (!stale) {
      if(state.profile&&JSON.stringify([state.profile.nickname,state.profile.hiddenPlayers,state.profile.hideTelegramAccount])!==JSON.stringify([result.profile.nickname,result.profile.hiddenPlayers,result.profile.hideTelegramAccount]))invalidateRankingReads();
      storage.set(`profile:${result.profile.id}`, result.profile); state.profile = result.profile;profileReceivedAt=Date.now();
      state.serverOffset = result.profile.serverNow - Date.now();
      serverAnchor = Math.max(serverAnchor?now():0,result.profile.serverNow); monotonicAnchor = performance.now();
    }
  }
  if (serial >= configSerial && result.gameConfig) {
    configSerial = serial;
    if(JSON.stringify((pendingConfig??state.config)?.config.ranking)!==JSON.stringify(result.gameConfig.config.ranking))invalidateRankingReads();
    if (result.gameConfig) { storage.set(`config:${result.profile?.id ?? state.profile!.id}`, result.gameConfig); if (world.value?.playing) pendingConfig = result.gameConfig; else { pendingConfig = null; state.config = result.gameConfig; } }
  }
  if(serial>=platformSerial&&result.platformConfig){platformSerial=serial;state.platform=result.platformConfig;}
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
    const known=(pendingConfig??state.config)?.revision;
    const averageDisabled=body.action!=='round_start'||body.averageDisabled===true;
    const result=await api.execute({localAwardsVersion:1,silentBackfillVersion:1,invitationMedalsVersion:2,...body,...(averageDisabled?{averageDisabled:true}:{}),...(body.includeGameConfig===true&&known?{knownConfigRevision:known}:{})});
    if(disposed)throw new Error('store_disposed');
    if(epoch!==generation)throw new Error('store_session_changed');
    beforeAccept?.(result);accept(result,serial);return result;
  }catch(error){

    if(!disposed&&(epoch===generation||(error instanceof Error&&error.message==='owner_changed')))blockRevokedSession(error);
    throw error;
  }
}
// Cached bootstrap and an ignored, out-of-order profile cannot authorize a prompt.
export async function refreshBonusEntryProfile():Promise<boolean>{
  const owner=state.profile?.id;
  if(!owner||!state.initialized||state.busy||state.externalBusy)return false;
  const result=await request({action:'profile'});
  return !!result.profile&&state.initialized&&state.profile?.id===owner&&toRaw(state.profile)===result.profile;
}
function blockRevokedSession(error:unknown){
  const code=error instanceof Error?error.message:String(error);
  if(!['telegram_unauthorized','telegram_session_expired','profile_disabled','owner_changed','platform_owner_invalid','telegram_bot_namespace_invalid'].includes(code))return;
  generation++;state.initialized=false;state.dailyBestReady=false;dailyHead.setOwner('');state.localAwardsSupported=false;pendingAwardResponse=null;state.recordMaxima={};state.recordSending=false;state.recordError='';state.periods={};state.levelRows=null;state.rankingTab='record';boardFresh.clear();
  if(bootstrapRetry){clearTimeout(bootstrapRetry);bootstrapRetry=undefined;}
  try{storage.set('bootstrap-revoked:v1',api.cacheNamespace());}catch{/* Current session remains blocked even if the marker cannot be saved. */}
  state.error=errorText(error);
}
async function openJournal(owner:string){
  if(disposed)return;
  await acquireWriter(owner);
  if(disposed)return;
  journal=new RoundJournal(storage,owner,operationId());
  journal.recoverUnfinished();
  state.recordStreamId=journal.recordStreamId;
  const ledger=awardLedger(owner)!;
  state.localAwardsSupported=ledger.supported||state.localAwardsSupported;
  const accounted=journal.accountedRecordIds(recordThrough.value);
  if(pendingAwardResponse){ledger.accept(pendingAwardResponse,accounted);pendingAwardResponse=null;}
  for(const entry of journal.pending){
    if(entry.result&&entry.localAwards&&!entry.recordRejected&&!accounted.has(entry.requestId))projectFinishedRun(entry);
  }
  if(!state.presentation.cupAutoCelebrationsEnabled)ledger.suppressCupCeremonies();
  awardsChanged();history();state.initialized=true;
}
function refreshBootstrap():Promise<void>{
  if(disposed)return Promise.resolve();
  if(bootstrapFlight)return bootstrapFlight;
  if(bootstrapRetry){clearTimeout(bootstrapRetry);bootstrapRetry=undefined;}
  const epoch=generation;
  bootstrapFlight=(async()=>{
    try{
      const result=await request({action:'guest',includeGameConfig:true,nicknameAutoLocked:state.history.length>0});
      lastRulesPrefetch=Date.now();
      if(!state.initialized)await openJournal(result.profile!.id);
      if(disposed||epoch!==generation)return;
      state.dailyBestReady=true;void refreshDailyBest();void syncInviteRewards({refreshProfile:false}).catch(()=>{});void refreshAchievements().catch(()=>{});
      storage.set('bootstrap-revoked:v1',null);cacheBootstrap();
      state.error='';if(result.inviteError)state.notice=errorText(new Error(result.inviteError));void flush(true);
    }catch(error){
      if(disposed||epoch!==generation)return;
      if(error instanceof ApiError&&(error.source==='transport'||error.code==='service_unavailable')){
        if(!state.initialized)state.error=errorText(error);
        bootstrapRetry=setTimeout(()=>{bootstrapRetry=undefined;void refreshBootstrap();},5000);
      }else if(!state.initialized)state.error=errorText(error);
      else state.notice=errorText(error);
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
    const prefs = storage.get('preferences', null as null | Partial<typeof state.preferences>); state.preferences={sound:typeof prefs?.sound==='boolean'?prefs.sound:true,music:typeof prefs?.music==='boolean'?prefs.music:true,vibration:typeof prefs?.vibration==='boolean'?prefs.vibration:true,controlSensitivity:typeof prefs?.controlSensitivity==='number'&&Number.isFinite(prefs.controlSensitivity)?Math.max(.5,Math.min(3,prefs.controlSensitivity)):1,showPlayerFace:typeof prefs?.showPlayerFace==='boolean'?prefs.showPlayerFace:true,enemyReactionsEnabled:typeof prefs?.enemyReactionsEnabled==='boolean'?prefs.enemyReactionsEnabled:true};
    state.helmet = storage.get('helmet', false); state.jump = storage.get('jump', false);
    const locale=storage.get('locale','ru');state.locale=['ru','en'].includes(locale)?locale:'ru';
    await api.initialize();if(!isCurrent())return;bootstrapHash=await sessionHash(api.sessionMaterial());if(!isCurrent())return;
    const cached=await readBootstrap(storage,api.sessionMaterial(),api.cacheNamespace());if(!isCurrent())return;
    if(cached){
      await acquireWriter(cached.profile.id);
      if(!isCurrent())return;
      state.profile=cached.profile;state.config=cached.config;state.platform=cached.platform;
      const p=cached.platform?.presentation;
      if(p){
        state.presentation={enemyReactionsEnabled:p.enemyReactionsEnabled===true,characterSettingsEnabled:p.characterSettingsEnabled===true,
          cupAutoCelebrationsEnabled:p.cupAutoCelebrationsEnabled===true,startupLoadingMinMs:Number.isFinite(p.startupLoadingMinMs)?Math.max(0,Math.min(10000,p.startupLoadingMinMs)):2000};
        presentationPinned=true;
      }
      bootstrapIdentity=cached.identity;profileReceivedAt=cached.receivedAt;
      serverAnchor=cached.profile.serverNow+Math.max(0,Date.now()-cached.receivedAt);monotonicAnchor=performance.now();
      await openJournal(cached.profile.id);
      if(isCurrent()){state.dailyBestReady=true;void refreshBootstrap();}
    }
    else await refreshBootstrap();
  } catch (error) { if (!disposed) state.error = errorText(error); }
}
export function setPreference(key: keyof typeof state.preferences, value: boolean|number) { if(key==='controlSensitivity'){if(typeof value!=='number'||!Number.isFinite(value))return;value=Math.max(.5,Math.min(3,value));}else if(typeof value!=='boolean')return;const next = { ...state.preferences, [key]: value }; storage.set('preferences', next); state.preferences = next as typeof state.preferences; }
export function setLocale(value:string) { if(!['ru','en'].includes(value))return;storage.set('locale',value);state.locale=value; }
export function selectAbility(key: 'helmet' | 'jump', value: boolean) { storage.set(key, value); state[key] = value; }
export function nextAttemptId(){return journal?.nextRecordRequestId??'';}
export function prepareAttempt(id: string) {
  if (failedFinish.value) throw new Error('storage_unavailable');
  if (!journal || !state.config || !state.profile) throw new Error('profile_unavailable');
  const config=state.config,ledger=awardLedger();
  const frozen=ledger?.ready?ledger.freezeRun({run:Math.max(1,config.config.economy.runRewardEvery),risk:Math.max(1,config.config.economy.riskRewardEvery)}):undefined;
  const entry=journal.prepare(id,config,state.helmet,state.jump,usableBalance.value,
    Math.trunc(now()),achievementPanel.value.bestTimeMs,state.profile.walletVersion,6,frozen,true,recordThrough.value);
  history();return entry;
}
export function finishAttempt(id: string, s: WorldState, proof: RoundProof, finishedAt=Math.trunc(now())) {
  const payload = { id, owner: state.profile!.id, finishedAt, result: { timeMs: s.timeMs, runDistance: s.runDistance, riskCount: s.riskCount, proof } };
  saveFinishedAttempt(payload);
}
function saveFinishedAttempt(payload:NonNullable<typeof failedFinish.value>){
  if(!journal||payload.owner!==state.profile?.id||payload.owner!==journal.owner)throw Error('owner_changed');
  const {id,finishedAt,result}=payload;
  try{journal.update(id,{finishedAt,result});}
  catch(error){failedFinish.value=payload;throw error;}
  failedFinish.value=null;history();liveResultId=id;
  // The proof is already durable. An error in the optional local award view
  // must not turn a saved result into a request to save a second time.
  try{
    const entry=state.history.find(a=>a.requestId===id);
    if(entry?.localAwards)projectFinishedRun(toRaw(entry));
  }catch(error){state.notice=errorText(error);}
  // Give the result route and its local state a render turn ahead of delivery.
  setTimeout(()=>{void flush();},0);
}
export function presentResultReward(id:string){
  if(state.bestResult)return;
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
  saveFinishedAttempt(pending);
}
let needsWork = false;
let forceRecordSync=false,lastCounterSync=Date.now();
let retryAt = Infinity;
const activationAge = new Map<string, number>();
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
function retireDaily(current:RoundJournal,through:number,acks:RecordAck[]){
  const livePending=current.accountedRecordIds(through).has(liveResultId);
  current.retireRecords(through,acks);history();
  const live=livePending?current.all.find(a=>a.requestId===liveResultId):undefined;
  if(live?.phase==='confirmed'&&live.rewardVisualShown&&live.reward){
    emitResultReward({key:`confirmed:${live.requestId}`,owner:live.owner,amount:live.reward,after:state.profile!.wallet.energy,
      provisional:false,kind:'wallet',counterOnly:true});
  }
}
async function sendDaily(current:RoundJournal,owner:string,epoch:number){
  const active=()=>!disposed&&epoch===generation&&current===journal&&owner===state.profile?.id;
  let rows=recordPrefix(current.recordPending);
  if(!rows.length){forceRecordSync=false;return;}
  if(!state.online||roundInProgress()||document.hidden||telegram()?.isActive===false)return;
  const wait=60000-(Date.now()-lastCounterSync);
  if(!forceRecordSync&&!pendingRecordIds.value.size&&wait>0){later(wait);return;}
  state.recordSending=true;state.recordError='';
  const streamId=current.recordStreamId,days=recordDays(rows);
  try{
    const read=await request({action:'daily_records_state',expectedOwner:owner,streamId,days});
    if(!active())return;
    const checkpoint=parseRecordRead(read,days);
    state.recordMaxima={...state.recordMaxima,...checkpoint.maxima};
    if(checkpoint.through)retireDaily(current,checkpoint.through,checkpoint.recordAcks);
    if(roundInProgress())return;
    rows=recordPrefix(current.recordPending);
    if(!rows.length){lastCounterSync=Date.now();forceRecordSync=false;return;}
    if(rows[0]!.recordSequence!==checkpoint.through+1)throw Error('daily_sequence_gap');
    if(rows.some(a=>!Object.hasOwn(checkpoint.maxima,recordDay(a)))){needsWork=true;return;}
    const command=recordCommand(streamId,rows,checkpoint.totals,checkpoint.maxima);
    if(!command.records.length&&!forceRecordSync&&wait>0){later(wait);return;}
    const reply=await request({...command,expectedOwner:owner});
    if(!active())return;
    if(Array.isArray(reply.rejectedRecords)){
      if(!reply.rejectedRecords.length)throw Error('daily_ack_invalid');
      for(const rejected of reply.rejectedRecords){
        const row=command.records.find(a=>a.sequence===rejected?.sequence&&a.requestId===rejected.requestId);
        if(!row||typeof rejected.error!=='string')throw Error('daily_ack_invalid');
        current.update(row.requestId,{recordRejected:rejected.error,abandoned:true});
        awardLedger(owner)?.rejectRun(row.requestId);
      }
      awardsChanged();history();forceRecordSync=true;needsWork=true;return;
    }
    if(reply.through!==command.through||!Array.isArray(reply.recordAcks))throw Error('daily_ack_invalid');
    retireDaily(current,reply.through,reply.recordAcks);
    lastCounterSync=Date.now();
    if(reply.recordAcks.some((ack:RecordAck)=>Array.isArray(ack.improved)&&ack.improved.length)){
      invalidateRankingReads();
      if(state.screen==='ranking')void refreshBoards().catch(()=>{});
    }
    needsWork=needsWork||recordPrefix(current.recordPending).length>0;
  }catch(error){
    if(!active())return;
    if(!(error instanceof ApiError&&error.code==='result_time_pending'))state.recordError=errorText(error);
    const wait=error instanceof ApiError&&error.retryAfterMs?Math.min(3600000,error.retryAfterMs+100):5000;
    later(wait);
  }finally{
    if(active())state.recordSending=false;
  }
}
export async function flush(forceRecords=false) {
  if (disposed||!state.initialized) return;
  forceRecordSync=forceRecordSync||forceRecords;
  if(roundInProgress())return;
  needsWork = true;
  if (flushing || !journal) return flushing;
  const current = journal, owner = state.profile!.id, epoch = generation;
  flushing = (async () => {
    do {
    needsWork = false;
    // Only unfinished work from versions before daily record delivery uses the
    // original three calls. A new run never creates a legacy server round.
    for (let entry of current.pending.filter(a=>a.recordSequence===undefined)) {
      if (disposed || epoch !== generation || owner !== state.profile?.id||roundInProgress()) return;
      try {
        if (entry.phase === 'prepared') {
          await request({ action: 'round_start', requestId: entry.requestId, averageDisabled: entry.averageDisabled, proofVersion: entry.proofVersion??1, personalMedalsVersion:entry.personalMedalsVersion??entry.localAwards?.personalMedalsVersion??1,rankingSnapshotId:entry.localAwards?.rankingSnapshot?.id, rulesRevision: entry.config.revision, revision: entry.config.config.economy.androidEnergyV2.revision, helmet: entry.helmet, jump: entry.jump },result=>{
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
          const notBefore = entry.finishNotBefore ?? 0;
          if (notBefore > now()) { later(notBefore - now()); return; }
          if (!activationAge.has(entry.requestId)) activationAge.set(entry.requestId, now());
          const remaining = entry.result.timeMs - (now() - activationAge.get(entry.requestId)!);
          if (remaining > 0) { later(remaining); return; }
          const result = await request({ action: 'round_finish', roundId: entry.roundId, ...entry.result, hadHelmet: entry.helmet, hadJump: entry.jump });
          if(liveResultId===entry.requestId&&current.all.find(a=>a.requestId===entry.requestId)?.rewardVisualShown&&Number.isSafeInteger(result.energyReward)&&result.energyReward!>0) {
            emitResultReward({key:`confirmed:${entry.requestId}`,owner,amount:result.energyReward!,after:state.profile!.wallet.energy,provisional:false,kind:'wallet',counterOnly:true});
          }
          current.update(entry.requestId, { phase: 'confirmed', reward: result.energyReward }); history();
          invalidateRankingReads();
          if(state.screen==='ranking') void refreshBoards().catch(() => {});
        }
      } catch (error) {
        if (disposed) return;
        if (error instanceof ApiError && error.code === 'result_time_invalid') {
          const refusals = (entry.timeRefusals ?? 0) + 1;
          if (refusals < 8) { const wait = Math.min(3600000, error.retryAfterMs ?? 5000) + 100; current.update(entry.requestId,{timeRefusals:refusals,finishNotBefore:now()+wait});history();later(wait);return; }
          awardLedger(owner)?.rejectRun(entry.requestId);awardsChanged();current.update(entry.requestId, { phase: 'rejected', error: error.code,timeRefusals:refusals }); history(); continue;
        }
        if (error instanceof ApiError && ['insufficient_energy', 'rules_changed', 'revision_mismatch', 'update_required', 'result_proof_invalid', 'round_canceled', 'result_metrics_invalid'].includes(error.code)) {
          awardLedger(owner)?.rejectRun(entry.requestId);awardsChanged();
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
    if(!disposed&&epoch===generation&&current===journal)await sendDaily(current,owner,epoch);
    } while (needsWork);
    if(!roundInProgress()&&!current.pending.length)void refreshAchievements().catch(()=>{});
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

  const result=await request({ action: 'wallet_operation', kind, args, operationId: id });
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
let inviteSerial = 0;
let boardRevision=0;
const boardFlights = new Map<string,Promise<void>>(), boardFresh = new Map<string,number>();
function invalidateRankingReads(){boardFresh.clear();boardRevision++;}
let invitePage: Promise<void> | null = null;
export function refreshBoards(force = false):Promise<void> {
  const period=state.period,board=state.rankingTab==='levels'?'levels':period;
  const owner=state.profile?.id, epoch=generation,revision=boardRevision,headRevision=dailyHead.revision,headStartedAt=Date.now(),headDay=utcDay(headStartedAt);
  if(!owner)return Promise.resolve();
  const key=`${epoch}:${owner}:${board}`,pending=boardFlights.get(key);
  if(pending)return pending;
  const stamp=Date.now(),last=boardFresh.get(key);
  if(!force&&last&&stamp-last<20000&&new Date(last).toISOString().slice(0,10)===new Date(stamp).toISOString().slice(0,10))return Promise.resolve();
  const operation=(async()=>{
    const result=await request(board==='levels'?{action:'level_rankings'}:{action:'scores',period});
    if(epoch!==generation||owner!==state.profile?.id)return;
    if(board==='levels')state.levelRows=parseLevelRanking(result,owner);
    else {
      state.periods[period]=result.scores??result.periods?.[period]??[];
      if(period==='day')dailyHead.reuseRanking(state.periods.day?.[0]?.timeMs??null,headDay,headRevision,headStartedAt);
    }
    if(revision===boardRevision)boardFresh.set(key,stamp);
  })().finally(()=>{
    if(boardFlights.get(key)===operation)boardFlights.delete(key);
    const visible=state.rankingTab==='levels'?'levels':state.period;
    if(!disposed&&epoch===generation&&owner===state.profile?.id&&revision!==boardRevision&&state.screen==='ranking'&&visible===board)
      void refreshBoards().catch(()=>{});
  });
  boardFlights.set(key,operation);return operation;
}
export async function loadPublicPlayerMedals(userId:string) {
  const owner=state.profile?.id;
  if(!owner)throw new Error('profile_unavailable');
  return parsePublicPlayerMedals(await request({action:'player_medals',userId,expectedOwner:owner}),userId);
}
export async function refreshInvites() { const serial = ++inviteSerial; const result = await request({ action: 'invites_state',inviteContract:3 }); if (serial === inviteSerial) state.invites = result.invites ?? null; }
export async function moreInvites() {
  if(invitePage)return invitePage;
  const current=state.invites,owner=state.profile?.id,serial=inviteSerial;
  if(!current?.nextCursor)return;
  invitePage=(async()=>{
    const result=await request({action:'invites_list',inviteContract:3,before:current.nextCursor}),page=result.invites;
    if(!page||serial!==inviteSerial||owner!==state.profile?.id||state.invites!==current)return;
    const unique=(rows:any[])=>Array.from(new Map(rows.map(row=>[row.inviteeUid??row.id??row.code, row])).values());
    state.invites={...page,paidRows:unique([...current.paidRows,...page.paidRows]),pendingRows:unique([...current.pendingRows,...page.pendingRows])};
  })().finally(()=>{invitePage=null;});
  return invitePage;
}
let navigation: string[] = [];
let replayGate:(()=>Promise<unknown>)|undefined,replayPending=false;
export function installReplayGate(gate:()=>Promise<unknown>){replayGate=gate;return()=>{if(replayGate===gate)replayGate=undefined;};}
export async function returnToPlay(){
 if(failedFinish.value||replayPending||state.externalBusy)return;
 const owner=state.profile?.id,epoch=generation;replayPending=true;
 try{if(replayGate&&state.screen==='result'&&!state.bestResult)await replayGate();}
 catch{/* Optional advertising never blocks another run. */}
 finally{replayPending=false;if(epoch===generation&&owner===state.profile?.id&&state.screen==='result')openScreen(energy.value<attemptCost.value?'energy':'');}
}
export function openScreen(screen: string, parent = '') {
  if(state.windowClosing)return;
  if (failedFinish.value && screen !== 'result') return;
  if (screen !== 'result' && screen !== 'share') state.bestResult = null;
  if (!parent) navigation = [];
  else if (parent === state.screen) navigation.push(parent);
  else navigation = [parent];
  changeWindow(()=>{if(screen==='ranking')state.rankingTab='record';state.error='';state.screen=screen;state.parent=navigation.at(-1)??'';});
}
export function openBestAttemptResult(score: Score,parent='history',kind:'best'|'history'|'ranking'='best',phase?:Attempt['phase']) {
  if (failedFinish.value || !state.profile || score.userId !== state.profile.id) return;
  state.bestResult = {...score};state.resultPreviewKind=kind;state.resultPreviewPhase=phase??'confirmed';
  openScreen('result',parent);
}
let closeTimer:ReturnType<typeof setTimeout>|undefined;
function changeWindow(apply:()=>void){
 const animated=!!state.screen&&typeof document.querySelector==='function'&&typeof window.matchMedia==='function'&&!window.matchMedia('(prefers-reduced-motion: reduce)').matches;
 if(!animated){apply();return;}state.windowClosing=true;const owner=state.profile?.id,epoch=generation;
 closeTimer=setTimeout(()=>{closeTimer=undefined;state.windowClosing=false;if(epoch===generation&&owner===state.profile?.id)apply();},100);
}
export function closeScreen(options:{immediate?:boolean}={}){if(failedFinish.value||state.windowClosing)return;const apply=()=>{state.screen=navigation.pop()??'';if(state.screen!=='result'&&state.screen!=='share')state.bestResult=null;state.parent=navigation.at(-1)??'';state.error='';};if(options.immediate)apply();else changeWindow(apply);}
export function back(){if(closeTopOverlay())return;closeScreen();}

const online = () => { if (!disposed) { void api.checkConnection().then(()=>flush(true)); void refreshDailyBest(); void syncInviteRewards().then(()=>refreshAchievements()).catch(()=>{}); } };
const offline = () => { if (!disposed) void api.checkConnection(); };
const activity = () => { if (!disposed) { const active = !document.hidden && telegram()?.isActive !== false; api.setActive(active); if (active) {void refreshDailyBest();void flush(true);void syncInviteRewards().then(()=>refreshAchievements()).catch(()=>{});} } };
const beforeUnload = (event: BeforeUnloadEvent) => { if (failedFinish.value) { event.preventDefault(); event.returnValue = ''; } };
window.addEventListener('online', online); window.addEventListener('offline', offline); window.addEventListener('beforeunload', beforeUnload);
document.addEventListener('visibilitychange',activity); telegram()?.onEvent('activated',activity); telegram()?.onEvent('deactivated',activity); activity();
// Android's idle prefetch stops while another route covers the game.
const invitePoll=setInterval(()=>{if(state.initialized&&!state.screen&&!state.windowClosing&&!state.busy&&!state.externalBusy)void syncInviteRewards().catch(()=>{});},30000);
export function disposeStore() {
  disposed = true;state.dailyBestReady=false;stopDailyIdle();stopDailyOwner();dailyHead.dispose(); generation++;if(closeTimer)clearTimeout(closeTimer);needsWork = false; clearInterval(invitePoll);if (retryTimer) clearTimeout(retryTimer);if(bootstrapRetry)clearTimeout(bootstrapRetry);
  api.dispose(); document.removeEventListener('visibilitychange',activity); telegram()?.offEvent('activated',activity); telegram()?.offEvent('deactivated',activity);
  window.removeEventListener('online', online); window.removeEventListener('offline', offline); window.removeEventListener('beforeunload', beforeUnload);
}
if (import.meta.hot) import.meta.hot.dispose(data => { data.failedFinish = failedFinish.value; disposeStore(); });
