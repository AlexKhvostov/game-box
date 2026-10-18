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
  await page.evaluate(async () => {
    const app=window.app,e=app.economy;
    const target=document.getElementById('touch-zone');app._touchZone=null;
    const ev=(type,id,x,ts)=>({type,pointerId:id,clientX:x,clientY:400,timeStamp:ts,target,preventDefault(){}});
    app._onPointerDown(ev('pointerdown',99,100,0));
    if(app.phase!=='idle'||app.sheets.isOpen)throw Error('Tap opened/started');
    app._onPointerMove(ev('pointermove',99,110,10));await app._startingRound;
    if(app.primaryPointer!==99||app.phase!=='playing')throw Error('Swipe lost controlling finger');
    app._onPointerUp(ev('pointerup',99,110,20));
    app.world.enemies=[];
    if(e.round.cost!==e.energyCfg.roundCost || e.round.loadout.model!=='abilities-v2') throw Error('Start still sells a loadout');
    const before=e.energy;
    app._onPointerDown(ev('pointerdown',1,100,30));app._onPointerDown(ev('pointerdown',2,120,40));
    if(!app.world.isJumping || e.energy!==before-e.energyCfg.jumpUseCost || app.jumpCooldownLeft!==4) throw Error('Jump cost/cooldown');
    app._onPointerDown(ev('pointerdown',1,100,30));app._onPointerDown(ev('pointerdown',2,120,40));if(e.energy!==before-e.energyCfg.jumpUseCost)throw Error('Repeated jump charged in cooldown');
    app._onPointerUp(ev('pointerup',2,120,50));app._onPointerUp(ev('pointerup',1,100,60));
    for(const [type,ts] of [['pointerdown',100],['pointerup',140],['pointerdown',220],['pointerup',250]])app[type==='pointerdown'?'_onPointerDown':'_onPointerUp'](ev(type,1,100,ts));
    const charged=e.energy;
    app._tryImpulse();if(e.energy!==charged || app.impulseCooldownLeft!==8)throw Error('Impulse cooldown/cost');
    app.sheets.open('energy');if(app.sheets.isOpen||app.paused)throw Error('Menu paused/opened during play');
    app.startInvulnLeft=0;app.helmetInvulnLeft=0;
    const helmetBefore=e.energy;app._triggerImpact(false);
    if(app.phase!=='playing'||app.shieldCooldownLeft!==10||e.energy!==helmetBefore-e.energyCfg.shieldCost)throw Error('Automatic helmet cost/cooldown');
    app.helmetInvulnLeft=0;
    e._applyEnergy({...e.energyWallet,base:0,reserve:0,revision:e.energyWallet.revision+1});
    app.jumpCooldownLeft=0;app.impulseCooldownLeft=0;app.world.jumpRemaining=0;
    app._onPointerDown(ev('pointerdown',1,100,30));app._onPointerDown(ev('pointerdown',2,120,40));app._tryImpulse();
    if(app.world.isJumping||app.impulseCooldownLeft||app.sheets.isOpen)throw Error('No energy interrupted game');
    e._applyEnergy({...e.energyWallet,base:70,reserve:0,revision:e.energyWallet.revision+1});
    app.showToast('Forbidden');app._boostNotice('Forbidden','jump');
    if(document.getElementById('boost-notices').children.length)throw Error('Notice covers field');
    if([...document.querySelectorAll('.hud button')].some(b=>!b.disabled))throw Error('HUD is interactive during play');
  });
  assert.equal(await page.locator('#round-input-surface').isVisible(),true);
  const consumed = await page.evaluate(()=>window.app.economy.energy);
  await page.mouse.move(30,115);await page.mouse.down();await page.mouse.move(35,118);await page.mouse.up();
  assert.equal(await page.evaluate(()=>window.app.sheets.isOpen),false);
  assert.equal(await page.evaluate(()=>window.app.economy.energy),consumed);
  await page.evaluate(async()=>{
    const app=window.app,e=app.economy;
    app._resetToIdle();
    e.preview=false;
    const original=e.energyRequest.bind(e);
    let first=true, accepted=new Set(), calls=0;
    e.energyRequest=async(action,item,id)=>{
      if(action!=='ability')return original(action,item,id);
      calls++;
      if(!accepted.has(id)){accepted.add(id);e._applyEnergy({...e.energyWallet,base:e.energyWallet.base-item.expectedCost,revision:e.energyWallet.revision+1});}
      if(first){first=false;throw Error('Lost acknowledgment');}
      return {wallet:e.energyWallet};
    };
    e.round={id:'queue-test-round',loadout:{model:'abilities-v2',rules:{jump:{cost:2,cooldownMs:4000}}}};
    if(!e.useAbility('jump',0))throw Error('Ability not queued');
    await e._abilityFlush.catch(()=>{});
    if(e.pendingAbilities.length!==1)throw Error('Lost response discarded request');
    await e.flushAbilities();
    if(e.pendingAbilities.length||accepted.size!==1||calls!==2)throw Error('Ability retry not idempotent');
    e.energyRequest=original;e.preview=true;
    e._applyEnergy({...e.energyWallet,base:100,revision:e.energyWallet.revision+1});
  });
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
      if(productSize.width===390) await page.screenshot({path:path.join(process.env.TEMP,`untouch-compact-${mode}-${theme}.png`)});
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
  assert.equal(await page.locator('#product-panel-title').innerText(),'Книга способностей');
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
  await page.screenshot({path:path.join(process.env.TEMP,'untouch-compact-result-light.png')});
  await page.locator('#result-ok').click();
  assert.equal(await page.evaluate(()=>window.app.phase),'idle');
  await page.evaluate(()=>window.app.sheets.open('profile'));
  await page.setViewportSize({width:320,height:640});await page.waitForTimeout(300);
  await page.evaluate(()=>window.app.sheets.close(true));await page.waitForTimeout(220);
  assert.equal(await page.locator('#sheet-root').evaluate(e=>e.style.pointerEvents),'none');
  assert.ok(await page.locator('#game-canvas').evaluate(e=>e.getBoundingClientRect().right<=innerWidth),'Field was not resized after closing a menu');
  assert.deepEqual(errors, []);
  console.log('PASS: per-use energy/recharge, active full-screen input and blocked menus/notifications, header timer, 44px controls; every window at 320/390/430 dark/light, internal overflow, profile save/error/discard, close/reopen race, late reward/start, ranking/detail, share/back to result and restart. Browser fixtures only.');
} finally { await browser.close(); await new Promise(resolve => server.close(resolve)); }
