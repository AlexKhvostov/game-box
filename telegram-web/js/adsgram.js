/** AdsGram rewarded ads for Telegram Mini App. */

import { RU } from './strings-ru.js';

export function adsgramBlockId(config) {
  const id = String(config?.economy?.adsgramBlockId ?? '').trim();
  return id;
}

export function showRewardedAd(blockId) {
  return new Promise((resolve, reject) => {
    const id = String(blockId || '').trim();
    if (!id) {
      reject(Object.assign(new Error('NO_BLOCK'), { adFail: 'load' }));
      return;
    }
    const adsgram = typeof window !== 'undefined' ? window.Adsgram : null;
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
