import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import { pathToFileURL } from 'node:url';

// Independent home-screen acceptance. All traffic stays on this fixture server.
const project = path.resolve(import.meta.dirname, '..');
const web = path.resolve(process.env.UNTOUCH_WEB_ROOT || path.join(project, 'telegram-web'));
const baseline = path.join(project, 'tmp/telegram-neon-migration-20261013/baseline');
const before = process.argv.includes('--baseline');
const output = path.join(project, 'docs/release-evidence/telegram-neon-home-20261013', before ? 'before' : 'after');
await fs.mkdir(output, { recursive: true });
const modules = process.env.UNTOUCH_BROWSER_MODULES || 'C:/Users/alexe/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const { chromium } = await import(pathToFileURL(path.join(modules, 'playwright/index.mjs')));
const config = JSON.parse(await fs.readFile(path.join(baseline, 'telegram-web/config/gameplay-config.json'), 'utf8'));
const failures = [], cases = [], errors = [], missing = [], external = [], apis = [];
const check = async (name, action) => { try { const value = await action(); cases.push({ name, status: 'PASS', value }); } catch (error) { failures.push({ name, error: error.message }); cases.push({ name, status: 'FAIL', error: error.message }); } };
const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    if (url.pathname.startsWith('/api/')) {
      apis.push({ path: url.pathname, method: req.method });
      res.setHeader('Content-Type', 'application/json');
      const fixture = url.pathname === '/api/config.php' ? { ok: true, config, revision: 'neon-fixture' } : { ok: true, scores: [], bound: false };
      res.end(JSON.stringify(fixture)); return;
    }
    const relative = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
    const requested = path.resolve(web, relative);
    if (!requested.startsWith(web + path.sep)) { res.writeHead(403); res.end(); return; }
    const candidates = [];
    if (before) candidates.push(path.join(baseline, 'telegram-web', relative));
    // Build overlays canonical assets onto legacy web assets, retaining JPGs.
    if (relative.startsWith('assets/')) candidates.push(path.join(project, relative));
    candidates.push(requested);
    let data;
    for (const candidate of candidates) { try { data = await fs.readFile(candidate); break; } catch {} }
    if (!data) throw Error('missing');
    const type = { '.js': 'text/javascript', '.json': 'application/json', '.css': 'text/css', '.html': 'text/html', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.mp3': 'audio/mpeg', '.wav': 'audio/wav' }[path.extname(requested)] || 'application/octet-stream';
    res.setHeader('Content-Type', type); res.end(data);
  } catch { res.writeHead(404); res.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({ headless: true });
const origin = `http://127.0.0.1:${server.address().port}`;
async function newPage(sdk = null, store = {}) {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, hasTouch: true, deviceScaleFactor: 1 });
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => { if (response.status() === 404) missing.push(response.url()); });
  await page.route('**/*', route => {
    if (new URL(route.request().url()).origin === origin) return route.continue();
    external.push(route.request().url());
    return route.fulfill({ status: 200, contentType: 'text/javascript', body: '' });
  });
  await page.addInitScript(({ sdk, store }) => {
    localStorage.setItem('untouch_tg_economy', JSON.stringify({ lives: 999, tokens: 999, bestTimeMs: 999000, musicEnabled: false, ...store }));
    if (sdk) {
      const handlers = {};
      const tg = { isFullscreen: sdk.fullscreen, safeAreaInset: sdk.safe, contentSafeAreaInset: sdk.content,
        initDataUnsafe: {}, initData: '', ready() {}, expand() {}, disableVerticalSwipes() {}, lockOrientation() {},
        setHeaderColor() {}, setBackgroundColor() {}, onEvent(name, cb) { handlers[name] = cb; } };
      if (sdk.requestFullscreen) tg.requestFullscreen = () => { throw Error('fixture fullscreen unavailable'); };
      window.Telegram = { WebApp: tg }; window.__tgEvents = handlers;
    }
  }, { sdk, store });
  await page.goto(origin);
  await page.locator('#boot-loader').waitFor({ state: 'hidden' });
  await page.evaluate(() => { window.app._tick = () => {}; window.app._hudAcc = 0; });
  return page;
}
async function state(page, mode, light = false) {
  await page.evaluate(({ mode, light }) => {
    const app = window.app;
    app.sheets.close(); app._resetToIdle();
    app.economy.lives = mode === 'empty' ? 0 : 999;
    app.economy.tokens = 999; app.economy.bestTimeMs = 999000;
    app.economy.communityScores = [{userId:'fixture-top',playerName:'Fixture',timeMs:999000,createdAt:Date.now(),scoreDay:new Date().toLocaleDateString('sv-SE')}];
    app.economy.lightTheme = light;
    app.economy.jumpRentalUntil = mode === 'active' ? Date.now() + 600000 : 0;
    app.economy.helmetRentalUntil = ['active', 'broken'].includes(mode) ? Date.now() + 600000 : 0;
    app.phase = ['playing', 'active', 'broken'].includes(mode) ? 'playing' : 'idle';
    app.runHadHelmet = ['active', 'broken'].includes(mode);
    app.runHelmetActive = mode === 'active';
    app.aliveMs = app.phase === 'playing' ? 65432 : 0;
    app.world.nearMissCount = 999; app.world.playerDistance = 999 * app.world.playerSize * .1;
    app.world.jumpReadyAt = mode === 'active' ? performance.now() + app.world.jumpCooldownMs / 2 : 0;
    document.body.classList.toggle('theme-light', light);
    document.documentElement.dataset.theme = light ? 'light' : 'dark';
    app._updateHud(); app._updateInfoBar(); app._updateOverlay(); app._draw();
  }, { mode, light });
  await page.waitForTimeout(90);
}
try {
  if (!before) {
    for (const relative of ['js/game-world.js', 'js/economy.js', 'js/sheets.js', 'config/gameplay-config.json']) await check(`unchanged/${relative}`, async () => {
      const a = await fs.readFile(path.join(baseline, 'telegram-web', relative));
      const b = await fs.readFile(path.join(web, relative)); assert.deepEqual(b, a);
      return crypto.createHash('sha256').update(b).digest('hex');
    });
    const a = await fs.readFile(path.join(baseline, 'telegram-web/js/main.js'), 'utf8');
    const b = await fs.readFile(path.join(web, 'js/main.js'), 'utf8');
    for (const name of ['_onPointerDown','_rememberPointer','_onPointerMove','_onPointerUp','_startGame','_tryJump','_isInvulnerable','_triggerImpact','_finishImpact','_tick','_speedMult','_averageSpeed']) await check(`unchanged-method/${name}`, () => {
      const method = source => source.match(new RegExp(`^  ${name}\\([^]*?(?=^  [\\w$]+\\(|^})`, 'm'))?.[0];
      assert.ok(method(a), `Baseline method missing: ${name}`);
      let actual=method(b);
      if(name==='_onPointerDown'&&actual.includes('this._openLivesExchange();')) {
        // The only permitted difference routes the same empty-wallet UI action
        // through a duplicate-dialog guard. Every gameplay statement stays exact.
        assert.match(method(b).replace(/\r/g,''), /this\._openLivesExchange\(\);/);
        assert.match(b.replace(/\r/g,''), /_openLivesExchange\(\) \{\n    if \(this\.sheets\?\.isOpen\) return;\n    this\.sheets\.open\('lives'\);\n  \}/);
        actual=actual.replace('this._openLivesExchange();',"this.sheets.open('lives');");
      }
      assert.equal(actual, method(a));
    });
  }
  const page = await newPage();
  await check('renderer-purity', () => page.evaluate(async () => {
    const { FieldRenderer } = await import('/js/renderer.js');
    const world = window.app.world;
    const snapshot = () => JSON.stringify(world);
    const initial = snapshot(); const canvas = document.createElement('canvas'); canvas.width = canvas.height = 380;
    const renderer = new FieldRenderer({});
    for (const [preview, helmet, light] of [[true,false,false],[false,false,false],[false,true,false],[false,false,true]]) {
      renderer.paint(canvas.getContext('2d'), world, { fieldSize: { width: 380, height: 380 }, fieldColor: light ? '#F7FBFD' : '#08253B', accent: '#35F5C6', danger: '#F0363E', borderColor: '#58E2EC', playerPreview: preview, hasHelmet: helmet, lightField: light, showFace: true });
    }
    if (snapshot() !== initial) throw Error('Renderer mutated world');
    return { paints: 4, cacheKeys: Object.keys(renderer) };
  }));
  if (!before) await check('background-cache-reuse',()=>page.evaluate(()=>{
    const app=window.app;
    app._draw(); const first=app.renderer._backgrounds?.get(app.ctx);
    if(!first)throw Error('Static field background not cached');
    for(let i=0;i<100;i++)app._draw();
    if(app.renderer._backgrounds.get(app.ctx)!==first)throw Error('Repeated paint recreates static field');
    for(let i=0;i<8;i++)app._updateHud();
    app._draw();
    if(app.renderer._backgrounds.get(app.ctx)!==first)throw Error('HUD update invalidates field cache');
    return {reusedAcrossPaints:100,reusedAcrossHudUpdates:8};
  }));
  for (const width of [320,360,390,430]) for (const height of [480,560,844]) {
    await page.setViewportSize({width,height});
    for (const light of [false,true]) for (const mode of ['idle','playing','empty','active','broken']) {
      await state(page, mode, light);
      const name = `${width}x${height}-${light?'light':'dark'}-${mode}`;
      await page.screenshot({ path: path.join(output, `${name}.png`) });
      if (before) continue;
      await check(name, async () => {
        const audit = await page.evaluate(() => {
          const bounds = el => { const r = el.getBoundingClientRect(); return {left:r.left,top:r.top,right:r.right,bottom:r.bottom,width:r.width,height:r.height}; };
          const ids = ['hud-lives-chip','hud-crystals-chip','hud-record-chip','hud-profile-btn'];
          const cards = ids.map(id => { const el = document.getElementById(id); if (!el) throw Error(`Missing card ${id}`); return {id,...bounds(el)}; });
          const checks = [...document.querySelectorAll('.hud [id], #game-canvas, .touch-pad, #start-text')].filter(el=>{ const r = el.getBoundingClientRect(); return r.width>0 && r.height>0 && getComputedStyle(el).visibility !== 'hidden'; });
          const clipped = checks.filter(el => { const r=el.getBoundingClientRect(); return r.left<-.5 || r.right>innerWidth+.5 || r.top<-.5 || r.bottom>innerHeight+.5; }).map(el=>el.id||el.className);
          const pad = document.querySelector('#touchpad-surface') || document.querySelector('.touch-pad');
          const field = document.getElementById('game-canvas');
          const text = document.getElementById('start-text');
          return { cards, clipped, pad: bounds(pad), field: bounds(field), horizontalOverflow: document.documentElement.scrollWidth > innerWidth+1,
            numbers: ['hud-lives','hud-crystals','hud-record','top-score'].map(id=>{ const el=document.getElementById(id);return {id,text:el.textContent,clipped:el.scrollWidth>el.clientWidth+1}; }),
            emptyImage: [...document.querySelectorAll('#start-banner img')].map(el=>({src:el.src,visible:el.getBoundingClientRect().width>0 && getComputedStyle(el).display!=='none',decoded:el.complete&&el.naturalWidth>0})),
            padVisible:getComputedStyle(pad).visibility!=='hidden'&&getComputedStyle(pad).display!=='none',hint: text.innerText,
            helmet: {status:document.getElementById('helmet-status')?.textContent,classes:document.getElementById('helmet-chip')?.className},
            jump: {status:document.getElementById('jump-status')?.textContent,classes:document.getElementById('jump-chip')?.className,progress:document.getElementById('jump-chip')?.dataset.recharge},
            rings:document.querySelectorAll('.ability-ring .ability-track,.ability-ring .ability-progress').length,
            portrait:document.getElementById('hud-profile-avatar')?.src,
            dayBest:document.getElementById('hud-day-best')?.textContent,
            hintColor:getComputedStyle(text).color,
            jumpTip:(()=>{const el=document.querySelector('#jump-chip .ability-tip');return {exists:!!el,display:el?getComputedStyle(el).display:null,pointerEvents:el?getComputedStyle(el).pointerEvents:null};})(),
            finger: (()=>{const el=document.getElementById('finger-hint');return {exists:!!el,hidden:el?.hasAttribute('hidden'),display:el?getComputedStyle(el).display:null,width:el?.getBoundingClientRect().width,pointerEvents:el?getComputedStyle(el).pointerEvents:null};})() };
        });
        assert.equal(audit.horizontalOverflow,false,'Page overflows horizontally');
        assert.deepEqual(audit.clipped,[],'Visible home elements outside viewport');
        assert.ok(audit.cards.every(card=>Math.abs(card.width-audit.cards[0].width)<1),'Four cards differ in width');
        assert.ok(audit.cards.every(card=>Math.abs(card.top-audit.cards[0].top)<1),'Four cards not in one row');
        assert.deepEqual(audit.numbers.filter(n=>n.clipped),[],'Value clipping');
        assert.ok(audit.padVisible && audit.pad.height >= 35,'Touchpad missing');
        assert.ok(audit.pad.bottom<=height+.5,'Touchpad below viewport');
        assert.ok(Math.abs(audit.field.width-audit.field.height)<1,'Arena not square');
        assert.equal(audit.rings,4,'Both abilities require permanent track+progress rings');
        assert.ok(audit.portrait?.includes('hud-player-portrait-v1.png'),'Canonical portrait missing');
        assert.ok(audit.dayBest !== undefined,'Daily top display missing');
        assert.ok(audit.finger.exists,'Android finger drag cue missing');
        assert.equal(audit.finger.hidden,mode!=='idle','Finger cue visibility must follow idle playable state');
        assert.equal(audit.finger.pointerEvents,'none','Decorative cue intercepts input');
        if(mode==='idle')assert.ok(audit.finger.display!=='none'&&audit.finger.width>20,'Finger cue still has no rendered body');
        if(mode==='active') {
          assert.ok(audit.helmet.classes?.includes('active'),'Active helmet missing');
          assert.ok(audit.jump.classes?.includes('recharging'),'Jump recharge state missing');
          assert.ok(Number(audit.jump.progress)>35&&Number(audit.jump.progress)<75,'Half recharge progress missing');
          assert.ok(audit.jumpTip.exists&&audit.jumpTip.display!=='none','Jump recharge endpoint tip missing');
        }
        if(mode==='broken')assert.ok(audit.helmet.classes?.includes('broken'),'Broken helmet state missing');
        if(['idle','playing','empty'].includes(mode))assert.ok(audit.helmet.status?.includes('Выкл'),'Off helmet status missing');
        if(mode==='idle') {
          const channel=v=>{v/=255;return v<=.04045?v/12.92:((v+.055)/1.055)**2.4;};
          const luminance=rgb=>rgb.map(channel).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0);
          const rgb=audit.hintColor.match(/[\d.]+/g).slice(0,3).map(Number);
          const a=luminance(rgb),b=luminance([22,65,91]);
          assert.ok((Math.max(a,b)+.05)/(Math.min(a,b)+.05)>=4.5,'Idle instruction lacks contrast on navy touchpad');
        }
        if (mode==='empty') assert.ok(audit.emptyImage.some(img=>img.visible&&img.decoded&&img.src.includes('lives-resting-sofa-v2.png')),'Canonical sofa-v2 missing');
        return audit;
      });
    }
  }
  if (!before) {
    for(const lives of [0,999])await check(`fresh-startup/${lives}`,async()=>{
      const q=await newPage(null,{lives});
      try{
        const initial=await q.evaluate(()=>({lives:window.app.economy.lives,empty:document.getElementById('start-banner').classList.contains('out-of-lives'),fingerHidden:document.getElementById('finger-hint').hasAttribute('hidden'),recoveryHidden:document.getElementById('get-lives-btn').hidden}));
        assert.equal(initial.lives,lives);assert.equal(initial.empty,lives===0);assert.equal(initial.fingerHidden,lives===0);assert.equal(initial.recoveryHidden,lives>0);
        await q.emulateMedia({reducedMotion:'reduce'});
        await q.waitForTimeout(50);
        if(lives>0){const reduced=await q.evaluate(()=>{const el=document.getElementById('finger-hint'),s=getComputedStyle(el);return {animation:s.animationName,opacity:s.opacity,width:el.getBoundingClientRect().width};});assert.equal(reduced.animation,'none');assert.ok(Number(reduced.opacity)>.1);assert.ok(reduced.width>20);initial.reducedMotion=reduced;}
        await q.screenshot({path:path.join(output,`fresh-startup-${lives}.png`)});return initial;
      }finally{await q.close();}
    });
    await check('wallet-ui/zero-positive-zero',async()=>{
      await state(page,'empty');
      return page.evaluate(()=>{
        const app=window.app;
        const inspect=()=>({empty:document.getElementById('start-banner').classList.contains('out-of-lives'),fingerHidden:document.getElementById('finger-hint').hasAttribute('hidden'),recoveryHidden:document.getElementById('get-lives-btn').hidden});
        app.economy.lives=1;app._updateHud();const positive=inspect();
        if(positive.empty||positive.fingerHidden||!positive.recoveryHidden)throw Error('After wallet credit recovery scene did not refresh');
        app.economy.lives=0;app._updateHud();const zero=inspect();
        if(!zero.empty||!zero.fingerHidden||zero.recoveryHidden)throw Error('After zero wallet recovery scene did not refresh');
        return {positive,zero};
      });
    });
    await page.setViewportSize({width:390,height:844});
    await check('original-input/first-touch-movement-two-fingers', async () => {
      await state(page,'idle');
      return page.evaluate(() => {
        const app=window.app, target=document.getElementById('touch-zone');
        app._touchZone=null; app.economy.jumpRentalUntil=Date.now()+600000;
        const event={pointerId:1,clientX:150,clientY:350,target,preventDefault(){}};
        const lives=app.economy.lives; app._onPointerDown(event); app.world.enemies=[];
        if(app.phase!=='playing'||app.economy.lives!==lives-1)throw Error('First touch did not start/spend exactly one life');
        const p={...app.world.player}; app._onPointerMove({...event,clientX:155,clientY:343});
        if(Math.abs(app.world.player.dx-p.dx-5)>.01||Math.abs(app.world.player.dy-p.dy+7)>.01)throw Error('Finger movement no longer maps to player movement');
        app._onPointerDown({...event,pointerId:2});
        if(!app.world.isJumping)throw Error('Second finger did not jump');
        app._onPointerUp({...event,pointerId:2});app._onPointerUp(event);
        if(app.pointers.size!==0||app.primaryPointer!==null)throw Error('Pointers not released');
        app._resetToIdle(); return {lifeSpent:1,moved:{dx:5,dy:-7},jump:true};
      });
    });
    await check('empty/one-dialog-no-life-spend',async()=>{
      await state(page,'empty');
      return page.evaluate(()=>{
        const app=window.app,target=document.getElementById('touch-zone');app._touchZone=null;
        let opens=0;const original=app.sheets.open.bind(app.sheets);app.sheets.open=(...args)=>{opens++;return original(...args);};
        const event={pointerId:1,clientX:150,clientY:450,target,preventDefault(){}};
        app._onPointerDown(event);
        if(opens!==1||!app.sheets.isOpen||app.phase!=='idle'||app.economy.lives!==0)throw Error(`Empty touch: opens=${opens},phase=${app.phase}`);
        app.sheets.open=original;app.sheets.close();return {opens,lives:app.economy.lives};
      });
    });
    await check('dom-pointer/start-move-release',async()=>{
      await state(page,'idle');
      const field=await page.locator('#game-canvas').boundingBox();
      const lives=await page.evaluate(()=>window.app.economy.lives);
      const x=field.x+field.width/2,y=field.y+field.height/2;
      await page.mouse.move(x,y);await page.mouse.down();
      const initial=await page.evaluate(()=>{window.app.world.enemies=[];return {...window.app.world.player};});
      await page.mouse.move(x+5,y-7);await page.mouse.up();
      const result=await page.evaluate(()=>({phase:window.app.phase,lives:window.app.economy.lives,player:{...window.app.world.player},pointers:window.app.pointers.size}));
      assert.equal(result.phase,'playing');assert.equal(result.lives,lives-1);assert.equal(result.pointers,0);
      assert.ok(Math.abs(result.player.dx-initial.dx-5)<.1);assert.ok(Math.abs(result.player.dy-initial.dy+7)<.1);
      return result;
    });
    await check('empty/action-click-opens-once',async()=>{
      await state(page,'empty');
      await page.evaluate(()=>{ const app=window.app;window.__sheetOriginal=app.sheets.open.bind(app.sheets);window.__sheetOpens=0;app.sheets.open=(...args)=>{window.__sheetOpens++;return window.__sheetOriginal(...args);}; });
      try {
        await page.locator('#get-lives-btn').click();
        const result=await page.evaluate(()=>({opens:window.__sheetOpens,isOpen:window.app.sheets.isOpen,lives:window.app.economy.lives}));
        assert.equal(result.opens,1,'One recovery click must open one dialog');assert.ok(result.isOpen);assert.equal(result.lives,0);return result;
      } finally {await page.evaluate(()=>{window.app.sheets.open=window.__sheetOriginal;window.app.sheets.close();});}
    });
    await check('header/actions-preserved',async()=>{
      const results=[];
      for(const [selector,type] of [['#hud-lives-chip','lives'],['#hud-crystals-chip','crystals'],['#hud-record-chip','leaderboard'],['#hud-profile-btn','profile']]){
        await state(page,'idle');
        await page.evaluate(()=>{const app=window.app;window.__sheetOriginal=app.sheets.open.bind(app.sheets);window.__sheetTypes=[];app.sheets.open=(type,...args)=>{window.__sheetTypes.push(type);return window.__sheetOriginal(type,...args);};});
        try {await page.locator(selector).click();const types=await page.evaluate(()=>window.__sheetTypes);assert.deepEqual(types,[type]);results.push({selector,type});}
        finally {await page.evaluate(()=>{window.app.sheets.open=window.__sheetOriginal;window.app.sheets.close();});}
      }
      return results;
    });
    for (const sdk of [
      {label:'fallback',fullscreen:false,safe:{},content:{},requestFullscreen:true},
      {label:'fullscreen-no-insets',fullscreen:true,safe:{},content:{}},
      {label:'fullscreen-safe',fullscreen:true,safe:{top:24,bottom:20,left:6,right:6},content:{top:44,left:12,right:12}}
    ]) await check(`telegram-sdk-mock/${sdk.label}`,async()=>{
      const q=await newPage(sdk);
      try {
        await state(q,'idle');
        const audit=await q.evaluate(()=>{
          const tg=window.Telegram.WebApp;
          const r=document.querySelector('.hud').getBoundingClientRect();
          return {hud:{left:r.left,top:r.top,right:r.right},topPad:parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--tg-pad-top')),safe:tg.safeAreaInset,content:tg.contentSafeAreaInset};
        });
        assert.ok(audit.hud.top>=audit.topPad-.5,'HUD overlaps Telegram controls');
        assert.ok(audit.hud.left>=((sdk.safe.left||0)+(sdk.content.left||0))-.5,'HUD overlaps left safe area');
        assert.ok(audit.hud.right<=390-((sdk.safe.right||0)+(sdk.content.right||0))+.5,'HUD overlaps right safe area');
        await q.screenshot({path:path.join(output,`sdk-${sdk.label}.png`)});return audit;
      } finally {await q.close();}
    });
  }
  await check('no-js-errors',()=>assert.deepEqual(errors,[]));
  await check('no-missing-assets',()=>assert.deepEqual(missing,[]));
  await fs.writeFile(path.join(output,'verification.json'),JSON.stringify({date:new Date().toISOString(),kind:'Local Chromium mock; not real Telegram/device',before,cases,failures,errors,missing,blockedExternal:external,fixtureApi:apis},null,2));
  console.log(JSON.stringify({pass:cases.filter(c=>c.status==='PASS').length,failed:failures.length,failures:failures.slice(0,12),screenshots:120,output},null,2));
  if(failures.length)process.exitCode=1;
} finally {await browser.close();await new Promise(resolve=>server.close(resolve));}
