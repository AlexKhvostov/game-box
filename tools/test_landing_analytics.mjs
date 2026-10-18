import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync(new URL('../telegram-web/landing/analytics.js',import.meta.url),'utf8');
function emitter(){const handlers=new Map();return {addEventListener(name,fn){const list=handlers.get(name)||[];list.push(fn);handlers.set(name,list);},emit(name,event={}){for(const fn of handlers.get(name)||[])fn(event);}};}
function fixture(saved,blockedStorage=false){
  const window=emitter(),document=emitter(),scripts=[],cookies=[],savedValues=new Map(saved?[['untouch_analytics_consent_v1',saved]]:[]);
  const allow=emitter(),deny=emitter(),settings=emitter();allow.focus=()=>{};
  const banner={hidden:true,querySelector:s=>s.includes('allow')?allow:deny};
  Object.assign(document,{currentScript:{dataset:{measurementId:'G-UNITTEST'}},documentElement:{dataset:{}},referrer:'https://youtube.com/watch?v=test&private=secret',
    querySelector:s=>s==='[data-analytics-consent]'?banner:null,querySelectorAll:()=>[settings],
    createElement:()=>({}),head:{append:s=>scripts.push(s)}});
  Object.defineProperty(document,'cookie',{set:s=>cookies.push(s)});
  const localStorage={getItem:k=>{if(blockedStorage)throw Error('blocked');return savedValues.get(k)||null;},setItem:(k,v)=>{if(blockedStorage)throw Error('blocked');savedValues.set(k,v);}};
  const context={window,document,localStorage,URL,Date,Set,console:{info(){}},location:new URL('https://untouch.fun/?utm_source=youtube&utm_medium=shorts&utm_campaign=oct_test&utm_content=metro&private=secret&analytics_debug=1#demo')};
  vm.runInNewContext(source,context);
  const commands=()=>Array.from(window.dataLayer,x=>Array.from(x));
  const events=()=>commands().filter(x=>x[0]==='event');
  return {window,document,scripts,cookies,banner,allow,deny,settings,savedValues,commands,events,repeat:()=>vm.runInNewContext(source,context)};
}
let count=0;function check(name,body){body();count++;console.log('PASS',name);}
check('No Google script, page_view or game events before choice',()=>{const f=fixture();f.window.emit('untouch:demo-start',{detail:{attempt_number:1}});assert.equal(f.scripts.length,0);assert.equal(f.events().length,0);assert.equal(f.banner.hidden,false);assert.equal(f.commands()[0][2].analytics_storage,'denied');});
check('Grant initializes once and preserves UTM while stripping unrelated query/referrer secrets',()=>{const f=fixture();f.allow.emit('click');f.allow.emit('click');f.repeat();assert.equal(f.scripts.length,1);const configs=f.commands().filter(x=>x[0]==='config');assert.equal(configs.length,1);const url=new URL(configs[0][2].page_location);assert.equal(url.searchParams.get('utm_source'),'youtube');assert.equal(url.searchParams.get('utm_medium'),'shorts');assert.equal(url.searchParams.get('utm_campaign'),'oct_test');assert.equal(url.searchParams.get('utm_content'),'metro');assert.equal(url.searchParams.has('private'),false);assert.equal(url.hash,'');assert.equal(configs[0][2].page_referrer,'https://youtube.com/');assert.equal(configs[0][2].allow_google_signals,false);assert.equal(f.commands().some(x=>x[0]==='event'&&x[1]==='page_view'),false);});
check('Stored refusal does not load Google or transmit events',()=>{const f=fixture('denied');f.window.emit('untouch:demo-start',{detail:{attempt_number:1}});assert.equal(f.scripts.length,0);assert.equal(f.events().length,0);assert.equal(f.banner.hidden,true);});
check('Stored permission initializes one page_view configuration',()=>{const f=fixture('granted');assert.equal(f.scripts.length,1);assert.equal(f.commands().filter(x=>x[0]==='config').length,1);});
check('First attempt, retries and result duration are distinct',()=>{const f=fixture('granted');f.window.emit('untouch:demo-start',{detail:{attempt_number:1}});f.window.emit('untouch:demo-start',{detail:{attempt_number:2}});f.window.emit('untouch:demo-end',{detail:{attempt_number:2,duration_ms:12345}});assert.deepEqual(f.events().map(x=>x[1]),['demo_start','demo_retry','demo_end']);assert.equal(f.events()[2][2].duration_seconds,12.345);});
check('Download and Telegram clicks include platform and placement without blocking navigation',()=>{const f=fixture('granted');function click(href,appStore,area){const control={getAttribute:()=>href,hasAttribute:()=>appStore,closest:s=>s===area?{}:null};f.document.emit('click',{target:{closest:()=>control}});}click('https://play.google.com/apps/testing/com.best4u.untouch',false,'.hero');click('',true,'.final-cta');click('https://t.me/UntouchGameBot/untouch',false,'footer');click('https://example.org',false,'.hero');assert.deepEqual(f.events().map(x=>x[1]),['download_click','download_click','telegram_click']);assert.equal(f.events()[0][2].store,'google_play');assert.equal(f.events()[0][2].placement,'hero');assert.equal(f.events()[1][2].availability,'coming_soon');assert.equal(f.events()[2][2].placement,'footer');});
check('Withdrawal stops events and removes only analytics cookies',()=>{const f=fixture('granted');f.deny.emit('click');f.window.emit('untouch:demo-start',{detail:{attempt_number:1}});assert.equal(f.events().length,0);assert.equal(f.window['ga-disable-G-UNITTEST'],true);assert.equal(f.cookies.length,6);assert.ok(f.cookies.every(x=>x.startsWith('_ga')));f.settings.emit('click');assert.equal(f.banner.hidden,false);});
check('Blocked local storage does not break consent or the website',()=>{const f=fixture(undefined,true);f.allow.emit('click');assert.equal(f.scripts.length,1);f.window.emit('untouch:demo-start',{detail:{attempt_number:1}});assert.equal(f.events().length,1);});
check('Actual demo lifecycle does not count resume or duplicate finish as another attempt',()=>{
  const raw=fs.readFileSync(new URL('../telegram-web/landing/demo.js',import.meta.url),'utf8');
  const demoSource=raw.slice(raw.indexOf('const KEY')).replace('export class LandingDemo','class LandingDemo').replace(/export const demo = new LandingDemo[\s\S]*$/,'')+'\nglobalThis.Subject=LandingDemo;';
  const events=[];
  const context={window:{dispatchEvent:e=>events.push(e)},CustomEvent:class{constructor(type,options){this.type=type;this.detail=options.detail;}},
    requestAnimationFrame:()=>1,cancelAnimationFrame(){},performance:{now:()=>0},console};
  vm.runInNewContext(demoSource,context);
  const d=Object.create(context.Subject.prototype);
  Object.assign(d,{lives:3,status:'idle',elapsed:0,best:0,analyticsAttempts:0,keys:new Set(),canvas:{focus(){}},world:{resetLayout(){}},preparePreview(){},save(){},updateUI(){},draw(){}});
  d.start();d.start();d.pause();d.start();assert.equal(events.length,1);
  d.elapsed=1245.9;d.finish();d.finish();assert.equal(events[1].detail.duration_ms,1245);
  d.arm();d.start();assert.equal(events[2].detail.attempt_number,2);
  d.reset();d.start();assert.equal(events[3].detail.attempt_number,3);
  assert.deepEqual(events.map(x=>x.type),['untouch:demo-start','untouch:demo-end','untouch:demo-start','untouch:demo-start']);
});
console.log(`${count} analytics checks passed`);
