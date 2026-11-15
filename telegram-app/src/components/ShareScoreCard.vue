<script setup lang="ts">
import {computed,ref,watch,nextTick,onMounted,onBeforeUnmount} from 'vue';
import GameIcon from './GameIcon.vue';
import {state} from '../services/game-store';
import type {ShareInvitation} from '../domain/share-invitation';
const props=defineProps<{timeMs:number;riskCount:number;steps:number;invitation?:ShareInvitation|null;artUrl?:string}>();
const emit=defineEmits<{layout:[textScale:number]}>();
const card=ref<HTMLElement>(),timeNode=ref<HTMLElement>(),largeText=ref(false);let resize:ResizeObserver|undefined,fitKey='';
function fitTime(){const el=card.value,time=timeNode.value;if(!el||!time)return;const style=getComputedStyle(el),scale=parseFloat(style.getPropertyValue('--text-scale'))||1,available=Math.min(time.parentElement!.clientWidth,el.clientWidth-parseFloat(style.paddingLeft)-parseFloat(style.paddingRight)),key=`${props.timeMs}:${props.invitation?.code}:${available}:${scale}`;if(key===fitKey)return;fitKey=key;time.style.fontSize='';if(time.scrollWidth>available)time.style.fontSize=Math.max(8,parseFloat(getComputedStyle(time).fontSize)*available/time.scrollWidth*.98)+'px';}
watch(()=>[props.timeMs,props.invitation?.code],()=>{void nextTick(fitTime);});
onMounted(()=>{const measure=()=>{const scale=card.value?parseFloat(getComputedStyle(card.value).getPropertyValue('--text-scale'))||1:1;largeText.value=scale>1.3;emit('layout',scale);void nextTick(fitTime);};resize=new ResizeObserver(measure);if(card.value)resize.observe(card.value);measure();});
onBeforeUnmount(()=>resize?.disconnect());
const seconds=computed(()=>(props.timeMs/1000).toFixed(3));
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
</script>
<template>
  <article ref="card" class="share-score-card" :aria-label="t('Предпросмотр публикации','Post preview')">
    <img v-if="artUrl" class="share-card-scene" :src="artUrl" :alt="t('Кубик уворачивается от красных препятствий','A cube dodges red obstacles')"/>
    <div class="share-card-top" :class="{'share-card-top-stacked':largeText||(invitation?.code.length??0)>8}"><div class="share-card-score"><span class="share-card-brand">untouch</span><strong ref="timeNode" class="share-card-time" :class="{'share-card-time-long':seconds.length>8}">{{seconds}} <small>{{t('с','s')}}</small></strong></div><div v-if="invitation" class="share-card-invitation" data-share-invitation><small>{{invitation.codeLabel}}</small><strong>{{invitation.code}}</strong><span>{{invitation.title}}</span></div></div>
    <div class="share-card-art-space" aria-hidden="true"/>
    <div class="share-card-bottom"><div class="share-card-metrics">
      <span class="share-card-metric share-card-risk"><GameIcon name="risk"/><span>{{t('Риск','Risk')}} <b>{{riskCount}}</b></span></span>
      <span class="share-card-metric share-card-steps"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><ellipse cx="7" cy="7" rx="3" ry="5" transform="rotate(18 7 7)"/><path d="m3 16 5 1-1 5-5-1Z"/><ellipse cx="18" cy="12" rx="3" ry="5" transform="rotate(18 18 12)"/><path d="m14 21 5 1"/></svg><span>{{t('Шаги','Steps')}} <b>{{steps}}</b></span></span>
    </div><p class="share-challenge">{{t('Сколько продержитесь вы?','How long can you survive?')}}</p></div>
  </article>
</template>
<style src="./share-score-card.css"/>
