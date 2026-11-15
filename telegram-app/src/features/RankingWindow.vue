<script setup lang="ts">
import './ranking-result-parity.css';
import { computed, ref, watch, nextTick, onBeforeUnmount } from 'vue';
import GameWindow from '../components/GameWindow.vue';
import LoadingClock from '../components/LoadingClock.vue';
import AverageChart from '../components/AverageChart.vue';
import GameArt from '../components/GameArt.vue';
import AverageInfoDialog from '../components/AverageInfoDialog.vue';
import MyAttemptsWindow from './MyAttemptsWindow.vue';
import LevelBadge from '../components/LevelBadge.vue';
import PlayerResultScene from './PlayerResultScene.vue';
import {registerOverlayBack} from '../services/ui-overlays';
import { state, action, errorText, refreshBoards, refreshInvites, openScreen, request, back, openBestAttemptResult, achievementPanel } from '../services/game-store';
import { averageChart } from '../domain/average';
import { ownAttempts } from '../domain/my-attempts';
import type { Score, Attempt } from '../services/contracts';
const t = (ru: string, en: string) => state.locale === 'ru' ? ru : en;
const title = computed(() => state.screen==='chart'?t('Средний результат','Average result'):state.screen==='history'?t('Мои попытки','My runs'):state.screen==='name-actions'?t('Имя игрока','Player name'):state.screen==='player-result'?t('Результат игрока','Player result'):t('Рейтинг','Leaderboard'));
const periodLabels = computed(() => [['all',t('Всё','All')],['year',t('Год','Year')],['month',t('Мес.','Month')],['week',t('Нед.','Week')],['day',t('День','Day')]]);
const currentPeriodLabel=computed(()=>periodLabels.value.find(([id])=>id===state.period)?.[1]??'');
const records = computed(() => state.periods[state.period]??[]), ownRecord = computed(() => records.value.find(r=>r.userId===state.profile?.id));
const averages = computed(() => (state.average?.rows??[]).filter(row=>row.place!=null&&row.place<=200).slice(0,200));
const reason = ref('offensive_name'),selectedContext=ref(''),historyPhase=ref<Attempt['phase']|null>(null),reporting=ref(false),showAverageInfo=ref(false),nameMenuOpen=ref(false);
const nameMenu=ref<HTMLElement>(),nameMenuShift=ref(0);
function clampNameMenu(){const menu=nameMenu.value,body=menu?.closest('.window-body');if(!nameMenuOpen.value||!menu||!body)return;const r=menu.getBoundingClientRect(),bounds=body.getBoundingClientRect(),scale=r.width/menu.offsetWidth;if(!(scale>0))return;const inset=4*scale,delta=r.left<bounds.left+inset?bounds.left+inset-r.left:r.right>bounds.right-inset?bounds.right-inset-r.right:0;if(delta)nameMenuShift.value+=delta/scale;}
const repositionNameMenu=()=>{if(nameMenuOpen.value)void nextTick(clampNameMenu);};
let removeMenuBack:(()=>void)|undefined;
function closeNameMenu(){nameMenuOpen.value=false;nameMenuShift.value=0;window.removeEventListener('resize',repositionNameMenu);removeMenuBack?.();removeMenuBack=undefined;}
function toggleNameMenu(){if(nameMenuOpen.value){closeNameMenu();return;}nameMenuOpen.value=true;removeMenuBack=registerOverlayBack(closeNameMenu,'player_name_menu');window.addEventListener('resize',repositionNameMenu);void nextTick(clampNameMenu);}
onBeforeUnmount(closeNameMenu);
watch(()=>[state.screen,state.profile?.id],()=>{closeNameMenu();reporting.value=false;});
const playerLevel=(row:{userId?:string;achievementLevel?:number})=>row.achievementLevel??(row.userId===state.profile?.id?achievementPanel.value.level:1);
const visibleName=(row:{userId?:string;playerName:string})=>row.userId&&state.profile?.hiddenPlayers.includes(row.userId)?t('Скрытое имя','Hidden name'):row.playerName;
const chart = computed(() => state.average ? averageChart(ownAttempts(state.history,state.profile?.id), state.average) : null);
watch(() => [state.profile?.id,state.screen,!!state.average], (value, previous) => {if(!value[2]||value[0]!==previous[0]||value[1]!==previous[1])showAverageInfo.value=false;}, {flush:'sync'});
const seconds = (v?: number | null) => v==null?'—':`${(v/1000).toFixed(3).replace('.',state.locale==='ru'?',':'.')} ${t('с','s')}`;
const date = (v: number) => new Date(v).toLocaleString(state.locale==='ru'?'ru-RU':'en-US',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'});
function detail(row: Score) { if(row.userId===state.profile?.id){openBestAttemptResult(row,'ranking','ranking');return;}historyPhase.value=null; selectedContext.value=periodLabels.value.find(([id])=>id===state.period)?.[1]??'';reporting.value=false;state.selectedScore=row; openScreen('player-result','ranking'); }
function detailHistory(run:Attempt) { if(!run.result||run.owner!==state.profile?.id)return;openBestAttemptResult({id:run.requestId,userId:run.owner,playerName:state.profile!.nickname,timeMs:run.result.timeMs,riskCount:run.result.riskCount,runDistance:run.result.runDistance,createdAt:run.createdAt,hadJump:run.jump,hadHelmet:run.helmet,achievementLevel:achievementPanel.value.level},'history','history',run.phase); }
const target=computed(()=>state.screen==='name-actions'?state.selectedPlayer:state.selectedScore);
function nameActions(row:{userId?:string;playerName:string}){if(!row.userId||row.userId===state.profile?.id)return;selectedContext.value='';reporting.value=false;state.selectedPlayer={userId:row.userId,playerName:row.playerName};openScreen('name-actions','ranking');}
const nameHidden=computed(()=>!!target.value?.userId&&!!state.profile?.hiddenPlayers.includes(target.value.userId));
const hideName = () => {closeNameMenu();return action(async () => { const hide=!nameHidden.value;await request({ action: 'public_name_hide', target: target.value!.userId, hide }); await refreshBoards(true); if(state.invites)await refreshInvites(); state.notice = hide?t('Имя скрыто для вас','Name hidden for you'):t('Имя снова видно','Name is visible again'); });};
const reportName = () => action(async () => { await request({ action: 'public_name_report', target: target.value!.userId, reason: reason.value }); state.notice = t('Жалоба принята','Report received'); });
const rankingLoading=ref(false),rankingError=ref('');let rankingRead=0;
function readRanking(force=false){const serial=++rankingRead;rankingLoading.value=state.screen==='ranking';rankingError.value='';if(!rankingLoading.value)return;void refreshBoards(force).catch(error=>{if(serial===rankingRead)rankingError.value=errorText(error);}).finally(()=>{if(serial===rankingRead)rankingLoading.value=false;});}
watch(()=>[state.screen,state.rankingTab,state.period,state.profile?.id],()=>readRanking(),{immediate:true});
</script>
<template>
  <MyAttemptsWindow v-if="state.screen==='history'" @detail="detailHistory"/>
  <GameWindow v-else class="port-ranking-result" :title="title" tall :inactive="showAverageInfo" :class="[{'average-ranking':state.screen==='ranking'&&state.rankingTab==='average'},['ranking','history'].includes(state.screen)?'ranking-window':state.screen==='chart'?'chart-window':'player-result-window']">
    <template #title><GameArt v-if="['ranking','history'].includes(state.screen)" class="window-title-art" src="/assets/branding/ranking/trophy.svg"/>{{title}}</template>
    <template v-if="state.screen==='ranking'" #header-extra><button v-analytics="{feature: 'history', placement: 'leaderboard'}" class="ranking-history-action text-button" @click="openScreen('history','ranking')">{{t('Мои попытки','My runs')}}</button></template>
    <template v-if="state.parent" #back>‹</template>
    <template v-if="state.screen==='ranking'">
      <p v-if="state.rankingTab==='record'" class="hint">{{t('До 200 лучших игроков · ваше место — отдельно','Top 200 players · your own place is shown separately')}}</p>
      <div class="tabs"><button v-analytics="{feature: 'ranking_record', placement: 'leaderboard'}" :class="{selected:state.rankingTab==='record'}" @click="state.rankingTab='record'">{{ t('Рекорд','Best') }}</button><button v-analytics="{feature: 'ranking_average', placement: 'leaderboard'}" :class="{selected:state.rankingTab==='average'}" @click="state.rankingTab='average'">{{ t('Среднее','Average') }}</button></div>
      
      <template v-if="state.rankingTab==='record'">
      <div class="ranking-intro"><span><img src="/assets/branding/ranking/jump.svg" alt="">{{ t('Прыжок','Jump') }} · <img src="/assets/branding/ranking/helmet.svg" alt="">{{ t('Шлем','Helmet') }}<small>{{ t('Яркие — были включены','Bright icons were enabled') }}</small></span></div>
        <div class="segments"><button v-analytics="{feature: 'ranking_period', placement: 'leaderboard'}" v-for="[id,label] in periodLabels" :key="id" :class="{selected:state.period===id}" @click="state.period=id!">{{ label }}</button></div>
        <div class="ranking-summary"><span>{{t('Ваш рекорд','Your best')}}: {{ seconds(ownRecord?.timeMs) }}</span><span>{{t('Место','Place')}}: {{ownRecord?.place??'—'}}</span></div>
        <div v-if="rankingLoading" class="ranking-loading" role="status"><LoadingClock :size="records.length?28:24"/><p v-if="!records.length">{{t('Загружаем рейтинг…','Loading leaderboard…')}}</p></div><p v-if="rankingError&&records.length" class="hint">{{t('Показаны последние загруженные результаты','Showing the last loaded results')}}</p>
        <div class="rank-header"><span>#</span><span>{{ t('Игрок','Player') }}</span><span>{{ t('Усиления','Boosts') }}</span><span>{{ t('Результат','Result') }}</span></div>
        <div class="ranking-list">
        <button v-analytics="{feature: 'detail', placement: 'leaderboard'}" v-for="row in records.filter(r=>(r.place??0)<=200)" :key="row.id" class="rank-row" :class="{mine:row.userId===state.profile?.id}" @click="detail(row)"><span class="place"><GameArt v-if="row.place&&row.place<=3" :src="`/assets/branding/ranking/medal-${row.place}.svg`" :alt="String(row.place)"/><b v-else>{{row.place}}</b></span><span class="rank-identity"><span class="rank-name"><strong>{{ visibleName(row) }}</strong><small>{{ date(row.createdAt) }}</small></span><LevelBadge :level="playerLevel(row)" :locale="state.locale" compact/></span><span class="boost-icons"><img :class="{dim:!row.hadJump}" src="/assets/branding/ranking/jump.svg" :alt="t('Прыжок','Jump')"><img :class="{dim:!row.hadHelmet}" src="/assets/branding/ranking/helmet.svg" :alt="t('Шлем','Helmet')"></span><span class="rank-value"><strong>{{ seconds(row.timeMs) }}</strong><small><GameArt class="inline-metric-art" src="/assets/branding/ranking/risk.svg"/> {{row.riskCount}} · <GameArt class="inline-metric-art" src="/assets/branding/ranking/footsteps.svg"/> {{row.runDistance}}</small></span></button>
        <button v-analytics="{feature: 'detail', placement: 'leaderboard'}" v-if="ownRecord&&(ownRecord.place??0)>200" class="rank-row mine own-row" @click="detail(ownRecord)"><b class="place">{{ ownRecord.place }}</b><span class="rank-identity"><span class="rank-name"><strong>{{visibleName(ownRecord)}}</strong><small>{{date(ownRecord.createdAt)}}</small></span><LevelBadge :level="playerLevel(ownRecord)" :locale="state.locale" compact/></span><span class="boost-icons"><img :class="{dim:!ownRecord.hadJump}" src="/assets/branding/ranking/jump.svg" :alt="t('Прыжок','Jump')"><img :class="{dim:!ownRecord.hadHelmet}" src="/assets/branding/ranking/helmet.svg" :alt="t('Шлем','Helmet')"></span><strong class="rank-value">{{ seconds(ownRecord.timeMs) }}</strong></button>
        <div v-if="!records.length&&!rankingLoading" class="empty"><GameArt class="ranking-empty-art" src="/assets/branding/ui/hero-ready-v1.png"/><p>{{rankingError?t('Не удалось загрузить рейтинг. Проверьте сеть.','Could not load the leaderboard. Check your connection.'):t('Подтверждённых результатов пока нет.','No confirmed results yet.')}}</p><button v-if="rankingError" class="text-button" @click="readRanking(true)">{{t('Повторить','Retry')}}</button></div>
        </div>
      </template>
      <template v-else>
        <div class="average-heading"><p>{{ t('Среднее · топ 200','Average · top 200') }}</p><button v-analytics="{feature: 'chart', placement: 'leaderboard'}" class="text-button" @click="openScreen('chart','ranking')">⌁ {{t('График','Chart')}}</button><button v-analytics="{feature: 'show_average_info', placement: 'leaderboard'}" class="icon-button average-info-button" :disabled="!state.average" aria-haspopup="dialog" :aria-label="t('Как считается среднее','How the average is calculated')" :aria-expanded="showAverageInfo" @click="showAverageInfo=!showAverageInfo">ⓘ</button></div>
        <div v-if="rankingLoading" class="ranking-loading" role="status"><LoadingClock :size="28" :active="!showAverageInfo"/></div><p v-if="rankingError&&state.average" class="hint">{{t('Показано последнее загруженное среднее','Showing the last loaded average')}}</p>
        <div v-if="state.average?.mine" class="ranking-summary"><span>{{t('Ваше среднее','Your average')}}: {{seconds(state.average.mine.averageMs)}}</span><span>{{t('Место','Place')}}: {{state.average.mine.place??'—'}}</span><span>{{t('Попыток','Attempts')}}: {{state.average.mine.totalAttempts}}</span></div>
        <p v-if="state.average?.mine.place==null&&(state.average?.rules.minAttempts??1)>1" class="hint">{{t('Предварительно','Provisional')}} · {{state.average?.mine.eligibleCount??0}} / {{state.average?.rules.minAttempts}} {{t('попыток для допуска','qualifying attempts')}}</p>
        <div class="average-columns"><span>#</span><span>{{t('Игрок','Player')}}</span><span>{{t('Среднее время','Average time')}}</span><span>{{t('Всего попыток','Total attempts')}}</span></div>
        <div class="ranking-list"><div v-for="row in averages" :key="row.userId" class="average-row" :class="{mine:row.userId===state.profile?.id}"><span class="average-place"><GameArt v-if="row.place&&row.place<=3" :src="`/assets/branding/ranking/medal-${row.place}.svg`" :alt="String(row.place)"/><b v-else>{{row.place}}</b></span><span class="rank-identity"><button v-analytics="{feature: 'name_actions', placement: 'leaderboard'}" class="public-name-button" :disabled="!row.userId||row.userId===state.profile?.id" @click="nameActions(row)">{{ visibleName(row) }}</button><LevelBadge :level="playerLevel(row)" :locale="state.locale" compact/></span><span><b>{{ seconds(row.averageMs) }}</b></span><span>{{row.totalAttempts}}</span></div>
        <template v-if="state.average?.mine.place&&(state.average.mine.place>200)"><p class="own-average-divider">{{t('Ваше место','Your place')}}</p><div class="average-row mine"><b class="average-place">{{state.average.mine.place}}</b><span class="rank-identity"><strong class="public-name-button">{{state.profile?.nickname}}</strong><LevelBadge :level="playerLevel(state.average.mine)" :locale="state.locale" compact/></span><span><b>{{seconds(state.average.mine.averageMs)}}</b></span><span>{{state.average.mine.totalAttempts}}</span></div></template>
        <div v-if="!averages.length" class="empty"><p>{{!state.average?(rankingLoading?t('Загружаем среднее…','Loading average…'):t('Среднее временно недоступно','Average temporarily unavailable')):(state.average.rules.minAttempts===1?t('Сыграйте первую попытку — здесь появится ваше среднее','Play your first run to see your average here'):t(`Пока нет игроков с ${state.average.rules.minAttempts} подходящими попытками`,`No player has ${state.average.rules.minAttempts} qualifying attempts yet`))}}</p><button v-if="!state.average&&!rankingLoading" class="text-button" @click="readRanking(true)">{{t('Повторить','Retry')}}</button></div>
        </div>
      </template>
      <button v-analytics="{feature: 'refresh_boards', placement: 'leaderboard'}" class="text-button full" :disabled="state.busy||rankingLoading" @click="readRanking(true)">{{ t('Обновить','Refresh') }}</button>
    </template>
    <template v-else-if="state.screen==='chart'">
      <p>{{ state.locale==='ru'?`Последние ${chart?.points.length??0} сохранённых попыток`:`Last ${chart?.points.length??0} saved attempts` }}</p><strong class="chart-total">⌁ {{ seconds(chart?.averageMs) }}</strong>
      <p>{{ t('На графике','On chart') }}: {{ chart?.points.length??0 }} · <template v-if="chart?.streaming">{{t('Среднее без фиксированного окна','Average without a fixed window')}}</template><template v-else>{{ t('В расчёте — последние','Included — last') }} {{ state.average?.rules.windowSize??50 }}</template></p>
      <AverageChart v-if="chart?.points.length" :data="chart" :locale="state.locale" />
      <div class="chart-legend"><span>▮ {{ (state.average?.rules.minDurationMs??0)===0?t('Попытка','Attempt'):t(`Попытка > ${(state.average?.rules.minDurationMs??0)/1000} с`,`Attempt > ${(state.average?.rules.minDurationMs??0)/1000} s`) }}</span><span v-if="(state.average?.rules.minDurationMs??0)>0" class="muted">▮ {{t('Не входит в среднее','Excluded from average')}}</span><span class="yellow">━ {{ t('Среднее','Average') }}</span></div><p v-if="chart&&!chart.historyComplete" class="hint">{{ t('На устройстве есть не вся история. График может отличаться от серверного среднего.','This device does not contain all history. The chart may differ from the server average.') }}</p><p class="hint">{{ t('Высокие результаты влияют сильнее низких, последние попытки — сильнее старых.','Higher results have more influence than lower ones; recent attempts have more influence than older ones.') }}</p><p v-if="!chart?.points.length" class="empty">{{ t('Нет подтверждённых попыток для графика.','No confirmed runs to chart.') }}</p>
    </template>
    <template v-else-if="target">
      <div class="player-result-identity">
        <div><div class="player-name-line"><h2>{{visibleName(target)}}</h2><div v-if="target.userId!==state.profile?.id" class="player-name-actions"><button type="button" class="player-name-menu-toggle" :aria-label="t('Скрыть имя или пожаловаться','Hide name or report')" :title="t('Скрыть имя или пожаловаться','Hide name or report')" :aria-expanded="nameMenuOpen" aria-haspopup="menu" @click="toggleNameMenu"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m3 3 18 18M10.6 5.1A11 11 0 0 1 21 12a14 14 0 0 1-3 4M6.2 6.2A14 14 0 0 0 3 12c2 4 5 7 9 7a11 11 0 0 0 4.1-.8M10 10a3 3 0 0 0 4 4"/></svg></button><div ref="nameMenu" v-if="nameMenuOpen" class="player-name-menu" :style="{transform:`translateX(${nameMenuShift}px)`}" role="menu"><button type="button" role="menuitem" :disabled="state.busy" @click="reporting=true;closeNameMenu()">{{t('Пожаловаться на имя','Report name')}}</button><button type="button" role="menuitem" :disabled="state.busy" @click="hideName">{{nameHidden?t('Показать имя для меня','Show name for me'):t('Скрыть имя для меня','Hide name for me')}}</button></div></div></div><small v-if="state.screen==='player-result'">{{selectedContext||currentPeriodLabel}}<span v-if="state.selectedScore?.place"> · #{{state.selectedScore.place}}</span></small></div>
        <GameArt v-if="state.screen==='player-result'&&state.selectedScore?.place===1" class="player-first-place" src="/assets/branding/ranking/medal-1.svg"/>
      </div>
      <template v-if="state.screen==='player-result'&&state.selectedScore">
        <PlayerResultScene :score="state.selectedScore" :locale="state.locale"/>
        <p v-if="historyPhase&&historyPhase!=='confirmed'" class="hint" role="status">{{['rejected','abandoned'].includes(historyPhase)?t('Попытка не зачтена и не входит в среднее.','This run was not counted and is excluded from the average.'):t('Результат ещё ожидает подтверждения.','This result is awaiting confirmation.')}}</p>
        <div class="player-result-meta"><p>{{date(state.selectedScore.createdAt)}}</p><p v-if="target.userId===state.profile?.id">{{t('Это ваш личный результат','This is your own result')}}</p></div>
      </template>
      <form v-if="reporting&&target.userId!==state.profile?.id" class="player-report-form" @submit.prevent="reportName"><label class="field-label">{{t('Причина жалобы','Report reason')}}<select v-model="reason"><option value="offensive_name">{{t('Оскорбительное имя','Offensive name')}}</option><option value="personal_data">{{t('Персональные данные','Personal information')}}</option><option value="impersonation">{{t('Выдаёт себя за другого','Impersonation')}}</option><option value="other">{{t('Другое','Other')}}</option></select></label><div class="button-row"><button type="button" class="text-button" @click="reporting=false">{{t('Отмена','Cancel')}}</button><button type="submit" class="secondary" :disabled="state.busy">{{t('Отправить жалобу','Submit report')}}</button></div></form>
    </template>
    <template v-if="['player-result','name-actions'].includes(state.screen)" #footer><button v-analytics="{feature: 'back', placement: 'leaderboard'}" class="secondary full" :disabled="state.busy" @click="back">{{t('Закрыть','Close')}}</button></template>
    
  </GameWindow>
  <AverageInfoDialog v-if="showAverageInfo&&state.average" :rules="state.average.rules" @close="showAverageInfo=false"/>
</template>

<style scoped>.ranking-loading{display:flex;flex-direction:column;align-items:center;gap:12px;padding:8px}.ranking-loading p{font-size:13px}.ranking-empty-art{width:56px;height:56px;object-fit:contain;margin:auto}.ranking-loading>.loading-clock{flex:none}</style>
