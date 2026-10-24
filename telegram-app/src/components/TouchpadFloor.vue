<script setup lang="ts">
import { computed } from 'vue';
const props = defineProps<{ height: number }>();
// Exact TouchpadGrid projection from the frozen Android painter.
const w = 540;
const grid = computed(() => { const h=Math.max(40,props.height), top=h*.04,bottom=h-9,near=w-6,columns=Math.max(6,Math.min(16,Math.round(near/56))),cell=near/columns,perspective=cell*(1-.22)/(bottom-top),depth=(1/.22-1)/perspective; return {h,top,bottom,columns,rows:Array.from({length:Math.max(0,Math.ceil(depth)-1)},(_,i)=>bottom-cell*(i+1)/(1+perspective*(i+1)))}; });
const path = computed(() => `M ${w*.39} ${grid.value.top} L ${w*.61} ${grid.value.top} L ${w-3} ${grid.value.bottom} Q ${w/2} ${grid.value.bottom+8} 3 ${grid.value.bottom} Z`);
</script>
<template><svg class="perspective-floor" :viewBox="`0 0 ${w} ${grid.h}`" :style="{height:`${grid.h}px`}" aria-hidden="true"><defs><linearGradient id="touchpad-fill" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#0D2C43"/><stop offset="1" stop-color="#16415B"/></linearGradient><clipPath id="touchpad-clip"><path :d="path"/></clipPath></defs><path :d="path" fill="url(#touchpad-fill)"/><g clip-path="url(#touchpad-clip)" stroke="#78BBD723" stroke-width="1"><line v-for="i in grid.columns-1" :key="i" :x1="w*.39+w*.22*i/grid.columns" :y1="grid.top" :x2="3+(w-6)*i/grid.columns" :y2="grid.bottom"/><line v-for="(y,i) in grid.rows" :key="`row-${i}`" x1="0" :y1="y" :x2="w" :y2="y"/></g><path :d="path" fill="none" stroke="#78BBD766" stroke-width="1.2"/><line :x1="w*.24" :y1="grid.bottom+2" :x2="w*.76" :y2="grid.bottom+2" stroke="#78BBD788" stroke-width="2" stroke-linecap="round"/></svg></template>
