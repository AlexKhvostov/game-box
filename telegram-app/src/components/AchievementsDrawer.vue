<script setup lang="ts">
import {computed} from 'vue';
import LevelBadge from './LevelBadge.vue';
import MedalArt from './MedalArt.vue';
import GameSettingsButton from './GameSettingsButton.vue';
import {activeMedalCount,safeLevel,type AchievementPanelModel} from '../domain/achievement-presentation';
import './achievement-port.css';
import {medalById} from '../domain/achievements';
const props=withDefaults(defineProps<{model:AchievementPanelModel;locale:string;playing:boolean;interactive?:boolean;embedded?:boolean;showSettings?:boolean}>(),{interactive:true,showSettings:true});
defineEmits<{open:[];settings:[]}>();
const ru=computed(()=>props.locale==='ru'),count=computed(()=>activeMedalCount(props.model.earnedIds)),level=computed(()=>safeLevel(props.model.level));
const recentMedals=computed(()=>props.model.earnedIds.filter(id=>!!medalById(id)).slice(-5));
const seconds=(value:number|null)=>value===null?'—':(value/1000).toFixed(1);
const metric=(key:'time'|'average')=>props.model.metrics!==undefined?(props.model.metrics[key]===undefined?null:props.model.metrics[key]!*1000):(key==='time'?props.model.bestTimeMs:props.model.averageMs);
</script>
<style scoped>
.port-drawer-wrap.port-drawer-embedded{position:relative;inset:auto;width:100%;height:64px;overflow:visible;pointer-events:auto}
.port-drawer-embedded>.port-drawer-lip{display:none}
.port-drawer-embedded>.port-drawer{position:static;transform:none;gap:7px}
.port-drawer-embedded .port-cassette{height:64px;padding:0 0 8px;border:0;border-radius:0;background:transparent;box-shadow:none}
.port-drawer-embedded .port-cassette-progress{left:0;right:0;bottom:0;height:3px}
.port-drawer-embedded .port-settings-entry{width:34px;min-height:48px;margin-top:2px;border-radius:8px}
</style>
<template><div class="port-drawer-wrap" :class="{'port-drawer-running':playing,'port-drawer-embedded':embedded}" :inert="playing||!interactive?true:undefined" @pointerdown.stop @pointerup.stop @pointermove.stop @pointercancel.stop @touchstart.stop @touchend.stop @click.stop><span class="port-drawer-lip" aria-hidden="true"><i v-for="n in 40" :key="n" :class="{lit:n<=count}"></i></span><div class="port-drawer"><button class="port-cassette" :disabled="playing||!interactive" :aria-label="ru?`Достижения: ${count} из 40`:`Achievements: ${count} of 40`" @click="$emit('open')"><div class="port-cassette-main"><LevelBadge :level="level" :locale="locale" compact decorative/><div class="port-cassette-metrics"><span><small>{{ru?'Рекорд':'Record'}}</small><b>{{seconds(metric('time'))}}<em v-if="metric('time')!==null">{{ru?' с':' s'}}</em></b></span><span><small>{{ru?'Среднее':'Average'}}</small><b>{{seconds(metric('average'))}}<em v-if="metric('average')!==null">{{ru?' с':' s'}}</em></b></span></div><div class="port-cassette-medals" aria-hidden="true"><MedalArt v-for="(id,index) in recentMedals" :style="{zIndex:recentMedals.length-index}" :key="id" :id="id" :normalized="false"/><svg v-if="!count" class="port-empty-medal" viewBox="0 0 32 36"><path d="m10 23-3 10 9-5 9 5-3-10M27 13a11 11 0 1 1-22 0 11 11 0 0 1 22 0Z"/><path d="m16 6 2 4 4 .5-3 3 .7 4.5-3.7-2-3.7 2 .7-4.5-3-3 4-.5Z"/></svg></div></div><div class="port-cassette-bottom"><small>{{level<6?`${ru?'До':'To'} LVL ${level+1} · ${model.levelCounts[level-1]??0}/7`:(ru?'Все ступени собраны':'All medal tiers complete')}}</small><b>{{count}}/40 ›</b></div><span class="port-cassette-progress" aria-hidden="true"><i v-for="n in 40" :key="n" :class="{lit:n<=count}"></i></span></button><GameSettingsButton v-if="showSettings" :disabled="playing||!interactive" :locale="locale" @click="$emit('settings')"/></div></div></template>
