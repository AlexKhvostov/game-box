import type { Attempt, GameConfig } from './contracts.ts';
import type { JsonStorage } from './storage.ts';
export class RoundJournal {
  private items: Attempt[];
  private storage: JsonStorage;
  readonly owner: string;
  constructor(storage: JsonStorage, owner: string) {
    this.storage = storage; this.owner = owner;
    const data = storage.get<{ version: number; owner: string; attempts: Attempt[] } | null>(`rounds:${owner}`, null);
    if (data && (data.version !== 1 || data.owner !== owner || !Array.isArray(data.attempts) || data.attempts.some(a =>
      a.owner !== owner || !/^[a-f0-9]{64}$/.test(a.requestId) || !Number.isSafeInteger(a.cost) || a.cost < 1 ||
      !['prepared','started','activated','finished','confirmed','rejected','abandoned'].includes(a.phase) ||
      a.proofVersion!==undefined&&a.proofVersion!==1&&a.proofVersion!==2&&a.proofVersion!==3 || typeof a.helmet !== 'boolean' || typeof a.jump !== 'boolean' || a.debitWalletVersion!==undefined&&(!Number.isSafeInteger(a.debitWalletVersion)||a.debitWalletVersion<0) || a.rewardVisualShown!==undefined&&typeof a.rewardVisualShown!=='boolean' || !/^[a-f0-9]{64}$/.test(a.config?.revision)))) throw new Error('journal_invalid');
    this.items = data?.attempts ?? [];
  }
  private save(items: Attempt[]) {
    // Delivered proofs belong on the server. Keep bounded lightweight local
    // history (100 displayed + up to 500 for the configurable RMS window).
    const terminal = (a: Attempt) => ['confirmed','rejected','abandoned'].includes(a.phase);
    const retained = new Set(items.filter(terminal).slice(-600).map(a => a.requestId));
    const compact = items.filter(a => !terminal(a) || retained.has(a.requestId)).map(a => {
      if (!terminal(a)) return a;
      const result = a.result ? { timeMs: a.result.timeMs, runDistance: a.result.runDistance, riskCount: a.result.riskCount } : undefined;
      return { ...a, config: { ok: true as const, revision: a.config.revision, config: {} }, result };
    });
    this.storage.set(`rounds:${this.owner}`, { version: 1, owner: this.owner, attempts: compact }); this.items = compact;
  }
  get all() { return structuredClone(this.items); }
  get pending() { return this.all.filter(a => !['confirmed','rejected','abandoned'].includes(a.phase)); }
  recoverUnfinished() { this.save(this.items.map(a => !a.result && !['confirmed','rejected','abandoned'].includes(a.phase) ? { ...a, abandoned: true } : a)); }
  reserved(walletVersion=Number.MAX_SAFE_INTEGER) { return this.items.filter(a => a.phase === 'prepared'||a.debitWalletVersion!==undefined&&a.debitWalletVersion>walletVersion).reduce((n, a) => n + a.cost, 0); }
  prepare(requestId: string, config: GameConfig, helmet: boolean, jump: boolean, balance: number, now: number, previousBestTimeMs?: number, walletVersion=Number.MAX_SAFE_INTEGER, proofVersion:1|2|3=1) {
    if (this.items.some(a => a.requestId === requestId)) throw new Error('operation_conflict');
    const e = config.config.economy.androidEnergyV2;
    const cost = e.baseAttemptCost + (helmet ? e.helmetExtraCost : 0) + (jump ? e.jumpExtraCost : 0);
    if (!Number.isSafeInteger(cost) || cost < 1 || balance - this.reserved(walletVersion) < cost) throw new Error('insufficient_energy');
    const entry: Attempt = { proofVersion, requestId, owner: this.owner, createdAt: now, config: JSON.parse(JSON.stringify(config)), helmet, jump, cost, phase: 'prepared', activatedAt: now, ...(previousBestTimeMs === undefined ? {} : { previousBestTimeMs }) };
    entry.rewardDivisors = { risk: Math.max(1,config.config.economy.riskRewardEvery), run: Math.max(1,config.config.economy.runRewardEvery) };
    this.save([...this.items, entry]); return entry;
  }
  update(id: string, patch: Partial<Attempt>) {
    if (patch.owner && patch.owner !== this.owner) throw new Error('owner_changed');
    const found = this.items.find(a => a.requestId === id); if (!found) throw new Error('round_not_found');
    this.save(this.items.map(a => a.requestId === id ? { ...a, ...structuredClone(patch), owner: this.owner, requestId: id } : a));
  }
}
