import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
const clockCode = await fs.readFile(new URL('../telegram-web/js/simulation-clock.js', import.meta.url), 'utf8');
const { SimulationClock } = await import('data:text/javascript;base64,' + Buffer.from(clockCode).toString('base64'));
const utilCode = await fs.readFile(new URL('../telegram-web/js/util.js', import.meta.url), 'utf8');
const utilUrl = 'data:text/javascript;base64,' + Buffer.from(utilCode).toString('base64');
const worldCode = (await fs.readFile(new URL('../telegram-web/js/game-world.js', import.meta.url), 'utf8')).replace("'./util.js'", JSON.stringify(utilUrl));
const { GameWorld, EnemyBody } = await import('data:text/javascript;base64,' + Buffer.from(worldCode).toString('base64'));
const { makeRect } = await import(utilUrl);
const config = JSON.parse(await fs.readFile(new URL('../telegram-web/config/gameplay-config.json', import.meta.url), 'utf8'));
function simulate(fps) {
  const clock = new SimulationClock();
  const world = new GameWorld({ config, fieldW: 380, fieldH: 380, rng: () => 0.25 });
  world.resetLayout();
  let time = 0;
  for (let i = 0; i <= fps * 2; i++) clock.advance(i * 1000 / fps, dt => { time += dt; world.tickPlay(dt, time); });
  return { time, positions: world.enemies.map(e => e.pos) };
}
const baseline = simulate(120);
for (const fps of [10, 15, 30, 60, 90, 144]) {
  assert.deepEqual(simulate(fps), baseline);
}
const stalled = new SimulationClock();
let ticks = 0;
stalled.advance(0, () => ticks++);
assert.equal(stalled.advance(2000, () => ticks++), false);
assert.equal(ticks, 0);
function enemy(angle = 0) { return new EnemyBody({ pos: { dx: 100, dy: 100 }, vel: { dx: 0, dy: 0 }, w: 20, h: 60, orientDeg: angle, initialSpeed: 0, acceleration: 0 }); }
const body = enemy();
assert.equal(body.sweptAabb(makeRect(0, 120, 20, 20), { dx: 200, dy: 0 }), 0.4);
assert.equal(body.sweptAabb(makeRect(0, 10, 20, 20), { dx: 200, dy: 0 }), null);
assert.ok(enemy(45).sweptAabb(makeRect(0, 120, 20, 20), { dx: 200, dy: 0 }) !== null);
assert.ok(body.sweptAabb(makeRect(220, 120, 20, 20), { dx: -200, dy: 0 }) !== null);
const world = new GameWorld({ config, fieldW: 380, fieldH: 380 });
world.player = { dx: 0, dy: 120 }; world.enemies = [body];
assert.ok(world.playerSweepHit({ dx: 200, dy: 0 }) !== null);
world.jumpRemaining = 1;
assert.equal(world.playerSweepHit({ dx: 200, dy: 0 }), null);
world.jumpRemaining = 0; world.player = { dx: 80, dy: 120 };
body.initialSpeed = 4000; body.vel = { dx: -4000, dy: 0 };
world.tickPlay(1/120, 0);
assert.equal(world.playerHitsEnemy(), true);
console.log('PASS: identical simulation at 10–144 FPS, explicit stall pause, continuous player/enemy collision, rotated rectangles and jump immunity');
