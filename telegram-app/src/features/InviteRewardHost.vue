<script setup lang="ts">
import {ref,watch,nextTick,onBeforeUnmount} from 'vue';
import GameWindow from '../components/GameWindow.vue';
import EnergyAmount from '../components/EnergyAmount.vue';
import {state,world,pendingInviteRewards,inviteWasPresented,acknowledgeInviteReward,errorText} from '../services/game-store';
import {emitResultReward} from '../services/reward-events';
import {rewardMotion} from '../services/energy-motion';
import {registerOverlayBack} from '../services/ui-overlays';
import {telegram} from '../platform/telegram';
import type {InviteRewardNotice} from '../domain/invite-rewards';
const props=defineProps<{ready:boolean}>();
const current=ref<InviteRewardNotice|null>(null),foreground=ref(!document.hidden&&telegram()?.isActive!==false);
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
let releaseBack:(()=>void)|undefined;
function hide(){current.value=null;state.inviteNoticeOpen=false;releaseBack?.();releaseBack=undefined;}
function close(){
  if(!current.value)return;
  try{acknowledgeInviteReward(current.value.id);hide();}
  catch(error){state.notice=errorText(error);}
}
function safe(){return props.ready&&state.initialized&&foreground.value&&!world.value?.playing&&!state.busy&&!state.externalBusy&&['','result'].includes(state.screen);}
watch(()=>[pendingInviteRewards.value,state.profile?.id,state.screen,!!world.value?.playing,state.busy,state.externalBusy,props.ready,foreground.value,rewardMotion.active],async()=>{
  if(current.value){if(!safe()||!pendingInviteRewards.value.some(n=>n.id===current.value!.id))hide();else return;}
  if(!safe()||rewardMotion.active)return;
  const notice=pendingInviteRewards.value[0],owner=state.profile?.id;
  if(!notice||!owner)return;
  current.value=notice;state.inviteNoticeOpen=true;releaseBack=registerOverlayBack(close,'invite-reward');
  await nextTick();
  if(current.value?.id===notice.id&&safe()&&!inviteWasPresented(notice.id)&&notice.amount>0){
    emitResultReward({owner,key:notice.id,amount:notice.amount,after:state.profile!.wallet.energy,provisional:false,kind:'invite'});
  }
},{immediate:true,flush:'post'});
function activity(){foreground.value=!document.hidden&&telegram()?.isActive!==false;}
document.addEventListener('visibilitychange',activity);telegram()?.onEvent('activated',activity);telegram()?.onEvent('deactivated',activity);
onBeforeUnmount(()=>{hide();document.removeEventListener('visibilitychange',activity);telegram()?.offEvent('activated',activity);telegram()?.offEvent('deactivated',activity);});
function friend(){const n=current.value;return n?.friendId&&state.profile?.hiddenPlayers?.includes(n.friendId)?t('Скрытое имя','Hidden name'):n?.friendName||t('друг','your friend');}
</script>
<template>
  <GameWindow v-if="current" class="invite-reward-window" :data-invite-reward-id="current.id" :data-role="current.role" :title="t('Бонус за приглашение','Invitation bonus')">
    <div class="invite-reward-scene" aria-hidden="true"><img src="/assets/branding/ui/hero-ready-v1.png" alt=""><img src="/assets/branding/ui/hero-ready-v1.png" alt=""><span>ϟ</span></div>
    <div class="invite-reward-copy"><div class="invite-reward-reason">{{current.role==='inviter'?t('ВЫ ПРИГЛАСИЛИ ДРУГА','YOU INVITED A FRIEND'):t('ВАС ПРИГЛАСИЛИ','YOU WERE INVITED')}}</div>
    <h2>{{current.role==='inviter'?t('Друг присоединился!','Your friend joined!'):t('Добро пожаловать!','Welcome!')}}</h2>
    <p>{{current.role==='inviter'?t(`Игрок ${friend()} завершил игру по вашему приглашению.`,`${friend()} completed a game through your invitation.`):t(`Вы завершили игру по приглашению игрока ${friend()}.`,`You completed a game after an invitation from ${friend()}.`)}}</p></div>
    <EnergyAmount class="invite-reward-amount" :amount="current.amount" prefix="+"/>
    <p class="invite-reward-caption">{{t('энергии за приглашение','energy for the invitation')}}</p>
    <button class="primary full invite-reward-ok" @click="close">{{t('Отлично!','Great!')}}</button>
    <p class="invite-reward-hint">{{t('Энергия уже на балансе','Energy is already on your balance')}}</p>
  </GameWindow>
</template>
<style>
.invite-reward-window{z-index:60!important}.invite-reward-window .game-window{width:100%;max-width:360px}.invite-reward-window .window-header{padding:9px 16px;border-bottom:1px solid #38bedb}.invite-reward-window .window-header h1{font-size:18px}.invite-reward-window .window-body{padding:8px 16px 13px;text-align:center}
.invite-reward-scene{height:108px;display:flex;align-items:center;justify-content:center;position:relative}.invite-reward-scene img{width:100px;height:100px;object-fit:contain;transform:rotate(-8deg)}.invite-reward-scene img+img{width:96px;transform:rotate(10deg);filter:hue-rotate(24deg)}.invite-reward-scene span{position:absolute;bottom:0;font-size:40px;color:#fff2b4}
.invite-reward-reason{font-size:10px;letter-spacing:1.1px;font-weight:800;color:#79f1f5;margin:8px 0}.invite-reward-copy h2{font-size:23px;font-weight:900;line-height:1.15;margin:8px 0 7px}.invite-reward-copy p{font-size:12px;line-height:1.5;color:#a9cbe4;margin:0;overflow-wrap:anywhere}
.invite-reward-window .invite-reward-amount{justify-content:center;font-size:52px;font-weight:900;line-height:1.1;margin-top:12px;min-height:57px}.invite-reward-caption{font-size:11px;color:#a9cbe4;margin:0 0 13px}.invite-reward-ok{height:48px;min-height:48px;font-size:17px;font-weight:800}.invite-reward-hint{font-size:9px;color:#a9cbe4;margin:7px 0 0}
</style>
