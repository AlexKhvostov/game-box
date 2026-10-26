<script setup lang="ts">
import {computed} from 'vue';
import {neonTubePath,neonTubeProgress} from '../game/neon-tube';
const props=withDefaults(defineProps<{progress:number;state?:string;flash?:number}>(),{state:'cooling',flash:0});
const path=neonTubePath();
const amount=computed(()=>neonTubeProgress(props.progress));
</script>
<template>
  <svg class="neon-tube" viewBox="0 0 208 88" preserveAspectRatio="none" :data-neon-state="state" :data-neon-empty="amount===0" :data-neon-progress="amount" :style="{'--tube-flash':neonTubeProgress(flash)}" aria-hidden="true">
    <path v-for="layer in ['casing','glass','channel']" :key="layer" :class="`tube-${layer}`" :d="path"/>
    <path v-for="layer in ['bloom','fill','core']" :key="layer" :class="`tube-${layer} tube-charge`" :d="path" pathLength="1" :stroke-dasharray="`${amount} 1`"/>
  </svg>
</template>
<style scoped>
.neon-tube{position:absolute;inset:0;width:100%;height:100%;fill:none;overflow:visible;pointer-events:none}
path{stroke-linecap:round;stroke-linejoin:round}.tube-casing{stroke:#0a2239;stroke-width:11}.tube-glass{stroke:#3c7798;stroke-width:8.6}.tube-channel{stroke:#061e38;stroke-width:6.2}
.tube-bloom{stroke:#16dbff;stroke-width:10;opacity:.28;filter:drop-shadow(0 0 3px #00d6ff)}.tube-fill{stroke:#22d9f4;stroke-width:5.8;filter:drop-shadow(0 0 1px #3eecff)}.tube-core{stroke:#c1ffff;stroke-width:1.9;opacity:.95}
[data-neon-state=ready] .tube-fill{stroke:#91f6ff;stroke-width:calc(5.8px + var(--tube-flash)*1.5px)}[data-neon-state=ready] .tube-core{stroke:#e9ffff}
[data-neon-empty=true] .tube-charge{visibility:hidden}[data-neon-state=off] .tube-glass,[data-neon-state=spent] .tube-glass{stroke:#2b4f69}
@media(prefers-reduced-motion:reduce){.neon-tube{--tube-flash:0!important}}
</style>
