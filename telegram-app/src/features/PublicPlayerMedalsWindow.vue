<script setup lang="ts">
import {computed, nextTick, onBeforeUnmount, onMounted, ref} from 'vue';
import LevelBadge from '../components/LevelBadge.vue';
import LoadingClock from '../components/LoadingClock.vue';
import MedalArt from '../components/MedalArt.vue';
import ParityDialog from '../components/ParityDialog.vue';
import {awardCopy, currentCupId, medalsInSeries} from '../domain/achievement-presentation';
import {personalSeries, personalSeriesCount, type AchievementDefinition} from '../domain/achievements';
import type {LevelRankEntry, PublicPlayerMedals} from '../domain/level-ranking';
import {loadPublicPlayerMedals} from '../services/game-store';

const props=defineProps<{entry:LevelRankEntry;locale:string}>();
const emit=defineEmits<{close:[]}>();
const t=(ru:string,en:string)=>props.locale==='ru'?ru:en;
const player=ref<PublicPlayerMedals>();
const loading=ref(false), failed=ref(false);
const earned=computed(()=>new Set(player.value?.earned));
const currentCup=computed(()=>currentCupId('record',player.value?.recordPlace??null));
const ranks=[2,3,4,5,6];
const seriesTitles={
  time:['Время','Time'],
  clean:['Без усил.','No boosts'],
  risk:['Риск','Risk'],
  distance:['Шаги','Steps'],
  attempts:['Попытки','Attempts'],
  invites:['Друзья','Friends'],
};
const rows=[...personalSeries.map(series=>({
  id:series.id,
  title:seriesTitles[series.id as keyof typeof seriesTitles],
  medals:medalsInSeries(series.id),
})),{id:'ranking',title:['Рейтинг','Ranking'],medals:medalsInSeries('ranking')}];

let mounted=true;
async function load(){
  if(loading.value)return;
  loading.value=true;failed.value=false;
  try{
    const result=await loadPublicPlayerMedals(props.entry.userId);
    if(mounted)player.value=result;
  }catch{
    if(mounted)failed.value=true;
  }finally{
    if(mounted)loading.value=false;
  }
}
onMounted(load);
onBeforeUnmount(()=>{mounted=false;});

type Detail={kind:'medal';medal:AchievementDefinition}|{kind:'level';level:number}|{kind:'cup'};
const detail=ref<Detail|null>(null);
const detailDialog=ref<InstanceType<typeof ParityDialog>>();
let detailTrigger:HTMLElement|null=null;
function openDetail(value:Detail,event:MouseEvent){
  detailTrigger=event.currentTarget as HTMLElement;
  detail.value=value;
}
function closeDetail(){
  detail.value=null;
  void nextTick(()=>{if(mounted&&detailTrigger?.isConnected)detailTrigger.focus({preventScroll:true});});
}
const status=(has:boolean)=>has?t('Получена','Earned'):t('Не получена','Not earned');
const title=computed(()=>{
  const item=detail.value;
  if(!item)return '';
  if(item.kind==='medal')return awardCopy(item.medal.id,props.locale).name;
  if(item.kind==='level')return t('Уровень ','Level ')+item.level;
  return t('Кубок рекорда','Record cup');
});
</script>

<template>
  <ParityDialog :title="player?.playerName??entry.playerName" :locale="locale" name="public-player-medals"
    :inactive="detail!==null" @close="emit('close')">
    <template #header><LevelBadge :level="player?.level??entry.level" :locale="locale" compact/></template>
    <div v-if="loading" class="public-medals-status" role="status">
      <LoadingClock :size="28"/>
      <span>{{t('Загружаем медали…','Loading medals…')}}</span>
    </div>
    <div v-else-if="failed" class="public-medals-status" role="alert">
      <span>{{t('Не удалось загрузить медали','Could not load medals')}}</span>
      <button type="button" class="port-primary" @click="load">{{t('Повторить','Retry')}}</button>
    </div>
    <div v-else-if="player" class="public-medal-matrix">
      <div class="public-medal-row public-level-row">
        <span>{{t('Уровни','Levels')}}</span>
        <button v-for="level in ranks" :key="level" type="button" class="public-medal-cell" :class="{locked:player.level<level}"
          :data-public-level="level" :aria-label="t('Уровень ','Level ')+level" @click="openDetail({kind:'level',level},$event)">
          <LevelBadge :level="level" :locale="locale" compact decorative/>
        </button>
      </div>
      <div v-for="row in rows" :key="row.id" class="public-medal-row" :class="{'public-ranking-medals':row.id==='ranking'}">
        <span>{{t(row.title[0]!,row.title[1]!)}}</span>
        <button v-for="medal in row.medals" :key="medal.id" type="button" class="public-medal-cell"
          :data-public-medal="medal.id" :data-earned="earned.has(medal.id)"
          :aria-label="awardCopy(medal.id,locale).name+' · '+status(earned.has(medal.id))"
          @click="openDetail({kind:'medal',medal},$event)">
          <MedalArt :id="medal.id" thumbnail :locked="!earned.has(medal.id)"/>
        </button>
      </div>
      <button type="button" class="public-record-cup" @click="openDetail({kind:'cup'},$event)">
        <MedalArt :id="currentCup??'record-cups-1000'" thumbnail :normalized="false" :locked="!currentCup"/>
        <span><small>{{t('Кубок рекорда','Record cup')}}</small><b>{{currentCup?awardCopy(currentCup,locale).label:'—'}}</b></span>
      </button>
    </div>
  </ParityDialog>

  <ParityDialog v-if="detail" ref="detailDialog" :title="title" :locale="locale" name="public-medal-info" @close="closeDetail">
    <div class="port-information-body public-medal-info">
      <template v-if="detail.kind==='medal'">
        <MedalArt :id="detail.medal.id" large :normalized="false" :locked="!earned.has(detail.medal.id)"/>
        <p>{{t(detail.medal.helpRu,detail.medal.helpEn)}}</p>
        <strong>{{status(earned.has(detail.medal.id))}}</strong>
      </template>
      <template v-else-if="detail.kind==='level'">
        <LevelBadge :level="detail.level" :locale="locale"/>
        <p>{{t('Для этого уровня нужен полный столбец из '+personalSeriesCount+' личных медалей на ступени '+(detail.level-1)+'.',
          'This level requires all '+personalSeriesCount+' personal medals in tier '+(detail.level-1)+'.')}}</p>
        <strong>{{(player?.level??entry.level)>=detail.level?t('Достигнут','Reached'):t('Не достигнут','Not reached')}}</strong>
      </template>
      <template v-else>
        <MedalArt :id="currentCup??'record-cups-1000'" large :normalized="false" :locked="!currentCup"/>
        <p>{{t('Кубок меняется вместе с местом в рейтинге рекордов. Ступени — топ 1000, 500, 100, 10 и 1.',
          'The cup follows placement in the record leaderboard. Its tiers are top 1000, 500, 100, 10 and 1.')}}</p>
      </template>
      <button type="button" class="port-primary" @click="detailDialog?.requestClose()">{{t('Понятно','Got it')}}</button>
    </div>
  </ParityDialog>
</template>

<style scoped>
.public-medal-matrix{--public-cell:clamp(22px,calc((100dvh - 160px)/8),38px);width:min(312px,100%);padding:0 9px 10px;align-self:center}
.public-medal-row{display:grid;grid-template-columns:48px repeat(5,minmax(0,1fr));align-items:center;min-height:var(--public-cell);gap:1px}
.public-medal-row>span{color:#bedde8;font-size:10px;line-height:1.1;overflow-wrap:anywhere}
.public-level-row{background:#123e57;border-radius:7px;margin:0 0 5px;padding:2px 0}
.public-ranking-medals{border-top:1px solid #6496a7;margin-top:4px;padding-top:4px}
.public-medal-cell{display:grid;place-items:center;min-width:0;height:var(--public-cell);padding:0;border:0;background:transparent;border-radius:4px;cursor:pointer}
.public-medal-cell:focus-visible,.public-record-cup:focus-visible{outline:2px solid #ffd54a;outline-offset:-2px}
.public-medal-cell :deep(.port-medal-art),.public-medal-cell :deep(.port-level-badge){width:min(var(--public-cell),34px);height:min(var(--public-cell),34px)}
.public-medal-cell.locked :deep(.port-level-badge){opacity:.3}
.public-record-cup{display:flex;align-items:center;gap:8px;width:100%;min-height:40px;padding:2px 8px;margin-top:5px;color:#e5fcff;background:#102c40;border:1px solid #30556d;border-radius:8px;text-align:left;cursor:pointer}
.public-record-cup :deep(.port-medal-art){width:34px;height:34px}
.public-record-cup small,.public-record-cup b{display:block;font-size:11px}
.public-record-cup b{color:#ffdf7a}
.public-medals-status{min-height:112px;display:grid;place-content:center;justify-items:center;gap:10px;padding:12px;text-align:center}
.public-medal-info{display:grid;justify-items:center;gap:10px;text-align:center}
.public-medal-info :deep(.port-medal-art){width:76px;height:76px}
.public-medal-info p{margin:0}
</style>
