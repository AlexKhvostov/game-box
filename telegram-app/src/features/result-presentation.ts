import {medalById,orderAchievementReceipts,type AchievementReceipt} from '../domain/achievements';
import {canonicalRoundId} from '../domain/local-awards';
import type {Attempt,Score} from '../services/contracts';

/** Receipts belong to an owner and the canonical run, not to the time the
 * result window opens. Historical/quiet awards cannot leak into this summary. */
export function runAwardSummary(receipts:readonly AchievementReceipt[],run:Attempt|undefined,owner:string|undefined){
  if(!run||!owner||run.owner!==owner||!run.result||['rejected','abandoned'].includes(run.phase))return {receipts:[],medals:0,cups:0,energy:0};
  const id=canonicalRoundId(owner,run.requestId),awards=new Map<string,AchievementReceipt>();
  for(const receipt of receipts){
    if(receipt.runId!==id||!Number.isSafeInteger(receipt.energy)||receipt.energy<0)continue;
    if(!medalById(receipt.awardId)&&!/^(record|average)-cups-(1000|500|100|10|1)$/.test(receipt.awardId))continue;
    if(!awards.has(receipt.awardId))awards.set(receipt.awardId,receipt);
  }
  const result=orderAchievementReceipts(awards.values()),cups=result.filter(r=>r.awardId.includes('-cups-')).length;
  return {receipts:result,medals:result.length-cups,cups,energy:result.reduce((sum,r)=>sum+r.energy,0)};
}
export function awardSummaryCopy(medals:number,cups:number,locale:string){
  const ru=locale==='ru',parts:string[]=[];
  if(medals){const n=medals%100,last=medals%10;parts.push(ru?`${medals} ${n>=11&&n<=14?'медалей':last===1?'медаль':last>=2&&last<=4?'медали':'медалей'}`:`${medals} medal${medals===1?'':'s'}`);}
  if(cups)parts.push(ru?(cups===1?'новый титул':'новые титулы'):(cups===1?'new title':'new titles'));
  return parts.join(' · ');
}
export function runPoints(score:Pick<Score,'timeMs'|'runDistance'|'riskCount'>){
  return Math.round(Math.max(0,score.timeMs)/1000*Math.max(0,score.runDistance)*(1+Math.max(0,score.riskCount)));
}
export function resultMetricTip(kind:string,score:Pick<Score,'hadJump'|'hadHelmet'>,locale:string){
  const ru=locale==='ru';
  if(kind==='run')return ru?'Шаги — путь героя на поле. Один шаг равен одной десятой его ширины на любом экране.':'Steps measure the hero’s path. One step equals one tenth of the hero’s width on every screen.';
  if(kind==='risk')return ru?'Риск засчитывается, когда вы едва разминулись с врагом — близко, но без касания.':'A close call counts when you narrowly escape an enemy, close but without touching.';
  const used=kind==='jump'?score.hadJump:score.hadHelmet;
  return kind==='jump'?(ru?(used?'Прыжок использовался в этой попытке.':'Прыжок в этой попытке не использовался.'):(used?'Jump was used in this run.':'Jump was not used in this run.')):(ru?(used?'Шлем использовался в этой попытке.':'Шлем в этой попытке не использовался.'):(used?'Helmet was used in this run.':'Helmet was not used in this run.'));
}
