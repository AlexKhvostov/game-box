import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {chargeSector,enemySpeedAt,createBrakeDemo,brakeButton,speedBar} from '../docs/design/simple-energy-bonus-20261016/live-kit/brake-kit.js';

// Independent clock/speed checks: cooldown cannot change real elapsed time.
assert.equal(chargeSector(0),'');
assert.match(chargeSector(.25),/A44 44 0 0 1 94\.00000 50\.00000/);
assert.match(chargeSector(.5),/50\.00000 94\.00000/);
assert.match(chargeSector(.75),/A44 44 0 1 1 6\.00000 50\.00000/);
assert.equal((chargeSector(1).match(/A44/g)||[]).length,2);
assert.equal(chargeSector(-1),'');assert.equal(chargeSector(2),chargeSector(1));
assert.throws(()=>chargeSector(NaN),TypeError);
const model=createBrakeDemo();
assert.equal(model.press(),null);
model.advance(6);assert.equal(model.press(),null);assert.equal(model.snapshot().effective,6);
model.advance(2);assert.equal(model.snapshot().ready,true);
const first=model.press();
assert.ok(Math.abs(first.before-43.077598634152466)<1e-10);
assert.ok(Math.abs(first.after-17.201165773086217)<1e-10);
assert.equal(first.elapsed,8);assert.equal(first.effective,0);assert.equal(first.remaining,8);
assert.equal(model.press(),null,'Repeated press during cooldown must be rejected');
model.advance(8.25);model.press();assert.ok(Math.abs(model.snapshot().effective-.25)<1e-10);
model.advance(8.75);model.press();assert.ok(Math.abs(model.snapshot().effective-1)<1e-10);
assert.equal(model.snapshot().elapsed,25);
assert.equal(model.snapshot().presses,3);
assert.throws(()=>model.advance(-1),RangeError);
assert.throws(()=>createBrakeDemo({cooldown:0}),RangeError);
assert.ok(Math.abs(enemySpeedAt(-10)-enemySpeedAt(0))<1e-10);
assert.match(brakeButton({state:'charging',progress:.5}),/stroke-dasharray="50 100"/);
assert.throws(()=>brakeButton({state:'unknown'}),RangeError);
assert.throws(()=>speedBar({max:0}),RangeError);
assert.match(speedBar({value:200}),/aria-valuenow="150"/);
console.log('PASS: sector geometry, ideal/delayed cooldown cycles, bounds and render contracts');

const modules=process.env.UNTOUCH_BROWSER_MODULES;
if(!modules)throw new Error('UNTOUCH_BROWSER_MODULES must point to the bundled node_modules');
const {chromium}=await import(pathToFileURL(path.join(modules,'playwright/index.mjs')));
const url=process.env.UNTOUCH_BRAKE_URL||'http://127.0.0.1:8896/';
const evidence=path.resolve('docs/design/simple-energy-bonus-20261016/live-kit/evidence/brake-20261023');
await fs.mkdir(evidence,{recursive:true});
const browser=await chromium.launch({headless:true});
const errors=[],missing=[],external=[],checks=[];
try {
 const page=await browser.newPage({viewport:{width:1440,height:1080},deviceScaleFactor:1});
 page.on('pageerror',e=>errors.push(e.message));
 page.on('response',r=>{if(r.status()>=400)missing.push({url:r.url(),status:r.status()});});
 page.on('request',r=>{if(!r.url().startsWith(url)&&!r.url().startsWith('data:'))external.push(r.url());});
 await page.goto(url+'#brake');
 await page.locator('[data-brk-live-button] .brk-button').waitFor();
 assert.equal(await page.locator('[data-brk-live-button] button').isDisabled(),true);
 const size=await page.evaluate(()=>{const b=document.querySelector('[data-brk-live-button] button').getBoundingClientRect(),h=document.querySelector('.brk-live-arena>.brk-hero').getBoundingClientRect();return {bw:b.width,bh:b.height,hw:h.width,hh:h.height};});
 assert.ok(Math.abs(size.bw-size.bh)<.1);assert.ok(size.bw<=size.hw);
 assert.equal(await page.locator('.brk-speed-caption').first().textContent(),'скорость врагов');
 assert.equal(await page.locator('[data-brk-live-speed]').innerText(),'скорость врагов');
 assert.equal(await page.locator('[data-brk-live-button] .brk-rim').evaluate(el=>el.tagName),'rect');
 checks.push({name:'initial-state-square-size-no-speed-numbers',size});

 // Verify quarter/half/three-quarter fill on the SAME face and ring.
 for(const p of [0,25,50,75,100]){
  await page.locator('[data-brk-charge]').fill(String(p));
  const details=await page.locator('[data-brk-specimen="charging"] .brk-button').evaluate(el=>({progress:Number(el.dataset.progress),d:el.querySelector('.brk-charge-face').getAttribute('d'),arc:el.querySelector('.brk-charge-ring').getAttribute('stroke-dasharray')}));
  assert.equal(details.progress,p/100);assert.equal(details.arc,`${p} 100`);assert.equal(details.d,chargeSector(p/100,64));
 }
 await page.locator('[data-brk-charge]').fill('50');
 await page.locator('.brk-state-grid').screenshot({path:path.join(evidence,'button-states.png')});
 checks.push({name:'background-and-ring-share-clockwise-progress',values:[0,25,50,75,100]});

 // Inspect live meter during hold/fade and cancel with a new update.
 const immediate=await page.evaluate(async()=>{
  const {mountSpeedBar}=await import('./brake-kit.js?v=2');
  const host=document.createElement('div');host.style.width='400px';document.body.append(host);
  const component=mountSpeedBar(host,{value:90});window.__brakeMeter={component,host};
  component.brakeTo(45,{holdMs:500,fadeMs:400});
  const el=host.querySelector('.brk-speed-loss');return {state:component.getState(),left:el.style.left,width:el.style.width,color:getComputedStyle(el).backgroundImage,caption:host.innerText};
 });
 assert.equal(immediate.state.value,45);assert.equal(immediate.state.tail,45);assert.equal(immediate.left,'30%');assert.equal(immediate.width,'30%');assert.match(immediate.color,/104, 229, 157/);assert.equal(immediate.caption,'скорость врагов');
 await page.waitForTimeout(250);
 assert.equal(await page.evaluate(()=>window.__brakeMeter.component.getState().tail),45);
 await page.waitForTimeout(400);
 const fading=await page.evaluate(()=>window.__brakeMeter.component.getState());assert.ok(fading.tail>0&&fading.tail<45);
 await page.waitForTimeout(350);
 assert.equal(await page.evaluate(()=>window.__brakeMeter.component.getState().tail),0);
 await page.evaluate(()=>{const c=window.__brakeMeter.component;c.setValue(100);c.brakeTo(20);c.setValue(135);});
 await page.waitForTimeout(450);
 assert.equal(await page.evaluate(()=>window.__brakeMeter.component.getState().value),135);
 assert.equal(await page.evaluate(()=>window.__brakeMeter.component.getState().tail),0);
 await page.evaluate(()=>{window.__brakeMeter.component.destroy();window.__brakeMeter.host.remove();delete window.__brakeMeter;});
 checks.push({name:'green-tail-hold-fade-complete-and-cancel',immediate,fading});

 await page.locator('[data-brk-action="ready"]').click();
 assert.equal(await page.locator('[data-brk-live-button] button').isEnabled(),true);
 await page.locator('[data-brk-live-button] button').focus();await page.keyboard.press('Enter');
 assert.equal(await page.locator('[data-brk-live-button] button').isDisabled(),true);
 await page.locator('[data-brk-live-button] button').evaluate(el=>el.click());
 await page.waitForTimeout(400);
 assert.ok(Number(await page.locator('[data-brk-live-button] button').getAttribute('data-progress'))<.15,'Repeat click must not instantly refill the button');
 await page.locator('[data-brk-action="toggle"]').click();
 const paused=await page.locator('[data-brk-clock]').textContent();await page.waitForTimeout(150);assert.equal(await page.locator('[data-brk-clock]').textContent(),paused);
 checks.push({name:'keyboard-press-repeat-blocked-and-pause',paused});

 await page.locator('[data-brk-action="ready"]').click();
 await page.locator('[data-brk-action="brake"]').click();
 await page.waitForTimeout(45);
 await page.locator('.brk-meter-demo').screenshot({path:path.join(evidence,'speed-green-tail.png')});
 await page.waitForTimeout(400);
 await page.locator('#workspace').screenshot({path:path.join(evidence,'desktop.png')});
 for(const w of [320,360,390,430]){
  await page.setViewportSize({width:w,height:1000});
  const geometry=await page.evaluate(()=>({viewport:innerWidth,doc:document.documentElement.scrollWidth,workspace:document.querySelector('#workspace').getBoundingClientRect().width,arena:document.querySelector('.brk-live-arena').getBoundingClientRect().width}));
  assert.ok(geometry.doc<=geometry.viewport+1,`Horizontal overflow at ${w}: ${JSON.stringify(geometry)}`);
  const nav=await page.locator('.kit-header nav').boundingBox();assert.ok(nav.width>w*.75&&nav.height<70,'Mobile navigation must be a readable horizontal row');
  checks.push({name:`width-${w}`,geometry});
  if(w===320||w===390)await page.screenshot({path:path.join(evidence,`mobile-${w}.png`),fullPage:true});
 }
 await page.setViewportSize({width:1440,height:1080});
 await page.locator('[data-brk-action="toggle"]').click();
 await page.waitForTimeout(200);
 await page.evaluate(()=>{window.__oldBrakeClock=document.querySelector('[data-brk-clock]');location.hash='library';});
 await page.locator('.component-grid').first().waitFor();
 const old=await page.evaluate(()=>window.__oldBrakeClock.textContent);await page.waitForTimeout(200);assert.equal(await page.evaluate(()=>window.__oldBrakeClock.textContent),old);
 await page.evaluate(()=>location.hash='brake');await page.locator('[data-brk-live-button] button').waitFor();
 assert.equal(await page.locator('[data-brk-clock]').textContent(),'00:00.000');
 checks.push({name:'route-disposes-previous-clock-and-mounts-cleanly'});
 await page.locator('[data-brk-action="toggle"]').click();
 await page.waitForTimeout(4200);
 const halfway=Number(await page.locator('[data-brk-live-button] button').getAttribute('data-progress'));assert.ok(halfway>.48&&halfway<.65);
 assert.equal(await page.locator('[data-brk-live-button] button').isDisabled(),true);
 await page.waitForTimeout(4050);
 assert.equal(await page.locator('[data-brk-live-button] button').isEnabled(),true);
 await page.locator('[data-brk-live-button] button').click();
 await page.locator('.brk-live-card').screenshot({path:path.join(evidence,'live-press.png')});
 await page.locator('[data-brk-action="toggle"]').click();
 checks.push({name:'real-eight-second-cycle-charges-and-becomes-ready',halfway});
 await page.emulateMedia({reducedMotion:'reduce'});await page.reload();await page.locator('[data-brk-action="ready"]').click();await page.locator('[data-brk-live-button] button').click();await page.waitForTimeout(180);
 assert.equal(await page.locator('[data-brk-live-speed] .brk-speed-loss').isVisible(),false);
 checks.push({name:'reduced-motion-green-hold-then-clear'});
 assert.deepEqual(errors,[]);assert.deepEqual(missing,[]);assert.deepEqual(external,[]);
 await fs.writeFile(path.join(evidence,'browser-checks.json'),JSON.stringify({ok:true,checks,errors,missing,external},null,2));
 console.log(JSON.stringify({ok:true,browserChecks:checks.map(c=>c.name),evidence}));
}finally{await browser.close();}
