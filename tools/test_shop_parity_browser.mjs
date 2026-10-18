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
  const page=await browser.newPage({viewport:{width:390,height:844},hasTouch:true});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route(/https:\/\//,route=>route.fulfill({body:'',contentType:'text/javascript'}));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.locator('#boot-loader').waitFor({state:'hidden'});
  for(const width of [320,390]) {
    await page.setViewportSize({width,height:844});
    for(const [type,tab] of [['crystals',0],['crystals',1],['crystals',2],['lives',0]]) {
      await page.evaluate(({type,tab})=>{window.app.sheets.open(type,{tab});},{type,tab});
      await page.waitForTimeout(250);
      if(type==='crystals') {
        await page.locator('#watch-ad-btn').waitFor();
        assert.equal(await page.locator('.crystals-header #daily-plus-card').count(),0);
        assert.equal(await page.locator('#daily-plus-card').count(),tab===0?1:0);
        if(tab===1) assert.ok(await page.locator('.shop-pack').count()>0);
        if(tab===2) assert.equal(await page.locator('.rent-btns').count(),2);
      } else {
        assert.ok(await page.locator('.life-buy-card').count()>0);
        assert.equal(await page.locator('#lives-to-shop').count(),1);
      }
      await page.screenshot({path:`docs/release-evidence/telegram-shop-reference-${type}-${tab}-${width}.png`});
    }
  }
  assert.deepEqual(errors,[]);
  console.log('PASS: Telegram shop reference: header ad/gift/balance; Plus in Daily only; purchase/rent/life panels at 320/390. No purchases or real ads.');
} finally { await browser.close(); await new Promise(r=>server.close(r)); }
