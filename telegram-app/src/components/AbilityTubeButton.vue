<script setup lang="ts">
import GameArt from './GameArt.vue';
import NeonTube from './NeonTube.vue';
defineProps<{kind:'helmet'|'jump';locale:string;status:string;phase:string;progress:number;flash:number;disabled:boolean}>();
defineEmits<{open:[]}>();
</script>
<template>
  <button class="ability-tube" :data-kind="kind" :data-state="phase" :disabled="disabled" :aria-label="`${kind==='helmet'?(locale==='ru'?'Шлем':'Helmet'):(locale==='ru'?'Прыжок':'Jump')}: ${status}`" @click="$emit('open')">
    <span class="tube-face" aria-hidden="true">
      <span class="tube-art"><GameArt :src="kind==='helmet'?'/assets/branding/ui/simple-energy-helmet.png':'/assets/branding/ui/jump-hud-a-v1.png'"/></span>
      <span class="tube-copy"><span class="tube-name">{{kind==='helmet'?(locale==='ru'?'Шлем':'Helmet'):(locale==='ru'?'Прыжок':'Jump')}}</span><strong class="tube-status">{{status}}</strong></span>
    </span>
    <NeonTube :progress="progress" :state="phase" :flash="flash"/>
  </button>
</template>
<style scoped>
.ability-tube{position:relative;display:block;flex:none;width:88px;height:44px;min-width:0;padding:0;border:0;border-radius:22px;background:none;box-shadow:none;isolation:isolate;color:#c1e6ef;container-type:inline-size;cursor:pointer;overflow:visible;opacity:1;font-family:inherit}
.ability-tube *{pointer-events:none}.ability-tube:focus-visible{outline:2px solid #c0f8ff;outline-offset:3px}.ability-tube:hover:not(:disabled) .tube-face{filter:brightness(1.08)}
.tube-face{position:absolute;inset:3px;border-radius:inherit;overflow:hidden;background:radial-gradient(ellipse at 35% 100%,#075278,#03162d 75%)}
.tube-art{position:absolute;inset:0 32% 0 0;overflow:hidden}.tube-art :deep(img){position:absolute;display:block;height:150%;max-width:none;width:auto;left:-11%;top:-25%;object-fit:cover;opacity:.9}
[data-kind=jump] .tube-art :deep(img){height:165%;top:-28%;left:0}.tube-art::after{content:"";position:absolute;inset:0;background:linear-gradient(90deg,transparent 55%,#03162d 100%)}
.tube-copy{position:absolute;left:59%;right:6%;inset-block:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:.6cqw;white-space:nowrap;color:#c8f5ff;text-shadow:0 1px 3px #01101e}
.tube-name{font-size:6px;font-size:clamp(6px,6.8cqw,8px);line-height:1.1;text-transform:uppercase;letter-spacing:.02em;color:#82c7dc;font-weight:650}.tube-status{font-size:9px;font-size:clamp(8px,10.6cqw,10px);line-height:1.14;font-weight:700;font-variant-numeric:tabular-nums}
[data-state=ready] .tube-copy{color:#caffff}[data-state=ready] .tube-art :deep(img){opacity:1}
[data-state=off] .tube-art :deep(img),[data-state=spent] .tube-art :deep(img){opacity:.3;filter:saturate(.35)}[data-state=off] .tube-copy,[data-state=spent] .tube-copy{color:#779db2}
</style>
