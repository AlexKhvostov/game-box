<script setup lang="ts">
// QA-only visual/audio exercise. No kernel commands, account calls, journal or energy writes.
import {ref,watch,onMounted,onBeforeUnmount} from 'vue';
import GameWindow from '../components/GameWindow.vue';
import {state,world} from '../services/game-store';
import {prepareAudio,enableAudio,sound,stopAudio,syncMusic,audioDiagnostics,inhibitAudio,previewAllAudioEffects} from '../platform/audio';
import {effects,type SoundName} from '../platform/audio-engine';
import {FieldPainter} from '../game/painter';
import {ImpactBurst} from '../game/impact';
import {prepareImpactGlyphs} from '../game/impact-glyphs';
import {telegram} from '../platform/telegram';
const canvas=ref<HTMLCanvasElement>(),report=ref(''),running=ref(false),ready=ref(false),label=ref('');
const names=Object.keys(effects) as SoundName[];
const titles:Record<SoundName,string>={start:'Старт',wall:'Враг — стена',collide:'Враг — враг',hit:'Герой — враг',heroWall:'Герой — стена',helmet:'Шлем',jump:'Прыжок',risk:'Риск'};
let raf=0,disposed=false,painter:FieldPainter|undefined,releaseInhibit:(()=>void)|undefined,releasePreview:(()=>void)|undefined;
let initial=world.value?structuredClone(world.value):null;
function refresh(){report.value=JSON.stringify({audio:audioDiagnostics(),soundPreference:state.preferences.sound,musicPreference:state.preferences.music},null,2);}
function one(name:SoundName){enableAudio();sound(name);label.value=titles[name];refresh();}
function run(withAudio:boolean){
  if(!ready.value||running.value||!initial||!state.config||!painter)return;
  running.value=true;label.value=withAudio?'QA: анимация и все звуки':'QA: та же анимация без звука';
  if(withAudio){enableAudio();syncMusic();}else{stopAudio();releaseInhibit=inhibitAudio();}
  const snapshot=structuredClone(initial),config=state.config.config,frames:number[]=[],costs:number[]=[];
  const started=performance.now(),beforeAudio=audioDiagnostics();let previous=started,nextSound=0,nextBurst=0,index=0,impacts:ImpactBurst[]=[];
  let seed=417;const rng=()=>((seed=(1664525*seed+1013904223)>>>0)/2**32);
  function tick(now:number){
    if(disposed||!running.value)return;
    if(document.hidden||telegram()?.isActive===false||state.externalBusy){abortRun();return;}
    const elapsed=now-started,dt=now-previous;previous=now;
    snapshot.timeMs=elapsed;snapshot.playing=true;snapshot.dead=false;
    snapshot.enemies=snapshot.enemies.map((enemy,i)=>({...enemy,x:(1+Math.sin(elapsed/900+i))*Math.max(0,380-enemy.w)/2,y:(1+Math.cos(elapsed/1100+i))*Math.max(0,380-enemy.h)/2}));
    if(elapsed>=nextBurst){impacts.push(new ImpactBurst(snapshot,true,rng));nextBurst+=2000;}
    impacts=impacts.filter(impact=>impact.update(Math.min(dt,50)/1000));
    const drawAt=performance.now();painter!.draw(snapshot,config,Math.floor(elapsed/16.667),impacts);costs.push(performance.now()-drawAt);frames.push(dt);
    if(withAudio&&elapsed>=nextSound){sound(names[index++%names.length]!);nextSound=elapsed+90;}
    if(elapsed<8000){raf=requestAnimationFrame(tick);return;}
    const during=audioDiagnostics();running.value=false;stopAudio();releaseInhibit?.();releaseInhibit=undefined;
    const stats=(rows:number[])=>{const sorted=[...rows].sort((a,b)=>a-b);return{n:sorted.length,p95:sorted[Math.round((sorted.length-1)*.95)]??0,max:sorted.at(-1)??0,over25:rows.filter(x=>x>25).length};};
    report.value=JSON.stringify({scope:'QA animation with actual FieldPainter; synthetic paths; not a paid game or acoustic recording',withAudio,rafMs:stats(frames),paintMs:stats(costs),audio:audioDiagnostics(),during,scheduledEffects:during.starts-beforeAudio.starts,canvasLogicalWidth:canvas.value?.clientWidth??0},null,2);
  }
  raf=requestAnimationFrame(tick);
}
function abortRun(){if(!running.value)return;running.value=false;cancelAnimationFrame(raf);stopAudio();releaseInhibit?.();releaseInhibit=undefined;report.value=JSON.stringify({incomplete:true,reason:'background_or_external_action',audio:audioDiagnostics()},null,2);}
const visibility=()=>{if(document.hidden)abortRun();};
watch(()=>state.externalBusy,busy=>{if(busy)abortRun();});
onMounted(async()=>{releasePreview=previewAllAudioEffects();document.addEventListener('visibilitychange',visibility);telegram()?.onEvent('deactivated',abortRun);await Promise.all([prepareAudio(),prepareImpactGlyphs()]);if(disposed)return;if(canvas.value){painter=new FieldPainter(canvas.value);if(state.config)painter.configure(state.config.config);}ready.value=!!painter&&!!initial;refresh();});
onBeforeUnmount(()=>{abortRun();releasePreview?.();document.removeEventListener('visibilitychange',visibility);telegram()?.offEvent('deactivated',abortRun);releaseInhibit?.();disposed=true;running.value=false;cancelAnimationFrame(raf);stopAudio();});
</script>
<template><GameWindow title="QA · Звуки" class="audio-diagnostics-window" :closable="!running"><p class="hint">Без списания энергии и сохранения результатов. Все восемь эффектов и музыка включены только для проверки; ваши настройки и RC не меняются. Это проверка подготовки и кадров, не запись динамика.</p><canvas ref="canvas" width="760" height="760" class="audio-lab-field"/><div class="audio-lab-buttons"><button v-for="name in names" :key="name" class="secondary" :disabled="running||!ready" @click="one(name)">{{titles[name]}}</button></div><div class="button-row"><button class="secondary" :disabled="running||!ready" @click="run(false)">8 с без звука</button><button class="secondary" :disabled="running||!ready" @click="run(true)">8 с со звуком</button></div><p role="status">{{label}}</p><pre class="audio-lab-report">AUDIO_QA {{report}}</pre></GameWindow></template>
