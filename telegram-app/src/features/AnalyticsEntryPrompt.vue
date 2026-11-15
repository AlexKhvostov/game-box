<script setup lang="ts">
import {watch} from 'vue';
import {state,world,openScreen,pendingAwards,pendingLevels} from '../services/game-store';
import {ageBand} from '../platform/audience';
import {DurableStorage} from '../services/storage';
const props=defineProps<{ready:boolean}>(),storage=new DurableStorage();
watch(()=>[props.ready,state.initialized,state.screen,state.profile?.id,state.externalBusy,state.inviteNoticeOpen,world.value?.playing,world.value?.dead,pendingAwards.value.length,pendingLevels.value.length],()=>{
 if(!props.ready||!state.initialized||state.screen||state.error||state.externalBusy||state.inviteNoticeOpen||world.value?.playing||world.value?.dead||pendingAwards.value.length||pendingLevels.value.length||ageBand()!=='adult18plus')return;
 try{if(storage.get('analyticsPromptSeen',false))return;storage.set('analyticsPromptSeen',true);openScreen('analytics-consent');}catch{/* Storage failure does not grant consent or block the game. */}
},{immediate:true,flush:'post'});
</script>
<template></template>
