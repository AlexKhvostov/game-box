<script setup lang="ts">
import {computed,nextTick} from 'vue';
import {state} from '../services/game-store';
import LoadingClock from './LoadingClock.vue';
const props=withDefaults(defineProps<{busy?:boolean;message?:string}>(),{busy:undefined});
const busy=computed(()=>props.busy??state.busy);
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
// Passive reachability changes never interrupt play; explicit failed actions
// and the result's pending/confirmed state remain visible where they belong.
const messages=computed(()=>[state.error,state.notice!==state.error?state.notice:'',props.message??(busy.value?t('Подтверждаем…','Confirming…'):'')].filter(Boolean));
function dismiss(event:MouseEvent){const overlay=(event.currentTarget as HTMLElement).closest('.status-overlay'),returnTo=overlay?.closest<HTMLElement>('.game-window');const heldFocus=!!overlay?.contains(document.activeElement);state.notice='';state.error='';if(heldFocus&&returnTo)void nextTick(()=>returnTo.focus({preventScroll:true}));}
</script>
<template>
  <aside v-if="messages.length" class="status-overlay" :class="{'has-dismiss':state.notice||state.error}" :role="state.error?'alert':'status'" aria-atomic="true">
    <div class="status-overlay-copy"><span v-if="busy" class="status-clock-slot"><LoadingClock :size="28"/></span><div class="status-messages"><p v-for="(message,index) in messages" :key="index">{{message}}</p></div></div>
    <button v-if="state.notice||state.error" class="status-dismiss" :aria-label="t('Закрыть уведомление','Dismiss notification')" @click="dismiss">×</button>
  </aside>
</template>
<style scoped>.status-clock-slot{display:flex;align-items:center;justify-content:center;width:36px;height:32px;flex:none}</style>
