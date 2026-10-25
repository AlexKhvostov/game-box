<script setup lang="ts">
import {computed,ref,watch,onBeforeUnmount} from 'vue';
import {analyticsOverlay} from '../services/analytics';
import EnergyAmount from './EnergyAmount.vue';
import GameIcon from './GameIcon.vue';
import {state,action,request,refreshInvites,moreInvites,openScreen} from '../services/game-store';
import {ensureResourceAge} from '../platform/audience';
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
const invite=computed(()=>state.invites);
const code=ref('');
const help=ref<HTMLDialogElement>();
const ownProgress=computed(()=>`${invite.value?.completedGames??0} / ${invite.value?.requiredGames??5}`);
watch([()=>state.profile?.id,()=>invite.value?.inviterAssigned,()=>invite.value?.inviterCode],()=>{code.value='';});
function copy(){const value=invite.value?.ownCode;if(!value)return;void navigator.clipboard.writeText(value).then(()=>state.notice=t('Скопировано','Copied')).catch(()=>state.error=t('Не удалось скопировать. Выделите код вручную.','Could not copy. Select the code manually.'));}
function name(row:any){return state.profile?.hiddenPlayers.includes(row.userId)?t('Скрытое имя','Hidden name'):row.nickname||t('Игрок','Player');}
function canAct(row:any){return !!row.userId&&row.userId!==state.profile?.id;}
function nameActions(row:any){if(!canAct(row))return;state.selectedPlayer={userId:row.userId,playerName:row.nickname||t('Игрок','Player')};openScreen('name-actions','friends');}
function waiting(row:any){return row.bonusStatus==='inviter_unavailable'?t('Пригласивший недоступен','Inviter unavailable'):row.identityReady||row.googleLinked?t('Вход подтверждён','Sign-in verified'):row.platform==='telegram'?t('Нужен вход в Telegram','Telegram sign-in needed'):t('Нужен вход в Google','Google sign-in needed');}
async function apply(){if(state.busy||invite.value?.inviterAssigned||!invite.value||!code.value.trim())return;await action(async()=>{if(!await ensureResourceAge())return;await request({action:'invites_bind',code:code.value.trim().toUpperCase()});await refreshInvites();});}
let stopHelpAnalytics:(()=>void)|undefined;
function releaseHelpAnalytics(){stopHelpAnalytics?.();stopHelpAnalytics=undefined;}
function showHelp(){help.value?.showModal();if(help.value?.open&&!stopHelpAnalytics)stopHelpAnalytics=analyticsOverlay('invitation_help');}
function closeHelp(){help.value?.close();releaseHelpAnalytics();}
function trap(event:KeyboardEvent){
  if(event.key!=='Tab')return;
  const buttons=Array.from(help.value?.querySelectorAll<HTMLButtonElement>('button:not([disabled])')??[]),first=buttons[0],last=buttons.at(-1);
  if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus();}
  else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first?.focus();}
}
onBeforeUnmount(closeHelp);
defineExpose({showHelp});
</script>
<template>
  <div class="compact-invites">
    <div class="ci-code"><span>{{t('Код','Code')}}</span><input readonly :value="invite?.ownCode??'—'" :aria-label="t('Ваш код приглашения','Your invite code')"><button v-analytics="{feature: 'copy_code', placement: 'friends'}" class="icon-button" :aria-label="t('Копировать код','Copy code')" :disabled="!invite" @click="copy"><GameIcon name="copy"/></button></div>
    <div class="ci-totals" :aria-label="t('Итоги приглашений','Invitation totals')"><span>{{t('Приглашено','Invited')}} <strong>{{invite?.invitedCount??'—'}}</strong></span><span>{{t('Получено','Received')}} <EnergyAmount v-if="invite" :amount="invite.rewardTotal"/><strong v-else>—</strong></span></div>
    <h2>{{t('Приглашённые друзья','Invited friends')}}</h2>
    <ul class="ci-list" :aria-label="t('Список приглашённых','Invited friends list')" tabindex="0">
      <li v-for="row in invite?.paidRows" :key="`paid-${row.id}`"><span class="ci-avatar" aria-hidden="true">{{Array.from(name(row))[0]}}</span><button v-analytics="{feature: 'name_actions', placement: 'friends'}" class="ci-name" :disabled="!canAct(row)" @click="nameActions(row)">{{name(row)}}</button><EnergyAmount :amount="row.energyEquivalent??row.amount??0" prefix="+"/><button v-analytics="{feature: 'name_actions', placement: 'friends'}" class="ci-menu" :aria-label="`${t('Действия с игроком','Actions for')} ${name(row)}`" :disabled="!canAct(row)" @click="nameActions(row)">⋯</button></li>
      <li v-for="row in invite?.pendingRows" :key="`pending-${row.id}`"><span class="ci-avatar" aria-hidden="true">{{Array.from(name(row))[0]}}</span><div class="ci-pending-name"><button v-analytics="{feature: 'name_actions', placement: 'friends'}" class="ci-name" :disabled="!canAct(row)" @click="nameActions(row)">{{name(row)}}</button><small>{{row.games??0}} / {{invite?.requiredGames??5}} {{t('игр','games')}} · {{waiting(row)}}</small></div><span class="ci-waiting">{{t('Ожидается','Pending')}}</span><button v-analytics="{feature: 'name_actions', placement: 'friends'}" class="ci-menu" :aria-label="`${t('Действия с игроком','Actions for')} ${name(row)}`" :disabled="!canAct(row)" @click="nameActions(row)">⋯</button></li>
      <li v-if="!invite" class="ci-empty">{{state.busy?t('Загрузка…','Loading…'):t('Не удалось загрузить приглашения.','Could not load invitations.')}}</li>
      <li v-else-if="!invite.paidRows.length&&!invite.pendingRows.length" class="ci-empty">{{t('Приглашённых пока нет','No invitations yet')}}</li>
      <li v-if="invite?.nextCursor" class="ci-more"><button v-analytics="{feature: 'more_invites', placement: 'friends'}" class="secondary full" :disabled="state.busy" @click="action(moreInvites)">{{t('Показать ещё','Show more')}}</button></li>
    </ul>
    <button v-analytics="{feature: 'refresh_invites', placement: 'friends'}" v-if="!invite" class="text-button full" :disabled="state.busy" @click="action(refreshInvites)">{{t('Повторить загрузку','Retry loading')}}</button>
    <details class="ci-inviter"><summary>{{t('Кто пригласил вас','Who invited you')}}</summary><div class="ci-editor"><label :for="'inviter-code'">{{t('Код пригласившего','Inviter code')}}</label><div class="ci-apply"><input id="inviter-code" :value="invite?.inviterAssigned?invite.inviterCode:code" :readonly="invite?.inviterAssigned" :disabled="state.busy||!invite" :placeholder="t('Введите код','Enter code')" maxlength="12" autocomplete="off" autocapitalize="characters" @input="code=($event.target as HTMLInputElement).value" @keydown.enter.prevent="apply"><button v-analytics="{feature: 'apply', placement: 'friends'}" v-if="!invite?.inviterAssigned" class="secondary" :disabled="state.busy||!invite||!code.trim()" @click="apply">{{t('Применить','Apply')}}</button></div><p>{{t('Ваш прогресс','Your progress')}}: {{ownProgress}}</p><p class="ci-binding">{{invite?.inviterAssigned?t('Код закреплён и больше не меняется.','This code is fixed and cannot be changed.'):t('Пригласившего можно выбрать один раз.','Choose your inviter only once.')}}</p></div></details>
    <dialog @close="releaseHelpAnalytics" ref="help" class="ci-help" :aria-label="t('Как работает приглашение','How invitations work')" @cancel.prevent="closeHelp" @keydown.stop="trap" @click.self="closeHelp">
      <header><h2>{{t('Как получить','How to earn')}} <EnergyAmount :amount="state.profile?.wallet.simpleBonus.policy.inviterReward??invite?.reward??0" prefix="+"/></h2><button v-analytics="{feature: 'close_help', placement: 'friends'}" class="icon-button" :aria-label="t('Закрыть подсказку','Close help')" @click="closeHelp">×</button></header>
      <ol><li><span class="ci-step" aria-hidden="true">1</span><strong>{{t('Передайте другу свой код','Give your friend your code')}}</strong><small>{{t('Друг введёт его в «Кто пригласил вас».','Your friend enters it in “Who invited you”.')}}</small></li><li><span class="ci-step" aria-hidden="true">2</span><strong>{{t(`Друг завершает ${invite?.requiredGames??5} игр`,`Your friend finishes ${invite?.requiredGames??5} games`)}}</strong></li><li><span class="ci-step" aria-hidden="true">3</span><strong>{{t('У обоих подтверждён вход','Both players verify sign-in')}}</strong><small>{{t('Google в Android или Telegram в Mini App.','Google on Android or Telegram in the Mini App.')}}</small></li></ol>
      <p>{{t('Награда начисляется автоматически.','Rewards are credited automatically.')}}</p><p>{{t('Пригласившего можно выбрать только один раз.','Choose your inviter only once.')}}</p><button v-analytics="{feature: 'close_help', placement: 'friends'}" class="primary full" @click="closeHelp">{{t('Понятно','Got it')}}</button>
    </dialog>
  </div>
</template>
<style>
.energy-window[data-page="friends"]{max-width:390px}
.energy-window[data-page="friends"] .window-header{padding:8px 10px;border-bottom:1px solid #217691;gap:4px}
.energy-window[data-page="friends"] .window-header h1{font-size:20px}
.energy-window[data-page="friends"] .window-body{padding:9px 10px 10px}
.energy-window[data-page="friends"] .energy-title-trigger{font-size:20px}
.energy-window[data-page="friends"] .window-header .icon-button{width:36px;height:36px;font-size:27px}
.energy-window[data-page="friends"] .compact-invites{color:#eef8ff}
.energy-window[data-page="friends"] .ci-code,.energy-window[data-page="friends"] .ci-totals,.energy-window[data-page="friends"] .ci-list,.energy-window[data-page="friends"] .ci-inviter{border:1px solid #22627b;border-radius:8px;background:#042237}
.energy-window[data-page="friends"] .ci-code{display:flex;align-items:center;gap:7px;padding:0 7px;min-height:44px}
.energy-window[data-page="friends"] .ci-code>span{font-size:11px;color:#a5cae8}
.energy-window[data-page="friends"] .ci-code input{border:0;background:none;box-shadow:none;padding:4px 0;min-width:0;font-size:21px;font-weight:800;color:#eef8ff;flex:1}
.energy-window[data-page="friends"] .ci-code .icon-button{width:36px;height:36px}
.energy-window[data-page="friends"] .ci-totals{display:grid;grid-template-columns:1fr 1fr;margin:7px 0 10px;padding:7px 0;min-height:38px}
.energy-window[data-page="friends"] .ci-totals>span{display:flex;align-items:center;justify-content:center;gap:5px;font-size:11px;color:#a5cae8;min-width:0}
.energy-window[data-page="friends"] .ci-totals>span+span{border-left:1px solid #22627b}
.energy-window[data-page="friends"] .ci-totals strong,.energy-window[data-page="friends"] .ci-totals .energy-amount{font-size:18px;font-weight:800}
.energy-window[data-page="friends"] .compact-invites>h2{font-size:16px;margin:0 0 6px}
.energy-window[data-page="friends"] .ci-list{padding:0;margin:0;list-style:none;height:264px;max-height:max(88px,calc(var(--logical-height) - 290px));overflow:auto;overscroll-behavior:contain;scrollbar-width:thin;scrollbar-color:#247189 transparent}
.energy-window[data-page="friends"] .ci-list li{display:flex;align-items:center;gap:7px;min-height:44px;border-bottom:1px solid #164158;padding:0 3px 0 7px}
.energy-window[data-page="friends"] .ci-list li:last-child{border-bottom:0}
.energy-window[data-page="friends"] .ci-avatar{width:26px;height:26px;flex:none;display:grid;place-items:center;background:#155161;border-radius:50%;font-size:12px;color:#7ff4f2}
.energy-window[data-page="friends"] .ci-name{min-width:0;flex:1;text-align:left;background:none;border:0;padding:0;color:#eef8ff;font-size:13px;font-weight:700;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;min-height:36px}
.energy-window[data-page="friends"] .ci-name:disabled{opacity:1}
.energy-window[data-page="friends"] .ci-list .energy-amount{font-size:17px;flex:none}
.energy-window[data-page="friends"] .ci-menu{width:28px;min-height:40px;padding:0;background:none;border:0;color:#79e8f5;font-size:21px;flex:none}
.energy-window[data-page="friends"] .ci-pending-name{flex:1;min-width:0;display:flex;flex-direction:column;justify-content:center}
.energy-window[data-page="friends"] .ci-pending-name .ci-name{min-height:18px;width:100%;flex:none}
.energy-window[data-page="friends"] .ci-pending-name small{font-size:10px;color:#a5cae8;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.energy-window[data-page="friends"] .ci-waiting{font-size:10px;color:#a5cae8;flex:none}
.energy-window[data-page="friends"] .ci-list .ci-empty{justify-content:center;padding:12px;font-size:12px;color:#a5cae8;min-height:88px}
.energy-window[data-page="friends"] .ci-list .ci-more{padding:3px 6px}
.energy-window[data-page="friends"] .ci-inviter{margin-top:7px}
.energy-window[data-page="friends"] .ci-inviter summary{cursor:pointer;min-height:36px;padding:10px 8px;color:#79e8f5;font-weight:700;font-size:12px}
.energy-window[data-page="friends"] .ci-editor{padding:0 9px 8px}
.energy-window[data-page="friends"] .ci-editor label{display:block;font-size:11px;color:#a5cae8;margin:0 0 5px}
.energy-window[data-page="friends"] .ci-apply{display:flex;gap:6px}
.energy-window[data-page="friends"] .ci-apply input{min-width:0;flex:1;background:#001b30;border:1px solid #22627b;border-radius:7px;font-size:14px;padding:7px;min-height:38px;text-transform:uppercase}
.energy-window[data-page="friends"] .ci-apply .secondary{font-size:12px;min-height:38px;padding:4px 9px}
.energy-window[data-page="friends"] .ci-editor p{font-size:12px;color:#a5cae8;margin:6px 0 0}
.energy-window[data-page="friends"] .compact-invites:has(.ci-inviter[open]) .ci-list{max-height:max(88px,calc(var(--logical-height) - 420px))}
.energy-window[data-page="friends"] .ci-help{width:calc(100% - 32px);max-width:390px;max-height:calc(100dvh - 40px);overflow:auto;color:#eef8ff;padding:13px;border:2px solid #61e9fb;border-radius:18px;background:linear-gradient(150deg,#062f44,#031b2d 70%);box-shadow:0 0 0 3px #043044,0 0 0 4px #36c4e699;font-family:Roboto,Arial,sans-serif}
.energy-window[data-page="friends"] .ci-help::backdrop{background:#061b2dcc}
.energy-window[data-page="friends"] .ci-help header{display:flex;align-items:center;gap:8px}
.energy-window[data-page="friends"] .ci-help h2{display:flex;align-items:center;gap:6px;flex:1;font-size:19px;margin:0}
.energy-window[data-page="friends"] .ci-help h2 .energy-amount{font-size:19px}
.energy-window[data-page="friends"] .ci-help ol{list-style:none;counter-reset:step;padding:0;margin:8px 0}
.energy-window[data-page="friends"] .ci-help li{counter-increment:step;position:relative;padding:10px 0 10px 35px;font-size:13px;min-height:43px}
.energy-window[data-page="friends"] .ci-help .ci-step{position:absolute;left:0;top:10px;width:25px;height:25px;display:grid;place-items:center;border:1px solid #36c4e6;border-radius:50%;color:#79e8f5;background:#075579}
.energy-window[data-page="friends"] .ci-help small{display:block;font-size:11px;line-height:1.4;color:#a5cae8;margin-top:3px}
.energy-window[data-page="friends"] .ci-help p{font-size:12px;color:#a5cae8;line-height:1.5;margin:7px 0}
.energy-window[data-page="friends"] .ci-help .primary{margin-top:12px;min-height:38px}
.energy-window[data-page="friends"] .ci-help .icon-button{width:32px;height:36px}
.energy-window[data-page="friends"] .window-header{margin:0}.energy-window[data-page="friends"] .window-header::after{display:none}
</style>
