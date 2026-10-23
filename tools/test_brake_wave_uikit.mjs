import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const {chromium}=await import(pathToFileURL(path.join(process.env.UNTOUCH_BROWSER_MODULES,'playwright/index.mjs')));
const evidence=path.resolve('docs/design/simple-energy-bonus-20261016/live-kit/evidence/brake-wave-20261023');
await fs.mkdir(evidence,{recursive:true});
const browser=await chromium.launch({headless:true}),errors=[],checks=[];
try{
 const page=await browser.newPage({viewport:{width:1440,height:1080}});
 page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://127.0.0.1:8896/#brake');await page.locator('[data-brk-live-button] button').waitFor();
 for(const [i,kind] of ['enemy','hero'].entries()){
  const floor=page.locator('.brk-layer-floor').nth(i);await floor.scrollIntoViewIfNeeded();
  const top=await floor.evaluate(el=>{const r=el.getBoundingClientRect(),target=document.elementFromPoint(r.left+r.width/2+5,r.top+r.height/2+2);return {className:target.className,z:getComputedStyle(target).zIndex};});
  assert.ok(top.className.includes(kind==='enemy'?'brk-layer-enemy':'brk-layer-hero'),JSON.stringify(top));
  checks.push({name:`${kind}-occludes-floor-button`,top});
 }
 await page.locator('.brk-layer-grid').screenshot({path:path.join(evidence,'body-overlap.png')});
 const mainLayers=await page.evaluate(()=>({button:getComputedStyle(document.querySelector('.brk-live-pedal')).zIndex,wave:getComputedStyle(document.querySelector('.brk-wave')).zIndex,enemy:getComputedStyle(document.querySelector('.brk-live-arena .brk-enemy')).zIndex,hero:getComputedStyle(document.querySelector('.brk-live-arena>.brk-hero')).zIndex}));
 assert.ok(Number(mainLayers.button)<Number(mainLayers.wave)&&Number(mainLayers.wave)<Number(mainLayers.enemy)&&Number(mainLayers.enemy)<=Number(mainLayers.hero));
 checks.push({name:'same-layer-order-in-live-arena',mainLayers});
 await page.evaluate(async()=>{
  const {mountBrakeButton}=await import('./brake-kit.js?v=2');
  const host=document.createElement('div');document.body.append(host);
  const component=mountBrakeButton(host,{state:'charging',progress:.99});let starts=0;
  component.element.addEventListener('animationstart',e=>{if(e.animationName==='brk-ready-cue')starts++;});
  window.__readyTest={host,component,getStarts:()=>starts};
  component.setState({state:'ready'});for(let i=0;i<25;i++)component.setState({state:'ready'});
 });
 await page.waitForTimeout(420);
 const ready=await page.evaluate(()=>{const {component,getStarts}=window.__readyTest;return {starts:getStarts(),flashing:component.element.classList.contains('brk-ready-flash'),transform:getComputedStyle(component.element.querySelector('.brk-face')).transform,color:getComputedStyle(component.element.querySelector('.brk-stop-2')).stopColor,shadow:getComputedStyle(component.element.querySelector('.brk-floor-shadow')).opacity};});
 assert.equal(ready.starts,1);assert.equal(ready.flashing,false);assert.match(ready.transform,/-4\)/);assert.equal(ready.color,'rgb(165, 245, 121)');assert.ok(Number(ready.shadow)>=.5);
 await page.evaluate(()=>window.__readyTest.component.setState({state:'pressed'}));await page.waitForTimeout(180);
 const down=await page.evaluate(()=>getComputedStyle(window.__readyTest.component.element.querySelector('.brk-face')).transform);assert.notEqual(down,ready.transform);
 await page.evaluate(()=>{window.__readyTest.component.setState({state:'charging',progress:.9});window.__readyTest.component.setState({state:'ready'});});await page.waitForTimeout(420);
 assert.equal(await page.evaluate(()=>window.__readyTest.getStarts()),2);
 await page.evaluate(()=>{window.__readyTest.component.destroy();window.__readyTest.host.remove();});
 checks.push({name:'one-ready-flash-per-transition-greener-raised-shadow-and-press-down',ready,down});

 await page.evaluate(async()=>{
  const {mountBrakeWave}=await import('./brake-kit.js?v=2');
  const host=document.createElement('div');host.className='brk-wave';document.body.append(host);
  const hits=[];const wave=mountBrakeWave(host,{onHit:target=>hits.push(target.id)});
  window.__waveTest={host,wave,hits};wave.play([{x:190,y:190,id:'near'},{x:230,y:190,id:'middle'},{x:10,y:10,id:'far'}]);
 });
 assert.deepEqual(await page.evaluate(()=>window.__waveTest.hits),['near']);
 await page.waitForTimeout(200);
 const during=await page.evaluate(()=>({hits:window.__waveTest.hits.slice(),active:window.__waveTest.wave.getState().active,r:Number(window.__waveTest.host.querySelector('circle').getAttribute('r')),visibleOpacity:Number(getComputedStyle(window.__waveTest.host.querySelector('circle')).opacity)}));
 assert.ok(during.active&&during.r>30);assert.ok(during.hits.includes('middle'));assert.ok(during.visibleOpacity>.1,'Expanding ring must actually be visible, not only have a radius');
 await page.waitForTimeout(600);
 assert.deepEqual(await page.evaluate(()=>window.__waveTest.hits),['near','middle','far']);
 assert.equal(await page.evaluate(()=>window.__waveTest.wave.getState().active),false);
 await page.evaluate(()=>{const t=window.__waveTest;t.hits.length=0;t.wave.play([{x:10,y:10,id:'cancelled'}]);t.wave.stop();});await page.waitForTimeout(720);
 assert.deepEqual(await page.evaluate(()=>window.__waveTest.hits),[]);
 await page.evaluate(()=>{window.__waveTest.wave.destroy();window.__waveTest.host.remove();});
 checks.push({name:'wave-expands-hits-near-before-far-once-and-cancels',during});

 await page.locator('[data-brk-action="wave"]').click();await page.waitForTimeout(210);
 assert.equal(await page.locator('.brk-wave-svg').getAttribute('data-active'),'true');
 await page.locator('.brk-live-card').screenshot({path:path.join(evidence,'expanding-wave.png')});
 await page.locator('[data-brk-action="toggle"]').click();
 assert.equal(await page.locator('.brk-wave-svg').getAttribute('data-active'),'false');
 assert.equal(await page.locator('.brk-wave-hit').count(),0);
 await page.locator('[data-brk-action="ready"]').click();await page.waitForTimeout(400);
 await page.locator('.brk-state-grid').screenshot({path:path.join(evidence,'square-states.png')});
 await page.locator('#workspace').screenshot({path:path.join(evidence,'desktop.png')});
 checks.push({name:'live-wave-preview-and-pause-cleanup'});
 await page.locator('[data-brk-action="wave"]').click();await page.waitForTimeout(100);
 await page.evaluate(()=>{window.__oldWave=document.querySelector('.brk-wave-svg');location.hash='library';});await page.locator('.component-grid').first().waitFor();
 assert.equal(await page.evaluate(()=>window.__oldWave.getAttribute('data-active')),'false');
 checks.push({name:'route-destroys-wave-before-hits-can-leak'});
 await page.setViewportSize({width:320,height:1000});await page.evaluate(()=>location.hash='brake');await page.locator('[data-brk-live-button] button').waitFor();
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
 await page.screenshot({path:path.join(evidence,'mobile-320.png'),fullPage:true});
 await page.emulateMedia({reducedMotion:'reduce'});await page.reload();await page.locator('[data-brk-action="wave"]').click();await page.waitForTimeout(250);
 const reduced=await page.locator('.brk-wave-svg circle').evaluateAll(rings=>rings.map(el=>Number(el.getAttribute('r'))));assert.deepEqual(reduced,[30,30,30]);
 await page.locator('[data-brk-action="toggle"]').click();checks.push({name:'320px-and-reduced-motion-static-wave',reduced});
 assert.deepEqual(errors,[]);await fs.writeFile(path.join(evidence,'browser-checks.json'),JSON.stringify({ok:true,checks,errors},null,2));
 console.log(JSON.stringify({ok:true,checks:checks.map(c=>c.name),evidence}));
}finally{await browser.close();}
