import type { RoundProof } from '../domain/kernel';
export interface Bonus { nextAt: number; durationMs: number; lastClaimAt: number; tier: number; reward: number; policy: { periodSec: number; videoReward: number; videoCooldownSec: number; videoDailyLimit: number; inviterReward: number } }
export interface Wallet {
  energy: number; bestTimeMs: number; claimed: string[]; gamesStarted: number; feedbackSpentEnergy: number; feedbackMinimumSpend?:number;
  lastAdAt?:number; energyIdentityReady: boolean; energyAgeCompleted?: boolean; simpleBonus: Bonus;
  adQuota: { used: number; limit: number; remaining: number; resetAt?: number; nextResetAt?: number };
  energyConfig: { revision: string; baseAttemptCost: number; helmetExtraCost: number; jumpExtraCost: number; rewards: { google: number; age: number; feedback: number; invite: number } };
  energySubscription: { batteryCount: number; expiresAt: number; awaitingReconciliation?: boolean; provider?: 'telegram'; autoRenew?: boolean } | null;
}
export interface Profile { id: string; nickname: string; platform: 'telegram'; telegramVerified: boolean; telegramUsername: string | null; hideTelegramAccount: boolean; communityRulesVersion: number; hiddenPlayers: string[]; wallet: Wallet; walletVersion: number; serverNow: number }
export interface GameConfig { ok: true; revision: string; config: Record<string, any> }
export interface PlatformConfig { ads: { enabled: boolean; interstitialEnabled?: boolean; rewardedBlockId: string; interstitialBlockId: string }; stars: { salesEnabled: boolean; pack100Price: number; pack250Price: number; pack500Price: number; pack1000Price: number; tier2Price: number; tier5Price: number; periodSec: number } }
export interface Score { id: string; userId: string; playerName: string; timeMs: number; createdAt: number; runDistance: number; riskCount: number; hadJump: boolean; hadHelmet: boolean; place?: number }
export interface AverageRow { userId?: string; playerName: string; averageMs: number | null; usedCount: number; eligibleCount: number; totalAttempts: number; place: number | null }
export interface AverageBoard { rules: { algorithm: string; windowSize: number; previousWeightPercent: number; minAttempts: number; minDurationMs: number }; rows: AverageRow[]; mine: AverageRow }
export interface ServerAttempt {id: string; number: number; timeMs: number; createdAt: number; runDistance: number; riskCount: number; hadJump: boolean; hadHelmet: boolean; averageMs: number | null; included: boolean; windowCount: number}
export interface ServerAttemptHistory {userId: string; snapshot: string; totalCount: number; rows: ServerAttempt[]; nextCursor: string | null; best: ServerAttempt | null}
export interface AttemptHistorySnapshot {average: AverageBoard; history: ServerAttemptHistory}
export interface InviteState { ownCode: string; inviteUrl: string; telegramInviteUrl?: string; inviterAssigned: boolean; inviterCode: string | null; completedGames: number; bonusStatus: string; reward: number; requiredGames: number; rewardTotal: number; invitedCount: number; paidRows: any[]; pendingRows: any[]; nextCursor: string | null }
export interface ApiResult { ok: true; profile?: Profile; gameConfig?: GameConfig; platformConfig?: PlatformConfig; serverNow?: number; roundId?: string; energyReward?: number; attemptCost?: number; activated?: boolean; periods?: Record<string, Score[]>; average?: AverageBoard; rules?: AverageBoard['rules']; rows?: AverageRow[]; mine?: AverageRow; invites?: InviteState; [key: string]: any }
export interface Attempt { debitWalletVersion?:number; rewardVisualShown?:boolean; rewardDivisors?: {risk:number;run:number}; previousBestTimeMs?: number; requestId: string; roundId?: string; owner: string; createdAt: number; config: GameConfig; helmet: boolean; jump: boolean; cost: number; activatedAt?: number; finishedAt?: number; abandoned?: boolean; result?: { timeMs: number; runDistance: number; riskCount: number; proof?: RoundProof }; phase: 'prepared' | 'started' | 'activated' | 'finished' | 'confirmed' | 'rejected' | 'abandoned'; error?: string; reward?: number }
