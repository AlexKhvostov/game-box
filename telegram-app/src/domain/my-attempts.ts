import type {Attempt, AverageBoard, Profile, Score} from '../services/contracts.ts';
import {averageChart} from './average.ts';

export type AttemptRow = {attempt: Attempt; number: number; averageMs: number | null; included: boolean; inCurrentWindow: boolean};
export type PersonalBest = {timeMs: number; createdAt: number | null; localId: string | null; source: 'server' | 'confirmed-local'};

/** Account-bound local history is not the complete server history. Never merge owners. */
export function ownAttempts(attempts: Attempt[], owner?: string | null): Attempt[] {
  if (!owner) return [];
  const ids = new Set<string>();
  return attempts.filter(a => {
    if (a.owner !== owner || !a.result || !Number.isFinite(a.result.timeMs) || a.result.timeMs < 0 ||
        !Number.isFinite(a.createdAt) || !a.requestId || ids.has(a.requestId)) return false;
    ids.add(a.requestId); return true;
  }).sort((a, b) => a.createdAt - b.createdAt || a.requestId.localeCompare(b.requestId));
}

export function myAttemptsModel(input: {attempts: Attempt[]; profile: Profile | null; board: AverageBoard | null; allTime: Score[]}) {
  const {profile, board} = input;
  const chronological = ownAttempts(input.attempts, profile?.id);
  // Compute from every retained row first. Only the UI then chooses 50 bars.
  const chart = board ? averageChart(chronological, board, {limit: null}) : null;
  const points = new Map(chart?.points.map(p => [p.attempt.requestId, p]));
  const rows: AttemptRow[] = chronological.map((attempt, index) => {
    const point = points.get(attempt.requestId);
    return {attempt, number: index + 1, averageMs: point?.averageMs ?? null,
      included: point?.included ?? false, inCurrentWindow: point?.inCurrentWindow ?? false};
  });
  const walletTime = profile?.wallet.bestTimeMs;
  const officialScores = input.allTime.filter(score => score.userId === profile?.id && Number.isFinite(score.timeMs) && score.timeMs > 0 && Number.isFinite(score.createdAt));
  const serverTime = Math.max(typeof walletTime === 'number' && Number.isFinite(walletTime) ? walletTime : 0, ...officialScores.map(score => score.timeMs));
  const localBest = chronological.filter(a => a.phase === 'confirmed').reduce<Attempt | undefined>((best, a) => !best || a.result!.timeMs > best.result!.timeMs ? a : best, undefined);
  let best: PersonalBest | null = null;
  if (localBest && localBest.result!.timeMs > serverTime) {
    best = {timeMs: localBest.result!.timeMs, createdAt: localBest.createdAt, localId: localBest.requestId, source: 'confirmed-local'};
  } else if (serverTime > 0) {
    const official = officialScores.find(score => score.timeMs === serverTime);
    const matching = chronological.filter(a => a.phase === 'confirmed' && a.result!.timeMs === serverTime);
    // A server row's date and selection must describe the same actual attempt.
    // Equal duration alone is insufficient when an official row is available.
    const local = official ? matching.find(a => a.roundId === official.id || a.requestId === official.id || a.createdAt === official.createdAt) : matching.at(0);
    best = {timeMs: serverTime, createdAt: official?.createdAt ?? local?.createdAt ?? null, localId: local?.requestId ?? null, source: 'server'};
  }
  const boardOwnerMatches = !board?.mine.userId || board.mine.userId === profile?.id;
  const average = boardOwnerMatches ? board?.mine.averageMs : null;
  return {rows, history: rows.slice().reverse(), chart, best,
    averageMs: typeof average === 'number' && Number.isFinite(average) && average >= 0 ? average : null,
    rules: board?.rules ?? null, historyComplete: boardOwnerMatches && (chart?.historyComplete ?? false),
    activeCount: chart?.points.filter(p => p.inCurrentWindow).length ?? 0};
}

/** Keep a selected historical ID visible without changing selection or graph state. */
export function attemptWindow(rows: AttemptRow[], selectedId: string | null, limit = 50): AttemptRow[] {
  const index = rows.findIndex(row => row.attempt.requestId === selectedId);
  const start = index < 0 ? Math.max(0, rows.length - limit) : Math.max(0, Math.min(rows.length - limit, index - Math.floor(limit / 2)));
  return rows.slice(start, start + limit);
}
