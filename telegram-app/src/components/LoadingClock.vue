<script setup lang="ts">
import {useId,ref,onMounted,onBeforeUnmount} from 'vue';
// Keep the approved clock usable by standalone public pages without app auth.
const telegram=()=>typeof window==='undefined'?undefined:window.Telegram?.WebApp;
withDefaults(defineProps<{size?:number;active?:boolean}>(),{size:28,active:true});
const id=useId().replace(/:/g,'');
const foreground=ref(typeof document==='undefined'||!document.hidden&&telegram()?.isActive!==false),activity=()=>foreground.value=!document.hidden&&telegram()?.isActive!==false;
onMounted(()=>{document.addEventListener('visibilitychange',activity);telegram()?.onEvent('activated',activity);telegram()?.onEvent('deactivated',activity);});
onBeforeUnmount(()=>{document.removeEventListener('visibilitychange',activity);telegram()?.offEvent('activated',activity);telegram()?.offEvent('deactivated',activity);});
</script>
<template>
 <svg class="loading-clock" :class="{stopped:!active||!foreground}" :style="{width:`${size}px`,height:`${size}px`}" viewBox="0 0 64 64" aria-hidden="true">
  <defs><linearGradient :id="`${id}-rim`" gradientUnits="userSpaceOnUse" x1="12" y1="5" x2="50" y2="59"><stop stop-color="#dcfff4"/><stop offset=".27" stop-color="#54e8d4"/><stop offset=".6" stop-color="#16829b"/><stop offset="1" stop-color="#76e7e6"/></linearGradient><radialGradient :id="`${id}-dial`" gradientUnits="userSpaceOnUse" cx="24" cy="19" r="40"><stop stop-color="#184c63"/><stop offset="1" stop-color="#061b30"/></radialGradient></defs>
  <circle cx="33" cy="35" r="29" fill="#00101e99"/><circle cx="32" cy="32" r="29" :fill="`url(#${id}-rim)`"/><circle cx="32" cy="32" r="25.5" :fill="`url(#${id}-dial)`" stroke="#9cfbeb" stroke-width=".7"/><circle cx="32" cy="32" r="23" fill="none" stroke="#397f92" stroke-width=".5"/>
  <path v-for="i in 12" :key="i" :transform="`rotate(${i*30} 32 32)`" :d="`M32 10v${i%3===0?5:3}`" :stroke="i%3===0?'#b5fff1':'#538f9f'" :stroke-width="i%3===0?2:1.4" stroke-linecap="round"/>
  <path d="M13 18A24 24 0 0 1 44 9" fill="none" stroke="#e4fff7b3" stroke-width="1.8" stroke-linecap="round"/>
  <g class="clock-hand"><path d="M32 39V15" stroke="#39c8cf33" stroke-width="6" stroke-linecap="round"/><path d="M32 38V15" stroke="#c6fff2" stroke-width="2.6" stroke-linecap="round"/></g><circle cx="32" cy="32" r="4" fill="#103f55" stroke="#92ffee" stroke-width="1.4"/><circle cx="31" cy="31" r="1.2" fill="#e0fff7"/>
 </svg>
</template>
<style scoped>
.loading-clock{display:inline-block;flex:none;vertical-align:middle}.clock-hand{transform-origin:32px 32px;animation:dial-turn 2s linear infinite}.stopped .clock-hand{animation-play-state:paused}@keyframes dial-turn{to{transform:rotate(360deg)}}@media(prefers-reduced-motion:reduce){.clock-hand{animation:none}}
</style>
