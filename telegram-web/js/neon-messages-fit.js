/* SafeArea/FittedBox presentation only. No message timers, flight targets or
   dismissal actions live here. Detached cards release all active observers. */
const peakScale = 1.2;
const gameCards = new WeakMap();
const tipCards = new WeakMap();
const ownedTipStyles = new WeakMap();
const roots = new Map();
let frameId = 0;

function write(node, property, value) {
  if (node.style.getPropertyValue(property) !== value) node.style.setProperty(property, value);
}

function insets() {
  const css = getComputedStyle(document.documentElement);
  const pixel = name => Math.max(0, parseFloat(css.getPropertyValue(name)) || 0);
  return { top: pixel('--tg-pad-top'), bottom: pixel('--tg-pad-bottom'), left: pixel('--tg-pad-left'), right: pixel('--tg-pad-right') };
}

function fitGame(card, presentation, safe) {
  const width = window.innerWidth, height = window.innerHeight;
  const freeWidth = Math.max(1, width - safe.left - safe.right - 16);
  const freeHeight = Math.max(1, height - safe.top - safe.bottom - 16);
  presentation.scale = Math.min(1, freeWidth / (peakScale * Math.max(1, card.offsetWidth)), freeHeight / (peakScale * Math.max(1, card.offsetHeight)));
  const halfWidth = card.offsetWidth * peakScale * presentation.scale / 2;
  const halfHeight = card.offsetHeight * peakScale * presentation.scale / 2;
  const clampX = x => Math.max(safe.left + 8 + halfWidth, Math.min(x, width - safe.right - 8 - halfWidth));
  const clampY = y => Math.max(safe.top + 8 + halfHeight, Math.min(y, height - safe.bottom - 8 - halfHeight));
  presentation.start.x = clampX(presentation.baseStart.x);
  presentation.start.y = clampY(presentation.baseStart.y);
  if (presentation.flyTo === 'none') {
    presentation.end.x = clampX(presentation.baseEnd.x);
    presentation.end.y = clampY(presentation.baseEnd.y);
  }
}

function fitSystem(card, safe) {
  const leaf = card.querySelector('.sys-toast-msg');
  if (!leaf) return;
  const css = getComputedStyle(card);
  const chrome = (parseFloat(css.paddingTop) || 0) + (parseFloat(css.paddingBottom) || 0) + (parseFloat(css.borderTopWidth) || 0) + (parseFloat(css.borderBottomWidth) || 0);
  const available = Math.max(1, window.innerHeight - safe.top - safe.bottom - 20 - chrome);
  const scale = Math.min(1, available / Math.max(1, leaf.offsetHeight));
  write(leaf, 'transform-origin', 'top center');
  write(leaf, 'transform', scale < 1 ? `scale(${scale})` : 'none');
  write(card, 'height', scale < 1 ? `${Math.ceil(leaf.offsetHeight * scale + chrome)}px` : '');
}

function fitTip(card, safe) {
  let placement = tipCards.get(card);
  const currentTop = card.style.top, currentLeft = card.style.left;
  if (!placement) {
    placement = { baseTop: parseFloat(currentTop) || 0, baseLeft: parseFloat(currentLeft) || 0, lastTop: '', lastLeft: '' };
    tipCards.set(card, placement);
  } else {
    if (currentTop !== placement.lastTop) placement.baseTop = parseFloat(currentTop) || 0;
    if (currentLeft !== placement.lastLeft) placement.baseLeft = parseFloat(currentLeft) || 0;
  }
  const top = Math.max(safe.top + 10, Math.min(placement.baseTop, window.innerHeight - safe.bottom - card.offsetHeight - 10));
  const left = Math.max(safe.left + 10, Math.min(placement.baseLeft, window.innerWidth - safe.right - card.offsetWidth - 10));
  write(card, 'top', `${top}px`);
  write(card, 'left', `${left}px`);
  placement.lastTop = card.style.top;
  placement.lastLeft = card.style.left;
  ownedTipStyles.set(card, card.style.cssText);
}

function isVisible(root) {
  return root.isConnected && !root.hidden && getComputedStyle(root).display !== 'none';
}

function fitAll() {
  frameId = 0;
  const safe = insets();
  for (const [root, state] of roots) {
    if (!isVisible(root)) continue;
    for (const card of state.cards) {
      if (!card.isConnected) continue;
      const game = gameCards.get(card);
      if (game) fitGame(card, game, safe);
      else if (card.matches('.sys-toast')) fitSystem(card, safe);
      else if (card.matches('.result-tip-pop-card')) fitTip(card, safe);
    }
  }
}

function schedule() {
  if (!frameId && [...roots.values()].some(state => state.cards.size)) frameId = requestAnimationFrame(fitAll);
}

function refresh(root, state) {
  const cards = isVisible(root) ? [...root.querySelectorAll('.fly-toast-card, .sys-toast, .result-tip-pop-card')] : [];
  state.resize.disconnect();
  state.cards.clear();
  for (const card of cards) {
    state.cards.add(card);
    state.resize.observe(card);
    for (const leaf of card.querySelectorAll('.fly-toast-msg, .sys-toast-msg, .result-tip-pop-body, .result-tip-pop-foot')) state.resize.observe(leaf);
  }
  if (cards.length) { state.resize.observe(root); schedule(); }
  else if (frameId && ![...roots.values()].some(other => other.cards.size)) {
    cancelAnimationFrame(frameId);
    frameId = 0;
  }
}

function scanRoots() {
  for (const [root, state] of roots) if (!root.isConnected) {
    state.mutation.disconnect();
    state.resize.disconnect();
    state.cards.clear();
    roots.delete(root);
  }
  for (const id of ['fly-toast-root', 'sys-toast-root', 'game-tip-pop']) {
    const root = document.getElementById(id);
    if (!root || roots.has(root)) continue;
    const state = { cards: new Set(), resize: new ResizeObserver(schedule), mutation: null };
    state.mutation = new MutationObserver(records => {
      if (records.every(record => record.type === 'attributes' && record.attributeName === 'style' && ownedTipStyles.get(record.target) === record.target.style.cssText)) return;
      if (id === 'game-tip-pop' && records.some(record => record.type === 'childList' || record.type === 'characterData' || (record.type === 'attributes' && record.attributeName === 'hidden' && record.target === root))) {
        for (const card of new Set([...state.cards, ...root.querySelectorAll('.result-tip-pop-card')])) {
          tipCards.delete(card);
          ownedTipStyles.delete(card);
        }
      }
      refresh(root, state);
    });
    // Card animation changes inline transform/opacity; never observe those.
    state.mutation.observe(root, { childList: true, characterData: true, subtree: true, attributes: true, attributeFilter: id === 'game-tip-pop' ? ['hidden', 'class', 'style'] : ['hidden', 'class'] });
    roots.set(root, state);
    refresh(root, state);
  }
  if (frameId && ![...roots.values()].some(state => state.cards.size)) {
    cancelAnimationFrame(frameId);
    frameId = 0;
  }
}

export function fitGameToast(card, start, end, flyTo) {
  const presentation = { scale: 1, start, end, flyTo, baseStart: { ...start }, baseEnd: { ...end } };
  gameCards.set(card, presentation);
  fitGame(card, presentation, insets());
  scanRoots();
  const root = card.parentElement;
  if (roots.has(root)) refresh(root, roots.get(root));
  return presentation;
}

const lifecycle = new MutationObserver(scanRoots);
lifecycle.observe(document.body, { childList: true });
// Telegram writes safe-area pixels on html only; this cannot observe animated
// card styles or the fitted leaf writes above.
const safeArea = new MutationObserver(schedule);
safeArea.observe(document.documentElement, { attributes: true, attributeFilter: ['style'] });
window.addEventListener('resize', schedule);
scanRoots();
