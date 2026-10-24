<script setup lang="ts">
import {computed} from 'vue';
const props=defineProps<{amount:number;ready:boolean;fraction:number;timer:string;multiplier:number;pending:boolean;locale:string}>();
defineEmits<{claim:[]}>();
const r=computed(()=>props.ready?81:86),f=computed(()=>Math.min(1,Math.max(0,props.fraction)));
const end=computed(()=>-Math.PI/2+2*Math.PI*(1-f.value));
const sparkles=Array.from({length:35},(_,i)=>{const a=i*2.399963,d=88+(Math.sin(i*13.71)*.5+.5)*10;return{x:100+Math.cos(a)*d,y:100+Math.sin(a)*d,r:i%7===0?1.5:.6,a:.4+(Math.cos(i*3.2)*.5+.5)*.6};});
</script>
<template>
<button class="bonus-orb" :disabled="!ready||pending" :aria-label="ready?`${amount} ${locale==='ru'?'энергии. Забрать':'energy. Claim'}`:timer" @click="$emit('claim')"><svg viewBox="0 0 200 200" aria-hidden="true"><defs>
<radialGradient id="orb-fill" cx="40%" cy="40%" r="65%"><stop offset="0" :stop-color="ready?'#B49B31':'#0D3B62'"/><stop :offset="ready?'.24':'.5'" :stop-color="ready?'#64571D':'#00101F'"/><stop v-if="ready" offset=".67" stop-color="#10252C"/><stop offset="1" :stop-color="ready?'#DDAC1D':'#0B3554'"/></radialGradient>
<linearGradient id="orb-rim" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#FFF7A6"/><stop offset=".12" stop-color="#957016"/><stop offset=".57" stop-color="#171A16"/><stop offset="1" stop-color="#FFDB42"/></linearGradient>
<linearGradient id="bonus-bolt" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#FFFF94"/><stop offset=".5" stop-color="#FFF03B"/><stop offset="1" stop-color="#FFD52C"/></linearGradient>
<filter id="orb-glow"><feGaussianBlur stdDeviation="4"/></filter><filter id="orb-number-blur"><feGaussianBlur stdDeviation="1.3"/></filter><clipPath id="orb-clip"><circle cx="100" cy="100" :r="r-2"/></clipPath><path id="bolt-shape" d="M11 0 0 13 7 13 5 24 18 9 10 9Z"/></defs>
<circle cx="100" cy="100" :r="r*1.06" :fill="ready?'#FFD83C':'#79F1F5'" :opacity="ready?.36:.12" filter="url(#orb-glow)"/>
<template v-if="ready"><circle cx="100" cy="100" :r="r*1.14" fill="none" stroke="url(#orb-rim)" stroke-width="10"/><circle cx="100" cy="100" :r="r*1.14" fill="none" stroke="#FFC52A" stroke-width="7" filter="url(#orb-glow)"/><circle cx="100" cy="100" :r="r*1.14" fill="none" stroke="#FFF6B2" stroke-width="1.8"/><line v-for="i in 24" :key="i" :x1="100+Math.cos(i*Math.PI/12)*r*1.065" :y1="100+Math.sin(i*Math.PI/12)*r*1.065" :x2="100+Math.cos(i*Math.PI/12)*r*1.105" :y2="100+Math.sin(i*Math.PI/12)*r*1.105" stroke="#C7A855" :stroke-width="i%6===0?2:1"/></template>
<circle cx="100" cy="100" :r="r" fill="url(#orb-fill)"/>
<g v-if="ready" clip-path="url(#orb-clip)"><ellipse cx="100" :cy="100+r*.66" :rx="r*.95" :ry="r*.34" fill="#FFDC37" filter="url(#orb-glow)"/><ellipse :cx="100-r*.15" :cy="100-r*.68" :rx="r*.725" :ry="r*.1" fill="#FFF9BD77" filter="url(#orb-glow)"/></g>
<circle v-if="ready" cx="100" cy="100" :r="r-1" fill="none" stroke="#FFD529" stroke-width="6"/>
<circle v-for="i in 3" :key="i" cx="100" cy="100" :r="r-(i-1)*5" fill="none" :stroke="ready?'#FFED87':'#567A95'" :opacity="i===2?.4:1" :stroke-width="i===2?4:1.5"/>
<g v-if="!ready"><path v-if="f>0&&f<1" :d="`M100 100L${100+Math.cos(end)*(r-10)} ${100+Math.sin(end)*(r-10)}A${r-10} ${r-10} 0 ${f>.5?1:0} 1 100 ${110-r}Z`" fill="#1E456588"/><circle v-else-if="f===1" cx="100" cy="100" :r="r-10" fill="#1E456588"/><circle cx="100" cy="100" :r="r-2" fill="none" stroke="#79F1F5" stroke-width="4" :stroke-dasharray="`${2*Math.PI*(r-2)*(1-f)} ${2*Math.PI*(r-2)}`" transform="rotate(-90 100 100)"/><circle :cx="100+Math.cos(end)*(r-2)" :cy="100+Math.sin(end)*(r-2)" r="4" fill="white"/></g>
<circle v-for="(p,i) in sparkles.slice(0,ready?35:14)" :key="i" :cx="p.x" :cy="p.y" :r="p.r" :fill="ready?'#FFD83C':'#79F1F5'" :opacity="p.a"/>
<text v-if="multiplier>1" x="100" :y="ready?44:36" text-anchor="middle" fill="#FFFF94" font-size="20" font-weight="800">×{{multiplier}}</text>
<use v-if="ready" href="#bolt-shape" transform="translate(85.5 51) scale(1.61 1.75)" fill="url(#bonus-bolt)"/>
<g :opacity="ready?1:.35" :filter="ready?undefined:'url(#orb-number-blur)'"><text x="100" :y="ready?137:97" text-anchor="middle" fill="#FFF03B" :font-size="amount>999?34:45" font-weight="900">{{amount}}</text><use href="#bolt-shape" :transform="`translate(142 ${ready?94:54}) scale(1.22 1.625)`" fill="url(#bonus-bolt)"/></g>
<text v-if="ready" x="100" y="162" text-anchor="middle" fill="#061A2B" font-size="21" font-weight="900">{{pending?(locale==='ru'?'Проверяем…':'Checking…'):(locale==='ru'?'Забрать':'Claim')}}</text>
<g v-else><circle cx="100" cy="110" r="8" stroke="white" fill="none" stroke-width="1.6"/><path d="M100 104V110L104 113" stroke="white" fill="none" stroke-width="1.4"/><text x="100" y="148" text-anchor="middle" fill="white" font-size="26" font-weight="900">{{timer}}</text><text x="100" y="198" text-anchor="middle" fill="#A9CBE4" font-size="11">{{locale==='ru'?'Перезарядка':'Recharging'}}</text></g>
</svg></button>
</template>
