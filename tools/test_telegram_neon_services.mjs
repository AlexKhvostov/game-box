import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';

const project=path.resolve(import.meta.dirname,'..');
const web=path.resolve(process.env.UNTOUCH_WEB_ROOT||path.join(project,'telegram-web'));
const baseline=path.join(project,'tmp/telegram-neon-services-20261013/baseline');
const before=process.argv.includes('--baseline');
const only=process.argv.find(x=>x.startsWith('--only='))?.slice(7);
const fitOnly=process.argv.includes('--fit-only');
const targeted=process.argv.includes('--targeted')||fitOnly;
const output=path.join(project,'docs/release-evidence/telegram-neon-services-20261013',before?'before':fitOnly?'after-lifecycle':targeted?'after-targeted':'after');
await fs.mkdir(output,{recursive:true});
const config=JSON.parse(await fs.readFile(path.join(baseline,'telegram-web/config/gameplay-config.json'),'utf8'));
const modules=process.env.UNTOUCH_BROWSER_MODULES||'C:/Users/alexe/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const {chromium}=await import(pathToFileURL(path.join(modules,'playwright/index.mjs')));
const {PNG}=(await import(pathToFileURL(path.join(modules,'pngjs/lib/png.js')))).default;
const fixtureClockAnchor=Date.parse('2026-10-13T09:00:00Z'),fixtureClockStart=Date.now();
const fixtureNow=()=>fixtureClockAnchor+Date.now()-fixtureClockStart;
const cases=[],failures=[],errors=[],missing=[],blocked=[],api=[],wallets=new Map();let serial=0;
const check=async(name,fn)=>{if(only&&!name.includes(only)&&!/^no-|source-/.test(name))return;if(fitOnly&&!/^(?:unchanged|sheets\/|fit\/|no-|source-)/.test(name))return;try{const value=await fn();cases.push({name,status:'PASS',value});}catch(e){failures.push({name,error:e.message});cases.push({name,status:'FAIL',error:e.message});}};
const sourceFiles=['index.html','js/sheets.js','js/main.js','js/game-world.js','js/economy.js','js/renderer.js','js/telegram.js','js/adsgram.js','js/shop-catalog.js','js/strings-ru.js','js/neon-shop-fit.js','js/neon-services-layout.js','css/neon-home.css','css/neon-windows.css','css/neon-lives.css','css/neon-shop.css','css/neon-shop-packs.css','css/neon-daily.css','css/neon-rent.css','css/neon-earn.css','css/neon-plus.css','config/gameplay-config.json'];
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
      if(url.pathname==='/api/scores.php'&&payload.action==='sync_social')data={ok:true,invited:state?.invited||[],writeAccess:state?.writeAccess||false,newlyRewarded:0,bound:false};
      if(url.pathname==='/api/scores.php'&&payload.action==='prepare_invite')data={ok:true,preparedId:'local-only-no-message'};
      if(url.pathname==='/api/scores.php'&&payload.action==='grant_write_access'){if(state)state.writeAccess=true;data={ok:true,writeAccess:true,invited:state?.invited||[]};}
      if(url.pathname==='/api/config.php')data={ok:true,config,revision:'shop-isolated-fixture'};
      if(url.pathname==='/api/payments.php'&&payload.action==='create_invoice'){
        if(!state)throw Error('Unknown fixture context');state.invoices++;
        const pack=[...config.economy.starsShop.packs,config.economy.starsShop.plus].find(p=>p.id===payload.productId);if(!pack)throw Error('Unknown fixture product');
        if(state.status==='invoice-error'){res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:false,error:'Fixture invoice refused'}));return;}
        data={ok:true,invoiceUrl:`http://127.0.0.1:${server.address().port}/invoice/${pack.id}?case=${encodeURIComponent(payload.initData)}`,crystals:pack.crystals};
      }
      if(url.pathname==='/__fixture/pay'){
        if(!state)throw Error('Unknown paid fixture');const pack=[...config.economy.starsShop.packs,config.economy.starsShop.plus].find(p=>p.id===payload.productId);
        if(!state.credited){if(pack.id===config.economy.starsShop.plus.id)state.plusUntilMs=fixtureNow()+pack.days*86400000;else state.tokens+=pack.crystals;state.credited=true;state.credits++;}
      }
      if(url.pathname==='/api/payments.php'&&payload.action==='wallet')data={ok:true,wallet:{tokens:state?.tokens||0,plusUntilMs:state?.plusUntilMs||0}};
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
async function newPage({width=390,height=844,payment=null,safe=false,social=false,share=true}={}){
  const page=await browser.newPage({viewport:{width,height},hasTouch:true,timezoneId:'Europe/Minsk'});const caseId=`fixture-${++serial}`;
  wallets.set(caseId,{status:payment,tokens:0,plusUntilMs:0,invoices:0,credits:0,credited:false,invited:[],writeAccess:false});
  page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()===404)missing.push(r.url());});
  await page.route('**/*',route=>{if(new URL(route.request().url()).origin===origin)return route.continue();blocked.push(route.request().url());return route.fulfill({contentType:'text/javascript',body:''});});
  await page.addInitScript(({payment,caseId,safe,social,share,clockAnchor})=>{
    const NativeDate=Date,installedAt=NativeDate.now();let clockOffset=0;
    window.__advanceFixtureClock=ms=>{clockOffset+=ms;};
    window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:[clockAnchor+NativeDate.now()-installedAt+clockOffset]));}static now(){return clockAnchor+NativeDate.now()-installedAt+clockOffset;}};
    localStorage.setItem('untouch_tg_economy',JSON.stringify({lives:8,tokens:payment?0:999,musicEnabled:false}));
    window.__observerLog=[];
    window.__shopRaf={requests:0,callbacks:0,cancelled:0,pending:[]};
    window.__uiRafByModule={shop:{requests:0,callbacks:0,pending:[]},services:{requests:0,callbacks:0,pending:[]}};
    const nativeRAF=window.requestAnimationFrame.bind(window),nativeCancelRAF=window.cancelAnimationFrame.bind(window);
    window.requestAnimationFrame=callback=>{
      const stack=new Error().stack;if(!/\/js\/neon-(?:shop-fit|services-layout)\.js/.test(stack))return nativeRAF(callback);
      const own=window.__uiRafByModule[stack.includes('neon-services-layout')?'services':'shop'];own.requests++;
      const log=window.__shopRaf;log.requests++;const id=nativeRAF(time=>{own.pending=own.pending.filter(x=>x!==id);own.callbacks++;log.pending=log.pending.filter(x=>x!==id);log.callbacks++;callback(time);});own.pending.push(id);log.pending.push(id);return id;
    };
    window.cancelAnimationFrame=id=>{const log=window.__shopRaf;if(log.pending.includes(id)){log.pending=log.pending.filter(x=>x!==id);log.cancelled++;}for(const own of Object.values(window.__uiRafByModule))own.pending=own.pending.filter(x=>x!==id);nativeCancelRAF(id);};
    for(const kind of ['MutationObserver','ResizeObserver']){
      const Native=window[kind];if(!Native)continue;
      window[kind]=class extends Native{
        constructor(callback){const record={kind,targets:[],seenTargets:[],callbacks:0,disconnects:0};super((...args)=>{record.callbacks++;callback(...args);});this.__record=record;window.__observerLog.push(record);}
        observe(target,options){const label=target.id||target.className||target.nodeName;if(!this.__record.targets.includes(label))this.__record.targets.push(label);if(!this.__record.seenTargets.includes(label))this.__record.seenTargets.push(label);return super.observe(target,options);}
        disconnect(){this.__record.targets=[];this.__record.disconnects++;return super.disconnect();}
        unobserve(target){this.__record.targets=this.__record.targets.filter(x=>x!==(target.id||target.className||target.nodeName));return super.unobserve(target);}
      };
    }
    if(payment||safe||social){
      window.__invoiceOpens=0;window.__stubShares=[];window.__stubWrites=0;
      const tg={initData:payment||social?caseId:'',initDataUnsafe:social?{user:{id:424242,first_name:'Изолированный игрок'}}:{},isFullscreen:true,safeAreaInset:safe?{top:24,bottom:24,left:6,right:6}:{},contentSafeAreaInset:safe?{top:88,left:10,right:10}:{},shareMessage(id,callback){window.__stubShares.push(id);setTimeout(()=>callback(share),150);},requestWriteAccess(callback){window.__stubWrites++;setTimeout(()=>callback(true),80);},ready(){},expand(){},disableVerticalSwipes(){},onEvent(){},setHeaderColor(){},setBackgroundColor(){},openInvoice(url,callback){window.__invoiceOpens++;const productId=new URL(url).pathname.split('/').at(-1);setTimeout(async()=>{if(payment==='paid')await fetch('/__fixture/pay',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({caseId,productId})});callback(payment==='invoice-error'?'failed':payment);},160);}};
      window.Telegram={WebApp:tg};
    }
  },{payment,caseId,safe,social,share,clockAnchor:fixtureNow()});
  await page.goto(origin);await page.locator('#boot-loader').waitFor({state:'hidden'});await page.evaluate(()=>{window.app._tick=()=>{};window.__toasts=[];window.app.showToast=(text,options)=>window.__toasts.push({text,options});});page.fixtureCaseId=caseId;return page;
}
async function settle(page){await page.locator('#sheet-panel').waitFor({state:'visible'});await page.waitForTimeout(40);await page.locator('#sheet-panel').evaluate(async el=>Promise.all(el.getAnimations().filter(a=>a.effect?.getTiming().iterations!==Infinity).map(a=>a.finished.catch(()=>{}))));await page.waitForTimeout(40);}

const serviceTabs={daily:0,rent:2,earn:3};
const scenarios={daily:['first','claimed3','day7','premium7','large'],rent:['poor','affordable','active','off'],earn:['locked','unlocked','done','invited'],plus:['inactive','active']};
async function openService(page,{screen='daily',state=scenarios[screen][0],light=false,font=1,large=false,tokens=999}={}){
  await page.evaluate(({screen,state,light,large,tokens,config})=>{
    const app=window.app,e=app.economy;
    document.querySelectorAll('[data-verifier-font]').forEach(el=>{el.style.fontSize=el.dataset.verifierFont;delete el.dataset.verifierFont;});
    for(const key of ['jumpRentalCost','jumpRentalHourCost','helmetRentalCost','helmetRentalHourCost','dailyRewardTokens','premiumDailyMultiplier','starsShop'])e.e[key]=structuredClone(config.economy[key]);
    app.config.game.jumpEnabled=true;app.config.game.helmetEnabled=true;
    e.tokens=state==='poor'?0:state==='affordable'?10:large?99999999:tokens;
    e.lastTimedBonusClaimMs=Date.now()-120000;e.lastWatchAdClaimMs=Date.now();
    e.plusUntilMs=state==='premium7'||screen==='plus'&&state==='active'?Date.now()+3*86400000:0;e._refreshPremiumFromUntil();
    const yesterday=new Date();yesterday.setDate(yesterday.getDate()-1);
    const older=new Date();older.setDate(older.getDate()-3);
    e.dailyStreak=state==='claimed3'?3:state==='day7'||state==='premium7'?6:state==='claimed7'||state==='continuing7'?7:0;
    e.lastDailyClaimMs=state==='claimed3'||state==='claimed7'?Date.now():state==='day7'||state==='premium7'||state==='continuing7'?yesterday.getTime():state==='reset'?older.getTime():0;
    e.jumpRentalUntil=state==='active'||state==='extension'?Date.now()+65000:0;e.helmetRentalUntil=state==='active'||state==='extension'?Date.now()+365000:0;
    if(state==='off'){app.config.game.jumpEnabled=false;app.config.game.helmetEnabled=false;}
    if(large&&screen==='rent'){e.e.jumpRentalCost=9999999;e.e.helmetRentalCost=88888888;e.e.jumpRentalHourCost=12345678;e.e.helmetRentalHourCost=99999999;}
    if(large&&screen==='daily')e.e.dailyRewardTokens=[99999,99998,99997,99996,99995,99994,99993];
    if(large&&screen==='plus')e.e.starsShop.plus.stars=99999999;
    e.claimedEarnIds=new Set(state==='done'?e.earnActions.filter(a=>a.id!=='invite_friend').map(a=>a.id):['install_bonus']);
    e.unlockedEarnIds=new Set(state==='unlocked'||state==='done'?e.earnActions.map(a=>a.id):[]);
    e.invitedFriends=state==='invited'?Array.from({length:6},(_,i)=>({name:i===0?'Очень длинное имя проверочного игрока с пробелами':`Игрок ${i+1}`,username:`@long_username_${i+1}`,photoUrl:''})):[];
    e.lightTheme=light;document.documentElement.dataset.theme=light?'light':'dark';app._updateHud();
    app.sheets.open(screen==='plus'?'plus':'crystals',{tab:{daily:0,rent:2,earn:3}[screen]??0});
  },{screen,state,light,large,tokens,config});await settle(page);
  if(font===2){await page.evaluate(()=>{
    const all=[...document.querySelectorAll('#sheet-body *')].filter(el=>[...el.childNodes].some(n=>n.nodeType===Node.TEXT_NODE&&n.textContent.trim()));
    const sizes=all.map(el=>({el,size:parseFloat(getComputedStyle(el).fontSize),old:el.style.fontSize}));
    for(const{el,size,old}of sizes){el.dataset.verifierFont=old;el.style.fontSize=`${size*2}px`;}
  });await page.waitForTimeout(120);}
}
async function audit(page,screen){return page.evaluate(screen=>{
  const rect=el=>{const r=el.getBoundingClientRect();return{left:r.left,top:r.top,right:r.right,bottom:r.bottom,width:r.width,height:r.height};};
  const style=el=>{const s=getComputedStyle(el);return{color:s.color,background:s.backgroundImage,backgroundColor:s.backgroundColor,display:s.display,opacity:s.opacity,radius:s.borderRadius,fontSize:s.fontSize};};
  const item=el=>({text:el.innerText,...rect(el),...style(el)}),panel=document.getElementById('sheet-panel');
  const root=screen==='plus'?document.querySelector('.plus-sheet'):document.querySelector(`#crystals-pane`);
  const fitted=[...document.querySelectorAll('#sheet-body [data-shop-fit]')].filter(el=>el.firstElementChild).map(el=>({text:el.textContent,slot:rect(el),leaf:rect(el.firstElementChild)}));
  const clipped=[...root.querySelectorAll('*')].filter(el=>el.children.length===0&&el.textContent.trim()&&!el.closest('[data-shop-fit]')&&el.clientWidth>0&&el.scrollWidth>el.clientWidth+1&&getComputedStyle(el).textOverflow!=='ellipsis').map(el=>({text:el.textContent,...style(el)}));
  const rows=[...document.querySelectorAll('.daily-card')].map(el=>({...item(el),class:el.className,amount:el.querySelector('.crystal-reward-amt')?.textContent,hint:el.querySelector('.crystal-plus-hint')?.textContent,claimedLabel:el.querySelector('.day-action-pill.claimed .day-action-txt')?{...rect(el.querySelector('.day-action-txt')),lineHeight:parseFloat(getComputedStyle(el.querySelector('.day-action-txt')).lineHeight)}:null,action:el.querySelector('.day-action-btn,.day-action-pill')?item(el.querySelector('.day-action-btn,.day-action-pill')):null}));
  const rent=[...document.querySelectorAll('.rent-dur-btn')].map(el=>({...item(el),class:el.className,disabled:el.disabled,ids:[...el.attributes].map(a=>a.name).filter(a=>a.startsWith('data-rent-')),cost:el.querySelector('.rd-cost')?.textContent.trim()}));
  const earn=[...document.querySelectorAll('[data-earn]')].map(el=>({...item(el),id:el.dataset.earn,class:el.className,reward:el.querySelector('.crystal-reward-amt')?.textContent}));
  const texts=[...root.querySelectorAll('.daily-hint,.earn-hint,.neon-daily-day,.daily-day-name,.day-action-txt,.rent-title,.rent-desc,.rd-action,.rd-mins,.rd-cost,.t1,.t2,.earn-invite-name,.earn-invite-status,.earn-invite-empty,.plus-desc,.plus-price-line,.plus-next-charge,.plus-benefit > span')].filter(el=>el.textContent.trim()).map(el=>{
    let node=el;const backgrounds=[];
    while(node&&node!==document.documentElement){const s=getComputedStyle(node),rgb=s.backgroundColor.match(/[\d.]+/g)?.map(Number);if(s.backgroundImage!=='none')backgrounds.push(s.backgroundImage);if(rgb?.length===3||rgb?.[3]===1){backgrounds.push(s.backgroundColor);break;}node=node.parentElement;}
    return{text:el.textContent,selector:el.className,color:getComputedStyle(el).color,backgrounds};
  });
  return{screen,panel:rect(panel),viewport:{width:innerWidth,height:innerHeight},overflow:panel.scrollWidth>panel.clientWidth+1,bodyText:root.innerText,fitted,clipped,rows,rent,earn,texts,
    plusCard:document.getElementById('daily-plus-card')?item(document.getElementById('daily-plus-card')):null,
    rentCards:[...document.querySelectorAll('.neon-rent-card')].map(item),invitePeople:[...document.querySelectorAll('.earn-invite-person')].map(item),
    inviteCard:document.querySelector('.earn-invite-card')?item(document.querySelector('.earn-invite-card')):null,
    expectedRent:[window.app.economy.e.jumpRentalCost,window.app.economy.e.jumpRentalHourCost,window.app.economy.e.helmetRentalCost,window.app.economy.e.helmetRentalHourCost],
    premium:window.app.economy.hasPremium,expectedDaily:Array.from({length:7},(_,i)=>window.app.economy.dailyTokensForStreak(i,window.app.economy.hasPremium)),
    expectedEarn:window.app.economy.earnActions.filter(a=>!['watch_ad','rate_app','social_post'].includes(a.id)).map(a=>({id:a.id,reward:a.reward,done:a.id!=='invite_friend'&&window.app.economy.isEarnClaimed(a.id),locked:a.id!=='invite_friend'&&!window.app.economy.isEarnClaimed(a.id)&&!window.app.economy.isEarnUnlocked(a.id)})),
    plusSubscribe:document.getElementById('plus-subscribe')?item(document.getElementById('plus-subscribe')):null,plusCancel:document.getElementById('plus-cancel')?item(document.getElementById('plus-cancel')):null,
    frame:screen==='plus'?rect(document.getElementById('sheet-body')):rect(document.querySelector('.crystals-content-area'))};
  },screen);}
function contrast(text){
  const color=text.color.match(/[\d.]+/g).map(Number);let background=[13,48,71];
  for(const layer of text.backgrounds){const matches=[...layer.matchAll(/rgba?\(([^)]+)\)/g)].map(x=>x[1].split(',').map(Number)).filter(v=>v.length===3||v[3]===1);if(matches.length){background=matches.at(-1).slice(0,3);break;}}
  const alpha=color[3]??1,fg=color.slice(0,3).map((n,i)=>n*alpha+background[i]*(1-alpha));
  const lum=a=>a.map(n=>{n/=255;return n<=.04045?n/12.92:((n+.055)/1.055)**2.4;}).reduce((s,n,i)=>s+n*[.2126,.7152,.0722][i],0);
  const a=lum(fg),b=lum(background);return(Math.max(a,b)+.05)/(Math.min(a,b)+.05);
}
async function reachLastAction(page,screen,safe=false){
  const selector=screen==='daily'?'.daily-row:last-child .daily-card .day-action-pill':screen==='rent'?'[data-rent-helmet-l]':screen==='earn'?'[data-earn="invite_friend"]':'#plus-subscribe';
  await page.locator(selector).scrollIntoViewIfNeeded();
  const bounds=await page.locator(selector).boundingBox();const frame=await page.evaluate(({screen,safe})=>{const el=screen==='plus'?document.getElementById('sheet-body'):document.querySelector('.crystals-content-area'),r=el.getBoundingClientRect();return{top:r.top,bottom:Math.min(r.bottom,innerHeight-(safe?24:0))};},{screen,safe});
  assert.ok(bounds.y>=frame.top-1&&bounds.y+bounds.height<=frame.bottom+1,`${screen} last action unreachable: ${JSON.stringify({bounds,frame})}`);return{bounds,frame};
}
async function dragTouch(page,x,y,distance){const cdp=await page.context().newCDPSession(page);try{await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,radiusX:1,radiusY:1}]});for(let i=1;i<=5;i++){await page.waitForTimeout(25);await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y+distance*i/5,radiusX:1,radiusY:1}]});}await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}finally{await cdp.detach();}}
async function numericInkProof(page,target,pane,pathName){
  const text=await target.textContent();assert.match(text,/^\+\d+$/);const bounds=await target.boundingBox();assert.ok(bounds.x>=pane.x-1&&bounds.x+bounds.width<=pane.x+pane.width+1);
  const color=await target.evaluate(el=>getComputedStyle(el).color.match(/[\d.]+/g).slice(0,3).map(Number));
  const data=await page.screenshot({clip:pane,path:path.join(output,pathName)}),png=PNG.sync.read(data);
  const left=Math.max(0,Math.floor(bounds.x-pane.x)),right=Math.min(png.width,Math.ceil(bounds.x+bounds.width-pane.x));
  let minY=png.height,maxY=-1,pixels=0;
  for(let y=0;y<png.height;y++)for(let x=left;x<right;x++){const pos=(y*png.width+x)*4;if(color.every((n,i)=>Math.abs(png.data[pos+i]-n)<=3)){pixels++;minY=Math.min(minY,y);maxY=Math.max(maxY,y);}}
  assert.ok(pixels>=20,`Numeric ink not detected: ${JSON.stringify({text,color,pixels})}`);assert.ok(minY>=1&&maxY<=png.height-2,`Numeric ink touches clipping edge: ${JSON.stringify({text,minY,maxY,height:png.height})}`);
  return{text,color,pixels,minY,maxY,viewportHeight:png.height,elementHeight:bounds.height,path:pathName};
}
function accept(r,{screen,state,disabled=false}){
  assert.equal(r.overflow,false);assert.deepEqual(r.clipped,[],'Unfitted text clipped horizontally');assert.ok(r.panel.top>=-.5&&r.panel.bottom<=r.viewport.height+.5);
  for(const f of r.fitted)assert.ok(f.leaf.width>0&&f.leaf.height>3&&f.leaf.left>=f.slot.left-1&&f.leaf.right<=f.slot.right+1&&f.leaf.top>=f.slot.top-1&&f.leaf.bottom<=f.slot.bottom+1,`Fitted value clipped: ${f.text}`);
  for(const text of r.texts)assert.ok(contrast(text)>=3,`Contrast ${contrast(text).toFixed(2)}: ${JSON.stringify(text)}`);
  if(screen==='daily'){
    assert.equal(r.rows.length,7);assert.ok(Math.max(...r.rows.map(x=>x.height))-Math.min(...r.rows.map(x=>x.height))<1,'Daily cards differ in height');
    r.rows.forEach((row,i)=>{assert.ok(row.text.includes(`День ${i+1}`),`Missing day ${i+1}`);assert.equal(row.amount,`+${r.expectedDaily[i]}`);assert.ok(row.action?.height>=28);assert.ok(row.action.left>=row.left-1&&row.action.right<=row.right+1);assert.match(row.hint,/×\s*2/);if(row.claimedLabel)assert.ok(row.claimedLabel.height<=row.claimedLabel.lineHeight+1,'Claimed label splits inside one word');});
    assert.ok(r.plusCard);assert.ok(r.rows[0].width<r.plusCard.width-3,'Daily cards should be narrower than Plus');
    if(state==='first')assert.ok(r.rows[0].class.includes('today'));if(state==='claimed3'){assert.equal(r.rows.filter(x=>x.class.includes('claimed')).length,3);assert.ok(r.rows[3].class.includes('waiting'));assert.match(r.rows[3].action.text,/\d{1,2}:\d{2}:\d{2}/);}
  }
  if(screen==='rent'){
    if(state==='off'){assert.equal(r.rent.length,0);assert.ok(r.bodyText.includes('недоступ'));}
    else{assert.equal(r.rent.length,4);assert.equal(r.rentCards.length,2);assert.deepEqual(r.rent.map(x=>x.cost),r.expectedRent.map(String));assert.match(r.rentCards[0].text,/Прыжок/);assert.match(r.rentCards[1].text,/Шлем/);assert.equal(r.rent.flatMap(x=>x.ids).join(','),'data-rent-jump-s,data-rent-jump-l,data-rent-helmet-s,data-rent-helmet-l');for(const button of r.rent){assert.equal(button.disabled,false,'Original insufficient toast must remain reachable');assert.ok(button.text.includes(button.cost));assert.ok(button.height>=40);if(state==='poor')assert.ok(button.class.includes('disabled'));if(state==='active'||state==='extension')assert.match(button.text,/Продлить/);}}
  }
  if(screen==='earn'){
    assert.deepEqual(r.earn.map(x=>x.id),r.expectedEarn.map(x=>x.id));assert.ok(!/5 игр|Google|код приглашения/i.test(r.bodyText));
    r.earn.forEach((row,i)=>{const expect=r.expectedEarn[i];if(expect.id==='invite_friend')assert.ok(row.text.includes('Поделиться'));else if(expect.done)assert.ok(row.class.includes('done'));else if(expect.locked)assert.ok(row.class.includes('locked'));else assert.ok(row.text.includes(String(expect.reward)));});
    assert.equal(r.invitePeople.length,state==='invited'?6:0);
    assert.ok(r.inviteCard.text.includes(`+${r.expectedEarn.find(x=>x.id==='invite_friend').reward}`),'Telegram invite reward changed');
  }
  if(screen==='plus'){
    assert.ok(r.bodyText.includes('×2'));assert.ok(r.bodyText.includes('Stars')||r.bodyText.includes('⭐'));assert.ok(!r.bodyText.includes('Google Play')&&!r.bodyText.includes('USD'));
    if(state==='active'){assert.ok(r.plusCancel&&!r.plusSubscribe);assert.ok(r.bodyText.includes('Действует до:'));}else{assert.ok(r.plusSubscribe&&!r.plusCancel);assert.ok(r.bodyText.includes('не списывает Stars'));}
  }
}
const extract=(source,name)=>source.match(new RegExp(`^  (?:async )?${name}\\([^]*?(?=^  (?:async )?[\\w$]+\\(|^})`,'m'))?.[0];
try{
  if(!before){
    const files=JSON.parse(await fs.readFile(path.join(baseline,'source-hashes.json'),'utf8'));
    for(const file of files.filter(x=>x.path.startsWith('telegram-web/')&&!['telegram-web/index.html','telegram-web/js/sheets.js'].includes(x.path)))await check(`unchanged/${file.path}`,()=>fs.readFile(path.join(project,file.path)).then(data=>assert.equal(crypto.createHash('sha256').update(data).digest('hex'),file.sha256)));
    await check('sheets/only-seven-render-methods-changed',async()=>{
      const old=await fs.readFile(path.join(baseline,'telegram-web/js/sheets.js'),'utf8');let current=await fs.readFile(path.join(web,'js/sheets.js'),'utf8');
      const tail=source=>extract(source,'_renderPlus').split("    this.body.querySelector('#plus-back')")[1];assert.ok(tail(old));assert.equal(tail(current),tail(old),'Plus action-binding tail changed');
      for(const method of ['_renderDailyPane','_renderRentPane','_rentCard','_rentDurBtn','_renderEarnPane','_renderInvitedList','_renderPlus']){assert.ok(extract(old,method)&&extract(current,method));current=current.replace(extract(current,method),()=>extract(old,method));}
      assert.equal(current,old,'Unexpected change outside seven render methods');
    });
  }
  if(!targeted)for(const[width,height]of [[320,480],[390,844],[430,560]])for(const light of [false,true]){
    const page=await newPage({width,height});try{for(const screen of ['daily','rent','earn','plus'])for(const state of scenarios[screen]){
      const params={screen,state,light,large:state==='large'},name=`${width}x${height}-${light?'light':'dark'}-${screen}-${state}`;await openService(page,params);await page.screenshot({path:path.join(output,`${name}.png`)});if(!before)await check(name,async()=>{const r=await audit(page,screen);accept(r,params);return r;});
    }}finally{await page.close();}
  }
  if(!before){
    for(const[width,height]of [[320,480],[390,844],[430,560]])for(const light of [false,true])for(const screen of ['daily','rent','earn','plus'])await check(`text200/${width}x${height}/${light}/${screen}`,async()=>{
      const page=await newPage({width,height});const params={screen,state:screen==='daily'?'claimed3':screen==='rent'?'active':screen==='earn'?'invited':'inactive',light,font:2,large:true};try{await openService(page,params);await page.screenshot({path:path.join(output,`font200-${width}x${height}-${light?'light':'dark'}-${screen}.png`)});const r=await audit(page,screen);accept(r,params);await reachLastAction(page,screen);return r;}finally{await page.close();}
    });
    for(const[width,height]of [[320,460],[844,390]])for(const screen of ['daily','rent','earn','plus'])await check(`safe/${width}x${height}/${screen}`,async()=>{
      const page=await newPage({width,height,safe:true});try{await openService(page,{screen});const r=await audit(page,screen);accept(r,{screen,state:scenarios[screen][0]});assert.ok(r.panel.top>=127.5);const selector=screen==='daily'?'.daily-row:last-child .daily-card .day-action-pill':screen==='rent'?'[data-rent-helmet-l]':screen==='earn'?'[data-earn="enable_notifications"]':'#plus-subscribe';await page.locator(selector).scrollIntoViewIfNeeded();const el=await page.locator(selector).boundingBox();await reachLastAction(page,screen,true);await page.screenshot({path:path.join(output,`safe-${width}x${height}-${screen}.png`)});return r.panel;}finally{await page.close();}
    });
    for(const light of [false,true])for(const font of [1,2])await check(`rent/landscape-safe-large/${light}/${font}`,async()=>{
      const page=await newPage({width:844,height:390,safe:true});try{
        await openService(page,{screen:'rent',state:'active',light,font,large:true});const r=await audit(page,'rent');accept(r,{screen:'rent',state:'active'});
        const header=await page.locator('#sheet-panel').evaluate(el=>parseFloat(getComputedStyle(el).getPropertyValue('--shop-header-h')));assert.equal(header,62);
        for(const target of await page.locator('.rent-dur-btn').all()){await target.scrollIntoViewIfNeeded();const bounds=await target.boundingBox();assert.ok(bounds.y>=r.frame.top-1&&bounds.y+bounds.height<=r.frame.bottom+1,'Complete landscape offer clipped');}
        await page.screenshot({path:path.join(output,`rent-landscape-safe-${light?'light':'dark'}-font${font}.png`)});
        const restored=[];for(const tab of [0,1,3]){await page.locator(`[data-tab="${tab}"]`).tap();await page.waitForTimeout(90);assert.equal(await page.locator('.neon-rent-pane').count(),0);const height=await page.locator('#sheet-panel').evaluate(el=>parseFloat(getComputedStyle(el).getPropertyValue('--shop-header-h')));assert.ok(font===2?height>90:height===62);restored.push({tab,height});}return{header,frame:r.frame,restored};
      }finally{await page.close();}
    });
    for(const light of [false,true])for(const font of [1,2])for(const state of ['first','claimed3'])await check(`daily/landscape-safefont/${light}/${font}/${state}`,async()=>{
      const page=await newPage({width:844,height:390,safe:true});try{
        await openService(page,{screen:'daily',state,light,font});const r=await audit(page,'daily');accept(r,{screen:'daily',state});
        const pane=await page.locator('.neon-daily-pane').boundingBox();const actions=[];
        for(const target of await page.locator('.day-action-btn,.day-action-pill').all()){await target.scrollIntoViewIfNeeded();const bounds=await target.boundingBox();assert.ok(bounds.y>=pane.y-1&&bounds.y+bounds.height<=pane.y+pane.height+1,'Whole Daily action clipped');actions.push(bounds);}
        await reachLastAction(page,'daily',true);
        const ink=[];for(const target of [page.locator('.daily-final-day .daily-day-name'),page.locator('.daily-final-day .crystal-reward-amt')]){await target.scrollIntoViewIfNeeded();const bounds=await target.boundingBox();if(font===2&&await target.evaluate(el=>el.classList.contains('crystal-reward-amt')))ink.push(await numericInkProof(page,target,pane,`day7-ink-${light?'light':'dark'}-font${font}-${state}.png`));else assert.ok(bounds.y>=pane.y-1&&bounds.y+bounds.height<=pane.y+pane.height+1,`Day7 label/amount clipped: ${JSON.stringify({bounds,pane,text:await target.textContent()})}`);}
        await page.screenshot({path:path.join(output,`daily-landscape-safe-${light?'light':'dark'}-font${font}-${state}.png`)});
        const viewport=await page.locator('.neon-daily-pane').evaluate(el=>({height:el.clientHeight,overflow:getComputedStyle(el).overflowY}));assert.equal(viewport.overflow,'auto');
        if(state==='first'){await page.locator('#claim-daily-btn').scrollIntoViewIfNeeded();await page.locator('#claim-daily-btn').tap();assert.equal(await page.evaluate(()=>window.app.economy.tokens),999+config.economy.dailyRewardTokens[0]);}
        const expectedTokens=state==='first'?999+config.economy.dailyRewardTokens[0]:999;
        await page.locator('#daily-plus-card').scrollIntoViewIfNeeded();await page.locator('#daily-plus-card').tap();await settle(page);assert.equal(await page.evaluate(()=>window.app.sheets._type),'plus');await page.locator('#plus-back').scrollIntoViewIfNeeded();await page.locator('#plus-back').tap();await settle(page);assert.equal(await page.evaluate(()=>window.app.sheets._type),'crystals');
        const grip=await page.locator('#sheet-panel > .sheet-handle').boundingBox();await dragTouch(page,grip.x+grip.width/2,grip.y+7.5,110);await page.waitForTimeout(260);assert.equal(await page.evaluate(()=>document.getElementById('sheet-root').hidden),true);assert.equal(await page.evaluate(()=>window.app.economy.tokens),expectedTokens);return{...viewport,actions,ink};
      }finally{await page.close();}
    });
    for(const state of ['first','day7','premium7','continuing7','reset'])await check(`daily/claim/${state}`,async()=>{
      const page=await newPage();try{await openService(page,{screen:'daily',state,tokens:0});const expected=await page.evaluate(()=>window.app.economy.dailyRewardAmount());await page.locator('#claim-daily-btn').scrollIntoViewIfNeeded();await page.locator('#claim-daily-btn').tap();await page.waitForTimeout(90);const value=await page.evaluate(()=>({tokens:window.app.economy.tokens,ready:window.app.economy.canClaimDaily,lives:window.app.economy.lives,phase:window.app.phase}));assert.equal(value.tokens,expected);assert.equal(value.ready,false);assert.equal(value.lives,8);assert.equal(value.phase,'idle');const wait=page.locator('[data-daily-wait]');if(await wait.count()){await wait.scrollIntoViewIfNeeded();await wait.tap();assert.equal(await page.evaluate(()=>window.app.economy.tokens),expected);}return value;}finally{await page.close();}
    });
    await check('daily/locked-and-wait-no-claim',async()=>{const page=await newPage();try{await openService(page,{screen:'daily',state:'claimed3',tokens:0});await page.locator('[data-daily-wait]').tap();await page.locator('[data-daily-locked]').last().scrollIntoViewIfNeeded();await page.locator('[data-daily-locked]').last().tap();assert.equal(await page.evaluate(()=>window.app.economy.tokens),0);}finally{await page.close();}});
    await check('daily/clock-progress-and-midnight-refresh',async()=>{const page=await newPage();try{await openService(page,{screen:'daily',state:'claimed3',tokens:0});const initial=await page.locator('[data-daily-timer]').textContent();await page.waitForTimeout(1200);const progressed=await page.locator('[data-daily-timer]').textContent();assert.notEqual(initial,progressed,'Countdown clock did not advance');await page.evaluate(()=>window.__advanceFixtureClock(13*3600000));await page.waitForTimeout(1100);assert.ok(await page.locator('.daily-card.today').innerText().then(x=>x.includes('День 4')));assert.equal(await page.evaluate(()=>window.app.economy.tokens),0);return{initial,progressed,newDay:await page.locator('.daily-card.today').innerText()};}finally{await page.close();}});
    await check('daily/short-large-scroll-owner-and-dismiss',async()=>{
      const page=await newPage({width:320,height:460,safe:true});try{
        await openService(page,{screen:'daily',state:'claimed3',font:2});await reachLastAction(page,'daily',true);
        const owner=await page.locator('.neon-daily-pane').evaluate(el=>({top:el.scrollTop,height:el.clientHeight,scroll:el.scrollHeight,overflow:getComputedStyle(el).overflowY}));assert.ok(owner.top>0&&owner.height>=60&&owner.scroll>owner.height,'Whole Daily scroll owner unavailable');
        const area=await page.locator('.crystals-content-area').boundingBox();await dragTouch(page,area.x+area.width/2,area.y+30,60);assert.equal(await page.evaluate(()=>window.app.sheets.isOpen),true,'Scrolled Daily drag dismissed sheet');
        await page.locator('#daily-plus-card').scrollIntoViewIfNeeded();const grip=await page.locator('#sheet-panel > .sheet-handle').boundingBox();await dragTouch(page,grip.x+grip.width/2,grip.y+7.5,110);await page.waitForTimeout(260);assert.equal(await page.evaluate(()=>document.getElementById('sheet-root').hidden),true);assert.equal(await page.evaluate(()=>window.app.economy.tokens),999);assert.equal(await page.evaluate(()=>window.app.phase),'idle');return owner;
      }finally{await page.close();}
    });
    for(const kind of ['jump','helmet'])for(const hour of [false,true])for(const extending of [false,true])await check(`rent/${kind}/${hour}/${extending}`,async()=>{
      const page=await newPage();try{await openService(page,{screen:'rent',state:extending?'extension':'rich'});const old=await page.evaluate(kind=>({tokens:window.app.economy.tokens,until:window.app.economy[`${kind}RentalUntil`]}),kind),cost=config.economy[`${kind}Rental${hour?'Hour':''}Cost`],mins=config.economy[`${kind}Rental${hour?'Hour':''}Minutes`],start=fixtureNow();const target=page.locator(`[data-rent-${kind}-${hour?'l':'s'}]`);await target.scrollIntoViewIfNeeded();await target.tap();await page.waitForTimeout(100);const value=await page.evaluate(kind=>({tokens:window.app.economy.tokens,until:window.app.economy[`${kind}RentalUntil`],phase:window.app.phase,lives:window.app.economy.lives}),kind);assert.equal(value.tokens,old.tokens-cost);assert.ok(Math.abs(value.until-(Math.max(old.until,start)+mins*60000))<1500);assert.equal(value.phase,'idle');assert.equal(value.lives,8);return value;}finally{await page.close();}
    });
    await check('rent/insufficient-does-not-spend',async()=>{const page=await newPage();try{await openService(page,{screen:'rent',state:'poor'});await page.locator('[data-rent-jump-s]').tap();assert.deepEqual(await page.evaluate(()=>({tokens:window.app.economy.tokens,until:window.app.economy.jumpRentalUntil})),{tokens:0,until:0});assert.ok(await page.evaluate(()=>window.__toasts.length>0));}finally{await page.close();}});
    for(const id of ['survive_10s','record_20s','risks_5'])for(const unlocked of [false,true])await check(`earn/claim/${id}/${unlocked}`,async()=>{
      const page=await newPage();try{await openService(page,{screen:'earn',state:unlocked?'unlocked':'locked',tokens:0});const action=page.locator(`[data-earn="${id}"]`);await action.scrollIntoViewIfNeeded();await action.tap();await page.waitForTimeout(60);const expected=unlocked?config.economy.earnActions.find(a=>a.id===id).reward:0;assert.equal(await page.evaluate(()=>window.app.economy.tokens),expected);await page.locator(`[data-earn="${id}"]`).tap();assert.equal(await page.evaluate(()=>window.app.economy.tokens),expected);return{expected};}finally{await page.close();}
    });
    for(const share of [false,true])await check(`invite/prepared-share-stub/${share}`,async()=>{
      const page=await newPage({social:true,share});try{await openService(page,{screen:'earn',tokens:0});const button=page.locator('[data-earn="invite_friend"]');await button.scrollIntoViewIfNeeded();await button.tap();await page.waitForFunction(()=>!window.app.sheets._inviteBusy);const value=await page.evaluate(()=>({tokens:window.app.economy.tokens,shares:window.__stubShares,busy:document.querySelector('.earn-share-btn').disabled,people:window.app.economy.invitedFriends.length}));assert.equal(value.tokens,0);assert.deepEqual(value.shares,['local-only-no-message']);assert.equal(value.busy,false);assert.equal(value.people,0);return value;}finally{await page.close();}
    });
    await check('notifications/stub-grant-exact-once',async()=>{const page=await newPage({social:true});try{await openService(page,{screen:'earn',tokens:0});let target=page.locator('[data-earn="enable_notifications"]');await target.scrollIntoViewIfNeeded();await target.tap();await page.waitForTimeout(130);const reward=config.economy.earnActions.find(a=>a.id==='enable_notifications').reward;assert.equal(await page.evaluate(()=>window.app.economy.tokens),reward);target=page.locator('[data-earn="enable_notifications"]');await target.tap();await page.waitForTimeout(130);assert.equal(await page.evaluate(()=>window.app.economy.tokens),reward);return{reward,stubWrites:await page.evaluate(()=>window.__stubWrites)};}finally{await page.close();}});
    for(const active of [false,true])await check(`plus/back-cancel/${active}`,async()=>{const page=await newPage();try{await openService(page,{screen:'daily',state:active?'premium7':'first'});await page.locator('#daily-plus-card').tap();await settle(page);assert.equal(await page.evaluate(()=>window.app.sheets._type),'plus');if(active){await page.locator('#plus-cancel').scrollIntoViewIfNeeded();await page.locator('#plus-cancel').tap();assert.equal(await page.evaluate(()=>window.app.economy.hasPremium),true);}await page.locator('#plus-back').scrollIntoViewIfNeeded();await page.locator('#plus-back').tap();await settle(page);assert.equal(await page.evaluate(()=>window.app.sheets._type),'crystals');assert.equal(await page.evaluate(()=>window.app.sheets._tab),0);assert.equal(await page.evaluate(()=>window.app.economy.tokens),999);}finally{await page.close();}});
    for(const status of ['cancelled','failed','invoice-error','paid'])await check(`plus/payment/${status}`,async()=>{const page=await newPage({payment:status});try{await openService(page,{screen:'plus',tokens:0});await page.locator('#plus-subscribe').scrollIntoViewIfNeeded();await page.locator('#plus-subscribe').tap();if(status==='paid')await page.locator('#plus-subscribe').tap();await page.waitForFunction(()=>!window.app.sheets._buyingStars);await page.waitForTimeout(80);const value=await page.evaluate(()=>({premium:window.app.economy.hasPremium,until:window.app.economy.plusUntilMs,tokens:window.app.economy.tokens,opens:window.__invoiceOpens})),state=wallets.get(page.fixtureCaseId);assert.equal(value.premium,status==='paid');assert.equal(value.tokens,0);assert.equal(state.invoices,1);assert.equal(state.credits,status==='paid'?1:0);assert.equal(value.opens,status==='invoice-error'?0:1);if(status==='paid'){assert.ok(Math.abs(value.until-(fixtureNow()+config.economy.starsShop.plus.days*86400000))<2000);await page.evaluate(()=>window.app.economy.syncWallet());assert.equal(await page.evaluate(()=>window.app.economy.plusUntilMs),value.until);}return value;}finally{await page.close();}});
    await check('fit/services-observers-hidden-close-type-switch',async()=>{const page=await newPage();try{await openService(page,{screen:'daily'});await page.evaluate(()=>window.app.sheets._stopTick());const initial=await page.evaluate(()=>({observers:window.__observerLog,raf:window.__shopRaf,byModule:window.__uiRafByModule}));assert.ok(initial.byModule.services.callbacks>0);await page.waitForTimeout(300);const stable=await page.evaluate(()=>window.__uiRafByModule.services.requests);assert.ok(stable-initial.byModule.services.requests<3,'Services layout feedback loop');await page.evaluate(()=>document.getElementById('sheet-root').hidden=true);await page.waitForTimeout(90);const hidden=await page.evaluate(()=>({observers:window.__observerLog.filter(x=>x.kind==='ResizeObserver'||x.seenTargets.some(t=>typeof t==='string'&&(t==='sheet-body'||t.includes('crystals-sheet')))),raf:window.__shopRaf,byModule:window.__uiRafByModule}));assert.ok(hidden.observers.every(x=>x.targets.length===0));assert.deepEqual(hidden.raf.pending,[]);await page.evaluate(()=>document.getElementById('sheet-root').hidden=false);await settle(page);await page.evaluate(()=>window.app.sheets.open('plus'));await settle(page);const plus=await page.evaluate(()=>window.__observerLog.filter(x=>x.kind==='ResizeObserver'||x.seenTargets.some(t=>typeof t==='string'&&(t==='sheet-body'||t.includes('crystals-sheet')))));assert.ok(plus.every(x=>x.targets.length===0));await openService(page,{screen:'rent'});await page.evaluate(()=>window.app.sheets.close());await page.waitForTimeout(260);const closed=await page.evaluate(()=>({observers:window.__observerLog.filter(x=>x.kind==='ResizeObserver'||x.seenTargets.some(t=>typeof t==='string'&&(t==='sheet-body'||t.includes('crystals-sheet')))),raf:window.__shopRaf,byModule:window.__uiRafByModule}));assert.ok(closed.observers.every(x=>x.targets.length===0));assert.deepEqual(closed.raf.pending,[]);assert.ok(Object.values(closed.byModule).every(x=>x.pending.length===0));return{initial,stable,hidden,plus,closed};}finally{await page.close();}});
  }
  await check('no-page-errors',()=>assert.deepEqual(errors,[]));await check('no-missing-assets',()=>assert.deepEqual(missing,[]));const hashes=before?[]:await sourceHashes();if(!before)await check('source-frozen-during-run',()=>assert.deepEqual(hashes,initialHashes));
  await fs.writeFile(path.join(output,'verification.json'),JSON.stringify({date:new Date().toISOString(),before,targeted,kind:'Isolated Chromium touch fixtures; synthetic font200; no live payment/message/Telegram/device',cases,failures,errors,missing,blockedExternal:blocked,fixtureApi:api,initialSourceHashes:initialHashes,checkedSourceHashes:hashes},null,2));console.log(JSON.stringify({pass:cases.filter(x=>x.status==='PASS').length,failed:failures.length,failures:failures.slice(0,20),output},null,2));if(failures.length)process.exitCode=1;
}finally{await browser.close();await new Promise(r=>server.close(r));}
