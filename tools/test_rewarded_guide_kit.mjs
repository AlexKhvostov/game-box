// Isolated browser test; all ad activity is the UIKit's local demonstration.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import {pathToFileURL} from 'node:url';
const {chromium}=await import(pathToFileURL('C:/Users/alexe/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs'));
const root=path.resolve('docs/design/simple-energy-bonus-20261016/live-kit');
const out=path.resolve('docs/release-evidence/rewarded-guide-20261019');await fs.mkdir(out,{recursive:true});
const server=http.createServer(async(req,res)=>{
  try{
    const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    const file=path.resolve(root,'.'+(name==='/'?'/index.html':name));
    if(!file.startsWith(root+path.sep))throw Error('path');
    res.setHeader('Content-Type',({'.js':'text/javascript','.css':'text/css','.png':'image/png','.svg':'image/svg+xml','.html':'text/html'})[path.extname(file)]||'application/octet-stream');
    res.end(await fs.readFile(file));
  }catch{res.writeHead(404);res.end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const browser=await chromium.launch({headless:true,channel:'chrome'});
const page=await browser.newPage({viewport:{width:1100,height:1000}});const errors=[],missing=[],checks=[];
page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()===404&&!r.url().endsWith('favicon.ico'))missing.push(r.url());});
await page.route('**/*',r=>r.request().url().startsWith(`http://127.0.0.1:${server.address().port}`)?r.continue():r.abort());
try{
  await page.goto(`http://127.0.0.1:${server.address().port}/#references`);
  const ref=page.locator('a[href="#rewarded-guide"]');await ref.click();
  const sheet=page.locator('.rewarded-guide-showcase .video-sheet');await sheet.waitFor();
  assert.equal(await sheet.locator('.rg-step').count(),2);assert.equal(await sheet.locator('img').count(),0);checks.push('Reference links to live E03; two schematic steps');
  for(const width of [1100,390,320]){
    await page.setViewportSize({width,height:900});
    const layout=await sheet.evaluate(el=>({w:el.clientWidth,scroll:el.scrollWidth,h:el.getBoundingClientRect().height}));
    assert.ok(layout.scroll<=layout.w+1,JSON.stringify(layout));assert.ok(layout.h<700);
    await sheet.screenshot({path:path.join(out,`uikit-${width}.png`)});checks.push(`width${width}: no horizontal overflow`);
  }
  await sheet.locator('summary').click();assert.match(await sheet.locator('details[open]').innerText(),/Без персонализации и геолокации/);await sheet.locator('summary').click();checks.push('data details open without starting an ad');
  await sheet.locator('.rg-launch').click();await page.locator('#overlay-root .system-sheet').waitFor();
  assert.equal(Number(await page.locator('#lab-balance').inputValue()),50);checks.push('launch enters local ad; no immediate reward');
  await page.waitForTimeout(6800);assert.equal(Number(await page.locator('#lab-balance').inputValue()),90);checks.push('demo completion credits 40 once');
  await page.keyboard.press('Escape');await page.goto(`http://127.0.0.1:${server.address().port}/#library`);
  await page.locator('[data-action="reset"]').click();
  await page.locator('[data-action="open-energy"]').first().click();
  await page.locator('#overlay-root [data-action="open-video"]').click();
  await page.locator('#overlay-root .rg-step').first().waitFor();
  assert.equal(await page.locator('#overlay-root .system-sheet').count(),0);checks.push('energy entry opens guide before any demo ad');
  assert.deepEqual(errors,[]);assert.deepEqual(missing,[]);
  await fs.writeFile(path.join(out,'uikit-verification.json'),JSON.stringify({ok:true,checks,errors,missing,externalNetwork:false},null,2));
  console.log(JSON.stringify({ok:true,checks:checks.length,errors:errors.length}));
}finally{await browser.close();await new Promise(r=>server.close(r));}
