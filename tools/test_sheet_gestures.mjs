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
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route(/https:\/\//,route=>route.fulfill({body:'',contentType:'text/javascript'}));
 await page.goto(`http://127.0.0.1:${server.address().port}`);
 await page.locator('#boot-loader').waitFor({state:'hidden'});
 const cdp=await page.context().newCDPSession(page);
 async function swipe(x,y,delta) {
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
   for(let n=1;n<=6;n++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y+delta*n/6}]});
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   await page.waitForTimeout(300);
 }
 let count=0;
 for(const [width,height] of [[320,460],[390,560],[430,900],[844,390]]) {
  await page.setViewportSize({width,height});
  await page.evaluate(async()=>{
   const version=new URL(document.querySelector('link[href*="app.css"]').href).search;
   const {telegram}=await import('/js/telegram.js'+version);
   telegram._tg={safeAreaInset:{top:24,bottom:24},contentSafeAreaInset:{top:88}};
   window.app._resize();
  });
  for(const type of ['crystals','leaderboard','lives','profile','share','plus']) {
   await page.evaluate(type=>window.app.sheets.open(type),type);
   await page.waitForTimeout(300);
   const box=await page.locator('#sheet-panel').boundingBox();
   assert.ok(box.y>=127.5,`${type} overlaps Telegram controls at ${width}/${height}: ${box.y}`);
   assert.ok(box.height<=height*.82+1,`${type} fills screen`);
   assert.equal(await page.locator('.sheet-panel').evaluate(el=>el.scrollWidth>el.clientWidth+1),false);
   if(width===390&&['crystals','leaderboard'].includes(type))await page.screenshot({path:`docs/release-evidence/sheet-safe-${type}.png`});
   const grip=await page.locator('.sheet-handle').boundingBox();
   await swipe(width/2,grip.y+12,100);
   if(type==='plus') {
    assert.equal(await page.evaluate(()=>window.app.sheets._type),'crystals');
    const next=await page.locator('.sheet-handle').boundingBox();await swipe(width/2,next.y+12,100);
   }
   assert.equal(await page.evaluate(()=>window.app.sheets.isOpen),false,`${type} touch swipe fails`);
   count++;
  }
 }
 await page.setViewportSize({width:390,height:560});
 await page.evaluate(()=>window.app.sheets.open('crystals'));
 await page.waitForTimeout(300);
 const grip=await page.locator('.sheet-handle').boundingBox();
 await swipe(195,grip.y+12,15);assert.equal(await page.evaluate(()=>window.app.sheets.isOpen),true,'short swipe closed sheet');
 await page.locator('.daily-bonus-scroll').evaluate(el=>el.scrollTop=60);
 const scroll=await page.locator('.daily-bonus-scroll').boundingBox();
 await swipe(200,scroll.y+40,90);
 assert.equal(await page.evaluate(()=>window.app.sheets.isOpen),true,'scrolled list dismissed instead of scrolling');
 await page.mouse.move(195,grip.y+12);await page.mouse.down();await page.mouse.move(195,grip.y+110,{steps:6});await page.mouse.up();await page.waitForTimeout(300);
 assert.equal(await page.evaluate(()=>window.app.sheets.isOpen),false,'mouse drag fails');
 assert.deepEqual(errors,[]);
 console.log(`PASS: ${count} sheets respect Telegram top safe area and 82% cap; real touch dismiss, Plus back, short swipe, list scrolling and mouse drag.`);
} finally {await browser.close();await new Promise(r=>server.close(r));}
