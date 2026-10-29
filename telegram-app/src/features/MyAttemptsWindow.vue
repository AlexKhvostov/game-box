<script setup lang="ts">
import {computed, ref, watch, nextTick, onMounted, useId} from 'vue';
import GameWindow from '../components/GameWindow.vue';
import GameArt from '../components/GameArt.vue';
import AverageInfoDialog from '../components/AverageInfoDialog.vue';
import {state, refreshAttemptHistory, moreAttemptHistory, retryAttemptHistory, openBestAttemptResult} from '../services/game-store';
import {myAttemptsModel, attemptWindow, bestAttemptScore} from '../domain/my-attempts';
import type {Attempt} from '../services/contracts';
const emit = defineEmits<{detail: [attempt: Attempt]}>();
const t = (ru: string, en: string) => state.locale === 'ru' ? ru : en;
const model = computed(() => myAttemptsModel({attempts: state.history, profile: state.profile, board: state.average, allTime: state.periods.all ?? [], server:state.serverHistory,config:state.config}));
const expanded = ref(true), showInfo = ref(false), selectedId = ref<string | null>(null), meanButton = ref<HTMLButtonElement>(), list = ref<HTMLElement>();
const plotId = useId(), missingBest = ref(false);
const visible = computed(() => attemptWindow(model.value.rows, selectedId.value));
const ceiling = computed(() => Math.max(5000, Math.ceil(Math.max(...visible.value.map(row => Math.max(row.attempt.result!.timeMs, row.averageMs ?? 0))) / 5000) * 5000));
const x = (index: number) => 36 + (index + .5) * 314 / Math.max(1, visible.value.length);
const y = (ms: number) => 172 - 160 * ms / ceiling.value;
const barWidth = computed(() => Math.min(22, 314 / Math.max(1, visible.value.length) * .58));
const averageLine = computed(() => visible.value.map((row, index) => row.averageMs === null ? null : `${x(index)},${y(row.averageMs)}`).filter(Boolean).join(' '));
const seconds = (ms?: number | null) => ms == null ? '—' : (ms / 1000).toFixed(3).replace('.', state.locale === 'ru' ? ',' : '.');
function stamp(timestamp?: number | null) {
  if (timestamp == null) return t('Дата недоступна','Date unavailable');
  const date = new Date(timestamp), now = new Date(), yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  const locale = state.locale === 'ru' ? 'ru-RU' : 'en-US';
  const day = date.toDateString() === now.toDateString() ? t('Сегодня','Today') : date.toDateString() === yesterday.toDateString() ? t('Вчера','Yesterday') : date.toLocaleDateString(locale, {day:'numeric', month:'short', ...(date.getFullYear()===now.getFullYear()?{}:{year:'numeric'})});
  return `${day}, ${date.toLocaleTimeString(locale,{hour:'2-digit',minute:'2-digit'})}`;
}
const phase = (attempt: Attempt) => attempt.phase === 'confirmed' ? '' : attempt.phase === 'rejected' || attempt.phase === 'abandoned' ? t(' · Не зачтена',' · Not counted') : t(' · Ожидает',' · Pending');
function scrollSelected() {void nextTick(() => {
  const row = Array.from(list.value?.querySelectorAll<HTMLElement>('[data-attempt-id]') ?? []).find(el => el.dataset.attemptId === selectedId.value);
  if (!row || !list.value) return;
  // Scroll only the history container; never move the modal or page.
  const top = row.offsetTop, bottom = top + row.offsetHeight;
  if (top < list.value.scrollTop) list.value.scrollTop = top;
  else if (bottom > list.value.scrollTop + list.value.clientHeight) list.value.scrollTop = bottom - list.value.clientHeight;
});}
function select(id: string, scroll = false) {selectedId.value = id; missingBest.value = false; if (scroll) scrollSelected();}
function showAttempt(attempt: Attempt) { select(attempt.requestId); emit('detail',attempt); }
function selectBest() {const score = bestAttemptScore(state.serverHistory, state.profile); if (score) openBestAttemptResult(score);}
function closeInfo() {const owner = state.profile?.id; showInfo.value = false; void nextTick(() => {if (owner === state.profile?.id && state.screen === 'history') meanButton.value?.focus({preventScroll: true});});}
function chartKey(event: KeyboardEvent) {
  const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0;
  if (!step) return;
  event.preventDefault();
  const index = model.value.rows.findIndex(row => row.attempt.requestId === selectedId.value);
  const row = model.value.rows[Math.max(0, Math.min(model.value.rows.length - 1, index + step))];
  if (row) select(row.attempt.requestId, true);
}
function chartClick(event: MouseEvent) {
  const rect = (event.currentTarget as SVGElement).getBoundingClientRect();
  const at = Math.floor(((event.clientX - rect.left) * 364 / rect.width - 36) / 314 * visible.value.length);
  const row = visible.value[Math.max(0, Math.min(visible.value.length - 1, at))];
  if (row) select(row.attempt.requestId, true);
}
watch(() => state.profile?.id, () => {selectedId.value = null; showInfo.value = false; expanded.value = true; missingBest.value = false;}, {flush: 'sync'});
watch(() => !!model.value.rules, available => {if (!available) showInfo.value = false;}, {flush: 'sync'});
watch(() => model.value.rows.map(row => row.attempt.requestId).join(','), () => {
  if (!model.value.rows.some(row => row.attempt.requestId === selectedId.value)) selectedId.value = model.value.rows.at(-1)?.attempt.requestId ?? null;
}, {immediate: true});
onMounted(() => {void refreshAttemptHistory();});
</script>
<template>
  <GameWindow class="my-attempts-window" :title="t('Мои попытки','My attempts')" tall :inactive="showInfo">
    <template #title><GameArt class="ma-hero" src="/assets/branding/ranking/my-attempts-hero.png"/>{{t('Мои попытки','My attempts')}}</template>
    <template v-if="state.parent" #back>‹</template>
    <section class="ma-graph" :aria-label="t('Результаты попыток','Attempt results')">
      <div class="ma-summary">
        <div class="ma-stat ma-total">
          <span class="ma-stat-label">{{t('Всего попыток','Total attempts')}}</span>
          <strong class="ma-value" :style="{'--characters':String(model.totalCount ?? '—').length}">{{model.totalCount ?? '—'}}</strong>
          <span class="ma-stat-sub">{{t('За всё время','All time')}}</span>
        </div>
        <button v-analytics="{feature: 'select_best', placement: 'my_attempts'}" type="button" class="ma-stat ma-best" :disabled="!model.best" @click="selectBest">
          <span class="ma-stat-label"><img src="/assets/branding/ranking/trophy.svg" alt="">{{t('Лучшая попытка','Best attempt')}}</span>
          <strong class="ma-value" :style="{'--characters':seconds(model.best?.timeMs).length+1}">{{seconds(model.best?.timeMs)}} <small>{{t('с','s')}}</small></strong>
          <span class="ma-stat-sub ma-best-date">{{model.best?stamp(model.best.createdAt):t('Пока нет рекорда','No record yet')}}</span>
          <span v-if="model.best?.source==='confirmed-local'" class="ma-stat-sub">{{t('Подтверждено на устройстве','Confirmed on this device')}}</span>
        </button>
        <button v-analytics="{feature: 'show_info', placement: 'my_attempts'}" ref="meanButton" type="button" class="ma-stat ma-mean" :disabled="!model.rules" aria-haspopup="dialog" :aria-expanded="showInfo" @click="showInfo=true">
          <span class="ma-stat-label">{{t('Среднее','Average')}} <span aria-hidden="true" class="ma-info">ⓘ</span></span>
          <strong class="ma-value" :style="{'--characters':seconds(model.averageMs).length+1}">{{seconds(model.averageMs)}} <small>{{t('с','s')}}</small></strong>
          <span class="ma-stat-sub">{{model.rules?t(`Учтено попыток: ${model.usedCount}`,`Attempts counted: ${model.usedCount}`):t('Подключаем данные…','Loading rules…')}}</span>
        </button>
      </div>
      <div class="ma-chart-shell">
        <button v-analytics="{feature: 'expanded', placement: 'my_attempts'}" type="button" class="ma-chart-toggle" :aria-expanded="expanded" :aria-controls="plotId" @click="expanded=!expanded"><span>{{t('График · время, с','Chart · time, s')}}</span><span>{{expanded?t('Свернуть','Collapse'):t('Развернуть','Expand')}} <svg viewBox="0 0 24 24" aria-hidden="true" :class="{collapsed:!expanded}"><path d="m6 15 6-6 6 6"/></svg></span></button>
        <div v-show="expanded" :id="plotId" class="ma-chart-region">
          <svg v-if="visible.length" viewBox="0 0 364 198" class="ma-chart" tabindex="0" role="img" :aria-label="t('Столбики — попытки, жёлтая линия — среднее. Стрелки выбирают попытку.','Bars show attempts; the yellow line shows the average. Arrow keys select an attempt.')" @click="chartClick" @keydown="chartKey">
            <g v-for="i in 6" :key="`grid-${i}`"><line x1="36" x2="350" :y1="y(ceiling*(i-1)/5)" :y2="y(ceiling*(i-1)/5)" class="ma-grid"/><text x="30" :y="y(ceiling*(i-1)/5)+4" text-anchor="end">{{ceiling*(i-1)/5000}}</text></g>
            <g v-for="(row,i) in visible" :key="row.attempt.requestId"><rect :x="x(i)-barWidth/2" :y="Math.min(170,y(row.attempt.result!.timeMs))" :width="barWidth" :height="Math.max(2,172-y(row.attempt.result!.timeMs))" rx="2" class="ma-bar" :class="{'is-selected':row.attempt.requestId===selectedId,'is-pending':row.attempt.phase!=='confirmed'}"/><text v-if="i===0||i===visible.length-1||i===Math.floor((visible.length-1)/2)" :x="x(i)" y="190" text-anchor="middle">{{row.number}}</text></g>
            <polyline v-if="averageLine" :points="averageLine" class="ma-average-line"/>
            <circle v-for="(row,i) in visible.filter(row=>row.averageMs!==null)" :key="`point-${row.attempt.requestId}`" :cx="x(visible.indexOf(row))" :cy="y(row.averageMs!)" :r="row.attempt.requestId===selectedId?3.8:2" class="ma-average-dot" :data-point="i"/>
          </svg>
          <p v-else class="ma-empty-chart"><span v-if="state.historyLoading" class="loading-spinner" aria-hidden="true"/>{{state.historyLoading?t('Загружаем историю…','Loading history…'):state.historyError?t('Не удалось загрузить историю','Could not load history'):t('Здесь появится ваш прогресс','Your progress will appear here')}}</p>
        </div>
      </div>
      <div v-show="expanded" class="ma-selection" aria-live="polite"><strong v-if="model.averageMs!==null">{{t('Среднее','Average')}} {{seconds(model.averageMs)}} {{t('с','s')}}</strong></div>
      <div v-show="expanded" class="ma-legend"><span v-if="model.chartMode!=='none'"><b class="ma-line-swatch"/>{{t('Среднее','Average')}}</span><span><b class="ma-bar-swatch"/>{{t('Попытка','Attempt')}}</span></div>
    </section>
    <section class="ma-history" :aria-label="t('История попыток','Attempt history')">
      <header class="ma-history-heading"><h2>{{t('История','History')}} <span>· {{model.history.length}} / {{model.totalCount ?? '—'}}</span></h2><small>{{t('Новые сверху','Newest first')}}</small></header>
      <div ref="list" class="ma-list">
        <div v-for="row in model.history" :key="row.attempt.requestId" class="ma-row" :class="{'is-selected':selectedId===row.attempt.requestId,'is-best':row.attempt.requestId===model.best?.localId}" :data-attempt-id="row.attempt.requestId">
          <button v-analytics="{feature: 'select', placement: 'my_attempts'}" type="button" class="ma-row-select" :aria-label="t(`Открыть результат попытки ${row.number}`,`View result of attempt ${row.number}`)" @click="showAttempt(row.attempt)"><span class="ma-number">#{{row.number}}</span><span class="ma-row-meta"><span class="ma-date">{{stamp(row.attempt.createdAt)}}</span><small>{{t('Шаги','Steps')}} {{row.attempt.result!.runDistance}} · {{t('Риск','Risk')}} {{row.attempt.result!.riskCount}}{{phase(row.attempt)}}</small></span><strong class="ma-time">{{seconds(row.attempt.result!.timeMs)}} <small>{{t('с','s')}}</small></strong><svg class="ma-eye" viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/></svg></button>
        </div>
        <p v-if="!model.history.length&&!state.historyLoading&&!state.historyError" class="ma-empty">{{t('Ваши попытки будут здесь. Пока нет результатов.','Your attempts will appear here. No results yet.')}}</p>
        <button v-analytics="{feature: 'state', placement: 'my_attempts'}" v-if="state.historyError||state.serverHistory?.history.nextCursor" class="ma-load-more" type="button" :disabled="state.historyLoading" @click="state.historyError?retryAttemptHistory():moreAttemptHistory()">{{state.historyLoading?t('Загружаем…','Loading…'):state.historyError?t('Повторить загрузку','Retry loading'):t('Загрузить ещё','Load more')}}</button>
        <div v-if="model.pending.length" class="ma-pending"><strong>{{t('На устройстве · отдельно от графика','On this device · outside the chart')}}</strong><button v-for="attempt in model.pending" :key="attempt.requestId" class="ma-pending-row" type="button" @click="showAttempt(attempt)"><span>{{stamp(attempt.createdAt)}} · {{seconds(attempt.result!.timeMs)}} {{t('с','s')}}{{phase(attempt)}}</span><svg class="ma-eye" viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/></svg><span class="ma-sr">{{t('Открыть результат','View result')}}</span></button></div>
      </div>
      <p v-if="missingBest||state.historyError||state.historyLoading" class="ma-history-note" role="status">{{missingBest?t('Рекорд в более ранней истории. Загрузите ещё попытки.','Your record is in earlier history. Load more attempts.'):state.historyError?(state.serverHistory?t('Связь прервалась. Загруженная история сохранена — повторите загрузку.','Connection interrupted. Loaded history is kept — retry loading.'):t('Не удалось загрузить историю. Повторите загрузку.','Could not load history. Please retry.')):t('Загружаем историю с сервера…','Loading history from the server…')}}</p>
    </section>
  </GameWindow>
  <AverageInfoDialog v-if="showInfo&&model.rules" :rules="model.rules" :incomplete="!model.historyComplete" @close="closeInfo"/>
</template>
<style scoped src="./my-attempts.css"></style>
