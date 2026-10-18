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
    const a=await fs.readFile(path.join(old,dir,name),'utf8'),b=await fs.readFile(path.join(root,dir,name),'utf8');
    assert.equal(clean(b).replace(/^\uFEFF/,''),clean(a).replace(/^\uFEFF/,''),`Different original file: ${dir}/${name}`);
  }
  assert.deepEqual(errors,[]);
  console.log('PASS: original 1.0.22 frontend/admin files match after version normalization; lives/crystals, original start and movement, shop/rentals/profile/ranking windows; no energy/product UI or browser errors. Browser emulation only.');
} finally {await browser.close();await new Promise(resolve=>server.close(resolve));}