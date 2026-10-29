<script setup lang="ts">
import {computed,ref,shallowRef,onMounted,onBeforeUnmount,toRaw} from 'vue';
import GameWindow from '../components/GameWindow.vue';
import BrakeButton from '../components/BrakeButton.vue';
import {state,back} from '../services/game-store';
import {telegram} from '../platform/telegram';
import {loadSpeedHelp,speedHelpCall,type PacePreview,type PaceSnapshot,type PacePoint,type PaceEvent} from '../domain/speed-help';
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
const chart=ref<HTMLElement>(),width=ref(340),preview=shallowRef<PacePreview>(),snapshot=shallowRef<PaceSnapshot>();
const manual=ref(false),running=ref(false),loading=ref(true),error=ref(false),pressed=ref(false),events=shallowRef<PaceEvent[]>([]);
const session=`help-${Date.now()}-${Math.random().toString(36).slice(2)}`;
let points:PacePoint[]=[],raf=0,last=0,disposed=false,observer:ResizeObserver|undefined,pressTimer:ReturnType<typeof setTimeout>|undefined;
const config=structuredClone(toRaw(state.config?.config.enemyPace??{}));
const call=(op:string,extra:Record<string,unknown>={})=>speedHelpCall<PaceSnapshot>({op,session,...extra});
const height=computed(()=>Math.max(180,Math.round(width.value*.57))),bottom=computed(()=>height.value-36);
const maximum=computed(()=>Math.max(1,(preview.value?.baseline.at(-1)?.target??150)*1.18));
const x=(time:number)=>20+time/60*(width.value-34),y=(value:number)=>bottom.value-value/maximum.value*(bottom.value-34);
const n=(value:number)=>Number(value.toFixed(3));
const path=(data:PacePoint[])=>data.map((p,i)=>`${i?'L':'M'}${n(x(p.t))},${n(y(p.target))}`).join(' ');
const baselinePath=computed(()=>path(preview.value?.baseline??[]));
const actualPath=computed(()=>{snapshot.value?.t;return path(manual.value?points:preview.value?.actual??[]);});
const shownEvents=computed(()=>manual.value?events.value:preview.value?.events??[]);
const rewind=computed(()=>snapshot.value?.rewind??preview.value?.rewind??6);
const waits=computed(()=>{
 const result=shownEvents.value.filter(e=>e.waitedSec>.04).map(e=>({from:e.readyAtBefore,to:e.t,target:e.readyTarget}));
 const s=snapshot.value;
 if(manual.value&&s?.ready&&s.t-s.readyAt>.02)result.push({from:s.readyAt,to:s.t,target:s.readyTarget!});
 return result;
});
const waitPath=(from:number,to:number)=>path((manual.value?points:preview.value?.actual??[]).filter(p=>p.t>=from-1e-7&&p.t<=to+1e-7&&p.phase!=='after'));
const clock=computed(()=>{const seconds=Math.floor(snapshot.value?.t??0);return `${String(Math.floor(seconds/60)).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')} / 01:00`;});
const status=computed(()=>snapshot.value?.ended?t('Проба завершена','Test finished'):manual.value&&!running.value?t('На паузе','Paused'):snapshot.value?.ready?t('Улитка готова','Snail ready'):t('Улитка заряжается','Snail charging'));
function stop(){running.value=false;cancelAnimationFrame(raf);raf=0;last=0;clearTimeout(pressTimer);pressed.value=false;}
async function initialize(){
 loading.value=true;error.value=false;
 try{await loadSpeedHelp();if(disposed)return;preview.value=speedHelpCall<PacePreview>({op:'preview',config});snapshot.value=call('reset',{config});if(!preview.value.ok||!snapshot.value.ok)throw Error('model');}
 catch{if(!disposed)error.value=true;}
 finally{if(!disposed)loading.value=false;}
}
function frame(now:number){
 if(!running.value||disposed)return;
 if(last){const next=call('advance',{ms:Math.min(100,Math.max(0,now-last))*2});snapshot.value=next;points.push({t:next.t,target:next.target});if(next.ended)stop();}
 last=now;if(running.value)raf=requestAnimationFrame(frame);
}
function start(){if(loading.value||error.value)return;stop();manual.value=true;events.value=[];snapshot.value=call('reset',{config});points=[{t:snapshot.value.t,target:snapshot.value.target}];running.value=true;raf=requestAnimationFrame(frame);}
function press(){if(!running.value||!snapshot.value?.ready||snapshot.value.ended)return;const next=call('press');if(!next.ok||!next.event)return;snapshot.value=next;events.value=[...events.value,next.event];points.push({t:next.t,target:next.target,phase:'after'});pressed.value=true;clearTimeout(pressTimer);pressTimer=setTimeout(()=>pressed.value=false,120);}
function pause(){if(snapshot.value?.ended)return;if(running.value)stop();else{running.value=true;last=0;raf=requestAnimationFrame(frame);}}
function explain(){stop();manual.value=false;points=[];events.value=[];snapshot.value=call('reset',{config});}
function goBack(){if(manual.value)explain();else back();}
function visibility(){if(document.hidden&&running.value)stop();}
function deactivate(){if(running.value)stop();}
onMounted(()=>{void initialize();observer=new ResizeObserver(()=>{if(chart.value)width.value=Math.max(240,chart.value.clientWidth);});if(chart.value)observer.observe(chart.value);document.addEventListener('visibilitychange',visibility);telegram()?.onEvent('deactivated',deactivate);});
onBeforeUnmount(()=>{disposed=true;stop();observer?.disconnect();document.removeEventListener('visibilitychange',visibility);telegram()?.offEvent('deactivated',deactivate);if(globalThis.untouchSpeedHelp)call('dispose');});
</script>
<template>
 <GameWindow class="speed-help-window" :title="t('Скорость и улитка','Speed and snail')">
  <article class="pace-panel" :data-mode="manual?'test':'explain'">
   <header class="pace-heading"><div><h2>{{t('Скорость и улитка','Speed and snail')}}</h2><p v-if="manual">{{t('Попробуйте сами','Try it yourself')}}</p></div><img v-if="!manual" src="/assets/branding/ui/speed-help/cube-analyst-v1.png" alt=""><div v-if="!manual" class="pace-marks" aria-hidden="true"><span class="mark-plus">+</span><span class="mark-sum">∑</span><span class="mark-root">√</span><span class="mark-times">×</span><svg viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="m7 12 4 4 7-9"/></svg></div><span v-if="manual" class="pace-check" aria-hidden="true">✓</span></header>
   <div class="pace-legend"><span><i class="pink"/>{{t('Без улитки','Without snail')}}</span><span><i/>{{t('С улиткой','With snail')}}</span><span class="pace-wait-legend"><i class="amber"/>{{t('Улитка готова, но ещё не нажата','Snail ready, but not pressed yet')}}</span></div>
   <div ref="chart" class="pace-chart"><svg v-if="preview&&!loading&&!error" :viewBox="`0 0 ${width} ${height}`" role="img" :aria-label="t('График скорости: без улитки, с улиткой и ожидание готовой кнопки','Speed: without snail, with snail, and waiting after ready')">
    <line v-for="i in 4" :key="'h'+i" x1="20" :x2="width-14" :y1="y(maximum*i/5)" :y2="y(maximum*i/5)" class="pace-grid"/>
    <line v-for="time in [10,20,30,40,50,60]" :key="'v'+time" :x1="x(time)" :x2="x(time)" y1="34" :y2="bottom" class="pace-grid vertical"/>
    <path :d="baselinePath" class="pace-curve baseline"/><path :d="actualPath" class="pace-curve actual"/>
    <g v-for="(wait,i) in waits" :key="'wait'+i"><rect :x="x(wait.from)" y="34" :width="Math.max(0,x(wait.to)-x(wait.from))" :height="bottom-34" class="pace-wait-zone"/><path :d="waitPath(wait.from,wait.to)" class="pace-curve waiting"/><circle :cx="x(wait.from)" :cy="y(wait.target)" r="3" class="pace-ready-dot"/></g>
    <g v-for="(event,i) in shownEvents" :key="'press'+i"><line :x1="x(event.pastT)" :x2="x(event.t)" :y1="y(event.after)" :y2="y(event.after)" class="pace-reference"/><circle :cx="x(event.pastT)" :cy="y(event.after)" r="2.5" class="pace-past-dot"/><circle :cx="x(event.t)" :cy="y(event.after)" r="3" class="pace-hit-dot"/><text v-if="i===shownEvents.length-1" :x="Math.max(34,(x(event.pastT)+x(event.t))/2)" :y="y(event.after)+16" text-anchor="middle" class="pace-reference-label">{{t(`${rewind} с назад`,`${rewind}s back`)}}</text></g>
    <g v-if="manual&&snapshot"><line :x1="x(snapshot.t)" :x2="x(snapshot.t)" y1="34" :y2="bottom" class="pace-cursor"/><circle :cx="x(snapshot.t)" :cy="y(snapshot.target)" r="4" class="pace-now-dot"/></g>
    <path :d="`M20 34V${bottom}H${width-14}`" class="pace-axis"/><text v-for="time in [0,10,20,30,40,50,60]" :key="'t'+time" :x="x(time)" :y="bottom+18" text-anchor="middle">{{time}}</text><text x="20" y="20">{{t('Скорость врагов','Enemy speed')}}</text><text :x="width/2" :y="height-3" text-anchor="middle" class="pace-axis-label">{{t('Время партии, с','Run time, s')}}</text>
   </svg><p v-else-if="loading" class="pace-message" role="status">{{t('Загрузка графика…','Loading chart…')}}</p><div v-else class="pace-message" role="alert"><p>{{t('График не загрузился','Chart could not load')}}</p><button class="secondary" @click="initialize">{{t('Повторить','Retry')}}</button></div><output v-if="manual&&!loading&&!error" :aria-label="t('Время партии','Run time')">{{clock}}</output></div>
   <ul v-if="!manual" class="pace-theses"><li>{{t(`Улитка возвращает скорость врагов к значению, которое было ${rewind} секунд назад.`,`The snail restores the enemy speed from ${rewind} seconds ago.`)}}</li><li>{{t('Пока готовая улитка ждёт нажатия, враги ускоряются. Ожидание не увеличивает откат.','Enemies keep accelerating while the ready snail waits. Waiting does not increase the rewind.')}}</li></ul>
   <div v-if="manual&&snapshot" class="pace-controls"><button class="secondary" :disabled="snapshot.ended" @click="pause">{{running?t('Пауза','Pause'):t('Продолжить','Resume')}}</button><BrakeButton :ready="snapshot.ready" :remaining="snapshot.remaining" :cooldown="snapshot.cooldown" :running="running" :ended="snapshot.ended" :pressed="pressed" :locale="state.locale" @press="press"/><button class="secondary" @click="start">{{t('Заново','Restart')}}</button></div>
   <p v-if="manual" class="pace-test-note">{{t('Для теста время ускорено ×2','Test time is sped up ×2')}}</p>
   <p v-if="manual" class="pace-sr" role="status" aria-live="polite">{{status}}</p>
   <button v-if="!manual" class="primary pace-start" :disabled="loading||error" @click="start">{{t('Протестировать','Try it')}} <span aria-hidden="true">›</span></button>
   <button v-if="manual" class="secondary pace-back" @click="goBack">{{t('Назад','Back')}}</button>
  </article>
 </GameWindow>
</template>
<style scoped>
.speed-help-window :deep(.game-window){max-width:390px;max-height:calc(var(--logical-height) - 24px);border:1px solid #19b7da;border-radius:25px;background:#061b2b;outline:0;box-shadow:inset 0 0 25px #0393b01c,0 0 20px #00dbf61c}.speed-help-window :deep(.window-body){padding:0;overflow:auto}.speed-help-window :deep(.window-header){position:absolute;top:4px;right:5px;left:auto;width:28px;min-height:0;height:28px;padding:0;z-index:3;border:0;background:none}.speed-help-window :deep(.window-header h1),.speed-help-window :deep(.window-header::after){display:none}.speed-help-window :deep(.close-window){width:26px;height:26px;min-height:0;padding:0;font-size:19px;border:1px solid #3b6980;border-radius:50%;background:#0c293e;color:#b8ebf9}
.pace-panel{position:relative;isolation:isolate;padding:14px 12px 38px;color:#edf6ff;background:radial-gradient(ellipse at 85% 0%,#10475d55,transparent 45%),linear-gradient(155deg,#062035,#021322 85%)}.pace-panel:before{content:'';position:absolute;z-index:-1;bottom:0;left:0;right:0;height:48px;background:url('/assets/branding/ui/speed-help/neon-reference-v1.png') left bottom/200% auto;mask-image:linear-gradient(transparent,#000 50%);pointer-events:none}.pace-heading{position:relative;display:flex;align-items:flex-start;min-height:70px;padding:10px 27% 0 7px;margin-bottom:3px}.pace-heading h2{font-size:21px;line-height:1.15;letter-spacing:-.6px;white-space:nowrap;margin:0;font-weight:800}.pace-heading p{font-size:15px;color:#67ddff;margin:6px 0 0}.pace-heading img{position:absolute;right:0;top:-5px;width:27%;height:auto}.pace-check{position:absolute;right:6%;top:15px;width:39px;height:39px;display:grid;place-items:center;border-radius:7px;background:linear-gradient(135deg,#c1ffbb,#78e9bb);color:#06746b;transform:rotate(8deg);font-size:29px;font-weight:700}
.pace-legend{display:flex;flex-wrap:wrap;column-gap:19px;row-gap:7px;margin:0 7px 12px;font-size:max(11px,calc(10px / var(--scale,1)));line-height:1.2}.pace-legend>span{display:flex;align-items:center;gap:7px}.pace-legend i{display:inline-block;width:25px;height:3px;background:#71ffdb;border-radius:2px}.pace-legend i.pink{background:repeating-linear-gradient(90deg,#ff79b4 0 7px,transparent 7px 12px)}.pace-legend .pace-wait-legend{flex-basis:100%;font-size:max(10px,calc(10px / var(--scale,1)));color:#ffce66}.pace-legend i.amber{background:#ffce66}
.pace-chart{position:relative;min-width:0;width:100%;border:1px solid #126487;border-radius:14px;background:linear-gradient(#061f3077,#031625cc);overflow:hidden}.pace-chart svg{display:block;width:100%;height:auto;font-family:inherit}.pace-chart svg text{fill:#edf6ff;font-size:12px}.pace-grid{stroke:#164057;stroke-width:1}.pace-grid.vertical{stroke-dasharray:3 4}.pace-curve{fill:none;stroke-linecap:round;stroke-linejoin:round;stroke-width:2.9}.pace-curve.baseline{stroke:#ff79b4;stroke-width:2.4;stroke-dasharray:6 5}.pace-curve.actual{stroke:#71ffdb}.pace-curve.waiting{stroke:#ffce66}.pace-wait-zone{fill:#ffce66;opacity:.07}.pace-ready-dot{fill:#061b2b;stroke:#ffce66;stroke-width:1.5}.pace-reference{stroke:#71ffdb;stroke-width:1.5;stroke-dasharray:5 4}.pace-past-dot{fill:#061b2b;stroke:#71ffdb;stroke-width:1.4}.pace-hit-dot{fill:#71ffdb}.pace-chart svg .pace-reference-label{fill:#71ffdb;font-size:11px}.pace-cursor{stroke:#91b5ca;stroke-dasharray:5 5}.pace-now-dot{fill:#edf6ff;stroke:#71ffdb;stroke-width:2}.pace-axis{stroke:#91b5ca;fill:none}.pace-chart svg .pace-axis-label{fill:#91b5ca}.pace-chart output{position:absolute;top:5px;right:8px;padding:3px 7px;border:1px solid #126487;background:#061b2bf0;border-radius:7px;font-size:12px;color:#a8ecff;font-variant-numeric:tabular-nums}.pace-message{min-height:180px;display:grid;place-content:center;text-align:center;padding:20px;font-size:13px}.pace-message button{margin-top:12px}
.pace-theses{list-style:none;padding:0;margin:14px 7px;display:grid;gap:10px;font-size:max(13px,calc(12px / var(--scale,1)));line-height:1.45}.pace-theses li{position:relative;padding-left:17px}.pace-theses li:before{content:'';width:6px;height:6px;position:absolute;top:.5em;left:0;background:#71ffdb;border-radius:50%;box-shadow:0 0 10px #61ffe066}.pace-start.primary{display:flex;justify-content:center;align-items:center;gap:18px;width:80%;margin:0 auto;min-height:44px;padding:9px 15px;background:linear-gradient(#35ebff,#00bce8);color:#032237;border:1px solid #84f6ff;border-radius:24px;font-size:17px;font-weight:700;box-shadow:inset 0 2px 3px #d0ffff6b,0 0 18px #00d8ff44}.pace-start span{font-size:24px;line-height:.7}.pace-controls{display:grid;grid-template-columns:minmax(0,1fr) 72px minmax(0,1fr);gap:10px;align-items:center;margin:13px 7px 7px}.pace-controls>.secondary{min-width:0;min-height:max(40px,calc(36px / var(--scale,1)));padding:9px 6px;border:1px solid #237697;background:linear-gradient(#12334b,#092139);color:#e9f7ff;border-radius:14px;font-size:max(12px,calc(12px / var(--scale,1)));font-weight:500}.pace-test-note{text-align:center;font-size:max(12px,calc(11px / var(--scale,1)));line-height:1.4;color:#ffd665;margin:8px 0 11px}.pace-back.secondary{display:block;width:80%;margin:0 auto;min-height:max(32px,calc(34px / var(--scale,1)));padding:6px 12px;color:#64e8ff;border:1px solid #156789;background:#041c2e;border-radius:18px;font-size:max(12px,calc(12px / var(--scale,1)));font-weight:400}.pace-sr{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip-path:inset(50%);white-space:nowrap;border:0}
.pace-marks{position:absolute;right:-1%;top:-7px;width:34%;height:70px;pointer-events:none;color:#45e9d6}.pace-marks span{position:absolute;font:600 15px/1 Georgia,serif;text-shadow:0 0 7px #21d9c544;opacity:.86}.pace-marks .mark-plus{right:30%;top:0;transform:rotate(8deg)}.pace-marks .mark-sum{left:0;top:26px;transform:rotate(-12deg)}.pace-marks .mark-root{left:22%;top:-2px;transform:rotate(-8deg)}.pace-marks .mark-times{right:4%;bottom:0;transform:rotate(13deg)}.pace-marks svg{position:absolute;right:-1px;top:31px;width:18px;height:18px;fill:none;stroke:#8beed8;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round;transform:rotate(9deg)}
</style>
