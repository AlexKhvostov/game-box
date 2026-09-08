import { calcScore } from './util.js';
import { telegram } from './telegram.js';
import { starsShopFromEconomy } from './shop-catalog.js';

/** Local economy — mirrors lib/data/economy_store.dart (offline Telegram). */

const KEY = 'untouch_tg_economy';
const COMM_KEY = 'untouch_community_scores_v2';
const REF_INIT_KEY = 'untouch_ref_initdata';

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

function scoreDayLocal(ms = Date.now()) {
  const d = new Date(ms);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function playerKey(s) {
  if (s?.userId != null && String(s.userId) !== '') return `id_${s.userId}`;
  if (s?.username) return `u_${String(s.username).toLowerCase()}`;
  return `name_${s?.playerName || 'Игрок'}`;
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
    this.plusUntilMs = 0;
    this.appliedStarsTokens = 0;
    this.customNickname = null;
    this.hideTelegramUsername = false;
    this.musicEnabled = true;
    this.hapticEnabled = true;
    this.lightTheme = false;
    this.recentAttempts = [];
    this.communityScores = [];
    this.invitedFriends = [];
    this.writeAccessGranted = false;
    this._fresh = true;
    this._load();
    this._forgetCachedCommunity();
    this.syncCommunityScores();
    if (this._fresh && e.installBonusAutoClaim !== false) {
      this._claimInstallBonus();
    }
  }

  _forgetCachedCommunity() {
    this.communityScores = [];
    try {
      localStorage.removeItem(COMM_KEY);
      localStorage.removeItem('untouch_community_scores_v1');
    } catch (e) {
      // ignore quota / private mode
    }
  }

  _authPayload(extra = {}) {
    return {
      ...extra,
      initData: extra.initData || telegram.initData || '',
    };
  }

  _rememberRefInitData(initData) {
    if (!initData) return;
    try {
      localStorage.setItem(REF_INIT_KEY, initData);
    } catch (_) {}
  }

  _readRefInitData() {
    try {
      return localStorage.getItem(REF_INIT_KEY) || '';
    } catch (_) {
      return '';
    }
  }

  _clearRefInitData() {
    try {
      localStorage.removeItem(REF_INIT_KEY);
    } catch (_) {}
  }

  _initDataForSocial() {
    const current = telegram.initData || '';
    if (telegram.startParam && current) {
      this._rememberRefInitData(current);
      return current;
    }
    return this._readRefInitData() || current;
  }

  _authHeaders() {
    return { 'Content-Type': 'application/json' };
  }

  _isMeScore(row) {
    const myId = telegram.user?.id != null ? String(telegram.user.id) : '';
    if (myId && row?.userId != null && String(row.userId) === myId) return true;
    if (row?.isMe) return true;
    return false;
  }

  _applyRemoteScores(remoteScores) {
    const list = Array.isArray(remoteScores) ? remoteScores : [];
    this.communityScores = list
      .filter((r) => r && r.timeMs > 0 && !String(r.id || '').startsWith('seed_'))
      .map((r) => {
        const row = { ...r };
        if (row.score == null) {
          row.score = calcScore(row.timeMs, row.runDistance, row.riskCount);
        }
        if (!row.scoreDay) row.scoreDay = scoreDayLocal(row.createdAt);
        row.isMe = this._isMeScore(row);
        return row;
      });
    this.communityScores.sort((a, b) => b.timeMs - a.timeMs);
  }

  async syncCommunityScores(onUpdated = null) {
    await this._uploadLocalDayBest();
    try {
      const ctrl = typeof AbortController !== 'undefined' ? new AbortController() : null;
      const timeout = ctrl ? setTimeout(() => ctrl.abort(), 8000) : null;
      const res = await fetch('api/scores.php', { signal: ctrl?.signal });
      if (timeout) clearTimeout(timeout);
      const data = await res.json().catch(() => null);
      if (data && Array.isArray(data.scores)) {
        this._applyRemoteScores(data.scores);
      }
    } catch (e) {
      console.warn('syncCommunityScores', e);
    }
    if (typeof onUpdated === 'function') onUpdated();
  }

  _bestAttemptSince(startMs) {
    let best = null;
    for (const a of this.recentAttempts) {
      if ((a.createdAt || 0) < startMs) continue;
      if (!best || a.timeMs > best.timeMs) best = a;
    }
    return best;
  }

  _attemptToScorePayload(att) {
    return {
      playerName: att.playerName || this.effectivePlayerName,
      username: this.hideTelegramUsername ? null : (att.username || this.effectiveUsername),
      hideTelegram: this.hideTelegramUsername,
      firstName: att.firstName || telegram.user?.first_name || null,
      lastName: att.lastName || telegram.user?.last_name || null,
      photoUrl: att.photoUrl || telegram.userPhotoUrl || null,
      userId: att.userId || (telegram.user?.id != null ? String(telegram.user.id) : null),
      timeMs: att.timeMs,
      runDistance: Math.round(att.runDistance || 0),
      riskCount: att.riskCount || 0,
      score: att.score,
      hadJump: Boolean(att.hadJump),
      hadHelmet: Boolean(att.hadHelmet),
      createdAt: att.createdAt || Date.now(),
    };
  }

  async _uploadLocalDayBest() {
    if (!telegram.initData) return false;
    const best = this._bestAttemptSince(getPeriodStartMs('day'));
    if (!best || best.timeMs <= 0) return false;
    return this._postScoreToServer(this._attemptToScorePayload(best));
  }

  async _postScoreToServer(payload) {
    try {
      const res = await fetch('api/scores.php', {
        method: 'POST',
        headers: this._authHeaders(),
        body: JSON.stringify(this._authPayload(payload)),
      });
      const text = await res.text();
      let data = null;
      try {
        data = text ? JSON.parse(text) : null;
      } catch (e) {
        console.warn('save_score: not JSON', res.status, text?.slice(0, 120));
        return false;
      }
      if (!res.ok || !data || data.ok === false) {
        console.warn('save_score failed', (data && data.error) || res.status);
        return false;
      }
      if (Array.isArray(data.scores)) this._applyRemoteScores(data.scores);
      return true;
    } catch (e) {
      console.warn('save_score', e);
      return false;
    }
  }

  async _postProfileToServer(payload) {
    const res = await fetch('api/scores.php', {
      method: 'POST',
      headers: this._authHeaders(),
      body: JSON.stringify(this._authPayload({
        action: 'update_profile',
        ...payload,
      })),
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
      this._applyRemoteScores(data.scores);
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
      if (Array.isArray(d.recentAttempts)) this.recentAttempts = d.recentAttempts;
      // Старые попытки с пробегом в метрах больше не показываем
      if (d.attemptsUnit !== 'steps') {
        this.recentAttempts = [];
        this.bestTimeMs = 0;
      }
      if (typeof d.jumpRentalUntil === 'number') this.jumpRentalUntil = d.jumpRentalUntil;
      if (typeof d.helmetRentalUntil === 'number') this.helmetRentalUntil = d.helmetRentalUntil;
      if (typeof d.dailyStreak === 'number') this.dailyStreak = d.dailyStreak;
      if (typeof d.lastDailyClaimMs === 'number') this.lastDailyClaimMs = d.lastDailyClaimMs;
      if (typeof d.lastTimedBonusClaimMs === 'number') this.lastTimedBonusClaimMs = d.lastTimedBonusClaimMs;
      if (typeof d.lastWatchAdClaimMs === 'number') this.lastWatchAdClaimMs = d.lastWatchAdClaimMs;
      if (Array.isArray(d.claimedEarnIds)) this.claimedEarnIds = new Set(d.claimedEarnIds);
      if (Array.isArray(d.unlockedEarnIds)) this.unlockedEarnIds = new Set(d.unlockedEarnIds);
      if (typeof d.appliedStarsTokens === 'number') this.appliedStarsTokens = d.appliedStarsTokens;
      if (typeof d.plusUntilMs === 'number') this.plusUntilMs = d.plusUntilMs;
      if (typeof d.customNickname === 'string') this.customNickname = d.customNickname;
      if (typeof d.hideTelegramUsername === 'boolean') this.hideTelegramUsername = d.hideTelegramUsername;
      if (typeof d.musicEnabled === 'boolean') this.musicEnabled = d.musicEnabled;
      if (typeof d.hapticEnabled === 'boolean') this.hapticEnabled = d.hapticEnabled;
      if (typeof d.lightTheme === 'boolean') this.lightTheme = d.lightTheme;
      this._refreshPremiumFromUntil();
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
          plusUntilMs: this.plusUntilMs,
          appliedStarsTokens: this.appliedStarsTokens,
          customNickname: this.customNickname,
          hideTelegramUsername: this.hideTelegramUsername,
          musicEnabled: this.musicEnabled,
          hapticEnabled: this.hapticEnabled,
          lightTheme: this.lightTheme,
          recentAttempts: this.recentAttempts.slice(0, 50),
          attemptsUnit: 'steps',
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

  updateDevicePrefs({ musicEnabled, hapticEnabled, lightTheme } = {}) {
    if (typeof musicEnabled === 'boolean') this.musicEnabled = musicEnabled;
    if (typeof hapticEnabled === 'boolean') this.hapticEnabled = hapticEnabled;
    if (typeof lightTheme === 'boolean') this.lightTheme = lightTheme;
    this._save();
    return {
      musicEnabled: this.musicEnabled,
      hapticEnabled: this.hapticEnabled,
      lightTheme: this.lightTheme,
    };
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

    // Обновляем ник в своих локальных попытках
    for (const att of this.recentAttempts) {
      if (att.isMe) {
        att.playerName = this.effectivePlayerName;
        att.username = this.effectiveUsername;
        att.hideTelegram = this.hideTelegramUsername;
      }
    }

    const myId = telegram?.user?.id ? String(telegram.user.id) : null;
    const rawUsername = telegram?.user?.username ? `@${telegram.user.username.replace(/^@/, '')}` : null;
    const myUsername = this.effectiveUsername;

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

  _refreshPremiumFromUntil() {
    this.hasPremium = this.plusUntilMs > Date.now();
    this.premiumNextChargeMs = this.hasPremium ? this.plusUntilMs : 0;
  }

  applyWallet(wallet) {
    if (!wallet || typeof wallet !== 'object') return { crystalsDelta: 0, plusActivated: false };
    const serverTokens = Math.max(0, Number(wallet.tokens) || 0);
    const plusUntil = Math.max(0, Number(wallet.plusUntilMs) || 0);
    const crystalsDelta = Math.max(0, serverTokens - this.appliedStarsTokens);
    if (crystalsDelta > 0) {
      this.tokens += crystalsDelta;
      this.appliedStarsTokens = serverTokens;
    } else if (serverTokens > 0 && this.appliedStarsTokens !== serverTokens) {
      this.appliedStarsTokens = serverTokens;
    }
    const wasPremium = this.hasPremium;
    this.plusUntilMs = plusUntil;
    this._refreshPremiumFromUntil();
    this._save();
    return {
      crystalsDelta,
      plusActivated: this.hasPremium && !wasPremium,
    };
  }

  async syncWallet() {
    if (!telegram.initData) return null;
    try {
      const res = await fetch('api/payments.php', {
        method: 'POST',
        headers: this._authHeaders(),
        body: JSON.stringify(this._authPayload({ action: 'wallet' })),
      });
      if (!res.ok) return null;
      const data = await res.json();
      if (!data || !data.ok || !data.wallet) return null;
      return this.applyWallet(data.wallet);
    } catch (e) {
      console.warn('syncWallet', e);
      return null;
    }
  }

  _applySocial(data) {
    if (!data || typeof data !== 'object') return;
    this.invitedFriends = Array.isArray(data.invited) ? data.invited : [];
    this.writeAccessGranted = Boolean(data.writeAccess);
  }

  get inviteRewardPerFriend() {
    const action = this.earnActions.find((a) => a.id === 'invite_friend');
    const n = Number(action?.reward);
    return Number.isFinite(n) && n >= 20 ? n : 20;
  }

  _applyInviteRewards(newlyRewarded) {
    const count = Math.max(0, Number(newlyRewarded) || 0);
    if (count < 1) return null;
    const total = count * this.inviteRewardPerFriend;
    this.tokens += total;
    this._save();
    return { crystals: total, friends: count };
  }

  async syncSocial() {
    const initData = this._initDataForSocial();
    if (!initData) return null;
    try {
      const res = await fetch('api/scores.php', {
        method: 'POST',
        headers: this._authHeaders(),
        body: JSON.stringify(this._authPayload({
          action: 'sync_social',
          initData,
          startParam: telegram.startParam || '',
        })),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok || !data || data.ok === false) return null;
      this._applySocial(data);
      if (data.bound || data.bindReason === 'already') {
        this._clearRefInitData();
        telegram.clearStoredRef();
      }
      const paid = this._applyInviteRewards(data.newlyRewarded);
      return {
        ...data,
        inviteReward: paid ? paid.crystals : null,
        inviteRewardFriends: paid ? paid.friends : 0,
      };
    } catch (e) {
      console.warn('syncSocial', e);
      return null;
    }
  }

  async prepareInviteShare({ timeSec = '', bonus = 40 } = {}) {
    if (!telegram.initData) return null;
    try {
      const res = await fetch('api/scores.php', {
        method: 'POST',
        headers: this._authHeaders(),
        body: JSON.stringify(this._authPayload({
          action: 'prepare_invite',
          timeSec,
          bonus,
        })),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok || !data || data.ok === false) return null;
      return data;
    } catch (e) {
      console.warn('prepareInviteShare', e);
      return null;
    }
  }

  async grantWriteAccess() {
    if (telegram.initData) {
      try {
        const res = await fetch('api/scores.php', {
          method: 'POST',
          headers: this._authHeaders(),
          body: JSON.stringify(this._authPayload({ action: 'grant_write_access' })),
        });
        const data = await res.json().catch(() => null);
        if (data && data.ok) this._applySocial(data);
      } catch (e) {
        console.warn('grantWriteAccess', e);
      }
    }
    this.writeAccessGranted = true;
    if (this.claimedEarnIds.has('enable_notifications')) {
      return { already: true, reward: null };
    }
    return { already: false, reward: this.claimEarnAction('enable_notifications') };
  }

  async waitForWalletUpdate({ expectCrystals = 0, expectPlus = false } = {}) {
    const startTokens = this.appliedStarsTokens;
    const startPlus = this.plusUntilMs;
    for (let i = 0; i < 10; i++) {
      const applied = await this.syncWallet();
      if (!applied) {
        await new Promise((r) => setTimeout(r, 700));
        continue;
      }
      const crystalsOk = !expectCrystals || this.appliedStarsTokens >= startTokens + expectCrystals;
      const plusOk = !expectPlus || this.plusUntilMs > startPlus;
      if (crystalsOk && plusOk) return applied;
      await new Promise((r) => setTimeout(r, 700));
    }
    return this.syncWallet();
  }

  async createStarsInvoice(productId) {
    const res = await fetch('api/payments.php', {
      method: 'POST',
      headers: this._authHeaders(),
      body: JSON.stringify(this._authPayload({
        action: 'create_invoice',
        productId,
      })),
    });
    const text = await res.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch (e) {
      const snippet = (text || '').replace(/\s+/g, ' ').slice(0, 120);
      throw new Error(`Сервер HTTP ${res.status}${snippet ? ': ' + snippet : ' (пустой ответ)'}`);
    }
    if (!res.ok || !data || data.ok === false || !data.invoiceUrl) {
      throw new Error((data && data.error) || `Ошибка счёта HTTP ${res.status}`);
    }
    return data;
  }

  activatePremiumPreview() {
    // Preview отключён: Plus только через Stars.
  }

  cancelPremium() {
    // Отмена Stars-подписки — в Telegram, не локально.
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

  get starsShop() {
    return starsShopFromEconomy(this.e);
  }

  get starPacks() {
    return this.starsShop.packs;
  }

  get plusProduct() {
    return this.starsShop.plus;
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

  get watchAdUnlockProgress() {
    if (this.canClaimWatchAd) return 1;
    if (!this.lastWatchAdClaimMs) return 1;
    const total = this._watchAdCooldownMs;
    if (total <= 0) return 1;
    const elapsed = Date.now() - this.lastWatchAdClaimMs;
    return Math.max(0, Math.min(1, elapsed / total));
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

  get avatarCheatEnabled() {
    const v = this.e.avatarCheatEnabled;
    return v === true || v === 1 || v === 'true';
  }

  get avatarCheatTokens() {
    const n = Number(this.e.avatarCheatTokens);
    if (!Number.isFinite(n) || n <= 0) return 10;
    return Math.min(9999, Math.floor(n));
  }

  grantAvatarCheat() {
    if (!this.avatarCheatEnabled) return null;
    const amount = this.avatarCheatTokens;
    this.tokens += amount;
    this._save();
    return amount;
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
    const today = scoreDayLocal();
    const inPeriod = (a) => {
      if (period === 'day' && a.scoreDay) return a.scoreDay === today;
      return (a.createdAt || 0) >= start;
    };
    const pool = this.communityScores.filter(inPeriod).map((a) => ({
      ...a,
      isMe: this._isMeScore(a),
    }));

    const myBest = this._bestAttemptSince(start);
    if (myBest && inPeriod({ ...myBest, scoreDay: scoreDayLocal(myBest.createdAt) })) {
      const key = playerKey(myBest);
      if (!pool.some((s) => playerKey(s) === key)) {
        pool.push({ ...myBest, isMe: true, scoreDay: scoreDayLocal(myBest.createdAt) });
      }
    }

    pool.sort((a, b) => b.timeMs - a.timeMs);

    const seenUsers = new Set();
    const uniqueByPlayer = [];
    for (const att of pool) {
      const userKey = playerKey(att);
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

    if (isDayBest || oldDayBest <= 0) {
      this._postScoreToServer(this._attemptToScorePayload(item));
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
