/** Bottom sheets — порт lives_sheet.dart + crystals_sheet.dart */

import { RU, earnTitle, earnSubtitle } from './strings-ru.js';
import { crystalImg, crystalRewardBadge } from './crystal-icon.js';
import { PACK_BADGES, starsLabel, subscribePriceLabel } from './shop-catalog.js';
import {
  heartIcon,
  uiIconImg,
  shopWatchIcon,
  rentKindIcon,
  checkMarkHtml,
  TAB_ICON_SVG,
  restingCubeImg,
} from './game-icons.js';
import { telegram } from './telegram.js';
import { adsgramBlockId, showRewardedAd, showAdLoadStub, showWatchAdHint } from './adsgram.js';
import { calcScore, fmtScore } from './util.js';
import { bindGameTips, hideGameTip, unbindGameTips } from './tip-pop.js';
import { metrikaGoal } from './metrika.js';

function fmtDuration(ms) {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function fmtCooldownSec(sec) {
  const total = Math.max(0, Math.floor(sec));
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

function fmtMsShort(ms) {
  if (ms <= 0) return '—';
  const s = ms / 1000;
  if (s >= 60) {
    const m = Math.floor(s / 60);
    const r = Math.floor(s % 60);
    return `${m}:${String(r).padStart(2, '0')}`;
  }
  return `${s.toFixed(2)}s`;
}

function fmtMs3(ms) {
  if (ms <= 0) return '—';
  const s = ms / 1000;
  if (s >= 60) {
    const m = Math.floor(s / 60);
    const r = (s % 60).toFixed(3);
    return `${m}:${r.padStart(6, '0')} с`;
  }
  return `${s.toFixed(3)} с`;
}

const JUMP_BOOST_SVG = `<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M7.41 18.59 8.83 20 12 16.83l3.17 3.17 1.41-1.41L12 14l-4.59 4.59zM7.41 6.59 12 11.17l4.59-4.58L15.17 5 12 8.17 8.83 5 7.41 6.59z"/></svg>`;
const HELMET_BOOST_SVG = `<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 1 3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm0 10.99h7c-.53 4.12-3.28 7.79-7 8.94V12H5V6.3l7-3.11v8.8z"/></svg>`;

function rewardBadge(amount, { emphasized = true, showPlusHint = false, base, hasPremium = false } = {}) {
  let plusHint = '';
  if (showPlusHint) {
    if (hasPremium && base != null && amount !== base) {
      plusHint = RU.premiumTimesBase(base, 2);
    } else if (!hasPremium) {
      plusHint = RU.premiumTimesLocked(2);
    }
  }
  return crystalRewardBadge(amount, { emphasized, plusHint });
}

function fmtChargeDate(d) {
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  return `${dd}.${mm}.${d.getFullYear()}`;
}

function bestLifePackIndex(packs) {
  let bestIdx = 0;
  let bestRatio = packs[0].costTokens / packs[0].lives;
  for (let i = 1; i < packs.length; i++) {
    const ratio = packs[i].costTokens / packs[i].lives;
    if (ratio < bestRatio) {
      bestRatio = ratio;
      bestIdx = i;
    }
  }
  return bestIdx;
}

function giftMarkHtml(ready) {
  return `<div class="gift-mark">
    <div class="lid"></div>
    <div class="box"></div>
    <div class="ribbon"></div>
    ${heartIcon(10, 'gift-bow-heart')}
  </div>`;
}

function fmtDurationRu(ms) {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  if (h > 0) return `${h} ч. ${m} мин.`;
  if (m > 0) return `${m} мин. ${s} сек.`;
  return `${s} сек.`;
}

function dayActionHtml(status, countdown, day) {
  if (status === 'claimed') {
    return `
      <div class="day-action-pill claimed">
        ${checkMarkHtml(13, false)}
        <span class="day-action-txt">${RU.completed}</span>
      </div>`;
  }
  if (status === 'today') {
    return `
      <button type="button" class="day-action-btn claim" id="claim-daily-btn">
        <span class="claim-txt">${RU.claim}</span>
      </button>`;
  }
  if (status === 'waiting') {
    return `
      <button type="button" class="day-action-btn wait" data-daily-wait="${day}">
        <span class="wait-ico">${uiIconImg('timer', 13)}</span>
        <span class="wait-timer" data-daily-timer>${countdown ?? ''}</span>
      </button>`;
  }
  return `
    <div class="day-action-pill locked" data-daily-locked="${day}">
      ${uiIconImg('lock', 13)}
    </div>`;
}

function giftRingSvg(progress) {
  const w = 92;
  const h = 78;
  const inset = 2.25;
  const rw = w - inset * 2;
  const rh = h - inset * 2;
  const r = 14;
  const perim = 2 * (rw + rh - 4 * r) + 2 * Math.PI * r;
  const dash = perim * Math.max(0, Math.min(1, progress));
  return `<svg class="gift-ring" viewBox="0 0 ${w} ${h}" aria-hidden="true">
    <rect x="${inset}" y="${inset}" width="${rw}" height="${rh}" rx="${r}" ry="${r}"
      fill="none" stroke="#243848" stroke-width="4.5"/>
    <rect x="${inset}" y="${inset}" width="${rw}" height="${rh}" rx="${r}" ry="${r}"
      fill="none" stroke="rgba(126,224,255,0.72)" stroke-width="4.5"
      stroke-dasharray="${dash} ${perim}" stroke-linecap="round"
      pathLength="${perim}"/>
  </svg>`;
}

export class SheetUI {
  constructor(app) {
    this.app = app;
    this.root = document.getElementById('sheet-root');
    this.backdrop = document.getElementById('sheet-backdrop');
    this.panel = document.getElementById('sheet-panel');
    this.body = document.getElementById('sheet-body');
    this._tab = 0;
    this._type = null;
    this._tick = null;
    this._fromPlus = false;
    this._lbFilter = 'day';
    this._lbLoading = false;

    this.backdrop?.addEventListener('click', () => this.close());
  }

  get isOpen() {
    return Boolean(this.root && !this.root.hidden && this._type);
  }

  open(type, opts = {}) {
    if (!this.root) return;
    this._fromPlus = false;
    this._type = type;
    this._tab = opts.tab ?? 0;
    this._opts = opts;
    this._onClose = opts.onClose ?? null;
    this._setPanelMode(type);
    if (type === 'leaderboard') {
      this._lbFilter = opts.filter || 'day';
      this._lbLoading = true;
      this._refreshLeaderboardFromServer();
    }

    this.root.hidden = false;
    requestAnimationFrame(() => this.root.classList.add('open'));
    this._startTick();
    this._render();
  }

  close() {
    if (!this.root) return;
    if (this._type === 'plus') {
      this._returnFromPlus();
      return;
    }
    this.root.classList.remove('open');
    this._stopTick();
    hideGameTip();
    const onCloseCb = this._onClose;
    this._onClose = null;
    setTimeout(() => {
      this.root.hidden = true;
      if (this.body) this.body.innerHTML = '';
      this._type = null;
      if (this.app.phase === 'result') {
        this.app._resetToIdle();
      }
      onCloseCb?.();
    }, 220);
  }

  _setPanelMode(type) {
    this.panel?.classList.remove('sheet-lives', 'sheet-crystals', 'sheet-leaderboard', 'sheet-plus', 'sheet-share', 'sheet-profile');
    if (type === 'lives') this.panel?.classList.add('sheet-lives');
    else if (type === 'crystals') this.panel?.classList.add('sheet-crystals');
    else if (type === 'plus') this.panel?.classList.add('sheet-plus');
    else if (type === 'share') this.panel?.classList.add('sheet-share');
    else if (type === 'profile') this.panel?.classList.add('sheet-profile');
    else this.panel?.classList.add('sheet-leaderboard');
  }

  _openPlusSheet() {
    this._fromPlus = true;
    this._type = 'plus';
    const active = this._economy().hasPremium;
    this.panel?.classList.toggle('sheet-plus-active', active);
    this._setPanelMode('plus');
    this._stopTick();
    this._renderPlus();
  }

  _returnFromPlus() {
    this._type = 'crystals';
    this._fromPlus = false;
    this.panel?.classList.remove('sheet-plus-active');
    this._setPanelMode('crystals');
    this._startTick();
    this._renderCrystals(this._tab);
  }

  _economy() {
    return this.app.economy;
  }

  _toast(msg, { accent = '#3DDC97', flyTo = 'none', festive = false, icon } = {}) {
    this.app.showToast(msg, { accent, flyTo, festive, icon });
  }

  _startTick() {
    this._stopTick();
    this._tick = setInterval(() => {
      if (this._type === 'crystals') this._softUpdateCrystals();
    }, 1000);
  }

  _stopTick() {
    if (this._tick) {
      clearInterval(this._tick);
      this._tick = null;
    }
  }

  _render() {
    if (this._type === 'lives') this._renderLives();
    else if (this._type === 'crystals') this._renderCrystals(this._tab);
    else if (this._type === 'plus') this._renderPlus();
    else if (this._type === 'leaderboard') this._renderLeaderboard();
    else if (this._type === 'share') this._renderShare();
    else if (this._type === 'profile') this._renderProfile();
  }

  _openCrystalsShop() {
    this._type = 'crystals';
    this._tab = 1;
    this.panel?.classList.remove('sheet-lives', 'sheet-leaderboard');
    this.panel?.classList.add('sheet-crystals');
    this._renderCrystals(1);
  }

  _renderLives() {
    const e = this._economy();
    const packs = e.lifePacks;
    const exhausted = !e.canPlay;
    const bestIdx = bestLifePackIndex(packs);

    const packHtml = packs
      .map((pack, i) => {
        const best = i === bestIdx;
        const can = e.canBuyLifePack(pack);
        return `
        <button type="button" class="life-buy-card ${best ? 'best-deal' : ''} ${can ? 'can-afford' : 'need-more'}" data-pack="${i}">
          ${best ? `<div class="deal-ribbon">${RU.badgeBest}</div>` : ''}
          <div class="card-gain-row">
            <div class="card-heart-circle">${heartIcon(18)}</div>
            <div class="card-gain-text">
              <span class="gain-number">+${pack.lives}</span>
              <span class="gain-label">жизней</span>
            </div>
          </div>
          <div class="card-price-pill ${can ? 'price-active' : 'price-disabled'}">
            <span class="price-action">${can ? RU.buyAction : RU.needMoreAction}</span>
            <div class="price-tag">
              ${crystalImg(13, can)}
              <span class="price-amount">${pack.costTokens}</span>
            </div>
          </div>
        </button>`;
      })
      .join('');

    const statusHtml = exhausted
      ? `
        <div class="lives-status exhausted">
          ${restingCubeImg(44, 'lives-status-cube')}
          <div class="lives-status-text">
            <div class="lives-status-title">${RU.noLivesTitle}</div>
            <div class="lives-status-sub">${RU.noLivesHeroSubtitle}</div>
          </div>
        </div>`
      : `
        <div class="lives-status normal">
          <div class="lives-status-title solo">${RU.livesConvertTitle}</div>
          <div class="lives-status-sub solo">${RU.livesConvertSubtitle}</div>
        </div>`;

    this.body.innerHTML = `
      <div class="lives-sheet">
        <div class="lives-header-bar">
          ${statusHtml}
          <div class="lives-balance-strip">
            <div class="lives-stat lives-stat-hearts">
              <span class="stat-ico-halo">${heartIcon(18)}</span>
              <div class="lives-stat-body">
                <span class="lives-stat-value">${e.lives}</span>
                <span class="lives-stat-label">${RU.statLives}</span>
              </div>
            </div>
            <button type="button" class="lives-stat lives-stat-crystals" id="lives-to-shop">
              <span class="stat-ico-halo">${crystalImg(18, true)}</span>
              <div class="lives-stat-body">
                <span class="lives-stat-value">${e.tokens}</span>
                <span class="lives-stat-label">${RU.crystals}</span>
              </div>
              <span class="lives-stat-action">В магазин ›</span>
            </button>
          </div>
        </div>
        <div class="lives-shop-frame">
          <div class="lives-frame-header">
            <span class="lives-frame-title">${RU.livesBuyFrameTitle.toUpperCase()}</span>
            <span class="lives-frame-sub">${RU.livesBuyFrameSub}</span>
          </div>
          <div class="lives-shop-grid">${packHtml}</div>
        </div>
      </div>`;

    this.body.querySelector('#lives-to-shop')?.addEventListener('click', () => this._openCrystalsShop());
    this.body.querySelectorAll('[data-pack]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const pack = packs[Number(btn.dataset.pack)];
        if (e.buyLifePack(pack)) {
          this._toast(RU.livesGained(pack.lives), { accent: '#5EE6B0', flyTo: 'lives', icon: 'heart' });
          this.app._updateHud();
          this.close();
        } else {
          this._openCrystalsShop();
        }
      });
    });
  }

  _renderCrystalsHeader(e) {
    const canGift = e.canClaimTimedBonus;
    const giftAmt = e.e.timedBonusTokens ?? 22;
    const progress = e.timedBonusUnlockProgress;
    const remain = e.timedBonusRemainingMs;
    const adAmt = e.earnActions.find((a) => a.id === 'watch_ad')?.reward ?? 5;
    const canAd = e.canClaimWatchAd;
    const adRemain = e.watchAdCooldownRemainingMs;
    const adProgress = e.watchAdUnlockProgress;

    return `
      <div class="crystals-header">
        <div class="game-panel accent-cyan crystals-balance-panel">
          ${crystalImg(24, true)}
          <div>
            <div class="cb-label">${RU.crystals}</div>
            <div class="cb-value" id="sheet-crystal-balance">${e.tokens}</div>
          </div>
        </div>
        <button type="button" class="gift-btn ${canGift ? 'ready' : 'frozen'}" id="gift-btn">
          ${canGift ? '' : giftRingSvg(progress)}
          <div class="gift-btn-inner ${canGift ? '' : 'gift-blur'}">
            ${giftMarkHtml(canGift)}
            <div class="gift-reward-row">
              ${crystalImg(13, canGift)}
              <span class="amt">+${giftAmt}</span>
            </div>
            ${canGift ? `<span class="gift-ready-lbl">${RU.giftReady}</span>` : ''}
          </div>
          ${canGift ? '' : `<span class="gift-timer">${fmtDuration(remain)}</span>`}
        </button>
        <button type="button" class="gift-btn ad-btn ${canAd ? 'ready' : 'frozen'}" id="watch-ad-btn">
          ${canAd ? '' : giftRingSvg(adProgress)}
          <div class="gift-btn-inner ${canAd ? '' : 'gift-blur'}">
            <span class="ad-mark">${shopWatchIcon(!canAd, 22)}</span>
            <div class="gift-reward-row">
              ${crystalImg(13, canAd)}
              <span class="amt">+${adAmt}</span>
            </div>
            ${canAd ? `<span class="gift-ready-lbl">${RU.adReadyLbl}</span>` : ''}
          </div>
          ${canAd ? '' : `<span class="gift-timer">${fmtCooldownSec(adRemain / 1000)}</span>`}
        </button>
      </div>`;
  }

  _renderCrystalsTabs(tab) {
    const tabs = [
      { id: 0, icon: TAB_ICON_SVG.daily, label: RU.tabDaily },
      { id: 1, icon: TAB_ICON_SVG.shop, label: RU.tabShop },
      { id: 2, icon: TAB_ICON_SVG.rent, label: RU.tabRent },
      { id: 3, icon: TAB_ICON_SVG.earn, label: RU.tabEarn },
    ];
    return `
      <div class="crystals-menu-dock">
        <div class="crystals-menu-label">Раздел</div>
        <div class="crystals-tabs">
          ${tabs
            .map(
              (t) => `
            <button type="button" class="crystals-tab ${tab === t.id ? 'active' : ''}" data-tab="${t.id}">
              <span class="tab-ico-wrap">${t.icon}</span>
              <span class="tab-txt">${t.label}</span>
            </button>`,
            )
            .join('')}
        </div>
      </div>`;
  }

  _switchCrystalsTab(tab) {
    this._tab = tab;
    this.body.querySelectorAll('.crystals-tab').forEach((btn) => {
      btn.classList.toggle('active', Number(btn.dataset.tab) === tab);
    });
    const panel = this.body.querySelector('#crystals-pane');
    if (panel) {
      panel.classList.remove('pane-in');
      panel.innerHTML = this._renderCrystalsPane(tab, this._economy());
      requestAnimationFrame(() => panel.classList.add('pane-in'));
    }
    this._bindCrystalsPane(tab);
    if (tab === 3) this._refreshSocialEarn();
  }

  async _refreshSocialEarn() {
    if (this._socialRefreshing || this._inviteBusy) return;
    this._socialRefreshing = true;
    try {
      const e = this._economy();
      const social = await e.syncSocial();
      if (!social) return;
      if (social.inviteReward) {
        this._toast(RU.earnInviteRewardToast(social.inviteReward, social.inviteRewardFriends || 1), {
          accent: '#7EE0FF',
          flyTo: 'crystals',
        });
        this.app._updateHud();
      }
      if (this._tab !== 3 || this._inviteBusy) return;
      const panel = this.body.querySelector('#crystals-pane');
      if (!panel) return;
      panel.innerHTML = this._renderCrystalsPane(3, e);
      this._bindCrystalsPane(3);
    } finally {
      this._socialRefreshing = false;
    }
  }

  _softUpdateCrystals() {
    if (!this.body.querySelector('.crystals-sheet')) return;
    const e = this._economy();
    const bal = this.body.querySelector('#sheet-crystal-balance');
    if (bal) bal.textContent = String(e.tokens);

    const giftBtn = this.body.querySelector('#gift-btn');
    if (giftBtn) {
      const canGift = e.canClaimTimedBonus;
      const wasReady = giftBtn.classList.contains('ready');
      if (canGift !== wasReady) {
        this._refreshCrystalsHeader();
        return;
      }
      if (!canGift) {
        const timer = giftBtn.querySelector('.gift-timer');
        if (timer) timer.textContent = fmtDuration(e.timedBonusRemainingMs);
        const ring = giftBtn.querySelector('.gift-ring');
        if (ring) {
          const svg = giftRingSvg(e.timedBonusUnlockProgress);
          ring.outerHTML = svg;
        }
      }
    }

    const adBtn = this.body.querySelector('#watch-ad-btn');
    if (adBtn) {
      const canAd = e.canClaimWatchAd;
      const wasReady = adBtn.classList.contains('ready');
      if (canAd !== wasReady) {
        this._refreshCrystalsHeader();
        return;
      }
      if (!canAd) {
        const timer = adBtn.querySelector('.gift-timer');
        if (timer) timer.textContent = fmtCooldownSec(e.watchAdCooldownRemainingMs / 1000);
        const ring = adBtn.querySelector('.gift-ring');
        if (ring) {
          const svg = giftRingSvg(e.watchAdUnlockProgress);
          ring.outerHTML = svg;
        }
      }
    }

    if (this._tab === 0) {
      if (this._dailyClaimedState != null && this._dailyClaimedState !== e.canClaimDaily) {
        this._dailyClaimedState = e.canClaimDaily;
        this._switchCrystalsTab(0);
        return;
      }
      const timerText = fmtDuration(e.untilMidnight);
      this.body.querySelectorAll('[data-daily-timer]').forEach((el) => {
        el.textContent = timerText;
      });
    } else if (this._tab === 2) {
      this.body.querySelectorAll('[data-rent-active]').forEach((el) => {
        const kind = el.dataset.rentActive;
        const rem = kind === 'jump' ? e.jumpRentalRemaining : e.helmetRentalRemaining;
        if (rem != null) {
          el.textContent = RU.rentActive(fmtCooldownSec(rem));
        }
      });
    }
  }

  _bindCrystalsHeader() {
    const e = this._economy();
    this.body.querySelector('#gift-btn')?.addEventListener('click', () => {
      const got = e.claimTimedBonus();
      if (got != null) {
        this._toast(RU.giftToast(got), { accent: '#7EE0FF', flyTo: 'crystals', festive: true });
        this.app._updateHud();
        this._refreshCrystalsHeader();
        this._switchCrystalsTab(this._tab);
      }
    });
    this.body.querySelector('#watch-ad-btn')?.addEventListener('click', () => {
      this._watchAdForCrystals();
    });
  }

  _refreshCrystalsHeader() {
    const el = this.body.querySelector('.crystals-header');
    if (!el) return;
    el.outerHTML = this._renderCrystalsHeader(this._economy());
    this._bindCrystalsHeader();
  }

  _renderCrystals(tab = 0) {
    this._tab = tab;
    const e = this._economy();
    const pane = this._renderCrystalsPane(tab, e);

    if (this.body.querySelector('.crystals-sheet')) {
      this._refreshCrystalsHeader();
      const headerBal = this.body.querySelector('#sheet-crystal-balance');
      if (headerBal) headerBal.textContent = String(e.tokens);
      this._switchCrystalsTab(tab);
      return;
    }

    this.body.innerHTML = `
      <div class="crystals-sheet">
        ${this._renderCrystalsHeader(e)}
        ${this._renderCrystalsTabs(tab)}
        <div class="crystals-content-area">
          <div id="crystals-pane" class="pane-in">${pane}</div>
        </div>
      </div>`;

    this._bindCrystalsHeader();

    this.body.querySelectorAll('.crystals-tab').forEach((btn) => {
      btn.addEventListener('click', () => this._switchCrystalsTab(Number(btn.dataset.tab)));
    });

    this._bindCrystalsPane(tab);
  }

  _bindCrystalsPane(tab) {
    const e = this._economy();
    if (tab === 0) {
      this._dailyClaimedState = e.canClaimDaily;
      this.body.querySelector('#claim-daily-btn')?.addEventListener('click', (ev) => {
        ev.stopPropagation();
        const got = e.claimDaily();
        if (got != null) {
          this._toast(RU.dailyToast(got), { accent: '#3DDC97', flyTo: 'crystals' });
          this.app._updateHud();
          this._renderCrystals(0);
        }
      });
      this.body.querySelector('.daily-card.today')?.addEventListener('click', () => {
        this.body.querySelector('#claim-daily-btn')?.click();
      });

      this.body.querySelectorAll('[data-daily-wait]').forEach((btn) => {
        btn.addEventListener('click', (ev) => {
          ev.stopPropagation();
          const day = btn.dataset.dailyWait;
          this._toast(RU.dailyUnlockWait(day, fmtDurationRu(e.untilMidnight)), {
            accent: '#7EE0FF',
            flyTo: 'none',
          });
        });
      });
      this.body.querySelector('.daily-card.waiting')?.addEventListener('click', () => {
        this.body.querySelector('[data-daily-wait]')?.click();
      });

      this.body.querySelectorAll('[data-daily-locked]').forEach((el) => {
        el.addEventListener('click', (ev) => {
          ev.stopPropagation();
          const day = el.dataset.dailyLocked;
          this._toast(RU.dailyLockedHint(day), { accent: '#FFC857', flyTo: 'none' });
        });
      });
      this.body.querySelector('#daily-plus-card')?.addEventListener('click', () => {
        this._openPlusSheet();
      });
    } else if (tab === 1) {
      this.body.querySelectorAll('[data-iap]').forEach((btn) => {
        btn.addEventListener('click', () => this._buyStars(btn.dataset.iap));
      });
    } else if (tab === 2) {
      this.body.querySelector('[data-rent-jump-s]')?.addEventListener('click', () => this._rent('jump', false));
      this.body.querySelector('[data-rent-jump-l]')?.addEventListener('click', () => this._rent('jump', true));
      this.body.querySelector('[data-rent-helmet-s]')?.addEventListener('click', () => this._rent('helmet', false));
      this.body.querySelector('[data-rent-helmet-l]')?.addEventListener('click', () => this._rent('helmet', true));
    } else if (tab === 3) {
      this.body.querySelectorAll('[data-earn]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.dataset.earn;
          if (id === 'invite_friend') {
            this._inviteFriend(btn);
            return;
          }
          if (id === 'enable_notifications') {
            this._enableNotifications();
            return;
          }
          const got = e.claimEarnAction(id);
          if (got != null) {
            this._toast(RU.crystalsPlus(got), { accent: '#7EE0FF', flyTo: 'crystals' });
            this.app._updateHud();
            this._renderCrystals(3);
          } else if (!e.isEarnUnlocked(id)) {
            this._toast(RU.earnBonusLocked, { accent: '#FFC857', flyTo: 'none' });
          }
        });
      });
    }
  }

  _renderCrystalsPane(tab, e) {
    if (tab === 0) return this._renderDailyPane(e);
    if (tab === 1) return this._renderShopPane(e);
    if (tab === 2) return this._renderRentPane(e);
    return this._renderEarnPane(e);
  }

  _renderDailyPane(e) {
    const rewards = e.e.dailyRewardTokens ?? [2, 4, 9, 16, 32, 64, 81];
    const upcoming = e.upcomingStreakDay;
    const claimedToday = !e.canClaimDaily;
    const claimedCount = claimedToday ? Math.max(1, e.dailyStreak) : Math.max(0, upcoming - 1);
    const waitingDay = claimedToday ? Math.min(claimedCount + 1, rewards.length) : -1;
    const hint = claimedToday ? RU.dailyStreakActive(e.dailyStreak) : RU.dailyStreakHint;
    const plusActive = e.hasPremium;
    const next = e.premiumNextChargeDate ?? new Date(Date.now() + (e.plusProduct?.days ?? 7) * 86400000);
    const plusCard = `
      <button type="button" class="daily-plus-card ${plusActive ? 'on' : ''}" id="daily-plus-card">
        <span class="daily-plus-ico">${uiIconImg('premium', 22)}</span>
        <span class="daily-plus-copy">
          <span class="daily-plus-title">${RU.plusTitle}</span>
          <span class="daily-plus-hint">${plusActive ? RU.plusDailyOnHint(fmtChargeDate(next)) : RU.plusDailyOffHint}</span>
        </span>
        <span class="daily-plus-cta">${plusActive ? RU.plusDailyCtaOn : RU.plusDailyCtaOff}</span>
      </button>`;

    const rows = rewards
      .map((_, i) => {
        const day = i + 1;
        const base = e.dailyTokensForStreak(i, false);
        const amount = e.dailyTokensForStreak(i, e.hasPremium);
        const isClaimed = day <= claimedCount;
        const isToday = !claimedToday && day === upcoming;
        const isWaiting = claimedToday && day === waitingDay;
        const isLocked = !isClaimed && !isToday && !isWaiting;

        let actionStatus = 'locked';
        if (isClaimed) actionStatus = 'claimed';
        else if (isToday) actionStatus = 'today';
        else if (isWaiting) actionStatus = 'waiting';
        const action = dayActionHtml(
          actionStatus,
          isWaiting ? fmtDuration(e.untilMidnight) : null,
          day,
        );

        const nodeCls = isClaimed
          ? 'claimed'
          : isToday
            ? 'today'
            : isWaiting
              ? 'waiting'
              : 'locked';

        const lineTop = i === 0 ? 'transparent' : isClaimed || isToday || isWaiting ? 'on' : '';
        const lineBot = i === rewards.length - 1 ? 'transparent' : isClaimed ? 'on' : '';

        return `
        <div class="daily-row">
          <div class="daily-rail">
            <div class="daily-line ${lineTop === 'on' ? 'on' : ''} ${isWaiting && i > 0 ? 'wait' : ''}" style="${i === 0 ? 'visibility:hidden' : ''}"></div>
            <div class="daily-node ${nodeCls}">${isClaimed ? checkMarkHtml(11, true) : day}</div>
            <div class="daily-line ${lineBot === 'on' ? 'on' : ''}" style="${i === rewards.length - 1 ? 'visibility:hidden' : ''}"></div>
          </div>
          <div class="daily-card ${isClaimed ? 'claimed' : ''} ${isToday ? 'today' : ''} ${isWaiting ? 'waiting' : ''} ${isLocked ? 'locked' : ''}">
            <div class="daily-card-mid">${rewardBadge(amount, {
              emphasized: isToday || isWaiting || !isLocked,
              showPlusHint: true,
              base,
              hasPremium: e.hasPremium,
            })}</div>
            ${action}
          </div>
        </div>`;
      })
      .join('');

    return `<div class="tab-pane tab-pane-daily">${plusCard}<div class="daily-bonus-scroll"><p class="daily-hint">${hint}</p>
      <div class="daily-row daily-rail-head">
        <div class="daily-rail"><span class="daily-rail-caption">${RU.periodDay}</span></div>
      </div>
      ${rows}</div></div>`;
  }

  async _watchAdForCrystals() {
    if (this._watchingAd) return;
    const e = this._economy();
    if (!e.canClaimWatchAd) return;
    const blockId = adsgramBlockId(this.app.config);
    if (!blockId) {
      showAdLoadStub();
      return;
    }
    this._watchingAd = true;
    const ad = e.earnActions.find((a) => a.id === 'watch_ad');
    const reward = ad?.reward ?? 5;
    try {
      if (!e.skipWatchAdHint) {
        const hint = await showWatchAdHint({ reward });
        if (!hint.ok) return;
        if (hint.skipNext) e.rememberSkipWatchAdHint();
      }
      this._toast(RU.shopAdWait, { accent: '#7EE0FF', flyTo: 'none' });
      await showRewardedAd(blockId);
      const got = e.claimWatchAd(reward);
      if (got != null) {
        this._toast(RU.crystalsPlus(got), { accent: '#7EE0FF', flyTo: 'crystals' });
        this.app._updateHud();
        if (this._type === 'crystals') this._renderCrystals(this._tab);
      }
    } catch (err) {
      const kind = err?.adFail || (/skip|close|cancel/i.test(String(err?.message || '')) ? 'skip' : 'load');
      if (kind === 'skip') this._toast(RU.shopAdSkipped, { accent: '#FFC857', flyTo: 'none' });
      else showAdLoadStub();
    } finally {
      this._watchingAd = false;
    }
  }

  _renderShopPane(e) {
    const packs = e.starPacks.map(
      (offer) => `
      <div class="game-panel accent-cyan mb-6 shop-pack" data-iap="${offer.id}">
        <div class="shop-row">
          ${crystalImg(28, true)}
          <div class="shop-text-col">
            <div class="t1">${offer.title}</div>
            ${offer.badgeKey ? `<div class="badge">${PACK_BADGES[offer.badgeKey] ?? ''}</div>` : ''}
          </div>
          <div class="shop-mid">${rewardBadge(offer.crystals)}</div>
          <div class="shop-price">${starsLabel(offer.stars)}</div>
        </div>
      </div>`,
    ).join('');

    return `
      <div class="tab-pane tab-pane-shop">
        ${packs}
        <p class="shop-iap-note">${RU.shopIapHint}</p>
      </div>`;
  }

  _renderRentPane(e) {
    const g = this.app.config.game ?? {};
    const jumpOn = g.jumpEnabled !== false;
    const helmetOn = g.helmetEnabled !== false;
    if (!jumpOn && !helmetOn) {
      return `<div class="tab-pane tab-pane-rent"><p class="daily-hint" style="text-align:center">${RU.rentInactive}</p></div>`;
    }

    const ec = e.e;
    const light = document.documentElement.getAttribute('data-theme') === 'light';
    const helmetAccent = light ? '#0A4A62' : '#7EE0FF';
    const jumpAccent = light ? '#0A8A58' : '#3DDC97';
    let html = '<div class="tab-pane tab-pane-rent">';
    if (helmetOn) {
      html += this._rentCard(e, 'helmet', {
        accent: helmetAccent,
        iconName: 'shield',
        title: RU.rentHelmetTitle,
        desc: RU.rentHelmetSub,
        active: e.helmetRentalRemaining,
        shortM: ec.helmetRentalMinutes,
        shortCost: ec.helmetRentalCost,
        shortOk: e.canRentHelmet(false),
        longM: ec.helmetRentalHourMinutes,
        longCost: ec.helmetRentalHourCost,
        longList: e.helmetRentalHourListPrice(),
        longDisc: e.helmetRentalHourDiscountPercent(),
        longOk: e.canRentHelmet(true),
        prefix: 'helmet',
      });
    }
    if (jumpOn && helmetOn) html += '<div style="height:10px"></div>';
    if (jumpOn) {
      html += this._rentCard(e, 'jump', {
        accent: jumpAccent,
        iconName: 'jump',
        title: RU.rentJumpTitle,
        desc: RU.rentJumpSub,
        active: e.jumpRentalRemaining,
        shortM: ec.jumpRentalMinutes,
        shortCost: ec.jumpRentalCost,
        shortOk: e.canRentJump(false),
        longM: ec.jumpRentalHourMinutes,
        longCost: ec.jumpRentalHourCost,
        longList: e.jumpRentalHourListPrice(),
        longDisc: e.jumpRentalHourDiscountPercent(),
        longOk: e.canRentJump(true),
        prefix: 'jump',
      });
    }
    html += '</div>';
    return html;
  }

  _rentCard(e, _kind, o) {
    const action = o.active != null ? RU.rentExtend : RU.rentBuy;
    const activeLbl =
      o.active != null
        ? `<div class="rent-active-lbl" data-rent-active="${o.prefix}" style="color:${o.accent}">${RU.rentActive(fmtCooldownSec(o.active))}</div>`
        : '';

    return `
      <div class="game-panel mb-6" style="border-color:${o.accent}73">
        <div class="rent-card-h">
          <div class="rent-icon-box" style="background:${o.accent}29">${rentKindIcon(o.iconName, 22)}</div>
          <div>
            <div class="rent-title">${o.title}</div>
            <div class="rent-desc">${o.desc}</div>
          </div>
        </div>
        ${activeLbl}
        <div class="rent-btns">
          ${this._rentDurBtn(o.prefix, 's', o.shortM, o.shortCost, null, null, o.shortOk, action, o.accent)}
          ${this._rentDurBtn(o.prefix, 'l', o.longM, o.longCost, o.longList, o.longDisc, o.longOk, action, o.accent)}
        </div>
      </div>`;
  }

  _rentDurBtn(prefix, suffix, mins, cost, listPrice, discPct, enabled, action, accent) {
    const disc =
      discPct > 0 && listPrice
        ? `<span class="rd-disc" style="background:${accent}38;color:${accent}">${RU.rentDiscountBadge(discPct)}</span>`
        : '';
    const strike =
      discPct > 0 && listPrice
        ? `<span class="rd-strike">${listPrice}</span>`
        : '';
    return `
      <button type="button" class="rent-dur-btn ${enabled ? '' : 'disabled'}"
        data-rent-${prefix}-${suffix} style="border-color:${accent}59;background:${accent}1a">
        <div class="rd-mins" style="color:${accent}">${RU.rentMinsLabel(mins)}</div>
        <div class="rd-cost-row">
          ${strike}
          <span class="rd-cost">${cost}</span>
          ${crystalImg(14)}
          ${disc}
        </div>
        <div class="rd-action" style="color:${accent}">${action}</div>
      </button>`;
  }

  _rent(kind, hour) {
    const e = this._economy();
    const can = kind === 'jump' ? e.canRentJump(hour) : e.canRentHelmet(hour);
    if (!can) {
      this._toast(RU.rentNotEnough, { accent: '#FF5A5F', flyTo: 'none' });
      return;
    }
    const extending = kind === 'jump' ? e.hasJumpRental() : e.hasHelmetRental();
    const ok = kind === 'jump' ? e.rentJump(hour) : e.rentHelmet(hour);
    if (!ok) return;
    const rem = kind === 'jump' ? e.jumpRentalRemaining : e.helmetRentalRemaining;
    const msg = extending ? RU.rentActive(fmtCooldownSec(rem)) : kind === 'jump' ? RU.rentJumpTitle : RU.rentHelmetTitle;
    this._toast(msg, {
      accent: kind === 'jump' ? '#3DDC97' : '#7EE0FF',
      flyTo: 'none',
    });
    this.app._updateHud();
    this._renderCrystals(2);
  }

  _setShareBusy(button, busy) {
    if (!button) return;
    button.disabled = busy;
    button.classList.toggle('busy', busy);
    button.setAttribute('aria-busy', busy ? 'true' : 'false');
    button.innerHTML = busy
      ? `<span class="earn-share-spin" aria-hidden="true"></span><span>${RU.earnInvitePreparing}</span>`
      : RU.shareSocial;
  }

  async _inviteFriend(btn) {
    if (this._inviteBusy) return;
    const button = btn?.classList?.contains('earn-share-btn')
      ? btn
      : this.body.querySelector('.earn-share-btn');
    if (!telegram.user?.id) {
      this._toast(RU.earnInviteNeedTelegram, { accent: '#FFC857', flyTo: 'none' });
      return;
    }
    this._inviteBusy = true;
    telegram.haptic('impact', 'medium');
    this._setShareBusy(button, true);
    try {
      const e = this._economy();
      const timeSec = formatInviteBest(e.bestTimeMs);
      const bonus = e.earnActions.find((a) => a.id === 'install_bonus')?.reward || 40;
      const text = RU.earnInviteShareText({ timeSec, bonus });
      const prepared = await e.prepareInviteShare({ timeSec, bonus });
      if (prepared?.preparedId && telegram.canSharePreparedMessage()) {
        const sent = await telegram.sharePreparedMessage(prepared.preparedId);
        if (sent) {
          metrikaGoal('invite_share');
          this._toast(RU.earnInviteShared, { accent: '#7EE0FF', flyTo: 'none' });
        }
        return;
      }
      if (prepared?.sentToChat) {
        telegram.openBotChat();
        metrikaGoal('invite_share');
        this._toast(RU.earnInviteForwardFromBot, { accent: '#7EE0FF', flyTo: 'none' });
        return;
      }
      const url = prepared?.inviteUrl || telegram.inviteShareUrl();
      let blob = null;
      try {
        blob = await makeInviteShareBlob({
          playerName: telegram.playerName,
          timeSec,
          bonus,
        });
      } catch (err) {
        console.warn('invite card', err);
      }
      await telegram.share(`${text}\n\n${RU.earnInviteLinkLabel}`, url, blob);
      metrikaGoal('invite_share');
      this._toast(RU.earnInviteShared, { accent: '#7EE0FF', flyTo: 'none' });
    } finally {
      this._inviteBusy = false;
      const live = this.body.querySelector('.earn-share-btn') || button;
      this._setShareBusy(live, false);
    }
  }

  async _enableNotifications() {
    const e = this._economy();
    if (!telegram.user?.id) {
      this._toast(RU.earnNotificationsNeedTelegram, { accent: '#FFC857', flyTo: 'none' });
      return;
    }
    const granted = await telegram.requestWriteAccess();
    if (!granted) {
      this._toast(
        e.isEarnClaimed('enable_notifications') ? RU.earnNotificationsAlready : RU.earnNotificationsNeedGrant,
        { accent: '#FFC857', flyTo: 'none' },
      );
      return;
    }
    const result = await e.grantWriteAccess();
    if (result.reward != null) {
      this._toast(RU.crystalsPlus(result.reward), { accent: '#7EE0FF', flyTo: 'crystals' });
      this.app._updateHud();
    } else {
      this._toast(RU.earnNotificationsAlready, { accent: '#7EE0FF', flyTo: 'none' });
    }
    this._renderCrystals(3);
  }

  _escText(value) {
    return String(value ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  _renderInvitedList(e) {
    const people = e.invitedFriends || [];
    const per = e.inviteRewardPerFriend;
    const items = people.length
      ? people
          .map((p) => {
            const name = this._escText(p.name || 'Игрок');
            const nick = p.username ? this._escText(p.username) : '';
            const photo = p.photoUrl ? this._escText(p.photoUrl) : '';
            const avatar = photo
              ? `<img src="${photo}" class="earn-invite-avatar" alt="">`
              : restingCubeImg(22, 'earn-invite-cube');
            return `
            <div class="earn-invite-person visited">
              ${avatar}
              <div class="earn-invite-who">
                <div class="earn-invite-name">${name}</div>
                <div class="earn-invite-meta">
                  ${nick ? `<span class="earn-invite-nick">${nick}</span>` : ''}
                  <span class="earn-invite-status">${RU.earnInviteVisited}</span>
                </div>
              </div>
              <span class="earn-invite-trail">
                <span class="earn-check">${checkMarkHtml(18)}</span>
                ${rewardBadge(per)}
              </span>
            </div>`;
          })
          .join('')
      : `<div class="earn-invite-empty">${RU.earnInviteWaiting}</div>`;

    const count = people.length ? ` · ${people.length}` : '';
    return `
      <div class="earn-invite-list">
        <div class="earn-invite-list-title">${RU.earnInviteListTitle}${count}</div>
        ${items}
      </div>`;
  }

  _renderEarnPane(e) {
    const hiddenEarn = new Set(['watch_ad', 'rate_app', 'social_post']);
    const actions = e.earnActions.filter((a) => !hiddenEarn.has(a.id));
    const rows = actions
      .map((a) => {
        const isInvite = a.id === 'invite_friend';
        const done = !isInvite && e.isEarnClaimed(a.id);
        const unlocked = e.isEarnUnlocked(a.id);
        const locked = !isInvite && !done && !unlocked;
        const alwaysOpen = isInvite || a.id === 'enable_notifications';
        let trailing = rewardBadge(a.reward);
        if (done) {
          trailing = `<span class="earn-done">${checkMarkHtml(18)}${rewardBadge(a.reward)}</span>`;
        } else if (locked) {
          trailing = `<span class="earn-lock">${uiIconImg('lock', 18)}</span>`;
        }

        let sub = locked ? RU.earnBonusLocked : earnSubtitle(a.id);
        if (isInvite) sub = RU.earnInviteFriendSub(e.inviteRewardPerFriend);

        const clickable = alwaysOpen || (!done && !locked);
        const accent = isInvite ? 'accent-warn' : done ? 'accent-mint' : unlocked && !done ? 'accent-warn' : '';
        const card = isInvite
          ? `
        <div class="game-panel mb-6 ${accent} earn-panel earn-invite-card">
          <div class="earn-row">
            <div class="earn-text">
              <div class="t1">${earnTitle(a.id)}</div>
              <div class="t2">${sub}</div>
            </div>
            ${rewardBadge(e.inviteRewardPerFriend)}
          </div>
          <button type="button" class="earn-share-btn" data-earn="invite_friend">${RU.shareSocial}</button>
        </div>`
          : `
        <div class="game-panel mb-6 ${accent} earn-panel ${locked ? 'locked' : ''}" data-earn="${a.id}" style="cursor:${clickable ? 'pointer' : 'default'}">
          <div class="earn-row ${locked ? 'locked' : ''}">
            <div class="earn-text">
              <div class="t1">${earnTitle(a.id)}</div>
              <div class="t2">${sub}</div>
            </div>
            ${trailing}
          </div>
        </div>`;
        return isInvite ? `${card}${this._renderInvitedList(e)}` : card;
      })
      .join('');

    return `<div class="tab-pane tab-pane-earn"><p class="earn-hint">${RU.earnPreviewHint}</p>${rows}</div>`;
  }

  _renderPlus() {
    const e = this._economy();
    const plus = e.plusProduct;
    const price = subscribePriceLabel(plus);
    const active = e.hasPremium;
    const next = e.premiumNextChargeDate ?? new Date(Date.now() + plus.days * 86400000);

    this.body.innerHTML = `
      <div class="plus-sheet">
        <button type="button" class="plus-back" id="plus-back">← ${RU.plusBack}</button>
        <div class="plus-head">
          <span class="plus-premium-ico">${uiIconImg('premium', 22)}</span>
          <h2 class="plus-head-title">${active ? RU.plusManageTitle : RU.plusOfferTitle}</h2>
          ${active ? `<span class="plus-head-check">${checkMarkHtml(20)}</span>` : ''}
        </div>
        <div class="plus-subtitle mint">${RU.plusTitle}</div>
        <p class="plus-desc">${active ? RU.plusManageSubtitle : RU.plusOfferSubtitle(plus.days)}</p>
        <div class="game-panel accent-mint mb-10 plus-benefits">
          <div class="plus-benefit">
            <span class="plus-benefit-ico">${uiIconImg('sparkle', 18)}</span>
            <span>${RU.plusManageBenefitDaily}</span>
            <span class="plus-benefit-trail">${crystalImg(14)} ×2</span>
          </div>
          <div class="plus-benefit">
            <span class="plus-benefit-ico">${uiIconImg('no-ads', 18)}</span>
            <span>${RU.plusManageBenefitAds}</span>
          </div>
        </div>
        <div class="game-panel mb-10 plus-price-panel">
          <div class="plus-price-line">${RU.plusManagePrice(price)}</div>
          ${active ? `<div class="plus-next-charge">${RU.plusManageNextCharge(fmtChargeDate(next))}</div>` : ''}
        </div>
        ${active
          ? `<button type="button" class="plus-btn cancel" id="plus-cancel">${RU.plusCancel}</button>`
          : `<button type="button" class="plus-btn subscribe" id="plus-subscribe">${RU.plusSubscribe(price)}</button>`}
      </div>`;

    this.body.querySelector('#plus-back')?.addEventListener('click', () => this._returnFromPlus());
    this.body.querySelector('#plus-subscribe')?.addEventListener('click', () => this._buyStars(plus.id));
    this.body.querySelector('#plus-cancel')?.addEventListener('click', () => {
      this._toast(RU.plusCancelInTelegram, { accent: '#7EE0FF', flyTo: 'none' });
    });
  }

  async _buyStars(productId) {
    if (this._buyingStars) return;
    const e = this._economy();
    if (!telegram.initData) {
      this._toast(RU.shopPayNeedTelegram, { accent: '#FFC857', flyTo: 'none' });
      return;
    }
    this._buyingStars = true;
    this._toast(RU.shopPayWait, { accent: '#7EE0FF', flyTo: 'none' });
    try {
      const invoice = await e.createStarsInvoice(productId);
      const status = await telegram.openInvoice(invoice.invoiceUrl);
      if (status === 'cancelled') {
        this._toast(RU.shopPayCancelled, { accent: '#ffffff88', flyTo: 'none' });
        return;
      }
      if (status === 'failed') {
        this._toast(RU.shopPayFailed, { accent: '#FF5A5F', flyTo: 'none' });
        return;
      }
      this._toast(RU.shopPayPending, { accent: '#7EE0FF', flyTo: 'none' });
      const expectPlus = productId === e.plusProduct.id;
      const expectCrystals = expectPlus ? 0 : (invoice.crystals || 0);
      const applied = await e.waitForWalletUpdate({ expectCrystals, expectPlus });
      this.app._updateHud();
      if (applied?.crystalsDelta > 0) {
        this._toast(RU.shopPaidCrystals(applied.crystalsDelta), { accent: '#3DDC97', flyTo: 'crystals' });
      } else if (applied?.plusActivated || (expectPlus && e.hasPremium)) {
        this._toast(RU.shopPaidPlus(e.plusProduct.days), { accent: '#3DDC97', flyTo: 'none' });
      } else if (status === 'paid') {
        this._toast(RU.shopPayPending, { accent: '#FFC857', flyTo: 'none' });
      }
      if (this._type === 'plus') this._renderPlus();
      else if (this._type === 'crystals') this._renderCrystals(this._tab);
    } catch (err) {
      console.warn('buyStars', err);
      this._toast(err?.message || RU.shopPayFailed, { accent: '#FF5A5F', flyTo: 'none' });
    } finally {
      this._buyingStars = false;
    }
  }

  _refreshLeaderboardFromServer() {
    this._economy().syncCommunityScores(() => {
      this._lbLoading = false;
      if (this.isOpen && this._type === 'leaderboard') {
        this._renderLeaderboard();
      }
    });
  }

  _renderLeaderboard() {
    const e = this._economy();
    const playerName = e.effectivePlayerName || telegram.playerName || 'Игрок';
    const userPhoto = telegram.userPhotoUrl;
    const filter = this._lbFilter || 'day';

    const PERIODS = [
      { id: 'all', label: RU.periodAll },
      { id: 'month', label: RU.periodMonth },
      { id: 'week', label: RU.periodWeek },
      { id: 'day', label: RU.periodDay },
    ];

    const menuHtml = `
      <div class="lb-menu-container">
        <div class="lb-menu-group">
          <button type="button" class="lb-tab-btn ${filter === 'all' ? 'active' : ''}" data-lb-filter="all">Всё время</button>
          <button type="button" class="lb-tab-btn ${filter === 'month' ? 'active' : ''}" data-lb-filter="month">Месяц</button>
          <button type="button" class="lb-tab-btn ${filter === 'week' ? 'active' : ''}" data-lb-filter="week">Неделя</button>
          <button type="button" class="lb-tab-btn ${filter === 'day' ? 'active' : ''}" data-lb-filter="day">День</button>
        </div>
        <div class="lb-menu-sep" aria-hidden="true"></div>
        <button type="button" class="lb-tab-btn lb-tab-mine ${filter === 'mine' ? 'active' : ''}" data-lb-filter="mine" title="Мои попытки">
          <span class="lb-mine-short">Мои</span>
          <span class="lb-mine-full">Мои попытки</span>
        </button>
      </div>`;

    const tableHeaderHtml = `
      <div class="lb-table-header">
        <span class="lb-th col-rank">${RU.colRank || '#'}</span>
        <span class="lb-th col-user">Игрок / Попытка</span>
        <span class="lb-th col-boosts">Бусты</span>
        <span class="lb-th col-time">Время / Очки</span>
      </div>`;

    const entries = e.getAttemptsForPeriod(filter);
    let contentHtml = '';

    if (entries.length === 0) {
      contentHtml = `<div class="lb-empty">${this._lbLoading ? RU.leaderboardLoading : RU.emptyPeriodRecords}</div>`;
    } else {
      contentHtml = `
        <div class="lb-attempts-list">
          ${entries
            .slice(0, 50)
            .map((att, idx) => {
              const rank = idx + 1;
              const isMineView = filter === 'mine';
              const rankClass = isMineView
                ? ''
                : (rank === 1 ? 'top-1' : rank === 2 ? 'top-2' : rank === 3 ? 'top-3' : '');
              const rankLabel = isMineView
                ? `#${rank}`
                : (rank === 1 ? '🥇' : rank === 2 ? '🥈' : rank === 3 ? '🥉' : `#${rank}`);
              const timeStr = fmtMs3(att.timeMs);
              const score = att.score != null ? att.score : calcScore(att.timeMs, att.runDistance, att.riskCount);
              const isMe = Boolean(att.isMe) ||
                (att.userId != null && telegram.user?.id != null && String(att.userId) === String(telegram.user.id)) ||
                (att.username != null && telegram.user?.username != null && att.username.toLowerCase() === `@${telegram.user.username.toLowerCase().replace(/^@/, '')}`) ||
                (att.playerName === playerName && att.playerName !== 'Игрок');
              const nameToDisplay = isMe ? playerName : (att.playerName || 'Игрок');

              const showTg = isMe
                ? (!e.hideTelegramUsername && telegram.user?.username ? `@${telegram.user.username.replace(/^@/, '')}` : null)
                : (att.username && !att.hideTelegram ? att.username : null);

              const d = new Date(att.createdAt || Date.now());
              const day = String(d.getDate()).padStart(2, '0');
              const month = String(d.getMonth() + 1).padStart(2, '0');
              const hours = String(d.getHours()).padStart(2, '0');
              const mins = String(d.getMinutes()).padStart(2, '0');
              const dateShort = `${day}.${month} ${hours}:${mins}`;

              const hadJump = Boolean(att.hadJump);
              const hadHelmet = Boolean(att.hadHelmet);

              return `
                <div class="lb-card ${isMe && !isMineView ? 'is-me' : ''} ${rankClass}" data-attempt-idx="${idx}">
                  <div class="lb-card-rank ${rankClass}">${rankLabel}</div>
                  <div class="lb-card-player-col">
                    <div class="lb-card-user-line">
                      <span class="lb-card-username ${isMe && !isMineView ? 'is-me' : ''}">${nameToDisplay}</span>
                      ${showTg ? `<span class="lb-card-tg-pill">${showTg}</span>` : ''}
                    </div>
                    <div class="lb-card-run-meta">${dateShort} · 🏃 ${att.runDistance || 0} · ⚡ ${att.riskCount || 0}</div>
                  </div>
                  <div class="lb-card-boosts" title="Бусты">
                    <span class="lb-boost ${hadJump ? 'jump-on' : 'boost-off'}" title="${hadJump ? 'Прыжок' : 'Без прыжка'}">
                      ${JUMP_BOOST_SVG}
                    </span>
                    <span class="lb-boost ${hadHelmet ? 'helmet-on' : 'boost-off'}" title="${hadHelmet ? 'Шлем' : 'Без шлема'}">
                      ${HELMET_BOOST_SVG}
                    </span>
                  </div>
                  <div class="lb-card-result-col">
                    <div class="lb-card-time">${timeStr}</div>
                    <div class="lb-card-score-badge">🎯 ${fmtScore(score)}</div>
                  </div>
                </div>`;
            })
            .join('')}
        </div>`;
    }

    const headerHtml = `
      <div class="lb-header">
        <div class="lb-title-wrap">
          <span class="lb-title-icon">🏆</span>
          <h2>${RU.leaderboardTitle}</h2>
        </div>
        <div class="lb-user-chip">
          ${userPhoto ? `<img src="${userPhoto}" class="lb-user-avatar" alt="">` : restingCubeImg(15, 'lb-user-cube')}
          <span class="lb-user-name">${playerName}</span>
        </div>
      </div>`;

    this.body.innerHTML = `
      <div class="leaderboard-sheet">
        ${headerHtml}
        ${menuHtml}
        <div class="lb-content-panel">
          ${tableHeaderHtml}
          <div class="leaderboard-sheet-scroll">
            ${contentHtml}
          </div>
          <button type="button" class="lb-scroll-top-btn" id="lb-scroll-top-btn" aria-label="Вверх к 1 месту" title="Вверх к 1 месту">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="18 15 12 9 6 15"></polyline>
            </svg>
            <span>Вверх</span>
          </button>
        </div>
        <div class="lb-actions">
          <button type="button" class="lb-play-btn" id="lb-play-again">${RU.playAgain}</button>
        </div>
      </div>`;

    // Скролл-контейнер и плавающая кнопка "Вверх"
    const scrollContainer = this.body.querySelector('.leaderboard-sheet-scroll');
    const scrollTopBtn = this.body.querySelector('#lb-scroll-top-btn');

    if (scrollContainer && scrollTopBtn) {
      scrollContainer.addEventListener('scroll', () => {
        if (scrollContainer.scrollTop > 55) {
          scrollTopBtn.classList.add('visible');
        } else {
          scrollTopBtn.classList.remove('visible');
        }
      });

      scrollTopBtn.addEventListener('click', (ev) => {
        ev.stopPropagation();
        telegram.haptic('impact', 'light');
        scrollContainer.scrollTo({ top: 0, behavior: 'smooth' });
      });
    }

    // Автопрокрутка к моему рекорду (чтобы он был виден на экране, даже если на 50 месте)
    if (filter !== 'mine' && scrollContainer) {
      const myCard = scrollContainer.querySelector('.lb-card.is-me');
      if (myCard) {
        setTimeout(() => {
          const cRect = scrollContainer.getBoundingClientRect();
          const cardRect = myCard.getBoundingClientRect();
          const relTop = cardRect.top - cRect.top + scrollContainer.scrollTop;
          const targetScroll = Math.max(0, relTop - (cRect.height / 2) + (cardRect.height / 2));
          if (targetScroll > 40) {
            scrollContainer.scrollTo({ top: targetScroll, behavior: 'smooth' });
            scrollTopBtn?.classList.add('visible');
          }
        }, 75);
      }
    }

    this.body.querySelectorAll('[data-lb-filter]').forEach((btn) => {
      btn.addEventListener('click', () => {
        this._lbFilter = btn.dataset.lbFilter;
        this._renderLeaderboard();
      });
    });

    this.body.querySelectorAll('.lb-card').forEach((card) => {
      card.addEventListener('click', () => {
        const idx = parseInt(card.dataset.attemptIdx, 10);
        const att = entries[idx];
        if (!att) return;
        const rank = idx + 1;
        const rankLabel = rank === 1 ? '🥇 1 место' : rank === 2 ? '🥈 2 место' : rank === 3 ? '🥉 3 место' : `#${rank} в рейтинге`;
        this._showPlayerModal(att, rankLabel, filter);
      });
    });

    this.body.querySelector('#lb-play-again')?.addEventListener('click', () => {
      this.close();
    });
  }

  _showPlayerModal(att, rankLabel, filter) {
    telegram.haptic('impact', 'medium');
    const existing = this.body.querySelector('.player-modal-backdrop');
    if (existing) existing.remove();

    const e = this._economy();
    const myPlayerName = e.effectivePlayerName || telegram.playerName || 'Игрок';
    const isMe = Boolean(att.isMe) ||
      (att.userId != null && telegram.user?.id != null && String(att.userId) === String(telegram.user.id)) ||
      (att.playerName === myPlayerName && att.playerName !== 'Игрок');

    const gameNick = isMe ? myPlayerName : (att.playerName || 'Игрок');
    const showTg = isMe
      ? (!e.hideTelegramUsername && telegram.user?.username ? `@${telegram.user.username.replace(/^@/, '')}` : null)
      : (att.username && !att.hideTelegram ? att.username : null);

    const photoUrl = att.photoUrl || (isMe ? telegram.userPhotoUrl : null);

    const timeStr = fmtMs3(att.timeMs);
    const d = new Date(att.createdAt || Date.now());
    const dateFormatted = `${String(d.getDate()).padStart(2, '0')}.${String(d.getMonth() + 1).padStart(2, '0')}.${d.getFullYear()} в ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;

    const score = att.score != null ? att.score : calcScore(att.timeMs, att.runDistance, att.riskCount);
    const filterName = filter === 'day' ? 'за сегодня' : filter === 'week' ? 'за неделю' : filter === 'month' ? 'за месяц' : filter === 'all' ? 'за всё время' : 'в истории';

    const modalHtml = `
      <div class="player-modal-backdrop">
        <div class="player-modal-card">
          <button type="button" class="player-modal-close" aria-label="Закрыть">✕</button>

          <div class="player-modal-header">
            <div class="player-modal-avatar-wrap">
              ${photoUrl ? `<img src="${photoUrl}" class="player-modal-avatar" alt="">` : restingCubeImg(40, 'player-modal-cube')}
            </div>
            <div class="player-modal-identity">
              <h3 class="player-modal-name">${gameNick}</h3>
              ${showTg ? `<div class="player-modal-username">${showTg}</div>` : ''}
            </div>
          </div>

          <div class="player-modal-score-box">
            <div class="player-modal-time-wrap">
              <span class="player-modal-score-label">Рекорд ${filterName}:</span>
              <span class="player-modal-time">${timeStr}</span>
            </div>
            <div class="player-modal-rank-badge">${rankLabel}</div>
          </div>

          <div class="player-modal-points-badge">
            <span class="modal-pts-label">🎯 ОЧКИ ПОПЫТКИ:</span>
            <span class="modal-pts-val">${fmtScore(score)}</span>
            ${(att.riskCount || 0) > 0 ? `<span class="modal-pts-mult">×${1 + (att.riskCount || 0)} за риски</span>` : ''}
          </div>

          <div class="player-modal-stats-grid">
            <button type="button" class="player-modal-stat-item" data-tip="run" aria-label="Шаги — подробнее">
              <span class="stat-icon">🏃</span>
              <div class="stat-text">
                <span class="stat-value">${att.runDistance || 0}</span>
                <span class="stat-label">Шаги</span>
              </div>
            </button>
            <button type="button" class="player-modal-stat-item" data-tip="risk" aria-label="Риск — подробнее">
              <span class="stat-icon">⚡</span>
              <div class="stat-text">
                <span class="stat-value">${att.riskCount || 0}</span>
                <span class="stat-label">Риски</span>
              </div>
            </button>
            <button type="button" class="player-modal-stat-item" data-tip="jump" aria-label="Прыжок — подробнее">
              <span class="stat-icon">🦘</span>
              <div class="stat-text">
                <span class="stat-value ${att.hadJump ? 'boost-active' : ''}">${att.hadJump ? 'Включен ✓' : 'Нет'}</span>
                <span class="stat-label">Прыжок</span>
              </div>
            </button>
            <button type="button" class="player-modal-stat-item" data-tip="helmet" aria-label="Шлем — подробнее">
              <span class="stat-icon">🛡️</span>
              <div class="stat-text">
                <span class="stat-value ${att.hadHelmet ? 'boost-active' : ''}">${att.hadHelmet ? 'Включен ✓' : 'Нет'}</span>
                <span class="stat-label">Шлем</span>
              </div>
            </button>
          </div>

          <div class="player-modal-date-line">Установлен: ${dateFormatted}</div>

          <div class="player-modal-actions">
            ${isMe ? `
              <div class="player-modal-self-pill">Это ваш личный результат</div>
            ` : ''}
            <button type="button" class="player-modal-dismiss-btn" id="player-modal-dismiss">Закрыть</button>
          </div>
        </div>
      </div>`;

    this.body.insertAdjacentHTML('beforeend', modalHtml);

    const backdrop = this.body.querySelector('.player-modal-backdrop');
    const closeBtn = backdrop?.querySelector('.player-modal-close');
    const dismissBtn = backdrop?.querySelector('#player-modal-dismiss');
    const tipEls = [...(backdrop?.querySelectorAll('[data-tip]') || [])];

    const closeModal = () => {
      unbindGameTips(tipEls);
      hideGameTip();
      backdrop?.classList.add('closing');
      setTimeout(() => backdrop?.remove(), 160);
    };

    closeBtn?.addEventListener('click', closeModal);
    dismissBtn?.addEventListener('click', closeModal);
    backdrop?.addEventListener('click', (ev) => {
      if (ev.target === backdrop) closeModal();
    });

    const ec = e.e || {};
    const riskEvery = Math.max(1, ec.riskRewardEvery ?? 5);
    const riskReward = ec.riskRewardTokens ?? 1;
    const runEvery = Math.max(1, ec.runRewardEvery ?? 200);
    const runReward = ec.runRewardTokens ?? 1;
    const tipBy = (id) => backdrop?.querySelector(`[data-tip="${id}"]`);
    bindGameTips(
      [
        {
          id: 'lb-run',
          el: tipBy('run'),
          accent: '#7ee0ff',
          body: RU.runTipHow,
          foot: RU.runTipConvert(runEvery, runReward > 0 ? runReward : 1),
        },
        {
          id: 'lb-risk',
          el: tipBy('risk'),
          accent: '#ffc107',
          body: RU.riskTipHow,
          foot: RU.riskTipConvert(riskEvery, riskReward > 0 ? riskReward : 1),
        },
        {
          id: 'lb-jump',
          el: tipBy('jump'),
          accent: '#3ddc97',
          body: RU.jumpTipHow,
          foot: RU.jumpTipState(Boolean(att.hadJump)),
        },
        {
          id: 'lb-helmet',
          el: tipBy('helmet'),
          accent: '#7ee0ff',
          body: RU.helmetTipHow,
          foot: RU.helmetTipState(Boolean(att.hadHelmet)),
        },
      ],
      { haptic: () => telegram.haptic('impact', 'light') },
    );
  }

  _renderShare() {
    const timeMs = this._opts?.timeMs ?? this.app.resultMs ?? this.app.aliveMs ?? 0;
    const run = this._opts?.run ?? this.app.resultRun ?? 0;
    const risk = this._opts?.risk ?? this.app.resultRisk ?? 0;
    const timeSec = (timeMs / 1000).toFixed(2);
    const botUrl = RU.shareBotUrl || 'https://t.me/UntouchGameBot';
    const scoreVal = calcScore(timeMs, run, risk);
    const text = `🔥 Я продержался ${timeSec} сек и набрал ${fmtScore(scoreVal)} очков в Untouch! Сможешь побить мой рекорд?`;

    this.body.innerHTML = `
      <div class="share-sheet">
        <div class="sheet-title-block">
          <h2>${RU.shareCardTitle}</h2>
        </div>
        <div class="share-sheet-scroll">
          <canvas id="share-card-canvas" class="share-card-canvas" width="800" height="800"></canvas>
          <img id="share-card-img" class="share-card-img" alt="Untouch Result" style="display:none;" draggable="false">
          <div class="share-card-hint">Удерживайте картинку, чтобы сохранить или скопировать</div>
        </div>
        <div class="share-actions">
          <button type="button" class="share-btn-primary" id="share-btn-send">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="22" y1="2" x2="11" y2="13"></line>
              <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
            </svg>
            ${RU.shareSendBtn}
          </button>
          <button type="button" class="share-btn-secondary" id="share-btn-download">
            <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
              <polyline points="7 10 12 15 17 10"></polyline>
              <line x1="12" y1="15" x2="12" y2="3"></line>
            </svg>
            ${RU.shareDownloadBtn}
          </button>
          <button type="button" class="share-btn-cancel" id="share-btn-close">
            ${RU.shareCancelBtn}
          </button>
        </div>
      </div>`;

    const canvas = this.body.querySelector('#share-card-canvas');
    const imgEl = this.body.querySelector('#share-card-img');

    const updateImgFromCanvas = () => {
      try {
        if (canvas && imgEl) {
          const dataUrl = canvas.toDataURL('image/png');
          imgEl.src = dataUrl;
          imgEl.style.display = 'block';
          canvas.style.display = 'none';
        }
      } catch (e) {
        console.warn('Canvas toDataURL failed', e);
      }
    };

    if (canvas && canvas.getContext) {
      drawShareCardCanvas(canvas, timeMs, run, risk, () => {
        updateImgFromCanvas();
      });
      updateImgFromCanvas();
    }

    this.body.querySelector('#share-btn-send')?.addEventListener('click', () => {
      if (canvas && canvas.toBlob) {
        canvas.toBlob((blob) => {
          telegram.share(text, botUrl, blob);
        }, 'image/png');
      } else {
        telegram.share(text, botUrl);
      }
    });

    this.body.querySelector('#share-btn-download')?.addEventListener('click', () => {
      if (!canvas) return;
      try {
        const dataUrl = canvas.toDataURL('image/png');
        const a = document.createElement('a');
        a.download = `untouch-record-${timeSec}s.png`;
        a.href = dataUrl;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        this._toast(RU.shareImageSavedToast || 'Картинка сохранена!', { accent: '#3DDC97', flyTo: 'none' });
      } catch (err) {
        console.warn('Canvas download failed', err);
      }
    });

    this.body.querySelector('#share-btn-close')?.addEventListener('click', () => {
      this.close();
    });
  }

  _renderProfile() {
    const e = this._economy();
    const user = telegram.user;
    const userPhoto = telegram.userPhotoUrl;
    const fullName = [user?.first_name, user?.last_name].filter(Boolean).join(' ') || (user?.username ? `@${user.username}` : 'Игрок Untouch');
    const tgUsername = user?.username ? `@${user.username.replace(/^@/, '')}` : null;
    let savedHideTg = Boolean(e.hideTelegramUsername);
    let savedNick = e.customNickname || (tgUsername || user?.first_name || 'Игрок');

    const allTimeBest = e.bestTimeMs;
    const dayBest = e.getBestForPeriod('day');
    const totalRuns = e.recentAttempts.length;

    this.body.innerHTML = `
      <div class="profile-sheet">
        <div class="profile-header">
          <div class="profile-title-wrap">
            <span class="profile-title-icon">👤</span>
            <h2>Профиль игрока</h2>
          </div>
          <button type="button" class="profile-close-btn" id="profile-close-btn" aria-label="Закрыть">✕</button>
        </div>

        <div class="profile-scroll-area">
          <!-- Блок аккаунта Telegram -->
          <div class="profile-card profile-account-card">
            <div class="profile-avatar-row">
              <div class="profile-avatar-wrap" id="profile-avatar-wrap">
                ${userPhoto ? `<img src="${userPhoto}" class="profile-avatar-img" alt="">` : restingCubeImg(44, 'profile-avatar-cube')}
              </div>
              <div class="profile-info-col">
                <div class="profile-fullname">${fullName}</div>
                <div class="profile-tg-row">
                  ${tgUsername ? `<span class="profile-tg-username ${savedHideTg ? 'hidden-nick' : ''}" id="profile-tg-username">${tgUsername}</span>` : '<span class="profile-no-tg">Без Telegram username</span>'}
                </div>
              </div>
            </div>

            <!-- Галочка: скрывать ник -->
            <label class="profile-privacy-toggle" for="profile-hide-tg-cb">
              <input type="checkbox" id="profile-hide-tg-cb" ${savedHideTg ? 'checked' : ''}>
              <span class="profile-toggle-box">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
              </span>
              <span class="profile-toggle-label">Скрывать Telegram-ник в рекордах</span>
            </label>
            <div class="profile-hint" id="profile-privacy-hint">
              ${savedHideTg ? '🔒 <span style="color:#ff8a80;font-weight:700;">Telegram-ник скрыт</span> (зачёркнут в профиле и скрыт в таблице лидеров)' : '🌐 Ваш @username отображается рядом с игровым ником'}
            </div>
          </div>

          <!-- Блок игрового ника -->
          <div class="profile-card profile-nickname-card">
            <label class="profile-field-title" for="profile-nick-input">Игровой ник</label>
            <div class="profile-input-wrap">
              <input type="text" class="profile-nick-input" id="profile-nick-input" maxlength="24" value="${savedNick}" placeholder="Ваш игровой ник">
            </div>
            <div class="profile-hint">
              Этот ник отображается в рекордах. По умолчанию совпадает с Telegram-ником, но вы можете указать свой.
            </div>
          </div>

          <div class="profile-card profile-settings-card">
            <div class="profile-stats-title">${RU.profileSettings}</div>
            <label class="profile-privacy-toggle" for="profile-music-cb">
              <input type="checkbox" id="profile-music-cb" ${e.musicEnabled !== false ? 'checked' : ''}>
              <span class="profile-toggle-box">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
              </span>
              <span class="profile-toggle-label">${RU.profileMusic}</span>
            </label>
            <label class="profile-privacy-toggle" for="profile-haptic-cb">
              <input type="checkbox" id="profile-haptic-cb" ${e.hapticEnabled !== false ? 'checked' : ''}>
              <span class="profile-toggle-box">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
              </span>
              <span class="profile-toggle-label">${RU.profileHaptic}</span>
            </label>
            <label class="profile-switch" for="profile-theme-cb">
              <span class="profile-switch-copy">
                <span class="profile-switch-label">${RU.profileLightTheme}</span>
                <span class="profile-switch-hint">Светлый интерфейс и поле</span>
              </span>
              <input type="checkbox" id="profile-theme-cb" role="switch" ${e.lightTheme ? 'checked' : ''}>
              <span class="profile-switch-track" aria-hidden="true"></span>
            </label>
          </div>

          <!-- Личные рекорды (информативно) -->
          <div class="profile-card profile-stats-card">
            <div class="profile-stats-title">Личные рекорды</div>
            <div class="profile-stats-grid">
              <div class="profile-stat-box">
                <div class="profile-stat-icon">🏆</div>
                <div class="profile-stat-val">${allTimeBest > 0 ? fmtMs3(allTimeBest) : '0.000'}</div>
                <div class="profile-stat-lbl">Рекорд всё время</div>
              </div>
              <div class="profile-stat-box">
                <div class="profile-stat-icon">⭐</div>
                <div class="profile-stat-val">${dayBest > 0 ? fmtMs3(dayBest) : '0.000'}</div>
                <div class="profile-stat-lbl">Лучший за сегодня</div>
              </div>
              <div class="profile-stat-box">
                <div class="profile-stat-icon">⚡</div>
                <div class="profile-stat-val">${totalRuns}</div>
                <div class="profile-stat-lbl">Всего попыток</div>
              </div>
            </div>
          </div>
        </div>

        <div class="profile-bottom-actions">
          <button type="button" class="profile-action-btn is-done" id="profile-action-btn">Готово</button>
        </div>
      </div>`;

    const closeBtn = this.body.querySelector('#profile-close-btn');
    const actionBtn = this.body.querySelector('#profile-action-btn');
    const hideCb = this.body.querySelector('#profile-hide-tg-cb');
    const nickInput = this.body.querySelector('#profile-nick-input');
    const privacyHint = this.body.querySelector('#profile-privacy-hint');
    const tgSpan = this.body.querySelector('#profile-tg-username');

    closeBtn?.addEventListener('click', () => {
      telegram.haptic('impact', 'light');
      this.close();
    });

    const avatarWrap = this.body.querySelector('#profile-avatar-wrap');
    if (avatarWrap && e.avatarCheatEnabled) {
      avatarWrap.classList.add('is-cheat');
      let taps = 0;
      let lastTap = 0;
      avatarWrap.addEventListener('click', (ev) => {
        ev.preventDefault();
        ev.stopPropagation();
        const now = Date.now();
        if (now - lastTap > 2500) taps = 0;
        lastTap = now;
        taps += 1;
        if (taps < 5) return;
        taps = 0;
        const got = this._economy().grantAvatarCheat();
        if (got == null) return;
        this.app._updateHud();
        this._toast(RU.crystalsPlus(got), { accent: '#7EE0FF', flyTo: 'crystals' });
      });
    }

    // Защита от вылетания Telegram WebApp при клике в текстовое поле:
    nickInput?.addEventListener('touchstart', (ev) => {
      ev.stopPropagation();
    }, { passive: true });
    nickInput?.addEventListener('pointerdown', (ev) => {
      ev.stopPropagation();
    });

    nickInput?.addEventListener('focus', () => {
      this.panel?.classList.add('keyboard-open');
      window.scrollTo(0, 0);
      document.body.scrollTop = 0;
      setTimeout(() => {
        nickInput?.scrollIntoView({ block: 'center', behavior: 'smooth' });
      }, 120);
    });

    nickInput?.addEventListener('blur', () => {
      this.panel?.classList.remove('keyboard-open');
      window.scrollTo(0, 0);
      document.body.scrollTop = 0;
    });

    const getNickVal = () => (nickInput?.value || '').trim();
    const getHideVal = () => Boolean(hideCb?.checked);

    const hasChanges = () => {
      const nv = getNickVal();
      const hv = getHideVal();
      return (nv.length > 0 && nv !== savedNick) || (hv !== savedHideTg);
    };

    const updateActionBtnState = () => {
      if (!actionBtn) return;
      if (hasChanges()) {
        actionBtn.classList.remove('is-done');
        actionBtn.classList.add('is-save');
        actionBtn.textContent = 'Сохранить';
        actionBtn.disabled = false;
      } else {
        actionBtn.classList.remove('is-save');
        actionBtn.classList.add('is-done');
        actionBtn.textContent = 'Готово';
        actionBtn.disabled = false;
      }
    };

    // При клике на чекбокс скрытия Telegram-ника ник зачеркивается СРАЗУ
    const onTogglePrivacy = () => {
      telegram.haptic('impact', 'light');
      const isHidden = getHideVal();
      if (tgSpan) {
        tgSpan.classList.toggle('hidden-nick', isHidden);
      }
      if (privacyHint) {
        privacyHint.innerHTML = isHidden
          ? '🔒 <span style="color:#ff8a80;font-weight:700;">Telegram-ник скрыт</span> (зачёркнут в профиле и скрыт в таблице лидеров)'
          : '🌐 Ваш @username отображается рядом с игровым ником';
      }
      updateActionBtnState();
    };

    hideCb?.addEventListener('change', onTogglePrivacy);
    hideCb?.addEventListener('input', onTogglePrivacy);

    const musicCb = this.body.querySelector('#profile-music-cb');
    const hapticCb = this.body.querySelector('#profile-haptic-cb');
    const themeCb = this.body.querySelector('#profile-theme-cb');
    musicCb?.addEventListener('change', () => {
      const on = Boolean(musicCb.checked);
      e.updateDevicePrefs({ musicEnabled: on });
      this.app.audio?.setUserMusicEnabled(on);
      telegram.haptic('impact', 'light');
    });
    hapticCb?.addEventListener('change', () => {
      const on = Boolean(hapticCb.checked);
      e.updateDevicePrefs({ hapticEnabled: on });
      telegram.hapticEnabled = on;
      if (on) telegram.haptic('impact', 'light');
    });
    themeCb?.addEventListener('change', () => {
      const on = Boolean(themeCb.checked);
      e.updateDevicePrefs({ lightTheme: on });
      telegram.applyUiTheme(on);
      telegram.haptic('impact', 'light');
    });

    nickInput?.addEventListener('input', () => {
      updateActionBtnState();
    });

    const doSave = async () => {
      const newNick = getNickVal();
      if (!newNick) {
        this._toast('Ник не может быть пустым', { accent: '#ff5a5f' });
        nickInput?.focus();
        return;
      }
      const newHide = getHideVal();

      if (actionBtn) {
        actionBtn.disabled = true;
        actionBtn.textContent = 'Сохраняем...';
      }
      telegram.haptic('impact', 'medium');
      this._toast('Сохраняем профиль в базу...', { accent: '#ffd54f' });

      try {
        const remote = await e.updateProfile({
          customNickname: newNick,
          hideTelegramUsername: newHide,
        });
        savedNick = newNick;
        savedHideTg = newHide;
        telegram.haptic('notification', 'success');
        if (remote?.ok && remote?.source === 'mysql') {
          this._toast('Профиль сохранён в базу ✓', { accent: '#3DDC97' });
        } else if (remote?.ok) {
          this._toast('Профиль сохранён (резерв сервера) ✓', { accent: '#ffd54f' });
        } else if (remote?.local) {
          this._toast(
            `Сохранено на устройстве. Сервер: ${remote.error || 'нет ответа'}`,
            { accent: '#ffd54f' },
          );
        } else {
          this._toast('Профиль сохранён ✓', { accent: '#3DDC97' });
        }
        if (actionBtn) {
          actionBtn.textContent = 'Сохранено ✓';
        }
        this.app._updateHud();
        setTimeout(() => {
          this.close();
        }, 300);
      } catch (err) {
        console.warn('save profile failed', err);
        this._toast(
          `Ошибка сохранения: ${err?.message || 'неизвестная ошибка'}`,
          { accent: '#ff5a5f' },
        );
        updateActionBtnState();
      }
    };

    actionBtn?.addEventListener('click', async () => {
      if (hasChanges()) {
        await doSave();
      } else {
        telegram.haptic('impact', 'light');
        this.close();
      }
    });

    nickInput?.addEventListener('keydown', (ev) => {
      if (ev.key === 'Enter') {
        ev.preventDefault();
        nickInput.blur();
        if (hasChanges()) {
          doSave();
        }
      }
    });

    updateActionBtnState();
  }
}

let _appIconImg = null;
function getAppIconImage(onLoadCb) {
  if (typeof Image === 'undefined') return null;
  if (_appIconImg) {
    if (_appIconImg.complete && _appIconImg.naturalWidth > 0 && onLoadCb) {
      setTimeout(onLoadCb, 0);
    }
    return _appIconImg;
  }
  _appIconImg = new Image();
  _appIconImg.src = 'assets/branding/app_icon.png';
  if (onLoadCb) {
    _appIconImg.onload = onLoadCb;
  }
  return _appIconImg;
}

function drawRoundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function drawShareCardCanvas(canvas, timeMs, runDist = 0, riskCount = 0, onReadyCb = null) {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const w = canvas.width;
  const h = canvas.height;

  ctx.clearRect(0, 0, w, h);

  // 1. Clip outer rounded rect
  ctx.save();
  drawRoundRect(ctx, 0, 0, w, h, 44);
  ctx.clip();

  // 2. Background base fill
  ctx.fillStyle = '#0a1014';
  ctx.fillRect(0, 0, w, h);

  // 3. Draw app icon if loaded
  const iconImg = getAppIconImage(() => {
    drawShareCardCanvas(canvas, timeMs, runDist, riskCount, onReadyCb);
  });
  if (iconImg && iconImg.complete && iconImg.naturalWidth > 0) {
    ctx.drawImage(iconImg, 0, 0, w, h);
  }

  // 4. Vertical dark gradient overlay
  const vGrad = ctx.createLinearGradient(0, 0, 0, h);
  vGrad.addColorStop(0.0, 'rgba(10, 16, 20, 0.45)');
  vGrad.addColorStop(0.35, 'rgba(10, 16, 20, 0.35)');
  vGrad.addColorStop(0.62, 'rgba(7, 11, 14, 0.82)');
  vGrad.addColorStop(1.0, 'rgba(7, 11, 14, 0.96)');
  ctx.fillStyle = vGrad;
  ctx.fillRect(0, 0, w, h);

  // 5. Radial glow
  const rGrad = ctx.createRadialGradient(w / 2, h * 0.35, 10, w / 2, h * 0.35, w * 0.65);
  rGrad.addColorStop(0.0, 'rgba(126, 224, 255, 0.16)');
  rGrad.addColorStop(1.0, 'rgba(126, 224, 255, 0.0)');
  ctx.fillStyle = rGrad;
  ctx.fillRect(0, 0, w, h);

  // 6. Top Pill badge ("Untouch")
  const pillW = 210;
  const pillH = 46;
  const pillX = (w - pillW) / 2;
  const pillY = 46;
  drawRoundRect(ctx, pillX, pillY, pillW, pillH, pillH / 2);
  ctx.fillStyle = 'rgba(12, 18, 24, 0.78)';
  ctx.fill();
  ctx.strokeStyle = 'rgba(126, 224, 255, 0.45)';
  ctx.lineWidth = 2;
  ctx.stroke();

  // Hero cube inside pill
  const cubeSize = 22;
  const cubeX = pillX + 16;
  const cubeY = pillY + (pillH - cubeSize) / 2;
  drawRoundRect(ctx, cubeX, cubeY, cubeSize, cubeSize, 5);
  ctx.fillStyle = '#7EE0FF';
  ctx.fill();
  ctx.fillStyle = '#0E1419';
  ctx.beginPath();
  ctx.arc(cubeX + cubeSize * 0.35, cubeY + cubeSize * 0.42, 2, 0, Math.PI * 2);
  ctx.arc(cubeX + cubeSize * 0.65, cubeY + cubeSize * 0.42, 2, 0, Math.PI * 2);
  ctx.fill();

  // "Untouch" text inside pill
  ctx.font = '800 20px "Segoe UI", Roboto, system-ui, sans-serif';
  ctx.fillStyle = '#7EE0FF';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText('Untouch', cubeX + cubeSize + 10, pillY + pillH / 2 + 1);

  // 7. Large Time in Center
  const timeSec = (timeMs / 1000).toFixed(2);
  ctx.save();
  ctx.font = '900 112px "Segoe UI", Roboto, system-ui, sans-serif';
  ctx.fillStyle = '#3DDC97';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.shadowColor = 'rgba(0, 0, 0, 0.65)';
  ctx.shadowBlur = 16;
  ctx.shadowOffsetY = 6;
  ctx.fillText(timeSec, w / 2, 330);
  ctx.restore();

  // 8. "СЕКУНД" label
  ctx.font = '700 18px "Segoe UI", Roboto, system-ui, sans-serif';
  ctx.fillStyle = 'rgba(255, 255, 255, 0.72)';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('С Е К У Н Д', w / 2, 400);

  // 9. Boast message
  ctx.save();
  ctx.font = '800 30px "Segoe UI", Roboto, system-ui, sans-serif';
  ctx.fillStyle = '#F2F7FA';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.shadowColor = 'rgba(0, 0, 0, 0.6)';
  ctx.shadowBlur = 10;
  ctx.shadowOffsetY = 3;
  ctx.fillText(`Я продержался ${timeSec} сек в Untouch!`, w / 2, 490);

  ctx.font = '700 22px "Segoe UI", Roboto, system-ui, sans-serif';
  ctx.fillStyle = '#7EE0FF';
  ctx.fillText('Сможешь побить мой рекорд?', w / 2, 535);
  ctx.restore();

  // 10. Run / Risk stats pill
  const hasStats = runDist > 0 || riskCount > 0;
  if (hasStats) {
    const scoreVal = calcScore(timeMs, runDist, riskCount);
    const statsW = 340;
    const statsH = 38;
    const statsX = (w - statsW) / 2;
    const statsY = 590;
    drawRoundRect(ctx, statsX, statsY, statsW, statsH, 12);
    ctx.fillStyle = 'rgba(255, 255, 255, 0.07)';
    ctx.fill();
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.12)';
    ctx.lineWidth = 1;
    ctx.stroke();

    ctx.font = '700 15px "Segoe UI", Roboto, system-ui, sans-serif';
    ctx.fillStyle = 'rgba(255, 255, 255, 0.9)';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`🏃 ${Math.round(runDist)}   ⚡ ${riskCount}   🎯 ${fmtScore(scoreVal)} очков`, w / 2, statsY + statsH / 2);
  }

  // 11. Bot handle at bottom
  const botW = 360;
  const botH = 46;
  const botX = (w - botW) / 2;
  const botY = 690;
  drawRoundRect(ctx, botX, botY, botW, botH, botH / 2);
  ctx.fillStyle = 'rgba(126, 224, 255, 0.12)';
  ctx.fill();
  ctx.strokeStyle = 'rgba(126, 224, 255, 0.4)';
  ctx.lineWidth = 1.5;
  ctx.stroke();

  ctx.font = '800 18px "Segoe UI", Roboto, system-ui, sans-serif';
  ctx.fillStyle = '#B8F4FF';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('🤖 Играй в Telegram: @UntouchGameBot', w / 2, botY + botH / 2);

  // 12. Outer frame stroke
  ctx.restore(); // unclip
  ctx.save();
  drawRoundRect(ctx, 3, 3, w - 6, h - 6, 42);
  ctx.strokeStyle = 'rgba(126, 224, 255, 0.85)';
  ctx.lineWidth = 6;
  ctx.stroke();
  ctx.restore();

  if (onReadyCb) {
    onReadyCb();
  }
}

let _inviteCoverImg = null;

function getInviteCoverImage(onLoadCb) {
  if (typeof Image === 'undefined') return null;
  if (_inviteCoverImg) {
    if (_inviteCoverImg.complete && _inviteCoverImg.naturalWidth > 0 && onLoadCb) {
      setTimeout(onLoadCb, 0);
    }
    return _inviteCoverImg;
  }
  _inviteCoverImg = new Image();
  _inviteCoverImg.src = 'assets/branding/botfather_webapp_640x360.jpg';
  if (onLoadCb) _inviteCoverImg.onload = onLoadCb;
  return _inviteCoverImg;
}

function formatInviteBest(ms) {
  const n = Number(ms) || 0;
  if (n < 100) return '';
  const sec = n / 1000;
  if (sec >= 10) return String(Math.round(sec * 10) / 10).replace('.', ',');
  return sec.toFixed(1).replace('.', ',');
}

function drawInviteShareCanvas(canvas, opts = {}) {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const w = canvas.width;
  const h = canvas.height;
  const timeSec = opts.timeSec || '';
  const bonus = opts.bonus || 40;
  ctx.clearRect(0, 0, w, h);
  ctx.save();
  drawRoundRect(ctx, 0, 0, w, h, 36);
  ctx.clip();
  ctx.fillStyle = '#0a1014';
  ctx.fillRect(0, 0, w, h);

  const cover = getInviteCoverImage(() => drawInviteShareCanvas(canvas, opts));
  if (cover && cover.complete && cover.naturalWidth > 0) {
    const scale = Math.max(w / cover.naturalWidth, h / cover.naturalHeight);
    const dw = cover.naturalWidth * scale;
    const dh = cover.naturalHeight * scale;
    ctx.drawImage(cover, (w - dw) / 2, (h - dh) / 2, dw, dh);
  } else {
    const icon = getAppIconImage(() => drawInviteShareCanvas(canvas, opts));
    if (icon && icon.complete && icon.naturalWidth > 0) {
      ctx.drawImage(icon, 0, 0, w, h);
    }
  }

  const veil = ctx.createLinearGradient(0, 0, 0, h);
  veil.addColorStop(0, 'rgba(10, 16, 20, 0.28)');
  veil.addColorStop(0.45, 'rgba(10, 16, 20, 0.4)');
  veil.addColorStop(1, 'rgba(7, 11, 14, 0.92)');
  ctx.fillStyle = veil;
  ctx.fillRect(0, 0, w, h);

  ctx.font = '800 22px "Segoe UI", Roboto, system-ui, sans-serif';
  ctx.fillStyle = '#7EE0FF';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('UNTOUCH', w / 2, 64);

  ctx.font = '900 36px "Segoe UI", Roboto, system-ui, sans-serif';
  ctx.fillStyle = '#F2F7FA';
  ctx.fillText('Попробуй побить мой рекорд!', w / 2, 160);

  ctx.font = '800 26px "Segoe UI", Roboto, system-ui, sans-serif';
  ctx.fillStyle = '#FFC857';
  ctx.fillText(timeSec ? `Я продержался ${timeSec} сек` : 'Заходи — будет интересно', w / 2, 220);

  ctx.font = '700 20px "Segoe UI", Roboto, system-ui, sans-serif';
  ctx.fillStyle = '#3DDC97';
  ctx.fillText(`Новичкам бонус — ${bonus} кристаллов`, w / 2, 320);

  drawRoundRect(ctx, (w - 360) / 2, 400, 360, 48, 24);
  ctx.fillStyle = 'rgba(126, 224, 255, 0.14)';
  ctx.fill();
  ctx.strokeStyle = 'rgba(126, 224, 255, 0.45)';
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.font = '800 18px "Segoe UI", Roboto, system-ui, sans-serif';
  ctx.fillStyle = '#B8F4FF';
  ctx.fillText('Играть · @UntouchGameBot', w / 2, 424);

  ctx.restore();
}

function makeInviteShareBlob(opts = {}) {
  return new Promise((resolve) => {
    const canvas = document.createElement('canvas');
    canvas.width = 800;
    canvas.height = 500;
    const finish = () => {
      if (!canvas.toBlob) {
        resolve(null);
        return;
      }
      canvas.toBlob((blob) => resolve(blob), 'image/png');
    };
    const cover = getInviteCoverImage(() => {
      drawInviteShareCanvas(canvas, opts);
      finish();
    });
    drawInviteShareCanvas(canvas, opts);
    if (cover && cover.complete && cover.naturalWidth > 0) finish();
    else setTimeout(finish, 350);
  });
}
