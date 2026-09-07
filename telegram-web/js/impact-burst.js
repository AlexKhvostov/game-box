import { clamp, PI, TAU } from './util.js';

const MARKS = ['#', '#', '#', '※', '✕', '✦'];

export class ImpactBurst {
  static spawn({ origin, accent, danger, againstWall, rng = Math.random }) {
    const palette = againstWall
      ? [accent, '#5CE1FF', '#FFFFFF', '#FFE566', '#B8F2FF']
      : [danger, '#FF3D7F', '#FFE566', '#FFFFFF', accent, '#FF8A5B'];
    const glyphs = [];
    const count = 11 + Math.floor(rng() * 4);
    for (let i = 0; i < count; i++) {
      const ang = (i / count) * TAU + rng() * 0.35;
      const speed = 90 + rng() * 160;
      glyphs.push({
        pos: { ...origin },
        vel: { dx: Math.cos(ang) * speed, dy: Math.sin(ang) * speed },
        rot: rng() * PI,
        rotVel: (rng() - 0.5) * 10,
        life: 0.38 + rng() * 0.22,
        size: 14 + rng() * 18,
        color: palette[Math.floor(rng() * palette.length)],
        mark: MARKS[Math.floor(rng() * MARKS.length)],
      });
    }
    return new ImpactBurst(origin, glyphs, againstWall ? accent : danger);
  }

  constructor(origin, glyphs, flashColor) {
    this.origin = origin;
    this._glyphs = glyphs;
    this.flashColor = flashColor;
    this.age = 0;
  }

  get alive() {
    return this.age < 0.55 || this._glyphs.some((g) => g.life > 0);
  }

  update(dt) {
    this.age += dt;
    for (const g of this._glyphs) {
      if (g.life <= 0) continue;
      g.life -= dt;
      g.pos.dx += g.vel.dx * dt;
      g.pos.dy += g.vel.dy * dt;
      g.vel.dx *= Math.pow(0.08, dt);
      g.vel.dy *= Math.pow(0.08, dt);
      g.rot += g.rotVel * dt;
    }
    return this.alive;
  }

  paint(ctx) {
    const t = clamp(this.age / 0.28, 0, 1);
    const ringR = 8 + t * 42;
    const ringA = (1 - t) * 0.85;
    if (ringA > 0.02) {
      ctx.strokeStyle = this._withAlpha(this.flashColor, ringA);
      ctx.lineWidth = 3.5 * (1 - t * 0.6);
      ctx.beginPath();
      ctx.arc(this.origin.dx, this.origin.dy, ringR, 0, TAU);
      ctx.stroke();
      ctx.fillStyle = `rgba(255,255,255,${ringA * 0.55})`;
      ctx.beginPath();
      ctx.arc(this.origin.dx, this.origin.dy, ringR * 0.45, 0, TAU);
      ctx.fill();
    }

    if (this.age < 0.22) {
      const la = (1 - this.age / 0.22) * 0.55;
      ctx.strokeStyle = `rgba(255,255,255,${la})`;
      ctx.lineWidth = 1.6;
      ctx.lineCap = 'round';
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * TAU + this.age * 2;
        const inner = 10 + this.age * 40;
        const outer = 28 + this.age * 90;
        ctx.beginPath();
        ctx.moveTo(
          this.origin.dx + Math.cos(a) * inner,
          this.origin.dy + Math.sin(a) * inner,
        );
        ctx.lineTo(
          this.origin.dx + Math.cos(a) * outer,
          this.origin.dy + Math.sin(a) * outer,
        );
        ctx.stroke();
      }
    }

    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (const g of this._glyphs) {
      if (g.life <= 0) continue;
      const fade = clamp(g.life / 0.45, 0, 1);
      ctx.save();
      ctx.translate(g.pos.dx, g.pos.dy);
      ctx.rotate(g.rot);
      ctx.font = `900 ${g.size * (0.85 + (1 - fade) * 0.35)}px system-ui,sans-serif`;
      ctx.fillStyle = this._withAlpha(g.color, fade);
      ctx.fillText(g.mark, 0, 0);
      ctx.restore();
    }
  }

  _withAlpha(hex, a) {
    if (hex.startsWith('rgba')) return hex;
    const h = hex.replace('#', '');
    const r = parseInt(h.slice(0, 2), 16);
    const g = parseInt(h.slice(2, 4), 16);
    const b = parseInt(h.slice(4, 6), 16);
    return `rgba(${r},${g},${b},${a})`;
  }
}
