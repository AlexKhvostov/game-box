import type {WorldState} from '../domain/kernel';

/** Read readiness from this round's snapshot/config; never start a visual timer. */
export function jumpGlowProgress(
  state: Pick<WorldState, 'jumpEnabled' | 'jumpRemainingMs' | 'jumpCooldownMs'>,
  game: {jumpEnabled?: boolean; jumpCooldownSec?: number; jumpDurationSec?: number},
): number {
  if (state.jumpEnabled !== true || game.jumpEnabled !== true) return 0;
  const cooldown = game.jumpCooldownSec, duration = game.jumpDurationSec;
  if (typeof cooldown !== 'number' || !Number.isFinite(cooldown) || cooldown < 0 ||
      typeof duration !== 'number' || !Number.isFinite(duration) || duration < 0 ||
      !Number.isFinite(state.jumpCooldownMs) || state.jumpCooldownMs < 0 ||
      typeof state.jumpRemainingMs !== 'number' || !Number.isFinite(state.jumpRemainingMs) || state.jumpRemainingMs < 0) return 0;
  // tryJump has an independent mid-air guard and at least a .12s flight.
  // A zero/short configured cooldown must not advertise a second mid-air jump.
  const total = Math.max(cooldown * 1000, Math.max(.12, duration) * 1000);
  const remaining = Math.max(state.jumpCooldownMs, state.jumpRemainingMs);
  return Math.max(0, Math.min(1, 1 - remaining / total));
}
