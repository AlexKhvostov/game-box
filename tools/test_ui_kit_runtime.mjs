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
 const page=await browser.newPage({viewport:{width:390,height:560},hasTouch:true});
 const errors=[],missing=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('response',r=>{if(r.status()===404)missing.push(r.url());});
 await page.route(/https:\/\//,route=>route.fulfill({body:'',contentType:'text/javascript'}));
 await page.goto(`http://127.0.0.1:${server.address().port}`);
 await page.locator('#boot-loader').waitFor({state:'hidden'});
 await page.evaluate(async()=>{
  const {FieldRenderer}=await import('/js/renderer.js'); const world=window.app.world;
  const snapshot=()=>JSON.stringify({player:world.player, size:world.playerSize,
    enemies:world.enemies.map(e=>({center:e.center,w:e.w,h:e.h,orient:e.orientDeg}))});
  const before=snapshot(),canvas=document.createElement('canvas');canvas.width=380;canvas.height=380;
  const renderer=new FieldRenderer({});
  for(const [preview,helmet] of [[true,false],[false,false],[false,true]])renderer.paint(canvas.getContext('2d'),world,
   {fieldColor:'#202b30',accent:'#3ddc97',danger:'#e45262',borderColor:'#3ddc97',fieldSize:{width:380,height:380},playerPreview:preview,hasHelmet:helmet,showFace:true});
  if(before!==snapshot())throw Error('Renderer mutated live geometry');
 });
 for(const width of [320,360,390,430]) {
  await page.setViewportSize({width,height:560});
  for(const [type,tab] of [['crystals',0],['crystals',1],['crystals',2],['crystals',3],['lives',0],['profile',0],['plus',0],['leaderboard',0]]) {
   await page.evaluate(({type,tab})=>window.app.sheets.open(type,{tab}),{type,tab});
   await page.waitForTimeout(350);
   const overflow=await page.evaluate(()=>[...document.querySelectorAll('.sheet-panel button,.sheet-panel input,.sheet-panel .ui-art')].filter(el=>{
    const r=el.getBoundingClientRect();return r.width&&r.height&&(r.left<-.5||r.right>innerWidth+.5);
   }).map(el=>({tag:el.tagName,cls:el.className})));
   assert.deepEqual(overflow,[],`${type}/${tab} at ${width}`);
   assert.equal(await page.locator('[data-store],[data-field-scene],.store-demo-controls').count(),0);
   if(type==='crystals') {
     assert.equal(await page.locator('#watch-ad-btn').count(),1);
     const balance=await page.evaluate(()=>window.app.economy.tokens);
     assert.equal((await page.locator('#sheet-crystal-balance').innerText()).trim(),String(balance));
   }
   if(type==='crystals'&&tab===2)assert.ok((await page.locator('.rent-icon-box .ui-art').first().getAttribute('src')).includes('helmet-v1.png'));
   if(type==='plus') {
     await page.locator('#plus-subscribe').scrollIntoViewIfNeeded();
     const box=await page.locator('#plus-subscribe').boundingBox();assert.ok(box.y+box.height<=560);
   }
   if(width===390||width===320)await page.screenshot({path:`docs/release-evidence/ui-runtime-${type}-${tab}-${width}.png`});
  }
 }
 assert.deepEqual(errors,[]);assert.deepEqual(missing.filter(url=>!url.includes('/assets/sfx/') || process.env.UNTOUCH_WEB_ROOT),[]);
 console.log('PASS: 32 live-data windows at 320/360/390/430 x 560; no horizontal overflow, missing assets, JS errors or gallery handlers. No payments or player mutations.');
} finally {await browser.close();await new Promise(r=>server.close(r));}
