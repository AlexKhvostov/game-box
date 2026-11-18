<script setup lang="ts">
import {computed,ref,watch,onBeforeUnmount} from 'vue';
import AwardHost from './AwardHost.vue';
import {state,world,impactActive,energy,failedFinish,pendingAwards,pendingLevels,markAwardPresented,markLevelPresented,openScreen,refreshAchievements,errorText} from '../services/game-store';
import {awardFlow} from '../services/award-flow';
import {emitResultReward} from '../services/reward-events';
import {registerOverlayBack} from '../services/ui-overlays';
import {awardVolume} from '../platform/audio';
import {telegram} from '../platform/telegram';
import type {AwardPresentationReceipt} from '../domain/achievement-presentation';
const props=defineProps<{ready:boolean}>();
const receipt=ref<AwardPresentationReceipt|null>(null),level=ref<number|null>(null),prepared=ref(false),active=ref(false),foreground=ref(!document.hidden),owner=ref('');
let removeBack:(()=>void)|undefined,ownsBusy=false,collectionShown=false;const pausedForCollection=ref(false);
const safe=computed(()=>!pausedForCollection.value&&props.ready&&state.initialized&&foreground.value&&!world.value?.playing&&!impactActive.value&&!state.inviteNoticeOpen&&(!state.externalBusy||ownsBusy)&&!state.busy&&
  (state.screen===''&&!world.value?.dead||state.screen==='result'&&!state.bestResult&&!failedFinish.value&&awardFlow.presentationAllowed&&state.resultId===awardFlow.runId));
const next=computed(()=>{const r=pendingAwards.value.find(r=>r.id!==receipt.value?.id);return r&&state.profile?{...r,owner:state.profile.id,after:energy.value,runId:r.runId??undefined}:null;});
function setBusy(value:boolean){if(value&&!ownsBusy){ownsBusy=true;state.externalBusy=true;}else if(!value&&ownsBusy){ownsBusy=false;state.externalBusy=false;}}
function reset(){owner.value='';active.value=false;receipt.value=null;level.value=null;prepared.value=false;removeBack?.();removeBack=undefined;setBusy(false);}
function close(_id?:string,reason?:string){if(receipt.value)try{markAwardPresented(receipt.value.id,owner.value);}catch(e){state.error=errorText(e);return;}
 if(reason==='collection'){pausedForCollection.value=true;collectionShown=false;reset();openScreen('achievements',state.screen==='result'?'result':'');return;}
 reset();choose();void refreshAchievements().catch(()=>{});}
watch(()=>state.screen,screen=>{if(!pausedForCollection.value)return;if(screen==='achievements')collectionShown=true;else if(collectionShown){pausedForCollection.value=false;collectionShown=false;choose();}});

function presented(id:string){if(id!==receipt.value?.id||owner.value!==state.profile?.id)return;try{markAwardPresented(id,owner.value);}catch(e){state.error=errorText(e);reset();}}
function levelClose(value:number){if(value!==level.value)return;try{markLevelPresented(value,owner.value);close();}catch(e){state.error=errorText(e);reset();}}
function activate(){if(active.value||!safe.value)return;if(receipt.value&&(!pendingAwards.value.some(r=>r.id===receipt.value?.id)||(receipt.value.awardId.includes('-cups-')&&!state.presentation.cupAutoCelebrationsEnabled))){choose();return;}if(receipt.value&&!prepared.value)return;if(!receipt.value&&!level.value)return;try{if(receipt.value)markAwardPresented(receipt.value.id,owner.value);else if(level.value)markLevelPresented(level.value,owner.value);}catch(e){state.error=errorText(e);return;}active.value=true;setBusy(true);removeBack??=registerOverlayBack(()=>level.value?levelClose(level.value):close(),'achievement_award');}
function choose(){if(!state.profile||!props.ready||world.value?.playing||impactActive.value)return;if(!state.presentation.cupAutoCelebrationsEnabled){try{for(const r of pendingAwards.value.filter(r=>r.awardId.includes('-cups-')))markAwardPresented(r.id,state.profile.id);}catch(e){state.error=errorText(e);reset();return;}}if(!active.value&&receipt.value&&!pendingAwards.value.some(r=>r.id===receipt.value?.id))reset();if(!receipt.value&&!level.value){const r=pendingAwards.value[0];owner.value=state.profile.id;if(r){receipt.value={...r,owner:owner.value,after:energy.value,runId:r.runId??undefined};prepared.value=false;}else if(pendingLevels.value.length)level.value=pendingLevels.value[0]!;}activate();}
function preparedAward(id:string,ready:boolean){if(id!==receipt.value?.id)return;prepared.value=ready;activate();}
function energyVisual(e:{id:string;amount:number;source:HTMLElement}){if(e.id!==receipt.value?.id||owner.value!==state.profile?.id||e.amount<=0)return;emitResultReward({key:e.id,owner:owner.value,amount:e.amount,after:energy.value,provisional:true,kind:'award',source:e.source});}
watch(()=>[props.ready,state.profile?.id,pendingAwards.value.map(r=>r.id).join(','),pendingLevels.value.join(','),state.presentation.cupAutoCelebrationsEnabled,safe.value,awardFlow.presentationAllowed,world.value?.dead,world.value?.playing,impactActive.value],()=>{if(owner.value&&owner.value!==state.profile?.id){pausedForCollection.value=false;collectionShown=false;reset();choose();return;}if(world.value?.playing||impactActive.value){reset();return;}choose();},{immediate:true,flush:'post'});
const activity=()=>{foreground.value=!document.hidden&&telegram()?.isActive!==false;};document.addEventListener('visibilitychange',activity);telegram()?.onEvent('activated',activity);telegram()?.onEvent('deactivated',activity);
onBeforeUnmount(()=>{reset();document.removeEventListener('visibilitychange',activity);telegram()?.offEvent('activated',activity);telegram()?.offEvent('deactivated',activity);});
</script>
<template><AwardHost :receipt="receipt" :prepare-next="next" :level="level" :locale="state.locale" :muted="!state.preferences.sound" :volume="awardVolume('medal')" :level-volume="awardVolume('level')" :active="active" @prepared="preparedAward" @presented="presented" @close="close" @level-close="levelClose" @level-presented="(value)=>markLevelPresented(value,owner)" @energy="energyVisual"/></template>
