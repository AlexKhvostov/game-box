<script setup lang="ts">
import { computed, ref, watch, onMounted } from 'vue';
import GameWindow from '../components/GameWindow.vue';
import AverageChart from '../components/AverageChart.vue';
import GameArt from '../components/GameArt.vue';
import AverageInfoDialog from '../components/AverageInfoDialog.vue';
import MyAttemptsWindow from './MyAttemptsWindow.vue';
import { state, action, refreshBoards, refreshInvites, openScreen, request, back } from '../services/game-store';
import { averageChart } from '../domain/average';
import { ownAttempts } from '../domain/my-attempts';
import type { Score, Attempt } from '../services/contracts';
const t = (ru: string, en: string) => state.locale === 'ru' ? ru : en;
const title = computed(() => state.screen==='chart'?t('Средний результат','Average result'):state.screen==='history'?t('Мои попытки','My runs'):state.screen==='name-actions'?t('Имя игрока','Player name'):state.screen==='player-result'?t('Результат игрока','Player result'):t('Рейтинг','Leaderboard'));
const periodLabels = computed(() => [['all',t('Всё','All')],['year',t('Год','Year')],['month',t('Мес.','Month')],['week',t('Нед.','Week')],['day',t('День','Day')]]);
const currentPeriodLabel=computed(()=>periodLabels.value.find(([id])=>id===state.period)?.[1]??'');
const records = computed(() => state.periods[state.period]??[]), ownRecord = computed(() => records.value.find(r=>r.userId===state.profile?.id));
const averages = computed(() => state.average?.rows??[]);
const reason = ref('offensive_name'),detailTip=ref(''),selectedContext=ref(''),reporting=ref(false),showAverageInfo=ref(false);
const chart = computed(() => state.average ? averageChart(ownAttempts(state.history,state.profile?.id), state.average) : null);
watch(() => [state.profile?.id,state.screen,!!state.average], (value, previous) => {if(!value[2]||value[0]!==previous[0]||value[1]!==previous[1])showAverageInfo.value=false;}, {flush:'sync'});
const seconds = (v?: number | null) => v==null?'—':`${(v/1000).toFixed(3)} ${t('с','s')}`;
const date = (v: number) => new Date(v).toLocaleString(state.locale==='ru'?'ru-RU':'en-US',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'});
function detail(row: Score) { selectedContext.value=periodLabels.value.find(([id])=>id===state.period)?.[1]??'';detailTip.value='';reporting.value=false;state.selectedScore=row; openScreen('player-result','ranking'); }
function detailHistory(run:Attempt) { if(!run.result)return;selectedContext.value=t('Мои попытки','My runs');detailTip.value='';reporting.value=false;state.selectedScore={id:run.requestId,userId:state.profile!.id,playerName:state.profile!.nickname,timeMs:run.result.timeMs,riskCount:run.result.riskCount,runDistance:run.result.runDistance,createdAt:run.createdAt,hadJump:run.jump,hadHelmet:run.helmet};openScreen('player-result','history'); }
const target=computed(()=>state.screen==='name-actions'?state.selectedPlayer:state.selectedScore);
function nameActions(row:{userId?:string;playerName:string}){if(!row.userId||row.userId===state.profile?.id)return;selectedContext.value='';detailTip.value='';reporting.value=false;state.selectedPlayer={userId:row.userId,playerName:row.playerName};openScreen('name-actions','ranking');}
const nameHidden=computed(()=>!!target.value?.userId&&!!state.profile?.hiddenPlayers.includes(target.value.userId));
const hideName = () => action(async () => { const hide=!nameHidden.value;await request({ action: 'public_name_hide', target: target.value!.userId, hide }); await refreshBoards(); if(state.invites)await refreshInvites(); state.notice = hide?t('Имя скрыто для вас','Name hidden for you'):t('Имя снова видно','Name is visible again'); });
const reportName = () => action(async () => { await request({ action: 'public_name_report', target: target.value!.userId, reason: reason.value }); state.notice = t('Жалоба принята','Report received'); });
onMounted(() => { if(state.screen==='ranking') void action(refreshBoards); });
</script>
<template>
  <MyAttemptsWindow v-if="state.screen==='history'" @detail="detailHistory"/>
  <GameWindow v-else :title="title" tall :inactive="showAverageInfo" :class="['ranking','history'].includes(state.screen)?'ranking-window':state.screen==='chart'?'chart-window':'player-result-window'">
    <template #title><GameArt v-if="['ranking','history'].includes(state.screen)" class="window-title-art" src="/assets/branding/ranking/trophy.svg"/>{{title}}</template>
    <template v-if="state.screen==='ranking'" #header-extra><button class="ranking-history-action text-button" @click="openScreen('history','ranking')">{{t('Мои попытки','My runs')}}</button></template>
    <template v-if="state.parent" #back>‹</template>
    <template v-if="state.screen==='ranking'">
      <div class="tabs"><button :class="{selected:state.rankingTab==='record'}" @click="state.rankingTab='record'">{{ t('Рекорд','Best') }}</button><button :class="{selected:state.rankingTab==='average'}" @click="state.rankingTab='average'">{{ t('Среднее','Average') }}</button></div>
      
      <template v-if="state.rankingTab==='record'">
      <div class="ranking-intro"><span><img src="/assets/branding/ranking/jump.svg" alt="">{{ t('Прыжок','Jump') }} · <img src="/assets/branding/ranking/helmet.svg" alt="">{{ t('Шлем','Helmet') }}<small>{{ t('Яркие — были включены','Bright icons were enabled') }}</small></span></div>
        <div class="segments"><button v-for="[id,label] in periodLabels" :key="id" :class="{selected:state.period===id}" @click="state.period=id!">{{ label }}</button></div>
        <div class="ranking-summary"><span>{{t('Ваш рекорд','Your best')}}: {{ seconds(ownRecord?.timeMs) }}</span><span>{{t('Место','Place')}}: {{ownRecord?.place??'—'}}</span></div>
        <div class="rank-header"><span>#</span><span>{{ t('Игрок','Player') }}</span><span>{{ t('Усиления','Boosts') }}</span><span>{{ t('Результат','Result') }}</span></div>
        <div class="ranking-list">
        <button v-for="row in records.filter(r=>(r.place??0)<=200)" :key="row.id" class="rank-row" :class="{mine:row.userId===state.profile?.id}" @click="detail(row)"><span class="place"><GameArt v-if="row.place&&row.place<=3" :src="`/assets/branding/ranking/medal-${row.place}.svg`" :alt="String(row.place)"/><b v-else>{{row.place}}</b></span><span class="rank-name"><strong>{{ row.playerName }}</strong><small>{{ date(row.createdAt) }}</small></span><span class="boost-icons"><img :class="{dim:!row.hadJump}" src="/assets/branding/ranking/jump.svg" :alt="t('Прыжок','Jump')"><img :class="{dim:!row.hadHelmet}" src="/assets/branding/ranking/helmet.svg" :alt="t('Шлем','Helmet')"></span><span class="rank-value"><strong>{{ seconds(row.timeMs) }}</strong><small><GameArt class="inline-metric-art" src="/assets/branding/ranking/risk.svg"/> {{row.riskCount}} · <GameArt class="inline-metric-art" src="/assets/branding/ranking/footsteps.svg"/> {{row.runDistance}}</small></span></button>
        <button v-if="ownRecord&&(ownRecord.place??0)>200" class="rank-row mine own-row" @click="detail(ownRecord)"><b>{{ ownRecord.place }}</b><strong>{{ ownRecord.playerName }}</strong><span></span><strong>{{ seconds(ownRecord.timeMs) }}</strong></button>
        <p v-if="!records.length" class="empty">{{ state.busy?t('Загрузка…','Loading…'):t('Подтверждённых результатов пока нет.','No confirmed results yet.') }}</p>
        </div>
      </template>
      <template v-else>
        <div class="average-heading"><p>{{ t('Рейтинг по среднему времени','Ranking by average attempt time') }}</p><button class="text-button" @click="openScreen('chart','ranking')">⌁ {{t('График','Chart')}}</button><button class="icon-button average-info-button" :disabled="!state.average" aria-haspopup="dialog" :aria-label="t('Как считается среднее','How the average is calculated')" :aria-expanded="showAverageInfo" @click="showAverageInfo=!showAverageInfo">ⓘ</button></div>
        <p v-if="!state.online" class="hint">{{t('Показано последнее загруженное среднее','Showing the last loaded average')}}</p>
        <div v-if="state.average?.mine" class="ranking-summary"><span>{{t('Ваше среднее','Your average')}}: {{seconds(state.average.mine.averageMs)}}</span><span>{{t('Место','Place')}}: {{state.average.mine.place??'—'}}</span><span>{{t('Попыток','Attempts')}}: {{state.average.mine.totalAttempts}}</span></div>
        <p v-if="state.average?.mine.place==null&&(state.average?.rules.minAttempts??1)>1" class="hint">{{t('Предварительно','Provisional')}} · {{state.average?.mine.eligibleCount??0}} / {{state.average?.rules.minAttempts}} {{t('попыток для допуска','qualifying attempts')}}</p>
        <div class="average-columns"><span>#</span><span>{{t('Игрок','Player')}}</span><span>{{t('Среднее время','Average time')}}</span><span>{{t('Всего попыток','Total attempts')}}</span></div>
        <div class="ranking-list"><div v-for="row in averages" :key="row.userId" class="average-row" :class="{mine:row.userId===state.profile?.id}"><b>{{ row.place }}</b><button class="public-name-button" :disabled="!row.userId||row.userId===state.profile?.id" @click="nameActions(row)">{{ row.playerName }}</button><span><b>{{ seconds(row.averageMs) }}</b></span><span>{{row.totalAttempts}}</span></div>
        <template v-if="state.average?.mine.place&&(state.average.mine.place>200)"><p class="own-average-divider">{{t('Ваше место','Your place')}}</p><div class="average-row mine"><b>{{state.average.mine.place}}</b><strong>{{state.profile?.nickname}}</strong><span><b>{{seconds(state.average.mine.averageMs)}}</b></span><span>{{state.average.mine.totalAttempts}}</span></div></template>
        <p v-if="!averages.length" class="empty">{{ t('Рейтинг появится после подтверждённых попыток.','The ranking will appear after confirmed runs.') }}</p>
        </div>
      </template>
      <button class="text-button full" :disabled="state.busy" @click="action(refreshBoards)">{{ t('Обновить','Refresh') }}</button>
    </template>
    <template v-else-if="state.screen==='chart'">
      <p>{{ state.locale==='ru'?`Последние ${chart?.points.length??0} сохранённых попыток`:`Last ${chart?.points.length??0} saved attempts` }}</p><strong class="chart-total">⌁ {{ seconds(chart?.averageMs) }}</strong>
      <p>{{ t('На графике','On chart') }}: {{ chart?.points.length??0 }} · {{ t('В расчёте — последние','Included — last') }} {{ state.average?.rules.windowSize??50 }}</p>
      <AverageChart v-if="chart?.points.length" :data="chart" :locale="state.locale" />
      <div class="chart-legend"><span>▮ {{ t('Попытка ≥ 1 с','Attempt ≥ 1 s') }}</span><span class="muted">▮ {{ t('Короче 1 с','Under 1 s') }}</span><span class="yellow">━ {{ t('Среднее','Average') }}</span></div><p v-if="chart&&!chart.historyComplete" class="hint">{{ t('На устройстве есть не вся история. График может отличаться от серверного среднего.','This device does not contain all history. The chart may differ from the server average.') }}</p><p class="hint">{{ t('Линия — среднее квадратичное после каждой попытки с весами по давности.','The line is the weighted root mean square after each run.') }}</p><p v-if="!chart?.points.length" class="empty">{{ t('Нет подтверждённых попыток для графика.','No confirmed runs to chart.') }}</p>
    </template>
    <template v-else-if="target">
      <div class="player-result-identity"><GameArt src="/assets/branding/ui/player-avatar-v1.png"/><span><h2>{{ target.playerName }}</h2><small v-if="state.screen==='player-result'">{{selectedContext||currentPeriodLabel}}<span v-if="state.selectedScore?.place"> · #{{state.selectedScore.place}}</span></small></span></div><template v-if="state.screen==='player-result'&&state.selectedScore"><strong class="chart-total">{{ seconds(state.selectedScore.timeMs) }}</strong><p class="player-points">{{t('Очки попытки','Run points')}}: {{Math.round(Math.max(0,state.selectedScore.timeMs)/1000*Math.max(0,state.selectedScore.runDistance)*(1+Math.max(0,state.selectedScore.riskCount)))}}</p>
      <div class="player-detail-grid"><button v-for="kind in ['run','risk','jump','helmet']" :key="kind" :class="{selected:detailTip===kind}" @click="detailTip=detailTip===kind?'':kind"><GameArt :class="{dim:kind==='jump'&&!state.selectedScore.hadJump||kind==='helmet'&&!state.selectedScore.hadHelmet}" :src="`/assets/branding/ranking/${kind==='run'?'footsteps':kind}.svg`"/><span>{{kind==='run'?t('Шаги','Steps'):kind==='risk'?t('Риск','Risk'):kind==='jump'?t('Прыжок','Jump'):t('Шлем','Helmet')}}<strong v-if="kind==='run'||kind==='risk'">{{kind==='run'?state.selectedScore.runDistance:state.selectedScore.riskCount}}</strong><small v-else>{{(kind==='jump'?state.selectedScore.hadJump:state.selectedScore.hadHelmet)?t('Использовался','Used in this run'):t('Не использовался','Not used')}}</small></span><i>ⓘ</i></button></div>
      <p v-if="detailTip" class="metric-tip" role="status">{{detailTip==='run'?t('Один шаг равен одной десятой ширины героя.','One step equals one tenth of the hero’s width.'):detailTip==='risk'?t('Риск — опасные сближения с врагами.','Risk counts close encounters with enemies.'):detailTip==='jump'?t('Прыжок защищает от врагов. Опасные стены остаются опасными.','Jumping protects from enemies. Dangerous walls remain dangerous.'):t('Шлем принимает один удар за попытку.','A helmet absorbs one hit per run.')}}</p><p class="hint">{{ date(state.selectedScore.createdAt) }}<span v-if="target.userId===state.profile?.id"> · {{t('Ваша попытка','Your run')}}</span></p></template>
      <template v-if="target.userId!==state.profile?.id"><button class="secondary full" :disabled="state.busy" @click="hideName">{{ nameHidden?t('Показать имя для меня','Show name for me'):t('Скрыть имя для меня','Hide name for me') }}</button><label v-if="reporting" class="field-label">{{ t('Причина жалобы','Report reason') }}<select v-model="reason"><option value="offensive_name">{{ t('Оскорбительное имя','Offensive name') }}</option><option value="personal_data">{{ t('Персональные данные','Personal information') }}</option><option value="impersonation">{{ t('Выдаёт себя за другого','Impersonation') }}</option><option value="other">{{ t('Другое','Other') }}</option></select></label><button class="text-button full" :disabled="state.busy" @click="reporting?reportName():reporting=true">{{ reporting?t('Отправить жалобу','Submit report'):t('Пожаловаться на имя','Report name') }}</button></template>
    </template>
    <template v-if="['player-result','name-actions'].includes(state.screen)" #footer><button class="secondary full" :disabled="state.busy" @click="back">{{t('Закрыть','Close')}}</button></template>
    
  </GameWindow>
  <AverageInfoDialog v-if="showAverageInfo&&state.average" :rules="state.average.rules" @close="showAverageInfo=false"/>
</template>
