<script setup lang="ts">
import {computed} from 'vue';
import GameArt from './GameArt.vue';
import GameIcon from './GameIcon.vue';
import {state} from '../services/game-store';
import {shareArtwork} from '../services/share-card';
const props=defineProps<{timeMs:number;riskCount:number;steps:number}>();
const seconds=computed(()=>(props.timeMs/1000).toFixed(3));
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
</script>
<template>
  <article class="share-score-card" :aria-label="t('Предпросмотр публикации','Post preview')">
    <GameArt class="share-card-scene" :src="shareArtwork" :alt="t('Кубик уворачивается от красных препятствий','A cube dodges red obstacles')"/>
    <div class="share-card-top"><span class="share-card-brand">untouch</span><strong class="share-card-time" :class="{'share-card-time-long':seconds.length>8}">{{seconds}} <small>{{t('с','s')}}</small></strong></div>
    <div class="share-card-art-space" aria-hidden="true"/>
    <div class="share-card-bottom"><div class="share-card-metrics">
      <span class="share-card-metric share-card-risk"><GameIcon name="risk"/><span>{{t('Риск','Risk')}} <b>{{riskCount}}</b></span></span>
      <span class="share-card-metric share-card-steps"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><ellipse cx="7" cy="7" rx="3" ry="5" transform="rotate(18 7 7)"/><path d="m3 16 5 1-1 5-5-1Z"/><ellipse cx="18" cy="12" rx="3" ry="5" transform="rotate(18 18 12)"/><path d="m14 21 5 1"/></svg><span>{{t('Шаги','Steps')}} <b>{{steps}}</b></span></span>
    </div><p class="share-challenge">{{t('Сколько продержитесь вы?','How long can you survive?')}}</p></div>
  </article>
</template>
<style src="./share-score-card.css"/>
