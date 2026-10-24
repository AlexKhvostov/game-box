import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
const modules=process.env.UNTOUCH_BROWSER_MODULES??path.join(process.env.USERPROFILE,'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules');
const {chromium}=await import(pathToFileURL(path.join(modules,'playwright/index.mjs')));
const root=path.resolve(import.meta.dirname,'../../..'),out=path.join(import.meta.dirname,'qa'),frames=path.join(root,'.private/jump-ready-20261024/frames');
await fs.mkdir(out,{recursive:true});await fs.mkdir(frames,{recursive:true});
const browser=await chromium.launch({headless:true});const checks=[],errors=[],failed=[];
try{
 const page=await browser.newPage({viewport:{width:1320,height:1100},deviceScaleFactor:1});
 page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()>=400)failed.push(r.url());});
 await page.goto('http://127.0.0.1:8919/docs/design/jump-ready-20261024/');await page.waitForFunction(()=>!!window.jumpReadySketch);
 assert.equal(await page.evaluate(()=>jumpReadySketch.state.signals),0);checks.push('Открытие готового эскиза не вызывает лишнюю вспышку');
 await page.evaluate(()=>{const d=jumpReadySketch;d.setProgress(.9999);d.render();});
 assert.equal(await page.locator('#status').textContent(),'Зарядка · 99%');assert.equal(await page.evaluate(()=>jumpReadySketch.state.signals),0);checks.push('99,99% не выдаются за готовность');
 await page.evaluate(()=>{const d=jumpReadySketch;d.setProgress(1);d.state.frozen=true;d.render();});
 assert.equal(await page.locator('#status').textContent(),'Готов · 100%');assert.equal(await page.evaluate(()=>jumpReadySketch.state.signals),1);checks.push('Точный переход100% даёт один сигнал');
 await page.evaluate(()=>{const d=jumpReadySketch;d.state.paused=false;d.advance(20);d.setProgress(1);d.render();});
 assert.equal(await page.evaluate(()=>jumpReadySketch.state.signals),1);assert.equal(await page.evaluate(()=>jumpReadySketch.signalStrength(jumpReadySketch.state.readyAge)),0);checks.push('Готовность сохраняется20с без повторных сигналов');
 await page.locator('#jump').click();await page.waitForTimeout(110);assert.ok((await page.evaluate(()=>jumpReadySketch.state.progress))<.2);checks.push('Прыжок сбрасывает свет и начинает новый цикл');
 await page.locator('#pause').click();const p=await page.evaluate(()=>jumpReadySketch.state.progress);await page.waitForTimeout(130);assert.equal(await page.evaluate(()=>jumpReadySketch.state.progress),p);checks.push('Пауза не продвигает заряд');
 await page.locator('#last').click();await page.waitForFunction(()=>jumpReadySketch.state.progress===1);await page.waitForTimeout(520);
 assert.equal(await page.evaluate(()=>jumpReadySketch.signalStrength(jumpReadySketch.state.readyAge)),0);checks.push('Живой цикл0,5с заканчивается одной вспышкой0,42с');
 // Pixel checks target the actual44px hero: centre/helmet are stable, side light changes.
 const pixels=async(p,age,reduced=false)=>page.evaluate(({p,age,reduced})=>{
  const d=jumpReadySketch;d.state.reduced=reduced;d.setFrame(p,age);return [...document.querySelectorAll('.live')].map(cv=>{
   const c=cv.getContext('2d'),sample=(x,y,w,h)=>[...c.getImageData(x*2,y*2,w*2,h*2).data];
   return {centre:sample(47,87,3,10),helmet:sample(20,88,3,10),side:sample(26,78,6,23),all:sample(0,0,Math.floor(cv.clientWidth),172)};
  });
 },{p,age,reduced});
 const before=await pixels(.9,-1),flash=await pixels(1,.21),ready=await pixels(1,1);
 for(let i=0;i<3;i++){assert.deepEqual(before[i].centre,flash[i].centre);assert.deepEqual(before[i].helmet,flash[i].helmet);assert.notDeepEqual(before[i].side,ready[i].side);assert.notDeepEqual(flash[i].side,ready[i].side);}checks.push('Сигнал меняет боковой свет всех3вариантов; лицо и голубой шлем сохраняются');
 const reducedA=await pixels(1,.21,true),reducedB=await pixels(1,1,true);assert.deepEqual(reducedA,reducedB);checks.push('Уменьшение движения исключает и вспышку, и бегущий блик');
 await page.emulateMedia({reducedMotion:'reduce'});await page.reload();await page.waitForFunction(()=>!!window.jumpReadySketch);assert.equal(await page.locator('#reduced').isChecked(),true);checks.push('Системная настройка reducedmotion подхватывается при открытии');
 await page.emulateMedia({reducedMotion:'no-preference'});await page.reload();await page.waitForFunction(()=>!!window.jumpReadySketch);
 await page.locator('#helmet').uncheck();assert.equal(await page.evaluate(()=>jumpReadySketch.state.helmet),false);await page.locator('#helmet').check();checks.push('Варианты проверяются со шлемом и без него');
 for(const width of [320,360,430,1320]){
  await page.setViewportSize({width,height:1100});await page.evaluate(()=>jumpReadySketch.setFrame(1,1));
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
  assert.ok(await page.locator('.live').first().evaluate(cv=>Math.abs(cv.width/cv.clientWidth-2)<.01));
  checks.push(`Ширина${width}: без переполнения, малый герой44CSSpx`);
  if(width===360)await page.screenshot({path:path.join(out,'mobile-360.png'),fullPage:true});
 }
 await page.locator('.demo').screenshot({path:path.join(out,'overview.png')});
 await page.evaluate(()=>jumpReadySketch.setFrame(.9,-1));await page.locator('.demo').screenshot({path:path.join(out,'charging.png')});
 await page.evaluate(()=>jumpReadySketch.setFrame(1,.21));await page.locator('.demo').screenshot({path:path.join(out,'flash.png')});
 // Last0.5s of charge and1.6s of readiness,20frames/s. No perpetual pulse.
 for(let i=0;i<43;i++){const t=i/20-.5;await page.evaluate(t=>jumpReadySketch.setFrame(t<0?1+t/2:1,t<0?-1:t),t);await page.locator('#motion-board').screenshot({path:path.join(frames,`${String(i).padStart(3,'0')}.png`)});}
 assert.deepEqual(errors,[]);assert.deepEqual(failed,[]);
 const manifest=JSON.parse(await fs.readFile(path.join(import.meta.dirname,'source-manifest.json'),'utf8'));
 for(const p of ['lib/features/game/jump_glow.dart','telegram-app/src/game/jump-glow.ts'])assert.equal(crypto.createHash('sha256').update(await fs.readFile(path.join(root,p))).digest('hex'),manifest.files[p]);
 checks.push('Действующие исходники полосок Android/Telegram не изменены');
 await fs.writeFile(path.join(out,'checks.json'),JSON.stringify({ok:true,kind:'isolated-design-sketch-not-game-runtime',checks,errors,failed,frames:43},null,2)+'\n');
 console.log(JSON.stringify({ok:true,checks:checks.length,errors:errors.length,frames:43}));
}finally{await browser.close();}
