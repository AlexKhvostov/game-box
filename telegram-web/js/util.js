/** Shared math / color helpers (port of Flutter gameplay utils). */

export const PI = Math.PI;
export const TAU = PI * 2;

export function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v));
}

export function lerp(a, b, t) {
  return a + (b - a) * t;
}

export function lerpColor(hexA, hexB, t) {
  const a = parseHex(hexA);
  const b = parseHex(hexB);
  if (!a || !b) return hexA;
  const r = Math.round(lerp(a.r, b.r, t));
  const g = Math.round(lerp(a.g, b.g, t));
  const bl = Math.round(lerp(a.b, b.b, t));
  const al = lerp(a.a, b.a, t);
  return rgba(r, g, bl, al);
}

export function parseHex(raw) {
  if (!raw) return null;
  let s = String(raw).trim();
  if (s.startsWith('#')) s = s.slice(1);
  if (s.length === 6) s = 'FF' + s;
  if (s.length !== 8) return null;
  const n = parseInt(s, 16);
  if (Number.isNaN(n)) return null;
  return {
    r: (n >> 16) & 255,
    g: (n >> 8) & 255,
    b: n & 255,
    a: ((n >> 24) & 255) / 255,
  };
}

export function rgba(r, g, b, a = 1) {
  return `rgba(${r},${g},${b},${clamp(a, 0, 1)})`;
}

export function hexAlpha(hex, alpha) {
  const c = parseHex(hex);
  if (!c) return hex;
  return rgba(c.r, c.g, c.b, alpha);
}

export function resolveSurfaceColor(themeSurface, fieldCfg) {
  const base = fieldCfg.colorHex ? parseHex(fieldCfg.colorHex) : parseHex(themeSurface);
  if (!base) return themeSurface;
  const b = clamp(fieldCfg.brightness ?? 1, 0.4, 1.8);
  if (b === 1) return rgbStr(base);
  if (b > 1) {
    const t = clamp((b - 1) / 0.8, 0, 1);
    return rgba(
      Math.round(lerp(base.r, 255, t)),
      Math.round(lerp(base.g, 255, t)),
      Math.round(lerp(base.b, 255, t)),
      base.a,
    );
  }
  const t = clamp((1 - b) / 0.6, 0, 1);
  return rgba(
    Math.round(lerp(base.r, 0, t)),
    Math.round(lerp(base.g, 0, t)),
    Math.round(lerp(base.b, 0, t)),
    base.a,
  );
}

function rgbStr(c) {
  return rgba(c.r, c.g, c.b, c.a);
}

export function dist(dx, dy) {
  return Math.hypot(dx, dy);
}

export function vecLen(v) {
  return Math.hypot(v.dx, v.dy);
}

export function normalize(v) {
  const d = vecLen(v);
  if (d < 1e-6) return { dx: 1, dy: 1 };
  return { dx: v.dx / d, dy: v.dy / d };
}

export function vecAdd(a, b) {
  return { dx: a.dx + b.dx, dy: a.dy + b.dy };
}

export function vecSub(a, b) {
  return { dx: a.dx - b.dx, dy: a.dy - b.dy };
}

export function vecScale(v, s) {
  return { dx: v.dx * s, dy: v.dy * s };
}

export function vecDot(a, b) {
  return a.dx * b.dx + a.dy * b.dy;
}

export function shuffle(arr, rng = Math.random) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

/** Flutter Curves.easeOut — cubic(0, 0, 0.58, 1). */
export function easeOut(t) {
  return 1 - Math.pow(1 - clamp(t, 0, 1), 3) * (1 - 0.58);
}

export function makeRect(l, t, w, h) {
  return {
    left: l,
    top: t,
    width: w,
    height: h,
    right: l + w,
    bottom: t + h,
    get center() {
      return { dx: l + w * 0.5, dy: t + h * 0.5 };
    },
  };
}

export function rectOverlaps(a, b) {
  return !(a.right <= b.left || b.right <= a.left || a.bottom <= b.top || b.bottom <= a.top);
}

export function roundRectPath(ctx, x, y, w, h, r) {
  const rad = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + rad, y);
  ctx.lineTo(x + w - rad, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + rad);
  ctx.lineTo(x + w, y + h - rad);
  ctx.quadraticCurveTo(x + w, y + h, x + w - rad, y + h);
  ctx.lineTo(x + rad, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - rad);
  ctx.lineTo(x, y + rad);
  ctx.quadraticCurveTo(x, y, x + rad, y);
  ctx.closePath();
}

export function fmtTimeMs(ms) {
  const sec = ms / 1000;
  return sec.toFixed(2) + 's';
}

/** Секундомер как в APK: MM:SS.mmm */
export function fmtTimerChip(ms) {
  const clamped = clamp(Math.floor(ms), 0, 99 * 60 * 1000);
  const totalSec = Math.floor(clamped / 1000);
  const minutes = String(Math.floor(totalSec / 60)).padStart(2, '0');
  const seconds = String(totalSec % 60).padStart(2, '0');
  const millis = String(clamped % 1000).padStart(3, '0');
  return `${minutes}:${seconds}.${millis}`;
}

/** Внутренний край видимой рамки поля — совпадает с game_field_painter inset + stroke/2. */
export function visualWallInset(borderWidth = 3) {
  const bw = borderWidth;
  const inset = clamp(bw / 2 + 0.5, 0.5, 12);
  return inset + bw / 2;
}

export function fmtRent(seconds) {
  if (seconds == null || seconds < 0) return '--:--';
  const total = clamp(Math.floor(seconds), 0, 86400);
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

/**
 * 1 шаг = 0.1 × ширина героя — пробег соизмерим на разных экранах.
 */
export const RUN_STEP_OF_HERO = 0.1;

export function runStepsFromPx(pxDistance, playerSize = 36) {
  const stepPx = Math.max(1e-6, (playerSize || 36) * RUN_STEP_OF_HERO);
  return Math.max(0, (pxDistance || 0) / stepPx);
}

/**
 * Подсчет очков заезда:
 * Секунды * пробег (шаги) * множитель рисков (1 + riskCount).
 */
export function calcScore(timeMs, runDistance = 0, riskCount = 0) {
  const sec = Math.max(0, timeMs || 0) / 1000;
  const dist = Math.max(0, runDistance || 0);
  const risks = Math.max(0, riskCount || 0);
  const riskMult = 1 + risks;
  return Math.round(sec * dist * riskMult);
}

/** Красивое форматирование очков с разделителем тысяч (например, 14 250) */
export function fmtScore(score) {
  return Math.round(score || 0).toLocaleString('ru-RU');
}

