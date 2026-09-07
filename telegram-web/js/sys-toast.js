/** Системные уведомления (без кристалла, без полёта к HUD). */

let _active = null;

function ensureRoot() {
  let root = document.getElementById('sys-toast-root');
  if (!root) {
    root = document.createElement('div');
    root.id = 'sys-toast-root';
    root.className = 'sys-toast-root';
    root.setAttribute('aria-live', 'polite');
    document.body.appendChild(root);
  }
  return root;
}

function dismissActive(immediate = false) {
  if (!_active) return;
  const { el, timer, onTap } = _active;
  _active = null;
  if (timer) clearTimeout(timer);
  if (onTap) {
    document.removeEventListener('pointerdown', onTap, true);
    document.removeEventListener('touchstart', onTap, true);
  }
  if (!el) return;
  if (immediate) {
    el.remove();
    return;
  }
  el.classList.remove('visible');
  el.classList.add('leaving');
  setTimeout(() => el.remove(), 220);
}

/**
 * Короткая системная плашка сверху (~1 с), без кристалла.
 * Любой тап по экрану сразу растворяет её.
 * @param {object} opts
 * @param {string} opts.message
 * @param {string} [opts.accent]
 * @param {number} [opts.holdMs] сколько висит до растворения (по умолчанию 1000)
 */
export function showSystemNotice(opts) {
  const {
    message,
    accent = '#7EE0FF',
    holdMs = 1000,
  } = opts || {};

  dismissActive(true);

  const root = ensureRoot();
  const el = document.createElement('div');
  el.className = 'sys-toast';
  el.style.setProperty('--sys-accent', accent);
  el.innerHTML = `<span class="sys-toast-msg">${message}</span>`;
  root.appendChild(el);

  requestAnimationFrame(() => el.classList.add('visible'));

  const onTap = () => dismissActive(false);
  // capture: ловим тап раньше игровых обработчиков
  document.addEventListener('pointerdown', onTap, true);
  document.addEventListener('touchstart', onTap, true);

  const timer = setTimeout(() => dismissActive(false), Math.max(400, holdMs));
  _active = { el, timer, onTap };
}

export function dismissSystemNotice() {
  dismissActive(false);
}
