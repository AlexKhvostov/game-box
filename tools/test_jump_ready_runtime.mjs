// Local Canvas/controller acceptance with real compiled physics; no account/API.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const modules=process.env.UNTOUCH_BROWSER_MODULES ?? path.join(process.env.USERPROFILE,'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules');
const {chromium}=await import(pathToFileURL(path.join(modules,'playwright/index.mjs')));
const origin=process.env.JUMP_QA_ORIGIN ?? 'http://127.0.0.1:5177';
assert.match(origin,/^http:\/\/127\.0\.0\.1:\d+$/);
const kitRoot=process.env.JUMP_UIKIT_ROOT ?? 'D:/_P_R_O_J_E_C_T/game/square/Untouch/docs/design/simple-energy-bonus-20261016/live-kit';
const data=source=>'data:text/javascript;base64,'+Buffer.from(source).toString('base64');
const glow=data(await fs.readFile(path.join(kitRoot,'jump-glow-artwork.js'),'utf8'));
const state=data(await fs.readFile(path.join(kitRoot,'jump-ready-state.js'),'utf8'));
const expected=data((await fs.readFile(path.join(kitRoot,'jump-ready-drawer.js'),'utf8')).replace('./jump-glow-artwork.js',glow).replace('./jump-ready-state.js',state));
const out=path.resolve('docs/release-evidence/jump-ready-runtime-20261024');await fs.mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true});const errors=[],checks=[];
try {
 const page=await browser.newPage({viewport:{width:430,height:820},deviceScaleFactor:2});
 page.on('pageerror',e=>errors.push(e.message));
 // Existing DEV fixture supplies a visible canvas and loads the real kernel.
 await page.goto(origin+'/qa/helmet.html');await page.locator('output[data-phase="ready"]').waitFor();
 const comparisons=await page.evaluate(async expected=>{
  const actual=(await import('/src/game/jump-ready-drawer.ts')).createJumpReadyDrawer();
  const reference=(await import(expected)).createJumpReadyDrawer();
  const result=[];
  for(const ready of [false,true])for(const age of [null,0,105,210,420,20000])for(const reduced of [false,true]){
   const pixels=draw=>{const cv=document.createElement('canvas');cv.width=cv.height=256;const c=cv.getContext('2d');draw(c,{x:0,y:0,size:256,enabled:true,progress:ready?1:.66,ready,readyAgeMs:age,reduced});return c.getImageData(0,0,256,256).data;};
   const a=pixels(actual),b=pixels(reference);let differences=0;for(let i=0;i<a.length;i++)if(a[i]!==b[i])differences++;
   result.push({ready,age,reduced,differences});
  }return result;
 },expected);
 for(const c of comparisons)assert.equal(c.differences,0,JSON.stringify(c));checks.push({pixelParityWithApprovedB:comparisons.length});
 const controller=await page.evaluate(async()=>{
  const {state}=await import('/src/services/game-store.ts');
  const {GameController}=await import('/src/game/controller.ts');
  const {kernel}=await import('/src/domain/kernel.ts');
  const bundled=(await import('/src/generated/android-config.json')).default;
  const config=structuredClone(bundled.config);Object.assign(config.game,{startInvulnSec:60,jumpCooldownSec:2});
  config.enemyPace={initialSpeed:0,growthMultiplier:0,brakeEnabled:false,speedBarEnabled:false};
  state.config={...bundled,config};state.jump=true;state.helmet=true;
  const controller=new GameController(document.querySelector('canvas'),document.createElement('div'));
  cancelAnimationFrame(controller.raf);controller.stopped=true;
  controller.snapshot=kernel({op:'start'});controller.draw();
  const initial=controller.jumpReady.ageMs;
  controller.jump();const used=controller.jumpReady.ageMs,count=controller.snapshot.jumpCount;
  for(let i=0;i<39;i++)controller.advance(50);
  const before={ready:controller.jumpReady.ready,age:controller.jumpReady.ageMs};
  controller.advance(50);const boundary=controller.jumpReady.ageMs;
  for(const ms of [50,50,50,50,10])controller.advance(ms);controller.draw();const peak=controller.jumpReady.ageMs;
  const previousScreen=state.screen;state.screen='energy';controller.stopped=false;controller.tick(100000);
  cancelAnimationFrame(controller.raf);controller.stopped=true;state.screen=previousScreen;
  const paused=controller.jumpReady.ageMs;
  for(const ms of [50,50,50,50,10,...Array(60).fill(50)])controller.advance(ms);const settled=controller.jumpReady.ageMs;
  controller.jump();const repeated={age:controller.jumpReady.ageMs,count:controller.snapshot.jumpCount};
  controller.reset();const reset=controller.jumpReady.ageMs;
  globalThis.jumpRuntimeQA={controller,config,state,kernel};
  return {initial,used,count,before,boundary,peak,paused,settled,repeated,reset};
 });
 assert.equal(controller.initial,null);assert.equal(controller.used,null);assert.equal(controller.count,1);
 assert.deepEqual(controller.before,{ready:false,age:null});assert.equal(controller.boundary,0);
 assert.equal(controller.peak,210);assert.equal(controller.paused,210);assert.ok(controller.settled>=420);
 assert.deepEqual(controller.repeated,{age:null,count:2});assert.equal(controller.reset,null);checks.push({actualController:controller});
 // Freeze chosen real-painter states for visual inspection, with external helmet.
 for(const mode of ['ready','flash','charging','reduced','helmet-charging']){
  await page.emulateMedia({reducedMotion:mode==='reduced'?'reduce':'no-preference'});
  await page.evaluate(mode=>{
   const q=globalThis.jumpRuntimeQA,c=q.controller;
   c.reset();c.snapshot=q.kernel({op:'start'});
   if(mode==='charging'){c.jump();for(let i=0;i<20;i++)c.advance(50);}
   if(mode==='helmet-charging')c.snapshot={...c.snapshot,helmet:false,helmetCharge:{equipped:true,cooldownMs:30000,remainingMs:15000,progress:.5,readyAgeMs:null,breaks:1}};
   c.painter.draw(c.snapshot,q.config,0,[],mode==='flash'||mode==='reduced'?210:null);
  },mode);
  await page.locator('canvas').screenshot({path:path.join(out,`telegram-${mode}.png`)});
 }
 assert.deepEqual(errors,[]);
 const report={ok:true,mode:'headless Chromium; local DEV fixture, actual controller/compiled kernel/Canvas; no real Telegram host',checks,errors};
 await fs.writeFile(path.join(out,'browser-checks.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({ok:true,comparisons:comparisons.length,controller:true,errors}));
}finally{await browser.close();}
