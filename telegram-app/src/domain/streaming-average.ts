/** Android385's normalized exponential RMS. No history window is retained. */
export interface StreamingAverageState {algorithm:'ew_rms_v2';meanSquare:number;count:number;normalizationCount:number;totalAttempts:number;rulesKey:string;rules:{q:number;minDurationMs:number;minAttempts:number};lastRunId:string|null}
export function emptyStreamingAverage():StreamingAverageState{return {algorithm:'ew_rms_v2',meanSquare:0,count:0,normalizationCount:0,totalAttempts:0,rulesKey:'ew_rms_v2:92:0:1',rules:{q:.92,minDurationMs:0,minAttempts:1},lastRunId:null};}
export function parseStreamingAverage(raw:unknown):StreamingAverageState {
  const r=raw as Partial<StreamingAverageState>|null;
  if(!r||r.algorithm!==undefined&&r.algorithm!=='ew_rms_v2'||typeof r.meanSquare!=='number'||!Number.isFinite(r.meanSquare)||r.meanSquare<0||r.meanSquare>3600000**2||![r.count,r.normalizationCount,r.totalAttempts??r.count].every(n=>Number.isSafeInteger(n)&&Number(n)>=0)||!r.rules||!Number.isFinite(r.rules.q)||r.rules.q<.5||r.rules.q>1||!Number.isSafeInteger(r.rules.minDurationMs)||r.rules.minDurationMs<0||r.rules.minDurationMs>60000||!Number.isSafeInteger(r.rules.minAttempts)||r.rules.minAttempts<1||r.rules.minAttempts>10000||r.normalizationCount!>r.count!||(r.totalAttempts??r.count)!<r.count!)throw Error('average_state_invalid');
  return {algorithm:'ew_rms_v2',meanSquare:r.meanSquare,count:r.count!,normalizationCount:r.normalizationCount!,totalAttempts:r.totalAttempts??r.count!,rulesKey:typeof r.rulesKey==='string'?r.rulesKey:`ew_rms_v2:${r.rules.q*100}:${r.rules.minDurationMs}:${r.rules.minAttempts}`,rules:{...r.rules},lastRunId:typeof r.lastRunId==='string'?r.lastRunId:null};
}
export function advanceStreamingAverage(state:StreamingAverageState,timeMs:number,runId:string):StreamingAverageState {
  if(!Number.isSafeInteger(timeMs)||timeMs<1||timeMs>3600000)throw Error('result_invalid');
  const next={...state,rules:{...state.rules},lastRunId:runId,totalAttempts:state.totalAttempts+1};
  if(timeMs<=state.rules.minDurationMs)return next;
  const {q}=state.rules,n=state.normalizationCount,k=q===1?1/(n+1):(1-q)/(1-q**(n+1));
  next.meanSquare=(1-k)*state.meanSquare+k*timeMs*timeMs;next.count++;next.normalizationCount++;return next;
}
export const streamingAverageMs=(state:StreamingAverageState)=>Math.sqrt(Math.max(0,state.meanSquare));
