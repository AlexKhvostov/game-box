import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import { pathToFileURL } from 'node:url';
const root = process.env.UNTOUCH_WEB_ROOT || path.resolve(import.meta.dirname, '../telegram-web');
const { chromium } = await import(pathToFileURL(path.join(process.env.UNTOUCH_BROWSER_MODULES, 'playwright/index.mjs')));
const config = JSON.parse(await fs.readFile(path.join(root, 'config/gameplay-config.json'), 'utf8'));
config.player.showFace = true;
const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    if (url.pathname === '/api/config.php') { res.setHeader('Content-Type', 'application/json'); res.end(JSON.stringify({ ok: true, config, revision: 'test' })); return; }
    if (url.pathname.startsWith('/api/')) { res.setHeader('Content-Type', 'application/json'); res.end(JSON.stringify({ scores: [] })); return; }
    const relative = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
    const file = path.resolve(root, relative);
    if (!file.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; }
    let data = await fs.readFile(file);
    const type = { '.js': 'text/javascript', '.json': 'application/json', '.css': 'text/css', '.html': 'text/html', '.svg': 'image/svg+xml', '.png': 'image/png' }[path.extname(file)] || 'application/octet-stream';
    if (relative === 'js/main.js') data = Buffer.concat([data, Buffer.from('\nexport { app, UntouchApp };\n')]);
    res.setHeader('Content-Type', type); res.end(data);
  } catch { res.writeHead(404); res.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, hasTouch: true });
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.route(/https:\/\//, route => route.fulfill({ body: '', contentType: 'text/javascript' }));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.locator('#boot-loader').waitFor({ state: 'hidden' });
  assert.equal(await page.evaluate(()=>window.app.economy.constructor.name),'EconomyStore');
  assert.equal(await page.evaluate(()=>Boolean(window.app.config.economy.energy)),false);
  assert.equal(await page.locator('link[href*="product.css"],link[href*="energy.css"]').count(),0);
  await page.evaluate(()=>{
    const app=window.app;
    if(typeof app.economy.lives!=='number'||typeof app.economy.tokens!=='number')throw Error('Legacy balances missing');
    app._touchZone=null;
    const target=document.getElementById('touch-zone');
    const event={pointerId:1,clientX:150,clientY:350,target,preventDefault(){}};
    app._onPointerDown(event);app.world.enemies=[];
    if(app.phase!=='playing'||app.sheets.isOpen)throw Error('Original start failed');
    app._onPointerMove({...event,clientX:155});
    app._onPointerUp(event);app._resetToIdle();
  });
  for (const mode of ['lives','crystals','leaderboard','profile']) {
    await page.evaluate(mode=>window.app.sheets.open(mode),mode);
    await page.waitForTimeout(250);
    assert.equal(await page.locator('#sheet-root').isVisible(),true);
    await page.screenshot({path:path.join(process.env.TEMP,`untouch-rollback-${mode}.png`)});
    await page.evaluate(()=>window.app.sheets.close());await page.waitForTimeout(250);
  }
  await page.screenshot({path:path.join(process.env.TEMP,'untouch-rollback-game.png')});
  const clean=s=>s.replace(/\?v=v[\d._]+/g,'');
  const old=path.resolve(import.meta.dirname,'../releases/v1.0.22_20261003_233329_134/site');
  for(const dir of ['js','css','admin'])for(const name of await fs.readdir(path.join(old,dir))){
    if (['js/main.js', 'js/game-world.js', 'js/economy.js', 'js/renderer.js', 'js/adsgram.js', 'js/sheets.js', 'css/app.css', 'css/sheets.css', 'js/game-icons.js', 'admin/config-schema.json'].includes(`${dir}/${name}`)) continue;
    const a=await fs.readFile(path.join(old,dir,name),'utf8'),b=await fs.readFile(path.join(root,dir,name),'utf8');
    assert.equal(clean(b).replace(/^\uFEFF/,''),clean(a).replace(/^\uFEFF/,''),`Different original file: ${dir}/${name}`);
  }
  // Check exactly the unchanged game/input methods, including score calculation.
  for (const name of ['_onPointerDown', '_onPointerMove', '_onPointerUp', '_startGame', '_tick', '_loop', '_finishImpact']) {
    const before = clean(await fs.readFile(path.join(old, 'js/main.js'), 'utf8'));
    const after = clean(await fs.readFile(path.join(root, 'js/main.js'), 'utf8'));
    const method = source => source.match(new RegExp(`^  ${name}\\([^]*?(?=^  [\\w$]+\\(|^})`, 'm'))?.[0];
    assert.ok(method(before), name);
    assert.equal(method(after), method(before), `Gameplay changed: ${name}`);
  }
  for (const width of [320, 360, 390, 430]) {
    await page.setViewportSize({ width, height: 844 });
    for (const light of [false, true]) {
      const bounds = await page.evaluate(light => {
        document.body.classList.toggle('theme-light', light);
        const app = window.app;
        app.economy.lives = 99999; app.economy.tokens = 99999999; app.economy.bestTimeMs = 99999999;
        app._updateHud();
        const walletWidths = ['hud-lives-chip','hud-crystals-chip'].map(id => document.getElementById(id).getBoundingClientRect().width);
        if (Math.abs(walletWidths[0] - walletWidths[1]) > 0.1) throw Error('Wallet sizes differ');
        const abilityWidths = [...document.querySelectorAll('.hud .rent-chip')].map(el => el.getBoundingClientRect().width);
        if (Math.abs(abilityWidths[0] - abilityWidths[1]) > 0.1) throw Error('Ability sizes differ');
        const avatar = document.getElementById('hud-profile-btn').getBoundingClientRect();
        const previous = document.getElementById('hud-record-chip').getBoundingClientRect();
        for (const id of ['hud-lives', 'hud-crystals', 'hud-record']) {
          const value = document.getElementById(id);
          const rect = value.getBoundingClientRect();
          const chip = value.parentElement.getBoundingClientRect();
          if (value.scrollWidth > value.clientWidth + 1 || rect.left < chip.left + 5 || rect.right > chip.right - 5) throw Error(`Clipped number or missing padding: ${id}`);
          if (getComputedStyle(value).textOverflow === 'ellipsis') throw Error('Numbers must not be abbreviated');
        }
        return { right: avatar.right, bottom: avatar.bottom, recordTop: previous.top, width: avatar.width, recordWidth: previous.width };
      }, light);
      assert.ok(bounds.right <= width - 7, JSON.stringify({width, bounds}));
      assert.ok(bounds.bottom <= bounds.recordTop, 'Account overlaps record');
      assert.ok(Math.abs(bounds.width - bounds.recordWidth) < 0.1);
    }
  }
  await page.evaluate(() => {
    const app = window.app;
    const cfg = structuredClone(app.config); cfg.game.wallsKillPlayer = false; delete cfg.game.jumpCooldownSec;
    const world = new app.world.constructor({ config: cfg, fieldW: 380, fieldH: 380, wallInset: 3 });
    world.resetLayout(); world.enemies = [];
    world.player = { dx: 3, dy: 3 }; world.playerDistance = 0;
    for (let i = 0; i < 100; i++) world.movePlayerBy({ dx: -100, dy: -100 });
    if (world.playerDistance !== 0) throw Error('Corner farms steps');
    world.movePlayerBy({ dx: -100, dy: 12 });
    if (world.playerDistance !== 12) throw Error('Wall sliding counts finger path');
    world.player = { dx: 10, dy: 10 }; world.playerDistance = 0;
    world.movePlayerBy({ dx: -1000, dy: -1000 });
    if (Math.abs(world.playerDistance - Math.hypot(7, 7)) > 0.001) throw Error('Overshoot counted');
    world.movePlayerBy({ dx: 3, dy: 4 });
    if (Math.abs(world.playerDistance - Math.hypot(7, 7) - 5) > 0.001) throw Error('Actual path missing');
    world.movePlayerBy({ dx: NaN, dy: 0 });
    if (!Number.isFinite(world.playerDistance)) throw Error('Invalid input poisoned distance');
    if (!world.tryJump(1000)) throw Error('First jump rejected');
    world.tickJump(10);
    if (world.tryJump(2999)) throw Error('Jump spam allowed');
    if (!world.tryJump(3000)) throw Error('Jump did not unlock at 2 seconds');
    if (world.tryJump(5000)) throw Error('Airborne jump allowed');
    world.tickJump(10);
    if (!world.tryJump(5000)) throw Error('Next landed jump rejected');
    world.resetLayout();
    if (!world.tryJump(1)) throw Error('New round kept old cooldown');
    app.phase = 'playing';
    app.world.jumpReadyAt = performance.now() + 1000; app._updateInfoBar();
    const chip = document.getElementById('jump-chip');
    if (!chip.classList.contains('recharging') || Math.abs(Number(chip.dataset.recharge) - 50) > 2) throw Error('Recharge ring progress failed');
    app.world.jumpReadyAt = 0; app._updateInfoBar();
    if (chip.classList.contains('recharging')) throw Error('Recharge ring did not clear');
    app._resetToIdle();
  });
  await page.evaluate(() => {
    const app = window.app;
    const draw = () => {
      app._draw();
      return app.ctx.getImageData(0, 0, app.ctx.canvas.width, app.ctx.canvas.height).data;
    };
    const state = JSON.stringify({ player: app.world.player, size: app.world.playerSize, phase: app.phase, lives: app.economy.lives });
    app.config.player.showFace = false; const plain = draw();
    app.config.player.showFace = true; const face = draw();
    if (!plain.some((value, i) => value !== face[i])) throw Error('Face skin not drawn');
    if (state !== JSON.stringify({ player: app.world.player, size: app.world.playerSize, phase: app.phase, lives: app.economy.lives })) throw Error('Skin changed game state');
    for (const [phase, ms, expected] of [['playing', 12345, '00:12.345'], ['impact', 62123, '01:02.123'], ['result', 62123, '01:02.123']]) {
      app.phase = phase; app.aliveMs = ms; app.resultMs = ms; app._updateInfoBar();
      if (document.getElementById('top-score').textContent !== expected) throw Error('Stopwatch failed');
    }
    app._resetToIdle();
    if (document.getElementById('top-score').textContent !== '00:00.000') throw Error('Stopwatch reset failed');
    const node = app.$('info-enemies');
    const replacement = node.cloneNode(true); node.replaceWith(replacement);
    if (app.$('info-enemies') !== replacement) throw Error('Stale cached element');
  });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.evaluate(() => { document.body.classList.remove('theme-light'); window.app._draw(); });
  await page.screenshot({ path: path.join(process.env.TEMP, 'untouch-face-skin.png') });
  // A slow body must remain covered by the timeout; all exits clear it.
  await page.evaluate(async () => {
    const store = window.app.economy;
    const saved = { fetch: window.fetch, setTimeout: window.setTimeout, clearTimeout: window.clearTimeout, upload: store._uploadLocalDayBest };
    try {
      store._uploadLocalDayBest = async () => {};
      for (const failure of [false, true]) {
        let expiry, cleared = false, callback = false;
        window.setTimeout = (fn, delay) => { if (delay !== 8000) throw Error('Unexpected timeout'); expiry = fn; return 123456; };
        window.clearTimeout = id => { if (id === 123456) cleared = true; };
        window.fetch = async (_, { signal }) => {
          if (failure) throw Error('Expected network failure');
          return { json: () => new Promise((resolve, reject) => {
            if (cleared) throw Error('Timeout cleared before body');
            signal.addEventListener('abort', () => reject(new Error('Aborted slow body')), { once: true });
            expiry();
          }) };
        };
        await store.syncCommunityScores(() => { callback = true; });
        if (!cleared || !callback) throw Error('Timeout/callback cleanup failed');
      }
    } finally { window.fetch = saved.fetch; window.setTimeout = saved.setTimeout; window.clearTimeout = saved.clearTimeout; store._uploadLocalDayBest = saved.upload; }
  });
  assert.deepEqual(errors,[]);
  await page.evaluate(async () => {
    const saved = window.Adsgram;
    try {
      for (const event of ['onTooLongSession', 'onBannerNotFound', 'onNonStopShow']) {
        const ads = await import(`/js/adsgram.js?test=${event}`);
        const listeners = new Map(); let calls = 0, inits = 0;
        window.Adsgram = { init() { inits++; return {
          addEventListener(name, handler) { listeners.set(name, handler); },
          async show() {
            calls++;
            if (calls > 1) return { done: true };
            if (!listeners.has(event)) throw Error('SDK would display blocking default alert');
            listeners.get(event)();
            throw { description: event === 'onTooLongSession' ? 'Too long session' : 'No fill' };
          }
        }; } };
        const first = await ads.showInterstitialAd('int-123').then(() => 'reward', e => e.adFail);
        const second = await ads.showInterstitialAd('int-123').then(() => 'reward', e => e.adFail);
        if (first === 'reward' || second !== 'reward' || calls !== 2 || inits !== 1) throw Error('Failed request permanently blocked later ad');
        if (event === 'onTooLongSession') {
          const crossBlock = await ads.showRewardedAd('456').then(() => 'reward', e => e.adFail);
          if (first !== 'session' || crossBlock !== 'reward' || calls !== 3) throw Error('Interstitial blocked rewarded ad');
        }
      }
      const success = await import('/js/adsgram.js?test=success');
      window.Adsgram = { init() { return { addEventListener() {}, async show() { return { done: true }; } }; } };
      if (!(await success.showRewardedAd('789')).done) throw Error('Successful ad failed');
      // Exercise the real shop and result methods, not only their adapter.
      const app = window.app, store = app.economy;
      const counts = new Map(); let rejectReward = false;
      window.Adsgram = { init({blockId}) { return { addEventListener() {}, async show() {
        const count = (counts.get(blockId) || 0) + 1; counts.set(blockId, count);
        if ((blockId.startsWith('int-') && count === 1) || (!blockId.startsWith('int-') && rejectReward)) throw { description: 'Too long session' };
        return { done: true };
      } }; } };
      store.hasPremium = false; store.interstitialArmedAtMs = 1; store.lastInterstitialMs = 0;
      store.sessionStartedAtMs = 1; store.sessionCompletedRounds = 11;
      store.lastWatchAdClaimMs = 0; store.skipWatchAdHint = true; store.lives = 185;
      app.phase = 'result';
      await app._maybeShowResultInterstitial();
      if (store.lastInterstitialMs || app._interstitialBusy) throw Error('Failed automatic ad marked successful or left busy');
      const balance = store.tokens;
      const reward = store.earnActions.find(a => a.id === 'watch_ad').reward;
      await app.sheets._watchAdForCrystals();
      if (store.tokens !== balance + reward || app.sheets._watchingAd) throw Error('Rewarded ad blocked or wrong reward');
      store.lastWatchAdClaimMs = 0; rejectReward = true;
      await app.sheets._watchAdForCrystals();
      if (store.tokens !== balance + reward || store.lastWatchAdClaimMs) throw Error('Failed reward granted crystals/cooldown');
      rejectReward = false;
      await app.sheets._watchAdForCrystals();
      if (store.tokens !== balance + reward * 2) throw Error('Reward did not recover after failure');
      await app._maybeShowResultInterstitial();
      if (!store.lastInterstitialMs || app._interstitialBusy) throw Error('Automatic ad did not recover after failure');
      app._resetToIdle();
    } finally { window.Adsgram = saved; }
  });
  console.log('PASS: actual distance at corner/wall/overshoot; 2-second jump cooldown and landing/reset/recharge; equal HUD blocks/full numbers/padding 320–430; unchanged input/scoring; advertising recovery and rewards. SDK mocked; browser emulation only.');
} finally {await browser.close();await new Promise(resolve=>server.close(resolve));}
