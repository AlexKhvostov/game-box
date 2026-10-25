/** Cosmetic observer; all time and readiness come from the actual simulation. */
export class JumpReadySignal {
  static readonly flashDurationMs = 420;
  ready = false;
  private observed = false;
  private lastNow = 0;
  private lastRemaining = 0;
  private readyAt: number | null = null;
  get ageMs(): number | null { return this.readyAt === null ? null : this.lastNow - this.readyAt; }
  reset(): void {
    this.ready = this.observed = false;
    this.readyAt = null;
    this.lastNow = this.lastRemaining = 0;
  }
  observe(enabled: boolean, remainingMs: number, nowMs: number): void {
    if (!enabled || !Number.isFinite(remainingMs) || remainingMs < 0 || !Number.isFinite(nowMs) || nowMs < 0) {
      this.reset(); return;
    }
    if (this.observed && nowMs < this.lastNow) this.reset();
    const ready = remainingMs === 0;
    if (!ready) this.readyAt = null;
    else if (this.observed && !this.ready) this.readyAt = Math.min(nowMs, this.lastNow + this.lastRemaining);
    this.ready = ready;
    this.observed = true;
    this.lastNow = nowMs;
    this.lastRemaining = remainingMs;
  }
}

export function jumpReadyFlash(ageMs: number | null = null, reduced = false): number {
  return reduced || ageMs === null || !Number.isFinite(ageMs) || ageMs < 0 || ageMs >= JumpReadySignal.flashDurationMs
    ? 0 : Math.sin(Math.PI * ageMs / JumpReadySignal.flashDurationMs);
}
