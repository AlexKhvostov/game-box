<script setup lang="ts">
import {computed,ref,onMounted,onBeforeUnmount} from 'vue';
import LoadingClock from '../components/LoadingClock.vue';
import {telegram} from '../platform/telegram';
import ParityDialog from '../components/ParityDialog.vue';
import LevelBadge from '../components/LevelBadge.vue';
import MedalArt from '../components/MedalArt.vue';
import EnergyAmount from '../components/EnergyAmount.vue';
import {achievementSeries,medalById} from '../domain/achievements';
import {personalSeriesIds,medalsInSeries,medalReward,medalProgress,activeMedalCount,currentCupId,safeLevel,type AchievementPanelModel,type StatisticDestination} from '../domain/achievement-presentation';
const props=withDefaults(defineProps<{model:AchievementPanelModel;locale:string;loading?:boolean;error?:string}>(),{loading:false,error:''});
const emit=defineEmits<{close:[];'open-statistic':[StatisticDestination];retry:[]}>();
const foreground=ref(!document.hidden&&telegram()?.isActive!==false),activity=()=>foreground.value=!document.hidden&&telegram()?.isActive!==false;
onMounted(()=>{document.addEventListener('visibilitychange',activity);telegram()?.onEvent('activated',activity);telegram()?.onEvent('deactivated',activity);});
onBeforeUnmount(()=>{document.removeEventListener('visibilitychange',activity);telegram()?.offEvent('activated',activity);telegram()?.offEvent('deactivated',activity);});
const levelDialog=ref<InstanceType<typeof ParityDialog>>();
const selected=ref<number|null>(null),detail=ref<string|null>(null),help=ref<string|null>(null),levelHelp=ref(false);
const ru=computed(()=>props.locale==='ru'),count=computed(()=>activeMedalCount(props.model.earnedIds)),level=computed(()=>safeLevel(props.model.level));
const rows=computed(()=>personalSeriesIds.map(id=>achievementSeries.find(s=>s.id===id)!));
const medal=computed(()=>detail.value?medalById(detail.value):undefined),earned=(id:string)=>props.model.earnedIds.includes(id);
const detailCupFamily=computed(()=>'average'===(detail.value??'').split('-')[0]?'average':'record');
const cupRank=(family:'record'|'average')=>family==='record'?props.model.recordRank:props.model.averageRank;
const seconds=(value:number|null)=>value===null?'—':`${(value/1000).toFixed(value%1000===0?0:1)} ${ru.value?'с':'s'}`;
const statValue=(id:StatisticDestination)=>{const key=id==='record'?'time':id==='history'?'attempts':'average',metrics=props.model.metrics;if(metrics!==undefined){const value=metrics[key];return value===undefined?'—':id==='history'?String(Math.trunc(value)):seconds(value*1000);}return id==='history'?String(props.model.totalAttempts):seconds(id==='record'?props.model.bestTimeMs:props.model.averageMs);};
const label=(id:string)=>{const m=medalById(id);return m?(m.series==='ranking'?(ru.value?['День','Неделя','Месяц','Год','Топ 1']:['Day','Week','Month','Year','Top 1'])[m.tier]!: `${m.value}${m.seconds?(ru.value?' с':' s'):''}`):id;};
const progress=computed(()=>medal.value?medalProgress(props.model,medal.value.id):{current:0,target:1});
const chosenHelp=computed(()=>achievementSeries.find(s=>s.id===help.value));
const nextLevelTier=computed(()=>Math.min(4,Math.max(0,level.value-1)));
const levelTargets=computed(()=>rows.value.map(series=>medalsInSeries(series.id)[nextLevelTier.value]!).filter(Boolean));
const levelTargetCount=computed(()=>props.model.levelCounts[nextLevelTier.value]??0);
const tierColor=(tier:number)=>['#52e3d5','#ba91ff','#dce9f3','#e5a177','#ffcf59'][tier]??'#52e3d5';
function closeDetail(){detail.value=null;help.value=null;levelHelp.value=false;}
</script>
<template>
  <ParityDialog :title="ru?'Достижения':'Achievements'" :locale="locale" name="achievements" wide :inactive="!!detail||!!help||levelHelp" @close="emit('close')">
    <template #eyebrow><small class="port-level-caption">{{level>=6?(ru?'LVL 6 · ВСЕ СТУПЕНИ СОБРАНЫ':'LVL 6 · ALL MEDAL TIERS COMPLETE'):`LVL ${level} · ${ru?'до':'to'} LVL ${level+1} · ${model.levelCounts[level-1]??0}/7`}}</small></template>
    <template #header><button class="port-level-info" :aria-label="ru?'Уровень игрока':'Player level'" @click="levelHelp=true"><LevelBadge :level="level" :locale="locale"/><i>i</i></button></template>
    <div class="port-achievement-content">
      
      <div class="port-achievement-stats"><button v-for="(id,i) in (['record','average','history'] as const)" :key="id" @click="emit('open-statistic',id)"><small>{{[ru?'Рекорд':'Record',ru?'Среднее':'Average',ru?'Попытки':'Attempts'][i]}} ›</small><span><img :src="`/assets/achievements/ui/${['record','average','attempts'][i]}-art-v1.webp`" alt=""><b>{{statValue(id)}}</b></span></button></div>
      <div class="port-snapshot-cups"><button v-for="family in (['record','average'] as const)" :key="family" @click="detail=`${family}-cup-detail`"><MedalArt thumbnail :id="currentCupId(family,cupRank(family))??`${family}-cups-1000`" :locked="!currentCupId(family,cupRank(family))" :normalized="false"/><span><small>{{family==='record'?(ru?'Рекорд':'Record'):(ru?'Среднее время':'Average time')}}</small><b>{{currentCupId(family,cupRank(family))?`TOP ${currentCupId(family,cupRank(family))?.split('-').at(-1)}`:'—'}}</b><small>{{ru?'Место':'Rank'}} {{cupRank(family)??'—'}}</small></span></button></div>
      <div class="port-collection-count"><span>{{ru?'Коллекция медалей':'Medal collection'}}</span><b>{{count}}/40</b></div><progress class="port-collection-progress" :value="count" max="40" :aria-label="ru?'Коллекция медалей':'Medal collection'"></progress>
      <button v-if="error" class="port-retry" @click="emit('retry')">{{ru?'Не удалось обновить · повторить':'Could not refresh · retry'}}</button><div v-if="loading&&!model.confirmed" class="port-achievement-loading" role="status" :aria-label="ru?'Загрузка достижений':'Loading achievements'"><LoadingClock :size="28" :active="foreground&&!detail&&!help&&!levelHelp"/></div>
      <div class="port-medal-scroll" :style="selected===null?undefined:{'--selected-column':selected}">
        <div class="port-tier-head"><div class="port-tier-copy"><b>{{ru?'УРОВНИ ИГРОКА':'PLAYER LEVELS'}}</b><span>{{ru?'7 серий → +1 LVL':'7 series → +1 LVL'}}</span></div><div class="port-tier-buttons"><button v-for="n in 5" :key="n" :class="{selected:selected===n-1}" :style="{'--medal-color':tierColor(n-1)}" :aria-pressed="selected===n-1" :aria-label="`${ru?'Ступень':'Tier'} ${n}, LVL ${n+1}, ${model.levelCounts[n-1]??0}/7`" @click="selected=n-1"><LevelBadge :level="n+1" :locale="locale"/><span class="port-tier-segments" aria-hidden="true"><i v-for="segment in 7" :key="segment" :class="{lit:segment<=(model.levelCounts[n-1]??0)}"></i></span><small>{{model.levelCounts[n-1]??0}}/7</small><i v-if="model.levelCounts[n-1]===7" class="port-tier-complete" aria-hidden="true">✓</i><i v-if="selected===n-1" class="port-tier-arrow" aria-hidden="true">▾</i></button></div></div>
        <div class="port-personal-medals"><i v-if="selected!==null" class="port-column-beam" aria-hidden="true"></i><section v-for="series in rows" :key="series.id" class="port-medal-row"><header><h2>{{ru?series.ru:series.en}}</h2><small>{{medalsInSeries(series.id).filter(m=>earned(m.id)).length}}/5</small><button class="port-series-help" :aria-label="`${ru?'О категории':'About'} ${ru?series.ru:series.en}`" @click="help=series.id">ⓘ</button></header><div class="port-medal-grid"><button v-for="m in medalsInSeries(series.id)" :key="m.id" :data-medal-id="m.id" :class="{earned:earned(m.id)}" :style="{'--medal-color':tierColor(m.tier)}" :aria-label="`${ru?series.ru:series.en}: ${label(m.id)}. ${earned(m.id)?(ru?'Получено':'Earned'):(ru?'Закрыто':'Locked')}`" @click="detail=m.id"><MedalArt thumbnail :id="m.id" :locked="!earned(m.id)"/><i v-if="earned(m.id)" class="port-earned-check" aria-hidden="true">✓</i><strong>{{label(m.id)}}</strong><EnergyAmount v-if="medalReward(model,m.id,m.tier)>0" :amount="medalReward(model,m.id,m.tier)" prefix="+"/><span v-else class="port-medal-empty-reward" aria-hidden="true"></span></button></div></section></div>
      </div>
      <section class="port-medal-row port-ranking-medals"><header><h2>{{ru?'Победы в рейтинге':'Leaderboard wins'}}</h2><small>{{medalsInSeries('ranking').filter(m=>earned(m.id)).length}}/5</small><button class="port-series-help" :aria-label="ru?'О победах в рейтинге':'About leaderboard wins'" @click="help='ranking'">ⓘ</button></header><div class="port-medal-grid"><button v-for="m in medalsInSeries('ranking')" :key="m.id" :data-medal-id="m.id" :class="{earned:earned(m.id)}" :style="{'--medal-color':tierColor(m.tier)}" @click="detail=m.id"><MedalArt thumbnail :id="m.id" :locked="!earned(m.id)"/><i v-if="earned(m.id)" class="port-earned-check" aria-hidden="true">✓</i><strong>{{label(m.id)}}</strong><EnergyAmount v-if="medalReward(model,m.id,m.tier)>0" :amount="medalReward(model,m.id,m.tier)" prefix="+"/><span v-else class="port-medal-empty-reward" aria-hidden="true"></span></button></div></section>
    </div>
  </ParityDialog>
  <ParityDialog v-if="detail" :title="medal?`${ru?medal.titleRu:medal.titleEn} · ${label(medal.id)}`:(detailCupFamily==='record'?(ru?'Рекорд':'Record'):(ru?'Среднее время':'Average time'))" :locale="locale" name="achievement-detail" @close="closeDetail">
    <div class="port-medal-detail" v-if="medal">
      <MedalArt thumbnail :id="medal.id" large :normalized="false"/>
      <p>{{ru?medal.helpRu:medal.helpEn}}</p>
      <progress v-if="!earned(medal.id)" :value="Math.min(progress.current,progress.target)" :max="progress.target" :aria-label="ru?'Прогресс':'Progress'"></progress>
      <div class="port-medal-detail-status"><svg viewBox="0 0 24 24" :class="{earned:earned(medal.id)}" aria-hidden="true"><template v-if="earned(medal.id)"><circle cx="12" cy="12" r="10"/><path d="m7 12 3 3 7-7"/></template><template v-else><rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V6a4 4 0 0 1 8 0v4M12 14v3"/></template></svg><span>{{earned(medal.id)?(ru?'Получена':'Earned'):(ru?'Предстоит получить':'Not earned yet')}}</span><EnergyAmount v-if="medalReward(model,medal.id,medal.tier)>0" :amount="medalReward(model,medal.id,medal.tier)" prefix="+"/></div>
    </div>
    <div class="port-information-body port-cup-detail" v-else>
      <MedalArt thumbnail :id="currentCupId(detailCupFamily,cupRank(detailCupFamily))??`${detailCupFamily}-cups-1000`" large :normalized="false" :locked="!currentCupId(detailCupFamily,cupRank(detailCupFamily))"/>
      <strong>{{currentCupId(detailCupFamily,cupRank(detailCupFamily))?`TOP ${currentCupId(detailCupFamily,cupRank(detailCupFamily))?.split('-').at(-1)} · ${ru?'Место':'Rank'} ${cupRank(detailCupFamily)}`:(ru?'Войдите в топ 1000, чтобы получить кубок.':'Reach the top 1000 to receive a cup.')}}</strong>
      <p class="port-information-muted">{{ru?'Переходящий статус: топ 1000 / 500 / 100 / 10 / 1. Кубок меняется вместе с вашим местом. Поздравление показывается только при повышении. Энергия за кубки не начисляется.':'A current status: top 1000 / 500 / 100 / 10 / 1. The cup changes with your rank. Only promotions are celebrated. Cups do not award energy.'}}</p>
    </div>
  </ParityDialog>
  <ParityDialog v-if="help&&chosenHelp" :title="ru?chosenHelp.ru:chosenHelp.en" :locale="locale" name="achievement-help" @close="closeDetail">
    <div class="port-information-body port-series-detail"><p>{{ru?chosenHelp.helpRu:chosenHelp.helpEn}}</p><div class="port-series-detail-tiers"><div v-for="m in medalsInSeries(help)" :key="m.id"><span>{{label(m.id)}}</span><EnergyAmount :amount="model.energyByTier[m.tier]??0" prefix="+"/></div></div><p class="port-information-muted">{{ru?'Энергия начисляется один раз за каждую медаль.':'Energy is awarded once per medal.'}}</p></div>
  </ParityDialog>
  <ParityDialog ref="levelDialog" v-if="levelHelp" :title="ru?'Уровень игрока':'Player level'" :locale="locale" name="level-help" @close="closeDetail">
    <div class="port-information-body port-level-detail">
      <div class="port-level-detail-intro"><LevelBadge :level="level" :locale="locale"/><div><strong>{{ru?'Ваш уровень':'Your level'}} · LVL {{level}}</strong><p>{{ru?'Начинаете с LVL 1. Каждая полностью собранная ступень медалей повышает уровень.':'Start at LVL 1. Complete a medal tier across every personal series to level up.'}}</p></div></div>
      <div class="port-level-detail-rules"><div><small>{{ru?'Все 7 первых медалей':'All 7 first-tier medals'}}</small><strong>LVL 2</strong></div><div><small>{{ru?'Все 7 вторых медалей':'All 7 second-tier medals'}}</small><strong>LVL 3</strong></div></div>
      <div class="port-level-detail-progress"><strong>{{level>=6?(ru?'Все ступени собраны':'All medal tiers complete'):`${ru?'До':'To'} LVL ${level+1}`}}</strong><b>{{levelTargetCount}}/7</b></div>
      <div class="port-level-targets"><div v-for="target in levelTargets" :key="target.id" :data-level-target="target.id"><MedalArt thumbnail :id="target.id" :locked="!earned(target.id)" :normalized="false"/><span>{{level>=6?label(target.id):(ru?target.titleRu:target.titleEn)}}</span><i v-if="earned(target.id)" aria-hidden="true">✓</i><small v-else>{{level>=6?(ru?'Закрыта':'Locked'):label(target.id)}}</small></div></div>
      <p class="port-information-muted">{{ru?'Собирайте медали одного столбца во всех семи сериях. Победы в рейтингах — отдельная коллекция; на LVL 2–6 они не влияют.':'Complete the same medal column across all seven series. Leaderboard wins are separate and do not affect LVL 2–6.'}}</p>
      <button class="port-primary port-information-done" @click="levelDialog?.requestClose()">{{ru?'К коллекции':'Back to collection'}}</button>
    </div>
  </ParityDialog>
</template>
