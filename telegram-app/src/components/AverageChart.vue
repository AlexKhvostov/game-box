<script setup lang="ts">
import { ref, computed, watch, nextTick, onMounted, onBeforeUnmount } from 'vue';
import { averageChart } from '../domain/average';
const props=defineProps<{data:ReturnType<typeof averageChart>;locale:string}>();
const host=ref<HTMLElement>(),scroll=ref<HTMLElement>(),available=ref(320),selected=ref(-1);
let observer:ResizeObserver|undefined;
const points=computed(()=>props.data.points),width=computed(()=>Math.max(available.value,points.value.length*5+60));
const top=computed(()=>{
  const max=Math.max(1000,...points.value.map(p=>Math.max(p.attempt.result!.timeMs,p.averageMs??0))),raw=Math.max(1000,max/4),magnitude=10**Math.floor(Math.log10(raw)),normalized=raw/magnitude;
  return (normalized<=1?1:normalized<=2?2:normalized<=5?5:10)*magnitude*4;
});
const x=(i:number)=>44+(width.value-56)*(i+.5)/points.value.length,y=(ms:number)=>200-186*ms/top.value;
const index=computed(()=>Math.min(points.value.length-1,selected.value<0?points.value.length-1:selected.value)),point=computed(()=>points.value[index.value]);
const line=computed(()=>points.value.map((p,i)=>p.averageMs===null?'':`${x(i)},${y(p.averageMs)}`).filter(Boolean).join(' '));
const label=(ms:number)=>{const sec=Math.round(ms/1000);return `${Math.floor(sec/60)}:${String(sec%60).padStart(2,'0')}`;};
const seconds=(ms:number|null)=>ms===null?'—':(ms/1000).toFixed(3).replace('.',props.locale==='ru'?',':'.');
function select(event:MouseEvent){const svg=event.currentTarget as SVGElement,r=svg.getBoundingClientRect(),pos=(event.clientX-r.x)*width.value/r.width;selected.value=Math.max(0,Math.min(points.value.length-1,Math.floor((pos-44)/(width.value-56)*points.value.length)));}
function key(event:KeyboardEvent){const step=event.key==='ArrowRight'?1:event.key==='ArrowLeft'?-1:0;if(!step)return;event.preventDefault();selected.value=Math.max(0,Math.min(points.value.length-1,index.value+step));}
function end(){void nextTick(()=>{if(scroll.value)scroll.value.scrollLeft=scroll.value.scrollWidth;});}
watch(()=>points.value.length,end);
onMounted(()=>{if(host.value){available.value=scroll.value!.clientWidth;observer=new ResizeObserver(()=>{available.value=scroll.value!.clientWidth;});observer.observe(host.value);}end();});
onBeforeUnmount(()=>observer?.disconnect());
</script>
<template>
  <div ref="host" class="chart-frame parity-chart"><small class="axis-caption">{{ locale==='ru'?'Время, мин:сек':'Time, min:sec' }}</small><div class="chart-plot-shell"><div ref="scroll" class="chart-scroll"><svg :viewBox="`0 0 ${width} 230`" :style="{width:`${width}px`}" class="average-chart" role="img" tabindex="0" :aria-label="`${locale==='ru'?'График попыток и среднего':'Attempts and average chart'}, ${index+1}: ${point?seconds(point.attempt.result!.timeMs):'—'}`" @click="select" @keydown="key"><defs><linearGradient id="chart-bar" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#64FBF5"/><stop offset="1" stop-color="#00A8CD"/></linearGradient><linearGradient id="chart-short" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#9CAFC0"/><stop offset="1" stop-color="#5F788D"/></linearGradient></defs><line v-for="i in 5" :key="i" x1="44" :y1="y((i-1)*top/4)" :x2="width-12" :y2="y((i-1)*top/4)" stroke="#17546b" stroke-dasharray="3 3"/><g v-for="(p,i) in points" :key="p.attempt.requestId"><rect :x="x(i)-Math.min(27,(width-56)/points.length*.55)/2" :y="Math.min(198,y(p.attempt.result!.timeMs))" :width="Math.min(27,(width-56)/points.length*.55)" :height="Math.max(2,200-y(p.attempt.result!.timeMs))" rx="3" :fill="p.attempt.result!.timeMs<1000?'url(#chart-short)':'url(#chart-bar)'" :opacity="p.inCurrentWindow?1:.32" :stroke="i===index?'#DAFFFF':p.attempt.result!.timeMs<1000?'#ADC3D6':'#52F7F4'" :stroke-width="i===index?2:1"/><text v-if="i===0||i===points.length-1||(i+1)%Math.max(1,Math.ceil(points.length/6))===0" :x="x(i)" y="220" text-anchor="middle">{{ i+1 }}</text></g><polyline :points="line" fill="none" stroke="#FFE56B44" stroke-width="6"/><polyline :points="line" fill="none" stroke="#FFE56B" stroke-width="2.4" stroke-linejoin="round"/><circle v-for="(p,i) in points.filter(p=>p.averageMs!==null)" :key="`point-${p.attempt.requestId}`" :cx="x(points.indexOf(p))" :cy="y(p.averageMs!)" :r="points.indexOf(p)===index?4:2.8" fill="#FFE56B" :data-point="i"/></svg></div><svg class="chart-axis" width="44" height="230" aria-hidden="true"><rect width="44" height="230" fill="#022235"/><text v-for="i in 5" :key="i" x="38" :y="y((i-1)*top/4)+4" text-anchor="end">{{ label((i-1)*top/4) }}</text></svg></div><small>{{ locale==='ru'?'Попытки · нажмите на столбик':'Attempts · tap a bar' }}</small></div>
  <p v-if="point" class="chart-selected"><span>{{ locale==='ru'?'Попытка':'Attempt' }} {{ index+1 }}: {{ seconds(point.attempt.result!.timeMs) }} {{ locale==='ru'?'с':'s' }}</span><b class="yellow">{{ locale==='ru'?'Среднее':'Average' }}: {{ seconds(point.averageMs) }} {{ locale==='ru'?'с':'s' }}</b></p>
</template>
