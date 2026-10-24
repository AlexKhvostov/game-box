<script setup lang="ts">
import {computed} from 'vue';
import type {WorldState} from '../domain/kernel';
import {helmetFlash,helmetBright,helmetDim} from '../game/helmet';
import GameArt from './GameArt.vue';
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
</script>
<template>
  <button class="helmet-indicator" :class="{active}" :disabled="disabled" :aria-label="`${locale==='ru'?'Шлем':'Helmet'}: ${status}`" @click="$emit('open')">
    <span class="helmet-icon"><GameArt src="/assets/branding/ui/simple-energy-helmet.png"/>
      <svg viewBox="0 0 34 34" aria-hidden="true"><circle class="helmet-track" cx="17" cy="17" r="14.5"/><circle v-if="progress>0" class="helmet-progress" cx="17" cy="17" r="14.5" pathLength="1" :stroke-dasharray="`${progress} 1`" :style="{stroke:active?(flash>.01?`rgb(${164+Math.round(73*flash)},${239+Math.round(16*flash)},255)`:helmetBright):helmetDim,strokeWidth:active?2.4+flash:2}"/></svg>
    </span><strong :style="{fontSize:`${Math.min(10.5,36/(status.length*.55))}px`}">{{status}}</strong>
  </button>
</template>
<style scoped>
.helmet-indicator{position:relative;display:flex;align-items:center;gap:2px;flex:none;width:72px;height:44px;padding:0;border:0;border-radius:22px;background:transparent;box-shadow:none;outline-offset:2px;color:#86aebd;opacity:1}
.helmet-indicator.active{color:#a4efff}.helmet-icon{position:relative;display:grid;place-items:center;width:34px;height:34px;flex:none}
.helmet-icon img{display:block;width:26px;height:26px;object-fit:cover;border-radius:50%;opacity:.4}.active .helmet-icon img{opacity:1}
.helmet-icon svg{position:absolute;inset:0;width:34px;height:34px;fill:none;transform:rotate(-90deg);pointer-events:none}
.helmet-track{stroke:#253f50;stroke-width:2.2}.helmet-progress{stroke-linecap:round}
.helmet-indicator strong{min-width:0;flex:1;font-size:10.5px;font-weight:500;text-align:center;white-space:nowrap;font-variant-numeric:tabular-nums}
</style>
