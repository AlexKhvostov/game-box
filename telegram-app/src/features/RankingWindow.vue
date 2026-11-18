<script setup lang="ts">
import './ranking-result-parity.css';
import { computed, ref, watch, nextTick, onBeforeUnmount } from 'vue';
import GameWindow from '../components/GameWindow.vue';
import LoadingClock from '../components/LoadingClock.vue';
import GameArt from '../components/GameArt.vue';
import MyAttemptsWindow from './MyAttemptsWindow.vue';
import LevelBadge from '../components/LevelBadge.vue';
import PublicPlayerMedalsWindow from './PublicPlayerMedalsWindow.vue';
import {levelRankingLimit, personalMedalTotal, type LevelRankEntry} from '../domain/level-ranking';
import PlayerResultScene from './PlayerResultScene.vue';
import {registerOverlayBack} from '../services/ui-overlays';
import { state, action, errorText, refreshBoards, refreshInvites, openScreen, request, back, openBestAttemptResult, achievementPanel } from '../services/game-store';
import type { Score, Attempt } from '../services/contracts';
import {recordTime} from '../domain/daily-records';
const t = (ru: string, en: string) => state.locale === 'ru' ? ru : en;
const title = computed(() => state.screen==='history'?t('Мои попытки','My runs'):state.screen==='name-actions'?t('Имя игрока','Player name'):state.screen==='player-result'?t('Результат игрока','Player result'):t('Рейтинг','Leaderboard'));
const periodLabels = computed(() => [['all',t('Всё','All')],['year',t('Год','Year')],['month',t('Мес.','Month')],['week',t('Нед.','Week')],['day',t('День','Day')]]);
const currentPeriodLabel=computed(()=>periodLabels.value.find(([id])=>id===state.period)?.[1]??'');
const records = computed(() => state.periods[state.period]??[]), ownRecord = computed(() => records.value.find(r=>r.userId===state.profile?.id));
const levels=computed(()=>state.rankingTab==='levels');
const levelRows=computed(()=>state.levelRows??[]);
const ownLevel=computed(()=>levelRows.value.find(row=>row.userId===state.profile?.id));
const currentPlace=computed(()=>levels.value?ownLevel.value?.place:ownRecord.value?.place);
const selectedMedals=ref<LevelRankEntry|null>(null);
let medalTrigger:HTMLElement|null=null;
function showMedals(row:LevelRankEntry,event:MouseEvent){
  medalTrigger=event.currentTarget as HTMLElement;
  selectedMedals.value={...row,playerName:visibleName(row)};
}
function closeMedals(){
  selectedMedals.value=null;
  void nextTick(()=>{if(medalTrigger?.isConnected&&state.screen==='ranking')medalTrigger.focus({preventScroll:true});});
}
watch(()=>[state.screen,state.profile?.id],()=>{
  selectedMedals.value=null;
  medalTrigger=null;
});
const reason = ref('offensive_name'),selectedContext=ref(''),historyPhase=ref<Attempt['phase']|null>(null),reporting=ref(false),nameMenuOpen=ref(false);
const nameMenu=ref<HTMLElement>(),nameMenuShift=ref(0);
function clampNameMenu(){const menu=nameMenu.value,body=menu?.closest('.window-body');if(!nameMenuOpen.value||!menu||!body)return;const r=menu.getBoundingClientRect(),bounds=body.getBoundingClientRect(),scale=r.width/menu.offsetWidth;if(!(scale>0))return;const inset=4*scale,delta=r.left<bounds.left+inset?bounds.left+inset-r.left:r.right>bounds.right-inset?bounds.right-inset-r.right:0;if(delta)nameMenuShift.value+=delta/scale;}
const repositionNameMenu=()=>{if(nameMenuOpen.value)void nextTick(clampNameMenu);};
let removeMenuBack:(()=>void)|undefined;
function closeNameMenu(){nameMenuOpen.value=false;nameMenuShift.value=0;window.removeEventListener('resize',repositionNameMenu);removeMenuBack?.();removeMenuBack=undefined;}
function toggleNameMenu(){if(nameMenuOpen.value){closeNameMenu();return;}nameMenuOpen.value=true;removeMenuBack=registerOverlayBack(closeNameMenu,'player_name_menu');window.addEventListener('resize',repositionNameMenu);void nextTick(clampNameMenu);}
onBeforeUnmount(closeNameMenu);
watch(()=>[state.screen,state.profile?.id],()=>{closeNameMenu();reporting.value=false;});
const playerLevel=(row:{userId?:string;achievementLevel?:number})=>row.achievementLevel??(row.userId===state.profile?.id?achievementPanel.value.level:1);
const visibleName=(row:{userId?:string;playerName:string})=>row.userId&&state.profile?.hiddenPlayers.some(id=>id===row.userId||'supabase:'+id===row.userId)?t('Скрытое имя','Hidden name'):row.playerName;
const seconds = (v?: number | null) => v==null?'—':`${(v/1000).toFixed(3).replace('.',state.locale==='ru'?',':'.')} ${t('с','s')}`;
const date = (v: number) => new Date(v).toLocaleString(state.locale==='ru'?'ru-RU':'en-US',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'});
function detail(row: Score) { if(row.userId===state.profile?.id){openBestAttemptResult(row,'ranking','ranking');return;}historyPhase.value=null; selectedContext.value=periodLabels.value.find(([id])=>id===state.period)?.[1]??'';reporting.value=false;state.selectedScore=row; openScreen('player-result','ranking'); }
function detailHistory(run:Attempt) { if(!run.result||run.owner!==state.profile?.id)return;openBestAttemptResult({id:run.requestId,userId:run.owner,playerName:state.profile!.nickname,timeMs:run.result.timeMs,riskCount:run.result.riskCount,runDistance:run.result.runDistance,createdAt:recordTime(run),hadJump:run.jump,hadHelmet:run.helmet,achievementLevel:achievementPanel.value.level},'history','history',run.phase); }
const target=computed(()=>state.screen==='name-actions'?state.selectedPlayer:state.selectedScore);
const nameHidden=computed(()=>!!target.value?.userId&&!!state.profile?.hiddenPlayers.includes(target.value.userId));
const hideName = () => {closeNameMenu();return action(async () => { const hide=!nameHidden.value;await request({ action: 'public_name_hide', target: target.value!.userId, hide }); await refreshBoards(true); if(state.invites)await refreshInvites(); state.notice = hide?t('Имя скрыто для вас','Name hidden for you'):t('Имя снова видно','Name is visible again'); });};
const reportName = () => action(async () => { await request({ action: 'public_name_report', target: target.value!.userId, reason: reason.value }); state.notice = t('Жалоба принята','Report received'); });
const rankingLoading=ref(false),rankingError=ref('');let rankingRead=0;
function readRanking(force=false){const serial=++rankingRead;rankingLoading.value=state.screen==='ranking';rankingError.value='';if(!rankingLoading.value)return;void refreshBoards(force).catch(error=>{if(serial===rankingRead)rankingError.value=errorText(error);}).finally(()=>{if(serial===rankingRead)rankingLoading.value=false;});}
watch(()=>[state.screen,state.rankingTab,state.period,state.profile?.id],()=>readRanking(),{immediate:true});
</script>
<template>
  <MyAttemptsWindow v-if="state.screen==='history'" @detail="detailHistory"/>
  <GameWindow v-else class="port-ranking-result" :title="title" tall :inactive="selectedMedals!==null" :class="state.screen==='ranking'?'ranking-window':'player-result-window'">
    <template #title><GameArt v-if="['ranking','history'].includes(state.screen)" class="window-title-art" src="/assets/branding/ranking/trophy.svg"/>{{title}}</template>
    <template v-if="state.screen==='ranking'" #header-extra>
      <button v-analytics="{feature:'history',placement:'leaderboard'}" type="button" class="ranking-progress-tile"
        :aria-label="t('Мои попытки','My attempts')+' · '+t('Место ','Rank ')+(currentPlace??'—')"
        @click="openScreen('history','ranking')">
        <strong>{{levels ? (ownLevel ? 'LVL '+ownLevel.level : '—') : seconds(ownRecord?.timeMs)}}</strong>
        <small>{{t('Место','Rank')}} <LoadingClock v-if="rankingLoading&&currentPlace==null" :size="10"/><span v-else>{{currentPlace??'—'}}</span></small>
      </button>
    </template>
    <template v-if="state.parent" #back>‹</template>
    <template v-if="state.screen==='ranking'">
      <div class="tabs">
        <button v-analytics="{feature:'ranking_record',placement:'leaderboard'}" type="button" :class="{selected:!levels}"
          :aria-pressed="!levels" @click="state.rankingTab='record'">{{t('Рекорд','Record')}}</button>
        <button v-analytics="{feature:'ranking_levels',placement:'leaderboard'}" type="button" :class="{selected:levels}"
          :aria-pressed="levels" @click="state.rankingTab='levels'">{{t('Уровни','Levels')}}</button>
      </div>
      <p class="hint">{{levels?t('Уровни · топ 200','Levels · top 200'):t('Рекорды · топ 200','Records · top 200')}}</p>
      <template v-if="levels">
        <div class="level-rank-grid level-rank-header">
          <span>#</span><span>{{t('Игрок','Player')}}</span><span>{{t('Уровень','Level')}}</span><span>{{t('Медали','Medals')}}</span>
        </div>
        <div v-if="rankingLoading" class="ranking-loading" role="status"><LoadingClock :size="24"/></div>
        <p v-if="rankingError&&levelRows.length" class="hint">{{t('Показаны последние загруженные уровни','Showing the last loaded levels')}}</p>
        <div class="ranking-list" key="levels">
          <template v-for="row in levelRows" :key="row.userId">
            <p v-if="row.place>levelRankingLimit" class="ranking-own-divider">{{t('Ваше место','Your place')}}</p>
            <button type="button" v-analytics="{feature:'player_medals',placement:'leaderboard'}"
              class="rank-row level-rank-grid level-rank-row" :class="{mine:row.userId===state.profile?.id}"
              :data-level-rank="row.place" @click="showMedals(row,$event)">
              <span class="place"><GameArt v-if="row.place<=3" :src="'/assets/branding/ranking/medal-'+row.place+'.svg'" :alt="String(row.place)"/><b v-else>{{row.place}}</b></span>
              <strong class="level-rank-name">{{visibleName(row)}}</strong>
              <LevelBadge :level="row.level" :locale="state.locale" compact/>
              <strong class="level-rank-count">{{row.medalCount}}<small>/{{personalMedalTotal}}</small></strong>
            </button>
          </template>
          <div v-if="!levelRows.length&&!rankingLoading" class="empty">
            <p>{{rankingError?t('Не удалось загрузить уровни','Could not load levels'):t('Пока нет игроков','No players yet')}}</p>
            <button v-if="rankingError" type="button" class="text-button" @click="readRanking(true)">{{t('Повторить','Retry')}}</button>
          </div>
        </div>
      </template>
      <template v-else>
      <div class="ranking-intro"><span><img src="/assets/branding/ranking/jump.svg" alt="">{{ t('Прыжок','Jump') }} · <img src="/assets/branding/ranking/helmet.svg" alt="">{{ t('Шлем','Helmet') }}<small>{{ t('Яркие — были включены','Bright icons were enabled') }}</small></span></div>
        <div class="segments"><button v-analytics="{feature: 'ranking_period', placement: 'leaderboard'}" v-for="[id,label] in periodLabels" :key="id" :class="{selected:state.period===id}" @click="state.period=id!">{{ label }}</button></div>
        <div v-if="rankingLoading" class="ranking-loading" role="status"><LoadingClock :size="records.length?28:24"/><p v-if="!records.length">{{t('Загружаем рейтинг…','Loading leaderboard…')}}</p></div><p v-if="rankingError&&records.length" class="hint">{{t('Показаны последние загруженные результаты','Showing the last loaded results')}}</p>
        <div class="rank-header"><span>#</span><span>{{ t('Игрок','Player') }}</span><span>{{ t('Усиления','Boosts') }}</span><span>{{ t('Результат','Result') }}</span></div>
        <div class="ranking-list">
        <button v-analytics="{feature: 'detail', placement: 'leaderboard'}" v-for="row in records.filter(r=>(r.place??0)<=200)" :key="row.id" class="rank-row" :class="{mine:row.userId===state.profile?.id}" @click="detail(row)"><span class="place"><GameArt v-if="row.place&&row.place<=3" :src="`/assets/branding/ranking/medal-${row.place}.svg`" :alt="String(row.place)"/><b v-else>{{row.place}}</b></span><span class="rank-identity"><span class="rank-name"><strong>{{ visibleName(row) }}</strong><small>{{ date(row.createdAt) }}</small></span><LevelBadge :level="playerLevel(row)" :locale="state.locale" compact/></span><span class="boost-icons"><img :class="{dim:!row.hadJump}" src="/assets/branding/ranking/jump.svg" :alt="t('Прыжок','Jump')"><img :class="{dim:!row.hadHelmet}" src="/assets/branding/ranking/helmet.svg" :alt="t('Шлем','Helmet')"></span><span class="rank-value"><strong>{{ seconds(row.timeMs) }}</strong><small><GameArt class="inline-metric-art" src="/assets/branding/ranking/risk.svg"/> {{row.riskCount}} · <GameArt class="inline-metric-art" src="/assets/branding/ranking/footsteps.svg"/> {{row.runDistance}}</small></span></button>
        <p v-if="ownRecord&&(ownRecord.place??0)>levelRankingLimit" class="ranking-own-divider">{{t('Ваше место','Your place')}}</p>
        <button v-analytics="{feature: 'detail', placement: 'leaderboard'}" v-if="ownRecord&&(ownRecord.place??0)>levelRankingLimit" class="rank-row mine own-row" @click="detail(ownRecord)"><b class="place">{{ ownRecord.place }}</b><span class="rank-identity"><span class="rank-name"><strong>{{visibleName(ownRecord)}}</strong><small>{{date(ownRecord.createdAt)}}</small></span><LevelBadge :level="playerLevel(ownRecord)" :locale="state.locale" compact/></span><span class="boost-icons"><img :class="{dim:!ownRecord.hadJump}" src="/assets/branding/ranking/jump.svg" :alt="t('Прыжок','Jump')"><img :class="{dim:!ownRecord.hadHelmet}" src="/assets/branding/ranking/helmet.svg" :alt="t('Шлем','Helmet')"></span><strong class="rank-value">{{ seconds(ownRecord.timeMs) }}</strong></button>
        <div v-if="!records.length&&!rankingLoading" class="empty"><GameArt class="ranking-empty-art" src="/assets/branding/ui/hero-ready-v1.png"/><p>{{rankingError?t('Не удалось загрузить рейтинг. Проверьте сеть.','Could not load the leaderboard. Check your connection.'):t('Подтверждённых результатов пока нет.','No confirmed results yet.')}}</p><button v-if="rankingError" class="text-button" @click="readRanking(true)">{{t('Повторить','Retry')}}</button></div>
        </div>
      </template>
      <button v-analytics="{feature: 'refresh_boards', placement: 'leaderboard'}" class="text-button full" :disabled="state.busy||rankingLoading" @click="readRanking(true)">{{ t('Обновить','Refresh') }}</button>
    </template>
    <template v-else-if="target">
      <div class="player-result-identity">
        <div><div class="player-name-line"><h2>{{visibleName(target)}}</h2><div v-if="target.userId!==state.profile?.id" class="player-name-actions"><button type="button" class="player-name-menu-toggle" :aria-label="t('Скрыть имя или пожаловаться','Hide name or report')" :title="t('Скрыть имя или пожаловаться','Hide name or report')" :aria-expanded="nameMenuOpen" aria-haspopup="menu" @click="toggleNameMenu"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m3 3 18 18M10.6 5.1A11 11 0 0 1 21 12a14 14 0 0 1-3 4M6.2 6.2A14 14 0 0 0 3 12c2 4 5 7 9 7a11 11 0 0 0 4.1-.8M10 10a3 3 0 0 0 4 4"/></svg></button><div ref="nameMenu" v-if="nameMenuOpen" class="player-name-menu" :style="{transform:`translateX(${nameMenuShift}px)`}" role="menu"><button type="button" role="menuitem" :disabled="state.busy" @click="reporting=true;closeNameMenu()">{{t('Пожаловаться на имя','Report name')}}</button><button type="button" role="menuitem" :disabled="state.busy" @click="hideName">{{nameHidden?t('Показать имя для меня','Show name for me'):t('Скрыть имя для меня','Hide name for me')}}</button></div></div></div><small v-if="state.screen==='player-result'">{{selectedContext||currentPeriodLabel}}<span v-if="state.selectedScore?.place"> · #{{state.selectedScore.place}}</span></small></div>
        <GameArt v-if="state.screen==='player-result'&&state.selectedScore?.place===1" class="player-first-place" src="/assets/branding/ranking/medal-1.svg"/>
      </div>
      <template v-if="state.screen==='player-result'&&state.selectedScore">
        <PlayerResultScene :score="state.selectedScore" :locale="state.locale"/>
        <p v-if="historyPhase&&historyPhase!=='confirmed'" class="hint" role="status">{{['rejected','abandoned'].includes(historyPhase)?t('Попытка не зачтена.','This run was not counted.'):t('Результат ещё ожидает подтверждения.','This result is awaiting confirmation.')}}</p>
        <div class="player-result-meta"><p>{{date(state.selectedScore.createdAt)}}</p><p v-if="target.userId===state.profile?.id">{{t('Это ваш личный результат','This is your own result')}}</p></div>
      </template>
      <form v-if="reporting&&target.userId!==state.profile?.id" class="player-report-form" @submit.prevent="reportName"><label class="field-label">{{t('Причина жалобы','Report reason')}}<select v-model="reason"><option value="offensive_name">{{t('Оскорбительное имя','Offensive name')}}</option><option value="personal_data">{{t('Персональные данные','Personal information')}}</option><option value="impersonation">{{t('Выдаёт себя за другого','Impersonation')}}</option><option value="other">{{t('Другое','Other')}}</option></select></label><div class="button-row"><button type="button" class="text-button" @click="reporting=false">{{t('Отмена','Cancel')}}</button><button type="submit" class="secondary" :disabled="state.busy">{{t('Отправить жалобу','Submit report')}}</button></div></form>
    </template>
    <template v-if="['player-result','name-actions'].includes(state.screen)" #footer><button v-analytics="{feature: 'back', placement: 'leaderboard'}" class="secondary full" :disabled="state.busy" @click="back">{{t('Закрыть','Close')}}</button></template>
    
  </GameWindow>
  <PublicPlayerMedalsWindow v-if="selectedMedals" :key="selectedMedals.userId" :entry="selectedMedals"
    :locale="state.locale" @close="closeMedals"/>
</template>

<style scoped>
.ranking-loading{display:flex;flex-direction:column;align-items:center;gap:12px;padding:8px}.ranking-loading p{font-size:13px}.ranking-empty-art{width:56px;height:56px;object-fit:contain;margin:auto}.ranking-loading>.loading-clock{flex:none}
.ranking-progress-tile{display:grid;align-content:center;gap:1px;min-width:76px;max-width:112px;min-height:36px;margin-left:auto;padding:3px 7px;border:0;border-left:2px solid #65ccb4;border-radius:6px;color:#eafff9;background:linear-gradient(120deg,#4de0c724,#102ec610);cursor:pointer;text-align:left;overflow:hidden}
.ranking-progress-tile strong{font-size:13px;white-space:nowrap;font-variant-numeric:tabular-nums}
.ranking-progress-tile small{display:flex;align-items:center;gap:3px;color:#a2c6d7;font-size:9px;white-space:nowrap}
.level-rank-grid{display:grid;grid-template-columns:32px minmax(0,1fr) 44px 48px;align-items:center;gap:4px;padding-inline:5px}
.level-rank-header{color:#a4cdef;font-size:10px;padding-block:4px}
.level-rank-grid>:nth-child(3){justify-self:center}.level-rank-grid>:last-child{justify-self:end}
.window-body .level-rank-row{grid-template-columns:32px minmax(0,1fr) 44px 48px;min-height:46px;gap:4px;text-align:left}
.level-rank-name{overflow:hidden;white-space:nowrap;text-overflow:ellipsis;font-size:13px}
.level-rank-count{color:#ffed9b;font-variant-numeric:tabular-nums;font-size:13px}
.level-rank-count small{color:#a9cce4;font-size:10px}
.level-rank-row :deep(.port-level-badge){width:28px;height:33px}
.ranking-own-divider{margin:7px 4px 4px;color:#a2c6d7;font-size:10px}
</style>
