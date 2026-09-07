/** Compact anchored tooltip next to a control — not a blocking modal. */

let pop = null;
let card = null;
let bodyEl = null;
let footEl = null;
let kind = null;
let docHide = null;
const registry = new Map();

function ensurePop() {
  pop = document.getElementById('game-tip-pop');
  if (!pop) {
    pop = document.createElement('div');
    pop.id = 'game-tip-pop';
    pop.className = 'result-tip-pop';
    pop.hidden = true;
    pop.innerHTML =
      '<div class="result-tip-pop-card" id="game-tip-pop-card" role="tooltip">' +
      '<p class="result-tip-pop-body" id="game-tip-pop-body"></p>' +
      '<p class="result-tip-pop-foot" id="game-tip-pop-foot"></p>' +
      '</div>';
    document.body.appendChild(pop);
  }
  card = pop.querySelector('.result-tip-pop-card');
  bodyEl = pop.querySelector('.result-tip-pop-body');
  footEl = pop.querySelector('.result-tip-pop-foot');
}

function placeCard(anchor) {
  if (!card || !anchor) return;
  const pad = 10;
  const gap = 8;
  const ar = anchor.getBoundingClientRect();
  const cr = card.getBoundingClientRect();
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  let place = 'bottom';
  let top = ar.bottom + gap;
  if (top + cr.height > vh - pad) {
    top = Math.max(pad, ar.top - cr.height - gap);
    place = 'top';
  }
  let left = ar.left + ar.width / 2 - cr.width / 2;
  left = Math.max(pad, Math.min(left, vw - cr.width - pad));
  card.dataset.place = place;
  card.style.top = `${Math.round(top)}px`;
  card.style.left = `${Math.round(left)}px`;
  card.style.setProperty('--arrow-x', `${Math.round(ar.left + ar.width / 2 - left)}px`);
}

function clearSelected() {
  for (const it of registry.values()) it.el.classList.remove('selected');
}

export function hideGameTip() {
  if (pop) pop.hidden = true;
  kind = null;
  clearSelected();
}

function showItem(it, haptic) {
  ensurePop();
  if (kind === it.id && pop && !pop.hidden) {
    hideGameTip();
    return;
  }
  clearSelected();
  it.el.classList.add('selected');
  it.el.style.setProperty('--tip-accent', it.accent || '#7ee0ff');
  pop.style.setProperty('--tip-accent', it.accent || '#7ee0ff');
  bodyEl.textContent = it.body || '';
  if (it.foot) {
    footEl.hidden = false;
    footEl.textContent = it.foot;
  } else {
    footEl.hidden = true;
    footEl.textContent = '';
  }
  kind = it.id;
  pop.hidden = false;
  placeCard(it.el);
  requestAnimationFrame(() => placeCard(it.el));
  if (typeof haptic === 'function') haptic();
}

function ensureDocHide() {
  if (docHide) return;
  docHide = (ev) => {
    if (!pop || pop.hidden) return;
    const t = ev.target;
    if (card && card.contains(t)) return;
    for (const it of registry.values()) {
      if (it.el.contains(t)) return;
    }
    hideGameTip();
  };
  document.addEventListener('pointerdown', docHide, true);
}

/**
 * @param {Array<{ id: string, el: Element, accent?: string, body: string, foot?: string }>} items
 * @param {{ haptic?: Function }} [opts]
 */
export function bindGameTips(items, opts = {}) {
  ensurePop();
  ensureDocHide();
  hideGameTip();
  for (const it of items) {
    if (!it?.el) continue;
    registry.set(it.el, it);
    it.el.onclick = (ev) => {
      ev.stopPropagation();
      showItem(it, opts.haptic);
    };
  }
}

export function unbindGameTips(els) {
  for (const el of els || []) {
    if (!el) continue;
    registry.delete(el);
    el.onclick = null;
    el.classList.remove('selected');
  }
  hideGameTip();
}
