<script setup lang="ts">
import { computed, ref, nextTick, watch, onMounted, onBeforeUnmount } from 'vue';
import GameWindow from '../components/GameWindow.vue';
import EnergyAmount from '../components/EnergyAmount.vue';
import GameArt from '../components/GameArt.vue';
import GameIcon from '../components/GameIcon.vue';
import ShareScoreCard from '../components/ShareScoreCard.vue';
import {renderShareCard} from '../services/share-card';
import { resultArtwork } from '../services/artwork';
import { state, openScreen, back, action, flush, failedFinish, retryFailedFinish, returnToPlay, presentResultReward } from '../services/game-store';
import { telegram } from '../platform/telegram';
import {registerOverlayBack} from '../services/ui-overlays';
const t = (ru: string, en: string) => state.locale === 'ru' ? ru : en;
const imageUrl=ref(''),artFailed=ref(false),artAttempt=ref(0);
const run = computed(() => state.history.find(a => a.requestId === state.resultId));
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
const seconds = computed(() => ((result.value?.timeMs ?? 0) / 1000).toFixed(3));
const previousBest = computed(() => run.value?.previousBestTimeMs);
const isRecord = computed(() => !bestAttempt.value && previousBest.value !== undefined && (result.value?.timeMs??0)>previousBest.value);
const best = computed(() => ((isRecord.value && (previousBest.value??0)>0 ? previousBest.value! : Math.max(result.value?.timeMs??0,state.profile?.wallet.bestTimeMs??0))/1000).toFixed(3));
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
const status = computed(() => bestAttempt.value ? t('Подтверждено · в общем рейтинге','Confirmed · in shared ranking') : failedFinish.value ? t('Результат ещё не сохранён','Result is not saved yet') : run.value?.phase==='confirmed' ? t('Подтверждено · в общем рейтинге','Confirmed · in shared ranking') : run.value?.phase==='rejected' ? t('Результат не подтверждён','Result not confirmed') : t('Сохранено · ожидает подтверждения','Saved · awaiting confirmation'));
function share() {

  const text = t(`Мой результат в Untouch — ${seconds.value} с. Попробуете побить?`,`My Untouch result is ${seconds.value} s. Can you beat it?`);
  const url = import.meta.env.VITE_TELEGRAM_APP_URL || 'https://untouch.fun/';
  telegram()?.openTelegramLink(`https://t.me/share/url?url=${encodeURIComponent(url)}&text=${encodeURIComponent(text)}`);
}
let shareGeneration=0,shareAlive=true;
watch(()=>[state.screen,state.resultId,result.value?.timeMs,result.value?.riskCount,result.value?.runDistance,state.locale],()=>{imageUrl.value='';shareGeneration++;});
onBeforeUnmount(()=>{shareAlive=false;shareGeneration++;});
async function saveImage() {
  const generation=++shareGeneration;
  const data={timeMs:result.value?.timeMs??0,riskCount:result.value?.riskCount??0,steps:result.value?.runDistance??0,locale:state.locale==='ru'?'ru' as const:'en' as const};
  const canvas=await renderShareCard(data);
  if(!shareAlive||generation!==shareGeneration||state.screen!=='share')return;
  imageUrl.value=canvas.toDataURL('image/png');

  const link=document.createElement('a');link.download=`untouch-${(data.timeMs/1000).toFixed(3)}.png`;link.href=imageUrl.value;link.click();
}
</script>
<template>
  <GameWindow :title="state.screen==='share'?t('Поделиться','Share'):t('Результат попытки','Run result')" :closable="!failedFinish" :inactive="!!metricTip" :class="state.screen==='result'?'result-window':'share-window'">
    <template v-if="state.screen==='share'||bestAttempt" #back>‹</template>
    <template v-if="state.screen==='result'" #background><GameArt class="result-scene" :src="resultArtwork+(artAttempt?'?reload='+artAttempt:'')" @unavailable="artFailed=$event"/><div class="result-shade" aria-hidden="true"/></template>
    <ShareScoreCard v-if="state.screen==='share'" :time-ms="result?.timeMs??0" :risk-count="result?.riskCount??0" :steps="result?.runDistance??0"/>
    <div v-else class="result-summary"><small>{{ bestAttempt?t('🏆 Лучшая попытка','🏆 Best attempt'):isRecord?t('Новый рекорд!','New personal best!'):t('Ваш результат','Your result') }}</small><strong>{{ seconds }} {{ t('с','s') }}</strong><span class="best-chip">{{ isRecord&&(previousBest??0)>0?t('Предыдущий рекорд','Previous best'):t('Ваш рекорд','Your best') }}: {{ best }} {{t('с','s')}}</span></div>
    <div v-if="state.screen==='result'" class="result-actions">
      <div class="result-art-space"><button v-analytics="{feature: 'art_attempt', placement: 'result'}" v-if="artFailed" class="secondary retry-result-art" @click="artAttempt++">{{t('Повторить загрузку картинки','Reload illustration')}}</button></div>
      <div class="result-metrics"><button v-analytics="{feature: 'open_metric', placement: 'result'}" v-for="kind in (['risk','run'] as const)" :key="kind" class="result-metric" aria-haspopup="dialog" @click="openMetric(kind,$event)"><span>{{ kind==='risk'?t('Риск','Risk'):t('Шаги','Steps') }} <i>ⓘ</i></span><strong>{{ result?.[kind==='risk'?'riskCount':'runDistance']??0 }}</strong><small v-if="bonus(kind)>0"><EnergyAmount :amount="bonus(kind)" prefix="+"/> {{ run?.phase==='confirmed'?t('получено','earned'):t('бонус','bonus') }}</small></button></div>

      <div class="result-status" :class="run?.phase==='confirmed'?'mint':'hint'"><span>{{status}}</span><span class="result-delivery-action"><EnergyAmount v-if="!bestAttempt&&run?.phase==='confirmed'" :amount="run.reward??0" prefix="+"/><button v-analytics="{feature: 'flush', placement: 'result'}" v-else-if="!bestAttempt&&!failedFinish&&run?.phase!=='rejected'" class="icon-button result-retry" :disabled="state.busy" :aria-label="t('Повторить отправку','Retry delivery')" :title="t('Повторить отправку','Retry delivery')" @click="action(flush)">↻</button></span></div>
      <template v-if="failedFinish"><p class="error-message">{{ t('Результат ещё не сохранён. Освободите место и повторите сохранение. Не закрывайте игру.','This result is not saved yet. Free storage space and retry saving. Keep the game open.') }}</p><button v-analytics="{feature: 'retry_failed_finish', placement: 'result'}" class="primary full" :disabled="state.busy" @click="action(retryFailedFinish)">{{ t('Повторить сохранение','Retry saving') }}</button></template>

    </div>


    <template v-if="state.screen==='result'" #footer><div class="button-row result-links"><button v-analytics="{feature: 'ranking', placement: 'result'}" v-if="!bestAttempt" class="text-button" :disabled="!!failedFinish" @click="openScreen('ranking','result')">{{t('Рейтинг','Leaderboard')}}</button><button v-analytics="{feature: 'share', placement: 'result'}" class="text-button" :disabled="!!failedFinish" @click="openScreen('share','result')">↥ {{t('Поделиться','Share')}}</button></div><button v-analytics="{feature: bestAttempt?'back_to_attempts':'play_again', placement: 'result'}" class="primary full replay-action" :disabled="!!failedFinish" @click="bestAttempt?back():returnToPlay()">{{bestAttempt?t('К моим попыткам','Back to my attempts'):t('↻ Ещё раз','↻ Play again')}}</button></template>
    <template v-if="state.screen==='share'" #footer>
      <button v-analytics="{feature: 'send_share', placement: 'result'}" class="primary share-send-action" @click="share"><GameIcon name="share"/><span>{{t('Отправить','Send')}}</span></button>
      <button v-analytics="{feature: 'save_share_image', placement: 'result'}" v-if="!imageUrl" class="text-button share-save-action" :disabled="state.busy" @click="action(saveImage)">{{t('Сохранить картинку','Save image')}}</button>
      <a v-else class="share-save-action" :href="imageUrl" :download="`untouch-${seconds}.png`">{{t('Скачать PNG','Download PNG')}}</a>
      <button v-analytics="{feature: 'back', placement: 'result'}" class="text-button share-cancel-action" @click="back">{{t('Отмена','Cancel')}}</button>
    </template>
  </GameWindow>
  <GameWindow v-if="metricTip" class="metric-tip-window" :title="metricTip==='risk'?t('Что такое риск','What is risk?'):t('Как считаются шаги','How steps are counted')">
    <p>{{metricTip==='risk'?t('Риск — успешное опасное сближение с врагом или прыжок через него. Награда начисляется после подтверждения попытки.','Risk counts a close escape from an enemy or a jump over one. Rewards are credited after run confirmation.'):t('Шаги — пройденное расстояние. Один шаг равен одной десятой ширины героя на любом экране.','Steps measure distance. One step equals one tenth of the hero’s width on every screen.')}}</p>
    <p v-if="!bestAttempt&&Number.isFinite(tipDivisor)&&tipDivisor>0" class="hint">{{metricTip==='risk'?t(`За каждые ${tipDivisor} рисков — 1 ед. энергии.`,`Every ${tipDivisor} risks earns 1 energy.`):t(`За каждые ${tipDivisor} шагов — 1 ед. энергии.`,`Every ${tipDivisor} steps earns 1 energy.`)}}</p>
    <template #footer><button v-analytics="{feature: 'close_metric', placement: 'result'}" class="secondary full" @click="closeMetric">{{t('Понятно','Got it')}}</button></template>
  </GameWindow>
</template>

<style src="./share-window.css"/>
