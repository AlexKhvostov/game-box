import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';

const project=path.resolve(import.meta.dirname,'..');
const web=path.resolve(process.env.UNTOUCH_WEB_ROOT||path.join(project,'telegram-web'));
const baseline=path.join(project,'tmp/telegram-neon-result-20261014/baseline');
const before=process.argv.includes('--baseline');
const only=process.argv.find(x=>x.startsWith('--only='))?.slice(7);
const fitOnly=process.argv.includes('--fit-only');
const targeted=process.argv.includes('--targeted')||fitOnly;
const output=path.join(project,'docs/release-evidence/telegram-neon-result-20261014',before?'before':fitOnly?'after-lifecycle':targeted?'after-targeted':'after');
await fs.mkdir(output,{recursive:true});
const config=JSON.parse(await fs.readFile(path.join(baseline,'telegram-web/config/gameplay-config.json'),'utf8'));
const modules=process.env.UNTOUCH_BROWSER_MODULES||'C:/Users/alexe/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const {chromium}=await import(pathToFileURL(path.join(modules,'playwright/index.mjs')));
const {PNG}=(await import(pathToFileURL(path.join(modules,'pngjs/lib/png.js')))).default;
const fixtureClockAnchor=Date.parse('2026-10-13T09:00:00Z'),fixtureClockStart=Date.now();
const fixtureNow=()=>fixtureClockAnchor+Date.now()-fixtureClockStart;
const cases=[],failures=[],errors=[],missing=[],blocked=[],api=[],wallets=new Map();let serial=0;
const check=async(name,fn)=>{if(only&&!name.includes(only)&&!/^no-|source-/.test(name))return;if(fitOnly&&!/^(?:unchanged|sheets\/|fit\/|no-|source-)/.test(name))return;try{const value=await fn();cases.push({name,status:'PASS',value});}catch(e){failures.push({name,error:e.message});cases.push({name,status:'FAIL',error:e.message});}};
const sourceEntries=JSON.parse(await fs.readFile(path.join(baseline,'source-hashes.json'),'utf8'));
const sourceFiles=[...sourceEntries.map(x=>x.path),'telegram-web/css/neon-result.css','telegram-web/js/neon-result-fit.js','telegram-web/css/neon-share.css'];
async function sourceHashes(){const list=[];for(const rel of sourceFiles){try{list.push({path:rel,sha256:crypto.createHash('sha256').update(await fs.readFile(rel.startsWith('telegram-web/')?path.join(web,rel.slice(13)):path.join(project,rel))).digest('hex')});}catch{}}return list;}
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
    window.__uiRafByModule={shop:{requests:0,callbacks:0,pending:[]},services:{requests:0,callbacks:0,pending:[]},result:{requests:0,callbacks:0,pending:[]}};
    const nativeRAF=window.requestAnimationFrame.bind(window),nativeCancelRAF=window.cancelAnimationFrame.bind(window);
    window.requestAnimationFrame=callback=>{
      const stack=new Error().stack;if(!/\/js\/neon-(?:shop-fit|services-layout|result-fit)\.js/.test(stack))return nativeRAF(callback);
      const own=window.__uiRafByModule[stack.includes('neon-result-fit')?'result':stack.includes('neon-services-layout')?'services':'shop'];own.requests++;
      const log=window.__shopRaf;log.requests++;const id=nativeRAF(time=>{own.pending=own.pending.filter(x=>x!==id);own.callbacks++;log.pending=log.pending.filter(x=>x!==id);log.callbacks++;callback(time);});own.pending.push(id);log.pending.push(id);return id;
    };
    window.cancelAnimationFrame=id=>{const log=window.__shopRaf;if(log.pending.includes(id)){log.pending=log.pending.filter(x=>x!==id);log.cancelled++;}for(const own of Object.values(window.__uiRafByModule))own.pending=own.pending.filter(x=>x!==id);nativeCancelRAF(id);};
    for(const kind of ['MutationObserver','ResizeObserver']){
      const Native=window[kind];if(!Native)continue;
      window[kind]=class extends Native{
        constructor(callback){const record={kind,targets:[],seenTargets:[],callbacks:0,disconnects:0};super((...args)=>{record.callbacks++;callback(...args);});this.__record=record;window.__observerLog.push(record);}
        observe(target,options){const label=target.id||target.className||target.nodeName;this.__record.options=options||null;if(!this.__record.targets.includes(label))this.__record.targets.push(label);if(!this.__record.seenTargets.includes(label))this.__record.seenTargets.push(label);return super.observe(target,options);}
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
  await page.goto(origin);await page.locator('#boot-loader').waitFor({state:'hidden'});await page.evaluate(()=>{window.app._tick=()=>{};window.__toasts=[];window.app.showToast=(text,options)=>window.__toasts.push({text,options}); window.__fixtureTick=window.app._tick; window.__canvasDrawLog=[]; window.__canvasTextLog=[];});page.fixtureCaseId=caseId;return page;
}
async function settle(page){await page.locator('#sheet-panel').waitFor({state:'visible'});await page.waitForTimeout(40);await page.locator('#sheet-panel').evaluate(async el=>Promise.all(el.getAnimations().filter(a=>a.effect?.getTiming().iterations!==Infinity).map(a=>a.finished.catch(()=>{}))));await page.waitForTimeout(40);}

const scenarios={ordinary:{ms:21349,run:435,risk:8,old:30000,day:25000},record:{ms:21349,run:435,risk:8,old:19000,day:18000},day:{ms:21349,run:435,risk:8,old:30000,day:18000},first:{ms:21349,run:435,risk:8,old:0,day:0},zero:{ms:0,run:0,risk:0,old:30000,day:0},large:{ms:999999999,run:99999999,risk:999999,old:999999998,day:0}};
async function setupCanvasInstrumentation(page){
  await page.evaluate(async()=>{
    const {telegram}=await import('./js/telegram.js?v=v1.0.22_20261003_233329_134');window.__shareCalls=[];telegram.share=async(text,url,blob)=>{window.__shareCalls.push({text,url,type:blob?.type,size:blob?.size});return true;};
    const proto=CanvasRenderingContext2D.prototype;
    for(const name of ['clearRect','drawImage','fillText']){const original=proto[name];proto[name]=function(...args){if(this.canvas.id==='share-card-canvas'){if(name==='drawImage'&&args[0]?.src.includes('run-scene-v1.png'))window.__shareSceneSource=args[0];if(name==='fillText')window.__canvasTextLog.push({text:args[0],x:args[1],y:args[2],max:args[3]??null,font:this.font,width:this.measureText(args[0]).width});else window.__canvasDrawLog.push({name,args:name==='drawImage'?[args[0]?.src,...args.slice(1)]:args});}return original.apply(this,args);};}
  });
}
async function finishFixture(page,{state='ordinary',light=false,font=1}={}){
  await page.evaluate(({values,light})=>{
    const app=window.app,e=app.economy;
    e.tokens=15;e.lives=8;e.bestTimeMs=values.old;e.recentAttempts=values.day?[{id:'fixture-before',timeMs:values.day,createdAt:Date.now(),scoreDay:new Date().toLocaleDateString('en-CA'),autoSaved:true,isMe:true}]:[];
    e.communityScores=[];e.lightTheme=light;document.documentElement.dataset.theme=light?'light':'dark';
    app.aliveMs=values.ms;app.world.playerDistance=values.run*app.world.playerSize*.1;app.world.nearMissCount=values.risk;
    const original=e.finishRun.bind(e);window.__finishCalls=0;e.finishRun=(...args)=>{window.__finishCalls++;return original(...args);};app._finishImpact();
    window.__resultSnapshot={tokens:e.tokens,lives:e.lives,attempts:JSON.stringify(e.recentAttempts),rounds:e.sessionCompletedRounds,values:{timeMs:app.resultMs,run:app.resultRun,risk:app.resultRisk,score:app.resultScore},result:structuredClone(app.lastRunResult)};
  },{values:scenarios[state],light});
  const model=await page.evaluate(()=>window.__resultSnapshot);assert.equal(model.values.timeMs,scenarios[state].ms);assert.equal(model.values.run,scenarios[state].run);assert.equal(model.values.risk,scenarios[state].risk);
  const ec=config.economy,earned=Math.floor(scenarios[state].risk/Math.max(1,ec.riskRewardEvery))*Math.max(0,ec.riskRewardTokens)+Math.floor(scenarios[state].run/Math.max(1,ec.runRewardEvery))*Math.max(0,ec.runRewardTokens);assert.equal(model.tokens,15+earned);
  await page.addStyleTag({content:'#fly-toast-root{display:none!important}'}); await page.waitForTimeout(350);
  if(font!==1)await page.locator('#result-overlay').evaluate((root,font)=>{const sizes=[...root.querySelectorAll('*')].filter(el=>[...el.childNodes].some(n=>n.nodeType===3&&n.textContent.trim())).map(el=>[el,parseFloat(getComputedStyle(el).fontSize)*font]);for(const[el,size]of sizes)el.style.fontSize=`${size}px`;},font);
  await page.waitForTimeout(80);
}
async function assertModelSame(page){const r=await page.evaluate(()=>{const e=window.app.economy,s=window.__resultSnapshot;return{calls:window.__finishCalls,tokens:e.tokens,lives:e.lives,attempts:JSON.stringify(e.recentAttempts),rounds:e.sessionCompletedRounds,expected:s};});assert.equal(r.calls,1);for(const key of ['tokens','lives','attempts','rounds'])assert.equal(r[key],r.expected[key],key);return r;}
async function openShare(page,{font=1}={}){await page.locator('#result-share-social').scrollIntoViewIfNeeded();await page.locator('#result-share-social').tap();await settle(page);if(font!==1)await page.locator('.share-sheet').evaluate((root,font)=>{const sizes=[...root.querySelectorAll('*')].filter(el=>[...el.childNodes].some(n=>n.nodeType===3&&n.textContent.trim())).map(el=>[el,parseFloat(getComputedStyle(el).fontSize)*font]);for(const[el,size]of sizes)el.style.fontSize=`${size}px`;},font);await page.waitForTimeout(120);}
async function reach(page,selector,{safe=false,frame=null}={}){const target=page.locator(selector);await target.scrollIntoViewIfNeeded();const bounds=await target.boundingBox();assert.ok(bounds&&bounds.width>0&&bounds.height>0,`${selector} invisible`);const view=frame?await page.locator(frame).boundingBox():{x:0,y:safe?112:0,width:page.viewportSize().width,height:page.viewportSize().height-(safe?136:0)};assert.ok(bounds.y>=view.y-1&&bounds.y+bounds.height<=view.y+view.height+1,`${selector} outside safe viewport ${JSON.stringify({bounds,view})}`);return bounds;}
async function reachResultValues(page,safe=false){const inner=await page.locator('.result-scroll').evaluate(el=>getComputedStyle(el).overflowY==='auto');for(const id of ['result-time','result-score','result-risk','result-run','result-best'])await reach(page,`#${id}`,{safe,frame:inner?'.result-scroll':'.result-viewport'});}
async function dragTouch(page,x,y,distance){const cdp=await page.context().newCDPSession(page);try{await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,radiusX:1,radiusY:1}]});for(let i=1;i<=5;i++){await page.waitForTimeout(25);await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y+distance*i/5,radiusX:1,radiusY:1}]});}await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}finally{await cdp.detach();}}
async function resultAudit(page){return page.evaluate(()=>{
  const root=document.getElementById('result-overlay'),card=root.querySelector('.result-card'),rect=el=>{const r=el.getBoundingClientRect();return{left:r.left,right:r.right,top:r.top,bottom:r.bottom,width:r.width,height:r.height};};
  const ids=['result-time','result-score','result-risk','result-run','result-rank','result-risk-earn','result-run-earn','result-best'];
  const values=Object.fromEntries(ids.map(id=>{const el=document.getElementById(id);return[id,el?{text:el.textContent,hidden:el.hidden,display:getComputedStyle(el).display,rect:rect(el),color:getComputedStyle(el).color}:null];}));
  const fit=[...root.querySelectorAll('[data-result-fit]')].map(el=>({slot:rect(el),leaf:rect(el.firstElementChild),text:el.textContent,hidden:el.hidden}));
  return{card:rect(card),background:getComputedStyle(card).backgroundColor,border:getComputedStyle(card).borderRadius,values,fit,overflow:document.documentElement.scrollWidth>innerWidth,scene:root.querySelector('.result-scene')?{src:root.querySelector('.result-scene').src,fit:getComputedStyle(root.querySelector('.result-scene')).objectFit}:null,snapshot:window.__resultSnapshot};
});}
function acceptResult(r,state){assert.equal(r.overflow,false);const v=r.snapshot.values;assert.equal(r.values['result-time'].text,(v.timeMs/1000).toFixed(3));assert.equal(r.values['result-risk'].text,String(v.risk));assert.equal(r.values['result-run'].text,String(v.run));assert.match(r.values['result-score'].text,/\d/);assert.ok(r.card.width<=358+3,'Native max width358');assert.equal(r.border,'18px');assert.equal(r.background,'rgb(6, 27, 43)');assert.ok(r.scene?.src.includes('result-scene-v1.png'),'Missing canonical scene');for(const f of r.fit.filter(x=>!x.hidden)){assert.ok(f.leaf.left>=f.slot.left-1&&f.leaf.right<=f.slot.right+1&&f.leaf.top>=f.slot.top-1&&f.leaf.bottom<=f.slot.bottom+1,`fit overflow: ${JSON.stringify(f)}`);}const old=scenarios[state].old,expected=state==='record'||state==='large'?old:Math.max(old,v.timeMs);assert.ok(r.values['result-best']?.text.includes((expected/1000).toFixed(3)),`Best differs ${JSON.stringify(r.values['result-best'])}`);}
async function exportCard(page,name){await page.locator('#share-btn-download').waitFor({state:'visible'});await page.waitForFunction(()=>!document.getElementById('share-btn-download').disabled);await page.locator('#share-btn-download').scrollIntoViewIfNeeded();const promise=page.waitForEvent('download');await page.locator('#share-btn-download').tap();const download=await promise;const file=path.join(output,`${name}.png`);await download.saveAs(file);const png=PNG.sync.read(await fs.readFile(file));assert.equal(png.width,800);assert.equal(png.height,800);assert.equal(png.data[(400*800+400)*4+3],255);return{file:path.basename(file),suggestedName:download.suggestedFilename(),sha256:crypto.createHash('sha256').update(await fs.readFile(file)).digest('hex')};}
const extract=(source,name)=>source.match(new RegExp(`^  (?:async )?${name}\\([^]*?(?=^  (?:async )?[\\w$]+\\(|^})`,'m'))?.[0];
try{
  if(!before){const sources=JSON.parse(await fs.readFile(path.join(baseline,'source-hashes.json'),'utf8'));for(const f of sources.filter(x=>!['telegram-web/index.html','telegram-web/js/sheets.js','telegram-web/js/main.js','tools/build_telegram_web.ps1'].includes(x.path)))await check(`unchanged/${f.path}`,async()=>assert.equal(crypto.createHash('sha256').update(await fs.readFile(path.join(project,f.path))).digest('hex'),f.sha256));
    await check('scope/main-only-approved-ui-block',async()=>{const old=await fs.readFile(path.join(baseline,'telegram-web/js/main.js'),'utf8'),now=await fs.readFile(path.join(web,'js/main.js'),'utf8');assert.equal(now.replace(/^    \/\/ NEON_RESULT_BEST_UI_START[^]*?^    \/\/ NEON_RESULT_BEST_UI_END\r?\n/gm,''),old);});
    await check('scope/share-tail-and-invite-exact',async()=>{const old=await fs.readFile(path.join(baseline,'telegram-web/js/sheets.js'),'utf8');let now=await fs.readFile(path.join(web,'js/sheets.js'),'utf8');assert.equal(extract(now,'_renderShare').split('    const canvas =')[1],extract(old,'_renderShare').split('    const canvas =')[1]);now=now.replace(extract(now,'_renderShare'),()=>extract(old,'_renderShare'));const oldStart=old.indexOf('function drawShareCardCanvas('),oldEnd=old.indexOf('let _inviteCoverImg =',oldStart),nowStart=now.indexOf('let _shareScenePromise ='),nowEnd=now.indexOf('let _inviteCoverImg =',nowStart);assert.ok(oldStart>0&&nowStart>0);now=now.slice(0,nowStart)+old.slice(oldStart,oldEnd)+now.slice(nowEnd);assert.equal(now,old,'Only share rendering/draw/adjacent loader is allowed');});
  }
  if(!fitOnly&&!targeted)for(const [width,height] of [[320,480],[390,844],[430,560]])for(const light of [false,true])for(const state of (before?['ordinary']:Object.keys(scenarios)))await check(`layout/${width}x${height}/${light}/${state}`,async()=>{
    const page=await newPage({width,height});try{await setupCanvasInstrumentation(page);await finishFixture(page,{state,light});const r=await resultAudit(page);await page.screenshot({path:path.join(output,`${width}x${height}-${light?'light':'dark'}-${state}-result.png`)});if(!before){acceptResult(r,state);await reachResultValues(page);}for(const selector of ['#result-stat-risk','#result-stat-run','#result-share-social','#result-save','#result-ok'])await reach(page,selector);await openShare(page);await page.waitForFunction(()=>document.querySelector('#share-card-img')?.complete);await page.screenshot({path:path.join(output,`${width}x${height}-${light?'light':'dark'}-${state}-share.png`)});if(!before){await reach(page,'#share-btn-send');await reach(page,'#share-btn-download');await reach(page,'#share-btn-close');}await assertModelSame(page);return r;
    }finally{await page.close();}
  });
  if(!before&&!fitOnly){
    for(const [width,height,safe] of [[320,460,true],[844,390,true],[390,844,false]])for(const light of [false,true])for(const font of [1,2])await check(`stress/${width}x${height}/${light}/${font}`,async()=>{const page=await newPage({width,height,safe});try{await setupCanvasInstrumentation(page);await finishFixture(page,{state:'large',light,font});const r=await resultAudit(page);acceptResult(r,'large');await reachResultValues(page,safe);await page.screenshot({path:path.join(output,`stress-${width}x${height}-${light?'light':'dark'}-font${font}-result.png`)});for(const selector of ['#result-stat-risk','#result-stat-run','#result-share-social','#result-save','#result-ok'])await reach(page,selector,{safe});await openShare(page,{font});for(const selector of ['#share-btn-send','#share-btn-download','#share-btn-close'])await reach(page,selector,{safe});await page.screenshot({path:path.join(output,`stress-${width}x${height}-${light?'light':'dark'}-font${font}-share.png`)});await assertModelSame(page);return r;}finally{await page.close();}});
    for(const state of ['ordinary','record','day','first','zero','large'])await check(`export/${state}`,async()=>{const page=await newPage();try{await setupCanvasInstrumentation(page);await finishFixture(page,{state});await openShare(page);const result=await exportCard(page,`export-${state}`);assert.equal(result.suggestedName,`untouch-record-${(scenarios[state].ms/1000).toFixed(2)}s.png`);const records=await page.evaluate(()=>({text:window.__canvasTextLog,draw:window.__canvasDrawLog}));assert.ok(records.text.some(x=>x.text.includes((scenarios[state].ms/1000).toFixed(2))));assert.ok(records.draw.some(x=>x.name==='drawImage'&&x.args[0].includes('run-scene-v1.png')));for(const t of records.text)assert.ok(t.width<=790||t.max&&t.max<=790,`Canvas text overflow ${JSON.stringify(t)}`);await page.locator('#share-btn-send').scrollIntoViewIfNeeded();await page.locator('#share-btn-send').tap();await page.waitForTimeout(100);const shares=await page.evaluate(()=>window.__shareCalls);assert.equal(shares.length,1);assert.ok(shares[0].text.includes((scenarios[state].ms/1000).toFixed(2)));assert.equal(shares[0].type,'image/png');assert.ok(shares[0].size>1000);await page.locator('#share-btn-close').scrollIntoViewIfNeeded();await page.locator('#share-btn-close').tap();await page.waitForTimeout(250);await page.evaluate(()=>window.app._showResult());await assertModelSame(page);return{...result,records,shares};}finally{await page.close();}});
    for(const action of ['result-ok','result-save'])await check(`action/${action}`,async()=>{const page=await newPage();try{await finishFixture(page);await page.locator(`#${action}`).scrollIntoViewIfNeeded();await page.locator(`#${action}`).tap();await page.waitForTimeout(280);assert.equal(await page.evaluate(()=>window.app.phase),'idle');assert.equal(await page.locator('#result-overlay').isVisible(),false);await assertModelSame(page);if(action==='result-save')assert.equal(await page.evaluate(()=>window.app.sheets._type),'leaderboard');}finally{await page.close();}});
    await check('action/replay-zero-lives',async()=>{const page=await newPage();try{await finishFixture(page);await page.evaluate(()=>{window.app.economy.lives=0;window.__resultSnapshot.lives=0;});await page.locator('#result-ok').scrollIntoViewIfNeeded();await page.locator('#result-ok').tap();await page.waitForTimeout(100);assert.equal(await page.evaluate(()=>window.app.phase),'idle');assert.equal(await page.locator('#get-lives-btn').isVisible(),true);await page.locator('#get-lives-btn').tap();await settle(page);assert.equal(await page.evaluate(()=>window.app.sheets._type),'lives');await assertModelSame(page);}finally{await page.close();}});
    for(const selector of ['result-stat-risk','result-stat-run'])await check(`tip/${selector}`,async()=>{const page=await newPage();try{await finishFixture(page);await page.locator(`#${selector}`).scrollIntoViewIfNeeded();await page.locator(`#${selector}`).tap();await page.waitForTimeout(100);assert.ok(await page.locator('.result-tip-pop').isVisible());assert.ok((await page.locator('#game-tip-pop-body').textContent()).length>20);const rect=await page.locator('#game-tip-pop-card').boundingBox();assert.ok(rect.y>=0&&rect.y+rect.height<=844);await page.screenshot({path:path.join(output,`tip-${selector}.png`)});await assertModelSame(page);}finally{await page.close();}});
  }
  if(!before&&!fitOnly)for(const mode of ['delayed','error','reopen','cached'])await check(`loader/${mode}`,async()=>{
    const page=await newPage();try{
      let release;const gate=new Promise(r=>release=r);let requests=0;
      await page.route('**/assets/branding/ui/run-scene-v1.png',async route=>{requests++;if(mode==='delayed'||mode==='reopen')await gate;if(mode==='error')return route.abort('failed');return route.fulfill({contentType:'image/png',body:await fs.readFile(path.join(project,'assets/branding/ui/run-scene-v1.png'))});});
      await setupCanvasInstrumentation(page);await finishFixture(page);await openShare(page);
      if(mode==='delayed'||mode==='reopen'){
        assert.equal(await page.locator('#share-btn-send').isDisabled(),true);assert.equal(await page.locator('#share-btn-download').isDisabled(),true);assert.equal(await page.locator('#share-btn-close').isEnabled(),true);
        for(const id of ['share-btn-send','share-btn-download']){await page.locator(`#${id}`).scrollIntoViewIfNeeded();const b=await page.locator(`#${id}`).boundingBox();await page.touchscreen.tap(b.x+b.width/2,b.y+b.height/2);}assert.equal(await page.evaluate(()=>window.__shareCalls.length),0);
        if(mode==='reopen'){await page.evaluate(()=>window.__oldShareCanvas=document.getElementById('share-card-canvas'));await page.locator('#share-btn-close').scrollIntoViewIfNeeded();await page.locator('#share-btn-close').tap();await page.waitForTimeout(250);await page.evaluate(()=>{window.app.resultMs=5000;window.app._showResult();});await openShare(page);assert.equal(await page.locator('#share-btn-send').isDisabled(),true);assert.equal(await page.evaluate(()=>document.getElementById('share-card-canvas')===window.__oldShareCanvas),false);}
        release();
      }
      await page.waitForFunction(()=>['ready','error'].includes(document.querySelector('#share-card-canvas')?.dataset.shareScene));assert.equal(await page.locator('#share-btn-send').isEnabled(),true);assert.equal(await page.locator('#share-btn-download').isEnabled(),true);assert.equal(await page.locator('#share-card-canvas').getAttribute('data-share-scene'),mode==='error'?'error':'ready');
      const file=await exportCard(page,`loader-${mode}`);const count=await page.evaluate(()=>window.__canvasDrawLog.length);await page.addStyleTag({content:'#fly-toast-root{display:none!important}'}); await page.waitForTimeout(350);assert.equal(await page.evaluate(()=>window.__canvasDrawLog.length),count,'Canvas repaints in a loop');
      if(mode==='cached'||mode==='error'){await page.locator('#share-btn-close').scrollIntoViewIfNeeded();await page.locator('#share-btn-close').tap();await page.waitForTimeout(250);await page.evaluate(()=>window.app._showResult());await openShare(page);await page.waitForFunction(state=>document.querySelector('#share-card-canvas')?.dataset.shareScene===state,mode==='error'?'error':'ready');assert.equal(requests,1);assert.equal(await page.locator('#share-btn-send').isEnabled(),true);}
      if(mode==='reopen'){const result=await page.evaluate(()=>({texts:window.__canvasTextLog,canvas:document.getElementById('share-card-canvas').toDataURL(),display:document.getElementById('share-card-img').src,oldConnected:window.__oldShareCanvas.isConnected}));assert.ok(result.texts.some(x=>x.text==='5.00 с'));assert.equal(result.canvas,result.display);assert.equal(result.oldConnected,false);assert.equal(file.suggestedName,'untouch-record-5.00s.png');}
      if(mode!=='error'){
        const scene=await page.evaluate(()=>{const img=window.__shareSceneSource;const a=document.getElementById('share-card-canvas').getContext('2d'),ref=document.createElement('canvas');ref.width=ref.height=800;const b=ref.getContext('2d'),scale=Math.min(792/img.naturalWidth,317/img.naturalHeight),width=img.naturalWidth*scale,height=img.naturalHeight*scale,x=4+(792-width)/2,y=180+(317-height)/2;b.drawImage(img,x,y,width,height);const samples=[];for(const fx of [.05,.25,.5,.75,.95])for(const fy of [.05,.35,.65,.95]){const px=Math.round(x+width*fx),py=Math.round(y+height*fy);samples.push({x:px,y:py,actual:[...a.getImageData(px,py,1,1).data],expected:[...b.getImageData(px,py,1,1).data]});}return{natural:[img.naturalWidth,img.naturalHeight],samples};});for(const s of scene.samples)assert.deepEqual(s.actual,s.expected,'Canonical scene cropped/changed');file.scene=scene;
      }
      await assertModelSame(page);return{...file,requests,paints:count};
    }finally{await page.close();}
  });
  if(!before)await check('fit/actual-lifecycle',async()=>{
    const page=await newPage();try{
      await finishFixture(page,{state:'large'});await page.waitForTimeout(200);const initial=await page.evaluate(()=>({raf:structuredClone(window.__uiRafByModule.result),obs:window.__observerLog.filter(x=>x.seenTargets.some(t=>String(t).includes('result')))}));assert.ok(initial.obs.some(x=>x.kind==='ResizeObserver'&&x.targets.length>0),'Result fit not observing visible values');const count=initial.raf.requests;await page.waitForTimeout(300);assert.equal(await page.evaluate(()=>window.__uiRafByModule.result.requests),count,'Result fit feedback loop');
      await page.evaluate(()=>document.getElementById('result-time').textContent='123456789.123');await page.waitForTimeout(100);assert.ok(await page.evaluate(n=>window.__uiRafByModule.result.requests>n,count),'Soft value update not fitted');await page.locator('#result-ok').scrollIntoViewIfNeeded();await page.locator('#result-ok').tap();await page.waitForTimeout(120);const closed=await page.evaluate(()=>({raf:window.__uiRafByModule.result,obs:window.__observerLog.filter(x=>x.seenTargets.some(t=>String(t).includes('result')))}));assert.deepEqual(closed.raf.pending,[]);for(const o of closed.obs.filter(x=>x.kind==='ResizeObserver'))assert.equal(o.targets.length,0);for(const o of closed.obs.filter(x=>x.kind==='MutationObserver'&&x.options?.childList))assert.equal(o.targets.length,0);
      await page.evaluate(()=>window.app._showResult());await page.waitForTimeout(100);assert.equal(await page.locator('#result-overlay').isVisible(),true);await assertModelSame(page);return{initial,closed};
    }finally{await page.close();}
  });
  if(!before)for(const height of [460,844])await check(`fit/reopen-touch-scroll/${height}`,async()=>{
    const page=await newPage({width:320,height,safe:true});try{await finishFixture(page,{state:'large',font:2});await reachResultValues(page,true);await page.locator('#result-ok').scrollIntoViewIfNeeded();await page.locator('#result-run').scrollIntoViewIfNeeded();const owners=await page.evaluate(()=>[...document.querySelectorAll('.result-viewport,.result-scroll')].map(el=>({name:el.className,top:el.scrollTop,height:el.clientHeight,scroll:el.scrollHeight,overflow:getComputedStyle(el).overflowY})));assert.ok(owners.some(x=>x.top>0));
      await page.evaluate(()=>document.getElementById('result-overlay').hidden=true);await page.waitForTimeout(80);await page.evaluate(()=>window.app._showResult());await page.waitForTimeout(100);assert.ok(await page.evaluate(()=>[...document.querySelectorAll('.result-viewport,.result-scroll')].every(el=>el.scrollTop===0)),'Entry retains scrollTop');
      const owner=height<=560?'.result-viewport':'.result-scroll',bounds=await page.locator(owner).boundingBox();await dragTouch(page,bounds.x+bounds.width/2,bounds.y+bounds.height*.7,-Math.min(110,bounds.height*.4));await page.waitForTimeout(100);assert.ok(await page.locator(owner).evaluate(el=>el.scrollTop>0),'Actual touch did not scroll');assert.equal(await page.evaluate(()=>window.app.phase),'result');assert.equal(await page.locator('#result-overlay').isVisible(),true);await assertModelSame(page);await page.screenshot({path:path.join(output,`touchscroll-${height}.png`)});return owners;
    }finally{await page.close();}
  });
  await check('no-js-errors',()=>assert.deepEqual(errors,[]));await check('no-missing-local-assets',()=>assert.deepEqual(missing,[]));const finalHashes=before?null:await sourceHashes();await check('source-frozen',()=>assert.deepEqual(finalHashes,initialHashes));await fs.writeFile(path.join(output,'verification.json'),JSON.stringify({updated:new Date().toISOString(),mode:before?'before':fitOnly?'lifecycle':'after',summary:{pass:cases.filter(x=>x.status==='PASS').length,fail:failures.length,errors:errors.length,missing:missing.length},cases,failures,errors,missing,blockedExternal:blocked,api,initialHashes,finalHashes},null,2));console.log(JSON.stringify({output,pass:cases.filter(x=>x.status==='PASS').length,fail:failures.length,failures,errors,missing},null,2));if(failures.length)process.exitCode=1;
}finally{await browser.close();await new Promise(r=>server.close(r));}

