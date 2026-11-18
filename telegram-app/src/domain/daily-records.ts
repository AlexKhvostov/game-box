import {localAwardHash} from './local-awards.ts';
import type {Attempt} from '../services/contracts.ts';

export const recordMetrics=['cleanTimeMs','boostedTimeMs','maxSteps','maxRisk'] as const;
export type RecordMetric=typeof recordMetrics[number];
export type DayMaxima=Record<string,Record<RecordMetric,number>>;
export const totalKeys=['started','completed','helmets','jumps','reward'] as const;
export type RecordTotals=Record<typeof totalKeys[number],number>;
export type RecordAck={requestId:string;sequence:number;improved:RecordMetric[]};
export const recordTime=(a:Attempt)=>Math.trunc(a.finishedAt??a.createdAt);
export const recordDay=(a:Attempt)=>new Date(recordTime(a)).toISOString().slice(0,10);
export const recordRequestId=(owner:string,streamId:string,sequence:number)=>
  localAwardHash(`${owner.replace(/^supabase:/,'')}:${streamId}:${sequence}`);

export function completedRecord(a:Attempt){
  return !!a.result&&!a.abandoned&&!a.recordRejected&&!['rejected','abandoned'].includes(a.phase);
}

function values(a:Attempt):Record<RecordMetric,number>{
  const r=a.result!,boosted=a.helmet||a.jump;
  return {cleanTimeMs:boosted?0:r.timeMs,boostedTimeMs:boosted?r.timeMs:0,maxSteps:r.runDistance,maxRisk:r.riskCount};
}

export function recordFloors(rows:readonly Attempt[],remote:DayMaxima){
  const floors={...remote};
  for(const a of rows){
    if(a.phase!=='confirmed'||!completedRecord(a)||(a.recordSequence!==undefined&&!a.recordPublished))continue;
    const day=recordDay(a),v=values(a),prior=floors[day];
    floors[day]={
      cleanTimeMs:Math.max(prior?.cleanTimeMs??0,v.cleanTimeMs),
      boostedTimeMs:Math.max(prior?.boostedTimeMs??0,v.boostedTimeMs),
      maxSteps:Math.max(prior?.maxSteps??0,v.maxSteps),
      maxRisk:Math.max(prior?.maxRisk??0,v.maxRisk),
    };
  }
  return floors;
}

export function roundReward(a:Attempt){
  const d=a.rewardDivisors,r=a.result;
  return r&&d?Math.floor(r.runDistance/d.run)+Math.floor(r.riskCount/d.risk):0;
}

/** Strict records, including when another day or category shares a result. */
export function recordWinners(rows:readonly Attempt[],floors:DayMaxima={}){
  const best:DayMaxima={};
  const winners=new Map<string,{id:string;metric:RecordMetric}>();
  for(const a of rows){
    if(!completedRecord(a))continue;
    const day=recordDay(a),current=best[day]??={...floors[day]},v=values(a);
    for(const metric of recordMetrics){
      if(v[metric]<=(current[metric]??0))continue;
      current[metric]=v[metric];
      winners.set(day+'/'+metric,{id:a.requestId,metric});
    }
  }
  const result=new Map<string,RecordMetric[]>();
  for(const {id,metric} of winners.values()){
    const found=result.get(id);
    if(found)found.push(metric);else result.set(id,[metric]);
  }
  return result;
}

export function recordPrefix(pending:readonly Attempt[]){
  const rows:Attempt[]=[],days=new Set<string>();
  for(const a of pending){
    if(!a.recordSequence||(!a.result&&!a.abandoned)||a.config.revision!==pending[0]?.config.revision)break;
    const day=recordDay(a);
    if(days.size===8&&!days.has(day))break;
    rows.push(a);days.add(day);
    if(rows.length===512)break;
  }
  return rows;
}

export function recordDays(rows:readonly Attempt[]){return [...new Set(rows.map(recordDay))];}

export function recordCommand(streamId:string,rows:readonly Attempt[],totals:RecordTotals,floors:DayMaxima){
  const candidates=recordWinners(rows,floors),selected:Attempt[]=[],next={...totals};
  const records:{sequence:number;requestId:string;playedAt:number;helmet:boolean;jump:boolean;rankingSnapshotId?:string;result:NonNullable<Attempt['result']>&{hadHelmet:boolean;hadJump:boolean}}[]=[];
  let events=0,bytes=0;
  for(const a of rows){
    const sequence=a.recordSequence;
    if(!sequence||selected.length&&sequence!==selected.at(-1)!.recordSequence!+1)throw Error('journal_invalid');
    if(candidates.has(a.requestId)){
      const proof=a.result?.proof;
      if(!proof)throw Error('journal_invalid');
      const size=JSON.stringify(proof).length;
      if(records.length&&(records.length>=4||events+proof.events.length>600000||bytes+size>10*1024*1024))break;
      events+=proof.events.length;bytes+=size;
      records.push({sequence,requestId:a.requestId,playedAt:recordTime(a),helmet:a.helmet,jump:a.jump,
        rankingSnapshotId:a.localAwards?.rankingSnapshot?.id,result:{...a.result!,hadHelmet:a.helmet,hadJump:a.jump}});
    }
    selected.push(a);next.started++;next.helmets+=Number(a.helmet);next.jumps+=Number(a.jump);
    if(completedRecord(a)){next.completed++;next.reward+=roundReward(a);}
  }
  if(!selected.length)throw Error('journal_invalid');
  return {action:'daily_records_commit',streamId,from:selected[0]!.recordSequence!,
    through:selected.at(-1)!.recordSequence!,rulesRevision:selected[0]!.config.revision,
    days:recordDays(selected),totals:next,records};
}

export function parseRecordRead(data:Record<string,unknown>,days:readonly string[]){
  const {through,totals,maxima,recordAcks}=data as {through:number;totals:RecordTotals;maxima:DayMaxima;recordAcks:RecordAck[]};
  const natural=(v:number)=>Number.isSafeInteger(v)&&v>=0;
  if(!natural(through)||!totals||!totalKeys.every(k=>natural(totals[k]))||totals.started!==through||
    !maxima||!days.every(day=>maxima[day]&&recordMetrics.every(k=>natural(maxima[day]![k])))||!Array.isArray(recordAcks))
    throw Error('daily_ack_invalid');
  return {through,totals,maxima,recordAcks};
}
