import type {JsonStorage} from '../services/storage.ts';
import {achievements,historicalAchievements,isHistoricalMedal,isRetiredAward,achievementLevel,emptyAchievementSnapshot,medalById,medalRequirement,orderAchievementReceipts,parseAchievementSnapshot,parseBackfillMarker,cupRanks,cupTier,type AchievementSnapshot,type AchievementReceipt,type BackfillMarker} from './achievements.ts';
import {emptyStreamingAverage,parseStreamingAverage,advanceStreamingAverage,streamingAverageMs,type StreamingAverageState} from './streaming-average.ts';

export interface RankingSnapshot {id:string;asOf:number;algorithm:'ew_rms_v2'|'record_only_v1';averageDisabled?:true;rulesKey:string;record:Record<string,number>;average?:Record<string,number>}
export interface FrozenLocalRun {averageDisabled?:true;personalMedalsVersion:1|2|3;rewards:number[];rankingSnapshot:RankingSnapshot|null;rewardDivisors?:{run:number;risk:number}}
export interface LocalRunInput {requestId:string;roundId?:string;owner?:string;timeMs:number;runDistance:number;riskCount:number;hadJump:boolean;hadHelmet:boolean;frozen?:FrozenLocalRun}
interface LocalRun extends LocalRunInput {roundId:string;frozen:FrozenLocalRun;roundReward:number}
interface Grant {energy:number;runId:string;confirmed:boolean}
interface LedgerState {version:1;recordOnlyLevels?:true;namespace:string;owner:string;supported:boolean;snapshotInitialized:boolean;averageInitialized:boolean;walletVersion:number;serverNow:number;remote:AchievementSnapshot;serverAverage:StreamingAverageState;rankingSnapshot:RankingSnapshot|null;runs:LocalRun[];grants:Record<string,Grant>;receipts:AchievementReceipt[];seenRuns:string[];presented:string[];ack:string[];silentEarned:string[];levelBaseline:number|null;levelObserved:number;levelPresented:number;markers:Partial<Record<'silentBackfill'|'invitationBackfill'|'personalBackfill'|'averageBackfill',BackfillMarker>>}
const validHex=(v:unknown):v is string=>typeof v==='string'&&/^[a-f0-9]{64}$/.test(v);
const clone=<T>(v:T):T=>structuredClone(v);
const rawOwner=(owner:string)=>owner.startsWith('supabase:')?owner.slice(9):owner;
const asObject=(v:unknown):Record<string,any>|null=>!!v&&typeof v==='object'&&!Array.isArray(v)?v as Record<string,any>:null;
const add=(a:string[],id:string)=>{if(!a.includes(id))a.push(id);};

/** Small synchronous SHA-256 for canonical receipt IDs before publishing a
 * local balance. Only public owner/operation IDs are hashed here, never auth. */
export function localAwardHash(value:string):string {
  const bytes=new TextEncoder().encode(value),length=(bytes.length+9+63)&~63,data=new Uint8Array(length);data.set(bytes);data[bytes.length]=128;
  const view=new DataView(data.buffer),bits=bytes.length*8;view.setUint32(length-8,Math.floor(bits/4294967296));view.setUint32(length-4,bits>>>0);
  const k=[0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];
  const h=[0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19],w=new Uint32Array(64),rotr=(x:number,n:number)=>(x>>>n)|(x<<(32-n));
  for(let offset=0;offset<length;offset+=64){for(let i=0;i<16;i++)w[i]=view.getUint32(offset+i*4);for(let i=16;i<64;i++){const x=w[i-15]!,y=w[i-2]!;w[i]=(w[i-16]!+(rotr(x,7)^rotr(x,18)^(x>>>3))+w[i-7]!+(rotr(y,17)^rotr(y,19)^(y>>>10)))>>>0;}let[a,b,c,d,e,f,g,j]=h as [number,number,number,number,number,number,number,number];for(let i=0;i<64;i++){const t1=(j+(rotr(e,6)^rotr(e,11)^rotr(e,25))+((e&f)^(~e&g))+k[i]!+w[i]!)>>>0,t2=((rotr(a,2)^rotr(a,13)^rotr(a,22))+((a&b)^(a&c)^(b&c)))>>>0;j=g;g=f;f=e;e=(d+t1)>>>0;d=c;c=b;b=a;a=(t1+t2)>>>0;}for(const [i,v]of [a,b,c,d,e,f,g,j].entries())h[i]=(h[i]!+v)>>>0;}
  return h.map(v=>v.toString(16).padStart(8,'0')).join('');
}
export const canonicalRoundId=(owner:string,requestId:string)=>localAwardHash(`${rawOwner(owner)}:${requestId}`);
export function parseRankingSnapshot(raw:unknown):RankingSnapshot|null {
  const r=asObject(raw);if(!r||!validHex(r.id)||(r.algorithm!=='ew_rms_v2'&&(r.algorithm!=='record_only_v1'||r.averageDisabled!==true))||typeof r.rulesKey!=='string'||!Number.isFinite(r.asOf))return null;
  for(const family of r.algorithm==='record_only_v1'?['record']:['record','average'])if(!asObject(r[family])||!cupRanks.every(rank=>typeof r[family][rank]==='number'&&Number.isFinite(r[family][rank])&&r[family][rank]>=0))return null;
  return clone(r) as RankingSnapshot;
}
export function snapshotPlace(value:number,thresholds:Record<string,number>|undefined,previousPlace:number|null=null):number|null {
  if(!(value>0)||!thresholds)return null;let reached:number|null=null;
  for(const rank of cupRanks){const cutoff=thresholds[rank];if(cutoff!==undefined&&(value>cutoff||value===cutoff&&(cupTier(previousPlace)??-1)>=(cupTier(rank)??0)))reached=rank;}return reached;
}

/** Owner-bound durable projection. The host owns networking and the exclusive
 * writer lock. Every mutation commits a cloned value before becoming visible. */
export class LocalAwardsLedger {
  private value:LedgerState;
  readonly key:string;
  private storage:JsonStorage;
  readonly namespace:string;
  readonly owner:string;
  constructor(storage:JsonStorage,namespace:string,owner:string){
    this.storage=storage;this.namespace=namespace;this.owner=owner;
    this.key=`local-awards:v1:${namespace}:${owner}`;
    const cached=storage.get<LedgerState|null>(this.key,null);
    this.value=cached?this.restore(cached):{version:1,recordOnlyLevels:true,namespace,owner,supported:false,snapshotInitialized:false,averageInitialized:false,walletVersion:-1,serverNow:0,remote:emptyAchievementSnapshot(owner),serverAverage:emptyStreamingAverage(),rankingSnapshot:null,runs:[],grants:{},receipts:[],seenRuns:[],presented:[],ack:[],silentEarned:[],levelBaseline:null,levelObserved:1,levelPresented:1,markers:{}};
  }
  private restore(raw:LedgerState):LedgerState {
    if(raw.version!==1||raw.owner!==this.owner||raw.namespace!==this.namespace||!Array.isArray(raw.runs)||!Array.isArray(raw.receipts)||!Array.isArray(raw.seenRuns)||!Array.isArray(raw.presented)||!Array.isArray(raw.ack)||!Array.isArray(raw.silentEarned)||!asObject(raw.grants)||!asObject(raw.markers)||!Number.isSafeInteger(raw.walletVersion)||raw.walletVersion< -1||!Number.isFinite(raw.serverNow)||typeof raw.supported!=='boolean'||![raw.levelObserved,raw.levelPresented].every(v=>Number.isInteger(v)&&v>=1&&v<=7)||raw.levelPresented>raw.levelObserved)throw Error('achievement_storage_invalid');
    const next=clone(raw);next.snapshotInitialized=raw.snapshotInitialized===true;next.averageInitialized=raw.averageInitialized===true;next.remote=parseAchievementSnapshot(raw.remote,this.owner);next.remote.confirmed=raw.remote.confirmed===true;next.serverAverage=parseStreamingAverage(raw.serverAverage);next.rankingSnapshot=raw.rankingSnapshot===null?null:parseRankingSnapshot(raw.rankingSnapshot);
    if(raw.rankingSnapshot&&!next.rankingSnapshot)throw Error('achievement_storage_invalid');
    for(const run of next.runs){if(!validHex(run.requestId)||!validHex(run.roundId)||run.roundId!==canonicalRoundId(this.owner,run.requestId)||run.owner!==undefined&&run.owner!==this.owner)throw Error('achievement_storage_invalid');this.validateRun(run);}
    for(const [id,g]of Object.entries(next.grants))if(!isHistoricalMedal(id)||!Number.isSafeInteger(g.energy)||g.energy<0||g.energy>100000||!validHex(g.runId)||typeof g.confirmed!=='boolean')throw Error('achievement_storage_invalid');
    for(const r of next.receipts)if(!validHex(r.id)||typeof r.awardId!=='string'||!Number.isSafeInteger(r.energy)||r.energy<0)throw Error('achievement_storage_invalid');
    if(!next.seenRuns.every(validHex)||![next.presented,next.ack].every(list=>list.every(v=>typeof v==='string'))||!next.silentEarned.every(v=>typeof v==='string'))throw Error('achievement_storage_invalid');
    if(!next.recordOnlyLevels){
      // Apply the six-series level quietly while retaining the wallet and queue.
      if(next.remote.confirmed){
        const level=achievementLevel([...next.remote.earned,...Object.keys(next.grants),...next.silentEarned]);
        next.levelBaseline=next.levelObserved=next.levelPresented=level;
      }
      next.recordOnlyLevels=true;
    }
    return next;
  }
  private commit(change:(next:LedgerState)=>void){const next=clone(this.value);change(next);this.observeLevel(next);this.storage.set(this.key,next);this.value=next;}
  private observeLevel(s:LedgerState){const level=achievementLevel([...s.remote.earned,...Object.keys(s.grants),...s.silentEarned]);if(s.levelBaseline===null){if(!s.remote.confirmed)return;s.levelBaseline=level;s.levelObserved=s.levelPresented=level;}else s.levelObserved=Math.max(s.levelObserved,level);}
  get supported(){return this.value.supported;}
  get ready(){return this.supported&&this.value.remote.confirmed&&this.value.snapshotInitialized;}
  private averageFor(s:LedgerState){let state=clone(s.serverAverage);for(const run of s.runs)if(!run.frozen.averageDisabled)state=advanceStreamingAverage(state,run.timeMs,run.roundId);return state;}
  get averageState(){return this.averageFor(this.value);}
  get rankingSnapshot(){return clone(this.value.rankingSnapshot);}
  private snapshotFor(s:LedgerState):AchievementSnapshot {
    const remote=clone(s.remote),earned=new Set([...remote.earned,...Object.keys(s.grants),...s.silentEarned]),metrics={...remote.metrics};
    metrics.attempts=Math.max(metrics.attempts??0,s.serverAverage.totalAttempts)+s.runs.length;
    for(const run of s.runs){metrics.time=Math.max(metrics.time??0,run.timeMs/1000);metrics.clean=Math.max(metrics.clean??0,!run.hadJump&&!run.hadHelmet?run.timeMs/1000:0);metrics.risk=Math.max(metrics.risk??0,run.riskCount);metrics.distance=Math.max(metrics.distance??0,run.runDistance);}
    const pending=new Map([...remote.pending,...s.receipts].map(r=>[r.id,r]));
    return {...remote,earned:[...earned],earnedRewards:{...Object.fromEntries(Object.entries(s.grants).map(([id,g])=>[id,g.energy])),...remote.earnedRewards},metrics,pending:orderAchievementReceipts(pending.values()),...this.localCupPlaces(s)};
  }
  get snapshot(){return this.snapshotFor(this.value);}
  private localCupPlaces(s:LedgerState):{recordPlace:number|null;averagePlace:number|null}{let record=s.remote.recordPlace,average=s.remote.averagePlace,best=s.remote.metrics.time??0,a=clone(s.serverAverage);for(const run of s.runs){best=Math.max(best,run.timeMs/1000);if(!run.frozen.averageDisabled)a=advanceStreamingAverage(a,run.timeMs,run.roundId);const snap=run.frozen.rankingSnapshot;if(snap){record=snapshotPlace(best*1000,snap.record,record);if(!run.frozen.averageDisabled&&snap.rulesKey===a.rulesKey)average=a.count>=a.rules.minAttempts?snapshotPlace(streamingAverageMs(a),snap.average,average):null;}}return{recordPlace:record,averagePlace:average};}
  get pending(){const s=this.value;return this.snapshot.pending.filter(r=>!isRetiredAward(r.awardId)&&!s.presented.includes(r.id)&&!s.silentEarned.includes(r.awardId));}
  get pendingLevels(){const reached=Math.min(6,this.value.levelObserved,achievementLevel(this.snapshot.earned));return this.ready&&this.value.levelBaseline!==null&&reached>this.value.levelPresented?[reached]:[];}
  get pendingAcknowledgements(){return [...this.value.ack];}
  get credits():Record<string,number>{const s=this.value,result:Record<string,number>={};if(!s.supported)return result;for(const [id,g]of Object.entries(s.grants))if(!g.confirmed&&!s.remote.earned.includes(id))result[id]=g.energy;for(const r of s.runs)if(r.roundReward>0)result[`round:${r.requestId}`]=r.roundReward;return result;}
  get creditTotal(){return Object.values(this.credits).reduce((a,b)=>a+b,0);}
  get pendingRunIds(){return this.value.runs.map(r=>r.requestId);}
  get needsBackfill(){return !this.value.markers.silentBackfill||!this.value.markers.invitationBackfill||!this.value.markers.personalBackfill;}
  get backfillRequest(){return {localAwardsVersion:1,silentBackfillVersion:1,invitationMedalsVersion:2,personalMedalsVersion:3,historicalRewardBackfillVersion:1,requestSilentBackfill:!this.value.markers.silentBackfill,requestInvitationBackfill:!this.value.markers.invitationBackfill,requestPersonalMedalBackfill:!this.value.markers.personalBackfill,requestHistoricalRewardBackfill:true};}
  freezeRun(rewardDivisors?:{run:number;risk:number}):FrozenLocalRun {if(!this.ready)throw Error('achievements_unavailable');return {averageDisabled:true,personalMedalsVersion:3,rewards:[...this.value.remote.rewards],rankingSnapshot:this.rankingSnapshot,...(rewardDivisors?{rewardDivisors:{...rewardDivisors}}:{})};}
  private validateRun(run:LocalRunInput){if(!validHex(run.requestId)||!Number.isSafeInteger(run.timeMs)||run.timeMs<1||run.timeMs>3600000||!Number.isSafeInteger(run.runDistance)||run.runDistance<0||run.runDistance>10000000||!Number.isSafeInteger(run.riskCount)||run.riskCount<0||run.riskCount>10000||typeof run.hadJump!=='boolean'||typeof run.hadHelmet!=='boolean'||run.owner!==undefined&&run.owner!==this.owner)throw Error('local_award_run_invalid');if(run.frozen&&(run.frozen.averageDisabled!==undefined&&run.frozen.averageDisabled!==true||![1,2,3].includes(run.frozen.personalMedalsVersion)||run.frozen.rewards.length!==5||!run.frozen.rewards.every(v=>Number.isSafeInteger(v)&&v>=0&&v<=100000)))throw Error('local_award_run_invalid');}
  completeRun(input:LocalRunInput):AchievementReceipt[] {
    this.validateRun(input);if(!input.frozen||!this.ready)return [];
    const roundId=canonicalRoundId(this.owner,input.requestId);if(input.roundId&&input.roundId!==roundId)throw Error('local_award_run_invalid');
    if(this.value.seenRuns.includes(input.requestId)||this.value.serverAverage.lastRunId===roundId)return [];
    const d=input.frozen.rewardDivisors,roundReward=d&&Number.isFinite(d.run)&&d.run>0&&Number.isFinite(d.risk)&&d.risk>0?Math.floor(input.runDistance/d.run)+Math.floor(input.riskCount/d.risk):0;
    const run:LocalRun={...clone(input),roundId,frozen:clone(input.frozen),roundReward},added:AchievementReceipt[]=[];
    this.commit(s=>{added.push(...this.appendProjectedRun(s,run));add(s.seenRuns,input.requestId);});return orderAchievementReceipts(added);
  }
  /** One projection path serves normal append, rejected predecessors and ACK
   * rebase. A pending grant is a derivation, never an independent paid ledger. */
  private appendProjectedRun(s:LedgerState,input:LocalRun):AchievementReceipt[]{
    const before=this.snapshotFor(s),a=input.frozen.averageDisabled?null:advanceStreamingAverage(this.averageFor(s),input.timeMs,input.roundId),rewards=input.frozen.rewards,personal=input.frozen.personalMedalsVersion,roundId=input.roundId;
    const qualification:Record<string,number>={time:input.timeMs/1000,clean:!input.hadJump&&!input.hadHelmet?input.timeMs/1000:0,risk:input.riskCount,distance:input.runDistance,attempts:(before.metrics.attempts??0)+1,average:a&&input.timeMs>a.rules.minDurationMs&&a.count>=a.rules.minAttempts?streamingAverageMs(a)/1000:0};
    const added:AchievementReceipt[]=[];
      const grant=(id:string,tier:number)=>{if(before.earned.includes(id)||s.grants[id])return;const energy=rewards[tier]!;s.grants[id]={energy,runId:roundId,confirmed:false};const receipt={id:localAwardHash(`achievement:v1:${rawOwner(this.owner)}:${id}`),awardId:id,energy,runId:roundId};s.receipts.push(receipt);added.push(receipt);};
      for(const medal of a?historicalAchievements:achievements){if(medal.series==='invites'||medal.series==='ranking')continue;const requirement=Number(medalRequirement(medal,personal));if(medal.series==='attempts'&&requirement<=(before.metrics.attempts??0))continue;if((qualification[medal.series]??0)>=requirement)grant(medal.id,medal.tier);}
      const snap=input.frozen!.rankingSnapshot;
      if(snap){for(const family of ['record','average']as const){if(family==='average'&&(!a||snap.rulesKey!==a.rulesKey))continue;const old=family==='record'?before.recordPlace:before.averagePlace,value=family==='record'?Math.max(before.metrics.time??0,input.timeMs/1000)*1000:a&&a.count>=a.rules.minAttempts?streamingAverageMs(a):0,rank=snapshotPlace(value,snap[family],old);if(rank!==old)s.receipts=s.receipts.filter(r=>!r.awardId.startsWith(`${family}-cups-`));if(rank!==null&&(cupTier(rank)??-1)>(cupTier(old)??-1)){const r={id:localAwardHash(`local-cup:v1:${rawOwner(this.owner)}:${input.requestId}:${family}:${rank}`),awardId:`${family}-cups-${rank}`,energy:0,runId:roundId};s.receipts.push(r);added.push(r);}}if(snapshotPlace(input.timeMs,snap.record)===1)grant('ranking-first',4);}
      s.runs.push(clone(input));return orderAchievementReceipts(added);
  }
  private reprojectPending(s:LedgerState,discardedRunIds:readonly string[]=[],authoritativeFull=false){
    const runs=[...s.runs],pendingIds=new Set(runs.map(r=>r.roundId)),confirmed=new Set(s.remote.earned),remoteReceipts=new Set(s.remote.pending.map(r=>r.id));
    for(const [id,grant]of Object.entries(s.grants)){if(confirmed.has(id))grant.confirmed=true;else if(!grant.confirmed)delete s.grants[id];}
    s.receipts=s.receipts.filter(r=>r.awardId.includes('-cups-')
      ? !pendingIds.has(r.runId??'')&&!discardedRunIds.includes(r.runId??'')&&(!authoritativeFull||remoteReceipts.has(r.id))
      : confirmed.has(r.awardId)||s.grants[r.awardId]?.confirmed===true);
    s.runs=[];for(const run of runs)this.appendProjectedRun(s,run);
  }
  /** Call before exposing the corresponding server wallet. Ceremony ACKs are
   * deliberately absent from the money/checkpoint reconciliation below. */
  accept(response:unknown,accountedRuns:ReadonlySet<string>=new Set()):boolean {
    const data=asObject(response);if(!data)return false;const profile=asObject(data.profile);if(profile?.id!==undefined&&profile.id!==this.owner)throw Error('achievement_owner_changed');
    const version=profile?.walletVersion;if(version!==undefined&&(!Number.isSafeInteger(version)||version<0))throw Error('achievement_snapshot_invalid');
    const stamp=Number(profile?.serverNow??data.serverNow??0);if(version!==undefined&&(version<this.value.walletVersion||version===this.value.walletVersion&&stamp<this.value.serverNow))return false;
    const full=data.achievements?parseAchievementSnapshot(data.achievements,this.owner):null,local=asObject(profile?.localAwards),avg=data.averageState?parseStreamingAverage(data.averageState):null,ranking=data.rankingSnapshot?parseRankingSnapshot(data.rankingSnapshot):null;
    if(data.rankingSnapshot&&!ranking)throw Error('ranking_snapshot_invalid');
    if(!full&&!local&&!avg&&!ranking&&data.localAwardsSupported!==true)return false;
    this.commit(s=>{
      if(data.localAwardsSupported===true)s.supported=true;
      if(version!==undefined){s.walletVersion=version;s.serverNow=stamp;}
      const priorEarned=this.snapshot.earned,firstSnapshot=full!==null&&!s.snapshotInitialized;
      if(full){s.remote=full;s.snapshotInitialized=true;}
      const localEarned=local&&Array.isArray(local.earned)?local.earned:null;
      if(localEarned){const parsed=parseAchievementSnapshot({earned:localEarned,earnedRewards:local!.earnedRewards??{}},this.owner);s.remote.earned=[...new Set([...s.remote.earned,...parsed.earned])];s.remote.earnedRewards={...s.remote.earnedRewards,...parsed.earnedRewards};s.remote.confirmed=true;}
      const config=asObject(data.gameConfig?.config?.achievements?.energy);if(!full&&config){const values=['tier1','tier2','tier3','tier4','tier5'].map(k=>config[k]);if(values.every(v=>Number.isSafeInteger(v)&&v>=0&&v<=100000))s.remote.rewards=values;}
      if(typeof profile?.wallet?.bestTimeMs==='number')s.remote.metrics.time=Math.max(s.remote.metrics.time??0,profile.wallet.bestTimeMs/1000);
      if(Number.isSafeInteger(profile?.completedAttempts)&&profile!.completedAttempts>=0)
        s.remote.metrics.attempts=Math.max(s.remote.metrics.attempts??0,profile!.completedAttempts);
      for(const [field,v]of [['silentBackfill',1],['invitationBackfill',2],['personalBackfill',2],['averageBackfill',3]]as const){const marker=parseBackfillMarker(data.achievements?.[field]??local?.[field],v);if(!marker)continue;const previous=s.markers[field],ids=marker.earned.filter(id=>medalById(id)&&!s.grants[id]);let quiet=previous?.localQuietLevel??1;if(!previous&&field!=='silentBackfill'&&ids.length){const historical=new Set([...priorEarned,...s.silentEarned,...ids]);quiet=achievementLevel(historical);}for(const id of ids)add(s.silentEarned,id);for(const id of marker.presented??[]){if(!s.presented.includes(id))add(s.ack,id);add(s.presented,id);}const floor=Math.max(marker.levelBaseline??1,quiet);s.markers[field]={...marker,earned:[...new Set([...(previous?.earned??[]),...ids])],...(quiet>1?{localQuietLevel:quiet}:{})};s.levelBaseline??=floor;s.levelObserved=Math.max(s.levelObserved,floor);s.levelPresented=Math.max(s.levelPresented,floor);}
      if(firstSnapshot){
        // A refreshed browser may see an old seven-series checkpoint before
        // receiving the full collection. Quietly recognize the historical
        // six-series level and leave genuine pending medals available.
        const pending=new Set(s.remote.pending.filter(r=>!s.presented.includes(r.id)).map(r=>r.awardId));
        const historyLevel=achievementLevel(s.remote.earned.filter(id=>!pending.has(id)));
        s.levelBaseline=Math.max(s.levelBaseline??1,historyLevel);
        s.levelObserved=Math.max(s.levelObserved,historyLevel);
        s.levelPresented=Math.max(s.levelPresented,historyLevel);
      }
      for(const id of s.remote.earned)if(s.grants[id])s.grants[id]!.confirmed=true;
      const processedRequest=local?.processedRequestId??data.processedRequestId,processedRun=local?.processedRunId??data.processedRunId??avg?.lastRunId;
      const index=s.runs.findIndex(r=>r.requestId===processedRequest||r.roundId===processedRun);
      if(index>=0){
        const covered=s.runs.slice(0,index+1);
        // A lost finish reply may first be observed through profile.localAwards.
        // Retain the already-proven accepted prefix as the canonical metric/cup
        // baseline until a complete achievement response arrives.
        if(!full){const prefix=clone(s);prefix.runs=covered;const projected=this.snapshotFor(prefix);s.remote.metrics={...projected.metrics};const cups=this.localCupPlaces(prefix);s.remote.recordPlace=cups.recordPlace;s.remote.averagePlace=cups.averagePlace;if(!avg&&covered.some(run=>!run.frozen.averageDisabled)){s.serverAverage=this.averageFor(prefix);s.averageInitialized=true;}}
        s.runs.splice(0,index+1);
      }
      if(typeof processedRequest==='string'&&validHex(processedRequest))add(s.seenRuns,processedRequest);
      if(accountedRuns.size)s.runs=s.runs.filter(run=>!accountedRuns.has(run.requestId));
      if(avg&&(avg.count>=s.serverAverage.count||avg.rulesKey!==s.serverAverage.rulesKey)){s.serverAverage=avg;s.averageInitialized=true;s.remote.metrics.attempts=Math.max(s.remote.metrics.attempts??0,avg.totalAttempts);}
      if(ranking)s.rankingSnapshot=ranking;
      this.reprojectPending(s,[],full!==null);
    });return true;
  }
  markPresented(id:string){if(!this.snapshot.pending.some(r=>r.id===id))return;this.commit(s=>{add(s.presented,id);add(s.ack,id);});}
  confirmAcknowledgements(ids:readonly string[]){this.commit(s=>{s.ack=s.ack.filter(id=>!ids.includes(id));});}
  markLevelPresented(level:number,owner=this.owner){if(owner!==this.owner||!Number.isInteger(level)||level<2||level>6||level>this.value.levelObserved||level<=this.value.levelPresented)return;this.commit(s=>{s.levelPresented=level;});}
  suppressCupCeremonies(){const ids=this.pending.filter(r=>r.awardId.includes('-cups-')).map(r=>r.id);if(ids.length)this.commit(s=>{for(const id of ids){add(s.presented,id);add(s.ack,id);}});}
  rejectRun(requestId:string){this.commit(s=>{const run=s.runs.find(r=>r.requestId===requestId);if(!run)return;s.runs=s.runs.filter(r=>r.requestId!==requestId);this.reprojectPending(s,[run.roundId]);});}
}
