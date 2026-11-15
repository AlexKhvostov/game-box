<script setup lang="ts">
import {ref,watch,onMounted,onBeforeUnmount} from 'vue';
import LoadingClock from './LoadingClock.vue';
import {settingsArtworkPool,type ArtworkState,type SettingsArtworkKind} from '../services/settings-artwork';
const props=withDefaults(defineProps<{kind:SettingsArtworkKind;locale:string;position?:string;active?:boolean}>(),{position:'50% 50%',active:true});
const state=ref<ArtworkState>({status:'loading',url:''});
let lease:ReturnType<typeof settingsArtworkPool.acquire>|undefined;
watch(()=>props.kind,kind=>{lease?.release();lease=settingsArtworkPool.acquire(kind,value=>{state.value=value;});},{immediate:true});
const retry=()=>{if(state.value.status==='error')lease?.retry();};
onMounted(()=>window.addEventListener('online',retry));
onBeforeUnmount(()=>{lease?.release();window.removeEventListener('online',retry);});
</script>
<template>
 <span class="settings-artwork" :data-settings-art="kind" :data-art-state="state.status" :aria-busy="state.status==='loading'" :role="state.status==='ready'?undefined:'status'">
  <span v-if="state.status==='ready'&&kind==='atlas'" class="settings-artwork-atlas" :style="{backgroundImage:'url('+JSON.stringify(state.url)+')',backgroundPosition:position}" aria-hidden="true"></span>
  <img v-else-if="state.status==='ready'" :src="state.url" alt="" @error="lease?.unavailable()">
  <span v-else class="settings-artwork-state">
   <LoadingClock v-if="state.status==='loading'" :size="kind==='sensitivity'?30:24" :active="active"/>
   <span v-if="state.status==='loading'" class="settings-artwork-sr">{{locale==='ru'?'Загрузка иллюстрации':'Loading illustration'}}</span>
   <button v-else type="button" class="settings-artwork-retry" :aria-label="locale==='ru'?'Не удалось загрузить иллюстрацию. Повторить':'Illustration unavailable. Retry'" @click.prevent.stop="retry"><span aria-hidden="true">⟳</span>{{locale==='ru'?'Повторить':'Retry'}}</button>
  </span>
 </span>
</template>
<style scoped>
.settings-artwork{position:relative;display:block;flex:none;overflow:hidden}.settings-artwork>img,.settings-artwork-atlas{position:absolute;inset:0;width:100%;height:100%;object-fit:contain}.settings-artwork-atlas{background-size:250%;background-repeat:no-repeat}.settings-artwork-state{position:absolute;inset:0;display:flex;align-items:center;justify-content:center}.settings-artwork-retry{display:flex;align-items:center;justify-content:center;flex-direction:column;gap:1px;min-height:40px;min-width:44px;max-width:100%;padding:2px;border:0;background:transparent;color:#a5e7ee;font:600 10px/1.2 Roboto,Arial,sans-serif;cursor:pointer}.settings-artwork-retry>span{font-size:23px;line-height:1}.settings-artwork-retry:focus-visible{outline:2px solid #89f3ef;outline-offset:-2px;border-radius:6px}.settings-artwork-sr{position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%)}
</style>
