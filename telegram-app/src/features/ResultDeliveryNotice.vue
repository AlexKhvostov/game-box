<script setup lang="ts">
import {ref,watch,onBeforeUnmount} from 'vue';
import {telegram} from '../platform/telegram';
const props=defineProps<{attemptId:string;pending:boolean;locale:string}>();
const visible=ref(false),seen=new Set<string>();let timer:ReturnType<typeof setTimeout>|undefined;
function hide(){clearTimeout(timer);visible.value=false;}
function sync(){
  if(document.hidden||telegram()?.isActive===false){hide();return;}
  if(!props.pending){hide();return;}
  if(!props.attemptId||seen.has(props.attemptId))return;
  seen.add(props.attemptId);visible.value=true;clearTimeout(timer);timer=setTimeout(hide,2000);
}
watch(()=>[props.attemptId,props.pending],()=>{hide();sync();},{immediate:true});
document.addEventListener('visibilitychange',sync);telegram()?.onEvent('deactivated',hide);telegram()?.onEvent('activated',sync);
onBeforeUnmount(()=>{hide();document.removeEventListener('visibilitychange',sync);telegram()?.offEvent('deactivated',hide);telegram()?.offEvent('activated',sync);});
</script>
<template><p v-if="visible" class="result-delivery-notice" role="status">{{locale==='ru'?'Результат сохранён на устройстве. Отправим, когда появится связь.':'Result saved on this device. It will be sent when connected.'}}</p></template>
<style scoped>.result-delivery-notice{position:fixed;left:50%;bottom:12px;transform:translateX(-50%);z-index:75;max-width:calc(100% - 24px);padding:6px 12px;background:#061b2d99;border-radius:8px;color:#cfdfebcc;font-size:10px;line-height:1.3;text-align:center;pointer-events:none;margin:0}</style>
