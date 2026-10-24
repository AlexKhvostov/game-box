<script setup lang="ts">
// Port of Android EnergyBoostTile and _BoostPainter (simple_energy_sheet.dart).
// MaterialIcons check_circle_outline_rounded U+F634; license: /fonts/materialicons_license.txt.
import {computed,ref,useId,onMounted,onBeforeUnmount} from 'vue';
import EnergyBolt from './EnergyBolt.vue';
const props=defineProps<{tier:number;locale:string;busy?:boolean}>();
defineEmits<{open:[]}>();
const tile=ref<HTMLButtonElement>(),labelText=ref<HTMLSpanElement>(),width=ref(90),height=ref(129.2),textWidth=ref(90),glowId=useId();
const maximum=computed(()=>props.tier>=5);
const label=computed(()=>props.locale==='ru'
  ?maximum.value?'Максимальный бонус. Подписка ×5':props.tier===2?'Увеличить бонус до ×5':'Увеличить размер бонуса. Подписка'
  :maximum.value?'Maximum bonus. Subscription ×5':props.tier===2?'Increase bonus to ×5':'Increase the bonus amount. Subscription');
const lines=computed(()=>props.locale==='ru'
  ?maximum.value?'Максимальный\nбонус':props.tier===2?'Увеличить\nдо ×5':'Увеличить\nразмер\nбонуса'
  :maximum.value?'Maximum\nbonus':props.tier===2?'Increase\nto ×5':'Increase\nthe bonus\namount');
const contentScale=computed(()=>Math.min(1,Math.max(0,width.value-8)/90));
const textFit=computed(()=>Math.min(1,90/Math.max(1,textWidth.value)));
const specks=computed(()=>Array.from({length:9},(_,i)=>({x:(i*31+9)%width.value,y:(i*23+18)%height.value,r:i%3===0?1.3:.7})));
let observer:ResizeObserver|undefined;
onMounted(()=>{observer=new ResizeObserver(entries=>{for(const entry of entries){if(entry.target===tile.value&&entry.contentRect.width>0){width.value=entry.contentRect.width;height.value=entry.contentRect.height;}else if(entry.target===labelText.value)textWidth.value=entry.contentRect.width;}});if(tile.value)observer.observe(tile.value);if(labelText.value)observer.observe(labelText.value);});
onBeforeUnmount(()=>observer?.disconnect());
</script>
<template>
  <button ref="tile" class="energy-boost-tile" :class="{maximum,upgraded:tier===2}" :disabled="maximum||busy" :aria-label="label" @click="$emit('open')">
    <svg v-if="!maximum" class="boost-decoration" :viewBox="`0 0 ${width} ${height}`" aria-hidden="true" focusable="false">
      <defs><radialGradient :id="glowId"><stop stop-color="#7676ff" stop-opacity=".467"/><stop offset="1" stop-color="#7676ff" stop-opacity="0"/></radialGradient></defs>
      <circle :cx="width/2" :cy="height*.27" :r="width*.47" :fill="`url(#${glowId})`"/>
      <g v-for="x in [.15,.85]" :key="x" fill="none" stroke="#83dfff" stroke-width="2">
        <path :d="`M${width*x-6} ${height*.32}L${width*x} ${height*.25}L${width*x+6} ${height*.32}`" stroke-linecap="round"/>
        <path :d="`M${width*x-6} ${height*.32-8}L${width*x} ${height*.25-8}L${width*x+6} ${height*.32-8}`" stroke-opacity=".467"/>
      </g>
      <path :d="`M10 3H${width-10}`" stroke="#d6f9ff" stroke-opacity=".6"/>
      <circle v-for="(p,i) in specks" :key="i" :cx="p.x" :cy="p.y" :r="p.r" fill="#aae8ff" fill-opacity=".533"/>
    </svg>
    <span class="boost-content" :style="{transform:`translate(-50%,-50%) scale(${contentScale})`}" aria-hidden="true">
      <svg v-if="maximum" class="boost-icon" viewBox="0 0 24 24" fill="currentColor" focusable="false"><path d="M12.0 2.015625C6.46875 2.015625 2.015625 6.46875 2.015625 12.0C2.015625 17.53125 6.46875 21.984375 12.0 21.984375C17.53125 21.984375 21.984375 17.53125 21.984375 12.0C21.984375 6.46875 17.53125 2.015625 12.0 2.015625ZM12.0 20.015625C7.59375 20.015625 3.984375 16.40625 3.984375 12.0C3.984375 7.59375 7.59375 3.984375 12.0 3.984375C16.40625 3.984375 20.015625 7.59375 20.015625 12.0C20.015625 16.40625 16.40625 20.015625 12.0 20.015625ZM15.890625 8.296875 9.984375 14.15625 8.109375 12.28125C7.734375 11.90625 7.078125 11.90625 6.703125 12.28125C6.328125 12.703125 6.328125 13.3125 6.703125 13.6875L9.28125 16.3125C9.703125 16.6875 10.3125 16.6875 10.6875 16.3125L17.296875 9.703125C17.671875 9.328125 17.671875 8.671875 17.296875 8.296875C16.921875 7.921875 16.265625 7.921875 15.890625 8.296875Z"/></svg>
      <EnergyBolt v-else class="boost-icon"/>
      <span class="boost-label-fit" :style="{height:`${lines.split('\n').length*16.8*textFit}px`}"><span ref="labelText" class="boost-label" :style="{transform:`translateX(-50%) scale(${textFit})`}">{{lines}}</span></span>
    </span>
  </button>
</template>
<style scoped>
.energy-boost-tile{position:relative;display:block;flex-shrink:0;width:100%;height:132px;padding:0;overflow:hidden;border:1.4px solid #8ef4ff;border-radius:15px;outline:0;background:linear-gradient(135deg,#354485,#132d56,#06283f);box-shadow:0 0 14px #5c66ff66,0 4px 5px #020e24aa;color:#f1fcff}
.energy-boost-tile.upgraded{border-color:#80f7c2}
.energy-boost-tile.maximum{border-color:#a5cae859;background:linear-gradient(135deg,#152d40,#10283a);box-shadow:none;color:#a5cae8}
.energy-boost-tile:disabled{opacity:1}
.energy-boost-tile:focus-visible{outline:2px solid #f1fcff;outline-offset:3px}
.boost-decoration{position:absolute;inset:0;width:100%;height:100%;pointer-events:none}
.boost-content{position:absolute;left:50%;top:50%;width:90px;display:flex;align-items:center;flex-direction:column;gap:8px;pointer-events:none}
.boost-icon{display:block;flex-shrink:0;width:38px;height:38px;color:#ffee73;filter:drop-shadow(0 0 8px #ffaa35)}
.maximum .boost-icon{color:#a5cae8;filter:none}
.boost-label-fit{position:relative;width:90px}
.boost-label{position:absolute;left:50%;top:0;display:block;width:max-content;transform-origin:top center;white-space:pre;text-align:center;font-family:RobotoResult,Roboto,sans-serif;font-size:15px;line-height:1.12;font-weight:900;text-shadow:0 0 5px #54e9ff66}
.maximum .boost-label{text-shadow:none}
</style>
