import { clamp, dist, makeRect, normalize, rectOverlaps, shuffle, vecAdd, vecDot, vecLen, vecScale, vecSub, PI } from './util.js';

export class BounceReport {
  constructor(wall = 0, enemy = 0) {
    this.wall = wall;
    this.enemy = enemy;
  }
}

export class NearMissFx {
  constructor(origin) {
    this.origin = origin;
    this.age = 0;
  }

  update(dt) {
    this.age += dt;
    return this.age < 0.42;
  }

  paint(ctx) {
    const t = clamp(this.age / 0.42, 0, 1);
    const a = (1 - t) * 0.9;
    const r = 6 + t * 26;
    ctx.strokeStyle = `rgba(255,193,7,${a})`;
    ctx.lineWidth = 2.4 * (1 - t * 0.5);
    ctx.beginPath();
    ctx.arc(this.origin.dx, this.origin.dy, r, 0, PI * 2);
    ctx.stroke();
    ctx.fillStyle = `rgba(255,245,157,${a * 0.55})`;
    ctx.beginPath();
    ctx.arc(this.origin.dx, this.origin.dy, r * 0.35, 0, PI * 2);
    ctx.fill();
  }
}

export class EnemyBody {
  constructor({
    pos, vel, w, h, aspect, angleDeg, quadrantN, fieldQuadrant,
    initialSpeed, acceleration, orientDeg = 0, spinDegPerSec = 0,
  }) {
    this.pos = pos;
    this.vel = vel;
    this.w = w;
    this.h = h;
    this.aspect = aspect;
    this.angleDeg = angleDeg;
    this.quadrantN = quadrantN;
    this.fieldQuadrant = fieldQuadrant;
    this.initialSpeed = initialSpeed;
    this.acceleration = acceleration;
    this.orientDeg = orientDeg;
    this.spinDegPerSec = spinDegPerSec;
  }

  get center() {
    return { dx: this.pos.dx + this.w * 0.5, dy: this.pos.dy + this.h * 0.5 };
  }

  setCenter(c) {
    this.pos = { dx: c.dx - this.w * 0.5, dy: c.dy - this.h * 0.5 };
  }

  get isSpinning() {
    return Math.abs(this.spinDegPerSec) > 0.01;
  }

  get axisX() {
    const r = (this.orientDeg * PI) / 180;
    return { dx: Math.cos(r), dy: Math.sin(r) };
  }

  get axisY() {
    const r = (this.orientDeg * PI) / 180;
    return { dx: -Math.sin(r), dy: Math.cos(r) };
  }

  get corners() {
    const c = this.center;
    const ax = this.axisX;
    const ay = this.axisY;
    const hx = this.w * 0.5;
    const hy = this.h * 0.5;
    const at = (lx, ly) => ({
      dx: c.dx + ax.dx * lx + ay.dx * ly,
      dy: c.dy + ax.dy * lx + ay.dy * ly,
    });
    return [at(-hx, -hy), at(hx, -hy), at(hx, hy), at(-hx, hy)];
  }

  get rect() {
    const cs = this.corners;
    let minX = cs[0].dx, maxX = cs[0].dx, minY = cs[0].dy, maxY = cs[0].dy;
    for (const p of cs) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return makeRect(minX, minY, maxX - minX, maxY - minY);
  }

  project(axis) {
    const c = this.center;
    const ax = this.axisX;
    const ay = this.axisY;
    const cen = c.dx * axis.dx + c.dy * axis.dy;
    const ext =
      this.w * 0.5 * Math.abs(axis.dx * ax.dx + axis.dy * ax.dy) +
      this.h * 0.5 * Math.abs(axis.dx * ay.dx + axis.dy * ay.dy);
    return [cen - ext, cen + ext];
  }

  speedAt(secondsAlive) {
    return this.initialSpeed + this.acceleration * secondsAlive;
  }

  overlapsAabb(other) {
    return this.mtvOutOfAabb(other) != null;
  }

  mtvOutOfAabb(other) {
    const axes = [
      { dx: 1, dy: 0 },
      { dx: 0, dy: 1 },
      this.axisX,
      this.axisY,
    ];
    let minOverlap = Infinity;
    let best = null;
    const oc = other.center;
    const ohx = other.width * 0.5;
    const ohy = other.height * 0.5;

    for (const axis of axes) {
      const len2 = axis.dx * axis.dx + axis.dy * axis.dy;
      if (len2 < 1e-12) continue;
      const inv = 1 / Math.sqrt(len2);
      const n = { dx: axis.dx * inv, dy: axis.dy * inv };
      const [minA, maxA] = this.project(n);
      const cenB = oc.dx * n.dx + oc.dy * n.dy;
      const extB = ohx * Math.abs(n.dx) + ohy * Math.abs(n.dy);
      const minB = cenB - extB;
      const maxB = cenB + extB;
      const overlap = Math.min(maxA, maxB) - Math.max(minA, minB);
      if (overlap <= 0) return null;
      if (overlap < minOverlap) {
        minOverlap = overlap;
        const side =
          (this.center.dx - oc.dx) * n.dx + (this.center.dy - oc.dy) * n.dy;
        best = side >= 0 ? n : { dx: -n.dx, dy: -n.dy };
      }
    }
    if (!best) return null;
    return vecScale(best, minOverlap + 0.5);
  }

  mtvOutOfObb(other) {
    const axes = [this.axisX, this.axisY, other.axisX, other.axisY];
    let minOverlap = Infinity;
    let best = null;
    for (const axis of axes) {
      const len2 = axis.dx * axis.dx + axis.dy * axis.dy;
      if (len2 < 1e-12) continue;
      const inv = 1 / Math.sqrt(len2);
      const n = { dx: axis.dx * inv, dy: axis.dy * inv };
      const [minA, maxA] = this.project(n);
      const [minB, maxB] = other.project(n);
      const overlap = Math.min(maxA, maxB) - Math.max(minA, minB);
      if (overlap <= 0) return null;
      if (overlap < minOverlap) {
        minOverlap = overlap;
        const side =
          (this.center.dx - other.center.dx) * n.dx +
          (this.center.dy - other.center.dy) * n.dy;
        best = side >= 0 ? n : { dx: -n.dx, dy: -n.dy };
      }
    }
    if (!best) return null;
    return vecScale(best, minOverlap + 0.5);
  }

  reflectVelocity(n) {
    const len2 = n.dx * n.dx + n.dy * n.dy;
    if (len2 < 1e-12) return;
    const inv = 1 / Math.sqrt(len2);
    const nx = n.dx * inv;
    const ny = n.dy * inv;
    const vn = this.vel.dx * nx + this.vel.dy * ny;
    if (vn >= 0) return;
    this.vel = { dx: this.vel.dx - 2 * vn * nx, dy: this.vel.dy - 2 * vn * ny };
  }
}

export class GameWorld {
  constructor({ config, fieldW, fieldH, rng = Math.random, wallInset = 0 }) {
    this.config = config;
    this.field = { width: fieldW, height: fieldH };
    this._rng = rng;
    this.wallInset = wallInset;
    this.player = { dx: 0, dy: 0 };
    this.enemies = [];
    this.jumpRemaining = 0;
    this.playerDistance = 0;
    this.nearMissCount = 0;
    this.nearMissFx = [];
    this._nearArmed = new Set();
    this._jumpOverCounted = new Set();
  }

  static NEAR_ENTER = 14;
  static NEAR_EXIT = 22;

  get playerSize() {
    return this.config.player.size;
  }

  get isJumping() {
    return this.jumpRemaining > 0;
  }

  get jumpLift() {
    if (!this.isJumping) return 0;
    const dur = Math.max(0.05, this.config.game.jumpDurationSec);
    const t = clamp(1 - this.jumpRemaining / dur, 0, 1);
    return Math.sin(PI * t);
  }

  get visualScale() {
    if (!this.isJumping) return 1;
    const peak = clamp(this.config.game.jumpScale, 1.05, 1.8);
    return 1 + (peak - 1) * this.jumpLift;
  }

  resetLayout() {
    const ps = this.playerSize;
    this.player = {
      dx: (this.field.width - ps) / 2,
      dy: (this.field.height - ps) / 2,
    };
    this.jumpRemaining = 0;
    this.playerDistance = 0;
    this.nearMissCount = 0;
    this.nearMissFx = [];
    this._nearArmed.clear();
    this._jumpOverCounted.clear();
    this.enemies = this._spawnEnemies();
  }

  tryJump() {
    if (!this.config.game.jumpEnabled || this.isJumping) return false;
    this.jumpRemaining = Math.max(0.12, this.config.game.jumpDurationSec);
    this._jumpOverCounted.clear();
    this._nearArmed.clear();
    this._evaluateJumpOver();
    return true;
  }

  tickJump(dt) {
    if (this.jumpRemaining <= 0) return;
    this.jumpRemaining = Math.max(0, this.jumpRemaining - dt);
    if (this.jumpRemaining > 0) {
      this._evaluateJumpOver();
    } else {
      this._jumpOverCounted.clear();
    }
  }

  idleEnemiesMove() {
    const v = this.config?.game?.idleEnemiesMove;
    return v !== false && v !== 0 && v !== 'false' && v !== '0';
  }

  /** Вернуть врагов на спавн с исходным направлением — перед стартом раунда. */
  snapEnemiesToHome() {
    for (const e of this.enemies) {
      if (e.homePos) e.pos = { dx: e.homePos.dx, dy: e.homePos.dy };
      const src = e.homeVel || e.vel;
      const d = vecLen(src);
      const dir = d < 1e-6 ? { dx: 1, dy: 1 } : normalize(src);
      e.vel = vecScale(dir, e.initialSpeed);
    }
  }

  tickIdle(dt) {
    const safeDt = clamp(dt, 0, 0.05);
    if (!this.idleEnemiesMove()) {
      return this._tickIdleDrowsy(safeDt);
    }
    const mult = clamp(this.config.game.idleSpeedMultiplier, 0.05, 1);
    let wall = 0;
    for (const e of this.enemies) {
      const speed = clamp(e.initialSpeed * mult, 0, 2000);
      const d = vecLen(e.vel);
      const dir = d < 1e-6 ? { dx: 1, dy: 1 } : normalize(e.vel);
      e.vel = vecScale(dir, speed);
      e.pos = vecAdd(e.pos, vecScale(e.vel, safeDt));
      if (e.isSpinning) e.orientDeg += e.spinDegPerSec * safeDt;
      if (this._bounce(e)) wall++;
    }
    const enemy = this.config.enemies.collideWithEachOther
      ? this._resolveEnemyCollisions()
      : 0;
    return new BounceReport(wall, enemy);
  }

  _tickIdleDrowsy(safeDt) {
    for (const e of this.enemies) {
      e.idleT = (e.idleT || 0) + safeDt;
      const home = e.homePos || e.pos;
      const amp = Math.min(e.w, e.h) * 0.5;
      const src = e.homeVel || e.vel;
      const d = vecLen(src);
      const dir = d < 1e-6 ? { dx: 1, dy: 0 } : normalize(src);
      const perp = { dx: -dir.dy, dy: dir.dx };
      const wx = Number.isFinite(e.idleWx) ? e.idleWx : 1.4;
      const wy = Number.isFinite(e.idleWy) ? e.idleWy : 1.1;
      const ph = Number.isFinite(e.idlePhase) ? e.idlePhase : 0;
      const ph2 = Number.isFinite(e.idlePhase2) ? e.idlePhase2 : 1;
      const along = Math.cos(e.idleT * wx + ph) * amp;
      const side = Math.sin(e.idleT * wy + ph2) * amp * 0.35;
      let ox = dir.dx * along + perp.dx * side;
      let oy = dir.dy * along + perp.dy * side;
      const len = Math.hypot(ox, oy);
      if (len > amp && len > 1e-6) {
        ox = (ox * amp) / len;
        oy = (oy * amp) / len;
      }
      e.pos = { dx: home.dx + ox, dy: home.dy + oy };
      if (e.isSpinning) e.orientDeg += e.spinDegPerSec * safeDt * 0.35;
      this._nudgeInside(e);
    }
    return new BounceReport(0, 0);
  }

  tickPlay(dt, secondsAlive, speedMult = 1) {
    const safeDt = clamp(dt, 0, 0.05);
    const mult = clamp(speedMult, 0, 2);
    const t = clamp(secondsAlive, 0, 3600);
    let wall = 0;
    for (const e of this.enemies) {
      const speed = clamp(e.speedAt(t) * mult, 0, 4000);
      const d = vecLen(e.vel);
      const dir = d < 1e-6 ? { dx: 1, dy: 1 } : normalize(e.vel);
      e.vel = vecScale(dir, speed);
      e.pos = vecAdd(e.pos, vecScale(e.vel, safeDt));
      if (e.isSpinning) e.orientDeg += e.spinDegPerSec * safeDt;
      if (this._bounce(e)) wall++;
    }
    const enemy = this.config.enemies.collideWithEachOther
      ? this._resolveEnemyCollisions()
      : 0;
    this.tickNearMiss(safeDt);
    return new BounceReport(wall, enemy);
  }

  averageSpeed(secondsAlive, speedMult = 1) {
    if (this.enemies.length === 0) return 0;
    const mult = clamp(speedMult, 0, 2);
    const t = clamp(secondsAlive, 0, 3600);
    let sum = 0;
    for (const e of this.enemies) {
      sum += clamp(e.speedAt(t) * mult, 0, 4000);
    }
    return sum / this.enemies.length;
  }

  wallsKillPlayer() {
    const v = this.config?.game?.wallsKillPlayer;
    return v !== false && v !== 0 && v !== 'false' && v !== '0';
  }

  clampPlayerToField() {
    const ps = this.playerSize;
    const lo = this.wallInset;
    const hiX = Math.max(lo, this.field.width - lo - ps);
    const hiY = Math.max(lo, this.field.height - lo - ps);
    this.player = {
      dx: clamp(this.player.dx, lo, hiX),
      dy: clamp(this.player.dy, lo, hiY),
    };
  }

  movePlayerBy(delta) {
    if (delta.dx === 0 && delta.dy === 0) return;
    this.player = vecAdd(this.player, delta);
    this.playerDistance += dist(delta.dx, delta.dy);
    if (this.isJumping) this._evaluateJumpOver();
    else this._evaluateNearMiss();
  }

  tickNearMiss(dt) {
    this.nearMissFx = this.nearMissFx.filter((fx) => fx.update(dt));
    if (this.isJumping) this._evaluateJumpOver();
    else this._evaluateNearMiss();
  }

  _evaluateJumpOver() {
    if (!this.isJumping) return;
    const pr = makeRect(this.player.dx, this.player.dy, this.playerSize, this.playerSize);
    for (let i = 0; i < this.enemies.length; i++) {
      if (this._jumpOverCounted.has(i)) continue;
      if (!rectOverlaps(pr, this.enemies[i].rect)) continue;
      this._jumpOverCounted.add(i);
      this.nearMissCount++;
      const mid = {
        dx: (pr.center.dx + this.enemies[i].rect.center.dx) / 2,
        dy: (pr.center.dy + this.enemies[i].rect.center.dy) / 2,
      };
      this.nearMissFx.push(new NearMissFx(mid));
    }
  }

  _evaluateNearMiss() {
    if (this.isJumping) return;
    const pr = makeRect(this.player.dx, this.player.dy, this.playerSize, this.playerSize);
    const stillArmed = new Set();
    for (let i = 0; i < this.enemies.length; i++) {
      const gap = GameWorld._aabbGap(pr, this.enemies[i].rect);
      if (gap <= 0) continue;
      if (gap <= GameWorld.NEAR_ENTER) {
        this._nearArmed.add(i);
        stillArmed.add(i);
      } else if (gap >= GameWorld.NEAR_EXIT && this._nearArmed.has(i)) {
        this.nearMissCount++;
        const mid = {
          dx: (pr.center.dx + this.enemies[i].rect.center.dx) / 2,
          dy: (pr.center.dy + this.enemies[i].rect.center.dy) / 2,
        };
        this.nearMissFx.push(new NearMissFx(mid));
      } else if (this._nearArmed.has(i)) {
        stillArmed.add(i);
      }
    }
    this._nearArmed = stillArmed;
  }

  static _aabbGap(a, b) {
    if (rectOverlaps(a, b)) return 0;
    const dx = Math.max(0, Math.max(a.left - b.right, b.left - a.right));
    const dy = Math.max(0, Math.max(a.top - b.bottom, b.top - a.bottom));
    if (dx > 0 && dy > 0) return Math.hypot(dx, dy);
    return Math.max(dx, dy);
  }

  playerHitsBorder() {
    const ps = this.playerSize;
    const lo = this.wallInset;
    return (
      this.player.dx <= lo ||
      this.player.dy <= lo ||
      this.player.dx + ps >= this.field.width - lo ||
      this.player.dy + ps >= this.field.height - lo
    );
  }

  playerHitsEnemy() {
    if (this.isJumping) return false;
    const pr = makeRect(this.player.dx, this.player.dy, this.playerSize, this.playerSize);
    for (const e of this.enemies) {
      if (e.overlapsAabb(pr)) return true;
    }
    return false;
  }

  _spawnEnemies() {
    let aspects = this.config.enemies.aspects.filter(
      (a) => Number.isFinite(a) && a > 0.05 && a < 50,
    );
    if (aspects.length === 0) aspects = [1, 0.25, 0.5, 3];
    const count = aspects.length;
    const ns = shuffle(Array.from({ length: Math.max(count, 4) }, (_, i) => i % 4), this._rng);
    const assignedN = ns.slice(0, count);
    const fieldQs = shuffle(
      Array.from({ length: Math.max(count, 4) }, (_, i) => i % 4),
      this._rng,
    );
    const assignedFieldQ = fieldQs.slice(0, count);
    const result = [];
    for (let i = 0; i < count; i++) {
      result.push(
        this._createEnemy({
          aspect: aspects[i],
          quadrantN: assignedN[i],
          fieldQuadrant: assignedFieldQ[i],
        }),
      );
    }
    return result;
  }

  _createEnemy({ aspect, quadrantN, fieldQuadrant }) {
    const playerArea = Math.max(1, this.playerSize * this.playerSize);
    const areaMult = clamp(this.config.enemies.areaMultiplier, 0.2, 20);
    const area = playerArea * areaMult;
    const safeAspect = clamp(aspect, 0.05, 50);
    const h = Math.sqrt(area / safeAspect);
    const w = Math.sqrt(area * safeAspect);
    const safePos = this._randomPosInQuadrant(fieldQuadrant, w, h);
    const angleDeg = this._angleForQuadrant(quadrantN);
    const rad = (angleDeg * PI) / 180;
    const initialSpeed = this._lerpRandom(
      this.config.enemies.speedMin,
      this.config.enemies.speedMax,
    );
    const acceleration = this._lerpRandom(
      this.config.enemies.accelMin,
      this.config.enemies.accelMax,
    );
    const vel = { dx: Math.cos(rad) * initialSpeed, dy: Math.sin(rad) * initialSpeed };
    const spin = this.config.enemies.spinDegPerSec;
    const body = new EnemyBody({
      pos: safePos,
      vel,
      w,
      h,
      aspect,
      angleDeg,
      quadrantN,
      fieldQuadrant,
      initialSpeed,
      acceleration,
      spinDegPerSec: spin,
      orientDeg: Math.abs(spin) > 0.01 ? this._rng() * 360 : 0,
    });
    body.homePos = { dx: body.pos.dx, dy: body.pos.dy };
    body.homeVel = { dx: body.vel.dx, dy: body.vel.dy };
    body.idleT = 0;
    body.idlePhase = this._rng() * PI * 2;
    body.idlePhase2 = this._rng() * PI * 2;
    body.idleWx = 1.15 + this._rng() * 0.85;
    body.idleWy = 0.85 + this._rng() * 0.85;
    return body;
  }

  _randomPosInQuadrant(fieldQuadrant, w, h) {
    const pad = Math.max(8, this.wallInset + 2);
    const midX = this.field.width / 2;
    const midY = this.field.height / 2;
    let minX, maxX, minY, maxY;
    switch (fieldQuadrant % 4) {
      case 0:
        minX = pad; maxX = midX - w - pad; minY = pad; maxY = midY - h - pad;
        break;
      case 1:
        minX = midX + pad; maxX = this.field.width - w - pad; minY = pad; maxY = midY - h - pad;
        break;
      case 2:
        minX = pad; maxX = midX - w - pad; minY = midY + pad; maxY = this.field.height - h - pad;
        break;
      default:
        minX = midX + pad; maxX = this.field.width - w - pad;
        minY = midY + pad; maxY = this.field.height - h - pad;
    }
    if (maxX < minX) {
      minX = pad;
      maxX = Math.max(pad, this.field.width - w - pad);
    }
    if (maxY < minY) {
      minY = pad;
      maxY = Math.max(pad, this.field.height - h - pad);
    }
    const playerRect = makeRect(
      this.player.dx - this.playerSize * 0.6,
      this.player.dy - this.playerSize * 0.6,
      this.playerSize * 2.2,
      this.playerSize * 2.2,
    );
    for (let attempt = 0; attempt < 12; attempt++) {
      const x = minX + this._rng() * Math.max(1, maxX - minX);
      const y = minY + this._rng() * Math.max(1, maxY - minY);
      const candidate = { dx: x, dy: y };
      const candRect = makeRect(candidate.dx, candidate.dy, w, h);
      if (!rectOverlaps(candRect, playerRect)) return candidate;
    }
    return {
      dx: clamp(minX, pad, this.field.width - w - pad),
      dy: clamp(minY, pad, this.field.height - h - pad),
    };
  }

  _angleForQuadrant(n) {
    const minA = Math.min(this.config.enemies.angleMinDeg, this.config.enemies.angleMaxDeg);
    const maxA = Math.max(this.config.enemies.angleMinDeg, this.config.enemies.angleMaxDeg);
    let a = minA + this._rng() * (maxA - minA) + 90 * n;
    if (a >= 360) a -= 360;
    return a;
  }

  _lerpRandom(a, b) {
    const lo = Math.min(a, b);
    const hi = Math.max(a, b);
    return lo + this._rng() * (hi - lo);
  }

  _nudgeInside(e) {
    let cen = e.center;
    for (let iter = 0; iter < 3; iter++) {
      e.setCenter(cen);
      const bounds = this._cornerBounds(e);
      const lo = this.wallInset;
      const hiX = this.field.width - this.wallInset;
      const hiY = this.field.height - this.wallInset;
      let dx = 0, dy = 0;
      if (bounds.minX < lo) dx = lo - bounds.minX;
      else if (bounds.maxX > hiX) dx = hiX - bounds.maxX;
      if (bounds.minY < lo) dy = lo - bounds.minY;
      else if (bounds.maxY > hiY) dy = hiY - bounds.maxY;
      if (dx === 0 && dy === 0) break;
      cen = { dx: cen.dx + dx, dy: cen.dy + dy };
    }
    e.setCenter(cen);
  }

  _cornerBounds(e) {
    const cs = e.corners;
    let minX = cs[0].dx, maxX = cs[0].dx, minY = cs[0].dy, maxY = cs[0].dy;
    for (const p of cs) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return { minX, maxX, minY, maxY };
  }

  _bounce(e) {
    let cen = e.center;
    let hit = false;
    for (let iter = 0; iter < 3; iter++) {
      e.setCenter(cen);
      const bounds = this._cornerBounds(e);
      const lo = this.wallInset;
      const hiX = this.field.width - this.wallInset;
      const hiY = this.field.height - this.wallInset;
      let dx = 0, dy = 0;
      if (bounds.minX < lo) {
        dx = lo - bounds.minX;
        e.reflectVelocity({ dx: 1, dy: 0 });
        hit = true;
      } else if (bounds.maxX > hiX) {
        dx = hiX - bounds.maxX;
        e.reflectVelocity({ dx: -1, dy: 0 });
        hit = true;
      }
      if (bounds.minY < lo) {
        dy = lo - bounds.minY;
        e.reflectVelocity({ dx: 0, dy: 1 });
        hit = true;
      } else if (bounds.maxY > hiY) {
        dy = hiY - bounds.maxY;
        e.reflectVelocity({ dx: 0, dy: -1 });
        hit = true;
      }
      if (dx === 0 && dy === 0) break;
      cen = { dx: cen.dx + dx, dy: cen.dy + dy };
    }
    e.setCenter(cen);
    return hit;
  }

  _resolveEnemyCollisions() {
    let hits = 0;
    for (let i = 0; i < this.enemies.length; i++) {
      for (let j = i + 1; j < this.enemies.length; j++) {
        const a = this.enemies[i];
        const b = this.enemies[j];
        if (!rectOverlaps(a.rect, b.rect)) continue;
        const mtv = a.mtvOutOfObb(b);
        if (!mtv) continue;
        hits++;
        const half = vecScale(mtv, 0.5);
        a.setCenter(vecAdd(a.center, half));
        b.setCenter(vecSub(b.center, half));
        a.reflectVelocity(mtv);
        b.reflectVelocity({ dx: -mtv.dx, dy: -mtv.dy });
        this._bounce(a);
        this._bounce(b);
      }
    }
    return hits;
  }
}
