<script setup lang="ts">
import {computed,nextTick} from 'vue';
import {state} from '../services/game-store';
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
const connection=computed(()=>state.connection==='checking'?t('Проверяем соединение…','Checking the connection…'):state.connection==='offline'?t('Сервер пока недоступен','Cannot reach the server right now'):'');
const messages=computed(()=>[state.error,state.notice!==state.error?state.notice:'',connection.value,state.busy?t('Подтверждаем…','Confirming…'):''].filter(Boolean));
function dismiss(event:MouseEvent){const overlay=(event.currentTarget as HTMLElement).closest('.status-overlay'),returnTo=overlay?.closest<HTMLElement>('.game-window');const heldFocus=!!overlay?.contains(document.activeElement);state.notice='';state.error='';if(heldFocus&&returnTo)void nextTick(()=>returnTo.focus());}
</script>
<template>
  <aside v-if="messages.length" class="status-overlay" :class="{'has-dismiss':state.notice||state.error}" :role="state.error?'alert':'status'" aria-atomic="true">
    <div class="status-overlay-copy"><p v-for="(message,index) in messages" :key="index">{{message}}</p></div>
    <button v-if="state.notice||state.error" class="status-dismiss" :aria-label="t('Закрыть уведомление','Dismiss notification')" @click="dismiss">×</button>
  </aside>
</template>
