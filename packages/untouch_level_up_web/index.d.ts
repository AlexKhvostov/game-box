export type LevelNumber = 1 | 2 | 3 | 4 | 5 | 6 | 7;
export type LevelUpPhase = 'intro' | 'rank' | 'paused' | 'complete';
export interface LevelUpResult { reason: 'accept' | 'dismiss' | 'dispose'; level: LevelNumber }
export interface LevelUpOptions {
  level?: LevelNumber; muted?: boolean; reduced?: boolean; assetBase?: string | URL;
  onPhaseChange?: (event: {phase: LevelUpPhase; level: LevelNumber}) => void;
  onAccept?: (event: {level: LevelNumber}) => void;
  onClose?: (event: LevelUpResult) => void;
}
export class LevelUpModal {
  constructor(options?: LevelUpOptions);
  readonly result: Promise<LevelUpResult>;
  readonly dialog: HTMLDialogElement;
  readonly closed: boolean;
  setLevel(level: LevelNumber): void;
  setMuted(muted: boolean): void;
  close(reason?: 'accept' | 'dismiss'): void;
  destroy(): void;
}
export class LevelUpAnimation {
  constructor(host: HTMLElement, options?: Omit<LevelUpOptions,'onAccept'|'onClose'> & {locale?:'ru'|'en';autoplay?: boolean;onComplete?: (event:{level:LevelNumber})=>void});
  play(): void; pause(): void; finish(options?: {animate?:boolean}): void;
  setLevel(level: LevelNumber): void; setMuted(muted: boolean): void; setLocale(locale:'ru'|'en'):void; destroy(): void;
}
export function checkedLevel(value: number): LevelNumber;
export function levelTitle(level: LevelNumber): string;
