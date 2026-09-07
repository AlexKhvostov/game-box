import { clamp, hexAlpha, makeRect, roundRectPath, PI } from './util.js';

/** Port of lib/features/game/game_field_painter.dart */
export class FieldRenderer {
  constructor(theme) {
    this.theme = theme;
  }

  paint(ctx, world, opts) {
    const {
      fieldColor,
      accent,
      danger,
      borderColor,
      borderWidth = 3,
      cornerRadius = 18,
      fieldSize,
      frame = 0,
      playerPreview = false,
      impacts = [],
      hasHelmet = false,
      invulnerable = false,
      invulnerableFactor = null,
      shadowBrightness = 1,
      drawBorder = true,
      showFace = false,
    } = opts;

    const size = fieldSize ?? {
      width: ctx.canvas.clientWidth || ctx.canvas.width,
      height: ctx.canvas.clientHeight || ctx.canvas.height,
    };
    if (size.width <= 0 || size.height <= 0) return;

    const r = clamp(Math.min(cornerRadius, size.width / 2, size.height / 2), 0, 64);

    // Без ctx.clip — иначе обрезаются рамка и уголки поля.
    ctx.fillStyle = fieldColor;
    roundRectPath(ctx, 0, 0, size.width, size.height, r);
    ctx.fill();

    ctx.strokeStyle = 'rgba(0,0,0,0.12)';
    ctx.lineWidth = Math.min(size.width * 0.08, 24);
    roundRectPath(ctx, 0, 0, size.width, size.height, r);
    ctx.stroke();

    const light = { dx: 5.5, dy: 7 };
    const enemyShadowAlpha = this._shadowAlpha(0.42, shadowBrightness);
    ctx.fillStyle = `rgba(0,0,0,${enemyShadowAlpha})`;
    for (const e of world.enemies) {
      this._paintEnemy(ctx, e, enemyShadowAlpha, light);
    }

    const base = makeRect(world.player.dx, world.player.dy, world.playerSize, world.playerSize);
    const lift = world.jumpLift;
    const jumping = lift > 0.02;

    if (this._isFiniteRect(base) && !jumping) {
      this._paintPlayerShadow(ctx, world, base, 0, playerPreview, shadowBrightness);
    }

    for (const e of world.enemies) {
      this._paintEnemy(ctx, e, hexAlpha(danger, 0.18), null, 1);
      this._paintEnemy(ctx, e, danger, null, 0);
      if (world.config.enemies.collideWithEachOther) {
        ctx.strokeStyle = 'rgba(255,255,255,0.82)';
        ctx.lineWidth = 2;
        this._paintEnemyStroke(ctx, e, 1.2);
      }
    }

    if (this._isFiniteRect(base) && jumping) {
      this._paintPlayerShadow(ctx, world, base, lift, playerPreview, shadowBrightness);
    }

    if (this._isFiniteRect(base)) {
      this._paintPlayer(ctx, world, base, {
        accent,
        lift,
        playerPreview,
        hasHelmet,
        invulnerable,
        invulnerableFactor,
        frame,
        showFace,
      });
    }

    if (drawBorder) {
      this._drawBorder(ctx, size, r, borderWidth, borderColor);
    }

    for (const burst of impacts) burst.paint(ctx);
    for (const fx of world.nearMissFx) fx.paint(ctx);
  }

  _shadowAlpha(base, shadowBrightness) {
    const b = clamp(shadowBrightness, 0.4, 2.5);
    return clamp(base / b, 0.02, 0.85);
  }

  _paintEnemy(ctx, e, colorOrAlpha, shift = null, inflate = 0) {
    const c = e.center;
    const cx = c.dx + (shift ? shift.dx : 0);
    const cy = c.dy + (shift ? shift.dy : 0);
    ctx.save();
    ctx.translate(cx, cy);
    if (Math.abs(e.orientDeg) > 0.01) {
      ctx.rotate((e.orientDeg * PI) / 180);
    }
    const hw = e.w / 2 + inflate;
    const hh = e.h / 2 + inflate;
    if (typeof colorOrAlpha === 'string') {
      ctx.fillStyle = colorOrAlpha;
    } else {
      ctx.fillStyle = `rgba(0,0,0,${colorOrAlpha})`;
    }
    roundRectPath(ctx, -hw, -hh, hw * 2, hh * 2, 3);
    ctx.fill();
    ctx.restore();
  }

  _paintEnemyStroke(ctx, e, inflate) {
    const c = e.center;
    ctx.save();
    ctx.translate(c.dx, c.dy);
    if (Math.abs(e.orientDeg) > 0.01) {
      ctx.rotate((e.orientDeg * PI) / 180);
    }
    const hw = e.w / 2 + inflate;
    const hh = e.h / 2 + inflate;
    roundRectPath(ctx, -hw, -hh, hw * 2, hh * 2, 3);
    ctx.stroke();
    ctx.restore();
  }

  _paintPlayerShadow(ctx, world, base, lift, preview, shadowBrightness) {
    const scale = world.visualScale;
    const cx = base.left + base.width / 2;
    const cy = base.top + base.height / 2;
    const vis = world.playerSize * scale;
    const baseAlpha = (preview ? 0.22 : 0.4) * (1 - lift * 0.25);
    const shadowAlpha = this._shadowAlpha(baseAlpha, shadowBrightness);
    ctx.fillStyle = `rgba(0,0,0,${shadowAlpha})`;
    const sx = cx + 5 + lift * 10;
    const sy = cy - lift * 8 + 6 + lift * 12;
    roundRectPath(ctx, sx - vis / 2, sy - vis / 2, vis, vis, 4);
    ctx.fill();
  }

  _paintPlayer(ctx, world, base, o) {
    const scale = world.visualScale;
    const cx = base.left + base.width / 2;
    const cy = base.top + base.height / 2;
    const vis = world.playerSize * scale;
    const px = cx - vis / 2;
    const py = cy - o.lift * 8 - vis / 2;
    const blink = !o.invulnerable
      ? 1
      : o.invulnerableFactor ??
        0.22 + 0.78 * ((Math.sin(o.frame * 1.35) + 1) * 0.5);
    const bodyAlpha = (o.playerPreview ? 0.38 : 1) * blink;

    ctx.fillStyle = hexAlpha(o.accent, 0.2 * bodyAlpha);
    roundRectPath(ctx, px - 4, py - 4, vis + 8, vis + 8, 4);
    ctx.fill();
    ctx.fillStyle = hexAlpha(o.accent, bodyAlpha);
    roundRectPath(ctx, px, py, vis, vis, 4);
    ctx.fill();

    if (o.hasHelmet) {
      ctx.strokeStyle = hexAlpha('#7EE0FF', 0.95 * bodyAlpha);
      ctx.lineWidth = 2.6;
      roundRectPath(ctx, px - 2.5, py - 2.5, vis + 5, vis + 5, 4);
      ctx.stroke();
      ctx.strokeStyle = hexAlpha('#FFFFFF', 0.35 * bodyAlpha);
      ctx.lineWidth = 1.2;
      roundRectPath(ctx, px - 5, py - 5, vis + 10, vis + 10, 4);
      ctx.stroke();
    }

    const shine = vis * 0.18;
    if (shine > 0 && shine * 2 < vis) {
      ctx.fillStyle = hexAlpha('#FFFFFF', 0.2 * bodyAlpha);
      roundRectPath(ctx, px + shine, py + shine, vis - shine * 2, vis - shine * 2, 4);
      ctx.fill();
    }

    if (o.showFace) {
      this._paintPlayerFace(ctx, px, py, vis, bodyAlpha, o.frame);
    }
  }

  _paintPlayerFace(ctx, px, py, vis, bodyAlpha, frame) {
    if (bodyAlpha < 0.05) return;
    const cx = px + vis / 2;
    const eyeCy = py + vis * 0.36;
    const gap = vis * 0.2;
    const eyeW = vis * 0.16;
    const eyeH = vis * 0.28;
    if (eyeH < 0.8) return;
    const lx = Math.sin(frame * 0.042) * 0.45;
    const ly = Math.cos(frame * 0.031) * 0.25;
    ctx.fillStyle = hexAlpha('#1A222C', bodyAlpha);
    for (const sign of [-1, 1]) {
      const ex = cx + sign * gap + lx * eyeW * 0.15;
      const ey = eyeCy + ly * eyeH * 0.12;
      ctx.beginPath();
      ctx.ellipse(ex, ey, eyeW / 2, eyeH / 2, 0, 0, PI * 2);
      ctx.fill();
      ctx.fillStyle = hexAlpha('#FFFFFF', 0.92 * bodyAlpha);
      ctx.beginPath();
      ctx.arc(ex - eyeW * 0.12, ey - eyeH * 0.22, eyeW * 0.22, 0, PI * 2);
      ctx.fill();
      ctx.fillStyle = hexAlpha('#1A222C', bodyAlpha);
    }
  }

  _drawBorder(ctx, size, r, borderWidth, borderColor) {
    const inset = clamp(borderWidth / 2 + 0.5, 0.5, 12);
    const frameW = size.width - inset * 2;
    const frameH = size.height - inset * 2;
    if (frameW <= 1 || frameH <= 1) return;
    const fr = Math.max(0, r - inset);
    ctx.strokeStyle = hexAlpha(borderColor, 0.28);
    ctx.lineWidth = borderWidth + 4;
    roundRectPath(ctx, inset, inset, frameW, frameH, fr);
    ctx.stroke();
    ctx.strokeStyle = borderColor;
    ctx.lineWidth = borderWidth;
    ctx.lineJoin = 'round';
    roundRectPath(ctx, inset, inset, frameW, frameH, fr);
    ctx.stroke();
    this._drawCornerMarks(ctx, size, borderColor, borderWidth);
  }

  _drawCornerMarks(ctx, size, color, borderWidth) {
    const m = borderWidth + 6;
    const len = 16;
    ctx.strokeStyle = hexAlpha(color, 0.85);
    ctx.lineWidth = 2.2;
    ctx.lineCap = 'round';
    const corners = [
      [[m, m + len], [m, m], [m + len, m]],
      [[size.width - m - len, m], [size.width - m, m], [size.width - m, m + len]],
      [[m, size.height - m - len], [m, size.height - m], [m + len, size.height - m]],
      [
        [size.width - m - len, size.height - m],
        [size.width - m, size.height - m],
        [size.width - m, size.height - m - len],
      ],
    ];
    for (const [a, b, c] of corners) {
      ctx.beginPath();
      ctx.moveTo(a[0], a[1]);
      ctx.lineTo(b[0], b[1]);
      ctx.lineTo(c[0], c[1]);
      ctx.stroke();
    }
  }

  _isFiniteRect(rect) {
    return (
      Number.isFinite(rect.left) &&
      Number.isFinite(rect.top) &&
      Number.isFinite(rect.width) &&
      Number.isFinite(rect.height) &&
      rect.width >= 0 &&
      rect.height >= 0
    );
  }
}
