import type { Attempt, GameConfig } from './contracts.ts';
import type { JsonStorage } from './storage.ts';
import {completedRecord,recordRequestId,roundReward,type RecordAck} from '../domain/daily-records.ts';
type RecordStream={id:string;next:number};
const terminal=(a:Attempt)=>['confirmed','rejected','abandoned'].includes(a.phase);
export class RoundJournal {
  private items: Attempt[];
  private stream:RecordStream|undefined;
  private storage: JsonStorage;
  readonly owner: string;
  constructor(storage: JsonStorage, owner: string, newStreamId?:string) {
    this.storage = storage; this.owner = owner;
    const data = storage.get<{ version: number; owner: string; attempts: Attempt[]; recordStream?:RecordStream } | null>(`rounds:${owner}`, null);
    if (data && (data.version !== 1 || data.owner !== owner || !Array.isArray(data.attempts) || data.attempts.some(a =>
      a.owner !== owner || a.averageDisabled!==undefined&&a.averageDisabled!==true||a.timeRefusals!==undefined&&(!Number.isInteger(a.timeRefusals)||a.timeRefusals<0||a.timeRefusals>8)||a.finishNotBefore!==undefined&&(!Number.isFinite(a.finishNotBefore)||a.finishNotBefore<0)||!/^[a-f0-9]{64}$/.test(a.requestId) || !Number.isSafeInteger(a.cost) || a.cost < 1 ||
      !['prepared','started','activated','finished','confirmed','rejected','abandoned'].includes(a.phase) ||
      a.personalMedalsVersion!==undefined&&![1,2,3].includes(a.personalMedalsVersion)||a.localAwards!==undefined&&(![1,2,3].includes(a.localAwards.personalMedalsVersion)||!Array.isArray(a.localAwards.rewards)||a.localAwards.rewards.length!==5||!a.localAwards.rewards.every(n=>Number.isSafeInteger(n)&&n>=0&&n<=100000))||a.proofVersion!==undefined&&a.proofVersion!==1&&a.proofVersion!==2&&a.proofVersion!==3&&a.proofVersion!==4&&a.proofVersion!==5&&a.proofVersion!==6 || typeof a.helmet !== 'boolean' || typeof a.jump !== 'boolean' || a.debitWalletVersion!==undefined&&(!Number.isSafeInteger(a.debitWalletVersion)||a.debitWalletVersion<0) || a.rewardVisualShown!==undefined&&typeof a.rewardVisualShown!=='boolean' || !/^[a-f0-9]{64}$/.test(a.config?.revision)))) throw new Error('journal_invalid');
    this.items = data?.attempts ?? [];
    const latestDaily=this.items.filter(a=>a.recordSequence!==undefined).at(-1);
    this.stream=data?.recordStream??(latestDaily?.recordStreamId&&latestDaily.recordSequence
      ? {id:latestDaily.recordStreamId,next:latestDaily.recordSequence+1}
      : newStreamId?{id:newStreamId,next:1}:undefined);
    if(this.stream&&(!/^[a-f0-9]{64}$/.test(this.stream.id)||!Number.isSafeInteger(this.stream.next)||this.stream.next<1))
      throw Error('journal_invalid');
    let last=0;
    for(const a of this.items){
      if(a.recordSequence===undefined)continue;
      if(!this.stream||a.recordStreamId!==this.stream.id||!Number.isSafeInteger(a.recordSequence)||a.recordSequence<=last||a.recordSequence>=this.stream.next||
        !Number.isFinite(a.finishedAt??a.createdAt))throw Error('journal_invalid');
      last=a.recordSequence;
    }
  }
  private save(items: Attempt[],stream=this.stream) {
    // Delivered proofs belong on the server. Keep bounded lightweight local
    // history (including results from clients before this update).
    const retained = new Set(items.filter(terminal).slice(-600).map(a => a.requestId));
    const compact = items.filter(a => !terminal(a) || retained.has(a.requestId)).map(a => {
      if (!terminal(a)) return a;
      const result = a.result ? { timeMs: a.result.timeMs, runDistance: a.result.runDistance, riskCount: a.result.riskCount } : undefined;
      return { ...a, config: { ok: true as const, revision: a.config.revision, config: {} }, result };
    });
    this.storage.set(`rounds:${this.owner}`, { version: 1, owner: this.owner, attempts: compact, recordStream:stream });
    this.items = compact;this.stream=stream;
  }
  get all() { return structuredClone(this.items); }
  get pending() { return structuredClone(this.items.filter(a=>!terminal(a))); }
  get recordStreamId(){return this.stream?.id??'';}
  get nextRecordRequestId(){return this.stream?recordRequestId(this.owner,this.stream.id,this.stream.next):'';}
  get recordPending(){return structuredClone(this.items.filter(a=>a.recordSequence!==undefined&&!terminal(a)));}
  accountedRecordIds(through:number){
    return new Set(this.items.filter(a=>a.recordSequence!==undefined&&a.recordSequence<=through&&!terminal(a)).map(a=>a.requestId));
  }
  retireRecords(through:number,acks:readonly RecordAck[]){
    if(!this.items.some(a=>a.recordSequence!==undefined&&a.recordSequence<=through&&!terminal(a)))return;
    const published=new Set(acks.filter(a=>Array.isArray(a.improved)&&a.improved.length).map(a=>a.requestId));
    this.save(this.items.map(a=>{
      if(a.recordSequence===undefined||a.recordSequence>through||terminal(a))return a;
      if(a.recordRejected)return {...a,phase:'rejected',error:a.recordRejected};
      if(!completedRecord(a))return {...a,phase:'abandoned'};
      return {...a,phase:'confirmed',reward:roundReward(a),recordPublished:published.has(a.requestId)};
    }));
  }
  recoverUnfinished() {
    const incomplete=(a:Attempt)=>!a.result&&!a.abandoned&&!terminal(a);
    if(this.items.some(incomplete))this.save(this.items.map(a=>incomplete(a)?{...a,abandoned:true}:a));
  }
  reserved(walletVersion=Number.MAX_SAFE_INTEGER,recordThrough=0) {
    return this.items.filter(a=>a.recordSequence!==undefined
      ? !terminal(a)&&a.recordSequence>recordThrough
      : a.phase==='prepared'||a.debitWalletVersion!==undefined&&a.debitWalletVersion>walletVersion).reduce((n,a)=>n+a.cost,0);
  }
  prepare(requestId: string, config: GameConfig, helmet: boolean, jump: boolean, balance: number, now: number, previousBestTimeMs?: number, walletVersion=Number.MAX_SAFE_INTEGER, proofVersion:1|2|3|4|5|6=1,localAwards?:Attempt['localAwards'],daily=false,recordThrough=0) {
    if (this.items.some(a => a.requestId === requestId)) throw new Error('operation_conflict');
    const e = config.config.economy.androidEnergyV2;
    const cost = e.baseAttemptCost + (helmet ? e.helmetExtraCost : 0) + (jump ? e.jumpExtraCost : 0);
    if (!Number.isSafeInteger(cost) || cost < 1 || balance - this.reserved(walletVersion,recordThrough) < cost) throw new Error('insufficient_energy');
    const frozenConfig:GameConfig=daily?{ok:true,revision:config.revision,config:{}}:JSON.parse(JSON.stringify(config));
    const entry: Attempt = { averageDisabled:true,proofVersion,personalMedalsVersion:localAwards?.personalMedalsVersion??1,...(localAwards?{localAwards:structuredClone(localAwards)}:{}), requestId, owner: this.owner, createdAt: now, config:frozenConfig, helmet, jump, cost, phase: 'prepared', activatedAt: now, ...(previousBestTimeMs === undefined ? {} : { previousBestTimeMs }) };
    entry.rewardDivisors = { risk: Math.max(1,config.config.economy.riskRewardEvery), run: Math.max(1,config.config.economy.runRewardEvery) };
    if(daily){
      const stream=this.stream;
      if(!stream||requestId!==this.nextRecordRequestId)throw Error('journal_invalid');
      entry.recordSequence=stream.next;
      entry.recordStreamId=stream.id;
      // The legacy sender ignores this phase. The presence of a result or
      // the abandoned flag determines when the daily sender can account for it.
      entry.phase='finished';
      this.save([...this.items,entry],{...stream,next:stream.next+1});
      return entry;
    }
    this.save([...this.items, entry]); return entry;
  }
  update(id: string, patch: Partial<Attempt>) {
    if (patch.owner && patch.owner !== this.owner) throw new Error('owner_changed');
    const found = this.items.find(a => a.requestId === id); if (!found) throw new Error('round_not_found');
    this.save(this.items.map(a => a.requestId === id ? { ...a, ...structuredClone(patch), owner: this.owner, requestId: id } : a));
  }
}
