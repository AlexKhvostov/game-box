<script setup lang="ts">
import {computed,ref,watch,onBeforeUnmount} from 'vue';
import {world,state} from '../services/game-store';
const fill=computed(()=>Math.min(100,Math.max(0,(world.value?.brake?.targetSpeed??0)/150*100)));
const tail=ref<{start:number;width:number}|null>(null),fading=ref(false);let hold:ReturnType<typeof setTimeout>|undefined,clear:ReturnType<typeof setTimeout>|undefined;
function cancel(){clearTimeout(hold);clearTimeout(clear);tail.value=null;fading.value=false;}
watch(()=>world.value?.brake?.presses,(n,p)=>{cancel();const b=world.value?.brake;if(!b||!n||n===(p??0))return;const before=Math.min(100,b.beforeSpeed/150*100),after=Math.min(100,b.afterSpeed/150*100);tail.value={start:after,width:Math.max(0,before-after)};hold=setTimeout(()=>fading.value=true,110);clear=setTimeout(cancel,330);});
watch(()=>world.value?.timeMs,(n,p)=>{if(n===0||(n??0)<(p??0))cancel();});
onBeforeUnmount(cancel);
</script>
<template><div v-if="world?.brake?.speedBarEnabled" class="enemy-speed-slot"><div class="enemy-speed" role="meter" :aria-label="state.locale==='ru'?'Скорость врагов':'Enemy speed'" aria-valuemin="0" aria-valuemax="150" :aria-valuenow="Math.round(fill*1.5)"><span class="enemy-speed-fill" :style="{width:`${fill}%`}"/><span v-if="tail" class="enemy-speed-loss" :class="{fading}" :style="{left:`${tail.start}%`,width:`${tail.width}%`}"/><small>{{state.locale==='ru'?'скорость врагов':'enemy speed'}}</small></div></div></template>
<style scoped>
.enemy-speed-slot{height:14px;padding:0 16px 5px;pointer-events:none}.enemy-speed{position:relative;height:9px;overflow:hidden;border:1px solid #467785;border-radius:5px;background:#071f31;isolation:isolate}.enemy-speed-fill,.enemy-speed-loss{position:absolute;inset:0 auto 0 0}.enemy-speed-fill{background:linear-gradient(90deg,#ffc1c0,#ff8c95);transition:width 60ms linear}.enemy-speed-loss{background:linear-gradient(90deg,#c5ffb3,#68e59d);transform-origin:left;z-index:1}.enemy-speed-loss.fading{transform:scaleX(0);opacity:0;transition:transform 220ms ease-out,opacity 220ms ease-out}.enemy-speed small{position:absolute;inset:0;text-align:center;font-size:7px;line-height:7px;color:#f0fbff;text-shadow:0 1px 2px #061b2d;z-index:2}@media(prefers-reduced-motion:reduce){.enemy-speed-fill{transition:none}.enemy-speed-loss.fading{transform:none;transition:opacity 100ms}}
</style>
