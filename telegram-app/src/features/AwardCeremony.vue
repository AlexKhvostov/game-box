<script setup lang="ts">
import {computed,ref,watch,onMounted,onBeforeUnmount} from 'vue';
import ParityDialog from '../components/ParityDialog.vue';
import MedalArt from '../components/MedalArt.vue';
import EnergyAmount from '../components/EnergyAmount.vue';
import {awardCopy,type AwardPresentationReceipt,type AwardCloseReason} from '../domain/achievement-presentation';
import {paintAward} from '../domain/award-canvas';
import type {AwardArtwork} from '../services/award-artwork';
import {telegram} from '../platform/telegram';
const props=withDefaults(defineProps<{receipt:AwardPresentationReceipt;artwork:AwardArtwork;locale:string;muted:boolean;volume?:number}>(),{volume:.25});
const emit=defineEmits<{presented:[string];close:[id:string,reason:AwardCloseReason];energy:[{id:string;amount:number;source:HTMLElement}]}>();
const canvas=ref<HTMLCanvasElement>(),source=ref<HTMLElement>(),dialog=ref<InstanceType<typeof ParityDialog>>(),ru=computed(()=>props.locale==='ru'),copy=computed(()=>awardCopy(props.receipt.awardId,props.locale));
let closeReason:AwardCloseReason='dismiss';
let timer:ReturnType<typeof setTimeout>|undefined,frame=0,start=0,lastPaint=0,finished=false,alive=true,audio:HTMLAudioElement|undefined,observer:ResizeObserver|undefined;
const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
function paint(elapsed:number){const el=canvas.value;if(!el||!alive)return;const bounds=el.getBoundingClientRect(),dpr=Math.min(devicePixelRatio||1,2),width=Math.max(1,bounds.width),height=Math.max(1,bounds.height);if(el.width!==Math.round(width*dpr)||el.height!==Math.round(height*dpr)){el.width=Math.round(width*dpr);el.height=Math.round(height*dpr);}const context=el.getContext('2d');if(!context)return;context.setTransform(dpr,0,0,dpr,0,0);paintAward(context,width,height,props.artwork,elapsed,copy.value.cup,reduced);}
function tick(stamp:number){frame=0;if(!alive||finished||document.hidden||telegram()?.isActive===false)return;const elapsed=stamp-start;if(stamp-lastPaint>=32){paint(elapsed);lastPaint=stamp;}if(elapsed<(reduced?600:copy.value.cup?4550:4020))frame=requestAnimationFrame(tick);else{finished=true;paint(5000);}}
function stop(){finished=true;cancelAnimationFrame(frame);frame=0;clearTimeout(timer);audio?.pause();if(audio){audio.removeAttribute('src');audio.load();}paint(5000);}
function background(){if(document.hidden||telegram()?.isActive===false)stop();}
function close(reason:AwardCloseReason){closeReason=reason;stop();dialog.value?.requestClose();}
function closed(){stop();emit('close',props.receipt.id,closeReason);}
function syncAudio(){if(audio){audio.muted=props.muted;audio.volume=Math.max(0,Math.min(.25,Number.isFinite(props.volume)?props.volume:0));}}
watch(()=>[props.muted,props.volume],syncAudio);
onMounted(()=>{
 paint(0);observer=new ResizeObserver(()=>paint(finished?5000:start?Math.max(0,performance.now()-start):0));if(canvas.value)observer.observe(canvas.value);
 document.addEventListener('visibilitychange',background);telegram()?.onEvent('deactivated',background);
 // Decode has already finished in AwardHost; start on the first frame after B entrance.
 timer=setTimeout(()=>{if(!alive)return;emit('presented',props.receipt.id);start=performance.now();lastPaint=0;
  if(source.value&&props.receipt.energy>0)emit('energy',{id:props.receipt.id,amount:props.receipt.energy,source:source.value});
  if(!props.muted){audio=new Audio('/assets/achievements/scene/tada.mp3');syncAudio();const delay=reduced?0:copy.value.cup?1340:790;timer=setTimeout(()=>{if(alive&&!finished)void audio?.play().catch(()=>{});},delay);}
  frame=requestAnimationFrame(tick);
 },reduced?0:160);
});
onBeforeUnmount(()=>{alive=false;stop();observer?.disconnect();document.removeEventListener('visibilitychange',background);telegram()?.offEvent('deactivated',background);});
</script>
<template><ParityDialog ref="dialog" :dismiss-on-backdrop="false" :title="copy.cup?(ru?'Новый титул':'New title'):(ru?'Достижение открыто':'Achievement unlocked')" :locale="locale" name="award-ceremony" variant="award" @close="closed"><div class="port-award-stage" :data-award-id="receipt.awardId"><img class="port-award-studio" src="/assets/achievements/scene/stage-studio-portrait.png" alt=""><canvas ref="canvas" class="port-award-canvas" aria-hidden="true"></canvas><div v-if="!artwork.start&&!artwork.end&&!artwork.atlas" class="port-award-fallback"><MedalArt :id="receipt.awardId" large :normalized="false"/></div><div class="port-award-heading"><small>{{copy.cup?(ru?'НОВЫЙ ТИТУЛ':'NEW TITLE'):(ru?'НОВОЕ ДОСТИЖЕНИЕ':'ACHIEVEMENT UNLOCKED')}}</small><h2>{{copy.label}}</h2><strong>{{copy.category}}</strong></div><div class="port-award-bottom"><div class="port-award-loot"><div class="port-award-collected"><MedalArt :id="receipt.awardId" :normalized="false"/><span><small>{{ru?'В КОЛЛЕКЦИИ':'COLLECTED'}}</small><b>{{copy.name}}</b></span></div><div v-if="receipt.energy>0" ref="source" class="port-award-energy" data-award-source><small>{{ru?'БОНУС':'BONUS'}}</small><EnergyAmount :amount="receipt.energy" prefix="+"/></div></div><button class="port-award-continue" @click="close('continue')">{{ru?'Продолжить':'Continue'}}</button><button class="port-award-collection" @click="close('collection')">{{ru?'В достижения':'View achievements'}}</button></div></div></ParityDialog></template>
