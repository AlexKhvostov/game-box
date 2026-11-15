import {achievements,medalById,cupRanks} from './achievements.ts';

/** Read-only UI snapshot. All credits and acknowledgements belong to the ledger. */
export interface AchievementPanelModel {
  earnedIds: readonly string[];
  earnedRewards: Readonly<Record<string,number>>;
  energyByTier: readonly number[];
  bestTimeMs:number;
  averageMs:number|null;
  totalAttempts:number;
  level:number;
  levelCounts:readonly number[];
  recordRank:number|null;
  averageRank:number|null;
  confirmed:boolean;
  /** Native metric units: seconds for time/average/clean, counts otherwise. */
  metrics?:Readonly<Record<string,number>>;
}
export interface AwardPresentationReceipt {
  id:string;awardId:string;energy:number;owner:string;after:number;runId?:string;
}
export type StatisticDestination='record'|'average'|'history';
export type AwardCloseReason='continue'|'dismiss'|'collection';
export function safeLevel(level:number){return Number.isFinite(level)?Math.max(1,Math.min(6,Math.trunc(level))):1;}
export function activeMedalCount(ids:readonly string[]){return new Set(ids.filter(id=>!!medalById(id))).size;}
export function medalReward(model:AchievementPanelModel,id:string,tier:number){
  const earned=Object.hasOwn(model.earnedRewards,id),value=earned?model.earnedRewards[id]:model.energyByTier[tier];
  return typeof value==='number'&&Number.isFinite(value)?Math.max(0,Math.trunc(value)):0;
}
export function medalProgress(model:AchievementPanelModel,id:string){
  const medal=medalById(id);if(!medal)return {current:0,target:0};
  if(model.earnedIds.includes(id))return {current:Number(medal.value)||1,target:Number(medal.value)||1};
  const current=model.metrics?.[medal.series]??(medal.series==='time'?model.bestTimeMs/1000:medal.series==='average'?(model.averageMs??0)/1000:medal.series==='attempts'?model.totalAttempts:0);
  return {current:Math.max(0,Number(current)||0),target:Number(medal.value)||1};
}
export function currentCupId(family:'record'|'average',rank:number|null){
  if(rank===null||!Number.isFinite(rank)||rank<1)return null;
  const threshold=[...cupRanks].reverse().find(value=>rank<=value);
  return threshold===undefined?null:`${family}-cups-${threshold}`;
}
export function awardCopy(id:string,locale:string){
  const ru=locale==='ru',medal=medalById(id);
  if(medal){const label=medal.series==='ranking'?(ru?['День','Неделя','Месяц','Год','Топ 1']:['Day','Week','Month','Year','Top 1'])[medal.tier]!: `${medal.value}${medal.seconds?(ru?' с':' s'):''}`,category=ru?medal.titleRu:medal.titleEn;return {label,category,name:`${category} · ${label}`,cup:false};}
  const family=id.startsWith('average')?'average':'record',rank=Number(id.split('-').at(-1));
  const label=`TOP ${Number.isFinite(rank)?rank:'—'}`,category=family==='average'?(ru?'Среднее время':'Average time'):(ru?'Рекорд выживания':'Survival record');return {label,category,name:`${category} · ${label}`,cup:true};
}
export const personalSeriesIds=['time','average','clean','risk','distance','attempts','invites'] as const;
export const medalsInSeries=(series:string)=>achievements.filter(m=>m.series===series);

export const MEDAL_LEAD_IN_MS=330;
export function awardPose(elapsedMs:number,cup=false,reduced=false){
  const duration=cup?4550:4020,p=Math.max(0,Math.min(1,elapsedMs/(reduced?600:duration)));
  const t=reduced?4.55:(cup?0:.33)+p*(cup?4.55:4.02),accent=cup?1.58:1.36;
  const smooth=(a:number,b:number,x:number)=>{const k=Math.max(0,Math.min(1,(x-a)/(b-a)));return k*k*(3-2*k);};
  return {p,t,after:t-accent,lift:reduced?1:smooth(0,1.38,t),done:p>=1};
}
