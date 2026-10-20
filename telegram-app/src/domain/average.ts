import type { Attempt, AverageBoard } from '../services/contracts.ts';
// Read-only projection matching lib/domain/average_chart.dart. Never submitted.
export function averageChart(attempts: Attempt[], ranking: AverageBoard) {
  const confirmed = attempts.filter(a => a.phase === 'confirmed' && a.result && a.result.timeMs > 0)
    .sort((a, b) => a.createdAt - b.createdAt || a.requestId.localeCompare(b.requestId));
  const eligible: { value: number; id: string }[] = [];
  const points = confirmed.map(a => {
    const included = a.result!.timeMs > ranking.rules.minDurationMs;
    if (included) { eligible.push({ value: a.result!.timeMs, id: a.requestId }); if (eligible.length > ranking.rules.windowSize) eligible.shift(); }
    let sum = 0, weights = 0, factor = 1;
    for (let i = eligible.length - 1; i >= 0; i--) { const value = eligible[i]!.value; sum += (ranking.rules.algorithm === 'weighted_rms_v1' ? value * value : value) * factor; weights += factor; factor *= ranking.rules.previousWeightPercent / 100; }
    const average = weights ? sum / weights : null;
    return { attempt: a, included, averageMs: average === null ? null : ranking.rules.algorithm === 'weighted_rms_v1' ? Math.sqrt(average) : average, windowCount: eligible.length, inCurrentWindow: false };
  });
  const current = new Set(eligible.map(e => e.id));
  for (const p of points) p.inCurrentWindow = current.has(p.attempt.requestId);
  const end=points.at(-1),official=ranking.mine.averageMs;
  const matchesRanking=!!end&&end.averageMs!==null&&official!==null&&official!==undefined&&Math.abs(end.averageMs-official)<.01&&end.windowCount===ranking.mine.usedCount;
  return { points: points.slice(-100), averageMs: points.at(-1)?.averageMs ?? null, confirmedCount: confirmed.length,
    matchesRanking, historyComplete: confirmed.length===ranking.mine.totalAttempts&&matchesRanking, awaitingCount: attempts.filter(a => !['confirmed','rejected','abandoned'].includes(a.phase)).length };
}
