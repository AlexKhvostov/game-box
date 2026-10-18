import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';

const project=path.resolve(import.meta.dirname,'..');
const web=path.resolve(process.env.UNTOUCH_WEB_ROOT||path.join(project,'telegram-web'));
const baseline=path.join(project,'tmp/telegram-neon-windows-20261013/baseline');
const before=process.argv.includes('--baseline');
const targeted=process.argv.includes('--targeted');
const output=path.join(project,'docs/release-evidence/telegram-neon-windows-20261013',before?'before':targeted?'after-targeted':'after');
await fs.mkdir(output,{recursive:true});
const modules=process.env.UNTOUCH_BROWSER_MODULES||'C:/Users/alexe/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const {chromium}=await import(pathToFileURL(path.join(modules,'playwright/index.mjs')));
const config=JSON.parse(await fs.readFile(path.join(baseline,'telegram-web/config/gameplay-config.json'),'utf8'));
const sourceFiles=['index.html','js/sheets.js','js/neon-window-chrome.js','js/main.js','js/game-world.js','js/economy.js','js/renderer.js','js/telegram.js','css/neon-home.css','css/neon-windows.css','css/neon-lives.css','config/gameplay-config.json'];
const sourceHashes=async()=>{const list=[];for(const rel of sourceFiles)list.push({path:`telegram-web/${rel}`,sha256:crypto.createHash('sha256').update(await fs.readFile(path.join(web,rel))).digest('hex')});return list;};
const initialHashes=before?null:await sourceHashes();
const cases=[],failures=[],errors=[],missing=[],blocked=[],api=[];
const check=async(name,fn)=>{try{const value=await fn();cases.push({name,status:'PASS',value});}catch(e){failures.push({name,error:e.message});cases.push({name,status:'FAIL',error:e.message});}};
const server=http.createServer(async(req,res)=>{
  try{
    const url=new URL(req.url,'http://localhost');
    if(url.pathname.startsWith('/api/')){
      api.push({path:url.pathname,method:req.method});res.setHeader('Content-Type','application/json');
      res.end(JSON.stringify(url.pathname==='/api/config.php'?{ok:true,config,revision:'windows-fixture'}:{ok:true,scores:[],bound:false}));return;
    }
    const relative=url.pathname==='/'?'index.html':url.pathname.slice(1),file=path.resolve(web,relative);
    if(!file.startsWith(web+path.sep)){res.writeHead(403);res.end();return;}
    const candidates=[];if(before)candidates.push(path.join(baseline,'telegram-web',relative));
    if(relative.startsWith('assets/'))candidates.push(path.join(project,relative));candidates.push(file);
    let data;for(const candidate of candidates){try{data=await fs.readFile(candidate);break;}catch{}}
    if(!data)throw Error('missing');
    const types={'.js':'text/javascript','.json':'application/json','.css':'text/css','.html':'text/html','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.mp3':'audio/mpeg','.wav':'audio/wav'};
    res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');res.end(data);
  }catch{res.writeHead(404);res.end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const origin=`http://127.0.0.1:${server.address().port}`,browser=await chromium.launch({headless:true});
async function newPage(safe=false){
  const page=await browser.newPage({viewport:{width:390,height:844},hasTouch:true});
  page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()===404)missing.push(r.url());});
  await page.route('**/*',route=>{if(new URL(route.request().url()).origin===origin)return route.continue();blocked.push(route.request().url());return route.fulfill({status:200,contentType:'text/javascript',body:''});});
  await page.addInitScript(({safe})=>{
    localStorage.setItem('untouch_tg_economy',JSON.stringify({lives:999,tokens:999,musicEnabled:false,resourceAgeConfirmed:true}));
    if(safe)window.Telegram={WebApp:{initData:'',initDataUnsafe:{},isFullscreen:true,safeAreaInset:{top:24,bottom:24,left:6,right:6},contentSafeAreaInset:{top:safe==='tall-controls'?88:44,left:10,right:10},ready(){},expand(){},disableVerticalSwipes(){},onEvent(){},setHeaderColor(){},setBackgroundColor(){}}};
  },{safe});
  await page.goto(origin);await page.locator('#boot-loader').waitFor({state:'hidden'});
  await page.evaluate(()=>{window.app._tick=()=>{};window.app.showToast=()=>{};});return page;
}
async function closeSheet(page){
  await page.evaluate(()=>{const s=window.app.sheets;if(s.isOpen){if(s._type==='plus')s._returnFromPlus();s.close();}});
  await page.waitForTimeout(230);
}
async function settlePanel(page){
  await page.locator('#sheet-panel').waitFor({state:'visible'});
  await page.waitForTimeout(40);
  await page.locator('#sheet-panel').evaluate(async el=>{await Promise.all(el.getAnimations().filter(a=>a.effect?.getTiming().iterations!==Infinity).map(a=>a.finished.catch(()=>{})));});
}
async function openLives(page,{lives=999,tokens=999,light=false,font=1}={}){
  await closeSheet(page);
  await page.evaluate(({lives,tokens,light})=>{const a=window.app;a._resetToIdle();a.economy.lives=lives;a.economy.tokens=tokens;a.economy.lightTheme=light;document.documentElement.dataset.theme=light?'light':'dark';document.body.classList.toggle('theme-light',light);a._updateHud();a.sheets.open('lives');},{lives,tokens,light});
  await settlePanel(page);
  if(font===2)await page.evaluate(()=>{
    const elements=[...document.querySelectorAll('#sheet-body *')].filter(el=>[...el.childNodes].some(n=>n.nodeType===Node.TEXT_NODE&&n.textContent.trim()));
    const snapshot=elements.map(el=>({el,size:parseFloat(getComputedStyle(el).fontSize)}));
    // Text-only stress. Fitted numeric balances retain their fitted output as in
    // Android FittedBox; this is explicitly not OS/font or physical testing.
    for(const {el,size}of snapshot){if(el.matches('.lives-stat-value,.gain-number,.price-amount,.neon-lives-amount,.neon-lives-crystals-amount,#lives-balance-amount,#lives-crystal-balance-amount,.neon-lives-fit-text,[data-font-fit]'))continue;el.style.fontSize=`${size*2}px`;}
  });
  if(font===2)await page.waitForTimeout(40);
}
async function auditLives(page){return page.evaluate(()=>{
  const rect=el=>{const r=el.getBoundingClientRect();return{left:r.left,top:r.top,right:r.right,bottom:r.bottom,width:r.width,height:r.height};};
  const style=el=>{const s=getComputedStyle(el);return{background:s.backgroundColor,backgroundImage:s.backgroundImage,blur:s.backdropFilter,radius:s.borderTopLeftRadius,border:s.borderTopWidth};};
  const panel=document.getElementById('sheet-panel'),sheet=document.querySelector('.lives-sheet');
  const cards=[...document.querySelectorAll('[data-pack]')].map(btn=>{const el=btn.closest('.neon-life-pack')||btn;return{pack:Number(btn.dataset.pack),...rect(el),classes:el.className,text:el.innerText,cost:rect(el.querySelector('.neon-life-cost > span')||el.querySelector('.price-amount')),price:rect(el.querySelector('.neon-life-cost')||el.querySelector('.card-price-pill')||el.querySelector('.price-tag'))};});
  const inventory=document.querySelector('.neon-lives-inventory,.lives-stat-hearts'),currency=document.querySelector('.neon-lives-currency,.lives-stat-crystals');
  const heart=document.querySelector('.neon-lives-heart,.lives-heart-pulse');
  const texts=[...document.querySelectorAll('.lives-sheet span,.lives-sheet p,.lives-sheet h2,.lives-sheet button')].filter(el=>el.clientWidth>0);
  return{panel:rect(panel),style:style(panel),barrier:style(document.getElementById('sheet-backdrop')),sheet:rect(sheet),cards,
    overflow:panel.scrollWidth>panel.clientWidth+1,
    clipped:texts.filter(el=>!el.closest('[data-life-fit]')&&el.scrollWidth>el.clientWidth+1).map(el=>({class:el.className,text:el.textContent})),
    inventory:inventory?rect(inventory):null,currency:currency?rect(currency):null,
    lives:inventory?.innerText,tokens:currency?.innerText,
    room:getComputedStyle(panel).backgroundImage+' '+getComputedStyle(sheet).backgroundImage+' '+[...sheet.querySelectorAll('img')].map(el=>el.src).join(' '),
    heart:heart?{animation:getComputedStyle(heart).animationName,state:getComputedStyle(heart).animationPlayState}:null,
    numericLines:['lives-balance-amount','lives-crystal-balance-amount'].map(id=>{const el=document.getElementById(id);if(!el)return{id,lines:0};const range=document.createRange();range.selectNodeContents(el.firstElementChild||el);return{id,lines:range.getClientRects().length,rect:rect(el),ink:range.getBoundingClientRect().toJSON()};}),
    fitted:[...document.querySelectorAll('[data-life-fit]')].map(el=>({slot:rect(el),ink:el.firstElementChild.getBoundingClientRect().toJSON(),text:el.textContent})),
    hiddenButtons:[...document.querySelectorAll('.lives-sheet button')].filter(el=>getComputedStyle(el).display==='none').map(el=>el.id||el.className)};
});}
async function swipe(page,x,y,delta){const cdp=await page.context().newCDPSession(page);try{await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});for(let n=1;n<=6;n++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y+delta*n/6}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await page.waitForTimeout(250);}finally{await cdp.detach();}}
try{
  if(!before){
    for(const rel of ['js/main.js','js/game-world.js','js/economy.js','js/renderer.js','js/telegram.js','js/adsgram.js','css/neon-home.css','config/gameplay-config.json'])await check(`unchanged/${rel}`,async()=>assert.deepEqual(await fs.readFile(path.join(web,rel)),await fs.readFile(path.join(baseline,'telegram-web',rel))));
    const a=await fs.readFile(path.join(baseline,'telegram-web/js/sheets.js'),'utf8'),b=await fs.readFile(path.join(web,'js/sheets.js'),'utf8');
    const extract=(source,name)=>source.match(new RegExp(`^  ${name}\\([^]*?(?=^  [\\w$]+\\(|^})`,'m'))?.[0];
    for(const name of ['_bindDismissGesture','_resetDismissGesture','open','close','_setPanelMode','_openPlusSheet','_returnFromPlus','_openCrystalsShop'])await check(`unchanged-sheets/${name}`,()=>{let actual=extract(b,name);if(name==='_setPanelMode'){actual=actual.replace(/^    this\.root\?\.classList\.toggle\('sheet-lives-dialog', type === 'lives'\);\r?\n/m,'').replace(/^    if \(type !== 'lives'\) this\._livesFitObserver\?\.disconnect\(\);\r?\n/m,'');}if(name==='close'){actual=actual.replace(/^    (?:if \(this\._type === 'lives'\) )?this\._livesFitObserver\?\.disconnect\(\);\r?\n/m,'').replace(/^    this\._livesFitObserver = null;\r?\n/m,'');}if(name==='_openCrystalsShop'){actual=actual.replace("    this._setPanelMode('crystals');","    this.panel?.classList.remove('sheet-lives', 'sheet-leaderboard');\r\n    this.panel?.classList.add('sheet-crystals');");}assert.equal(actual,extract(a,name));});
    await check('unchanged-buy-handlers',()=>{const handlers=source=>extract(source,'_renderLives').match(/        const pack = packs\[Number\(btn\.dataset\.pack\)\];[^]*?          this\._openCrystalsShop\(\);\r?\n        \}\r?\n      \}\);/)?.[0];assert.ok(handlers(a));assert.equal(handlers(b),handlers(a));});
  }
  const page=await newPage();
  const wallets=[{lives:0,tokens:0},{lives:0,tokens:1},{lives:999,tokens:10},{lives:999,tokens:49},{lives:999,tokens:999},{lives:999999,tokens:99999999}];
  if(!targeted)for(const width of [320,360,390,430])for(const height of [480,560,844]){
    await page.setViewportSize({width,height});
    for(const light of [false,true])for(const wallet of wallets)for(const font of [1,2]){
      if(before&&font===2)continue;
      await openLives(page,{...wallet,light,font});
      const name=`${width}x${height}-${light?'light':'dark'}-L${wallet.lives}-C${wallet.tokens}-font${font}`;
      if(font===1||wallet.tokens===999)await page.screenshot({path:path.join(output,`${name}.png`)});
      if(before)continue;
      await check(name,async()=>{
        const r=await auditLives(page);
        assert.equal(r.overflow,false,'Panel horizontal overflow');assert.deepEqual(r.clipped,[],'Text clipped horizontally');
        assert.ok(r.panel.left>=-.5&&r.panel.right<=width+.5&&r.panel.top>=-.5&&r.panel.bottom<=height+.5,'Panel outside viewport');
        assert.equal(r.style.radius,'18px');assert.equal(r.style.border,'2px');assert.equal(r.barrier.blur,'none');assert.match(r.barrier.background,/rgba\(6, 27, 45, 0\.72/);
        assert.equal(r.cards.length,4);assert.ok(Math.abs(r.cards[0].top-r.cards[1].top)<1&&Math.abs(r.cards[2].top-r.cards[3].top)<1&&r.cards[2].top>r.cards[0].top,'Packs not 2x2');
        assert.ok(r.room.includes('lives-room-v2.png'),'Canonical room-v2 missing');assert.ok(r.inventory&&r.currency,'Separate inventory/currency missing');
        assert.ok(r.inventory.height>r.inventory.width,'Life card must be vertical');assert.ok(r.inventory.width>=80&&r.inventory.width<=114,'Inventory not Android29% clamped84..112');
        assert.ok(r.currency.top>=r.inventory.bottom-1,'Currency not below hero inventory');assert.ok(r.lives.includes(String(wallet.lives)));assert.ok(r.tokens.includes(String(wallet.tokens)));
        assert.ok(r.numericLines.every(value=>value.lines===1),'Balance number wraps instead of Android FittedBox single line');
        for(const value of r.numericLines){const owner=value.id==='lives-balance-amount'?r.inventory:r.currency;assert.ok(value.ink.bottom<=owner.bottom-2&&value.ink.top>=owner.top+2,'Numeric ink clips vertically inside balance card');}
        for(const value of r.fitted)assert.ok(value.ink.width>1&&value.ink.height>3&&value.ink.left>=value.slot.left-1&&value.ink.right<=value.slot.right+1&&value.ink.top>=value.slot.top-1&&value.ink.bottom<=value.slot.bottom+1,`Fitted text missing or clipped: ${value.text}`);
        const packs=config.economy.lifePacks;
        r.cards.forEach((card,i)=>{const can=wallet.tokens>=packs[i].costTokens;assert.ok(card.text.includes(`+${packs[i].lives}`));assert.ok(card.text.includes(String(packs[i].costTokens)));assert.ok(card.text.includes(can?'Обменять':'В магазин'));assert.ok(card.classes.includes(can?'can-afford':'need-more'));assert.ok(card.price.right>=card.right-15&&card.price.right<=card.right-4&&card.price.left>=card.left+4&&card.price.top<card.top+30,'Cost badge not aligned upper right');});
        assert.equal(r.hiddenButtons.length,0,'Hidden legacy action button');assert.ok(r.heart,'Dedicated heart-only animation missing');
        if(font===2){await page.locator('[data-pack="3"]').scrollIntoViewIfNeeded();const target=await page.locator('[data-pack="3"]').boundingBox();assert.ok(target.y>=r.panel.top&&target.y+target.height<=r.panel.bottom+1,'Last CTA cannot be reached by scrolling');}
        return r;
      });
    }
  }
  if(!before){
    await page.setViewportSize({width:390,height:844});
    for(const [i,pack]of config.economy.lifePacks.entries())for(const affordable of [true,false])await check(`exchange/${i}/${affordable?'exact-cost':'insufficient'}`,async()=>{
      const tokens=affordable?pack.costTokens:Math.max(0,pack.costTokens-1);await openLives(page,{lives:0,tokens});
      await page.locator(`[data-pack="${i}"]`).scrollIntoViewIfNeeded();await page.locator(`[data-pack="${i}"]`).click();await page.waitForTimeout(260);
      const result=await page.evaluate(()=>({lives:window.app.economy.lives,tokens:window.app.economy.tokens,open:window.app.sheets.isOpen,type:window.app.sheets._type,phase:window.app.phase}));
      assert.equal(result.lives,affordable?pack.lives:0);assert.equal(result.tokens,affordable?0:tokens);assert.equal(result.phase,'idle');
      if(affordable)assert.equal(result.open,false);else{assert.equal(result.type,'crystals');assert.ok(result.open);}return result;
    });
    await check('exchange/double-click-latch',async()=>{const pack=config.economy.lifePacks[0];await openLives(page,{lives:0,tokens:pack.costTokens*2});const r=await page.evaluate(()=>{const btn=document.querySelector('[data-pack="0"]');btn.click();btn.click();return{lives:window.app.economy.lives,tokens:window.app.economy.tokens};});assert.equal(r.lives,pack.lives);assert.equal(r.tokens,pack.costTokens);return r;});
    await check('heart/reduced-motion',async()=>{await openLives(page);await page.emulateMedia({reducedMotion:'reduce'});const r=await auditLives(page);assert.equal(r.heart.animation,'none');await page.emulateMedia({reducedMotion:'no-preference'});return r.heart;});
    await check('heart/synthetic-background',async()=>{await openLives(page);const r=await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'));const heart=document.querySelector('.neon-lives-heart');const background=getComputedStyle(heart).animationName;Object.defineProperty(document,'hidden',{configurable:true,get:()=>false});document.dispatchEvent(new Event('visibilitychange'));const foreground=getComputedStyle(heart).animationName;delete document.hidden;return{background,foreground};});assert.equal(r.background,'none');assert.notEqual(r.foreground,'none');return r;});
    for(const action of ['close','shop'])await check(`fitted-observer/cleanup-${action}`,async()=>{await openLives(page);const r=await page.evaluate(action=>{const sheets=window.app.sheets,observer=sheets._livesFitObserver;if(!observer)throw Error('ResizeObserver missing');let disconnected=0;const original=observer.disconnect.bind(observer);observer.disconnect=()=>{disconnected++;original();};if(action==='close')sheets.close();else sheets._openCrystalsShop();return{disconnected,type:sheets._type};},action);assert.ok(r.disconnected>=1,'Fit observer survives window close/transition');await page.waitForTimeout(240);return r;});
    for(const [width,height]of [[320,480],[390,844]])for(const light of [false,true])for(const font of [1,2])for(const type of ['crystals','profile','plus'])await check(`common-layout/${width}x${height}/${light?'light':'dark'}/font${font}/${type}`,async()=>{
      await closeSheet(page);await page.setViewportSize({width,height});await page.evaluate(({light,type})=>{window.app.economy.lightTheme=light;document.documentElement.dataset.theme=light?'light':'dark';window.app.sheets.open(type);},{light,type});await settlePanel(page);
      if(font===2)await page.evaluate(()=>{const targets=[...document.querySelectorAll('.profile-header h2,.plus-head-title,.plus-btn,.sheet-title-block h2')];const sizes=targets.map(el=>({el,size:parseFloat(getComputedStyle(el).fontSize)}));for(const{el,size}of sizes)el.style.fontSize=`${size*2}px`;});
      const audit=await page.evaluate(()=>{const panel=document.getElementById('sheet-panel'),r=panel.getBoundingClientRect();return{panel:{top:r.top,bottom:r.bottom,left:r.left,right:r.right},overflow:panel.scrollWidth>panel.clientWidth+1,headers:[...panel.querySelectorAll('.profile-header h2,.plus-head-title,.sheet-title-block h2')].map(el=>({text:el.textContent,clipped:el.scrollWidth>el.clientWidth+1})),close:(panel.querySelector('.profile-close-btn')||document.getElementById('sheet-window-close')).getBoundingClientRect().toJSON()};});
      assert.equal(audit.overflow,false);assert.ok(audit.headers.every(h=>!h.clipped),'Shared header clipped');assert.ok(audit.panel.top>=0&&audit.panel.bottom<=height+1);assert.ok(audit.close.width>=44&&audit.close.height>=44&&audit.close.right<=width+1,'Shared close target inaccessible');
      await page.screenshot({path:path.join(output,`common-${width}x${height}-${light?'light':'dark'}-font${font}-${type}.png`)});return audit;
    });
    await page.setViewportSize({width:390,height:844});
    for(const type of ['lives','crystals','leaderboard','profile','share','plus'])for(const action of ['backdrop','swipe','close'])await check(`shell/${type}/${action}`,async()=>{
      await closeSheet(page);await page.evaluate(type=>{window.app.economy.lives=999;window.app.sheets.open(type);},type);await settlePanel(page);
      await page.locator('#sheet-panel').waitFor({state:'visible'});
      const panel=await page.locator('#sheet-panel').boundingBox();const st=await page.locator('#sheet-backdrop').evaluate(el=>({bg:getComputedStyle(el).backgroundColor,blur:getComputedStyle(el).backdropFilter}));assert.match(st.bg,/rgba\(6, 27, 45, 0\.72/);assert.equal(st.blur,'none');
      const chrome=await page.locator('#sheet-panel').evaluate(el=>{const s=getComputedStyle(el),grip=getComputedStyle(el.querySelector('.sheet-handle'),'::after');return{radius:s.borderTopLeftRadius,border:s.borderTopWidth,grip:{width:grip.width,height:grip.height,content:grip.content}};});assert.equal(chrome.radius,'18px');assert.equal(chrome.border,'2px');if(type!=='lives'){assert.equal(chrome.grip.width,'28px');assert.equal(chrome.grip.height,'3px');assert.notEqual(chrome.grip.content,'none');}
      if(action==='close'){
        const selector=type==='lives'?'#lives-close':type==='profile'?'.profile-close-btn':'#sheet-window-close';
        const chrome=await page.locator('#sheet-window-close').isVisible();assert.equal(chrome,!['lives','profile'].includes(type));
        await page.screenshot({path:path.join(output,`shell-${type}-close.png`)});
        await page.locator(selector).click();
      }else if(action==='backdrop')await page.locator('#sheet-backdrop').click({position:{x:4,y:4}});else await swipe(page,195,panel.y+15,100);
      await page.waitForTimeout(260);const r=await page.evaluate(()=>({type:window.app.sheets._type,open:window.app.sheets.isOpen,lives:window.app.economy.lives,phase:window.app.phase}));assert.equal(r.lives,999);assert.equal(r.phase,'idle');if(type==='plus'){assert.equal(r.type,'crystals');assert.ok(r.open);}else assert.equal(r.open,false);return r;
    });
    await check('nested-player/barrier-close',async()=>{
      // Independent fixture context prevents unrelated earlier close callbacks
      // from clearing this case's UI after the new window has opened.
      const isolatedPage=await newPage();
      const page=isolatedPage;
      // Open by the actual touch target after the list refresh, never by private
      // injection into a loading list. Mouse capture is a known baseline issue.
      const scoreRoute=/\/api\/scores\.php/;
      await page.route(scoreRoute,route=>route.fulfill({contentType:'application/json',body:JSON.stringify({ok:true,scores:[{id:'fixture-nested',userId:'fixture-npc',playerName:'Проверка',timeMs:999000,createdAt:Date.now(),runDistance:10,riskCount:1}]})}));
      try{
        await closeSheet(page);await page.evaluate(()=>window.app.sheets.open('leaderboard'));await settlePanel(page);await page.waitForFunction(()=>!window.app.sheets._lbLoading);await page.locator('.lb-card').first().waitFor({state:'visible'});
        await page.locator('.lb-card').first().tap();await page.locator('.player-modal-backdrop').waitFor({state:'visible',timeout:5000});await page.waitForTimeout(200);
        const r=await page.locator('.player-modal-backdrop').evaluate(el=>({bg:getComputedStyle(el).backgroundColor,blur:getComputedStyle(el).backdropFilter,input:'touchscreen tap on loaded row'}));assert.match(r.bg,/rgba\(6, 27, 45, 0\.72/);assert.equal(r.blur,'none');
        await page.screenshot({path:path.join(output,'nested-player.png')});await page.locator('.player-modal-close').tap();await page.waitForTimeout(180);assert.equal(await page.locator('.player-modal-backdrop').count(),0);return r;
      }finally{await page.unroute(scoreRoute);await isolatedPage.close();}
    });
    const adPage=await newPage();
    for(const light of [false,true])for(const id of ['ad-fail-overlay','ad-watch-hint','result-overlay'])await check(`shell/${id}/${light?'light':'dark'}`,async()=>{
      const page=adPage;
      await closeSheet(page);await page.evaluate(({id,light})=>{document.documentElement.dataset.theme=light?'light':'dark';document.getElementById(id).hidden=false;},{id,light});const selector=id==='result-overlay'?'.result-bg':`#${id} .ad-fail-backdrop`;
      const r=await page.locator(selector).evaluate(el=>({bg:getComputedStyle(el).backgroundColor,blur:getComputedStyle(el).backdropFilter}));assert.match(r.bg,/rgba\(6, 27, 45, 0\.72/);assert.equal(r.blur,'none');
      if(id==='ad-watch-hint'){
        r.facts=await page.locator('#ad-watch-hint .ad-hint-fact').evaluateAll(els=>els.map(el=>({text:el.textContent,color:getComputedStyle(el).color,bg:getComputedStyle(el).backgroundColor})));
        assert.equal(r.facts.length,3);
        const channel=v=>{v/=255;return v<=.04045?v/12.92:((v+.055)/1.055)**2.4;};
        const lum=rgb=>rgb.map(channel).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0);
        for(const fact of r.facts){const fg=fact.color.match(/[\d.]+/g).slice(0,3).map(Number),bg=fact.bg.match(/[\d.]+/g).map(Number),alpha=bg[3]??1,base=[18,62,88],surface=base.map((v,i)=>bg[i]*alpha+v*(1-alpha));const a=lum(fg),b=lum(surface);fact.contrast=(Math.max(a,b)+.05)/(Math.min(a,b)+.05);assert.ok(fact.contrast>=4.5,`Fact lacks contrast on navy card: ${fact.text}`);}
      }
      await page.screenshot({path:path.join(output,`${id}-${light?'light':'dark'}.png`)});await page.evaluate(id=>document.getElementById(id).hidden=true,id);return r;
    });
    await adPage.close();
    for(const [mode,dimensions,top]of [[true,[[320,480],[390,844]],68],['tall-controls',[[320,460],[844,390]],112]]){const safe=await newPage(mode);try{for(const [width,height]of dimensions)await check(`safe/${width}x${height}/${top}`,async()=>{await safe.setViewportSize({width,height});await openLives(safe);const r=await auditLives(safe);assert.ok(r.panel.top>=top+16-.5&&r.panel.bottom<=height-24+.5&&r.panel.left>=16-.5&&r.panel.right<=width-16+.5,'Dialog overlaps Telegram safe controls');await safe.screenshot({path:path.join(output,`safe-${width}x${height}.png`)});return r.panel;});}finally{await safe.close();}}
  }
  await check('no-page-errors',()=>assert.deepEqual(errors,[]));await check('no-missing-assets',()=>assert.deepEqual(missing,[]));
  const checked=before?[]:await sourceHashes();
  if(!before)await check('checked-source-frozen-during-run',()=>assert.deepEqual(checked,initialHashes));
  await fs.writeFile(path.join(output,'verification.json'),JSON.stringify({date:new Date().toISOString(),kind:'Local Chromium isolated fixtures; text200 synthetic; not physical Telegram',before,targeted,cases,failures,errors,missing,blockedExternal:blocked,fixtureApi:api,initialSourceHashes:initialHashes,checkedSourceHashes:checked},null,2));
  console.log(JSON.stringify({pass:cases.filter(c=>c.status==='PASS').length,failed:failures.length,failures:failures.slice(0,15),output},null,2));if(failures.length)process.exitCode=1;
}finally{await browser.close();await new Promise(r=>server.close(r));}
