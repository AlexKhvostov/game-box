import { calcScore, clamp, easeOut, fmtScore, fmtTimerChip, lerpColor, runStepsFromPx, visualWallInset } from './util.js?v=v1.0.22_20261003_233329_134';
import { GameWorld } from './game-world.js?v=v1.0.22_20261003_233329_134';
import { FieldRenderer } from './renderer.js?v=v1.0.22_20261003_233329_134';
import { ImpactBurst } from './impact-burst.js?v=v1.0.22_20261003_233329_134';
import { GameAudio } from './audio.js?v=v1.0.22_20261003_233329_134';
import { EconomyStore } from './economy.js?v=v1.0.22_20261003_233329_134';
import { telegram } from './telegram.js?v=v1.0.22_20261003_233329_134';
import { SheetUI } from './sheets.js?v=v1.0.22_20261003_233329_134';
import { showGameToast } from './game-toast.js?v=v1.0.22_20261003_233329_134';
import { showSystemNotice } from './sys-toast.js?v=v1.0.22_20261003_233329_134';
import { RU } from './strings-ru.js?v=v1.0.22_20261003_233329_134';
import { remoteConfig } from './remote-config.js?v=v1.0.22_20261003_233329_134';
import { bindGameTips, hideGameTip } from './tip-pop.js?v=v1.0.22_20261003_233329_134';
import { initMetrika, metrikaGoal } from './metrika.js?v=v1.0.22_20261003_233329_134';
import { adsgramInterstitialBlockId, showInterstitialAd } from './adsgram.js?v=v1.0.22_20261003_233329_134';

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
    this._crystalFlyTimer = 0;
    this._interstitialTimer = 0;
    this._interstitialGen = 0;
    this._interstitialBusy = false;

    this.canvas = document.getElementById('game-canvas');
    this.ctx = this.canvas.getContext('2d', { alpha: false, desynchronized: true })
      || this.canvas.getContext('2d', { alpha: false });
    if (this.ctx) this.ctx.imageSmoothingEnabled = false;
    this._hudAcc = 0;
    const elements = new Map();
    this.$ = (id) => {
      const cached = elements.get(id);
      if (cached?.isConnected) return cached;
      const element = document.getElementById(id);
      if (element) elements.set(id, element);
      else elements.delete(id);
      return element;
    };
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
    this._updateOverlay();
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

    const hudH = document.querySelector('.hud')?.getBoundingClientRect().height || 84;
    const infoBarH = document.querySelector('.info-bar')?.getBoundingClientRect().height || 0;
    // Reserve enough room for the Android brand and complete start instruction.
    const touchMin = 96;
    const gaps = 16;

    const availW = w - pad.left - pad.right - 32;
    const availH = h - pad.top - pad.bottom - hudH - infoBarH - touchMin - gaps;

    const maxSide = this.config?.field?.maxSide || 380;
    const newSide = Math.max(200, Math.floor(Math.min(availW, availH, maxSide)));
    this.fieldSide = newSide;
    const paintedRadius = clamp(Math.min(this.config?.field?.cornerRadius ?? 18, GameWorld.referenceFieldSide / 2), 0, 64);
    const displayRadius = `${paintedRadius * this.fieldSide / GameWorld.referenceFieldSide}px`;
    this.canvas.style.borderRadius = displayRadius;
    const frame = this.canvas.parentElement;
    if (frame?.classList.contains('field-frame')) frame.style.borderRadius = displayRadius;

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
      this.world.wallInset = inset;
    }
    document.documentElement.style.setProperty('--field-side', `${this.fieldSide}px`);
    this._fitHudNumbers();
    this._drawTouchpad();
  }

  _drawTouchpad() {
    const canvas = this.$('touchpad-surface');
    if (!canvas) return;
    const { width, height } = canvas.getBoundingClientRect();
    if (width < 1 || height < 10) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const top = height * .04, bottom = height - 9;
    const backLeft = width * .39, backRight = width * .61;
    const frontLeft = 3, frontRight = width - 3;
    const surface = (offset = 0) => {
      const path = new Path2D();
      path.moveTo(backLeft, top + offset);
      path.lineTo(backRight, top + offset);
      path.lineTo(frontRight, bottom + offset);
      path.quadraticCurveTo(width / 2, bottom + 8 + offset, frontLeft, bottom + offset);
      path.closePath();
      return path;
    };
    ctx.fillStyle = '#071827';
    ctx.fill(surface(5));
    const face = surface();
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, '#0D2C43');
    gradient.addColorStop(1, '#16415B');
    ctx.fillStyle = gradient; ctx.fill(face);
    ctx.save(); ctx.clip(face);
    ctx.strokeStyle = '#78BBD723'; ctx.lineWidth = 1;
    const columns = clamp(Math.round((width - 6) / 56), 6, 16);
    const cell = (width - 6) / columns;
    const perspective = cell * .78 / (bottom - top);
    const depth = (1 / .22 - 1) / perspective;
    ctx.beginPath();
    for (let i = 1; i < columns; i++) {
      const f = i / columns;
      ctx.moveTo(backLeft + (backRight - backLeft) * f, top);
      ctx.lineTo(frontLeft + (frontRight - frontLeft) * f, bottom);
    }
    for (let row = 1; row < depth; row++) {
      const y = bottom - cell * row / (1 + perspective * row);
      ctx.moveTo(0, y); ctx.lineTo(width, y);
    }
    ctx.stroke(); ctx.restore();
    ctx.strokeStyle = '#78BBD766'; ctx.lineWidth = 1.2; ctx.stroke(face);
    ctx.strokeStyle = '#78BBD788'; ctx.lineWidth = 2; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(width * .24, bottom + 2); ctx.lineTo(width * .76, bottom + 2); ctx.stroke();
  }

  _resetWorld() {
    const inset = visualWallInset(this.config.field.borderWidth);
    this.world = new GameWorld({
      config: this.config,
      fieldW: GameWorld.referenceFieldSide,
      fieldH: GameWorld.referenceFieldSide,
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
    this.$('get-lives-btn')?.addEventListener('pointerdown', (ev) => ev.stopPropagation());
    this.$('get-lives-btn')?.addEventListener('click', (ev) => {
      ev.stopPropagation();
      this.audio.resume();
      telegram.haptic('impact', 'light');
      this._openLivesExchange();
    });
  }

  _openLivesExchange() {
    if (this.sheets?.isOpen) return;
    this.sheets.open('lives');
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
        this._openLivesExchange();
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
      const toWorld = GameWorld.referenceFieldSide / this.fieldSide;
      this.world.movePlayerBy({ dx: dx * toWorld, dy: dy * toWorld });
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
      if (!againstWall) this.world.repelEnemiesFromPlayer();
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
    clearTimeout(this._interstitialTimer);
    this._interstitialGen += 1;
    this.phase = Phase.idle;
    this.impacts = [];
    this.aliveMs = 0;
    this.rampT = 0;
    this.resultScore = 0;
    const topScore = this.$('top-score');
    if (topScore) topScore.textContent = fmtTimerChip(0);
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
    // NEON_RESULT_BEST_UI_START
    const resultBest = this.$('result-best');
    if (resultBest) {
      const previousBest = rr?.isAllTimeBest && (rr?.oldBestTimeMs ?? 0) > 0;
      const bestMs = previousBest ? rr.oldBestTimeMs : Math.max(this.resultMs, this.economy.bestTimeMs);
      resultBest.textContent = `${previousBest ? 'Предыдущий рекорд' : 'Ваш рекорд'}: ${(bestMs / 1000).toFixed(3)} с`;
    }
    // NEON_RESULT_BEST_UI_END
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
    this._scheduleResultInterstitial();
    this._updateOverlay();
  }

  _scheduleResultInterstitial() {
    clearTimeout(this._interstitialTimer);
    const gen = ++this._interstitialGen;
    if (!this.economy.canShowResultInterstitial()) return;
    this._interstitialTimer = setTimeout(() => {
      if (gen !== this._interstitialGen) return;
      this._maybeShowResultInterstitial();
    }, 900);
  }

  async _maybeShowResultInterstitial() {
    if (this._interstitialBusy) return;
    if (this.phase !== Phase.result) return;
    if (!this.economy.canShowResultInterstitial()) return;
    const blockId = adsgramInterstitialBlockId(this.config);
    if (!blockId) return;
    this._interstitialBusy = true;
    try {
      await showInterstitialAd(blockId);
      this.economy.markInterstitialShown();
    } catch {
      // нет заполнения / ошибка — результат остаётся, пробуем в следующей попытке
    } finally {
      this._interstitialBusy = false;
    }
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
      const rampSec = Math.max(0, this.config.game.speedRampSeconds);
      const idleMult = this.world.idleEnemiesMove()
        ? this.config.game.idleSpeedMultiplier
        : 0;
      this.rampT = Math.min(rampSec, this.rampT + dt);
      const t = rampSec > 0 ? clamp(this.rampT / rampSec, 0, 1) : 1;
      const speedMult = rampSec > 0 ? idleMult + (1 - idleMult) * easeOut(t) : 1;

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
    const light = this.economy?.lightTheme === true;
    const fieldColor = light ? '#F7FBFD' : '#08253B';
    this.ctx.save();
    this.ctx.scale(this.fieldSide / this.world.field.width, this.fieldSide / this.world.field.height);
    try {
    this.renderer.paint(this.ctx, this.world, {
      fieldSize: this.world.field,
      fieldColor,
      accent: '#35F5C6',
      danger: '#F0363E',
      borderColor: '#58E2EC',
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
    } finally {
      this.ctx.restore();
    }
  }

  _speedMult() {
    if (this.phase === Phase.idle) {
      if (this.world && !this.world.idleEnemiesMove()) return 0;
      return this.config.game.idleSpeedMultiplier;
    }
    const rampSec = Math.max(0, this.config.game.speedRampSeconds);
    if (rampSec === 0) return 1;
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
    const jumpChip = this.$('jump-chip');
    const remaining = this.phase === Phase.playing ? this.world.jumpCooldownRemaining() : 0;
    const progress = Math.round((1 - remaining / this.world.jumpCooldownMs) * 100);
    if (jumpChip && jumpChip.dataset.recharge !== String(progress)) {
      jumpChip.dataset.recharge = String(progress);
      jumpChip.classList.toggle('recharging', remaining > 0);
      jumpChip.style.setProperty('--recharge-offset', String(100 - progress));
    }
    this._updateAbilityHud(remaining);
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
    const topScore = this.$('top-score');
    const topTime = fmtTimerChip(isPlaying ? this.aliveMs : this.phase === Phase.result ? this.resultMs : 0);
    if (topScore && topScore.textContent !== topTime) topScore.textContent = topTime;

    const topTimer = this.$('top-timer');
    if (topTimer && topTimer.textContent !== timerText) topTimer.textContent = timerText;

    const scoreStrip = this.$('score-strip') || this.$('timer-strip');
    if (scoreStrip) {
      scoreStrip.classList.toggle('idle', this.phase !== Phase.playing);
    }

    const enemies = this.$('info-enemies');
    const enemiesText = String(this.world.enemies.length);
    if (enemies && enemies.textContent !== enemiesText) enemies.textContent = enemiesText;
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
    this.$('hud-record').textContent = (best / 1000).toFixed(3);
    const dayScores = this.economy.getAttemptsForPeriod('day');
    const topDay = dayScores.reduce((best, score) => Math.max(best, Number(score.timeMs) || 0), 0);
    this.$('hud-day-best').textContent = topDay > 0 ? (topDay / 1000).toFixed(3) : '—';
    this._fitHudNumbers();
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

    this._updateAbilityHud();
    this._updateOverlay();
  }

  _updateAbilityHud(remaining = this.phase === Phase.playing ? this.world?.jumpCooldownRemaining() || 0 : 0) {
    const playing = this.phase !== Phase.idle;
    const helmetActive = playing ? this.runHadHelmet : this.economy.hasHelmetRental();
    const broken = Boolean(helmetActive && playing && !this.runHelmetActive);
    const helmet = this.$('helmet-chip');
    helmet?.classList.toggle('active', Boolean(helmetActive));
    helmet?.classList.toggle('broken', broken);
    const helmetStatus = broken ? 'Разбит' : helmetActive ? 'Активен' : 'Выкл.';
    if (this.$('helmet-status').textContent !== helmetStatus) this.$('helmet-status').textContent = helmetStatus;
    const helmetLabel = `Шлем · ${helmetStatus} · аренда ${this.$('helmet-rent').textContent}`;
    if (helmet?.getAttribute('aria-label') !== helmetLabel) helmet?.setAttribute('aria-label', helmetLabel);
    const jumpActive = this.economy.hasJumpRental();
    const jump = this.$('jump-chip');
    jump?.classList.toggle('active', Boolean(jumpActive));
    jump?.classList.toggle('recharging', Boolean(jumpActive && remaining > 0));
    const offset = jumpActive && remaining > 0 ? Math.round(clamp(remaining / this.world.jumpCooldownMs, 0, 1) * 100) : 0;
    if (jump?.style.getPropertyValue('--recharge-offset') !== String(offset)) jump?.style.setProperty('--recharge-offset', String(offset));
    const jumpStatus = !jumpActive ? 'Выкл.' : remaining > 0 ? `${(remaining / 1000).toFixed(1).replace('.', ',')} с` : 'Готов';
    if (this.$('jump-status').textContent !== jumpStatus) this.$('jump-status').textContent = jumpStatus;
    const jumpLabel = `Прыжок · ${jumpStatus} · аренда ${this.$('jump-rent').textContent}`;
    if (jump?.getAttribute('aria-label') !== jumpLabel) jump?.setAttribute('aria-label', jumpLabel);
  }

  _fitHudNumbers() {
    // Only measure when text or available width changes, outside the frame loop.
    const measure = this._hudMeasure ??= document.createElement('canvas').getContext('2d');
    for (const id of ['hud-lives', 'hud-crystals', 'hud-day-best', 'hud-record']) {
      const value = this.$(id);
      if (!value) continue;
      const card = value.closest('.hud-chip, .hud-profile-btn');
      const icon = value.parentElement.querySelector('img, svg');
      const width = card.clientWidth - 8 - (icon ? icon.getBoundingClientRect().width + 4 : 0);
      const key = `${width}:${value.textContent}`;
      if (value.dataset.fit === key || width <= 0) continue;
      value.dataset.fit = key;
      const baseSize = id === 'hud-record' ? 12 : 18;
      measure.font = `700 ${baseSize}px ${getComputedStyle(value).fontFamily}`;
      const natural = measure.measureText(value.textContent).width;
      value.style.fontSize = `${Math.min(baseSize, baseSize * (width - 2) / Math.max(1, natural))}px`;
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
    const outOfLives = !this.economy.canPlay;
    banner.hidden = this.phase !== Phase.idle || (!outOfLives && !this.config.game.startHintEnabled);
    this.$('finger-hint').toggleAttribute('hidden', banner.hidden || outOfLives);
    banner.classList.toggle('out-of-lives', outOfLives);
    const hero = this.$('start-hero-cube');
    if (hero) hero.hidden = !outOfLives;
    this.$('get-lives-btn').hidden = !outOfLives;
    this.$('start-text').textContent = this.economy.canPlay
      ? 'Коснись и уворачивайся'
      : 'Обменяйте кристаллы на жизни и возвращайтесь в игру.';
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
