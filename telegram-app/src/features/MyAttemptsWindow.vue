<script setup lang="ts">
import {computed,onBeforeUnmount,ref} from 'vue';
import GameWindow from '../components/GameWindow.vue';
import GameArt from '../components/GameArt.vue';
import GameIcon from '../components/GameIcon.vue';
import ParityDialog from '../components/ParityDialog.vue';
import {state,achievementPanel,flush,now,pendingRecordIds,recordThrough} from '../services/game-store';
import {myAttemptsModel} from '../domain/my-attempts';
import {recordMetrics,recordTime,type RecordMetric} from '../domain/daily-records';
import type {Attempt} from '../services/contracts';

const emit=defineEmits<{detail:[attempt:Attempt]}>();
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
const model=computed(()=>myAttemptsModel(state.history,state.profile,recordThrough.value,achievementPanel.value.totalAttempts));
const info=ref(false);
const hasPending=computed(()=>state.history.some(a=>!['confirmed','rejected','abandoned'].includes(a.phase)));
const clock=ref(now());
const timer=setInterval(()=>clock.value=now(),15000);
onBeforeUnmount(()=>clearInterval(timer));
const nextMidnight=computed(()=>new Date(new Date(clock.value).toISOString().slice(0,10)+'T00:00:00Z').getTime()+86400000);
const seconds=(ms:number)=>(ms/1000).toFixed(3).replace('.',state.locale==='ru'?',':'.');
const time=(timestamp:number,utc=false)=>new Intl.DateTimeFormat('en-GB',{hour:'2-digit',minute:'2-digit',
  ...(utc?{timeZone:'UTC'}:{})}).format(timestamp);
const utcDate=(day:string)=>day.split('-').reverse().join('.');
const metricLabel=(metric:RecordMetric)=>({
  cleanTimeMs:t('Время без усилений','Time without boosts'),
  boostedTimeMs:t('Время с усилениями','Time with boosts'),
  maxSteps:t('Шаги','Steps'),maxRisk:t('Риск','Risk'),
})[metric];
const delivery=(a:Attempt)=>{
  if(a.recordRejected||a.phase==='rejected'||a.phase==='abandoned')return 'rejected';
  if(a.recordPublished||a.recordSequence===undefined&&a.phase==='confirmed')return 'sent';
  if(a.recordSequence===undefined||pendingRecordIds.value.has(a.requestId))return 'waiting';
  return 'local';
};
const deliveryLabel=(a:Attempt)=>({
  sent:t('Отправлено','Sent'),waiting:t('Ожидает отправки','Waiting to send'),
  local:t('На устройстве','On this device'),rejected:t('Не зачтена','Not counted'),
})[delivery(a)];
</script>

<template>
  <GameWindow class="my-attempts-window" :inactive="info" :title="t('Мои попытки','My attempts')" tall>
    <template #title><GameArt class="ma-hero" src="/assets/branding/ranking/my-attempts-hero.png"/>{{t('Мои попытки','My attempts')}}</template>
    <template v-if="state.parent" #back>‹</template>
    <section class="ma-graph" :aria-label="t('Результаты попыток','Attempt results')">
      <p class="ma-intro">{{t('На сервер идут дневные рекорды и общий счётчик.','Daily records and the total count sync to the server.')}}</p>
      <div class="ma-summary">
        <div class="ma-stat ma-total">
          <span class="ma-stat-label">{{t('Всего попыток','Total attempts')}}</span>
          <strong class="ma-value" :style="{'--characters':String(model.totalCount).length}">{{model.totalCount}}</strong>
          <span class="ma-stat-sub">{{model.confirmed===undefined?t('За всё время','All time'):
            t('Подтверждено ','Confirmed ')+model.confirmed}}</span>
        </div>
        <button v-analytics="{feature:'select_best',placement:'my_attempts'}" type="button" class="ma-stat ma-best"
          :disabled="!model.localBest" @click="model.localBest&&emit('detail',model.localBest)">
          <span class="ma-stat-label"><img src="/assets/branding/ranking/trophy.svg" alt="">{{t('Лучшая попытка','Best attempt')}}</span>
          <strong class="ma-value" :style="{'--characters':seconds(model.bestTime).length+1}">
            {{model.bestTime?seconds(model.bestTime):'—'}} <small>{{t('с','s')}}</small>
          </strong>
          <span class="ma-stat-sub ma-best-date">{{model.localBest?time(recordTime(model.localBest))+' / '+time(recordTime(model.localBest),true)+' UTC':
            model.bestTime?t('Дата недоступна','Date unavailable'):t('Пока нет рекорда','No record yet')}}</span>
        </button>
      </div>
      <p class="ma-clock">{{t('У вас ','Local ')}}{{time(clock)}} · {{t('Игра ','Game ')}}{{time(clock,true)}} UTC<br>
        {{t('Новый день','New day')}} · 00:00 UTC / {{time(nextMidnight)}} {{t('у вас','local')}}</p>
    </section>
    <section class="ma-history" :aria-label="t('История попыток','Attempt history')">
      <header class="ma-history-heading">
        <h2>{{t('История','History')}} <span>· {{model.historyCount}}</span></h2>
        <button type="button" class="ma-action" :disabled="state.recordSending||!hasPending" @click="flush(true)"
          :aria-label="t('Отправить сейчас','Sync now')" :title="t('Отправить сейчас','Sync now')">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 12a8 8 0 0 0-13-6L4 9m0-5v5h5m-5 3a8 8 0 0 0 13 6l3-3m0 5v-5h-5"/></svg>
        </button>
        <button type="button" class="ma-action" @click="info=true" :aria-label="t('Как отправляются рекорды','How records sync')">ⓘ</button>
        <small>{{t('На этом устройстве','On this device')}}</small>
      </header>
      <p v-if="state.recordSending||state.recordError||!state.online&&hasPending" class="ma-sync-note" role="status">
        {{state.recordSending?t('Отправляем…','Syncing…'):!state.online?t('Нет сети. Попытки сохранены на устройстве.','Offline. Attempts are saved on this device.'):state.recordError}}
      </p>
      <div class="ma-list">
        <section v-for="group in model.days" :key="group.day" :data-record-day="group.day">
          <h3 class="ma-day">{{utcDate(group.day)}} · UTC</h3>
          <div v-for="{attempt,number,records} in group.rows" :key="attempt.requestId" class="ma-row"
            :class="{'is-best':attempt.requestId===model.localBest?.requestId,'is-record':records.length>0}" :data-attempt-id="attempt.requestId">
            <button type="button" class="ma-row-select" v-analytics="{feature:'select',placement:'my_attempts'}"
              :aria-label="t('Открыть результат попытки ','View result of attempt ')+number" @click="emit('detail',attempt)">
              <span class="ma-row-meta">
                <span class="ma-date"><span class="ma-number">#{{number}}</span> {{time(recordTime(attempt))}} / {{time(recordTime(attempt),true)}} UTC</span>
                <small class="ma-delivery" :data-delivery="delivery(attempt)">
                  <svg v-if="delivery(attempt)==='sent'" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 18a4 4 0 1 1 .5-8A5.5 5.5 0 0 1 17 11a3.5 3.5 0 1 1 1 7H6Zm3-4 2 2 4-4"/></svg>
                  <svg v-else-if="delivery(attempt)==='waiting'" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8"/><path d="M12 7v6l3 2"/></svg>
                  <svg v-else-if="delivery(attempt)==='local'" viewBox="0 0 24 24" aria-hidden="true"><rect x="7" y="3" width="10" height="18" rx="2"/><path d="M11 18h2"/></svg>
                  {{deliveryLabel(attempt)}}
                </small>
              </span>
              <span class="ma-record-grid" :aria-label="records.map(metricLabel).join(', ')||undefined" :aria-hidden="!records.length">
                <span v-for="metric in recordMetrics" :key="metric" :data-category="metric"
                  :class="{lit:records.includes(metric)}" :title="metricLabel(metric)">
                  <GameIcon v-if="metric==='maxSteps'||metric==='maxRisk'" :name="metric==='maxSteps'?'run':'risk'"/>
                  <svg v-else viewBox="0 0 24 24" aria-hidden="true">
                    <path v-if="metric==='boostedTimeMs'" d="M12 2 4 5v6c0 4 3 8 8 11 5-3 8-7 8-11V5l-8-3Z"/>
                    <template v-else><circle cx="12" cy="13" r="8"/><path d="M10 2h4m-2 6v5l3 1"/></template>
                  </svg>
                </span>
              </span>
              <strong class="ma-time">{{seconds(attempt.result!.timeMs)}} <small>{{t('с','s')}}</small></strong>
              <svg class="ma-eye" viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/></svg>
            </button>
          </div>
        </section>
        <p v-if="!model.historyCount" class="ma-empty">{{t('Ваши попытки будут здесь.','Your attempts will appear here.')}}</p>
      </div>
    </section>
  </GameWindow>
  <ParityDialog v-if="info" name="record-delivery-help" :title="t('Дневные рекорды','Daily records')" :locale="state.locale" @close="info=false">
    <div class="port-information-body ma-record-help">
      <p>{{t('История хранится на этом устройстве. Сервер получает только новые максимумы каждого дня UTC и общий счётчик.',
        'Attempt history stays on this device. The server receives new records for each UTC day and the total count.')}}</p>
      <ul><li v-for="metric in recordMetrics" :key="metric">{{metricLabel(metric)}}</li></ul>
      <p>{{t('Рекорд отмечается как отправленный после подтверждения. Если сети нет, запись останется в очереди.',
        'A record is marked sent after confirmation. Records stay queued while offline.')}}</p>
    </div>
  </ParityDialog>
</template>
<style scoped src="./my-attempts.css"></style>
