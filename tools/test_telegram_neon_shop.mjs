import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';

const project=path.resolve(import.meta.dirname,'..');
const web=path.resolve(process.env.UNTOUCH_WEB_ROOT||path.join(project,'telegram-web'));
const baseline=path.join(project,'tmp/telegram-neon-shop-20261013/baseline');
const before=process.argv.includes('--baseline');
const fitOnly=process.argv.includes('--fit-only');
const targeted=process.argv.includes('--targeted')||fitOnly;
const output=path.join(project,'docs/release-evidence/telegram-neon-shop-20261013',before?'before':fitOnly?'after-lifecycle':targeted?'after-targeted':'after');
await fs.mkdir(output,{recursive:true});
const config=JSON.parse(await fs.readFile(path.join(baseline,'telegram-web/config/gameplay-config.json'),'utf8'));
const modules=process.env.UNTOUCH_BROWSER_MODULES||'C:/Users/alexe/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const {chromium}=await import(pathToFileURL(path.join(modules,'playwright/index.mjs')));
const cases=[],failures=[],errors=[],missing=[],blocked=[],api=[],wallets=new Map();let serial=0;
const check=async(name,fn)=>{if(fitOnly&&!/^(?:unchanged|sheets\/|fit\/|no-|source-)/.test(name))return;try{const value=await fn();cases.push({name,status:'PASS',value});}catch(e){failures.push({name,error:e.message});cases.push({name,status:'FAIL',error:e.message});}};
const sourceFiles=['index.html','js/sheets.js','js/main.js','js/game-world.js','js/economy.js','js/renderer.js','js/telegram.js','js/adsgram.js','js/shop-catalog.js','js/strings-ru.js','js/neon-shop-fit.js','css/neon-home.css','css/neon-windows.css','css/neon-lives.css','css/neon-shop.css','css/neon-shop-packs.css','config/gameplay-config.json'];
async function sourceHashes(){const list=[];for(const rel of sourceFiles){try{list.push({path:`telegram-web/${rel}`,sha256:crypto.createHash('sha256').update(await fs.readFile(path.join(web,rel))).digest('hex')});}catch{}}return list;}
const initialHashes=before?null:await sourceHashes();
const server=http.createServer(async(req,res)=>{
  try{
    const url=new URL(req.url,'http://localhost');
    if(url.pathname.startsWith('/api/')||url.pathname==='/__fixture/pay'){
      let payload={};if(req.method==='POST'){let text='';for await(const chunk of req)text+=chunk;payload=JSON.parse(text||'{}');}
      api.push({path:url.pathname,action:payload.action||null,productId:payload.productId||null});
      let data={ok:true,scores:[],bound:false};
      const state=wallets.get(payload.initData||payload.caseId);
      if(url.pathname==='/api/config.php')data={ok:true,config,revision:'shop-isolated-fixture'};
      if(url.pathname==='/api/payments.php'&&payload.action==='create_invoice'){
        if(!state)throw Error('Unknown fixture context');state.invoices++;
        const pack=config.economy.starsShop.packs.find(p=>p.id===payload.productId);if(!pack)throw Error('Unknown fixture product');
        if(state.status==='invoice-error'){res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'Fixture invoice refused'}));return;}
        data={ok:true,invoiceUrl:`http://127.0.0.1:${server.address().port}/invoice/${pack.id}?case=${encodeURIComponent(payload.initData)}`,crystals:pack.crystals};
      }
      if(url.pathname==='/__fixture/pay'){
        if(!state)throw Error('Unknown paid fixture');const pack=config.economy.starsShop.packs.find(p=>p.id===payload.productId);
        if(!state.credited){state.tokens+=pack.crystals;state.credited=true;state.credits++;}
      }
      if(url.pathname==='/api/payments.php'&&payload.action==='wallet')data={ok:true,wallet:{tokens:state?.tokens||0,plusUntilMs:0}};
      res.setHeader('Content-Type','application/json');res.end(JSON.stringify(data));return;
    }
    const rel=url.pathname==='/'?'index.html':url.pathname.slice(1),file=path.resolve(web,rel);
    if(!file.startsWith(web+path.sep)){res.writeHead(403);res.end();return;}
    const candidates=[];if(before)candidates.push(path.join(baseline,'telegram-web',rel));if(rel.startsWith('assets/'))candidates.push(path.join(project,rel));candidates.push(file);
    let data;for(const candidate of candidates){try{data=await fs.readFile(candidate);break;}catch{}}
    if(!data)throw Error('Missing asset');
    const types={'.js':'text/javascript','.css':'text/css','.html':'text/html','.json':'application/json','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.mp3':'audio/mpeg','.wav':'audio/wav'};res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');res.end(data);
  }catch(e){res.writeHead(404);res.end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const origin=`http://127.0.0.1:${server.address().port}`,browser=await chromium.launch({headless:true});
async function newPage({width=390,height=844,payment=null,safe=false}={}){
  const page=await browser.newPage({viewport:{width,height},hasTouch:true});const caseId=`fixture-${++serial}`;
  wallets.set(caseId,{status:payment,tokens:0,invoices:0,credits:0,credited:false});
  page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()===404)missing.push(r.url());});
  await page.route('**/*',route=>{if(new URL(route.request().url()).origin===origin)return route.continue();blocked.push(route.request().url());return route.fulfill({contentType:'text/javascript',body:''});});
  await page.addInitScript(({payment,caseId,safe})=>{
    localStorage.setItem('untouch_tg_economy',JSON.stringify({lives:8,tokens:payment?0:999,musicEnabled:false}));
    window.__observerLog=[];
    window.__shopRaf={requests:0,callbacks:0,cancelled:0,pending:[]};
    const nativeRAF=window.requestAnimationFrame.bind(window),nativeCancelRAF=window.cancelAnimationFrame.bind(window);
    window.requestAnimationFrame=callback=>{
      if(!new Error().stack.includes('/js/neon-shop-fit.js'))return nativeRAF(callback);
      const log=window.__shopRaf;log.requests++;const id=nativeRAF(time=>{log.pending=log.pending.filter(x=>x!==id);log.callbacks++;callback(time);});log.pending.push(id);return id;
    };
    window.cancelAnimationFrame=id=>{const log=window.__shopRaf;if(log.pending.includes(id)){log.pending=log.pending.filter(x=>x!==id);log.cancelled++;}nativeCancelRAF(id);};
    for(const kind of ['MutationObserver','ResizeObserver']){
      const Native=window[kind];if(!Native)continue;
      window[kind]=class extends Native{
        constructor(callback){const record={kind,targets:[],seenTargets:[],callbacks:0,disconnects:0};super((...args)=>{record.callbacks++;callback(...args);});this.__record=record;window.__observerLog.push(record);}
        observe(target,options){const label=target.id||target.className||target.nodeName;if(!this.__record.targets.includes(label))this.__record.targets.push(label);if(!this.__record.seenTargets.includes(label))this.__record.seenTargets.push(label);return super.observe(target,options);}
        disconnect(){this.__record.targets=[];this.__record.disconnects++;return super.disconnect();}
        unobserve(target){this.__record.targets=this.__record.targets.filter(x=>x!==(target.id||target.className||target.nodeName));return super.unobserve(target);}
      };
    }
    if(payment||safe){
      window.__invoiceOpens=0;
      const tg={initData:payment?caseId:'',initDataUnsafe:{},isFullscreen:true,safeAreaInset:safe?{top:24,bottom:24,left:6,right:6}:{},contentSafeAreaInset:safe?{top:88,left:10,right:10}:{},ready(){},expand(){},disableVerticalSwipes(){},onEvent(){},setHeaderColor(){},setBackgroundColor(){},openInvoice(url,callback){window.__invoiceOpens++;const productId=new URL(url).pathname.split('/').at(-1);setTimeout(async()=>{if(payment==='paid')await fetch('/__fixture/pay',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({caseId,productId})});callback(payment==='invoice-error'?'failed':payment);},160);}};
      window.Telegram={WebApp:tg};
    }
  },{payment,caseId,safe});
  await page.goto(origin);await page.locator('#boot-loader').waitFor({state:'hidden'});await page.evaluate(()=>{window.app._tick=()=>{};window.app.showToast=()=>{};});page.fixtureCaseId=caseId;return page;
}
async function settle(page){await page.locator('#sheet-panel').waitFor({state:'visible'});await page.waitForTimeout(40);await page.locator('#sheet-panel').evaluate(async el=>Promise.all(el.getAnimations().filter(a=>a.effect?.getTiming().iterations!==Infinity).map(a=>a.finished.catch(()=>{}))));await page.waitForTimeout(40);}
async function openShop(page,{tokens=999,ready=true,adReady=true,light=false,tab=1,font=1}={}){
  await page.evaluate(({tokens,ready,adReady,light,tab})=>{
    const app=window.app;document.querySelectorAll('[data-verifier-font]').forEach(el=>{el.style.fontSize=el.dataset.verifierFont;delete el.dataset.verifierFont;});
    app.economy.tokens=tokens;app.economy.lastTimedBonusClaimMs=ready?0:Date.now()-120000;app.economy.lastWatchAdClaimMs=adReady?0:Date.now();app.economy.lightTheme=light;document.documentElement.dataset.theme=light?'light':'dark';app._updateHud();app.sheets.open('crystals',{tab});
  },{tokens,ready,adReady,light,tab});await settle(page);
  if(font===2){await page.evaluate(()=>{const els=[...document.querySelectorAll('.neon-shop-header *,.crystals-tab *,.neon-shop-pack *')].filter(el=>[...el.childNodes].some(n=>n.nodeType===Node.TEXT_NODE&&n.textContent.trim()));const snapshot=els.map(el=>({el,size:parseFloat(getComputedStyle(el).fontSize),old:el.style.fontSize}));for(const{el,size,old}of snapshot){el.dataset.verifierFont=old;el.style.fontSize=`${size*2}px`;}});await page.waitForTimeout(80);}
}
async function audit(page){return page.evaluate(()=>{
  const rect=el=>{const r=el.getBoundingClientRect();return{left:r.left,top:r.top,right:r.right,bottom:r.bottom,width:r.width,height:r.height};};
  const style=el=>{const s=getComputedStyle(el);return{display:s.display,visibility:s.visibility,color:s.color,background:s.backgroundImage,radius:s.borderRadius};};
  const panel=document.getElementById('sheet-panel'),balance=document.querySelector('.crystals-balance-panel'),gift=document.getElementById('gift-btn'),ad=document.getElementById('watch-ad-btn');
  return{panel:rect(panel),overflow:panel.scrollWidth>panel.clientWidth+1,balance:rect(balance),balanceText:document.getElementById('sheet-crystal-balance').textContent,gift:{...rect(gift),...style(gift),background:style(gift.querySelector('.gift-btn-inner')).background,class:gift.className,text:gift.innerText},ad:{...rect(ad),...style(ad),class:ad.className,text:ad.innerText},
    tabs:[...document.querySelectorAll('.crystals-tab')].map(el=>({tab:Number(el.dataset.tab),...rect(el),...style(el),class:el.className,text:el.innerText})),
    cards:[...document.querySelectorAll('[data-iap]')].map(el=>({id:el.dataset.iap,...rect(el),...style(el),text:el.innerText,price:rect(el.querySelector('.neon-shop-pack-price')),piles:el.querySelectorAll('.neon-shop-pack-pile .crystal-img').length})),
    fitted:[...document.querySelectorAll('[data-shop-fit]')].map(el=>({text:el.textContent,slot:rect(el),leaf:rect(el.firstElementChild),whiteSpace:getComputedStyle(el.firstElementChild).whiteSpace})),
    clipped:[...document.querySelectorAll('.neon-shop-header span,.crystals-tab span,.neon-shop-pack span')].filter(el=>el.children.length===0&&el.textContent.trim()&&!el.closest('[data-shop-fit]')&&el.clientWidth>0&&el.scrollWidth>el.clientWidth+1).map(el=>el.textContent),
    frame:rect(document.querySelector('.crystals-content-area')),
    hints:[...document.querySelectorAll('#crystals-pane .daily-hint,#crystals-pane .daily-rail-caption,#crystals-pane .earn-hint,#crystals-pane .shop-iap-note')].map(el=>({text:el.textContent,color:getComputedStyle(el).color})),
    heightLimit:parseFloat(getComputedStyle(panel).getPropertyValue('--shop-window-height'))||512,
    tabFont:parseFloat(getComputedStyle(document.querySelector('.tab-txt')).fontSize),
    giftRing:gift.querySelectorAll('.gift-ring').length,
    availableHeight:document.querySelector('.neon-shop-packs-pane')?.clientHeight,compact:document.querySelector('.neon-shop-packs-pane')?.classList.contains('compact'),
    legacyLabels:[...document.querySelectorAll('.crystals-menu-label')].map(el=>el.innerText)};
});}
function accept(r,{width,height,tokens,ready,adReady,tab=1}){
  assert.equal(r.overflow,false);assert.deepEqual(r.clipped,[]);assert.equal(r.balanceText,String(tokens));
  assert.ok(r.panel.top>=-.5&&r.panel.bottom<=height+.5);assert.ok(Math.abs(r.balance.height-r.gift.height)<1,'Bonus and balance differ in height');
  assert.equal(r.giftRing,0,'Native fillHeader bonus has no countdown ring');
  assert.ok(Math.abs(r.heightLimit-512*Math.min(1.5,Math.max(1,r.tabFont/12)))<1,'Native shop height limit differs from text scale');
  assert.ok(r.panel.height<=r.heightLimit+1);
  if(tab===1&&height>=480&&r.tabFont<=12.1)for(const card of r.cards)assert.ok(card.price.top>=r.frame.top-1&&card.price.bottom<=r.frame.bottom+1,`Normal screen Stars CTA clipped: ${card.id}`);
  if(tab===1&&height===844&&r.tabFont<=12.1)for(const card of r.cards)assert.ok(card.top>=r.frame.top-1&&card.bottom<=r.frame.bottom+1,`Normal screen package clipped: ${card.id}`);
  for(const hint of r.hints){const rgba=hint.color.match(/[\d.]+/g).map(Number),alpha=rgba[3]??1,bg=[13,48,71];const rgb=rgba.slice(0,3).map((v,i)=>v*alpha+bg[i]*(1-alpha));const lum=v=>v.map(x=>{x/=255;return x<=.04045?x/12.92:((x+.055)/1.055)**2.4;}).reduce((s,x,i)=>s+x*[.2126,.7152,.0722][i],0);const a=lum(rgb),b=lum(bg),ratio=(Math.max(a,b)+.05)/(Math.min(a,b)+.05);assert.ok(ratio>=4.5,`Hint contrast ${ratio.toFixed(2)}: ${hint.text}`);}
  assert.ok(r.gift.class.includes(ready?'ready':'frozen'));assert.ok(r.ad.class.includes(adReady?'ready':'frozen'));
  if(ready){assert.match(r.gift.background,/#?rgb\(255, (?:201|230|184|185|217|226|202)/,'Ready bonus is not gold');assert.ok(r.gift.text.includes('+'));}else assert.ok(/\d{1,2}:\d{2}/.test(r.gift.text),'Waiting bonus lacks timer');
  assert.equal(r.ad.display==='none',false,'Ad action disappeared');assert.ok(r.ad.width>=40&&r.ad.height>=40);
  assert.equal(r.tabs.length,4);assert.ok(r.tabs.every(t=>Math.abs(t.width-r.tabs[0].width)<1&&t.height>=40));assert.equal(r.tabs.filter(t=>t.class.includes('active')).length,1);assert.ok(r.tabs[tab].class.includes('active'));assert.equal(r.legacyLabels.length,0,'Legacy section caption retained');
  for(const f of r.fitted)assert.ok(f.leaf.width>0&&f.leaf.height>3&&f.leaf.left>=f.slot.left-1&&f.leaf.right<=f.slot.right+1&&f.leaf.top>=f.slot.top-1&&f.leaf.bottom<=f.slot.bottom+1,`Fitted value clipped: ${f.text}`);
  if(tab===1){assert.equal(r.cards.length,4);assert.ok(Math.abs(r.cards[0].top-r.cards[1].top)<1&&Math.abs(r.cards[2].top-r.cards[3].top)<1&&r.cards[2].top>r.cards[0].top,'Not2x2');r.cards.forEach((card,i)=>{const pack=config.economy.starsShop.packs[i];assert.equal(card.id,pack.id);assert.ok(card.text.includes(String(pack.crystals)));assert.ok(card.text.includes(String(pack.stars))&&card.text.includes('⭐'),'Stars price incomplete');assert.equal(card.piles,[1,3,6,10][i]);assert.ok(!card.text.includes('$')&&!card.text.includes('Бесплатно'),'Android price/test action leaked');});assert.equal(r.compact,r.availableHeight<300,'Compact breakpoint differs from actual pane height');}
}
try{
  if(!before){
    for(const rel of ['js/main.js','js/game-world.js','js/economy.js','js/renderer.js','js/telegram.js','js/adsgram.js','js/shop-catalog.js','js/strings-ru.js','js/util.js','css/neon-home.css','css/neon-windows.css','css/neon-lives.css','config/gameplay-config.json'])await check(`unchanged/${rel}`,async()=>assert.deepEqual(await fs.readFile(path.join(web,rel)),await fs.readFile(path.join(baseline,'telegram-web',rel))));
    const a=await fs.readFile(path.join(baseline,'telegram-web/js/sheets.js'),'utf8'),b=await fs.readFile(path.join(web,'js/sheets.js'),'utf8');const method=(s,name)=>s.match(new RegExp(`^  (?:async )?${name}\\([^]*?(?=^  (?:async )?[\\w$]+\\(|^})`,'m'))?.[0];
    for(const name of ['open','close','_switchCrystalsTab','_softUpdateCrystals','_bindCrystalsHeader','_refreshCrystalsHeader','_renderCrystals','_bindCrystalsPane','_renderCrystalsPane','_renderDailyPane','_watchAdForCrystals','_renderRentPane','_rent','_renderEarnPane','_renderPlus','_buyStars'])await check(`unchanged-method/${name}`,()=>{assert.ok(method(a,name),`Missing baseline method ${name}`);assert.equal(method(b,name),method(a,name));});
  }
  if(!before)await check('sheets/only-three-render-methods-changed',async()=>{
    let oldSource=await fs.readFile(path.join(baseline,'telegram-web/js/sheets.js'),'utf8');
    let newSource=await fs.readFile(path.join(web,'js/sheets.js'),'utf8');
    for(const name of ['_renderCrystalsHeader','_renderCrystalsTabs','_renderShopPane']){
      const pattern=new RegExp(`^  (?:async )?${name}\\([^]*?(?=^  (?:async )?[\\w$]+\\(|^})`,'m');
      assert.ok(oldSource.match(pattern)&&newSource.match(pattern),`Missing allowed UI method ${name}`);
      newSource=newSource.replace(pattern,()=>oldSource.match(pattern)[0]);
    }
    assert.equal(newSource,oldSource);
  });
  const scenarios=[{tokens:0,ready:true,adReady:true},{tokens:999,ready:false,adReady:false},{tokens:999,ready:true,adReady:false},{tokens:99999999,ready:false,adReady:true}];
  if(!targeted)for(const width of [320,360,390,430])for(const height of [480,560,844]){
    const page=await newPage({width,height});try{for(const light of [false,true])for(const scenario of scenarios){await openShop(page,{...scenario,light});const name=`${width}x${height}-${light?'light':'dark'}-${scenario.tokens}-${scenario.ready?'ready':'wait'}-ad${scenario.adReady?'ready':'wait'}`;await page.screenshot({path:path.join(output,`${name}.png`)});if(!before)await check(name,async()=>{const r=await audit(page);accept(r,{width,height,...scenario});return r;});}}finally{await page.close();}
  }
  if(!before){
    for(const width of [320,360,390,430])for(const light of [false,true]){
      const page=await newPage({width,height:560});try{await openShop(page,{light,tab:1});for(const tab of [0,1,2,3])await check(`tabs/${width}/${light}/${tab}`,async()=>{await page.locator(`[data-tab="${tab}"]`).tap();await page.waitForTimeout(90);const r=await audit(page);accept(r,{width,height:560,tokens:999,ready:true,adReady:true,tab});assert.equal(await page.evaluate(()=>window.app.sheets._tab),tab);if(width===390)await page.screenshot({path:path.join(output,`tab-${tab}-${light?'light':'dark'}.png`)});return r.tabs;});}finally{await page.close();}
    }
    for(const[width,height]of [[320,480],[390,844],[430,560]])for(const light of [false,true])for(const ready of [false,true])await check(`text200/${width}x${height}/${light}/${ready}`,async()=>{const page=await newPage({width,height});try{await openShop(page,{tokens:99999999,ready,adReady:!ready,light,font:2});const r=await audit(page);accept(r,{width,height,tokens:99999999,ready,adReady:!ready});await page.screenshot({path:path.join(output,`font200-${width}x${height}-${light?'light':'dark'}-${ready?'ready':'wait'}.png`)});await page.locator('[data-iap="pack_xl"]').scrollIntoViewIfNeeded();const c=await page.locator('[data-iap="pack_xl"]').boundingBox();assert.ok(c.y>=r.panel.top&&c.y+c.height<=r.panel.bottom+1,'Last package unreachable');return r;}finally{await page.close();}});
    for(const[width,height]of [[320,460],[844,390]])await check(`safe/${width}x${height}`,async()=>{const page=await newPage({width,height,safe:true});try{await openShop(page);const r=await audit(page);accept(r,{width,height,tokens:999,ready:true,adReady:true});assert.ok(r.panel.top>=127.5&&r.panel.bottom<=height+.5&&r.frame.bottom<=height-23.5,JSON.stringify({panel:r.panel,frame:r.frame}));await page.screenshot({path:path.join(output,`safe-${width}x${height}.png`)});await page.locator('[data-iap="pack_xl"] .neon-shop-pack-price').scrollIntoViewIfNeeded();const price=await page.locator('[data-iap="pack_xl"] .neon-shop-pack-price').boundingBox();assert.ok(price.y>=r.frame.top-1&&price.y+price.height<=r.frame.bottom+1,'Safe/landscape last Stars price unreachable');return r.panel;}finally{await page.close();}});
    await check('bonus/exact-once-ready-to-wait',async()=>{const page=await newPage();try{await openShop(page,{tokens:0,ready:true});await page.locator('#gift-btn').tap();await page.waitForTimeout(120);const r=await page.evaluate(()=>({tokens:window.app.economy.tokens,ready:window.app.economy.canClaimTimedBonus,display:document.getElementById('gift-btn').innerText}));assert.equal(r.tokens,config.economy.timedBonusTokens);assert.equal(r.ready,false);await page.locator('#gift-btn').tap();assert.equal(await page.evaluate(()=>window.app.economy.tokens),r.tokens);return r;}finally{await page.close();}});
    for(const status of ['cancelled','failed','invoice-error','paid'])for(const pack of (status==='paid'?config.economy.starsShop.packs:[config.economy.starsShop.packs[0]]))await check(`stars/${status}/${pack.id}`,async()=>{const page=await newPage({payment:status});try{await openShop(page,{tokens:0});await page.locator(`[data-iap="${pack.id}"]`).tap();if(status==='paid')await page.locator(`[data-iap="${pack.id}"]`).tap();await page.waitForFunction(()=>!window.app.sheets._buyingStars);await page.waitForTimeout(100);const r=await page.evaluate(()=>({tokens:window.app.economy.tokens,applied:window.app.economy.appliedStarsTokens,opens:window.__invoiceOpens,phase:window.app.phase}));assert.equal(r.tokens,status==='paid'?pack.crystals:0);assert.equal(r.phase,'idle');const state=wallets.get(page.fixtureCaseId);assert.equal(state.invoices,1);assert.equal(state.credits,status==='paid'?1:0);assert.equal(r.opens,status==='invoice-error'?0:1);if(status==='paid'){await page.evaluate(()=>window.app.economy.syncWallet());assert.equal(await page.evaluate(()=>window.app.economy.tokens),pack.crystals);}return{...r,...state};}finally{await page.close();}});
    await check('fit/updates-lifecycle-no-feedback',async()=>{const page=await newPage();try{await openShop(page);await page.evaluate(()=>{window.app.sheets._stopTick();window.app.economy.tokens=99999999;window.app.sheets._softUpdateCrystals();});await page.waitForTimeout(90);accept(await audit(page),{width:390,height:844,tokens:99999999,ready:true,adReady:true});const stableBefore=await page.evaluate(()=>window.__observerLog.map(x=>({kind:x.kind,callbacks:x.callbacks,targets:x.targets.length})));await page.waitForTimeout(250);const stableAfter=await page.evaluate(()=>window.__observerLog.map(x=>({kind:x.kind,callbacks:x.callbacks,targets:x.targets.length})));assert.ok(stableAfter.reduce((s,x)=>s+x.callbacks,0)-stableBefore.reduce((s,x)=>s+x.callbacks,0)<5,'Observer style feedback loop');await page.evaluate(()=>window.app.sheets.close());await page.waitForTimeout(260);const closed=await page.evaluate(()=>window.__observerLog.filter(x=>x.kind==='ResizeObserver').flatMap(x=>x.targets));assert.deepEqual(closed,[],'Active slot observer survives close');await openShop(page,{tokens:0,ready:false});const reopened=await audit(page);accept(reopened,{width:390,height:844,tokens:0,ready:false,adReady:true});await page.evaluate(()=>window.app.sheets.open('profile'));await settle(page);const profile=await page.evaluate(()=>window.__observerLog.filter(x=>x.kind==='ResizeObserver').flatMap(x=>x.targets));assert.deepEqual(profile,[],'Shop observer survives type change');return{stableBefore,stableAfter,closed,profile};}finally{await page.close();}});
  }
  if(!before)await check('fit/root-hidden-reopen-cleanup',async()=>{
    const page=await newPage();try{
      await openShop(page);
      const active=await page.evaluate(()=>window.__observerLog.filter(x=>x.kind==='ResizeObserver').flatMap(x=>x.targets));assert.ok(active.length>4);
      const rafActive=await page.evaluate(()=>window.__shopRaf);assert.ok(rafActive.requests>0&&rafActive.callbacks>0&&rafActive.pending.length===0);
      await page.evaluate(()=>document.getElementById('sheet-root').hidden=true);await page.waitForTimeout(90);
      const hidden=await page.evaluate(()=>window.__observerLog.filter(x=>x.kind==='ResizeObserver'||x.seenTargets.includes('sheet-body')).map(x=>({kind:x.kind,targets:x.targets})));assert.ok(hidden.every(x=>x.targets.length===0),'Scoped observation retained while hidden');
      const rafHidden=await page.evaluate(()=>window.__shopRaf);assert.deepEqual(rafHidden.pending,[]);
      await page.evaluate(()=>document.getElementById('sheet-root').hidden=false);await settle(page);
      accept(await audit(page),{width:390,height:844,tokens:999,ready:true,adReady:true});
      const resumed=await page.evaluate(()=>window.__observerLog.filter(x=>x.kind==='ResizeObserver').flatMap(x=>x.targets));assert.ok(resumed.length>4);
      const rafResumed=await page.evaluate(()=>window.__shopRaf);assert.ok(rafResumed.callbacks>rafActive.callbacks&&rafResumed.pending.length===0);
      await page.evaluate(()=>window.app.sheets.close());await page.waitForTimeout(260);const rafClosed=await page.evaluate(()=>window.__shopRaf);assert.deepEqual(rafClosed.pending,[]);return{active,hidden,resumed,rafActive,rafHidden,rafResumed,rafClosed};
    }finally{await page.close();}
  });
  await check('no-page-errors',()=>assert.deepEqual(errors,[]));await check('no-missing-assets',()=>assert.deepEqual(missing,[]));
  const checked=before?[]:await sourceHashes();if(!before)await check('source-frozen-during-run',()=>assert.deepEqual(checked,initialHashes));
  await fs.writeFile(path.join(output,'verification.json'),JSON.stringify({date:new Date().toISOString(),kind:'Isolated Chromium fixtures; real touch events; synthetic font200; no live Telegram/payment/device',before,targeted,cases,failures,errors,missing,blockedExternal:blocked,fixtureApi:api,initialSourceHashes:initialHashes,checkedSourceHashes:checked},null,2));
  console.log(JSON.stringify({pass:cases.filter(x=>x.status==='PASS').length,failed:failures.length,failures:failures.slice(0,16),output},null,2));if(failures.length)process.exitCode=1;
}finally{await browser.close();await new Promise(r=>server.close(r));}
