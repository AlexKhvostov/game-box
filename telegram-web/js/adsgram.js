/** AdsGram rewarded + interstitial ads for Telegram Mini App. */

import { RU } from './strings-ru.js';

export function adsgramBlockId(config) {
  const id = String(config?.economy?.adsgramBlockId ?? '').trim();
  return id;
}

export function normalizeInterstitialBlockId(raw) {
  const id = String(raw ?? '').trim();
  if (!id) return '';
  if (/^int-/i.test(id)) return id;
  if (/^\d+$/.test(id)) return `int-${id}`;
  return id;
}

export function adsgramInterstitialBlockId(config) {
  return normalizeInterstitialBlockId(config?.economy?.adsgramInterstitialBlockId);
}

function adsgramSdk() {
  return typeof window !== 'undefined' ? window.Adsgram : null;
}

function showAdsgram(blockId) {
  return new Promise((resolve, reject) => {
    const id = String(blockId || '').trim();
    if (!id) {
      reject(Object.assign(new Error('NO_BLOCK'), { adFail: 'load' }));
      return;
    }
    const adsgram = adsgramSdk();
    if (!adsgram || typeof adsgram.init !== 'function') {
      reject(Object.assign(new Error('NO_SDK'), { adFail: 'load' }));
      return;
    }
    try {
      const ctrl = adsgram.init({ blockId: id });
      ctrl.show().then(resolve).catch((err) => {
        const desc = err && (err.description || err.error || err.state || err.message);
        const e = new Error(desc ? String(desc) : 'AD_FAILED');
        e.cause = err;
        e.adFail = classifyAdFail(e.message, err);
        reject(e);
      });
    } catch (err) {
      const e = err instanceof Error ? err : new Error('AD_FAILED');
      e.adFail = 'load';
      reject(e);
    }
  });
}

export function showRewardedAd(blockId) {
  return showAdsgram(blockId);
}

export function showInterstitialAd(blockId) {
  return showAdsgram(blockId);
}

export function classifyAdFail(message, cause) {
  const blob = `${message || ''} ${JSON.stringify(cause || {})}`.toLowerCase();
  if (/skip|close|cancel|user/.test(blob) && !/not active|no.?fill|load|network|timeout/.test(blob)) {
    return 'skip';
  }
  return 'load';
}

let stubBound = false;

function bindAdLoadStub() {
  if (stubBound) return;
  const overlay = document.getElementById('ad-fail-overlay');
  if (!overlay) return;
  stubBound = true;
  const hide = () => {
    overlay.hidden = true;
  };
  overlay.querySelector('#ad-fail-backdrop')?.addEventListener('click', hide);
  overlay.querySelector('#ad-fail-ok')?.addEventListener('click', hide);
}

export function showAdLoadStub() {
  bindAdLoadStub();
  const overlay = document.getElementById('ad-fail-overlay');
  if (!overlay) return;
  const title = overlay.querySelector('#ad-fail-title');
  const body = overlay.querySelector('#ad-fail-body');
  const ok = overlay.querySelector('#ad-fail-ok');
  if (title) title.textContent = RU.shopAdFailTitle;
  if (body) body.textContent = RU.shopAdFailBody;
  if (ok) ok.textContent = RU.shopAdFailOk;
  overlay.hidden = false;
}

let hintBound = false;
let hintResolver = null;

function finishWatchAdHint(ok) {
  const overlay = document.getElementById('ad-watch-hint');
  if (overlay) overlay.hidden = true;
  const skip = overlay?.querySelector('#ad-watch-hint-skip');
  const resolve = hintResolver;
  hintResolver = null;
  resolve?.({ ok: Boolean(ok), skipNext: Boolean(ok && skip?.checked) });
}

function bindWatchAdHint() {
  if (hintBound) return;
  const overlay = document.getElementById('ad-watch-hint');
  if (!overlay) return;
  hintBound = true;
  overlay.querySelector('#ad-watch-hint-backdrop')?.addEventListener('click', () => finishWatchAdHint(false));
  overlay.querySelector('#ad-watch-hint-cancel')?.addEventListener('click', () => finishWatchAdHint(false));
  overlay.querySelector('#ad-watch-hint-ok')?.addEventListener('click', () => finishWatchAdHint(true));
}

export function showWatchAdHint({ reward = 5 } = {}) {
  return new Promise((resolve) => {
    bindWatchAdHint();
    const overlay = document.getElementById('ad-watch-hint');
    if (!overlay) {
      resolve({ ok: true, skipNext: false });
      return;
    }
    if (hintResolver) finishWatchAdHint(false);
    hintResolver = resolve;
    const title = overlay.querySelector('#ad-watch-hint-title');
    const body = overlay.querySelector('.ad-hint-lead');
    const skipLabel = overlay.querySelector('#ad-watch-hint-skip-text');
    const cancel = overlay.querySelector('#ad-watch-hint-cancel');
    const ok = overlay.querySelector('#ad-watch-hint-ok');
    const rewardEl = overlay.querySelector('#ad-watch-hint-reward');
    const skip = overlay.querySelector('#ad-watch-hint-skip');
    if (title) title.textContent = RU.shopAdHintTitle;
    if (body) body.textContent = RU.shopAdHintBody;
    if (skipLabel) skipLabel.textContent = RU.shopAdHintSkip;
    if (cancel) cancel.textContent = RU.shopAdHintCancel;
    if (ok) ok.textContent = RU.shopAdHintOk;
    if (rewardEl) rewardEl.textContent = String(reward);
    if (skip) skip.checked = false;
    overlay.hidden = false;
  });
}
