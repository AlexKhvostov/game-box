import { calcScore, clamp, easeOut, fmtScore, fmtTimeMs, fmtTimerChip, lerpColor, resolveSurfaceColor, runStepsFromPx, visualWallInset } from './util.js';
import { GameWorld } from './game-world.js';
import { FieldRenderer } from './renderer.js';
import { ImpactBurst } from './impact-burst.js';
import { GameAudio } from './audio.js';
import { EconomyStore } from './economy.js';
import { telegram } from './telegram.js';
import { SheetUI } from './sheets.js';
import { showGameToast } from './game-toast.js';
import { showSystemNotice } from './sys-toast.js';
import { restingCubeImg } from './game-icons.js';
import { RU } from './strings-ru.js';
import { remoteConfig } from './remote-config.js';
import { bindGameTips, hideGameTip } from './tip-pop.js';
import { initMetrika, metrikaGoal } from './metrika.js';

const Phase = { idle: 'idle', playing: 'playing', impact: 'impact', result: 'result' };

class UntouchApp {
  constructor() {
    this.config = null;
    this.economy = null;
    this.audio = null;
    this.world = null;
    this.renderer = null;
    this.phase = Phase.idle;
    this.fieldSide = 380;
    this.frame = 0;
    this.lastTs = 0;
    this.aliveMs = 0;
    this.rampT = 0;
    this.resultMs = 0;
    this.resultRun = 0;
    this.resultRisk = 0;
    this.resultScore = 0;
    this.impacts = [];
    this.impactHoldSec = 0;
    this.runHelmetActive = false;
    this.helmetInvulnLeft = 0;
    this.startInvulnLeft = 0;
    this._hadStartInvuln = false;
    this._hbStrongSec = 0;
    this.sfxRiskCount = 0;
    this.idleSpeedWobble = 0;
    this.idleSpeedWobbleTarget = 0;
    this.pointers = new Map();
    this.primaryPointer = null;
    this.primaryLastPos = null;
    this.hintPulse = 0;
    this.sheets = null;
    this.lastRunTokens = 0;

    this.canvas = document.getElementById('game-canvas');
    this.ctx = this.canvas.getContext('2d', { alpha: false, desynchronized: true })
      || this.canvas.getContext('2d', { alpha: false });
    if (this.ctx) this.ctx.imageSmoothingEnabled = false;
    this._hudAcc = 0;
    this.$ = (id) => document.getElementById(id);
  }

  async init() {
    telegram.boot();
    telegram.onResize = () => this._resize();
    this.config = await remoteConfig.loadConfig();
    initMetrika(this.config.yandexMetrikaId);
    this.economy = new EconomyStore(this.config);
    await this.economy.syncWallet();
    let social = await this.economy.syncSocial();
    if (telegram.startParam && social && !social.bound && social.bindReason !== 'already') {
      await new Promise((r) => setTimeout(r, 500));
      social = (await this.economy.syncSocial()) || social;
    }
    if (social?.inviteReward) {
      showGameToast({
        message: RU.earnInviteRewardToast(social.inviteReward, social.inviteRewardFriends || 1),
        accent: '#7EE0FF',
        flyTo: 'crystals',
      });
      this._updateHud();
    } else if (social?.bound) {
      showSystemNotice({ message: RU.earnInviteWelcome, accent: '#7EE0FF' });
      metrikaGoal('invite_bound');
    }
    this.audio = new GameAudio(this.config);
    this.renderer = new FieldRenderer(this.config.theme);
    this.sheets = new SheetUI(this);
    telegram.hapticEnabled = this.economy.hapticEnabled !== false;
    this.audio.userMusicEnabled = this.economy.musicEnabled !== false;
    telegram.applyUiTheme(this.economy.lightTheme === true);
    await this.audio.init();
    if (this.economy.musicEnabled !== false) {
      await this.audio.ensureMusic();
    }
    this._bindInput();
    this._bindHud();
    this._resize();
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) return;
      this.economy.syncSocial().then((social) => {
        if (!social?.inviteReward) return;
        showGameToast({
          message: RU.earnInviteRewardToast(social.inviteReward, social.inviteRewardFriends || 1),
          accent: '#7EE0FF',
          flyTo: 'crystals',
        });
        this._updateHud();
        if (this.sheets?._tab === 3) this.sheets._refreshSocialEarn();
      });
    });
    window.addEventListener('resize', () => this._resize());
    window.addEventListener('orientationchange', () => setTimeout(() => this._resize(), 100));
    this._resetWorld();
    this._updateHud();
    this._hideBootLoader();
    requestAnimationFrame((ts) => this._loop(ts));
  }

  _hideBootLoader() {
    const el = this.$('boot-loader');
    if (!el) return;
    el.classList.add('hidden');
    setTimeout(() => el.remove(), 280);
  }

  _resize() {
    telegram.syncInsets();

    // Если открыта шторка или фокус в текстовом поле (открылась клавиатура) — не трогаем игровой канвас и мир во время ввода
    if (this.sheets?.isOpen || (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA'))) {
      return;
    }

    const pad = telegram.viewPadding;
    const w = window.innerWidth;
    const h = window.innerHeight;

    const hudH = 48;
    const infoBarH = 46;
    const touchMin = 48;
    const gaps = 16;

    const availW = w - pad.left - pad.right - 32;
    const availH = h - pad.top - pad.bottom - hudH - infoBarH - touchMin - gaps;

    const maxSide = this.config?.field?.maxSide || 380;
    const newSide = Math.max(200, Math.floor(Math.min(availW, availH, maxSide)));
    const sizeChanged = newSide !== this.fieldSide;
    this.fieldSide = newSide;

    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const targetPx = Math.round(this.fieldSide * dpr);
    if (this.canvas.width !== targetPx || this.canvas.height !== targetPx) {
      this.canvas.width = targetPx;
      this.canvas.height = targetPx;
    }
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.ctx.imageSmoothingEnabled = false;

    const inset = visualWallInset(this.config?.field?.borderWidth ?? 3);
    if (this.world) {
      this.world.field = { width: this.fieldSide, height: this.fieldSide };
      this.world.wallInset = inset;
      if (sizeChanged && this.phase !== Phase.playing) {
        this.world.resetLayout();
      }
    }
    document.documentElement.style.setProperty('--field-side', `${this.fieldSide}px`);
  }

  _resetWorld() {
    const inset = visualWallInset(this.config.field.borderWidth);
    this.world = new GameWorld({
      config: this.config,
      fieldW: this.fieldSide,
      fieldH: this.fieldSide,
      wallInset: inset,
    });
    this.world.resetLayout();
  }

  _bindInput() {
    const zone = this.$('touch-zone');
    this._touchZone = zone;
    zone.addEventListener('pointerdown', (e) => this._onPointerDown(e), { passive: false });
    zone.addEventListener('pointermove', (e) => this._onPointerMove(e), { passive: true });
    zone.addEventListener('pointerup', (e) => this._onPointerUp(e), { passive: true });
    zone.addEventListener('pointercancel', (e) => this._onPointerUp(e), { passive: true });
  }

  _bindHud() {
    setInterval(() => this._updateHud(), 1000);
    document.querySelector('.hud-chip.lives')?.addEventListener('click', (ev) => {
      ev.stopPropagation();
      this.sheets.open('lives');
    });
    document.querySelector('.hud-chip.crystals')?.addEventListener('click', (ev) => {
      ev.stopPropagation();
      this.sheets.open('crystals');
    });
    document.querySelector('.hud-chip.record')?.addEventListener('click', (ev) => {
      ev.stopPropagation();
      this.sheets.open('leaderboard');
    });
    document.getElementById('hud-profile-btn')?.addEventListener('click', (ev) => {
      ev.stopPropagation();
      telegram.haptic('impact', 'light');
      this.sheets.open('profile');
    });
    document.getElementById('jump-chip')?.addEventListener('click', (ev) => {
      ev.stopPropagation();
      this.sheets.open('crystals', { tab: 2 });
    });
    document.querySelector('.rent-chip.helmet')?.addEventListener('click', (ev) => {
      ev.stopPropagation();
      this.sheets.open('crystals', { tab: 2 });
    });
  }

  showToast(message, opts = {}) {
    if (typeof opts === 'string') {
      showSystemNotice({ message, accent: opts });
      return;
    }
    const flyTo = opts.flyTo ?? 'none';
    // Награды (кристаллы/жизни) — летающая вспышка; всё остальное — системная плашка сверху
    if (flyTo === 'crystals' || flyTo === 'lives') {
      showGameToast({
        message,
        accent: opts.accent ?? '#3DDC97',
        flyTo,
        festive: opts.festive ?? false,
        icon: opts.icon,
      });
      return;
    }
    showSystemNotice({
      message,
      accent: opts.accent ?? '#7EE0FF',
      holdMs: opts.holdMs ?? 1000,
    });
  }

  _onPointerDown(e) {
    if (e.target.closest('.hud-chip, .rent-chip, .hud-btn, .hud-profile-btn, .modal, .sheet-root')) return;
    e.preventDefault();
    this.audio.resume();
    this._touchZone?.setPointerCapture?.(e.pointerId);

    if (this.phase === Phase.idle) {
      this.pointers.clear();
      this.pointers.set(e.pointerId, true);
      this.primaryPointer = e.pointerId;
      this._rememberPointer(e);
      if (!this.economy.canPlay) {
        this.pointers.clear();
        this.primaryPointer = null;
        telegram.haptic('impact', 'light');
        this.sheets.open('lives');
        return;
      }
      this._startGame();
      return;
    }
    if (this.phase !== Phase.playing) return;

    if (this.pointers.size === 0) {
      this.pointers.set(e.pointerId, true);
      this.primaryPointer = e.pointerId;
      this._rememberPointer(e);
      return;
    }
    this.pointers.set(e.pointerId, true);
    this._tryJump();
  }

  _rememberPointer(e) {
    this.primaryLastPos = { x: e.clientX, y: e.clientY };
  }

  _onPointerMove(e) {
    if (this.phase !== Phase.playing || !this.world) return;
    if (e.pointerId !== this.primaryPointer) return;
    const coalesced = typeof e.getCoalescedEvents === 'function' ? e.getCoalescedEvents() : null;
    const batch = coalesced && coalesced.length ? coalesced : [e];
    let moved = false;
    for (let i = 0; i < batch.length; i++) {
      const ev = batch[i];
      const x = ev.clientX;
      const y = ev.clientY;
      if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
      const last = this.primaryLastPos;
      this.primaryLastPos = { x, y };
      if (!last) continue;
      const dx = x - last.x;
      const dy = y - last.y;
      if (dx === 0 && dy === 0) continue;
      this.world.movePlayerBy({ dx, dy });
      moved = true;
    }
    if (!moved) return;
    if (this.world.playerHitsBorder()) {
      if (!this.world.wallsKillPlayer()) this.world.clampPlayerToField();
      else if (!this._isInvulnerable()) {
        this._triggerImpact(true);
        return;
      }
    }
    if (this._isInvulnerable()) return;
    if (this.world.playerHitsEnemy()) this._triggerImpact(false);
  }

  _onPointerUp(e) {
    this.pointers.delete(e.pointerId);
    if (e.pointerId === this.primaryPointer) {
      this.primaryPointer = this.pointers.size ? this.pointers.keys().next().value : null;
      this.primaryLastPos = null;
    }
  }

  _startGame() {
    if (!this.economy.canPlay) return;
    this.economy.spendLife();
    if (this.world && !this.world.idleEnemiesMove()) {
      this.world.snapEnemiesToHome();
    }
    this.phase = Phase.playing;
    this.aliveMs = 0;
    this.rampT = 0;
    this.sfxRiskCount = 0;
    this.runHadJump = this.config.game.jumpEnabled && this.economy.hasJumpRental();
    this.runHadHelmet = this.config.game.helmetEnabled && this.economy.hasHelmetRental();
    this.runHelmetActive = this.runHadHelmet;
    this.helmetInvulnLeft = 0;
    this.startInvulnLeft = this._startInvulnSec();
    this._hadStartInvuln = this.startInvulnLeft > 0;
    this._hbStrongSec = 0;
    this.impacts = [];
    this.audio.gameStart();
    metrikaGoal('game_start');
    telegram.haptic('impact', 'medium');
    this._hudAcc = 999;
    this._updateOverlay();
    this._updateHud();
  }

  _tryJump() {
    if (!this.config.game.jumpEnabled || !this.world) return;
    if (!this.economy.hasJumpRental()) {
      this.$('jump-chip')?.classList.add('warn-flash');
      setTimeout(() => this.$('jump-chip')?.classList.remove('warn-flash'), 660);
      return;
    }
    this.runHadJump = true;
    if (this.world.tryJump()) {
      this.audio.jump();
    }
  }

  _startInvulnSec() {
    const n = Number(this.config?.game?.startInvulnSec);
    return Number.isFinite(n) ? clamp(n, 0, 5) : 1;
  }

  _isInvulnerable() {
    return this.startInvulnLeft > 0 || this.helmetInvulnLeft > 0;
  }

  _heartbeatEnabled() {
    const g = this.config?.game || {};
    if (g.timerHaptic === false || g.heartbeatHaptic === false) return false;
    return this.economy?.hapticEnabled !== false;
  }

  _timerHapticStyle(sec) {
    const g = this.config?.game || {};
    const usual = String(g.timerHapticStyle || 'warning');
    if (sec % 10 === 0) return String(g.timerHapticStyle10 || usual);
    if (sec % 5 === 0) return String(g.timerHapticStyle5 || usual);
    return usual;
  }

  _pulseTimerSecond(sec) {
    if (this.phase !== Phase.playing) return;
    if (!this._heartbeatEnabled()) return;
    const n = Math.floor(Number(sec) || 0);
    if (n < 1 || n === this._hbStrongSec) return;
    this._hbStrongSec = n;
    telegram.timerPulse(this._timerHapticStyle(n));
  }

  _tickPlayHaptics() {
    this._pulseTimerSecond(Math.floor(this.aliveMs / 1000));
  }

  _triggerImpact(againstWall) {
    if (this._isInvulnerable()) return;
    if (this.runHelmetActive) {
      this.runHelmetActive = false;
      this.helmetInvulnLeft = this.config.game.helmetInvulnSec;
      this.audio.helmetBreak();
      return;
    }
    this.phase = Phase.impact;
    this.impactHoldSec = 0;
    const origin = this._impactOrigin(againstWall);
    this.impacts.push(
      ImpactBurst.spawn({
        origin,
        accent: this.config.theme.primary,
        danger: this.config.theme.danger,
        againstWall,
      }),
    );
    if (againstWall) this.audio.heroWall();
    else this.audio.heroMob();
    telegram.haptic('notification', 'error');
  }

  _impactOrigin(againstWall) {
    const w = this.world;
    const cx = w.player.dx + w.playerSize / 2;
    const cy = w.player.dy + w.playerSize / 2;
    if (!againstWall) {
      for (const e of w.enemies) {
        const pr = { left: w.player.dx, top: w.player.dy, width: w.playerSize, height: w.playerSize };
        if (this._overlaps(pr, e.rect)) {
          return {
            dx: (cx + e.rect.left + e.rect.width / 2) / 2,
            dy: (cy + e.rect.top + e.rect.height / 2) / 2,
          };
        }
      }
      return { dx: cx, dy: cy };
    }
    const fw = w.field.width;
    const fh = w.field.height;
    const distL = cx, distR = fw - cx, distT = cy, distB = fh - cy;
    const m = Math.min(distL, distR, distT, distB);
    if (m === distL) return { dx: 0, dy: cy };
    if (m === distR) return { dx: fw, dy: cy };
    if (m === distT) return { dx: cx, dy: 0 };
    return { dx: cx, dy: fh };
  }

  _overlaps(a, b) {
    return !(a.left + a.width <= b.left || b.left + b.width <= a.left ||
      a.top + a.height <= b.top || b.top + b.height <= a.top);
  }

  _finishImpact() {
    this.phase = Phase.result;
    this.resultMs = this.aliveMs;
    this.resultRun = Math.round(runStepsFromPx(this.world.playerDistance, this.world.playerSize));
    this.resultRisk = this.world.nearMissCount;
    this.resultScore = calcScore(this.resultMs, this.resultRun, this.resultRisk);
    const playerInfo = {
      ...telegram.playerInfo,
      playerName: this.economy.effectivePlayerName,
      username: this.economy.effectiveUsername,
      hideTelegram: this.economy.hideTelegramUsername,
      hadJump: Boolean(this.runHadJump),
      hadHelmet: Boolean(this.runHadHelmet),
      score: this.resultScore,
    };
    const runResult = this.economy.finishRun(
      this.resultMs,
      this.resultRisk,
      this.resultRun,
      playerInfo,
    );
    this.lastRunResult = runResult;
    this.lastRunTokens = runResult?.gainedTokens ?? 0;
    metrikaGoal('game_finish');
    this._showResult();
  }

  _resetToIdle() {
    clearTimeout(this._crystalFlyTimer);
    this.phase = Phase.idle;
    this.impacts = [];
    this.aliveMs = 0;
    this.rampT = 0;
    this.resultScore = 0;
    const topScore = this.$('top-score');
    if (topScore) topScore.textContent = '0';
    this._resetWorld();
    this._updateOverlay();
    this._updateHud();
    this.$('result-overlay').hidden = true;
    hideGameTip();
  }

  _showResult() {
    const el = this.$('result-overlay');
    const inner = el?.querySelector('.result-inner');
    if (inner) {
      inner.style.animation = 'none';
      void inner.offsetHeight;
      inner.style.animation = '';
    }
    el.hidden = false;

    const timeSec = (this.resultMs / 1000).toFixed(3);
    const timeSecShort = (this.resultMs / 1000).toFixed(2);
    this.$('result-time').textContent = timeSec;

    const scoreEl = this.$('result-score');
    if (scoreEl) scoreEl.textContent = fmtScore(this.resultScore);
    const scoreTag = el.querySelector('.result-score-tag');
    if (scoreTag) scoreTag.textContent = RU.resultScoreTag;

    const rr = this.lastRunResult;
    if (rr?.isAllTimeBest && (rr?.oldBestTimeMs ?? 0) > 0) {
      this.$('result-rank').textContent = '🎉 НОВЫЙ РЕКОРД!';
      this.showToast(RU.recordBeatToast(timeSecShort), {
        accent: '#3DDC97',
        festive: true,
      });
      telegram.haptic('notification', 'success');
    } else if (rr?.isDayBest && (rr?.oldDayBest ?? 0) > 0) {
      this.$('result-rank').textContent = '⭐ ЛУЧШИЙ ЗА ДЕНЬ!';
      this.showToast(RU.recordDayToast(timeSecShort), {
        accent: '#7EE0FF',
        festive: true,
      });
      telegram.haptic('notification', 'success');
    } else if (rr?.isAllTimeBest) {
      this.$('result-rank').textContent = '🏆 ПЕРВЫЙ РЕКОРД!';
      this.showToast(`🏆 Рекорд сохранён: ${timeSecShort} с!`, { accent: '#3DDC97' });
    } else {
      this.$('result-rank').textContent = RU.newScore;
    }

    const ec = this.config.economy;
    const riskEvery = Math.max(1, ec.riskRewardEvery ?? 5);
    const riskReward = ec.riskRewardTokens ?? 1;
    const runEvery = Math.max(1, ec.runRewardEvery ?? 200);
    const runReward = ec.runRewardTokens ?? 1;
    const runDist = Math.round(this.resultRun);
    const riskEarned = riskReward > 0 ? Math.floor(this.resultRisk / riskEvery) * riskReward : 0;
    const runEarned = runReward > 0 ? Math.floor(runDist / runEvery) * runReward : 0;

    this.$('result-risk').textContent = String(this.resultRisk);
    this.$('result-run').textContent = String(runDist);

    const riskRate = this.$('result-risk-rate');
    const runRate = this.$('result-run-rate');
    if (riskRate) {
      riskRate.innerHTML =
        riskReward > 0
          ? `${riskEvery}=<img src="icons/crystal.svg" alt="" width="9" height="9">${riskReward > 1 ? riskReward : ''}`
          : '';
    }
    if (runRate) {
      runRate.innerHTML =
        runReward > 0
          ? `${runEvery}=<img src="icons/crystal.svg" alt="" width="9" height="9">${runReward > 1 ? runReward : ''}`
          : '';
    }

    this._setResultEarn('result-risk-earn', riskEarned);
    this._setResultEarn('result-run-earn', runEarned);

    this._bindResultStatTips({
      riskEvery,
      riskReward,
      runEvery,
      runReward,
    });

    this._scheduleResultCrystalFlights(this.lastRunTokens);
    this._updateOverlay();
  }

  _bindResultStatTips({ riskEvery, riskReward, runEvery, runReward }) {
    const riskBtn = this.$('result-stat-risk');
    const runBtn = this.$('result-stat-run');
    if (!riskBtn || !runBtn) return;
    bindGameTips(
      [
        {
          id: 'result-risk',
          el: riskBtn,
          accent: '#ffc107',
          body: RU.riskTipHow,
          foot: RU.riskTipConvert(riskEvery, riskReward > 0 ? riskReward : 1),
        },
        {
          id: 'result-run',
          el: runBtn,
          accent: '#7ee0ff',
          body: RU.runTipHow,
          foot: RU.runTipConvert(runEvery, runReward > 0 ? runReward : 1),
        },
      ],
      { haptic: () => telegram.haptic('impact', 'light') },
    );
  }

  _setResultEarn(id, amount) {
    const el = this.$(id);
    if (!el) return;
    if (amount > 0) {
      el.hidden = false;
      el.innerHTML = `<img src="icons/crystal.svg" alt="" width="11" height="11">+${amount}`;
    } else {
      el.hidden = true;
      el.textContent = '';
    }
  }

  _scheduleResultCrystalFlights(total) {
    if (total <= 0) return;
    let left = total;
    const fire = () => {
      if (left <= 0) return;
      showGameToast({
        message: RU.crystalsPlus(1),
        accent: '#7EE0FF',
        flyTo: 'crystals',
      });
      left -= 1;
      if (left > 0) this._crystalFlyTimer = setTimeout(fire, 360);
    };
    this._crystalFlyTimer = setTimeout(fire, 520);
  }

  _loop(ts) {
    if (!this.lastTs) this.lastTs = ts;
    const rawDt = ts - this.lastTs;
    this.lastTs = ts;
    if (rawDt > 0) this._tick(Math.min(50, rawDt) / 1000);
    this._draw();
    this.hintPulse = (Math.sin(ts / 800) + 1) / 2;
    this._hudAcc += rawDt;
    const hudEvery = this.phase === Phase.playing ? 33 : 80;
    if (this._hudAcc >= hudEvery) {
      this._hudAcc = 0;
      this._updateInfoBar();
    }
    requestAnimationFrame((t) => this._loop(t));
  }

  _tick(dt) {
    if (!this.world) return;
    this.frame++;

    if (this.phase === Phase.result) return;

    if (this.phase === Phase.impact) {
      this.impactHoldSec += dt;
      this.impacts = this.impacts.filter((b) => b.update(dt));
      if (this.impactHoldSec >= 0.42) this._finishImpact();
      return;
    }

    if (this.phase === Phase.idle) {
      const b = this.world.tickIdle(dt);
      if (b.wall > 0) this.audio.mobWall();
      if (b.enemy > 0) this.audio.mobCollide();
      this._tickIdleWobble(dt);
      return;
    }

    if (this.phase === Phase.playing) {
      const rampSec = Math.max(0.05, this.config.game.speedRampSeconds);
      const idleMult = this.world.idleEnemiesMove()
        ? this.config.game.idleSpeedMultiplier
        : 0;
      this.rampT = Math.min(rampSec, this.rampT + dt);
      const t = clamp(this.rampT / rampSec, 0, 1);
      const speedMult = idleMult + (1 - idleMult) * easeOut(t);

      this.aliveMs += dt * 1000;
      this.world.tickJump(dt);
      const b = this.world.tickPlay(dt, this.aliveMs / 1000, speedMult);
      if (b.wall > 0) this.audio.mobWall();
      if (b.enemy > 0) this.audio.mobCollide();
      this._sfxRiskIfNeeded();

      if (this.startInvulnLeft > 0) {
        this.startInvulnLeft = Math.max(0, this.startInvulnLeft - dt);
      }
      if (this.helmetInvulnLeft > 0) {
        this.helmetInvulnLeft = Math.max(0, this.helmetInvulnLeft - dt);
      }
      if (this.world.playerHitsBorder()) {
        if (!this.world.wallsKillPlayer()) this.world.clampPlayerToField();
        else if (!this._isInvulnerable()) {
          this._triggerImpact(true);
          return;
        }
      }
      if (!this._isInvulnerable() && this.world.playerHitsEnemy()) {
        this._triggerImpact(false);
        return;
      }
      this._tickPlayHaptics();

      if (this.impacts.length > 0) {
        this.impacts = this.impacts.filter((b) => b.update(dt));
      }
    }
  }

  _sfxRiskIfNeeded() {
    if (this.world.nearMissCount <= this.sfxRiskCount) return;
    this.sfxRiskCount = this.world.nearMissCount;
    this.audio.nearMiss();

    // Визуальный импульс счетчика очков при риске
    const pill = this.$('score-strip-pill');
    if (pill) {
      pill.classList.remove('score-bump');
      void pill.offsetWidth;
      pill.classList.add('score-bump');
    }
  }

  _tickIdleWobble(dt) {
    this.idleSpeedWobble += (this.idleSpeedWobbleTarget - this.idleSpeedWobble) * Math.min(1, dt * 2.8);
    if (Math.abs(this.idleSpeedWobble - this.idleSpeedWobbleTarget) < 0.35) {
      this.idleSpeedWobbleTarget = Math.random() * 16 - 8;
    }
  }

  _activeTheme() {
    const base = this.config?.theme || {};
    if (!this.economy?.lightTheme) return base;
    return {
      ...base,
      bg: '#D7E2EA',
      surface: '#F7FBFD',
      text: '#102028',
      muted: '#3D5160',
      cyan: '#0A6A88',
    };
  }

  _draw() {
    if (!this.world) return;
    const theme = this._activeTheme();
    const light = this.economy?.lightTheme === true;
    const fieldColor = light
      ? '#F7FBFD'
      : resolveSurfaceColor(theme.surface, this.config.field);
    const wallsKill = this.world
      ? this.world.wallsKillPlayer()
      : this.config?.game?.wallsKillPlayer !== false;
    this.renderer.paint(this.ctx, this.world, {
      fieldSize: { width: this.fieldSide, height: this.fieldSide },
      fieldColor,
      accent: theme.primary,
      danger: theme.danger,
      borderColor: wallsKill ? theme.danger : theme.primary,
      borderWidth: this.config.field.borderWidth,
      cornerRadius: this.config.field.cornerRadius,
      frame: this.frame,
      playerPreview: this.phase === Phase.idle,
      impacts: this.impacts,
      hasHelmet: this.runHelmetActive,
      invulnerable: this._isInvulnerable(),
      shadowBrightness: light ? 1.7 : this.config.field.shadowBrightness,
      lightField: light,
      showFace: this.config.player.showFace,
    });
  }

  _speedMult() {
    if (this.phase === Phase.idle) {
      if (this.world && !this.world.idleEnemiesMove()) return 0;
      return this.config.game.idleSpeedMultiplier;
    }
    const rampSec = Math.max(0.05, this.config.game.speedRampSeconds);
    const idleMult = this.world && !this.world.idleEnemiesMove()
      ? 0
      : this.config.game.idleSpeedMultiplier;
    const t = clamp(this.rampT / rampSec, 0, 1);
    return idleMult + (1 - idleMult) * easeOut(t);
  }

  _averageSpeed() {
    if (!this.world || this.world.enemies.length === 0) return 0;
    if (this.phase === Phase.idle) {
      const base = this.world.averageSpeed(0, this._speedMult());
      return clamp(base + this.idleSpeedWobble, 0, this.config.game.hudSpeedScaleMax);
    }
    if (this.phase === Phase.playing) {
      return this.world.averageSpeed(this.aliveMs / 1000, this._speedMult());
    }
    return 0;
  }

  _updateInfoBar() {
    if (!this.world) return;
    const speed = this._averageSpeed();
    const scaleMax = this.config.game.hudSpeedScaleMax;
    const bar = clamp(speed / scaleMax, 0, 1);
    const cool = '#7EE0FF';
    const hot = '#FF3D4A';
    const color = lerpColor(cool, hot, easeOut(bar));
    const barEl = this.$('speed-bar');
    if (barEl) {
      barEl.style.width = `${bar * 100}%`;
      barEl.style.background = color;
    }

    const isPlaying = this.phase === Phase.playing || this.phase === Phase.impact;
    const ms = isPlaying ? this.aliveMs : 0;
    const timerText = fmtTimerChip(ms);
    if (this.phase === Phase.playing) {
      this._pulseTimerSecond(Math.floor(ms / 1000));
    }

    // Секундомер под полем
    const infoTimer = this.$('info-timer');
    if (infoTimer && infoTimer.textContent !== timerText) infoTimer.textContent = timerText;

    const runSteps = runStepsFromPx(this.world.playerDistance, this.world.playerSize);
    const currentScore = isPlaying
      ? calcScore(this.aliveMs, runSteps, this.world.nearMissCount)
      : (this.resultScore || 0);

    const topScore = this.$('top-score');
    const scoreText = fmtScore(currentScore);
    if (topScore && topScore.textContent !== scoreText) topScore.textContent = scoreText;

    const topTimer = this.$('top-timer');
    if (topTimer && topTimer.textContent !== timerText) topTimer.textContent = timerText;

    const scoreStrip = this.$('score-strip') || this.$('timer-strip');
    if (scoreStrip) {
      scoreStrip.classList.toggle('idle', this.phase !== Phase.playing);
    }

    this.$('info-enemies').textContent = String(this.world.enemies.length);
    const runText = String(Math.round(runSteps));
    const riskText = String(this.world.nearMissCount);
    const runEl = this.$('info-run');
    const riskEl = this.$('info-risk');
    if (runEl && runEl.textContent !== runText) runEl.textContent = runText;
    if (riskEl && riskEl.textContent !== riskText) riskEl.textContent = riskText;
  }

  _updateHud() {
    this.$('hud-lives').textContent = String(this.economy.lives);
    this.$('hud-crystals').textContent = String(this.economy.tokens);
    const best = this.economy.bestTimeMs;
    this.$('hud-record').textContent = best > 0 ? fmtTimeMs(best) : '0';
    const jumpEl = this.$('jump-rent');
    const helmetEl = this.$('helmet-rent');
    if (jumpEl) {
      const j = this.economy.jumpRentalRemaining;
      jumpEl.textContent = j != null ? this._fmtRent(j) : '--:--';
      jumpEl.parentElement.classList.toggle('active', j != null);
    }
    if (helmetEl) {
      const h = this.economy.helmetRentalRemaining;
      helmetEl.textContent = h != null ? this._fmtRent(h) : '--:--';
      helmetEl.parentElement.classList.toggle('active', h != null);
    }

    const photoUrl = telegram.userPhotoUrl;
    const avatarImg = this.$('hud-profile-avatar');
    const cubeSpan = this.$('hud-profile-cube');
    if (avatarImg && cubeSpan) {
      if (photoUrl) {
        if (avatarImg.src !== photoUrl) avatarImg.src = photoUrl;
        avatarImg.style.display = 'block';
        cubeSpan.style.display = 'none';
      } else {
        avatarImg.style.display = 'none';
        cubeSpan.style.display = 'flex';
        if (!cubeSpan.innerHTML) {
          cubeSpan.innerHTML = restingCubeImg(18, 'hud-profile-cube-svg');
        }
      }
    }
  }

  _fmtRent(sec) {
    const total = Math.max(0, Math.floor(sec));
    const m = Math.floor(total / 60);
    const s = total % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }

  _updateOverlay() {
    const banner = this.$('start-banner');
    if (!banner) return;
    banner.hidden = this.phase !== Phase.idle || !this.config.game.startHintEnabled;
    const outOfLives = !this.economy.canPlay;
    banner.classList.toggle('out-of-lives', outOfLives);
    const hero = this.$('start-hero-cube');
    if (hero) hero.hidden = !outOfLives;
    this.$('start-text').textContent = this.economy.canPlay
      ? 'Коснитесь экрана и уводите куб'
      : 'Нет жизней — коснитесь, чтобы пополнить';
  }
}

const app = new UntouchApp();
window.app = app;
app.init().catch((e) => {
  console.error('Untouch init', e);
  app._hideBootLoader();
});

document.getElementById('result-ok')?.addEventListener('click', () => app._resetToIdle());
document.getElementById('result-share-social')?.addEventListener('click', () => {
  app.sheets.open('share', {
    timeMs: app.resultMs,
    run: app.resultRun,
    risk: app.resultRisk,
  });
});
document.getElementById('result-save')?.addEventListener('click', () => {
  const timeMs = app.resultMs;
  app.showToast(RU.autoSaveHint, { accent: '#7EE0FF', flyTo: 'none' });
  app._resetToIdle();
  app.sheets.open('leaderboard', {
    highlightMs: timeMs,
    onClose: () => app._resetToIdle(),
  });
});
