import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const {chromium}=await import(pathToFileURL(path.join(process.env.UNTOUCH_BROWSER_MODULES,'playwright/index.mjs')));
const evidence=path.resolve('docs/release-evidence/telegram-brake-20261023');await fs.mkdir(evidence,{recursive:true});
const browser=await chromium.launch({headless:true}),checks=[],errors=[];
try{
 const context=await browser.newContext({viewport:{width:390,height:844}});const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
 const results=[];page.on('response',async response=>{if(response.url().endsWith('/qa-api')){const data=await response.json();if(data.scoreId)results.push(data);}});
 await page.goto('http://127.0.0.1:5175/');await page.waitForFunction(async()=>{const {state}=await import('/src/services/game-store.ts');return state.initialized;});await page.locator('.age-window').waitFor();await page.keyboard.press('Escape');await page.locator('.age-window').waitFor({state:'hidden'});
 assert.equal(await page.locator('.enemy-speed').innerText(),'скорость врагов');
 const canvas=page.locator('canvas.game-field');await canvas.waitFor();await page.waitForTimeout(150);
 for(const width of [320,360,390,430]){
  await page.setViewportSize({width,height:844});await page.waitForTimeout(100);
  const geometry=await page.evaluate(()=>{const field=document.querySelector('canvas.game-field').getBoundingClientRect(),meter=document.querySelector('.enemy-speed').getBoundingClientRect();return {f:{x:field.x,y:field.y,w:field.width,h:field.height},m:{x:meter.x,y:meter.y,w:meter.width,h:meter.height},overflow:document.documentElement.scrollWidth>innerWidth};});
  assert.ok(Math.abs(geometry.f.w-380*Math.min(width/412,1))<.1);assert.ok(Math.abs(geometry.f.w-geometry.f.h)<.1);assert.ok(geometry.m.y+geometry.m.h<=geometry.f.y);assert.equal(geometry.overflow,false);
  checks.push({name:'meter-above-field-and-reference-geometry',width,...geometry});
 }
 await page.setViewportSize({width:390,height:844});await canvas.click({position:{x:260,y:250}});await page.waitForFunction(async()=>{const {world}=await import('/src/services/game-store.ts');return world.value?.playing;});
 await page.evaluate(async()=>{const {state}=await import('/src/services/game-store.ts');state.screen='help';});await page.waitForTimeout(120);const paused=await page.evaluate(async()=>{const {world}=await import('/src/services/game-store.ts');return world.value.timeMs;});await page.waitForTimeout(250);assert.equal(await page.evaluate(async()=>{const {world}=await import('/src/services/game-store.ts');return world.value.timeMs;}),paused);await page.keyboard.press('Escape');
 await page.waitForFunction(async()=>{const {world}=await import('/src/services/game-store.ts');return world.value?.dead;},{timeout:30000});await page.waitForFunction(async()=>{const {state}=await import('/src/services/game-store.ts');return state.history.some(a=>a.phase==='confirmed'&&a.proofVersion===2);},{timeout:30000});checks.push({name:'actual-controller-round-v2-start-replay-confirm-and-modal-pause'});
 await page.close();
 // Visual specimens: actual Vue HUD + Canvas painter, isolated synthetic world.
 const sample=await context.newPage();sample.on('pageerror',e=>errors.push(e.message));
 await sample.addInitScript(()=>{const original=window.requestAnimationFrame.bind(window);window.requestAnimationFrame=cb=>original(t=>{if(!window.__brakeFreeze)cb(t);});});
 await sample.goto('http://127.0.0.1:5175/');await sample.waitForFunction(async()=>{const {state}=await import('/src/services/game-store.ts');return state.initialized;});await sample.waitForFunction(async()=>{const {world}=await import('/src/services/game-store.ts');return !!world.value;});await sample.waitForTimeout(150);if(await sample.locator('.age-window').isVisible())await sample.keyboard.press('Escape');
 await sample.evaluate(async()=>{window.__brakeFreeze=true;const {state}=await import('/src/services/game-store.ts');state.screen='';const caption=document.querySelector('.start-caption');if(caption)caption.style.display='none';});await sample.waitForTimeout(60);
 async function specimen(kind,flags={}){return sample.evaluate(async ({kind,flags})=>{
   const {state,world}=await import('/src/services/game-store.ts');const {FieldPainter}=await import('/src/game/painter.ts');const call=input=>JSON.parse(globalThis.untouchKernel(JSON.stringify(input)));const config=JSON.parse(JSON.stringify(state.config.config));config.game.startInvulnSec=30;config.enemyPace={...config.enemyPace,...flags};call({op:'create',proofVersion:2,config,requestId:'visual-brake-specimen'});call({op:'start'});call({op:'move',dx:110,dy:105});let s;
   const elapsed=kind==='empty'?0:kind==='charging'?3000:8000;for(let t=0;t<elapsed;t+=50)s=call({op:'tick',ms:50});s=call({op:'snapshot'});s.invulnerable=false;
   if(kind==='wave'||kind==='loss'){
    const before=s.brake.speed;call({op:'move',dx:-110,dy:-105});const pressed=call({op:'snapshot'});for(let t=0;t<200;t+=50)s=call({op:'tick',ms:50});s=call({op:'snapshot'});s.invulnerable=false;s.player.x=282;s.player.y=282;
    world.value={...s,brake:{...s.brake,presses:0}};await new Promise(r=>setTimeout(r,0));world.value={...s,brake:{...s.brake,beforeSpeed:before,afterSpeed:pressed.brake.afterSpeed}};
   }else world.value=s;
   const painter=new FieldPainter(document.querySelector('canvas.game-field'));painter.configure(config);painter.draw(s,config,100);return {kind,brake:s.brake,hero:s.player};
 },{kind,flags});}
 for(const kind of ['empty','charging','ready','wave','loss']){const state=await specimen(kind);if(kind==='loss')await sample.waitForTimeout(160);else await sample.waitForTimeout(20);await sample.screenshot({path:path.join(evidence,kind+'.png')});if(kind==='ready'||kind==='wave')await sample.locator('.gameplay-layer').screenshot({path:path.join(evidence,kind+'-field.png')});checks.push({name:'actual-renderer-synthetic-'+kind,...state});}
 for(const brakeEnabled of [false,true])for(const speedBarEnabled of [false,true]){
  const s=await specimen('ready',{brakeEnabled,speedBarEnabled});assert.equal(s.brake.enabled,brakeEnabled);assert.equal(s.brake.speedBarEnabled,speedBarEnabled);assert.equal(await sample.locator('.enemy-speed-slot').count(),speedBarEnabled?1:0);
  if(!brakeEnabled){assert.equal(s.brake.presses,0);assert.ok(Math.abs(s.brake.effectiveSec-8.001)<.00001);const equality=await sample.evaluate(async()=>{const {state,world}=await import('/src/services/game-store.ts');const {FieldPainter}=await import('/src/game/painter.ts');const config=JSON.parse(JSON.stringify(state.config.config)),s=JSON.parse(JSON.stringify(world.value)),canvas=document.querySelector('canvas.game-field'),p=new FieldPainter(canvas);p.configure(config);p.draw(s,config,100);const before=canvas.toDataURL();p.draw({...s,brake:null},config,100);return before===canvas.toDataURL();});assert.equal(equality,true);}
  await sample.screenshot({path:path.join(evidence,`toggles-brake-${brakeEnabled}-meter-${speedBarEnabled}.png`)});checks.push({name:'independent-toggles',brakeEnabled,speedBarEnabled});
 }
 assert.equal((await sample.locator('body').innerText()).includes('уже открыта в другом окне'),false);assert.deepEqual(errors,[]);await fs.writeFile(path.join(evidence,'browser-checks.json'),JSON.stringify({checks,errors,note:'Geometry and v2 round use real app/controller and isolated local API. Five visual specimens use actual Vue/Canvas renderer and synthetic safe state, no production data.'},null,2));console.log(JSON.stringify({passed:checks.length,errors,evidence}));
}finally{await browser.close();}
