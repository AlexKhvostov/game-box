<script setup lang="ts">
import {computed} from 'vue';
import {safeLevel} from '../domain/achievement-presentation';
const props=withDefaults(defineProps<{level:number;locale?:string;compact?:boolean;decorative?:boolean}>(),{locale:'ru'});
const value=computed(()=>safeLevel(props.level));
</script>
<template><span class="port-level-badge" :class="{'port-level-compact':compact}" role="img" :aria-label="decorative?undefined:`${locale==='ru'?'Уровень':'Level'} ${value}`" :aria-hidden="decorative?true:undefined"><img class="port-level-picture" :src="`/assets/achievements/levels/level-${value}.svg`" alt="" aria-hidden="true" width="90" height="84" decoding="sync"></span></template>
<style scoped>
/* Native385 fits a64×68 viewport, then paints the90×84 picture in OverflowBox.
   Contain inside this proportionally expanded box produces the same min(W/64,
   H/68) scale for every host, without a resize observer or an animation loop. */
.port-level-badge{display:block;position:relative;width:48px;height:54px;flex:none;overflow:visible}.port-level-compact{width:34px;height:43px}.port-level-badge>.port-level-picture{position:absolute;left:50%;top:50%;width:140.625%;height:123.5294118%;max-width:none;max-height:none;object-fit:contain;transform:translate(-50%,-50%);pointer-events:none}
</style>
