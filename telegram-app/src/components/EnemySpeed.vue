<script setup lang="ts">
import {computed,ref,watch,onBeforeUnmount} from 'vue';
import {world,state} from '../services/game-store';
const fieldRadius=computed(()=>Math.max(0,Math.min(190,state.config?.config.field.cornerRadius??18)));
const fill=computed(()=>Math.min(100,Math.max(0,(world.value?.brake?.targetSpeed??0)/150*100)));
const tail=ref<{start:number;width:number}|null>(null),fading=ref(false);let hold:ReturnType<typeof setTimeout>|undefined,clear:ReturnType<typeof setTimeout>|undefined;
function cancel(){clearTimeout(hold);clearTimeout(clear);tail.value=null;fading.value=false;}
watch(()=>world.value?.brake?.presses,(n,p)=>{cancel();const b=world.value?.brake;if(!b||!n||n===(p??0))return;const before=Math.min(100,b.beforeSpeed/150*100),after=Math.min(100,b.afterSpeed/150*100);tail.value={start:after,width:Math.max(0,before-after)};hold=setTimeout(()=>fading.value=true,110);clear=setTimeout(cancel,330);});
watch(()=>world.value?.timeMs,(n,p)=>{if(n===0||(n??0)<(p??0))cancel();});
onBeforeUnmount(cancel);
</script>
<template><div v-if="world?.brake?.speedBarEnabled" class="enemy-speed-slot" :style="{paddingInline:`${16+fieldRadius}px`}"><div class="enemy-speed" role="meter" :aria-label="state.locale==='ru'?'Скорость врагов':'Enemy speed'" aria-valuemin="0" aria-valuemax="150" :aria-valuenow="Math.round(fill*1.5)"><span class="enemy-speed-chamber" aria-hidden="true"><span class="enemy-speed-fill" :style="{width:`${fill}%`}"/><span v-if="tail" class="enemy-speed-loss" :class="{fading}" :style="{left:`${tail.start}%`,width:`${tail.width}%`}"/></span><small>{{state.locale==='ru'?'скорость врагов':'enemy speed'}}</small></div></div></template>
<style scoped>
.enemy-speed-slot{height:15px;padding:0 34px 6px;pointer-events:none;box-sizing:border-box}
.enemy-speed{position:relative;height:9px;box-sizing:border-box;overflow:hidden;border:1px solid #4c9baf;border-radius:3px;background:linear-gradient(#0d2e43,#041421 60%,#10364b);box-shadow:inset 0 1px 0 #bdf7ff45,0 1px 2px #0005;isolation:isolate}
.enemy-speed-chamber{position:absolute;inset:1px;border-radius:1px;overflow:hidden;background:linear-gradient(#285267,#102d42 40%,#183e53);-webkit-mask-image:repeating-linear-gradient(112deg,#000 0 8px,transparent 8px 10px);mask-image:repeating-linear-gradient(112deg,#000 0 8px,transparent 8px 10px)}
.enemy-speed-fill,.enemy-speed-loss{position:absolute;inset:0 auto 0 0;box-shadow:inset 0 1px 0 #fff9,inset 0 -1px 1px #a6245266}
.enemy-speed-fill{background:linear-gradient(#ffe2dc,#ffb0b5 25%,#ff8596 66%,#eb6a83);transition:width 60ms linear}
.enemy-speed-loss{background:linear-gradient(#e4ffd5,#aaffbd 25%,#68e59d 70%,#42ba87);transform-origin:left;z-index:1}
.enemy-speed-loss.fading{transform:scaleX(0);transition:transform 220ms ease-out}
.enemy-speed small{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-size:7px;line-height:1;color:#f0fbff;text-shadow:0 1px 1px #03101f,0 0 2px #03101f;z-index:2}
@media(prefers-reduced-motion:reduce){.enemy-speed-fill{transition:none}.enemy-speed-loss.fading{visibility:hidden;transition:none}}
</style>
