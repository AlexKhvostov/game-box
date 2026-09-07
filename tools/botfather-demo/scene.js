import { FieldRenderer } from '../../telegram-web/js/renderer.js';
import { EnemyBody, NearMissFx } from '../../telegram-web/js/game-world.js';
import { clamp, resolveSurfaceColor, visualWallInset } from '../../telegram-web/js/util.js';

const FIELD = 380;
const SCALE = 2;
const FRAMES = 48;
const DT = 1 / 20;
const PLAYER = 48;

const config = {
  theme: {
    bg: '#0E1419',
    surface: '#172028',
    primary: '#3DDC97',
    danger: '#FF5A5F',
  },
  field: {
    borderWidth: 3,
    brightness: 1,
    shadowBrightness: 1,
    colorHex: null,
    cornerRadius: 18,
  },
  enemies: { collideWithEachOther: false },
  player: { size: PLAYER },
  game: { jumpDurationSec: 0.38, jumpScale: 1.32 },
};

const canvas = document.getElementById('game-canvas');
const ctx = canvas.getContext('2d');
ctx.scale(SCALE, SCALE);

const renderer = new FieldRenderer(config.theme);
const inset = visualWallInset(config.field.borderWidth);

function enemySize(aspect) {
  const area = PLAYER * PLAYER * 2;
  const h = Math.sqrt(area / aspect);
  const w = Math.sqrt(area * aspect);
  return { w, h };
}

function makeEnemy(aspect, x, y) {
  const { w, h } = enemySize(aspect);
  return new EnemyBody({
    pos: { dx: x - w / 2, dy: y - h / 2 },
    vel: { dx: 0, dy: 0 },
    w,
    h,
    aspect,
    angleDeg: 0,
    quadrantN: 0,
    fieldQuadrant: 0,
    initialSpeed: 90,
    acceleration: 0,
  });
}

function clampBody(e) {
  const pad = inset + 4;
  const cx = clamp(e.center.dx, pad + e.w / 2, FIELD - pad - e.w / 2);
  const cy = clamp(e.center.dy, pad + e.h / 2, FIELD - pad - e.h / 2);
  e.setCenter({ dx: cx, dy: cy });
}

function keepAway(e, hx, hy, extra = 16) {
  const minDist = PLAYER / 2 + Math.max(e.w, e.h) * 0.42 + extra;
  const dx = e.center.dx - hx;
  const dy = e.center.dy - hy;
  const d = Math.hypot(dx, dy) || 1;
  if (d < minDist) {
    e.setCenter({
      dx: hx + (dx / d) * minDist,
      dy: hy + (dy / d) * minDist,
    });
  }
  clampBody(e);
}

function heroAt(t) {
  const a = t * Math.PI * 2;
  return {
    x: 190 + 78 * Math.cos(a),
    y: 188 + 62 * Math.sin(a * 2),
  };
}

function jumpAt(t) {
  const start = 0.42;
  const dur = 0.16;
  if (t < start || t > start + dur) return 0;
  const u = (t - start) / dur;
  return Math.sin(Math.PI * u);
}

function sceneAt(frame) {
  const t = frame / FRAMES;
  const hero = heroAt(t);
  const prev = heroAt((frame - 1) / FRAMES);
  const jump = jumpAt(t);
  const lift = jump;
  const visualScale = 1 + (1.32 - 1) * lift;

  const e0 = makeEnemy(1, 0, 0);
  const e1 = makeEnemy(0.25, 0, 0);
  const e2 = makeEnemy(3, 0, 0);

  const lag = heroAt((frame - 7) / FRAMES);
  const lag2 = heroAt((frame - 11) / FRAMES);
  const cut = t * Math.PI * 2;

  e0.setCenter({ dx: lag.x - 18, dy: lag.y + 10 });
  e1.setCenter({
    dx: 190 + 110 * Math.sin(cut + 0.6),
    dy: lag2.y - 8,
  });
  e2.setCenter({
    dx: lag2.x + 12,
    dy: 190 + 96 * Math.cos(cut * 0.85),
  });

  const hx = hero.x;
  const hy = hero.y;
  keepAway(e0, hx, hy, jump > 0.2 ? 10 : 18);
  keepAway(e1, hx, hy, jump > 0.35 ? 8 : 20);
  keepAway(e2, hx, hy, 18);

  const fx = [];
  for (const e of [e0, e1, e2]) {
    const d = Math.hypot(e.center.dx - hx, e.center.dy - hy);
    const limit = PLAYER / 2 + Math.min(e.w, e.h) * 0.55 + 22;
    if (d < limit) {
      const burst = new NearMissFx({
        dx: (e.center.dx + hx) / 2,
        dy: (e.center.dy + hy) / 2,
      });
      burst.age = (d / limit) * 0.18;
      fx.push(burst);
    }
  }

  const ps = PLAYER;
  return {
    config,
    player: { dx: hx - ps / 2, dy: hy - ps / 2 },
    playerSize: ps,
    enemies: [e0, e1, e2],
    jumpLift: lift,
    visualScale,
    nearMissFx: fx,
    _moved: { dx: hero.x - prev.x, dy: hero.y - prev.y },
  };
}

function paint(frame) {
  ctx.setTransform(SCALE, 0, 0, SCALE, 0, 0);
  ctx.clearRect(0, 0, FIELD, FIELD);
  const world = sceneAt(frame);
  const theme = config.theme;
  renderer.paint(ctx, world, {
    fieldSize: { width: FIELD, height: FIELD },
    fieldColor: resolveSurfaceColor(theme.surface, config.field),
    accent: theme.primary,
    danger: theme.danger,
    borderColor: theme.primary,
    borderWidth: config.field.borderWidth,
    cornerRadius: config.field.cornerRadius,
    frame,
    shadowBrightness: config.field.shadowBrightness,
    showFace: true,
    showEnemyFaces: true,
    expressive: true,
  });
}

window.DEMO = {
  frames: FRAMES,
  render(frame) {
    paint(((frame % FRAMES) + FRAMES) % FRAMES);
  },
  png(frame) {
    paint(((frame % FRAMES) + FRAMES) % FRAMES);
    return canvas.toDataURL('image/png');
  },
};

paint(0);

if (!window.location.search.includes('still')) {
  let i = 0;
  setInterval(() => {
    i = (i + 1) % FRAMES;
    paint(i);
  }, DT * 1000);
}
