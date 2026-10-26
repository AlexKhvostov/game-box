<script setup lang="ts">
import {computed,watch} from 'vue';
import type {WorldState} from '../domain/kernel';
import {jumpGlowProgress} from '../game/jump-glow-progress';
import {JumpReadySignal,jumpReadyFlash} from '../game/jump-ready-signal';
import AbilityTubeButton from './AbilityTubeButton.vue';
const props=defineProps<{equipped:boolean;snapshot:WorldState|null;locale:string;disabled:boolean;game:{jumpEnabled?:boolean;jumpCooldownSec?:number;jumpDurationSec?:number}}>();
defineEmits<{open:[]}>();
const signal=new JumpReadySignal();
// Observe simulation time, never wall time. Pauses and new rounds remain exact.
watch(()=>[props.snapshot,props.equipped] as const,([s,equipped])=>{
  if(!s){signal.reset();return;}
  signal.observe(equipped&&s.jumpEnabled===true&&props.game.jumpEnabled===true,
    Math.max(s.jumpCooldownMs,s.jumpRemainingMs??NaN),s.timeMs);
},{immediate:true,flush:'sync'});
const remaining=computed(()=>Math.max(0,props.snapshot?.jumpCooldownMs??0,props.snapshot?.jumpRemainingMs??0));
const active=computed(()=>props.equipped&&remaining.value===0);
const progress=computed(()=>!props.equipped?0:active.value?1:props.snapshot?jumpGlowProgress(props.snapshot,props.game):0);
const flash=computed(()=>{void props.snapshot;return active.value?jumpReadyFlash(signal.ageMs,matchMedia('(prefers-reduced-motion: reduce)').matches):0;});
const status=computed(()=>{const ru=props.locale==='ru';return !props.equipped?(ru?'Выкл.':'Off'):active.value?(ru?'Готов':'Ready'):`${(remaining.value/1000).toFixed(1).replace('.',ru?',':'.')} ${ru?'с':'s'}`;});
const phase=computed(()=>!props.equipped?'off':active.value?'ready':(props.snapshot?.jumpRemainingMs??0)>0&&(props.snapshot?.jumpCooldownMs??0)===0?'flight':'cooling');
</script>
<template><AbilityTubeButton class="jump-indicator" kind="jump" :locale="locale" :status="status" :phase="phase" :progress="progress" :flash="flash" :disabled="disabled" @open="$emit('open')"/></template>
