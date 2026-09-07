/** Порт lib/ui/game_toast.dart — вспышка и полёт к чипу HUD. */

const CRYSTAL_SVG = 'icons/crystal.svg';

function easeOutBack(t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  return 1 + c3 * (t - 1) ** 3 + c1 * (t - 1) ** 2;
}

function easeInCubic(t) {
  return t * t * t;
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function targetCenter(selector, fallback) {
  const node = document.querySelector(selector);
  if (!node) return fallback;
  const r = node.getBoundingClientRect();
  if (r.width <= 0) return fallback;
  return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
}

function ensureRoot() {
  let root = document.getElementById('fly-toast-root');
  if (!root) {
    root = document.createElement('div');
    root.id = 'fly-toast-root';
    root.setAttribute('aria-live', 'polite');
    document.body.appendChild(root);
  }
  return root;
}

/**
 * @param {object} opts
 * @param {string} opts.message
 * @param {string} [opts.accent]
 * @param {'none'|'crystals'|'lives'} [opts.flyTo]
 * @param {boolean} [opts.festive]
 * @param {'crystal'|'heart'} [opts.icon]
 */
export function showGameToast(opts) {
  const {
    message,
    accent = '#7EE0FF',
    flyTo = 'none',
    festive = false,
    icon = flyTo === 'lives' ? 'heart' : 'crystal',
  } = opts;

  const w = window.innerWidth;
  const h = window.innerHeight;
  const start = { x: w / 2, y: h * 0.3 };
  let end;
  if (flyTo === 'crystals') {
    end = targetCenter('#hud-crystals-chip', { x: 96, y: 52 });
  } else if (flyTo === 'lives') {
    end = targetCenter('#hud-lives-chip', { x: 36, y: 52 });
  } else {
    end = { x: w / 2, y: h * 0.14 };
  }

  const root = ensureRoot();
  const card = document.createElement('div');
  card.className = `fly-toast-card${festive ? ' festive' : ''}`;
  card.style.setProperty('--toast-accent', accent);

  const iconHtml =
    icon === 'heart'
      ? '<img src="icons/ui-heart.svg" width="28" height="28" alt="" class="fly-toast-icon heart" draggable="false">'
      : `<img src="${CRYSTAL_SVG}" width="28" height="28" alt="" class="fly-toast-icon crystal" draggable="false">`;

  card.innerHTML = `${iconHtml}<span class="fly-toast-msg">${message}</span>`;

  let burst = null;
  if (festive) {
    burst = document.createElement('canvas');
    burst.className = 'fly-toast-burst';
    burst.width = w;
    burst.height = h;
    root.appendChild(burst);
  }

  root.appendChild(card);

  const duration = festive ? 1100 : 920;
  const t0 = performance.now();

  function drawBurst(t) {
    if (!burst) return;
    const ctx = burst.getContext('2d');
    if (!ctx) return;
    ctx.clearRect(0, 0, w, h);
    if (t <= 0.02 || t > 0.75) return;
    const burstT = easeInCubic(Math.min(1, t / 0.45));
    const fade = 1 - Math.max(0, (t - 0.25) / 0.5);
    for (let i = 0; i < 18; i++) {
      const ang = (i / 18) * Math.PI * 2;
      const dist = 28 + burstT * (70 + (i % 3) * 18);
      const px = start.x + Math.cos(ang) * dist;
      const py = start.y + Math.sin(ang) * dist;
      ctx.beginPath();
      ctx.fillStyle = i % 2 === 0 ? accent : '#FFD54F';
      ctx.globalAlpha = 0.85 * fade;
      ctx.arc(px, py, 2.2 + (1 - burstT) * 2.5, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 0.16 * fade;
    ctx.beginPath();
    ctx.fillStyle = '#FFD54F';
    ctx.arc(start.x, start.y, 18 + burstT * 40, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  function frame(now) {
    const t = Math.min(1, (now - t0) / duration);
    const appear = Math.min(1, t / 0.22);
    const flyRaw = Math.max(0, Math.min(1, (t - 0.2) / 0.8));
    const fly = easeInCubic(flyRaw);
    const pop = easeOutBack(appear);
    const scale = 1.05 * pop * (1 - 0.72 * fly);
    const opacity =
      fly < 0.55 ? appear : appear * Math.max(0, 1 - (fly - 0.55) / 0.45);

    const x = lerp(start.x, end.x, fly);
    const y = lerp(start.y, end.y, fly);

    card.style.transform = `translate(${x}px, ${y}px) translate(-50%, -50%) scale(${Math.max(0.12, Math.min(1.2, scale))})`;
    card.style.opacity = String(opacity);

    drawBurst(t);

    if (t < 1) {
      requestAnimationFrame(frame);
    } else {
      if (flyTo === 'lives' || flyTo === 'crystals') {
        pulseHud(flyTo);
      }
      card.remove();
      burst?.remove();
    }
  }

  requestAnimationFrame(frame);
}

function pulseHud(flyTo) {
  const sel = flyTo === 'lives' ? '#hud-lives-chip' : '#hud-crystals-chip';
  const el = document.querySelector(sel);
  if (!el) return;
  el.classList.add('hud-pulse');
  setTimeout(() => el.classList.remove('hud-pulse'), 420);
}
