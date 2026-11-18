<script setup lang="ts">
import {computed} from 'vue';
import LevelBadge from './LevelBadge.vue';
import LoadingClock from './LoadingClock.vue';
import MedalArt from './MedalArt.vue';
import GameSettingsButton from './GameSettingsButton.vue';
import {activeMedalCount,safeLevel,type AchievementPanelModel} from '../domain/achievement-presentation';
import './achievement-port.css';
import {achievements,personalSeriesCount,medalById} from '../domain/achievements';
const props=withDefaults(defineProps<{model:AchievementPanelModel;locale:string;playing:boolean;interactive?:boolean;embedded?:boolean;showSettings?:boolean}>(),{interactive:true,showSettings:true});
const emit=defineEmits<{open:[];settings:[];drag:[event:PointerEvent,origin:{x:number;y:number}]}>();
const tapSlopPx=8;
let press:{id:number;origin:{x:number;y:number}}|undefined;
let suppressPointerClick=false;

function pressDrawer(event:PointerEvent){
  if(!event.isPrimary||event.button!==0)return;
  suppressPointerClick=false;
  press={id:event.pointerId,origin:{x:event.clientX,y:event.clientY}};
  (event.currentTarget as HTMLButtonElement).setPointerCapture(event.pointerId);
}
function outsideTap(event:PointerEvent,origin:{x:number;y:number}){
  return Math.hypot(event.clientX-origin.x,event.clientY-origin.y)>=tapSlopPx;
}
function dragDrawer(event:PointerEvent){
  if(press?.id!==event.pointerId||!outsideTap(event,press.origin))return;
  const {origin}=press;
  press=undefined;
  suppressPointerClick=true;
  emit('drag',event,origin);
}
function releaseDrawer(event:PointerEvent){
  if(press?.id!==event.pointerId)return;
  suppressPointerClick=event.type!=='pointerup'||outsideTap(event,press.origin);
  press=undefined;
}
function openDrawer(event:MouseEvent){
  if(event.detail===0||!suppressPointerClick)emit('open');
}
const ru=computed(()=>props.locale==='ru'),count=computed(()=>activeMedalCount(props.model.earnedIds)),level=computed(()=>safeLevel(props.model.level));
const recentMedals=computed(()=>props.model.earnedIds.filter(id=>!!medalById(id)).slice(-5));
const title=computed(()=>props.model.confirmed
  ? (ru.value?'Достижения: '+count.value+' из '+achievements.length:'Achievements: '+count.value+' of '+achievements.length)
  : (ru.value?'Достижения загружаются':'Loading achievements'));
const seconds=(value:number|null)=>value===null?'—':(value/1000).toFixed(1);
const record=computed(()=>props.model.metrics===undefined?props.model.bestTimeMs:
  props.model.metrics.time===undefined?null:props.model.metrics.time*1000);
</script>
<style scoped>
.port-drawer-wrap.port-drawer-embedded{position:relative;inset:auto;width:100%;height:64px;overflow:visible;pointer-events:auto}
.port-drawer-embedded>.port-drawer-lip{display:none}
.port-drawer-embedded>.port-drawer{position:static;transform:none;gap:7px}
.port-drawer-embedded .port-cassette{height:64px;padding:0 0 8px;border:0;border-radius:0;background:transparent;box-shadow:none}
.port-drawer-embedded .port-cassette-progress{left:0;right:0;bottom:0;height:3px}
.port-drawer-embedded .port-settings-entry{width:34px;min-height:48px;margin-top:2px;border-radius:8px}
</style>
<template><div class="port-drawer-wrap" :class="{'port-drawer-running':playing,'port-drawer-embedded':embedded}" :inert="playing||!interactive?true:undefined" @pointerdown.stop @pointerup.stop @pointermove.stop @pointercancel.stop @touchstart.stop @touchend.stop @click.stop><span class="port-drawer-lip" aria-hidden="true"><i v-for="n in achievements.length" :key="n" :class="{lit:n<=count}"></i></span><div class="port-drawer"><button type="button" class="port-cassette" :disabled="playing||!interactive" :aria-label="title" aria-haspopup="dialog"
    @pointerdown="pressDrawer" @pointermove="dragDrawer" @pointerup="releaseDrawer"
    @pointercancel="releaseDrawer" @lostpointercapture="releaseDrawer" @dragstart.prevent
    @keydown.space.stop @click="openDrawer"><div class="port-cassette-main"><LevelBadge v-if="model.confirmed" :level="level" :locale="locale" compact decorative/><LoadingClock v-else :size="23" :active="!playing"/><div class="port-cassette-metrics"><span><small>{{ru?'Рекорд':'Record'}}</small><b>{{seconds(record)}}<em v-if="record!==null">{{ru?' с':' s'}}</em></b></span></div><div v-if="model.confirmed" class="port-cassette-medals" aria-hidden="true"><MedalArt v-for="(id,index) in recentMedals" :style="{zIndex:recentMedals.length-index}" :key="id" :id="id" :normalized="false"/><svg v-if="!count" class="port-empty-medal" viewBox="0 0 32 36"><path d="m10 23-3 10 9-5 9 5-3-10M27 13a11 11 0 1 1-22 0 11 11 0 0 1 22 0Z"/><path d="m16 6 2 4 4 .5-3 3 .7 4.5-3.7-2-3.7 2 .7-4.5-3-3 4-.5Z"/></svg></div></div><div v-if="model.confirmed" class="port-cassette-bottom"><small>{{level<6?`${ru?'До':'To'} LVL ${level+1} · ${model.levelCounts[level-1]??0}/${personalSeriesCount}`:(ru?'Все ступени собраны':'All medal tiers complete')}}</small><b>{{count}}/{{achievements.length}} ›</b></div><span v-if="model.confirmed" class="port-cassette-progress" aria-hidden="true"><i v-for="n in achievements.length" :key="n" :class="{lit:n<=count}"></i></span></button><GameSettingsButton v-if="showSettings" :disabled="playing||!interactive" :locale="locale" @click="$emit('settings')"/></div></div></template>
