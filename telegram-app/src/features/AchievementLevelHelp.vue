<script setup lang="ts">
import {computed,ref} from 'vue';
import AchievementMedalTile from '../components/AchievementMedalTile.vue';
import LevelBadge from '../components/LevelBadge.vue';
import ParityDialog from '../components/ParityDialog.vue';
import {levelHelpProgress,medalsInSeries} from '../domain/achievement-presentation';
import {personalSeries,personalSeriesCount} from '../domain/achievements';

const props=defineProps<{level:number;earnedIds:readonly string[];locale:string;inactive:boolean}>();
defineEmits<{close:[];medal:[id:string,event:MouseEvent]}>();

const dialog=ref<InstanceType<typeof ParityDialog>>();
const t=(ru:string,en:string)=>props.locale==='ru'?ru:en;
const title=computed(()=>t('Как растёт уровень','How levels work'));
const columns=[2,3,4,5,6];
const rowLabels=[
  ['Время','Time'],['Без усил.','No boosts'],['Риск','Risk'],
  ['Шаги','Steps'],['Попытки','Attempts'],['Друзья','Friends'],
];
const rows=personalSeries.map((series,index)=>({
  id:series.id,
  label:rowLabels[index]!,
  medals:medalsInSeries(series.id),
}));
const earned=computed(()=>new Set(props.earnedIds));
const target=computed(()=>levelHelpProgress(props.level,props.earnedIds));
const targetMedals=computed(()=>rows.map(row=>row.medals[target.value.tier]!));
const remainingText=computed(()=>{
  const count=target.value.remaining;
  const ruMedals=count===1?'медаль':count>=2&&count<=4?'медали':'медалей';
  return t((count===1?'Осталась ':'Осталось ')+count+' '+ruMedals,
    count+(count===1?' medal left':' medals left'));
});
</script>

<template>
  <ParityDialog ref="dialog" name="level-help" :title="title"
    :locale="locale" :inactive="inactive" @close="$emit('close')">
    <template #title><span class="own-level-title" :lang="locale">{{title}}</span></template>
    <div class="port-information-body own-level-help" :lang="locale">
      <p class="own-level-importance">{{t('Уровень — главный показатель вашего прогресса в игре.',
        'Your level is the main measure of your progress in the game.')}}</p>
      <p>{{target.complete?t('Вы собрали все пять столбцов — все уровни открыты.',
        'All five columns are complete — every level is unlocked.'):
        t('Соберите весь столбец — получите новый уровень.','Complete a whole column to unlock the next level.')}}</p>

      <div class="own-level-matrix" :style="{'--target-column':target.tier+2}" :data-level-target="target.nextLevel">
        <div class="own-level-column-highlight" aria-hidden="true"></div>
        <span aria-hidden="true"></span>
        <span v-for="(level,column) in columns" :key="level" class="own-level-shield" :class="{target:column===target.tier}">
          <LevelBadge :level="level" :locale="locale" compact/>
        </span>
        <template v-for="row in rows" :key="row.id">
          <span class="own-level-row-label">{{t(row.label[0]!,row.label[1]!)}}</span>
          <AchievementMedalTile v-for="medal in row.medals" :key="medal.id" :medal="medal" :locale="locale"
            :earned="earned.has(medal.id)" compact class="own-level-cell" :class="{target:medal.tier===target.tier}"
            :data-level-help-medal="medal.id" @select="$emit('medal',medal.id,$event)"/>
        </template>
      </div>

      <div class="own-level-progress">
        <strong>{{target.complete?t('Все уровни открыты','All levels unlocked'):t('До LVL ','To LVL ')+target.nextLevel}}</strong>
        <b>{{target.collected}}/{{personalSeriesCount}}</b>
      </div>
      <div class="own-level-progress-bar" aria-hidden="true">
        <span v-for="medal in targetMedals" :key="medal.id" :class="{lit:earned.has(medal.id)}"></span>
      </div>
      <p v-if="!target.complete" class="own-level-remaining">{{remainingText}}</p>
      <p class="port-information-muted">{{t('Кубки и победы в рейтингах уровень не повышают.',
        'Cups and leaderboard wins do not raise your level.')}}</p>
      <button type="button" class="port-primary port-information-done" @click="dialog?.requestClose()">
        {{t('К коллекции','Back to collection')}}
      </button>
    </div>
  </ParityDialog>
</template>

<style scoped>
.own-level-title{font-size:calc(1rem * min(var(--text-scale,1),1.3))}
.own-level-help{display:grid;gap:5px}
.own-level-help>p{font-size:calc(.72rem * var(--information-scale));line-height:1.25}
.own-level-help>.own-level-importance{font-weight:800;color:#c1f0e2}
.own-level-matrix{
  --own-level-cell:clamp(30px,calc((100dvh - 260px)/7),42px);
  display:grid;position:relative;isolation:isolate;
  grid-template-columns:clamp(40px,calc(3rem * var(--information-scale)),33%) repeat(5,minmax(0,1fr));
  grid-template-rows:var(--own-level-cell) repeat(6,minmax(var(--own-level-cell),auto));
  gap:3px;align-items:center;margin:3px 1px
}
.own-level-column-highlight{
  grid-column:var(--target-column);grid-row:1/-1;position:absolute;inset:-2px 0;
  border:1px solid #75dcc6aa;border-radius:9px;background:#54e3be15;pointer-events:none;z-index:-1
}
.own-level-shield{display:grid;place-items:center;min-width:0}
.own-level-shield :deep(.port-level-badge){width:min(29px,70%);height:calc(var(--own-level-cell) - 3px)}
.own-level-row-label{color:#c1dbe5;font-size:calc(.56rem * var(--information-scale));line-height:1.12;overflow-wrap:anywhere}
.own-level-shield:not(.target),.own-level-cell:not(.target){opacity:.55}
.own-level-cell:focus-visible{opacity:1}
.own-level-progress{display:flex;justify-content:space-between;gap:6px;color:#e8fbf7;font-size:calc(.75rem * var(--information-scale))}
.own-level-progress>b{color:#b7f3e1}
.own-level-progress-bar{display:flex;gap:3px}
.own-level-progress-bar>span{flex:1;height:4px;border-radius:2px;background:#294c60}
.own-level-progress-bar>.lit{background:#66d9c2}
.own-level-help>.own-level-remaining{font-size:calc(.68rem * var(--information-scale));font-weight:800}
.own-level-help>.port-information-muted{font-size:calc(.66rem * var(--information-scale))}
.own-level-help>.port-information-done{min-height:42px;margin:2px 0 0;font-size:calc(.82rem * var(--information-scale))}
</style>
