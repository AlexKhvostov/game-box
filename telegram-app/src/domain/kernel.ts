import {version as appVersion} from '../../package.json';
export type ProofEvent = [0, number] | [1, number, number] | [2];
export interface RoundProof { version: 1 | 2 | 3 | 4 | 5; events: ProofEvent[]; startPose: number[][] }
export interface Body { x: number; y: number; w: number; h: number; angle: number; speed: number }
export interface BrakeState {enabled:boolean;speedBarEnabled:boolean;effectiveSec:number;speed:number;targetSpeed:number;charge:number;ready:boolean;presses:number;pressAgeMs:number;readyAgeMs:number;beforeSpeed:number;afterSpeed:number}
export interface WorldState {
  helmetCharge?: {equipped:boolean;cooldownMs:number;remainingMs:number;progress:number;readyAgeMs:number|null;breaks:number};
  brake?: BrakeState | null;
  playing: boolean; dead: boolean; timeMs: number; runDistance: number; riskCount: number;
  helmet: boolean; invulnerable: boolean; jumpCooldownMs: number; jumpCount?:number;
  jumpEnabled?: boolean; jumpRemainingMs?: number;
  player: { x: number; y: number; size: number; visualScale: number; jumpLift: number };
  enemies: Body[]; wallBounces: number; enemyBounces: number;
  againstWall: boolean; issue?: string | null;
  impactOrigin?: {x:number;y:number}|null; startled?:boolean; nearMissFx?:{x:number;y:number;age:number}[];
}
declare global { var untouchKernel: ((input: string) => string) | undefined }
let loading: Promise<void> | undefined;
export function loadKernel(): Promise<void> {
  return loading ??= new Promise<void>((resolve, reject) => {
    const script = document.createElement('script');
    script.src = `${import.meta.env.BASE_URL}kernel/helmet-world-v3.js?v=${appVersion}`;
    script.onload = () => globalThis.untouchKernel ? resolve() : reject(new Error('kernel_unavailable'));
    script.onerror = () => reject(new Error('kernel_unavailable'));
    document.head.append(script);
  }).catch(error => { loading = undefined; throw error; });
}
export function kernel(input: Record<string, unknown>): WorldState {
  if (!globalThis.untouchKernel) throw new Error('kernel_unavailable');
  const result = JSON.parse(globalThis.untouchKernel(JSON.stringify(input)));
  if (!result.ok) throw new Error(result.error);
  return result;
}
export function proof(): RoundProof {
  const result = JSON.parse(globalThis.untouchKernel!(JSON.stringify({ op: 'proof' })));
  if (!result.ok) throw new Error(result.error);
  return result.proof;
}
