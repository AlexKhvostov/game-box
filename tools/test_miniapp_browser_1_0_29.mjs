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
  const initial = await page.evaluate(async () => { const app = window.app; return { side: app.world.field.width, energy: app.economy.energy, ready: app.economy.energyReady }; });
  assert.equal(initial.side, config.field.maxSide); assert.equal(initial.energy, config.economy.energy.initial); assert.equal(initial.ready, true);
  await page.evaluate(async () => {
    const app = window.app, target = document.getElementById('touch-zone');
    app._touchZone = null;
    const ev = (type, x) => ({type, pointerId: 99, clientX: x, clientY: 400, timeStamp: x, target, preventDefault(){}});
    app._onPointerDown(ev('pointerdown',100));
    if (app.sheets.isOpen || app.phase !== 'idle') throw Error('A tap opened preparation or charged a round');
    app._onPointerMove(ev('pointermove',110));
    const pending = app._startingRound;
    app._onPointerMove(ev('pointermove',115));
    await pending;
    if (app.phase !== 'playing' || app.sheets.isOpen || app.primaryPointer !== 99 || app.primaryLastPos.x !== 115) throw Error('Swipe did not start and retain the controlling finger');
    if (app.economy.energy !== app.config.economy.energy.initial-app.economy.selectedCost) throw Error('Swipe charged twice');
    app._onPointerUp(ev('pointerup',115));
    app._resetToIdle();
    const economy = app.economy, original = economy.energyRequest.bind(economy);
    let first = true, charged, key;
    economy.energyRequest = async (action, extra, id) => {
      if (action !== 'start') return original(action,extra,id);
      if (!charged) { key=id; charged=await original(action,extra,id); }
      if (id !== key || JSON.stringify(extra.loadout)!==JSON.stringify(charged.round.loadout)) throw Error('Retry changed the frozen start');
      if (first) { first=false; throw Error('Lost response'); }
      return charged;
    };
    try { await app._beginRound(true); throw Error('Expected lost response'); } catch(error) { if(error.message!=='Lost response') throw error; }
    const afterCharge = economy.energy;
    await app._beginRound(true);
    if(economy.energy!==afterCharge || app.phase!=='playing' || !app.paused || app.primaryPointer!==null) throw Error('Retry charged twice or released finger continued playing');
    economy.energyRequest = original;
    app._resetToIdle(); app.paused=false;
    // Restore only the isolated preview balance for the remaining scenarios.
    app.economy._applyEnergy({...app.economy.energyWallet,base:app.config.economy.energy.initial,revision:app.economy.energyWallet.revision+1});
  });
  await page.locator('#hud-crystals-chip').click();
  await page.locator('[data-jump-count="2"]').click();
  assert.equal(await page.locator('[data-jump-count="2"]').getAttribute('aria-pressed'),'true');
  await page.locator('[data-jump-count="3"]').click();
  assert.equal(await page.locator('[data-jump-count="3"]').getAttribute('aria-pressed'),'true');
  await page.locator('[data-shield]').check(); await page.locator('[data-impulse]').check();
  const cost = config.economy.energy.roundCost + config.economy.energy.jump3Cost + config.economy.energy.shieldCost + config.economy.energy.impulseCost;
  assert.equal(await page.locator('[data-round-cost]').innerText(), `${cost} ⚡`);
  assert.equal(await page.locator('[data-jump-cost]').innerText(), `+${config.economy.energy.jump3Cost} ⚡`);
  await page.screenshot({ path: path.join(process.env.TEMP, 'untouch-prepare-mobile.png') });
  await page.locator('[data-start]').click();
  const started = await page.evaluate(async () => { const app = window.app; app.world.enemies = []; return { phase: app.phase, energy: app.economy.energy, jumps: app.jumpCharges, shield: app.runHelmetActive, impulse: app.impulseCharges }; });
  assert.deepEqual(started, { phase: 'playing', energy: initial.energy - cost, jumps: 3, shield: true, impulse: 1 });
  await page.evaluate(async () => {
    const app = window.app;
    const target = document.getElementById('touch-zone');
    const event = (type, id, x, y, ts) => ({ type, pointerId: id, clientX: x, clientY: y, timeStamp: ts, target, preventDefault() {} });
    app._touchZone = null; // Synthetic unit events cannot capture a hardware pointer.
    app._onPointerDown(event('pointerdown', 1, 100, 400, 1));
    app._onPointerDown(event('pointerdown', 2, 120, 410, 5));
    if (app.jumpCharges !== 2 || !app.world.isJumping) throw new Error('Second finger did not jump');
    app._onPointerUp(event('pointerup', 2, 120, 410, 15));
    app._onPointerUp(event('pointerup', 1, 100, 400, 20));
    app._onPointerDown(event('pointerdown', 1, 100, 400, 100));
    app._onPointerUp(event('pointerup', 1, 100, 400, 140));
    app._onPointerUp(event('lostpointercapture', 1, 100, 400, 141));
    app._onPointerDown(event('pointerdown', 1, 100, 400, 220));
    app._onPointerUp(event('pointerup', 1, 100, 400, 260));
    if (app.impulseCharges !== 0 || app.impulseLeft <= 0) throw new Error('Double tap did not trigger impulse');
    app.startInvulnLeft = 0; app.helmetInvulnLeft = 0;
    app._triggerImpact(false);
    if (app.runHelmetActive || app.phase !== 'playing' || document.querySelectorAll('#boost-notices .boost-notice').length !== 3) throw new Error('Shield did not absorb a hit or usage notices did not stack');
    app._pauseGame();
    const time = app.aliveMs;
    app.clock.advance(0, dt => app._tick(dt));
    if (!app.paused || app.pointers.size || app.primaryLastPos) throw new Error('Pause failed to clear input');
    app._onPointerDown(event('pointerdown', 3, 100, 400, 400));
    if (app.paused || app.aliveMs !== time) throw new Error('Resume changed time');
  });
  await page.setViewportSize({ width: 320, height: 640 });
  await page.evaluate(() => { const e=window.app.economy; e._applyEnergy({...e.energyWallet,reserve:15000,revision:e.energyWallet.revision+1}); window.app._updateHud(); });
  const resized = await page.evaluate(async () => { const app = window.app; app._resize(); return { logical: app.world.field.width, display: app.displaySide, overflow: document.documentElement.scrollWidth > innerWidth, hudRight: document.querySelector('.hud').getBoundingClientRect().right, profileRight: document.getElementById('hud-profile-btn').getBoundingClientRect().right }; });
  assert.equal(resized.logical, initial.side); assert.ok(resized.display < initial.side); assert.equal(resized.overflow, false); assert.ok(resized.profileRight <= resized.hudRight + 1, JSON.stringify(resized));
  const chips = await page.locator('.hud').evaluate(h => [...h.children].filter(e=>getComputedStyle(e).display!=='none').map(e=>{const r=e.getBoundingClientRect(); return {left:r.left,right:r.right};}));
  for(let i=1;i<chips.length;i++) assert.ok(chips[i].left >= chips[i-1].right-1, 'HUD controls overlap');
  await page.screenshot({ path: path.join(process.env.TEMP, 'untouch-game-small.png') });
  // Simulate a lost finish response. Pending results must survive and only be
  // marked saved after both energy confirmation and score delivery succeed.
  let failFinish = true;
  await page.route('**/api/energy.php', async route => {
    if (failFinish) { await route.abort('failed'); return; }
    const input = route.request().postDataJSON();
    const wallet = await page.evaluate(() => window.app.economy.energyWallet);
    await route.fulfill({contentType:'application/json',body:JSON.stringify({ok:true,wallet,roundId:input.roundId,reward:0})});
  });
  await page.route('**/api/scores.php', route => route.fulfill({contentType:'application/json',body:JSON.stringify({ok:true,scores:[]})}));
  await page.evaluate(() => {
    const e = window.app.economy; e.preview = false;
    e.finishRun(500,0,5,{playerName:'Audit',userId:'audit-browser'});
  });
  await page.waitForFunction(() => !window.app.economy._flushing);
  assert.equal(await page.evaluate(() => window.app.economy.pendingResults.length),1);
  failFinish = false;
  await page.evaluate(() => window.app.economy.flushResults());
  assert.equal(await page.evaluate(() => window.app.economy.pendingResults.length),0);
  assert.equal(await page.evaluate(() => window.app.economy.recentAttempts.at(-1).autoSaved),true);
  await page.evaluate(() => { window.app._resetToIdle(); window.app.economy.preview=true; });
  for (const size of [{width:390,height:844},{width:320,height:640},{width:360,height:560}]) {
    await page.setViewportSize(size);
    await page.waitForTimeout(300);
    await page.evaluate(() => { document.documentElement.style.setProperty('--tg-pad-top','94px'); document.documentElement.style.setProperty('--tg-pad-bottom','24px'); });
    for (const mode of ['prepare','energy']) {
      await page.evaluate(mode => window.app.sheets.open(mode),mode);
      await page.waitForTimeout(250);
      const bounds=await page.locator('.sheet-panel').boundingBox();
      const footer=await page.locator('[data-energy-footer]').boundingBox();
      assert.ok(bounds.y>=94-1 && bounds.y+bounds.height<=size.height+1, `Panel outside safe viewport ${JSON.stringify({size,mode,bounds})}`);
      assert.ok(footer.y+footer.height<=size.height-23, `Footer must remain above bottom safe area ${JSON.stringify({size,mode,bounds,footer})}`);
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
      if(mode==='energy') {
        await page.locator('[data-energy-tab="shop"]').click();
        assert.equal(await page.locator('[data-energy-section="bonus"]').isVisible(),false);
        assert.equal(await page.locator('[data-energy-section="shop"]').isVisible(),true);
        if(size.width===320) await page.screenshot({path:path.join(process.env.TEMP,'untouch-energy-shop-compact.png')});
        await page.locator('[data-energy-tab="bonus"]').click();
        if(size.width===320) await page.screenshot({path:path.join(process.env.TEMP,'untouch-energy-bonus-compact.png')});
      } else if(size.width===320) await page.screenshot({path:path.join(process.env.TEMP,'untouch-prepare-compact.png')});
    }
  }
  assert.equal(await page.locator('.hud .rent-chip').count(),0);
  assert.equal(await page.locator('.score-strip-label').count(),0);
  assert.equal(await page.locator('#boost-notices').evaluate(e=>getComputedStyle(e).pointerEvents),'none');
  const timer = await page.locator('#score-strip').boundingBox();
  const hud = await page.locator('.hud').boundingBox();
  assert.ok(timer.y+timer.height <= hud.y, 'Timer must stay above the HUD');
  // Every active window, including populated ranking/detail and share, uses
  // the same modal/navigation contract. Fixtures never call real users/APIs.
  await page.evaluate(() => {
    const e=window.app.economy;
    e.communityScores=Array.from({length:20},(_,i)=>({userId:`fixture-${i}`,playerName:i===0?'Длинное имя <script> & кавычки "тест"':`Игрок ${i+1}`,timeMs:20000-i*100,createdAt:Date.now(),runDistance:120,riskCount:3,hadJump:true,hadHelmet:true}));
    e.syncCommunityScores=callback=>callback?.();
  });
  for (const theme of ['dark','light']) {
    await page.evaluate(theme=>document.documentElement.setAttribute('data-theme',theme),theme);
    for (const productSize of [{width:320,height:560},{width:390,height:844},{width:430,height:932}]) {
    await page.setViewportSize(productSize); await page.waitForTimeout(300);
    await page.evaluate(()=>{document.documentElement.style.setProperty('--tg-pad-top','94px');document.documentElement.style.setProperty('--tg-pad-bottom','24px');document.documentElement.style.setProperty('--tg-header-left','108px');document.documentElement.style.setProperty('--tg-header-right','76px');document.documentElement.style.setProperty('--tg-safe-top','50px');});
    for (const mode of ['prepare','energy','profile','leaderboard','share']) {
      await page.evaluate(mode=>window.app.sheets.open(mode),mode); await page.waitForTimeout(220);
      assert.equal(await page.locator('#app').evaluate(e=>e.inert),true);
      const box=await page.locator('.product-panel').boundingBox();
      assert.ok(box.y>=94 && box.y+box.height<=productSize.height+1, `Bad ${mode}/${theme} bounds`);
      const controls=await page.locator('.product-panel button').evaluateAll(elements=>elements.filter(e=>e.getClientRects().length).map(e=>({text:e.textContent.trim(),height:e.getBoundingClientRect().height})));
      for(const control of controls) assert.ok(control.height>=43, `Small touch target ${mode}: ${JSON.stringify(control)}`);
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
      assert.equal(await page.locator('.energy-content,.share-sheet-scroll').evaluate(e=>e.scrollWidth>e.clientWidth+1),false, `Internal horizontal clipping in ${mode}`);
      if(productSize.width===390) await page.screenshot({path:path.join(process.env.TEMP,`untouch-product-${mode}-${theme}.png`)});
      if(mode==='leaderboard') {
        await page.locator('[data-entry="0"]').click();
        assert.equal(await page.locator('#product-panel-title').innerText(),'Результат игрока');
        await page.locator('[data-return]').click();
        assert.equal(await page.locator('#product-panel-title').innerText(),'Рейтинг');
      }
    }
  }
  }
  await page.evaluate(()=>window.app.sheets.open('profile'));
  await page.locator('#profile-nick-input').fill('Имя после редактирования');
  await page.keyboard.press('Escape');
  assert.equal(await page.locator('[data-discard]').isVisible(),true);
  await page.locator('[data-keep-edit]').click();
  assert.equal(await page.locator('#profile-nick-input').inputValue(),'Имя после редактирования');
  await page.keyboard.press('Escape');await page.locator('[data-discard]').click();
  await page.waitForTimeout(200);
  assert.equal(await page.evaluate(()=>window.app.sheets.isOpen),false);
  assert.equal(await page.locator('#app').evaluate(e=>e.inert),false);
  // Close/reopen cannot let an old animation timer hide the new panel.
  await page.evaluate(()=>{const s=window.app.sheets;s.open('energy');s.close();s.open('prepare');});
  await page.waitForTimeout(250);
  assert.equal(await page.locator('#product-panel-title').innerText(),'Усиления');
  assert.equal(await page.locator('#sheet-root').isVisible(),true);
  await page.evaluate(()=>{window.app.sheets.open('profile'); window._profileApi=window.app.economy.updateProfile; window.app.economy.updateProfile=async()=>({local:true,ok:false});});
  await page.locator('#profile-nick-input').fill('Проверка сохранения');
  await page.locator('#profile-action-btn').click();
  assert.match(await page.locator('[data-energy-error]').innerText(),/Нет подтверждения сервера/);
  assert.equal(await page.locator('#profile-action-btn').isEnabled(),true);
  await page.evaluate(()=>window.app.economy.updateProfile=async()=>({ok:true,source:'mysql'}));
  await page.locator('#profile-action-btn').click();await page.waitForTimeout(200);
  assert.equal(await page.evaluate(()=>window.app.sheets.isOpen),false);
  await page.evaluate(async()=>{
    const app=window.app, e=app.economy;
    e.updateProfile=window._profileApi;
    const original=e.claimTimedBonus;
    let resolve;
    e.claimTimedBonus=()=>new Promise(r=>resolve=r);
    app.sheets.open('energy');
    const request=app.sheets._claimEnergy('timed');
    app.sheets.close(true);app.sheets.open('profile');
    resolve({reward:20});await request;
    if(app.sheets._type!=='profile'||!document.getElementById('profile-nick-input'))throw Error('Late reward overwrote the current profile');
    e.claimTimedBonus=original;
    app.sheets.close(true);app.sheets.open('prepare');
    const start=e.startRound;
    e.startRound=()=>new Promise(r=>resolve=r);
    const begin=app._beginRound();
    app.sheets.close(true);app.sheets.open('profile');
    resolve({id:'fixture-start',cost:e.selectedCost,loadout:{...e.loadout}});await begin;
    if(app.sheets._type!=='profile'||!app.paused||app.phase!=='playing')throw Error('Late start interrupted the new menu or played unattended');
    e.startRound=start;
    app.sheets.close(true);app._resetToIdle();
  });
  await page.evaluate(()=>{
    const app=window.app;app.sheets.close(true);app.phase='result';app.resultMs=12345;app.resultRun=250;app.resultRisk=3;app.resultScore=20;app.deathReason='Коснулись врага';app._showResult();
  });
  await page.waitForTimeout(220);
  await page.locator('#result-share-social').click();await page.waitForTimeout(200);
  await page.keyboard.press('Escape');await page.waitForTimeout(220);
  assert.equal(await page.evaluate(()=>window.app.phase),'result');
  assert.equal(await page.locator('#result-overlay').isVisible(),true);
  await page.screenshot({path:path.join(process.env.TEMP,'untouch-product-result-light.png')});
  await page.locator('#result-ok').click();
  assert.equal(await page.evaluate(()=>window.app.phase),'idle');
  await page.evaluate(()=>window.app.sheets.open('profile'));
  await page.setViewportSize({width:320,height:640});await page.waitForTimeout(300);
  await page.evaluate(()=>window.app.sheets.close(true));await page.waitForTimeout(220);
  assert.equal(await page.locator('#sheet-root').evaluate(e=>e.style.pointerEvents),'none');
  assert.ok(await page.locator('#game-canvas').evaluate(e=>e.getBoundingClientRect().right<=innerWidth),'Field was not resized after closing a menu');
  assert.deepEqual(errors, []);
  console.log('PASS: gameplay gestures/idempotent energy, header timer, 44px controls; every window at 320/390/430 dark/light, internal overflow, profile save/error/discard, close/reopen race, late reward/start, ranking/detail, share/back to result and restart. Browser fixtures only.');
} finally { await browser.close(); await new Promise(resolve => server.close(resolve)); }
