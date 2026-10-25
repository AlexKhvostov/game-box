import type {Attempt, AttemptHistorySnapshot, AverageBoard, GameConfig, Profile, Score} from '../services/contracts.ts';
export type AttemptRow = {attempt: Attempt; number: number; averageMs: number | null; included: boolean; inCurrentWindow: boolean};
export type PersonalBest = {timeMs: number; createdAt: number | null; localId: string | null; source: 'server' | 'confirmed-local'};
/** The dedicated best record contains metrics even outside the loaded page. */
export function bestAttemptScore(snapshot: AttemptHistorySnapshot | null, profile: Profile | null): Score | null {
  const best = snapshot?.history.best;
  if (!profile || snapshot?.history.userId !== profile.id || snapshot.average.mine.userId !== profile.id || !best) return null;
  return {id: best.id, userId: profile.id, playerName: profile.nickname, timeMs: best.timeMs, createdAt: best.createdAt,
    runDistance: best.runDistance, riskCount: best.riskCount, hadJump: best.hadJump, hadHelmet: best.hadHelmet};
}
/** Account-bound local history is only a delivery journal, never a server curve. */
export function ownAttempts(attempts: Attempt[], owner?: string | null): Attempt[] {
  if (!owner) return [];
  const ids = new Set<string>();
  return attempts.filter(a => {
    if (a.owner !== owner || !a.result || !Number.isFinite(a.result.timeMs) || a.result.timeMs < 0 ||
        !Number.isFinite(a.createdAt) || !a.requestId || ids.has(a.requestId)) return false;
    ids.add(a.requestId); return true;
  }).sort((a, b) => a.createdAt - b.createdAt || a.requestId.localeCompare(b.requestId));
}
export function myAttemptsModel(input: {attempts: Attempt[]; profile: Profile | null; board: AverageBoard | null; allTime: Score[]; server?: AttemptHistorySnapshot | null; config?:GameConfig|null}) {
  const owner=input.profile?.id, local=ownAttempts(input.attempts,owner);
  const server=input.server?.history.userId===owner&&input.server?.average.mine.userId===owner?input.server:null;
  const board=server?.average??(input.board?.mine.userId===owner?input.board:null);
  const official=board?.mine.averageMs;
  const averageMs=typeof official==='number'&&Number.isFinite(official)&&official>=0?official:null;
  const serverIds=new Set(server?.history.rows.map(row=>row.id));
  const activeIds=new Set(server?.history.rows.filter(row=>row.included).slice(0,board!.mine.usedCount).map(row=>row.id));
  // Local confirmed rows absent from a loaded page are not proof of missing server
  // history. Keep only unsent/rejected delivery statuses in a separate list.
  const pending=local.filter(a=>a.phase!=='confirmed'&&!serverIds.has(a.roundId??'')&&!serverIds.has(a.requestId));
  const rows:AttemptRow[]=server?server.history.rows.slice().reverse().map(row=>({
    attempt:{requestId:row.id,roundId:row.id,owner:owner!,createdAt:row.createdAt,config:input.config!,cost:0,helmet:row.hadHelmet,jump:row.hadJump,phase:'confirmed',result:{timeMs:row.timeMs,runDistance:row.runDistance,riskCount:row.riskCount}},
    number:row.number,averageMs:row.averageMs,included:row.included,inCurrentWindow:activeIds.has(row.id),
  })):[];
  let best:PersonalBest|null=null;
  if(server?.history.best){const b=server.history.best;best={timeMs:b.timeMs,createdAt:b.createdAt,localId:serverIds.has(b.id)?b.id:null,source:'server'};}
  const chartMode=rows.some(row=>row.averageMs!==null)?'trend':'none';
  return {rows,history:rows.slice().reverse(),pending,best,averageMs,chartMode,
    rules:board?.rules??null,usedCount:board?.mine.usedCount??0,totalCount:server?.history.totalCount??board?.mine.totalAttempts??null,
    historyComplete:!!server&&server.history.nextCursor===null,hasServer:!!server,
    activeCount:rows.filter(r=>r.inCurrentWindow).length};
}
/** Keep a selected historical ID visible without changing selection or graph state. */
export function attemptWindow(rows: AttemptRow[], selectedId: string | null, limit = 100): AttemptRow[] {
  const index = rows.findIndex(row => row.attempt.requestId === selectedId);
  const start = index < 0 ? Math.max(0, rows.length - limit) : Math.max(0, Math.min(rows.length - limit, index - Math.floor(limit / 2)));
  return rows.slice(start, start + limit);
}
