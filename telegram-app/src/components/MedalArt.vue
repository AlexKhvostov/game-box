<script setup lang="ts">
import {computed,ref,watch,onMounted,onBeforeUnmount,nextTick} from 'vue';
import LoadingClock from './LoadingClock.vue';
import {state} from '../services/game-store';
import {medalTileLayout} from '../generated/medal-tile-layout';
import {medalSheet,medalSheetTiles} from '../generated/medal-sheet';
const props=withDefaults(defineProps<{id:string;locked?:boolean;large?:boolean;thumbnail?:boolean;normalized?:boolean;alt?:string}>(),{normalized:true,alt:''});
const failed=ref(false),pending=ref(true),attempt=ref(0),image=ref<HTMLImageElement|null>(null);
const sheetFailed=ref(false);
// Only collection thumbnails share the sheet; detail art stays at768px.
const tile=computed(()=>!sheetFailed.value&&!props.large&&props.thumbnail?medalSheetTiles[props.id]:undefined);
const source=computed(()=>(tile.value?medalSheet.src:`/assets/achievements/art-${props.large?768:256}/${props.id}.webp`)+(attempt.value?`?artRetry=${attempt.value}`:''));
const spriteStyle=computed(()=>tile.value?{width:`${medalSheet.columns*100}%`,height:`${medalSheet.rows*100}%`,left:`${-tile.value[0]*100}%`,top:`${-tile.value[1]*100}%`}:undefined);
const retryLabel=computed(()=>state.locale==='en'?'Retry image':'Повторить картинку');
let timer:ReturnType<typeof setTimeout>|undefined;
function clearWait(){if(timer!==undefined){clearTimeout(timer);timer=undefined;}}
function loaded(event?:Event){if(event&&event.target!==image.value)return;clearWait();pending.value=false;failed.value=false;}
function unavailable(event?:Event){if(event&&event.target!==image.value)return;clearWait();if(tile.value){sheetFailed.value=true;pending.value=true;void nextTick(begin);return;}pending.value=false;failed.value=true;}
function begin(){clearWait();failed.value=false;pending.value=true;timer=setTimeout(()=>unavailable(),15000);if(image.value?.complete&&image.value.naturalWidth>0)loaded();}
function retryLoad(){if(!failed.value)return;attempt.value++;begin();}
watch(()=>[props.id,props.large,props.thumbnail],()=>{attempt.value=0;begin();},{flush:'post'});
onMounted(()=>{begin();window.addEventListener('online',retryLoad);});
onBeforeUnmount(()=>{clearWait();window.removeEventListener('online',retryLoad);});
const style=computed(()=>{const frame=props.normalized?medalTileLayout[props.id]:undefined;return frame?{transform:`translate(${frame.dx*100}%,${frame.dy*100}%) scale(${frame.scale})`}:undefined;});
</script>
<template><span class="port-medal-art" :class="{'port-medal-locked':locked,'port-art-unavailable':failed}"><span v-if="tile" class="port-medal-sprite" :style="style"><img ref="image" :key="source" :src="source" :class="{'port-art-pending-image':pending}" :alt="alt" :style="spriteStyle" :width="medalSheet.columns*medalSheet.size" :height="medalSheet.rows*medalSheet.size" decoding="async" @load="loaded" @error="unavailable"></span><img v-else ref="image" :key="source" :src="source" :class="{'port-art-pending-image':pending}" :alt="alt" :style="style" width="256" height="256" decoding="async" @load="loaded" @error="unavailable"><span v-if="pending" class="port-art-wait" role="status" :aria-label="state.locale==='en'?'Loading image':'Загрузка картинки'"><LoadingClock :size="large?36:22"/></span><span v-if="failed" class="port-art-fallback" role="button" tabindex="0" :aria-label="retryLabel" :title="retryLabel" @click.stop="retryLoad" @keydown.enter.stop.prevent="retryLoad" @keydown.space.stop.prevent="retryLoad">◇</span></span></template>
<style scoped>
.port-medal-sprite{display:block;position:relative;width:100%;height:100%;overflow:hidden;transform-origin:center}
.port-medal-sprite>img{position:absolute;max-width:none;max-height:none;object-fit:fill}
</style>
<style scoped>.port-medal-art{display:block;position:relative;width:48px;height:48px;flex:none;overflow:visible}.port-medal-art img{display:block;width:100%;height:100%;object-fit:contain;transform-origin:center}.port-medal-locked{opacity:.48;filter:grayscale(.3)}.port-art-unavailable img{visibility:hidden}.port-art-fallback{position:absolute;inset:0;display:grid;place-items:center;font-size:34px;color:#c7d5e3}.port-art-pending-image{visibility:hidden}.port-art-wait{position:absolute;inset:0;display:grid;place-items:center;pointer-events:none}.port-art-fallback[role=button]{cursor:pointer}</style>
