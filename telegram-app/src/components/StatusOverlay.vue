<script setup lang="ts">
import {computed,nextTick} from 'vue';
import {state} from '../services/game-store';
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
// Passive reachability changes never interrupt play; explicit failed actions
// and the result's pending/confirmed state remain visible where they belong.
const messages=computed(()=>[state.error,state.notice!==state.error?state.notice:'',state.busy?t('Подтверждаем…','Confirming…'):''].filter(Boolean));
function dismiss(event:MouseEvent){const overlay=(event.currentTarget as HTMLElement).closest('.status-overlay'),returnTo=overlay?.closest<HTMLElement>('.game-window');const heldFocus=!!overlay?.contains(document.activeElement);state.notice='';state.error='';if(heldFocus&&returnTo)void nextTick(()=>returnTo.focus({preventScroll:true}));}
</script>
<template>
  <aside v-if="messages.length" class="status-overlay" :class="{'has-dismiss':state.notice||state.error}" :role="state.error?'alert':'status'" aria-atomic="true">
    <div class="status-overlay-copy"><span v-if="state.busy" class="loading-spinner" aria-hidden="true"></span><div class="status-messages"><p v-for="(message,index) in messages" :key="index">{{message}}</p></div></div>
    <button v-if="state.notice||state.error" class="status-dismiss" :aria-label="t('Закрыть уведомление','Dismiss notification')" @click="dismiss">×</button>
  </aside>
</template>
