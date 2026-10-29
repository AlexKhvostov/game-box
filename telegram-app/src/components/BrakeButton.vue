<script setup lang="ts">
import {computed,ref,useId,watch,onBeforeUnmount} from 'vue';
const props=defineProps<{ready:boolean;remaining:number;cooldown:number;running:boolean;ended:boolean;pressed:boolean;locale:string}>();
const emit=defineEmits<{press:[]}>(),id=useId(),flash=ref(false);
let flashTimer:ReturnType<typeof setTimeout>|undefined;
const skin=computed(()=>props.pressed?'pressed':props.ready?'ready':'charging');
const progress=computed(()=>props.ready||props.pressed?1:Math.min(1,Math.max(0,1-props.remaining/Math.max(.1,props.cooldown))));
const timer=computed(()=>((Math.ceil(Math.max(.1,props.remaining)*10-1e-9))/10).toFixed(1).replace('.',props.locale==='ru'?',':'.'));
const label=computed(()=>props.ended?(props.locale==='ru'?'Проба завершена':'Test finished'):props.ready?(props.locale==='ru'?'Замедлить врагов':'Slow enemies'):(props.locale==='ru'?`Улитка: ${timer.value} с`:`Snail: ${timer.value} s`));
watch(()=>props.ready,(ready,before)=>{clearTimeout(flashTimer);flash.value=ready&&!before;flashTimer=setTimeout(()=>flash.value=false,520);});
onBeforeUnmount(()=>clearTimeout(flashTimer));
</script>
<template>
 <button type="button" class="pace-brake" :class="{'pace-brake-flash':flash}" :data-state="skin" :disabled="!ready||!running||ended" :aria-label="label" @click="emit('press')">
  <svg viewBox="0 0 100 100" aria-hidden="true"><defs><linearGradient :id="id+'-glass'" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#194558"/><stop offset="1" stop-color="#103247"/></linearGradient><linearGradient :id="id+'-mint'" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#b3e9d3"/><stop offset="1" stop-color="#95dabe"/></linearGradient></defs>
   <rect x="5" y="5" width="90" height="90" rx="16" :fill="`url(#${id}-glass)`" opacity=".95"/><path d="M9 25V20Q9 9 21 9H27Q32 9 28 14L14 28Q9 33 9 25Z" fill="#c2e9ef" opacity=".13"/><rect class="pace-brake-rim" x="5" y="5" width="90" height="90" rx="16"/>
   <g v-if="skin==='charging'&&!ended"><circle cx="50" cy="47" r="33" fill="none" stroke="#31576c" stroke-width="4"/><circle cx="50" cy="47" r="33" pathLength="100" transform="rotate(-90 50 47)" fill="none" stroke="#74c0dc" stroke-width="4" stroke-linecap="round" :stroke-dasharray="`${progress*100} 100`"/><text x="50" y="52" text-anchor="middle" class="pace-brake-timer">{{timer}}</text><text x="50" y="68" text-anchor="middle" class="pace-brake-unit">{{locale==='ru'?'с':'s'}}</text></g>
   <g v-else :fill="`url(#${id}-mint)`" color="#a5ddc3" stroke-linecap="round" stroke-linejoin="round" :opacity="ended ? .4 : 1"><path d="M20 70c8-5 14-8 27-8 10 0 15-6 17-16l2-7c2-6 10-6 12 0 4 15-8 32-24 35H20c-3 0-3-2 0-4Z"/><circle cx="39" cy="47" r="20"/><path d="M39 62c-17 0-21-20-9-28 11-7 24 3 20 13-3 8-14 9-17 2-2-5 4-9 8-5" fill="none" stroke="#164450" stroke-width="3.6"/><path d="m69 38 1-13m5 15 6-13" fill="none" stroke="currentColor" stroke-width="2.6"/><circle cx="70" cy="24" r="2.6"/><circle cx="82" cy="25" r="2.6"/></g>
  </svg>
 </button>
</template>
<style scoped>
.pace-brake{width:72px;height:72px;display:block;padding:0!important;min-height:0!important;border:0!important;border-radius:20%;background:none!important;box-shadow:none!important;cursor:pointer;touch-action:manipulation;flex:none}.pace-brake:disabled{cursor:default;opacity:1!important;filter:none!important}.pace-brake svg{display:block;width:100%;height:100%;overflow:visible}.pace-brake:focus-visible{outline:2px solid #c8e9ef;outline-offset:3px}.pace-brake-rim{fill:none;stroke:#52849a;stroke-width:1.6}.pace-brake[data-state=ready] .pace-brake-rim,.pace-brake[data-state=pressed] .pace-brake-rim{stroke:#81c6b4}.pace-brake-timer,.pace-brake-unit{fill:#cee4ec;font-family:'Segoe UI',Arial,sans-serif;font-variant-numeric:tabular-nums}.pace-brake-timer{font-size:26px;font-weight:650;letter-spacing:-.5px}.pace-brake-unit{font-size:13px}.pace-brake-flash{animation:pace-ready .52s ease-out 1}@keyframes pace-ready{0%,100%{filter:brightness(1)}35%{filter:brightness(1.3) drop-shadow(0 0 3px #a7e9cf80)}}@media(prefers-reduced-motion:reduce){.pace-brake-flash{animation:none}}
</style>
