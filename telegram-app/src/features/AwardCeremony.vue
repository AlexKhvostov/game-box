<script setup lang="ts">
import {computed,onBeforeUnmount,onMounted,ref} from 'vue';
import ParityDialog from '../components/ParityDialog.vue';
import MedalArt from '../components/MedalArt.vue';
import EnergyAmount from '../components/EnergyAmount.vue';
import {awardCopy,type AwardPresentationReceipt,type AwardCloseReason} from '../domain/achievement-presentation';
import {AWARD_CELEBRATION_MS,AWARD_FRAME_MS,paintAwardParticles} from '../domain/award-canvas';
import {awardStudio,type AwardArtwork} from '../services/award-artwork';
import type {AwardFanfare} from '../services/award-fanfare';
import {telegram} from '../platform/telegram';

const props=defineProps<{receipt:AwardPresentationReceipt;artwork:AwardArtwork;locale:string;muted:boolean;volume:number;fanfare:AwardFanfare}>();
const emit=defineEmits<{presented:[id:string];close:[id:string,reason:AwardCloseReason];energy:[{id:string;amount:number;source:HTMLElement}]}>();
const stage=ref<HTMLElement>(),canvas=ref<HTMLCanvasElement>(),source=ref<HTMLElement>();
const dialog=ref<InstanceType<typeof ParityDialog>>();
const ru=computed(()=>props.locale==='ru'),copy=computed(()=>awardCopy(props.receipt.awardId,props.locale));
const motion=matchMedia('(prefers-reduced-motion: reduce)');
const particles=ref(!motion.matches),artUnavailable=ref(false);
let closeReason:AwardCloseReason='dismiss';
let timer:ReturnType<typeof setTimeout>|undefined,frame=0,start=0,lastPaint=-Infinity,stopped=false;
let observer:ResizeObserver|undefined,context:CanvasRenderingContext2D|null=null,width=0,height=0;

function resizeEffects(){
  const layer=canvas.value,bounds=stage.value?.getBoundingClientRect();
  if(!layer||!bounds)return;
  width=bounds.width;height=bounds.height;
  const ratio=Math.min(devicePixelRatio||1,1.5);
  layer.width=Math.max(1,Math.round(width*ratio));layer.height=Math.max(1,Math.round(height*ratio));
  context=layer.getContext('2d');
  context?.setTransform(ratio,0,0,ratio,0,0);
}
function stopParticles(){
  cancelAnimationFrame(frame);frame=0;particles.value=false;context=null;
  observer?.disconnect();
}
function tick(stamp:number){
  frame=0;
  if(stopped||!particles.value)return;
  if(document.hidden||telegram()?.isActive===false){stop();return;}
  const elapsed=stamp-start;
  if(elapsed>=AWARD_CELEBRATION_MS){stopParticles();return;}
  if(context&&elapsed-lastPaint>=AWARD_FRAME_MS-1){
    paintAwardParticles(context,width,height,elapsed,copy.value.cup);
    lastPaint=elapsed;
  }
  frame=requestAnimationFrame(tick);
}
function stop(closing=false){
  if(stopped)return;
  stopped=true;clearTimeout(timer);stopParticles();
  if(closing)props.fanfare.close();else props.fanfare.stop();
}
function background(){if(document.hidden||telegram()?.isActive===false)stop();}
function reduceMotion(){if(motion.matches)stopParticles();}
function close(reason:AwardCloseReason){closeReason=reason;dialog.value?.requestClose();}
function closed(){stop();emit('close',props.receipt.id,closeReason);}
function begin(){
  if(stopped||document.hidden||telegram()?.isActive===false){stop();return;}
  emit('presented',props.receipt.id);
  if(particles.value){
    resizeEffects();
    start=performance.now();frame=requestAnimationFrame(tick);
    if(!copy.value.cup&&source.value&&props.receipt.energy>0)
      emit('energy',{id:props.receipt.id,amount:props.receipt.energy,source:source.value});
  }
  props.fanfare.present();
}
onMounted(()=>{
  props.fanfare.prepare(props.muted,props.volume,event=>event.target instanceof Element&&
    !!event.target.closest('.port-award-continue,.port-award-collection,.port-award-backdrop .port-close'));
  if(particles.value&&stage.value){observer=new ResizeObserver(resizeEffects);observer.observe(stage.value);}
  motion.addEventListener('change',reduceMotion);
  document.addEventListener('visibilitychange',background);telegram()?.onEvent('deactivated',background);
  timer=setTimeout(begin,motion.matches?0:160);
});
onBeforeUnmount(()=>{
  stop();motion.removeEventListener('change',reduceMotion);
  document.removeEventListener('visibilitychange',background);telegram()?.offEvent('deactivated',background);
});
</script>

<template>
  <ParityDialog ref="dialog" :dismiss-on-backdrop="false" :title="copy.cup?(ru?'Новый титул':'New title'):(ru?'Достижение открыто':'Achievement unlocked')"
    :locale="locale" name="award-ceremony" variant="award" @closing="stop(true)" @close="closed">
    <div ref="stage" class="port-award-stage" :class="{'port-award-cup':copy.cup}" :data-award-id="receipt.awardId">
      <img class="port-award-studio" :src="awardStudio" alt="">
      <div class="port-award-still">
        <img v-if="artwork.src&&!artUnavailable" :src="artwork.src" :alt="copy.name" @error="artUnavailable=true">
        <MedalArt v-else :id="receipt.awardId" :alt="copy.name" thumbnail :normalized="false"/>
      </div>
      <canvas v-if="particles" ref="canvas" class="port-award-canvas" aria-hidden="true"></canvas>
      <div class="port-award-heading">
        <small>{{copy.cup?(ru?'НОВЫЙ ТИТУЛ':'NEW TITLE'):(ru?'НОВОЕ ДОСТИЖЕНИЕ':'ACHIEVEMENT UNLOCKED')}}</small>
        <strong v-if="copy.cup">{{copy.category}}</strong>
        <h2>{{copy.label}}</h2>
        <strong v-if="!copy.cup">{{copy.category}}</strong>
      </div>
      <div class="port-award-bottom">
        <div class="port-award-loot">
          <div class="port-award-collected">
            <MedalArt :id="receipt.awardId" thumbnail :normalized="false"/>
            <span><small>{{ru?'В КОЛЛЕКЦИИ':'COLLECTED'}}</small><b>{{copy.name}}</b></span>
          </div>
          <div v-if="!copy.cup&&receipt.energy>0" ref="source" class="port-award-energy" data-award-source>
            <small>{{ru?'БОНУС':'BONUS'}}</small><EnergyAmount :amount="receipt.energy" prefix="+"/>
          </div>
        </div>
        <button type="button" class="port-award-continue" @click="close('continue')">{{ru?'Продолжить':'Continue'}}</button>
        <button type="button" class="port-award-collection" @click="close('collection')">{{ru?'В достижения':'View achievements'}}</button>
      </div>
    </div>
  </ParityDialog>
</template>

<style scoped>
.port-award-still{
  position:absolute;z-index:1;left:50%;top:44%;transform:translate(-50%,-50%);width:78%;max-height:49%;
  aspect-ratio:1;pointer-events:none
}
.port-award-cup .port-award-still{top:45%;width:90%}
.port-award-still>img,.port-award-still :deep(.port-medal-art){display:block;width:100%;height:100%;object-fit:contain}
.port-award-stage .port-award-canvas{z-index:2}
.port-award-stage .port-award-heading{z-index:3}
@media(max-height:500px){
  .port-award-stage .port-award-heading{top:36px;gap:3px}
  .port-award-heading h2{font-size:32px}
}
</style>
