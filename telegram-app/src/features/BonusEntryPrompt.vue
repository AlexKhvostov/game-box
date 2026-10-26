<script setup lang="ts">
import {watch,onBeforeUnmount} from 'vue';
import {state,world,failedFinish,pendingInviteRewards,now,openScreen,refreshBonusEntryProfile} from '../services/game-store';
import {BonusEntryOffer} from '../services/bonus-entry';
import {rewardMotion} from '../services/energy-motion';
import {telegram} from '../platform/telegram';
const props=defineProps<{ready:boolean}>();
let offeredOwner:string|null=null;
const offer=new BonusEntryOffer(()=>{
  const b=state.profile?.wallet.simpleBonus;
  return {
    owner:state.profile?.id??null,revision:state.profile,
    safe:props.ready&&state.initialized&&!!state.config&&!state.screen&&!state.error&&!state.notice&&
      !state.busy&&!state.externalBusy&&!state.inviteNoticeOpen&&!pendingInviteRewards.value.length&&
      !rewardMotion.active&&!failedFinish.value&&!!world.value&&!world.value.playing&&!world.value.dead,
    ready:!!b&&Number.isFinite(b.nextAt)&&b.nextAt>=0&&Number.isFinite(b.reward)&&b.reward>0&&
      b.policy.periodSec>0&&b.nextAt<=now()&&state.profile?.wallet.energySubscription?.awaitingReconciliation!==true,
    alreadyOpen:state.screen==='energy',
  };
},refreshBonusEntryProfile,()=>{offeredOwner=state.profile?.id??null;openScreen('energy');});
watch(()=>state.profile?.id,owner=>{
  if(offeredOwner&&owner!==offeredOwner&&state.screen==='energy')openScreen('');
  if(owner!==offeredOwner)offeredOwner=null;
},{flush:'sync'});
const activity=()=>offer.setActive(!document.hidden&&telegram()?.isActive!==false);
document.addEventListener('visibilitychange',activity);
telegram()?.onEvent('activated',activity);telegram()?.onEvent('deactivated',activity);
activity();
watch(()=>[props.ready,state.initialized,state.profile,state.screen,state.error,state.notice,state.config,
  state.busy,state.externalBusy,state.inviteNoticeOpen,pendingInviteRewards.value.length,
  rewardMotion.active,failedFinish.value,world.value?.playing,world.value?.dead],()=>offer.check(),{immediate:true,flush:'post'});
onBeforeUnmount(()=>{
  offer.dispose();document.removeEventListener('visibilitychange',activity);
  telegram()?.offEvent('activated',activity);telegram()?.offEvent('deactivated',activity);
});
</script>
<template></template>
