import type {Attempt,Profile} from '../services/contracts.ts';
import {completedRecord,recordDay,recordTime,recordWinners,type RecordMetric} from './daily-records.ts';

export type AttemptRow={attempt:Attempt;number:number;records:RecordMetric[]};
export type AttemptsDay={day:string;rows:AttemptRow[]};

export function knownRecordTime(attempts:readonly Attempt[],profile:Profile|null,projection=0){
  if(!profile)return 0;
  let best=Math.max(profile.wallet.bestTimeMs||0,projection);
  for(const a of attempts){
    if(a.owner===profile.id&&completedRecord(a)&&Number.isSafeInteger(a.result!.timeMs))best=Math.max(best,a.result!.timeMs);
  }
  return best;
}

export function ownAttempts(attempts:readonly Attempt[],owner?:string|null){
  if(!owner)return [];
  const ids=new Set<string>();
  return attempts.filter(a=>{
    if(a.owner!==owner||!a.result||!Number.isFinite(a.result.timeMs)||a.result.timeMs<0||
      !Number.isFinite(recordTime(a))||!a.requestId||ids.has(a.requestId))return false;
    ids.add(a.requestId);return true;
  }).sort((a,b)=>recordTime(a)-recordTime(b)||a.createdAt-b.createdAt||a.requestId.localeCompare(b.requestId));
}

export function myAttemptsModel(attempts:readonly Attempt[],profile:Profile|null,through=0,knownTotal=0){
  const history=ownAttempts(attempts,profile?.id),winners=recordWinners(history);
  const days:AttemptsDay[]=[];
  let localBest:Attempt|null=null,pendingCount=0,localCount=0;
  for(const [index,attempt] of history.entries()){
    if(completedRecord(attempt)){
      localCount++;
      if((attempt.result?.timeMs??0)>(localBest?.result?.timeMs??0))localBest=attempt;
      if(attempt.recordSequence!==undefined&&attempt.recordSequence>through&&!['confirmed','rejected','abandoned'].includes(attempt.phase))pendingCount++;
    }
    const day=recordDay(attempt);
    if(days.at(-1)?.day!==day)days.push({day,rows:[]});
    days.at(-1)!.rows.unshift({attempt,number:index+1,records:winners.get(attempt.requestId)??[]});
  }
  const confirmed=profile?.completedAttempts;
  const totalCount=Math.max(confirmed===undefined?0:confirmed+pendingCount,knownTotal,localCount);
  const remoteBest=profile?.wallet.bestTimeMs??0;
  const bestTime=Math.max(remoteBest,localBest?.result?.timeMs??0);
  if(localBest?.result?.timeMs!==bestTime)localBest=null;
  return {days:days.reverse(),localBest,bestTime,totalCount,historyCount:history.length,confirmed,pendingCount};
}
