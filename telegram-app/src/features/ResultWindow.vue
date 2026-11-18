<script setup lang="ts">
import './ranking-result-parity.css';
import { computed, ref, shallowRef, nextTick, watch, onMounted, onBeforeUnmount } from 'vue';
import GameWindow from '../components/GameWindow.vue';
import EnergyAmount from '../components/EnergyAmount.vue';
import GameArt from '../components/GameArt.vue';
import GameIcon from '../components/GameIcon.vue';
import MedalArt from '../components/MedalArt.vue';
import PlayerResultScene from './PlayerResultScene.vue';
import ResultDeliveryNotice from './ResultDeliveryNotice.vue';
import {runAwardSummary,awardSummaryCopy,resultMetricTip} from './result-presentation';
import ShareScoreCard from '../components/ShareScoreCard.vue';
import LoadingClock from '../components/LoadingClock.vue';
import {renderShareCard} from '../services/share-card';
import {loadShareArtwork,type ShareArtworkResource} from '../services/share-artwork';
import {resultInvitation,sameShareInvitation,shareCaption} from '../domain/share-invitation';
import {shareDownloadUrl,sharePngName} from '../domain/share-download';
import { resultArtwork,resultTrophy,preparedArtwork } from '../services/artwork';
import { completedRecord } from '../domain/daily-records';
import { state, pendingRecordIds, openScreen, back, action, failedFinish, retryFailedFinish, returnToPlay, presentResultReward, achievementSnapshot,refreshInvites } from '../services/game-store';
import { telegram } from '../platform/telegram';
import {registerOverlayBack} from '../services/ui-overlays';
const t = (ru: string, en: string) => state.locale === 'ru' ? ru : en;
const imageUrl=ref(''),artFailed=ref(false),artAttempt=ref(0);
const sceneInMemory=preparedArtwork(resultArtwork),trophyInMemory=preparedArtwork(resultTrophy);
const run = computed(() => state.history.find(a => a.requestId === state.resultId&&a.owner===state.profile?.id));
const runAwards=computed(()=>bestAttempt.value?runAwardSummary([],undefined,undefined):runAwardSummary(achievementSnapshot.value.pending,run.value,state.profile?.id));
const previewPhase=computed(()=>state.resultPreviewPhase??'confirmed');
const previewLabel=computed(()=>state.resultPreviewKind==='best'?t('Лучшая попытка','Best attempt'):t('Ваша попытка','Your run'));
const previewReturn=computed(()=>state.resultPreviewKind==='ranking'?t('К рейтингу','Back to leaderboard'):t('К моим попыткам','Back to my attempts'));
const bestAttempt = computed(() => state.bestResult?.userId === state.profile?.id ? state.bestResult : null);
function presentWhenVisible(){
  const id=state.resultId;
  if(!bestAttempt.value&&state.screen==='result'&&!document.hidden&&telegram()?.isActive!==false)void nextTick(()=>{
    if(state.screen==='result'&&state.resultId===id&&!document.hidden&&telegram()?.isActive!==false)try{presentResultReward(id);}catch{/* Saving the proof remains guarded separately. */}
  });
}
watch(()=>[state.screen,state.resultId,!!run.value?.result,!!failedFinish.value],presentWhenVisible,{immediate:true,flush:'post'});
onMounted(()=>{document.addEventListener('visibilitychange',presentWhenVisible);telegram()?.onEvent('activated',presentWhenVisible);});
onBeforeUnmount(()=>{document.removeEventListener('visibilitychange',presentWhenVisible);telegram()?.offEvent('activated',presentWhenVisible);});
const result = computed(() => bestAttempt.value ?? failedFinish.value?.result ?? run.value?.result);
const seconds = computed(() => ((result.value?.timeMs ?? 0) / 1000).toFixed(3).replace('.',state.locale==='ru'?',':'.'));
const previousBest = computed(() => run.value?.previousBestTimeMs);
const savedRun=computed(()=>!failedFinish.value&&!!run.value&&completedRecord(run.value));
const isRecord = computed(() => !bestAttempt.value&&savedRun.value&&previousBest.value!==undefined&&run.value!.result!.timeMs>previousBest.value);
const best = computed(() => {
  const known=Math.max(previousBest.value??0,state.profile?.wallet.bestTimeMs??0);
  const shown=isRecord.value&&previousBest.value!>0?previousBest.value!:
    Math.max(known,savedRun.value||bestAttempt.value?result.value?.timeMs??0:0);
  return (shown/1000).toFixed(3);
});
const metricTip = ref<'risk'|'run'|null>(null);
let metricTrigger:HTMLElement|undefined,removeTipBack:(()=>void)|undefined;
function closeMetric(){removeTipBack?.();removeTipBack=undefined;metricTip.value=null;void nextTick(()=>{if(metricTrigger?.isConnected)metricTrigger.focus({preventScroll:true});});}
function openMetric(kind:'risk'|'run',event:MouseEvent){metricTrigger=event.currentTarget as HTMLElement;metricTip.value=kind;removeTipBack?.();removeTipBack=registerOverlayBack(closeMetric,`result_${kind}`);}
onBeforeUnmount(()=>removeTipBack?.());
const tipDivisor=computed(()=>{const kind=metricTip.value??'risk';return run.value?.rewardDivisors?.[kind]??run.value?.config.config.economy?.[kind==='risk'?'riskRewardEvery':'runRewardEvery'];});
const bonus = (kind:'risk'|'run') => {
  if(bestAttempt.value)return 0;
  const economy=run.value?.config.config.economy;
  const divisor=run.value?.rewardDivisors?.[kind]??economy?.[kind==='risk'?'riskRewardEvery':'runRewardEvery'];
  return Number.isFinite(divisor)&&divisor>0?Math.floor((result.value?.[kind==='risk'?'riskCount':'runDistance']??0)/divisor):0;
};

const loadedInviteOwner=ref(''),invitationLoading=ref(false),invitationError=ref(false),imageLoading=ref(false),imageError=ref(false),shareSending=ref(false),shareFeedback=ref(''),shareTextScale=ref<number|null>(null),shareArtRevision=ref(0),shareFile=shallowRef<File|null>(null),fileKey=ref('');
const shareMiniAppTarget=import.meta.env.VITE_TELEGRAM_APP_URL||(import.meta.env.DEV?'https://t.me/TestUntouch_bot':'');
let inviteSerial=0,inviteFlight:{owner:string;promise:Promise<void>}|null=null,shareGeneration=0,providerGeneration=0,shareAlive=true;
const shareArt=shallowRef<ShareArtworkResource|null>(null);
let artOperation:{key:string;controller:AbortController;promise:Promise<ShareArtworkResource>}|null=null;
function releaseShareArt(){artOperation?.controller.abort();artOperation=null;shareArt.value?.dispose();shareArt.value=null;}
function preparedShareArt(owner:string,revision:number){
 const key=`${owner}:${revision}`;if(artOperation?.key===key)return artOperation.promise;releaseShareArt();
 const controller=new AbortController(),operation={key,controller,promise:Promise.resolve(null as unknown as ShareArtworkResource)};
 artOperation=operation;operation.promise=loadShareArtwork(revision,controller.signal).then(resource=>{if(!shareAlive||artOperation!==operation||state.screen!=='share'||state.profile?.id!==owner){resource.dispose();throw new DOMException('Aborted','AbortError');}shareArt.value=resource;return resource;});return operation.promise;
}
const invitation=computed(()=>loadedInviteOwner.value===state.profile?.id?resultInvitation(state.profile?.id,state.invites,state.locale,3,shareMiniAppTarget):null);
const exportData=computed(()=>state.screen==='share'&&invitation.value&&result.value&&shareTextScale.value!==null?{owner:state.profile!.id,timeMs:result.value.timeMs,riskCount:result.value.riskCount,steps:result.value.runDistance,locale:state.locale==='ru'?'ru' as const:'en' as const,invitation:invitation.value,textScale:shareTextScale.value,artRevision:shareArtRevision.value}:null);
const exportKey=computed(()=>exportData.value?JSON.stringify(exportData.value):'');
const fileReady=computed(()=>!!shareFile.value&&fileKey.value===exportKey.value&&!imageLoading.value);
const nativeFileShare=computed(()=>{try{return!!shareFile.value&&typeof navigator.share==='function'&&typeof navigator.canShare==='function'&&navigator.canShare({files:[shareFile.value]});}catch{return false;}});
const canOpenShare=computed(()=>fileReady.value&&(nativeFileShare.value||!!telegram()?.initData));
const browserSaveUrl=ref('');
function currentExport(key:string){return shareAlive&&state.screen==='share'&&key===exportKey.value&&!!exportData.value&&sameShareInvitation(exportData.value.invitation,invitation.value);}
function clearShareFile(){shareFile.value=null;fileKey.value='';if(imageUrl.value){URL.revokeObjectURL(imageUrl.value);imageUrl.value='';}}
function loadInvitation(){
 const owner=state.profile?.id;if(!owner||state.screen!=='share')return Promise.resolve();
 const serial=++inviteSerial;invitationLoading.value=true;invitationError.value=false;loadedInviteOwner.value='';
 let operation=inviteFlight;if(!operation||operation.owner!==owner){operation={owner,promise:refreshInvites()};inviteFlight=operation;const clear=()=>{if(inviteFlight===operation)inviteFlight=null;};void operation.promise.then(clear,clear);}
 return(async()=>{try{await operation.promise;if(!shareAlive||serial!==inviteSerial||state.screen!=='share'||state.profile?.id!==owner)return;loadedInviteOwner.value=owner;invitationError.value=!resultInvitation(owner,state.invites,state.locale,3,shareMiniAppTarget);}catch{if(shareAlive&&serial===inviteSerial){loadedInviteOwner.value='';invitationError.value=true;}}finally{if(serial===inviteSerial)invitationLoading.value=false;}})();
}
watch(()=>[state.screen,state.profile?.id],()=>{releaseShareArt();inviteSerial++;providerGeneration++;shareSending.value=false;loadedInviteOwner.value='';invitationLoading.value=false;invitationError.value=false;shareFeedback.value='';browserSaveUrl.value='';if(state.screen==='share')void loadInvitation();},{immediate:true,flush:'sync'});
async function prepareShareFile(){
 const data=exportData.value,key=exportKey.value,generation=++shareGeneration;clearShareFile();imageError.value=false;shareFeedback.value='';imageLoading.value=!!data;if(!data)return;
 try{const resource=await preparedShareArt(data.owner,data.artRevision);if(!currentExport(key)||generation!==shareGeneration)return;const canvas=await renderShareCard(data,resource.image);if(!currentExport(key)||generation!==shareGeneration)return;const blob=await new Promise<Blob>((resolve,reject)=>canvas.toBlob(value=>value?resolve(value):reject(Error('share_image_unavailable')),'image/png'));if(!currentExport(key)||generation!==shareGeneration)return;shareFile.value=new File([blob],`untouch-${(data.timeMs/1000).toFixed(3)}.png`,{type:'image/png'});fileKey.value=key;}catch{if(currentExport(key)&&generation===shareGeneration)imageError.value=true;}finally{if(generation===shareGeneration)imageLoading.value=false;}
}
watch(exportKey,()=>{browserSaveUrl.value='';void prepareShareFile();},{immediate:true,flush:'post'});
async function share(){
 const data=exportData.value,key=exportKey.value,file=shareFile.value;if(state.busy||shareSending.value||!fileReady.value||!data||!file||!currentExport(key))return;
 const caption=shareCaption(t(`Мой результат в Untouch — ${seconds.value} с. Попробуете побить?`,`My Untouch result is ${seconds.value} s. Can you beat it?`),data.invitation),operation=++providerGeneration;shareSending.value=true;shareFeedback.value='';
 try{if(nativeFileShare.value){await navigator.share({files:[file],text:caption,title:'Untouch'});if(operation===providerGeneration&&currentExport(key))back();}else{const tg=telegram();if(!tg?.initData)throw Error('share_unavailable');tg.openTelegramLink(`https://t.me/share/url?url=${encodeURIComponent(data.invitation.url)}&text=${encodeURIComponent(caption.slice(0,-data.invitation.url.length).trimEnd())}`);}}catch(error){if(operation===providerGeneration&&currentExport(key))shareFeedback.value=error instanceof DOMException&&error.name==='AbortError'?t('Отправка отменена','Sharing canceled'):t('Отправка недоступна на этом устройстве.','Sharing is unavailable on this device.');}finally{if(operation===providerGeneration)shareSending.value=false;}
}
function saveImage(){
 const key=exportKey.value,file=shareFile.value,data=exportData.value;if(state.busy||shareSending.value||!fileReady.value||!file||!data||!currentExport(key))return;
 if(telegram()?.initData){
  try{const url=shareDownloadUrl(data,location.href);browserSaveUrl.value=url;shareFeedback.value=t('Если браузер не открылся, скопируйте ссылку и откройте её в браузере. Там нажмите «Скачать PNG».','If your browser did not open, copy the link and open it in your browser. Then select Download PNG.');telegram()!.openLink(url,{try_browser:'chrome'});}catch{shareFeedback.value=t('Не удалось открыть браузер. Скопируйте ссылку и откройте её в браузере.','Could not open the browser. Copy the link and open it in your browser.');}return;
 }
 if(!imageUrl.value)imageUrl.value=URL.createObjectURL(file);const link=document.createElement('a');link.download=sharePngName(data.timeMs);link.href=imageUrl.value;link.click();
}
async function copyBrowserLink(){
 const key=exportKey.value,data=exportData.value;if(state.busy||shareSending.value||!fileReady.value||!data||!currentExport(key))return;
 try{const url=shareDownloadUrl(data,location.href);await navigator.clipboard.writeText(url);if(currentExport(key))shareFeedback.value=t('Ссылка скопирована. Откройте её в браузере и нажмите «Скачать PNG».','Link copied. Open it in your browser and select Download PNG.');}
 catch{if(currentExport(key))shareFeedback.value=t('Не удалось скопировать ссылку. Разрешите копирование и повторите.','Could not copy the link. Allow clipboard access and retry.');}
}
onBeforeUnmount(()=>{shareAlive=false;inviteSerial++;shareGeneration++;providerGeneration++;clearShareFile();releaseShareArt();});
</script>
<style>
.modal-backdrop.result-window:not(.window-exiting)::before,
.modal-backdrop.result-window:not(.window-exiting)>.game-window{animation:none}
</style>
<template>
  <GameWindow class="port-ranking-result" v-if="!bestAttempt||state.screen==='share'" :title="state.screen==='share'?t('Поделиться','Share'):t('Результат попытки','Run result')" :closable="!failedFinish" :inactive="!!metricTip" :class="state.screen==='result'?'result-window':'share-window'">
    <template v-if="state.screen==='share'||bestAttempt" #back>‹</template>
    <template v-if="state.screen==='result'" #background><img v-if="sceneInMemory" class="result-scene" :src="sceneInMemory" alt=""><GameArt v-else class="result-scene" :src="resultArtwork+(artAttempt?'?reload='+artAttempt:'')" @unavailable="artFailed=$event"/><div class="result-shade" aria-hidden="true"/></template>
    <template v-if="state.screen==='share'"><ShareScoreCard :time-ms="result?.timeMs??0" :risk-count="result?.riskCount??0" :steps="result?.runDistance??0" :invitation="invitation" :art-url="shareArt?.url" @layout="shareTextScale=$event"/><p v-if="invitationLoading||imageLoading" class="share-ready-status" role="status"><LoadingClock :size="16"/>{{invitationLoading?t('Загружаем ваш код…','Loading your code…'):t('Готовим картинку…','Preparing image…')}}</p><button v-else-if="invitationError||!invitation" class="text-button full" @click="loadInvitation">{{t('Код недоступен. Повторить','Code unavailable. Retry')}}</button><button v-else-if="imageError" class="text-button full" @click="shareArtRevision++">{{t('Картинка не загрузилась. Повторить','Image unavailable. Retry')}}</button><p v-if="shareFeedback" class="share-ready-status" role="status">{{shareFeedback}}</p></template>
    <div v-else class="result-summary"><small>{{ bestAttempt?t('🏆 Лучшая попытка','🏆 Best attempt'):isRecord?t('Новый рекорд!','New personal best!'):t('Ваш результат','Your result') }}</small><strong>{{ seconds }} {{ t('с','s') }}</strong><span class="best-chip">{{ isRecord&&(previousBest??0)>0?t('Предыдущий рекорд','Previous best'):t('Ваш рекорд','Your best') }}: {{ best }} {{t('с','s')}}</span></div>
    <div v-if="state.screen==='result'" class="result-actions">
      <div class="result-art-space"><button v-analytics="{feature: 'art_attempt', placement: 'result'}" v-if="artFailed" class="secondary retry-result-art" @click="artAttempt++">{{t('Повторить загрузку картинки','Reload illustration')}}</button></div>
      <div class="result-metrics"><button v-analytics="{feature: 'open_metric', placement: 'result'}" v-for="kind in (['risk','run'] as const)" :key="kind" class="result-metric" aria-haspopup="dialog" @click="openMetric(kind,$event)"><span><GameIcon :name="kind==='risk'?'risk':'run'"/>{{ kind==='risk'?t('Риск','Risk'):t('Шаги','Steps') }} <i aria-hidden="true">i</i></span><strong>{{ result?.[kind==='risk'?'riskCount':'runDistance']??0 }}</strong><small v-if="bonus(kind)>0"><EnergyAmount :amount="bonus(kind)" prefix="+"/> {{ run?.phase==='confirmed'?t('получено','earned'):t('бонус','bonus') }}</small></button></div>

      <button v-if="runAwards.receipts.length" type="button" class="result-awards-summary" @click="openScreen('achievements','result')"><span class="result-awards-medals" aria-hidden="true"><MedalArt v-for="receipt in runAwards.receipts.slice(0,3)" :key="receipt.awardId" :id="receipt.awardId" :normalized="false"/></span><span class="result-awards-copy"><small>{{t('НАГРАДЫ ЭТОЙ ПОПЫТКИ','THIS RUN’S REWARDS')}}</small><span>{{awardSummaryCopy(runAwards.medals,runAwards.cups,state.locale)}}</span></span><EnergyAmount v-if="runAwards.energy>0" :amount="runAwards.energy" prefix="+"/></button>
      <p v-if="run?.phase==='rejected'||run?.phase==='abandoned'" class="result-status" role="status">{{t('Попытка не зачтена и не входит в общий рейтинг.','This run was not counted and is excluded from the shared ranking.')}}</p>
      <template v-if="failedFinish"><p class="error-message">{{ t('Результат ещё не сохранён. Освободите место и повторите сохранение. Не закрывайте игру.','This result is not saved yet. Free storage space and retry saving. Keep the game open.') }}</p><button v-analytics="{feature: 'retry_failed_finish', placement: 'result'}" class="primary full" :disabled="state.busy" @click="action(retryFailedFinish)">{{ t('Повторить сохранение','Retry saving') }}</button></template>

    </div>


    <template v-if="state.screen==='result'" #footer><div class="result-footer-actions"><button v-analytics="{feature:'ranking',placement:'result'}" type="button" class="result-side-action" :disabled="!!failedFinish" :aria-label="t('Рейтинг','Leaderboard')" :title="t('Рейтинг','Leaderboard')" @click="openScreen('ranking','result')"><img v-if="trophyInMemory" :src="trophyInMemory" alt=""><GameArt v-else :src="resultTrophy"/></button><button v-analytics="{feature:'play_again',placement:'result'}" type="button" class="primary replay-action" :disabled="!!failedFinish" @click="returnToPlay()"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 10a8 8 0 1 1 0 5M4 4v6h6"/></svg>{{t('Ещё раз','Play again')}}</button><button v-analytics="{feature:'share',placement:'result'}" type="button" class="result-side-action" :disabled="!!failedFinish" :aria-label="t('Поделиться','Share')" :title="t('Поделиться','Share')" @click="openScreen('share','result')"><GameIcon name="share"/></button></div></template>
    <template v-if="state.screen==='share'" #footer>
      <button v-analytics="{feature: 'send_share', placement: 'result'}" class="primary share-send-action" :disabled="state.busy||shareSending||!canOpenShare" @click="share"><GameIcon name="share"/><span>{{t('Отправить','Send')}}</span></button><p v-if="fileReady&&!nativeFileShare" class="share-transport-hint">{{telegram()?.initData?t('В Telegram отправятся текст и ссылка. Картинку можно сохранить отдельно.','Telegram will share text and a link. Save the image separately.'):t('Отправка недоступна на этом устройстве. Картинку можно сохранить.','Sharing is unavailable on this device. You can save the image.')}}</p>
      <button v-analytics="{feature: 'save_share_image', placement: 'result'}" v-if="!imageUrl" class="text-button share-save-action" :disabled="state.busy||shareSending||!fileReady" @click="saveImage">{{telegram()?.initData?t('Сохранить картинку в браузере','Save image in browser'):t('Сохранить картинку','Save image')}}</button>
      <a v-else class="share-save-action" :href="imageUrl" :download="sharePngName(result?.timeMs??0)">{{t('Скачать PNG','Download PNG')}}</a>
      <button v-if="browserSaveUrl&&telegram()?.initData" type="button" class="text-button share-copy-link" :disabled="state.busy||shareSending||!fileReady" @click="copyBrowserLink">{{t('Скопировать ссылку для браузера','Copy browser link')}}</button>
      <button v-analytics="{feature: 'back', placement: 'result'}" class="text-button share-cancel-action" @click="back">{{t('Отмена','Cancel')}}</button>
    </template>
  </GameWindow>
  <GameWindow v-else-if="bestAttempt&&state.screen==='result'" class="port-ranking-result player-result-window own-preview" :title="t('Результат игрока','Player result')">
    <template #back>‹</template>
    <div class="player-result-identity"><div><h2>{{bestAttempt.playerName}}</h2><small>{{previewLabel}}<span v-if="bestAttempt.place"> · #{{bestAttempt.place}}</span></small></div></div>
    <PlayerResultScene :score="bestAttempt" :locale="state.locale"/>
    <p v-if="previewPhase!=='confirmed'" class="hint" role="status">{{['rejected','abandoned'].includes(previewPhase)?t('Попытка не зачтена.','This run was not counted.'):t('Результат сохранён на устройстве.','Result saved on this device.')}}</p>
    <div class="player-result-meta"><p>{{new Date(bestAttempt.createdAt).toLocaleString(state.locale==='ru'?'ru-RU':'en-US')}}</p><p>{{t('Это ваш личный результат','This is your own result')}}</p></div>
    <template #footer><div class="button-row"><button type="button" class="secondary" @click="openScreen('share','result')"><GameIcon name="share"/>{{t('Поделиться','Share')}}</button><button type="button" class="secondary" @click="back">{{previewReturn}}</button></div></template>
  </GameWindow>
  <ResultDeliveryNotice v-if="!bestAttempt&&!failedFinish&&state.screen==='result'&&run" :attempt-id="run.requestId" :pending="run.recordSequence===undefined?!['confirmed','rejected','abandoned'].includes(run.phase):pendingRecordIds.has(run.requestId)" :locale="state.locale"/>
  <GameWindow v-if="metricTip" class="metric-tip-window" :title="metricTip==='risk'?t('Что такое риск','What is risk?'):t('Как считаются шаги','How steps are counted')">
    <p>{{resultMetricTip(metricTip??'risk',{hadJump:false,hadHelmet:false},state.locale)}}</p>
    <p v-if="!bestAttempt&&Number.isFinite(tipDivisor)&&tipDivisor>0" class="hint">{{metricTip==='risk'?t(`За каждые ${tipDivisor} рисков — 1 ед. энергии.`,`Every ${tipDivisor} risks earns 1 energy.`):t(`За каждые ${tipDivisor} шагов — 1 ед. энергии.`,`Every ${tipDivisor} steps earns 1 energy.`)}}</p>
    <template #footer><button v-analytics="{feature: 'close_metric', placement: 'result'}" class="secondary full" @click="closeMetric">{{t('Понятно','Got it')}}</button></template>
  </GameWindow>
</template>

<style src="./share-window.css"/>


