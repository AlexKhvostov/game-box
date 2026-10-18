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
  const page = await browser.newPage({viewport:{width:390,height:844},hasTouch:true});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route(/https:\/\//,route=>route.fulfill({body:'',contentType:'text/javascript'}));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.locator('#boot-loader').waitFor({state:'hidden'});
  await page.evaluate(()=>{
    const original=Date.now;let now=original();Date.now=()=>now;
    try {
      const cfg=structuredClone(window.app.config);
      Object.assign(cfg.economy,{interstitialSessionGraceSec:180,interstitialSessionFreeRounds:10,interstitialGraceSec:0,adsgramInterstitialBlockId:'int-123'});
      const make=()=>{const s=new window.app.economy.constructor(cfg);s.lives=30;s.hasPremium=false;s.interstitialArmedAtMs=1;s.lastInterstitialMs=0;return s;};
      const store=make();
      for(let i=0;i<10;i++)store.recordAttempt(1000);
      now+=180000;
      if(store.canShowResultInterstitial())throw Error('The tenth loss must remain ad-free');
      store.recordAttempt(1000);
      if(!store.canShowResultInterstitial())throw Error('Eleventh loss after three minutes should unlock');
      store.markInterstitialShown();if(store.canShowResultInterstitial())throw Error('Cooldown lost');
      now+=store.interstitialCooldownMs;if(!store.canShowResultInterstitial())throw Error('Cooldown boundary');
      const reopened=make();for(let i=0;i<11;i++)reopened.recordAttempt(1000);
      now+=179999;if(reopened.canShowResultInterstitial())throw Error('New launch grace lost');
      now++;if(!reopened.canShowResultInterstitial())throw Error('Exact launch grace boundary');
    }finally{Date.now=original;}
  });
  for(const [width,height] of [[320,560],[390,844],[430,932]]) {
    await page.setViewportSize({width,height});
    for(const light of [false,true]) {
      await page.evaluate(async light=>{
        document.documentElement.toggleAttribute('data-theme',light);
        if(light)document.documentElement.setAttribute('data-theme','light');
        const version=new URL(document.querySelector('link[href*="app.css"]').href).search;
        const {telegram}=await import('/js/telegram.js'+version);
        telegram._tg={safeAreaInset:{top:24,bottom:24},contentSafeAreaInset:{top:70}};
        window.app._resize();window.app._updateHud();
        const rect=selector=>document.querySelector(selector).getBoundingClientRect();
        const life=rect('#hud-lives-chip'),crystal=rect('#hud-crystals-chip'),account=rect('#hud-profile-btn'),record=rect('#hud-record-chip'),timer=rect('#score-strip'),boost=rect('.hud-boosts'),field=rect('.field-wrap');
        if(life.bottom>crystal.top||account.bottom>record.top||timer.bottom>boost.top)throw Error('Header rows overlap');
        if(crystal.right>=timer.left||timer.right>=account.left)throw Error('Header columns overlap');
        if(life.top<94||timer.top<94||account.top<94)throw Error('Header overlaps Telegram native buttons');
        if(field.top<Math.max(crystal.bottom,boost.bottom,record.bottom))throw Error('Field overlaps header');
        if(document.documentElement.scrollWidth>innerWidth)throw Error('Horizontal overflow');
      },light);
      await page.screenshot({path:path.join(root,'../docs/release-evidence',`session-header-${width}-${light?'light':'dark'}.png`)});
    }
  }
  assert.deepEqual(errors,[]);
  console.log('PASS: Telegram session time/ten free rounds/relaunch/cooldown; three-column header 320/390/430, both themes, Telegram native safe area. Ads mocked.');
}finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
