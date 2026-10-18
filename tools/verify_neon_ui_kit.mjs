// Offline gallery verification. No game service or external site is contacted.
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const {chromium} = await import(pathToFileURL('C:/Users/alexe/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs'));
const root = path.resolve(process.argv[2] || 'docs/design/neon-ui-kit-20261015');
const catalog = JSON.parse(fs.readFileSync(path.join(root,'catalog.json'),'utf8').replace(/^\uFEFF/,''));
const browser = await chromium.launch({headless:true,channel:'chrome'});
const page = await browser.newPage({viewport:{width:1440,height:1100},deviceScaleFactor:1});
const errors=[];
page.on('pageerror',error=>errors.push(String(error)));
await page.route('**/*',route=>route.request().url().startsWith('file:')||route.request().url().startsWith('data:') ? route.continue() : route.abort());
try {
  await page.goto(pathToFileURL(path.join(root,'gallery.html')).href);
  const count = await page.locator('.card').count();
  if(count!==catalog.screens.length) throw new Error('Gallery count mismatch');
  await page.locator('img').evaluateAll(images=>images.forEach(image=>image.loading='eager'));
  await page.locator('.preview img').evaluateAll(images=>Promise.all(images.map(image=>image.decode())));
  await page.screenshot({path:path.join(root,'gallery-desktop.png')});
  await page.locator('#group').selectOption('energy');
  const expected=catalog.screens.filter(row=>row.group==='energy').length;
  if(await page.locator('.card:visible').count()!==expected) throw new Error('Group filter failed');
  await page.locator('#search').fill('5 аккумуляторов');
  if(await page.locator('.card:visible').count()<1) throw new Error('Five-battery search failed');
  await page.locator('.card:visible .preview').first().click();
  await page.locator('#full').evaluate(image=>image.decode());
  if(!(await page.locator('#viewer').isVisible())) throw new Error('Viewer failed');
  await page.screenshot({path:path.join(root,'gallery-five-batteries.png')});
  await page.keyboard.press('ArrowRight');
  await page.keyboard.press('Escape');
  if(await page.locator('#viewer').isVisible()) throw new Error('Viewer did not close');
  await page.locator('#search').fill('');
  await page.locator('#group').selectOption('');
  for(const width of [1440,768,390]) {
    await page.setViewportSize({width,height:1000});
    const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
    if(overflow) throw new Error('Horizontal overflow at '+width);
  }
  await page.screenshot({path:path.join(root,'gallery-mobile.png')});
  if(errors.length) throw new Error(errors.join('\n'));
  fs.writeFileSync(path.join(root,'gallery-verification.json'),JSON.stringify({ok:true,screens:count,allImagesDecoded:true,filter:true,search:true,viewer:true,keyboard:true,widths:[1440,768,390],consoleErrors:errors},null,2));
  process.stdout.write(JSON.stringify({ok:true,screens:count,errors}));
} finally {await browser.close();}
