import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import '../public/kernel/android-world.js';
import {jumpGlowProgress} from '../src/game/jump-glow-progress.ts';
const baseline = JSON.parse(fs.readFileSync(new URL('../src/generated/android-config.json', import.meta.url))).config;
const call = data => JSON.parse(globalThis.untouchKernel(JSON.stringify(data)));

test('real compiled snapshots expose equipped/allowed jump and remaining flight', () => {
  for (const equipped of [false, true]) for (const allowed of [false, true]) {
    const config = structuredClone(baseline); config.game.jumpEnabled = allowed;
    const s = call({op: 'create', config, requestId: 'glow-equipment', hadJump: equipped, hadHelmet: false});
    assert.equal(s.jumpEnabled, equipped && allowed); assert.equal(s.jumpRemainingMs, 0);
    assert.equal(jumpGlowProgress(s, config.game), equipped && allowed ? 1 : 0);
  }
});

test('glow follows actual zero/short/normal/long cooldown and never becomes ready mid-air', () => {
  for (const seconds of [0, .1, .5, 2, 20]) {
    const config = structuredClone(baseline); config.game.jumpCooldownSec = seconds; config.game.startInvulnSec = 30;
    call({op: 'create', config, requestId: 'glow-cooldown', hadJump: true, hadHelmet: true});
    let s = call({op: 'start'}); assert.equal(jumpGlowProgress(s, config.game), 1);
    s = call({op: 'jump'}); assert.equal(s.jumpCount, 1); assert.equal(jumpGlowProgress(s, config.game), 0);
    s = call({op: 'jump'}); assert.equal(s.jumpCount, 1); assert.equal(jumpGlowProgress(s, config.game), 0);
    let previous = 0;
    for (let frame = 0; frame < Math.ceil(Math.max(seconds, .38) * 1000 / 25) + 2; frame++) {
      s = call({op: 'tick', ms: 25});
      const p = jumpGlowProgress(s, config.game);
      assert.ok(Number.isFinite(p) && p >= previous && p <= 1);
      if (s.jumpRemainingMs > 0) assert.ok(p < 1, `not ready in flight at ${seconds}`);
      previous = p;
    }
    assert.equal(s.jumpRemainingMs, 0); assert.equal(jumpGlowProgress(s, config.game), 1);
    s = call({op: 'jump'}); assert.equal(s.jumpCount, 2); assert.equal(jumpGlowProgress(s, config.game), 0);
  }
});

test('readiness is independent of helmet and fails closed for malformed or old snapshots', () => {
  const s = {jumpEnabled: true, jumpRemainingMs: 0, jumpCooldownMs: 1000};
  for (const helmet of [true, false]) assert.equal(jumpGlowProgress({...s, helmet}, baseline.game), .5);
  for (const value of [NaN, Infinity, -1]) {
    assert.equal(jumpGlowProgress({...s, jumpCooldownMs: value}, baseline.game), 0);
    assert.equal(jumpGlowProgress({...s, jumpRemainingMs: value}, baseline.game), 0);
  }
  assert.equal(jumpGlowProgress({...s, jumpRemainingMs: undefined}, baseline.game), 0);
  assert.equal(jumpGlowProgress({...s, jumpEnabled: false}, baseline.game), 0);
});
