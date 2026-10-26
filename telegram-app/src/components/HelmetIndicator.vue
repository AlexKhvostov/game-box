<script setup lang="ts">
import {computed} from 'vue';
import type {WorldState} from '../domain/kernel';
import {helmetFlash} from '../game/helmet';
import AbilityTubeButton from './AbilityTubeButton.vue';
const props=defineProps<{equipped:boolean;snapshot:WorldState|null;locale:string;disabled:boolean}>();
defineEmits<{open:[]}>();
const active=computed(()=>props.equipped&&props.snapshot?.helmet===true);
const charge=computed(()=>props.snapshot?.helmetCharge);
const progress=computed(()=>!props.equipped?0:active.value?1:Math.max(0,Math.min(1,charge.value?.progress??0)));
const flash=computed(()=>props.snapshot?helmetFlash(props.snapshot,matchMedia('(prefers-reduced-motion: reduce)').matches):0);
const status=computed(()=>{
  const ru=props.locale==='ru';
  return !props.equipped?(ru?'Выкл.':'Off'):active.value?(ru?'Готов':'Ready'):(charge.value?.remainingMs??0)>0
    ?`${(charge.value!.remainingMs/1000).toFixed(1).replace('.',ru?',':'.')} ${ru?'с':'s'}`:(ru?'Разбит':'Spent');
});
const phase=computed(()=>!props.equipped?'off':active.value?'ready':(charge.value?.remainingMs??0)>0?'cooling':'spent');
</script>
<template><AbilityTubeButton class="helmet-indicator" kind="helmet" :locale="locale" :status="status" :phase="phase" :progress="progress" :flash="flash" :disabled="disabled" @open="$emit('open')"/></template>
