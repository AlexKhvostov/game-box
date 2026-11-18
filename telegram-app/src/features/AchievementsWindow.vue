<script setup lang="ts">
import {computed,ref,nextTick,onMounted,onBeforeUnmount} from 'vue';
import LoadingClock from '../components/LoadingClock.vue';
import {telegram} from '../platform/telegram';
import ParityDialog from '../components/ParityDialog.vue';
import LevelBadge from '../components/LevelBadge.vue';
import MedalArt from '../components/MedalArt.vue';
import EnergyAmount from '../components/EnergyAmount.vue';
import AchievementMedalTile from '../components/AchievementMedalTile.vue';
import AchievementLevelHelp from './AchievementLevelHelp.vue';
import {achievementSeries,achievements,personalSeriesCount,medalById} from '../domain/achievements';
import {personalSeriesIds,medalsInSeries,medalReward,medalProgress,activeMedalCount,currentCupId,safeLevel,awardCopy,medalTierColor,type AchievementPanelModel,type StatisticDestination} from '../domain/achievement-presentation';
const props=withDefaults(defineProps<{model:AchievementPanelModel;locale:string;loading?:boolean;error?:string}>(),{loading:false,error:''});
const emit=defineEmits<{close:[];'open-statistic':[StatisticDestination];retry:[]}>();
const foreground=ref(!document.hidden&&telegram()?.isActive!==false),activity=()=>foreground.value=!document.hidden&&telegram()?.isActive!==false;
const collectionReady=ref(false);
let collectionFrame=0;
function stopCollectionFrame(){cancelAnimationFrame(collectionFrame);}
onMounted(()=>{
  document.addEventListener('visibilitychange',activity);telegram()?.onEvent('activated',activity);telegram()?.onEvent('deactivated',activity);
  // Let the title and progress appear before creating all medal tiles.
  collectionFrame=requestAnimationFrame(()=>{
    collectionFrame=requestAnimationFrame(()=>{collectionReady.value=true;});
  });
});
onBeforeUnmount(()=>{stopCollectionFrame();document.removeEventListener('visibilitychange',activity);telegram()?.offEvent('activated',activity);telegram()?.offEvent('deactivated',activity);});
const selected=ref<number|null>(null),detail=ref<string|null>(null),help=ref<string|null>(null),levelHelp=ref(false);
const ru=computed(()=>props.locale==='ru'),count=computed(()=>activeMedalCount(props.model.earnedIds)),level=computed(()=>safeLevel(props.model.level));
const rows=computed(()=>personalSeriesIds.map(id=>achievementSeries.find(s=>s.id===id)!));
const medal=computed(()=>detail.value?medalById(detail.value):undefined),earned=(id:string)=>props.model.earnedIds.includes(id);
const seconds=(value:number|null)=>value===null?'—':`${(value/1000).toFixed(value%1000===0?0:1)} ${ru.value?'с':'s'}`;
const statValue=(id:StatisticDestination)=>{
  const metric=props.model.metrics?.[id==='record'?'time':'attempts'];
  if(metric===undefined&&props.model.metrics!==undefined)return '—';
  return id==='history'?String(Math.trunc(metric??props.model.totalAttempts)):seconds(metric===undefined?props.model.bestTimeMs:metric*1000);
};
const recordCup=computed(()=>currentCupId('record',props.model.recordRank));
const label=(id:string)=>medalById(id)?awardCopy(id,props.locale).label:id;
const progress=computed(()=>medal.value?medalProgress(props.model,medal.value.id):{current:0,target:1});
const chosenHelp=computed(()=>achievementSeries.find(s=>s.id===help.value));
let levelTrigger:HTMLElement|null=null,detailTrigger:HTMLElement|null=null;
function openLevelHelp(event:MouseEvent){
  levelTrigger=event.currentTarget as HTMLElement;
  levelHelp.value=true;
}
function openDetail(id:string,event:MouseEvent){
  detailTrigger=event.currentTarget as HTMLElement;
  detail.value=id;
}
function closeLevelHelp(){
  levelHelp.value=false;
  void nextTick(()=>{if(levelTrigger?.isConnected)levelTrigger.focus({preventScroll:true});});
}
function closeDetail(){
  detail.value=null;
  const trigger=detailTrigger;
  detailTrigger=null;
  void nextTick(()=>{if(trigger?.isConnected)trigger.focus({preventScroll:true});});
}
</script>
<template>
  <ParityDialog :title="ru?'Достижения':'Achievements'" :locale="locale" name="achievements" wide :inactive="!!detail||!!help||levelHelp" @closing="stopCollectionFrame" @close="emit('close')">
    <template #eyebrow><small class="port-level-caption">{{level>=6?(ru?'LVL 6 · ВСЕ СТУПЕНИ СОБРАНЫ':'LVL 6 · ALL MEDAL TIERS COMPLETE'):`LVL ${level} · ${ru?'до':'to'} LVL ${level+1} · ${model.levelCounts[level-1]??0}/${personalSeriesCount}`}}</small></template>
    <template #header><button class="port-level-info" :aria-label="ru?'Уровень игрока':'Player level'" @click="openLevelHelp"><LevelBadge :level="level" :locale="locale"/><i>i</i></button></template>
    <div class="port-achievement-content">
      
      <div class="own-achievement-stats" role="group" :lang="locale" :aria-label="ru?'Кубок, рекорд и попытки':'Cup, record and attempts'">
        <button type="button" data-achievement-stat="cup"
          :aria-label="(ru?'Кубок рекорда':'Record cup')+(recordCup?' · '+awardCopy(recordCup,locale).label:'')"
          @click="openDetail('record-cup-detail',$event)">
          <MedalArt :id="recordCup??'record-cups-1000'" thumbnail :locked="!recordCup" :normalized="false"/>
          <b>{{recordCup?awardCopy(recordCup,locale).label:'—'}}</b>
        </button>
        <button type="button" data-achievement-stat="record" @click="emit('open-statistic','record')">
          <small>{{ru?'Рекорд':'Record'}}</small><b>{{statValue('record')}}</b>
        </button>
        <button type="button" data-achievement-stat="attempts" @click="emit('open-statistic','history')">
          <small>{{ru?'Попытки':'Attempts'}}</small><b>{{statValue('history')}}</b>
        </button>
      </div>
      <div class="port-collection-count"><span>{{ru?'Коллекция медалей':'Medal collection'}}</span><b>{{count}}/{{achievements.length}}</b></div><progress class="port-collection-progress" :value="count" :max="achievements.length" :aria-label="ru?'Коллекция медалей':'Medal collection'"></progress>
      <button v-if="error" class="port-retry" @click="emit('retry')">{{ru?'Не удалось обновить · повторить':'Could not refresh · retry'}}</button><div v-if="loading&&!model.confirmed" class="port-achievement-loading" role="status" :aria-label="ru?'Загрузка достижений':'Loading achievements'"><LoadingClock :size="28" :active="foreground&&!detail&&!help&&!levelHelp"/></div>
      <div class="port-medal-scroll" :style="selected===null?undefined:{'--selected-column':selected}" :aria-busy="!collectionReady">
        <div v-if="!collectionReady" class="port-achievement-loading" aria-hidden="true"><LoadingClock :size="28"/></div>
        <template v-else>
        <div class="port-tier-head"><div class="port-tier-copy"><b>{{ru?'УРОВНИ ИГРОКА':'PLAYER LEVELS'}}</b><span>{{ru?'6 серий → +1 LVL':'6 series → +1 LVL'}}</span></div><div class="port-tier-buttons"><button v-for="n in 5" :key="n" :class="{selected:selected===n-1}" :style="{'--medal-color':medalTierColor(n-1)}" :aria-pressed="selected===n-1" :aria-label="`${ru?'Ступень':'Tier'} ${n}, LVL ${n+1}, ${model.levelCounts[n-1]??0}/${personalSeriesCount}`" @click="selected=n-1"><LevelBadge :level="n+1" :locale="locale"/><span class="port-tier-segments" aria-hidden="true"><i v-for="segment in personalSeriesCount" :key="segment" :class="{lit:segment<=(model.levelCounts[n-1]??0)}"></i></span><small>{{model.levelCounts[n-1]??0}}/{{personalSeriesCount}}</small><i v-if="model.levelCounts[n-1]===personalSeriesCount" class="port-tier-complete" aria-hidden="true">✓</i><i v-if="selected===n-1" class="port-tier-arrow" aria-hidden="true">▾</i></button></div></div>
        <div class="port-personal-medals"><i v-if="selected!==null" class="port-column-beam" aria-hidden="true"></i><section v-for="series in rows" :key="series.id" class="port-medal-row"><header><h2>{{ru?series.ru:series.en}}</h2><small>{{medalsInSeries(series.id).filter(m=>earned(m.id)).length}}/5</small><button class="port-series-help" :aria-label="`${ru?'О категории':'About'} ${ru?series.ru:series.en}`" @click="help=series.id">ⓘ</button></header><div class="port-medal-grid"><AchievementMedalTile v-for="m in medalsInSeries(series.id)" :key="m.id" :medal="m" :locale="locale" :earned="earned(m.id)" :reward="medalReward(model,m.id,m.tier)" @select="openDetail(m.id,$event)"/></div></section></div>
        </template>
      </div>
      <section v-if="collectionReady" class="port-medal-row port-ranking-medals"><header><h2>{{ru?'Победы в рейтинге':'Leaderboard wins'}}</h2><small>{{medalsInSeries('ranking').filter(m=>earned(m.id)).length}}/5</small><button class="port-series-help" :aria-label="ru?'О победах в рейтинге':'About leaderboard wins'" @click="help='ranking'">ⓘ</button></header><div class="port-medal-grid"><AchievementMedalTile v-for="m in medalsInSeries('ranking')" :key="m.id" :medal="m" :locale="locale" :earned="earned(m.id)" :reward="medalReward(model,m.id,m.tier)" @select="openDetail(m.id,$event)"/></div></section>
    </div>
  </ParityDialog>
  <AchievementLevelHelp v-if="levelHelp" :level="level" :earned-ids="model.earnedIds" :locale="locale"
    :inactive="!!detail" @medal="openDetail" @close="closeLevelHelp"/>
  <ParityDialog v-if="detail" :title="medal?`${ru?medal.titleRu:medal.titleEn} · ${label(medal.id)}`:(ru?'Рекорд':'Record')" :locale="locale" name="achievement-detail" @close="closeDetail">
    <div class="port-medal-detail" v-if="medal">
      <MedalArt thumbnail :id="medal.id" large :normalized="false"/>
      <p>{{ru?medal.helpRu:medal.helpEn}}</p>
      <progress v-if="!earned(medal.id)" :value="Math.min(progress.current,progress.target)" :max="progress.target" :aria-label="ru?'Прогресс':'Progress'"></progress>
      <div class="port-medal-detail-status"><svg viewBox="0 0 24 24" :class="{earned:earned(medal.id)}" aria-hidden="true"><template v-if="earned(medal.id)"><circle cx="12" cy="12" r="10"/><path d="m7 12 3 3 7-7"/></template><template v-else><rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V6a4 4 0 0 1 8 0v4M12 14v3"/></template></svg><span>{{earned(medal.id)?(ru?'Получена':'Earned'):(ru?'Предстоит получить':'Not earned yet')}}</span><EnergyAmount v-if="medalReward(model,medal.id,medal.tier)>0" :amount="medalReward(model,medal.id,medal.tier)" prefix="+"/></div>
    </div>
    <div class="port-information-body port-cup-detail" v-else>
      <MedalArt thumbnail :id="recordCup??'record-cups-1000'" large :normalized="false" :locked="!recordCup"/>
      <strong>{{recordCup?`TOP ${recordCup?.split('-').at(-1)} · ${ru?'Место':'Rank'} ${model.recordRank}`:(ru?'Войдите в топ 1000, чтобы получить кубок.':'Reach the top 1000 to receive a cup.')}}</strong>
      <p class="port-information-muted">{{ru?'Переходящий статус: топ 1000 / 500 / 100 / 10 / 1. Кубок меняется вместе с вашим местом. Поздравление показывается только при повышении. Энергия за кубки не начисляется.':'A current status: top 1000 / 500 / 100 / 10 / 1. The cup changes with your rank. Only promotions are celebrated. Cups do not award energy.'}}</p>
    </div>
  </ParityDialog>
  <ParityDialog v-if="help&&chosenHelp" :title="ru?chosenHelp.ru:chosenHelp.en" :locale="locale" name="achievement-help" @close="help=null">
    <div class="port-information-body port-series-detail"><p>{{ru?chosenHelp.helpRu:chosenHelp.helpEn}}</p><div class="port-series-detail-tiers"><div v-for="m in medalsInSeries(help)" :key="m.id"><span>{{label(m.id)}}</span><EnergyAmount :amount="model.energyByTier[m.tier]??0" prefix="+"/></div></div><p class="port-information-muted">{{ru?'Энергия начисляется один раз за каждую медаль.':'Energy is awarded once per medal.'}}</p></div>
  </ParityDialog>
</template>

<style scoped>
.own-achievement-stats{
  display:grid;grid-template-columns:repeat(3,minmax(0,1fr));min-width:0;flex:none;
  margin-top:6px;padding:3px 4px;border:1px solid #3e7488;border-radius:12px;background:#102f43
}
.own-achievement-stats>button{
  display:grid;grid-template-columns:minmax(0,1fr);place-content:center;justify-items:center;
  position:relative;min-width:0;min-height:43px;gap:2px;
  padding:2px 4px;border:0;border-radius:6px;background:transparent;color:#e5fcff;line-height:1.12;cursor:pointer
}
.own-achievement-stats>button+button::before{
  position:absolute;left:0;top:50%;height:65%;width:1px;transform:translateY(-50%);background:#376578;content:''
}
.own-achievement-stats>button:focus-visible{outline:2px solid #ffd54a;outline-offset:-2px}
.own-achievement-stats small,.own-achievement-stats b{max-width:100%;overflow-wrap:anywhere;text-align:center}
.own-achievement-stats small{font-size:calc(.6rem * var(--achievement-text-scale,1));color:#adc9d9}
.own-achievement-stats b{font-size:calc(.86rem * var(--achievement-text-scale,1));font-variant-numeric:tabular-nums}
.own-achievement-stats [data-achievement-stat="cup"] b{font-size:calc(.7rem * var(--achievement-text-scale,1));color:#ffdf7a}
.own-achievement-stats :deep(.port-medal-art){width:25px;height:23px}
</style>
