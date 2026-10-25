import {isAnalyticsEvent,clickEvent,WindowAnalytics,type AnalyticsEvent} from './analytics-core';
import {analyticsDestination} from './analytics-config';
type Ym=((...args:unknown[])=>void)&{a?:unknown[][];l?:number};
declare global{interface Window{ym?:Ym}}
const destination=analyticsDestination(import.meta.env.VITE_ANALYTICS_ENV,import.meta.env.VITE_QA_MODE,typeof location==='undefined'?'':location.hostname);
// A new queue format deliberately never reads old schema2 payloads.
const storageKey=`untouch_ui_analytics_v3:${destination.counter}`;
type Packet={name:AnalyticsEvent;id:string};
let queue:Packet[]=[],started=false,ready=false,sending=false,sequence=0;
let timer:ReturnType<typeof setInterval>|undefined;
try{const cached=JSON.parse(localStorage.getItem(storageKey)??'[]');if(Array.isArray(cached))queue=cached.filter(p=>p&&isAnalyticsEvent(p.name)&&typeof p.id==='string').map(p=>({name:p.name,id:p.id})).slice(-64);}catch{/* Optional telemetry never blocks the game. */}
function persist(){try{localStorage.setItem(storageKey,JSON.stringify(queue));}catch{/* Best effort. */}}
function pump(){
 if(!ready||sending||!queue.length||!window.ym)return;
 sending=true;const packet=queue[0]!;let settled=false;
 const timeout=setTimeout(()=>{if(!settled){settled=true;sending=false;}},8000);
 try{window.ym(destination.counter,'reachGoal',packet.name,undefined,()=>{
  if(settled)return;settled=true;clearTimeout(timeout);if(queue[0]?.id===packet.id)queue.shift();persist();sending=false;
  if(import.meta.env.DEV)console.debug('UNTOUCH_METRIKA_ACK',JSON.stringify({counter:destination.counter,name:packet.name}));pump();
 });}catch{clearTimeout(timeout);sending=false;}
}
export function analyticsEvent(name:string){
 try{if(!started||!isAnalyticsEvent(name))return;const packet={name,id:`${Date.now()}-${++sequence}`};if(queue.length>=64)queue.shift();queue.push(packet);persist();
  if(import.meta.env.DEV)console.debug('UNTOUCH_ANALYTICS',JSON.stringify({counter:destination.counter,name}));pump();
 }catch{/* Never throw into the interface. */}
}
export function analyticsClick(placement:string,feature:string){const name=clickEvent(placement,feature);if(name)analyticsEvent(name);}
const windows=new WindowAnalytics(analyticsEvent);
let baseWindows:string[]=[];const overlays:{name:string}[]=[];
export function analyticsWindows(names:string[]){baseWindows=names;windows.setStack([...baseWindows,...overlays.map(o=>o.name)]);}
export function analyticsOverlay(name='dialog'){const item={name};overlays.push(item);analyticsWindows(baseWindows);return()=>{const i=overlays.indexOf(item);if(i>=0){overlays.splice(i,1);analyticsWindows(baseWindows);}};}
function loadSdk(){
 if(ready||document.querySelector('script[data-untouch-metrika]'))return;
 const script=document.createElement('script');script.dataset.untouchMetrika='true';script.async=true;script.referrerPolicy='no-referrer';script.src=`https://mc.yandex.ru/metrika/tag.js?id=${destination.counter}`;
 const ym:Ym=window.ym??Object.assign((...args:unknown[])=>{ym.a!.push(args);},{a:[] as unknown[][],l:Date.now()});window.ym=ym;
 ym(destination.counter,'init',{defer:true,webvisor:false,clickmap:false,trackLinks:false,accurateTrackBounce:false,trackHash:false,url:location.origin+location.pathname,referrer:''});
 script.onload=()=>{ready=true;ym(destination.counter,'hit',location.origin+location.pathname,{referer:''});pump();};script.onerror=()=>script.remove();document.head.append(script);
}
export function initializeAnalytics(){
 if(started)return;started=true;loadSdk();
 const retry=()=>{if(!document.hidden){loadSdk();pump();}};
 document.addEventListener('visibilitychange',retry);window.addEventListener('pageshow',retry);window.addEventListener('online',retry);
 timer=setInterval(retry,5000);
 if(import.meta.hot)import.meta.hot.dispose(()=>{if(timer)clearInterval(timer);document.removeEventListener('visibilitychange',retry);window.removeEventListener('pageshow',retry);window.removeEventListener('online',retry);});
}
