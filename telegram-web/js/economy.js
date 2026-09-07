import { calcScore } from './util.js';
import { telegram } from './telegram.js';

/** Local economy — mirrors lib/data/economy_store.dart (offline Telegram). */

const KEY = 'untouch_tg_economy';
const COMM_KEY = 'untouch_community_scores_v2';

function dayStart(d = new Date()) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function getPeriodStartMs(period) {
  const now = new Date();
  if (period === 'day') {
    return new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  }
  if (period === 'week') {
    const d = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    d.setDate(d.getDate() - 7);
    return d.getTime();
  }
  if (period === 'month') {
    return new Date(now.getFullYear(), now.getMonth(), 1).getTime();
  }
  if (period === 'year') {
    return new Date(now.getFullYear(), 0, 1).getTime();
  }
  return 0;
}

function sameDay(a, b) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

export class EconomyStore {
  constructor(config) {
    this.config = config;
    const e = config.economy;
    this.lives = e.initialLives;
    this.tokens = e.initialTokens ?? 0;
    this.bestTimeMs = 0;
    this.jumpRentalUntil = 0;
    this.helmetRentalUntil = 0;
    this.dailyStreak = 0;
    this.lastDailyClaimMs = 0;
    this.lastTimedBonusClaimMs = 0;
    this.lastWatchAdClaimMs = 0;
    this.claimedEarnIds = new Set();
    this.unlockedEarnIds = new Set();
    this.hasPremium = false;
    this.premiumNextChargeMs = 0;
    this.customNickname = null;
    this.hideTelegramUsername = false;
    this.recentAttempts = [];
    this.communityScores = [];
    this._fresh = true;
    this._load();
    this._loadCommunityScores();
    this.syncCommunityScores();
    if (this._fresh && e.installBonusAutoClaim !== false) {
      this._claimInstallBonus();
    }
  }

  _loadCommunityScores() {
    try {
      const raw = localStorage.getItem(COMM_KEY);
      if (raw) {
        const arr = JSON.parse(raw);
        if (Array.isArray(arr)) {
          // Исключаем старые фейковые seed-записи, оставляем только реальных людей
          this.communityScores = arr.filter((s) => !String(s.id || '').startsWith('seed_'));
          return;
        }
      }
    } catch (e) {
      console.warn('community scores load', e);
    }
    this.communityScores = [];
    this._saveCommunityScores();
  }

  _saveCommunityScores() {
    try {
      localStorage.setItem(COMM_KEY, JSON.stringify(this.communityScores.slice(0, 300)));
    } catch (e) {
      console.warn('community scores save', e);
    }
  }

  async syncCommunityScores(onUpdated = null) {
    try {
      const ctrl = typeof AbortController !== 'undefined' ? new AbortController() : null;
      const timeout = ctrl ? setTimeout(() => ctrl.abort(), 4000) : null;
      const res = await fetch('api/scores.php', { signal: ctrl?.signal });
      if (timeout) clearTimeout(timeout);
      if (!res.ok) return;
      const data = await res.json();
      if (data && Array.isArray(data.scores)) {
        this._mergeRemoteScores(data.scores);
        this._saveCommunityScores();
        if (typeof onUpdated === 'function') onUpdated();
      }
    } catch (e) {
      // Offline / fallback to local community scores
    }
  }

  _mergeRemoteScores(remoteScores) {
    if (!Array.isArray(remoteScores)) return;
    for (const r of remoteScores) {
      if (!r || !r.timeMs || String(r.id || '').startsWith('seed_')) continue;
      if (r.score == null) {
        r.score = calcScore(r.timeMs, r.runDistance, r.riskCount);
      }
      const key = r.userId != null ? `id_${r.userId}` : (r.username ? `u_${r.username.toLowerCase()}` : `name_${r.playerName || 'Игрок'}`);
      const idx = this.communityScores.findIndex((s) => {
        const k = s.userId != null ? `id_${s.userId}` : (s.username ? `u_${s.username.toLowerCase()}` : `name_${s.playerName || 'Игрок'}`);
        return k === key;
      });
      if (idx >= 0) {
        if (r.timeMs >= (this.communityScores[idx].timeMs || 0)) {
          this.communityScores[idx] = { ...this.communityScores[idx], ...r };
        }
      } else {
        this.communityScores.push(r);
      }
    }
    this.communityScores.sort((a, b) => b.timeMs - a.timeMs);
  }

  async _postScoreToServer(payload) {
    try {
      await fetch('api/scores.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
    } catch (e) {
      // Silent catch on offline
    }
  }

  async _postProfileToServer(payload) {
    const res = await fetch('api/scores.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        action: 'update_profile',
        ...payload,
      }),
    });
    const text = await res.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch (e) {
      throw new Error(`Сервер вернул не JSON (HTTP ${res.status})`);
    }
    if (!res.ok || !data || data.ok === false) {
      throw new Error((data && data.error) || `Ошибка сервера HTTP ${res.status}`);
    }
    if (data && Array.isArray(data.scores)) {
      this._mergeRemoteScores(data.scores);
      this._saveCommunityScores();
    }
    return data;
  }

  _load() {
    try {
      const raw = localStorage.getItem(KEY);
      if (!raw) return;
      this._fresh = false;
      const d = JSON.parse(raw);
      if (typeof d.lives === 'number') this.lives = d.lives;
      if (typeof d.tokens === 'number') this.tokens = d.tokens;
      if (typeof d.bestTimeMs === 'number') this.bestTimeMs = d.bestTimeMs;
      if (typeof d.jumpRentalUntil === 'number') this.jumpRentalUntil = d.jumpRentalUntil;
      if (typeof d.helmetRentalUntil === 'number') this.helmetRentalUntil = d.helmetRentalUntil;
      if (typeof d.dailyStreak === 'number') this.dailyStreak = d.dailyStreak;
      if (typeof d.lastDailyClaimMs === 'number') this.lastDailyClaimMs = d.lastDailyClaimMs;
      if (typeof d.lastTimedBonusClaimMs === 'number') this.lastTimedBonusClaimMs = d.lastTimedBonusClaimMs;
      if (typeof d.lastWatchAdClaimMs === 'number') this.lastWatchAdClaimMs = d.lastWatchAdClaimMs;
      if (Array.isArray(d.claimedEarnIds)) this.claimedEarnIds = new Set(d.claimedEarnIds);
      if (Array.isArray(d.unlockedEarnIds)) this.unlockedEarnIds = new Set(d.unlockedEarnIds);
      if (typeof d.hasPremium === 'boolean') this.hasPremium = d.hasPremium;
      if (typeof d.premiumNextChargeMs === 'number') this.premiumNextChargeMs = d.premiumNextChargeMs;
      if (typeof d.customNickname === 'string') this.customNickname = d.customNickname;
      if (typeof d.hideTelegramUsername === 'boolean') this.hideTelegramUsername = d.hideTelegramUsername;
      if (Array.isArray(d.recentAttempts)) this.recentAttempts = d.recentAttempts;
      if (this.hasPremium && !this.premiumNextChargeMs) {
        this.premiumNextChargeMs = Date.now() + 7 * 86400000;
      }
    } catch (err) {
      console.warn('economy load', err);
    }
  }

  _save() {
    try {
      localStorage.setItem(
        KEY,
        JSON.stringify({
          lives: this.lives,
          tokens: this.tokens,
          bestTimeMs: this.bestTimeMs,
          jumpRentalUntil: this.jumpRentalUntil,
          helmetRentalUntil: this.helmetRentalUntil,
          dailyStreak: this.dailyStreak,
          lastDailyClaimMs: this.lastDailyClaimMs,
          lastTimedBonusClaimMs: this.lastTimedBonusClaimMs,
          lastWatchAdClaimMs: this.lastWatchAdClaimMs,
          claimedEarnIds: [...this.claimedEarnIds],
          unlockedEarnIds: [...this.unlockedEarnIds],
          hasPremium: this.hasPremium,
          premiumNextChargeMs: this.premiumNextChargeMs,
          customNickname: this.customNickname,
          hideTelegramUsername: this.hideTelegramUsername,
          recentAttempts: this.recentAttempts.slice(0, 50),
        }),
      );
    } catch (err) {
      console.warn('economy save', err);
    }
  }

  get effectivePlayerName() {
    if (this.customNickname && this.customNickname.trim()) {
      return this.customNickname.trim();
    }
    return telegram.playerName || 'Игрок';
  }

  get effectiveUsername() {
    if (this.hideTelegramUsername) return null;
    return telegram.user?.username ? `@${telegram.user.username.replace(/^@/, '')}` : null;
  }

  async updateProfile({ customNickname, hideTelegramUsername }) {
    if (customNickname !== undefined) {
      const clean = typeof customNickname === 'string' ? customNickname.trim().slice(0, 30) : null;
      this.customNickname = clean || null;
    }
    if (typeof hideTelegramUsername === 'boolean') {
      this.hideTelegramUsername = hideTelegramUsername;
    }
    this._save();

    // Обновляем ник текущего пользователя в локальном кэше recentAttempts
    for (const att of this.recentAttempts) {
      if (att.isMe) {
        att.playerName = this.effectivePlayerName;
        att.username = this.effectiveUsername;
        att.hideTelegram = this.hideTelegramUsername;
      }
    }

    // Обновляем ник текущего пользователя в локальном кэше communityScores
    const myId = telegram?.user?.id ? String(telegram.user.id) : null;
    const rawUsername = telegram?.user?.username ? `@${telegram.user.username.replace(/^@/, '')}` : null;
    const myUsername = this.effectiveUsername;

    for (const item of this.communityScores) {
      if ((myId && String(item.userId) === myId) || (rawUsername && item.username === rawUsername) || item.isMe) {
        item.playerName = this.effectivePlayerName;
        item.username = myUsername;
        item.hideTelegram = this.hideTelegramUsername;
      }
    }
    this._saveCommunityScores();

    // Сохраняем обновление профиля на сервере (MySQL / HostLand)
    try {
      return await this._postProfileToServer({
        userId: myId,
        username: myUsername,
        rawUsername: rawUsername,
        hideTelegram: this.hideTelegramUsername,
        playerName: this.effectivePlayerName,
        firstName: telegram?.user?.first_name || null,
        lastName: telegram?.user?.last_name || null,
        photoUrl: telegram?.userPhotoUrl,
      });
    } catch (err) {
      console.warn('updateProfile remote failed', err);
      return {
        ok: false,
        local: true,
        error: err?.message || String(err),
      };
    }
  }

  get e() {
    return this.config.economy;
  }

  activatePremiumPreview() {
    this.hasPremium = true;
    this.premiumNextChargeMs = Date.now() + 7 * 86400000;
    this._save();
  }

  cancelPremium() {
    if (!this.hasPremium) return;
    this.hasPremium = false;
    this.premiumNextChargeMs = 0;
    this._save();
  }

  get premiumNextChargeDate() {
    if (!this.premiumNextChargeMs) return null;
    return new Date(this.premiumNextChargeMs);
  }

  get canPlay() {
    return this.lives > 0;
  }

  get lifePacks() {
    return this.e.lifePacks ?? [{ lives: 5, costTokens: 5 }];
  }

  get earnActions() {
    return this.e.earnActions ?? [];
  }

  jumpRentalHourListPrice() {
    const short = Math.max(1, this.e.jumpRentalMinutes ?? 10);
    const hour = Math.max(1, this.e.jumpRentalHourMinutes ?? 60);
    return Math.max(1, Math.round(((this.e.jumpRentalCost ?? 20) * hour) / short));
  }

  helmetRentalHourListPrice() {
    const short = Math.max(1, this.e.helmetRentalMinutes ?? 10);
    const hour = Math.max(1, this.e.helmetRentalHourMinutes ?? 60);
    return Math.max(1, Math.round(((this.e.helmetRentalCost ?? 40) * hour) / short));
  }

  jumpRentalHourDiscountPercent() {
    const list = this.jumpRentalHourListPrice();
    const cost = this.e.jumpRentalHourCost ?? 60;
    if (list <= 0 || cost >= list) return 0;
    return Math.min(99, Math.round(((list - cost) / list) * 100));
  }

  helmetRentalHourDiscountPercent() {
    const list = this.helmetRentalHourListPrice();
    const cost = this.e.helmetRentalHourCost ?? 120;
    if (list <= 0 || cost >= list) return 0;
    return Math.min(99, Math.round(((list - cost) / list) * 100));
  }

  dailyTokensForStreak(streakIndex, premium = false) {
    const rewards = this.e.dailyRewardTokens ?? [2, 4, 9, 16, 32, 64, 81];
    const idx = Math.max(0, Math.min(streakIndex, rewards.length - 1));
    const base = rewards[idx] ?? 2;
    if (!premium) return base;
    const mult = this.e.premiumDailyMultiplier ?? 2;
    return Math.min(99999, Math.max(base, Math.round(base * mult)));
  }

  get canClaimDaily() {
    if (!this.lastDailyClaimMs) return true;
    const last = new Date(this.lastDailyClaimMs);
    const today = dayStart();
    const lastDay = dayStart(last);
    return lastDay.getTime() < today.getTime();
  }

  get upcomingStreakDay() {
    if (this.canClaimDaily) {
      if (!this.lastDailyClaimMs) return 1;
      const last = new Date(this.lastDailyClaimMs);
      const today = dayStart();
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      const lastDay = dayStart(last);
      if (sameDay(lastDay, yesterday)) return Math.min(this.dailyStreak + 1, (this.e.dailyRewardTokens ?? []).length || 7);
      return 1;
    }
    return this.dailyStreak;
  }

  get untilMidnight() {
    const now = new Date();
    const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    return Math.max(0, next.getTime() - now.getTime());
  }

  dailyRewardAmount() {
    return this.dailyTokensForStreak(this.upcomingStreakDay - 1, this.hasPremium);
  }

  _claimInstallBonus() {
    if (this.claimedEarnIds.has('install_bonus')) return;
    this.claimedEarnIds.add('install_bonus');
    this.unlockedEarnIds.add('install_bonus');
    this._save();
  }

  claimDaily() {
    if (!this.canClaimDaily) return null;
    const now = new Date();
    if (this.lastDailyClaimMs) {
      const last = new Date(this.lastDailyClaimMs);
      const today = dayStart(now);
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      const lastDay = dayStart(last);
      this.dailyStreak = sameDay(lastDay, yesterday) ? this.dailyStreak + 1 : 1;
    } else {
      this.dailyStreak = 1;
    }
    const amount = this.dailyTokensForStreak(this.dailyStreak - 1, this.hasPremium);
    this.tokens += amount;
    this.lastDailyClaimMs = now.getTime();
    this._save();
    return amount;
  }

  get _timedBonusIntervalMs() {
    const h = Math.max(0, Math.min(24 * 30, this.e.timedBonusHours ?? 1));
    return h * 3600 * 1000;
  }

  get canClaimTimedBonus() {
    if (!this.lastTimedBonusClaimMs) return true;
    return Date.now() >= this.lastTimedBonusClaimMs + this._timedBonusIntervalMs;
  }

  get timedBonusRemainingMs() {
    if (this.canClaimTimedBonus) return 0;
    return Math.max(0, this.lastTimedBonusClaimMs + this._timedBonusIntervalMs - Date.now());
  }

  get timedBonusUnlockProgress() {
    if (this.canClaimTimedBonus) return 1;
    if (!this.lastTimedBonusClaimMs) return 1;
    const total = this._timedBonusIntervalMs;
    if (total <= 0) return 1;
    const elapsed = Date.now() - this.lastTimedBonusClaimMs;
    return Math.max(0, Math.min(1, elapsed / total));
  }

  claimTimedBonus() {
    if (!this.canClaimTimedBonus) return null;
    const amount = this.e.timedBonusTokens ?? 22;
    this.tokens += amount;
    this.lastTimedBonusClaimMs = Date.now();
    this._save();
    return amount;
  }

  get _watchAdCooldownMs() {
    const sec = Math.max(0, Math.min(24 * 3600, this.e.watchAdCooldownSec ?? 300));
    return sec * 1000;
  }

  get canClaimWatchAd() {
    if (!this.lastWatchAdClaimMs) return true;
    if (this._watchAdCooldownMs <= 0) return true;
    return Date.now() >= this.lastWatchAdClaimMs + this._watchAdCooldownMs;
  }

  get watchAdCooldownRemainingMs() {
    if (this.canClaimWatchAd) return 0;
    return Math.max(0, this.lastWatchAdClaimMs + this._watchAdCooldownMs - Date.now());
  }

  claimWatchAd(fallbackReward = 5) {
    if (!this.canClaimWatchAd) return null;
    let reward = fallbackReward;
    for (const a of this.earnActions) {
      if (a.id === 'watch_ad') {
        reward = a.reward;
        break;
      }
    }
    this.tokens += reward;
    this.lastWatchAdClaimMs = Date.now();
    this.claimedEarnIds.delete('watch_ad');
    this._save();
    return reward;
  }

  isEarnClaimed(id) {
    return this.claimedEarnIds.has(id);
  }

  isEarnUnlocked(id) {
    const gameplay = ['survive_10s', 'record_20s', 'risks_5'];
    if (!gameplay.includes(id)) return true;
    return this.unlockedEarnIds.has(id) || this.claimedEarnIds.has(id);
  }

  syncGameplayEarnUnlocks(aliveMs, riskCount, persist = true) {
    const surviveMs = Math.max(1, (this.e.earnSurviveSeconds ?? 10) * 1000);
    const recordMs = Math.max(1, (this.e.earnRecordSeconds ?? 20) * 1000);
    const risksTarget = Math.max(1, this.e.earnRisksInRun ?? 5);
    const bestOrRun = Math.max(aliveMs, this.bestTimeMs);
    const unlock = (id, cond) => {
      if (!cond || this.claimedEarnIds.has(id) || this.unlockedEarnIds.has(id)) return;
      if (!this.earnActions.some((a) => a.id === id)) return;
      this.unlockedEarnIds.add(id);
    };
    unlock('survive_10s', bestOrRun >= surviveMs);
    unlock('record_20s', bestOrRun >= recordMs);
    unlock('risks_5', riskCount >= risksTarget);
    if (persist) this._save();
  }

  claimEarnAction(id) {
    if (this.claimedEarnIds.has(id) || !this.isEarnUnlocked(id)) return null;
    const action = this.earnActions.find((a) => a.id === id);
    if (!action) return null;
    this.claimedEarnIds.add(id);
    this.unlockedEarnIds.add(id);
    this.tokens += action.reward;
    this._save();
    return action.reward;
  }

  canBuyLifePack(pack) {
    return this.tokens >= pack.costTokens;
  }

  buyLifePack(pack) {
    if (!this.canBuyLifePack(pack)) return false;
    this.tokens -= pack.costTokens;
    this.lives += pack.lives;
    this._save();
    return true;
  }

  canRentJump(hour = false) {
    const cost = hour ? this.e.jumpRentalHourCost : this.e.jumpRentalCost;
    return this.tokens >= cost;
  }

  canRentHelmet(hour = false) {
    const cost = hour ? this.e.helmetRentalHourCost : this.e.helmetRentalCost;
    return this.tokens >= cost;
  }

  _extendRental(untilMs, addMinutes) {
    const base = Math.max(untilMs, Date.now());
    return base + addMinutes * 60 * 1000;
  }

  rentJump(hour = false) {
    const cost = hour ? this.e.jumpRentalHourCost : this.e.jumpRentalCost;
    const mins = hour ? this.e.jumpRentalHourMinutes : this.e.jumpRentalMinutes;
    if (this.tokens < cost) return false;
    this.tokens -= cost;
    this.jumpRentalUntil = this._extendRental(this.jumpRentalUntil, mins);
    this._save();
    return true;
  }

  rentHelmet(hour = false) {
    const cost = hour ? this.e.helmetRentalHourCost : this.e.helmetRentalCost;
    const mins = hour ? this.e.helmetRentalHourMinutes : this.e.helmetRentalMinutes;
    if (this.tokens < cost) return false;
    this.tokens -= cost;
    this.helmetRentalUntil = this._extendRental(this.helmetRentalUntil, mins);
    this._save();
    return true;
  }

  buyJumpRent(hour = false) {
    return this.rentJump(hour);
  }

  buyHelmetRent(hour = false) {
    return this.rentHelmet(hour);
  }

  get jumpRentalRemaining() {
    const left = (this.jumpRentalUntil - Date.now()) / 1000;
    return left > 0 ? left : null;
  }

  get helmetRentalRemaining() {
    const left = (this.helmetRentalUntil - Date.now()) / 1000;
    return left > 0 ? left : null;
  }

  hasJumpRental() {
    return this.jumpRentalRemaining != null;
  }

  hasHelmetRental() {
    return this.helmetRentalRemaining != null;
  }

  spendLife() {
    if (this.lives <= 0) return false;
    this.lives -= 1;
    this._save();
    return true;
  }

  getBestForPeriod(period = 'all') {
    if (period === 'all') return this.bestTimeMs;
    const start = getPeriodStartMs(period);
    let best = 0;
    for (const a of this.recentAttempts) {
      if ((a.createdAt || 0) >= start && a.timeMs > best) {
        best = a.timeMs;
      }
    }
    return best;
  }

  getAttemptsForPeriod(period = 'day') {
    if (period === 'mine') {
      return [...this.recentAttempts];
    }
    const start = getPeriodStartMs(period);
    // Берем записи сообщества за указанный период
    const pool = [...this.communityScores.filter((a) => (a.createdAt || 0) >= start)];

    // Добавляем лучший результат текущего игрока за этот период из его попыток (если есть)
    for (const myAtt of this.recentAttempts) {
      if ((myAtt.createdAt || 0) >= start) {
        pool.push({
          ...myAtt,
          isMe: true,
        });
      }
    }

    pool.sort((a, b) => b.timeMs - a.timeMs);

    // Только лучший результат каждого игрока (без дублей одного человека)
    const seenUsers = new Set();
    const uniqueByPlayer = [];
    for (const att of pool) {
      const userKey = att.userId != null ? `id_${att.userId}` : `name_${att.playerName || 'player'}`;
      if (!seenUsers.has(userKey)) {
        seenUsers.add(userKey);
        uniqueByPlayer.push(att);
      }
    }
    return uniqueByPlayer.slice(0, 50);
  }

  recordAttempt(timeMs, riskCount = 0, runDistance = 0, playerInfo = {}) {
    if (timeMs <= 0) return null;

    const oldAllTimeBest = this.bestTimeMs;
    const oldDayBest = this.getBestForPeriod('day');
    const oldWeekBest = this.getBestForPeriod('week');
    const oldMonthBest = this.getBestForPeriod('month');

    const isAllTimeBest = timeMs > oldAllTimeBest;
    const isDayBest = timeMs > oldDayBest;
    const isWeekBest = timeMs > oldWeekBest;
    const isMonthBest = timeMs > oldMonthBest;

    const score = playerInfo.score != null ? playerInfo.score : calcScore(timeMs, runDistance, riskCount);
    const pName = playerInfo.playerName || this.effectivePlayerName;
    const pUsername = this.hideTelegramUsername ? null : (playerInfo.username || this.effectiveUsername);

    const item = {
      id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
      timeMs,
      riskCount,
      runDistance: Math.round(runDistance),
      score,
      createdAt: Date.now(),
      playerName: pName,
      username: pUsername,
      hideTelegram: this.hideTelegramUsername,
      firstName: playerInfo.firstName || null,
      lastName: playerInfo.lastName || null,
      photoUrl: playerInfo.photoUrl || null,
      userId: playerInfo.userId || null,
      hadJump: Boolean(playerInfo.hadJump),
      hadHelmet: Boolean(playerInfo.hadHelmet),
      isAllTimeBest,
      isDayBest,
      isWeekBest,
      isMonthBest,
      autoSaved: true,
      isMe: true,
    };

    if (isAllTimeBest) {
      this.bestTimeMs = timeMs;
    }

    this.recentAttempts.unshift(item);
    if (this.recentAttempts.length > 50) this.recentAttempts.length = 50;
    this._save();

    // Обновляем результат текущего пользователя в общем рейтинге сообщества
    const myKey = playerInfo.userId != null ? `id_${playerInfo.userId}` : (pUsername ? `u_${pUsername.toLowerCase()}` : `name_${pName}`);
    const commIdx = this.communityScores.findIndex((s) => {
      const k = s.userId != null ? `id_${s.userId}` : (s.username ? `u_${s.username.toLowerCase()}` : `name_${s.playerName || 'Игрок'}`);
      return k === myKey;
    });

    if (commIdx >= 0) {
      if (timeMs > (this.communityScores[commIdx].timeMs || 0)) {
        this.communityScores[commIdx].timeMs = timeMs;
        this.communityScores[commIdx].runDistance = Math.round(runDistance);
        this.communityScores[commIdx].riskCount = riskCount;
        this.communityScores[commIdx].score = score;
        this.communityScores[commIdx].hadJump = Boolean(playerInfo.hadJump);
        this.communityScores[commIdx].hadHelmet = Boolean(playerInfo.hadHelmet);
        this.communityScores[commIdx].createdAt = Date.now();
      }
      this.communityScores[commIdx].playerName = pName;
      this.communityScores[commIdx].username = pUsername;
      this.communityScores[commIdx].hideTelegram = this.hideTelegramUsername;
      if (playerInfo.firstName) this.communityScores[commIdx].firstName = playerInfo.firstName;
      if (playerInfo.lastName) this.communityScores[commIdx].lastName = playerInfo.lastName;
      if (playerInfo.photoUrl) this.communityScores[commIdx].photoUrl = playerInfo.photoUrl;
      this.communityScores[commIdx].isMe = true;
    } else {
      this.communityScores.push({
        id: 'usr_' + Date.now().toString(36),
        playerName: pName,
        username: pUsername,
        hideTelegram: this.hideTelegramUsername,
        firstName: playerInfo.firstName || null,
        lastName: playerInfo.lastName || null,
        photoUrl: playerInfo.photoUrl || null,
        userId: playerInfo.userId || null,
        timeMs,
        runDistance: Math.round(runDistance),
        riskCount,
        score,
        hadJump: Boolean(playerInfo.hadJump),
        hadHelmet: Boolean(playerInfo.hadHelmet),
        createdAt: Date.now(),
        isMe: true,
      });
    }
    this._saveCommunityScores();
    // Отправляем новый результат на сервер (MySQL / HostLand)
    // Отправляем только когда игрок показал свой лучший результат за сегодня (или первый заезд за день)
    if (isDayBest || oldDayBest <= 0) {
      this._postScoreToServer({
        playerName: pName,
        username: pUsername,
        hideTelegram: this.hideTelegramUsername,
        firstName: playerInfo.firstName || null,
        lastName: playerInfo.lastName || null,
        photoUrl: playerInfo.photoUrl || null,
        userId: playerInfo.userId || null,
        timeMs,
        runDistance: Math.round(runDistance),
        riskCount,
        score,
        hadJump: Boolean(playerInfo.hadJump),
        hadHelmet: Boolean(playerInfo.hadHelmet),
        createdAt: Date.now(),
      });
    }

    return {
      item,
      isAllTimeBest,
      isDayBest,
      isWeekBest,
      isMonthBest,
      oldAllTimeBest,
      oldDayBest,
    };
  }

  finishRun(timeMs, riskCount = 0, runDistance = 0, playerInfo = {}) {
    const rec = this.recordAttempt(timeMs, riskCount, runDistance, playerInfo);
    this.syncGameplayEarnUnlocks(timeMs, riskCount, false);
    const gained = this._runEndTokens(riskCount, runDistance);
    if (gained > 0) this.tokens += gained;
    this._save();

    return {
      gainedTokens: gained,
      isAllTimeBest: rec ? rec.isAllTimeBest : false,
      isDayBest: rec ? rec.isDayBest : false,
      isWeekBest: rec ? rec.isWeekBest : false,
      isMonthBest: rec ? rec.isMonthBest : false,
      oldBestTimeMs: rec ? rec.oldAllTimeBest : 0,
      oldDayBest: rec ? rec.oldDayBest : 0,
      newBestTimeMs: this.bestTimeMs,
      attempt: rec ? rec.item : null,
    };
  }

  _runEndTokens(riskCount, runDistance) {
    let t = 0;
    const re = Math.max(1, this.e.riskRewardEvery ?? 5);
    const rt = this.e.riskRewardTokens ?? 1;
    if (rt > 0) t += Math.floor(riskCount / re) * rt;
    const rne = Math.max(1, this.e.runRewardEvery ?? 200);
    const rnt = this.e.runRewardTokens ?? 1;
    if (rnt > 0) t += Math.floor(runDistance / rne) * rnt;
    return t;
  }
}
