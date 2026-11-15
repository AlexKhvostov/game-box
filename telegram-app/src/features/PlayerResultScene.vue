<script setup lang="ts">
import {computed,ref,watch} from 'vue';
import GameArt from '../components/GameArt.vue';
import type {Score} from '../services/contracts';
import {resultMetricTip,runPoints} from './result-presentation';
const props=defineProps<{score:Score;locale:string}>();
const tip=ref('');watch(()=>props.score.id,()=>tip.value='');
const t=(ru:string,en:string)=>props.locale==='ru'?ru:en;
const integer=(value:number)=>new Intl.NumberFormat(props.locale==='ru'?'ru-RU':'en-US').format(value);
const time=computed(()=>(props.score.timeMs/1000).toFixed(3).replace('.',props.locale==='ru'?',':'.'));
</script>
<template>
  <section class="player-finish" :aria-label="t('Показатели попытки','Run statistics')">
    <GameArt class="player-finish-art" src="/assets/branding/ui/player-result-finish-turn-v1.png"/>
    <div class="player-time-info"><span>{{t('Время попытки','Run time')}}</span><strong :class="{'player-time-wide':score.timeMs>=100000}">{{time}} <small>{{t('с','s')}}</small></strong><p :class="{'player-points-wide':runPoints(score)>=100000000}"><b>{{integer(runPoints(score))}}</b> {{t('очков','points')}}</p></div>
    <div class="player-finish-metrics"><button v-for="kind in ['run','risk']" :key="kind" type="button" :class="{'player-risk':kind==='risk',selected:tip===kind}" :aria-expanded="tip===kind" @click="tip=tip===kind?'':kind"><span v-if="kind==='run'"><strong>{{integer(score.runDistance)}}</strong> {{t('шагов','steps')}}</span><span v-else>{{t('Риск','Risk')}} <strong>{{integer(score.riskCount)}}</strong></span><i aria-hidden="true">i</i></button></div>
  </section>
  <div class="player-abilities" role="group" :aria-label="t('Усиления в этой попытке','Boosts in this run')"><button v-for="kind in (['jump','helmet'] as const)" :key="kind" type="button" :class="{selected:tip===kind,used:kind==='jump'?score.hadJump:score.hadHelmet}" :aria-expanded="tip===kind" @click="tip=tip===kind?'':kind"><GameArt :src="kind==='jump'?'/assets/branding/ui/jump-hud-a-v1.png':'/assets/branding/ui/simple-energy-helmet.png'"/><span><strong>{{kind==='jump'?t('Прыжок','Jump'):t('Шлем','Helmet')}}</strong><small>{{(kind==='jump'?score.hadJump:score.hadHelmet)?t('Использован','Used'):t('Не использован','Not used')}}</small></span><i aria-hidden="true">i</i></button></div>
  <p v-if="tip" class="player-result-tip" role="status">{{resultMetricTip(tip,score,locale)}}</p>
</template>
<style scoped>
.player-finish{position:relative;min-height:0;aspect-ratio:3/2;display:flex;flex-direction:column;justify-content:space-between;margin:0 -1px;isolation:isolate}
.player-finish-art{position:absolute;z-index:-1;inset:0;width:100%;height:100%;object-fit:cover;mask-image:linear-gradient(transparent,#000 8%,#000 90%,transparent);pointer-events:none}
.player-time-info{padding:12.7% 0 0 5%;width:56%;color:#fff5d9}.player-time-info>span{display:block;font-size:11px;color:#b9d4e5;font-weight:700}.player-time-info>strong{display:block;font-size:41px;line-height:1.04;letter-spacing:-.8px;font-weight:900;font-variant-numeric:tabular-nums;white-space:nowrap}.player-time-info>strong.player-time-wide{font-size:35px}.player-time-info strong>small{font-size:17px}.player-time-info>p{margin:4px 0 0;color:#9bffe5;font-size:15px;line-height:1.15;font-weight:800}.player-time-info>p.player-points-wide{font-size:12px}
.player-finish-metrics{display:flex;gap:8px;padding:0 11px}.player-finish-metrics>button{flex:1;min-width:0;display:flex;align-items:center;gap:5px;padding:4px;min-height:48px;background:transparent;border:0;border-radius:8px;color:#f0fbff;text-align:left;font-size:12px;font-weight:700}.player-finish-metrics>button.player-risk{justify-content:flex-end;text-align:right}.player-finish-metrics strong{font-size:16px;font-weight:900;color:#9bffe5;font-variant-numeric:tabular-nums}.player-finish-metrics .player-risk strong{color:#ff9da4}
.player-abilities{display:flex;gap:7px;margin:0 11px}.player-abilities>button{display:flex;align-items:center;gap:6px;flex:1;min-width:0;min-height:48px;padding:4px;background:none;border:0;border-radius:8px;color:#f0fbff;text-align:left}.player-abilities img{width:32px;height:32px;object-fit:cover;border-radius:50%;border:1px solid #47718b;opacity:.66;padding:2px;background:#06283e}.player-abilities .used img{opacity:1;border-color:#57c7e4}.player-abilities strong,.player-abilities small{display:block}.player-abilities strong{font-size:12px;font-weight:700}.player-abilities small{font-size:10px;color:#b9d4e5;margin-top:3px}.player-abilities .used small{color:#9bffe5}i{font:600 10px/1.1 Georgia,serif;border:1px solid #b9d4e5;border-radius:50%;width:12px;height:12px;text-align:center;flex:none;color:#b9d4e5}.selected{background:#22597755!important}.player-result-tip{margin:4px 12px 3px;padding:9px;background:#0b3146;border-left:2px solid #42b5d3;font-size:12px;line-height:1.45;color:#f0fbff}
button:focus-visible{outline:2px solid #9bffe5;outline-offset:2px}@media(max-width:340px){.player-time-info>strong{font-size:36px}.player-time-info>strong.player-time-wide{font-size:30px}.player-time-info>p{font-size:13px}}
</style>
