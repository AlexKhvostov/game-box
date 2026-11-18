<script setup lang="ts">
import {computed} from 'vue';
import type {AchievementDefinition} from '../domain/achievements';
import {awardCopy,medalTierColor} from '../domain/achievement-presentation';
import EnergyAmount from './EnergyAmount.vue';
import MedalArt from './MedalArt.vue';

const props=withDefaults(defineProps<{
  medal:AchievementDefinition;
  locale:string;
  earned:boolean;
  reward?:number;
  compact?:boolean;
}>(),{reward:0,compact:false});
defineEmits<{select:[event:MouseEvent]}>();

const copy=computed(()=>awardCopy(props.medal.id,props.locale));
const status=computed(()=>props.locale==='ru'
  ? (props.earned?'Получено':'Закрыто')
  : (props.earned?'Earned':'Locked'));
</script>

<template>
  <button type="button" class="achievement-medal-tile" :class="{earned,compact}"
    :data-medal-id="medal.id" :data-earned="earned"
    :style="{'--medal-color':medalTierColor(medal.tier)}"
    :aria-label="copy.name+' · '+status" @click="$emit('select',$event)">
    <MedalArt :id="medal.id" thumbnail :locked="!earned"/>
    <i v-if="earned" class="port-earned-check" aria-hidden="true">✓</i>
    <template v-if="!compact">
      <strong>{{copy.label}}</strong>
      <EnergyAmount v-if="reward>0" :amount="reward" prefix="+"/>
      <span v-else class="port-medal-empty-reward" aria-hidden="true"></span>
    </template>
  </button>
</template>

<style scoped>
.achievement-medal-tile.compact{
  display:grid;grid-template-columns:minmax(0,1fr);position:relative;place-items:center;
  width:100%;height:100%;min-width:0;padding:1px;overflow:hidden;
  border:1px solid #24475a;border-radius:8px;background:linear-gradient(135deg,#174357,#12364b);cursor:pointer
}
.achievement-medal-tile.compact.earned{
  border-color:var(--medal-color);
  background:linear-gradient(135deg,color-mix(in srgb,var(--medal-color) 22%,#143b50),#12364b)
}
.achievement-medal-tile.compact :deep(.port-medal-art){
  width:min(100%,calc(var(--own-level-cell,36px) - 5px),32px);height:auto;aspect-ratio:1
}
.achievement-medal-tile.compact .port-earned-check{
  width:12px;height:12px;top:0;right:1px;font-size:9px;line-height:1
}
.achievement-medal-tile:focus-visible{outline:2px solid #ffd54a;outline-offset:-2px}
</style>
