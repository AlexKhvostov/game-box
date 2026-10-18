// Offline audit scenarios. Run: node --experimental-vm-modules tools/audit_telegram.mjs
// Uses the actual source in an isolated VM; no browser, network, or game data writes.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { performance } from 'node:perf_hooks';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'telegram-web/config/gameplay-config.json'), 'utf8'));
const storage = new Map();
const noop = () => {};
const doc = { documentElement: { style: { setProperty: noop }, setAttribute: noop } };
const context = vm.createContext({
  console, performance, Date, URLSearchParams, AbortController,
  window: {}, document: doc,
  localStorage: { getItem: k => storage.get(k) ?? null, setItem: (k, v) => storage.set(k, v), removeItem: k => storage.delete(k) },
  fetch: async () => ({ ok: true, json: async () => ({ scores: [] }), text: async () => '{}' }),
  requestAnimationFrame: noop, setTimeout, clearTimeout, setInterval, clearInterval,
});
const modules = new Map();
function getModule(filename) {
  if (modules.has(filename)) return modules.get(filename);
  let source = fs.readFileSync(filename, 'utf8');
  if (filename.endsWith('main.js')) {
    source = source.slice(0, source.indexOf('\nconst app = new UntouchApp();')) + '\nexport { UntouchApp };';
  }
  const mod = new vm.SourceTextModule(source, { context, identifier: filename });
  modules.set(filename, mod);
  return mod;
}
const main = getModule(path.join(root, 'telegram-web/js/main.js'));
await main.link((specifier, referencing) => getModule(path.resolve(path.dirname(referencing.identifier), specifier)));
await main.evaluate();
const { UntouchApp } = main.namespace;
const { GameWorld, EnemyBody } = modules.get(path.join(root, 'telegram-web/js/game-world.js')).namespace;
const { EconomyStore } = modules.get(path.join(root, 'telegram-web/js/economy.js')).namespace;
const { runStepsFromPx, calcScore } = modules.get(path.join(root, 'telegram-web/js/util.js')).namespace;
const { ImpactBurst } = modules.get(path.join(root, 'telegram-web/js/impact-burst.js')).namespace;
const observations = [];
function report(name, details) { observations.push({ name, ...details }); }
function world() {
  const w = new GameWorld({ config: structuredClone(config), fieldW: 380, fieldH: 380, rng: () => 0.5, wallInset: 3 });
  w.resetLayout();
  return w;
}

const loop = Object.create(UntouchApp.prototype);
Object.assign(loop, { lastTs: 1000, phase: 'playing', _hudAcc: 0, _draw: noop, _updateInfoBar: noop, _tick(dt) { this.simulatedMs += dt * 1000; }, simulatedMs: 0 });
for (let ts = 1100; ts <= 2000; ts += 100) loop._loop(ts);
assert.equal(loop.simulatedMs, 500);
report('10 FPS clock', { wallMs: 1000, simulationMs: loop.simulatedMs });
loop.sheets = { isOpen: true };
loop._loop(2100);
assert.equal(loop.simulatedMs, 550);
report('Sheet open does not pause loop', { additionalSimulationMs: 50 });

const w = world();
w.player = { dx: 20, dy: 100 };
w.enemies = [new EnemyBody({ pos: { dx: 100, dy: 90 }, vel: { dx: 0, dy: 0 }, w: 20, h: 70, aspect: 1, initialSpeed: 0, acceleration: 0 })];
const input = Object.create(UntouchApp.prototype);
Object.assign(input, { phase: 'playing', world: w, primaryPointer: 1, primaryLastPos: { x: 20, y: 100 }, _isInvulnerable: () => false, _triggerImpact() { this.hit = true; }, hit: false });
input._onPointerMove({ pointerId: 1, clientX: 200, clientY: 100 });
assert.equal(input.hit, false);
report('Pointer crosses enemy', { fromX: 20, toX: 200, enemyX: 100, hitDetected: input.hit });
input._onPointerMove({ pointerId: 1, getCoalescedEvents: () => [{ clientX: 100, clientY: 100 }, { clientX: 200, clientY: 100 }] });
assert.equal(input.hit, false);
report('Coalesced pointer crosses and exits enemy', { intermediateX: 100, finalX: 200, hitDetected: input.hit });

const jumpWorld = world();
jumpWorld.tryJump();
jumpWorld.tickJump(config.game.jumpDurationSec);
assert.equal(jumpWorld.tryJump(), true);
report('Jump retrigger', { nextJumpImmediatelyAvailable: true, durationSec: config.game.jumpDurationSec });
const outside = world();
outside.movePlayerBy({ dx: 10000, dy: 0 });
report('Unbounded movement distance', { distancePx: outside.playerDistance, runSteps: runStepsFromPx(outside.playerDistance, outside.playerSize), outsideField: outside.playerHitsBorder() });

EconomyStore.prototype.syncCommunityScores = async () => {};
storage.clear();
const first = new EconomyStore(structuredClone(config));
const initial = first.tokens;
first.applyWallet({ tokens: 500, plusUntilMs: 0 });
first.tokens -= 400;
first._save();
const remaining = first.tokens;
storage.clear();
const reinstalled = new EconomyStore(structuredClone(config));
reinstalled.applyWallet({ tokens: 500, plusUntilMs: 0 });
assert.equal(reinstalled.tokens, initial + 500);
report('Wallet after storage reset', { initialTokens: initial, remainingBeforeReset: remaining, afterResetAndSync: reinstalled.tokens });
reinstalled.plusUntilMs = Date.now() + 100000;
reinstalled._refreshPremiumFromUntil();
reinstalled.plusUntilMs = Date.now() - 1;
assert.equal(reinstalled.hasPremium, true);
report('Plus expiration without refresh', { pastExpiry: true, hasPremiumStillTrue: reinstalled.hasPremium });
report('Referral reward mismatch', { configuredReward: config.economy.earnActions.find(a => a.id === 'invite_friend').reward, effectiveReward: reinstalled.inviteRewardPerFriend });
report('Daily after seventh consecutive day', { daily: reinstalled.dailyTokensForStreak(100), matureWeek: 7 * reinstalled.dailyTokensForStreak(100), firstWeek: config.economy.dailyRewardTokens.reduce((a, b) => a + b, 0) });

const burst = ImpactBurst.spawn({ origin: { dx: 100, dy: 100 }, accent: '#3DDC97', danger: '#FF5A5F', againstWall: false, rng: () => 0.5 });
burst.update(0.42);
assert.ok(burst._glyphs.some(g => g.life > 0));
report('Impact at result transition', { ageSec: burst.age, liveGlyphs: burst._glyphs.filter(g => g.life > 0).length });
report('Score example', { stationary30Sec: calcScore(30000, 0, 0), active10Sec100Steps3Risks: calcScore(10000, 100, 3) });

const samples = [];
for (let sample = 0; sample < 5; sample++) {
  const b = world();
  for (let i = 0; i < 1000; i++) b.tickPlay(1 / 60, 20, 1);
  const t0 = performance.now();
  for (let i = 0; i < 10000; i++) b.tickPlay(1 / 60, 20, 1);
  samples.push((performance.now() - t0) / 10000);
}
samples.sort((a, b) => a - b);
report('Desktop Node physics microbenchmark', { enemies: config.enemies.aspects.length, stepsPerSample: 10000, medianMsPerStep: Number(samples[2].toFixed(4)), minMsPerStep: Number(samples[0].toFixed(4)), maxMsPerStep: Number(samples[4].toFixed(4)), excludes: 'Canvas, DOM, GPU, Telegram WebView, mobile CPU' });
console.log(JSON.stringify({ date: '2026-10-02', node: process.version, observations }, null, 2));
