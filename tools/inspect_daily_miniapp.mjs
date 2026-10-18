// Render the actual Mini App with local fixture data, no live account or calls.
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
const root = path.resolve(import.meta.dirname, '../telegram-web');
const out = path.resolve(import.meta.dirname, '../docs/release-evidence/daily-bonus-states-20261012/telegram');
const { chromium } = await import(pathToFileURL(path.join(process.env.UNTOUCH_BROWSER_MODULES, 'playwright/index.mjs')));
const config = JSON.parse(await fs.readFile(path.join(root, 'config/gameplay-config.json'), 'utf8'));
const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    res.setHeader('Content-Type', 'application/json');
    if (url.pathname === '/api/config.php') return res.end(JSON.stringify({ ok: true, config, revision: 'fixture' }));
    if (url.pathname.startsWith('/api/')) return res.end(JSON.stringify({ scores: [] }));
    const relative = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
    const file = path.resolve(root, relative);
    if (!file.startsWith(root+path.sep)) {res.writeHead(403);res.end();return;}
    let data = await fs.readFile(file);
    res.setHeader('Content-Type', {'.js':'text/javascript','.css':'text/css','.html':'text/html',
      '.json':'application/json','.svg':'image/svg+xml','.png':'image/png'}[path.extname(file)] || 'application/octet-stream');
    if (relative === 'js/main.js') data = Buffer.concat([data,Buffer.from('\nexport { app, UntouchApp };\n')]);
    res.end(data);
  } catch {res.writeHead(404);res.end();}
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  await fs.mkdir(out,{recursive:true});
  browser = await chromium.launch({headless:true});
  const page = await browser.newPage({viewport:{width:390,height:844},timezoneId:'Europe/Minsk'});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route(/https:\/\//,route=>route.fulfill({body:'',contentType:'text/javascript'}));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.locator('#boot-loader').waitFor({state:'hidden'});
  const results=[];
  for (const state of ['ready','claimed','premium']) {
    await page.evaluate(state => {
      const e=window.app.economy;
      e.dailyStreak = state === 'ready' ? 0 : 3;
      e.lastDailyClaimMs = state === 'ready' ? 0 : Date.now();
      e.hasPremium = state === 'premium';
      e.plusUntilMs = state === 'premium' ? Date.now()+86400000*7 : 0;
      window.app.sheets.open('crystals',{tab:0});
    }, state);
    await page.waitForTimeout(300);
    const data = await page.locator('.daily-card').evaluateAll(cards=>cards.map(c=>({
      classes:c.className,text:c.innerText,
      reward:c.querySelector('.daily-card-mid')?.getBoundingClientRect().toJSON(),
    })));
    await page.screenshot({path:path.join(out,state+'.png')});
    results.push({state,rows:data});
  }
  assert.deepEqual(errors,[]);
  await fs.writeFile(path.join(out,'reference.json'),JSON.stringify({results,errors},null,2));
  console.log('Actual local Mini App rendered: ready, claimed, premium. No live requests or rewards.');
} finally {
  await browser?.close();await new Promise(resolve=>server.close(resolve));
}
