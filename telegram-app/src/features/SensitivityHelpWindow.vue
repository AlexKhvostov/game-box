<script setup lang="ts">
import {computed,ref,watch} from 'vue';
import ParityDialog from '../components/ParityDialog.vue';
import SettingsArtwork from '../components/SettingsArtwork.vue';
const props=defineProps<{locale:string;value:number;saving?:boolean;error?:string}>();
const emit=defineEmits<{close:[];change:[number]}>();
const draft=ref(props.value),dialog=ref<InstanceType<typeof ParityDialog>>(),ru=computed(()=>props.locale==='ru');watch(()=>props.value,value=>{draft.value=value;});
const label=computed(()=>`×${draft.value.toFixed(Number.isInteger(draft.value)?0:2)}`);
</script>
<template>
 <ParityDialog ref="dialog" :title="ru?'Чувствительность управления':'Control sensitivity'" :locale="locale" name="sensitivity-help" :closable="!saving" @close="emit('close')">
  <template #title><span class="port-sensitivity-title">{{ru?'Чувствительность':'Sensitivity'}}<small>{{ru?'управления':'controls'}}</small></span></template>
  <div class="port-sensitivity-info">
   <SettingsArtwork kind="sensitivity" :locale="locale" class="port-sensitivity-art"/>
   <strong class="port-sensitivity-large" aria-live="polite">{{label}}</strong>
   <h2>{{ru?'Скорость движения героя':'Hero movement speed'}}</h2>
   <p class="port-sensitivity-hint">{{ru?'Меньше движение пальца — дальше движение героя.':'A shorter swipe moves the hero farther.'}}</p>
   <input v-model.number="draft" class="port-neon-slider" type="range" min="0.5" max="3" step="0.25" :style="{'--range-fill':`${(draft-.5)/2.5*100}%`}" :disabled="saving" :aria-label="ru?'Чувствительность':'Sensitivity'" :aria-valuetext="label" @change="emit('change',draft)">
   <div class="port-sensitivity-ticks" aria-hidden="true"><span>{{ru?'×0,5':'×0.5'}}</span><span>×2</span><span>×3</span></div>
   <p class="port-sensitivity-save" :class="{'port-error':error}" :role="error?'alert':undefined">{{error?(ru?'Не удалось сохранить. Повторите.':'Could not save. Try again.'):(ru?'Сохраняется на этом телефоне':'Saved on this phone')}}</p>
   <div class="port-sensitivity-actions"><button class="port-secondary" :disabled="saving" @click="draft=1;emit('change',1)"><span aria-hidden="true">⟳</span>{{ru?'Сбросить до ×1':'Reset to ×1'}}</button><button class="port-primary" :disabled="saving" @click="dialog?.requestClose()">{{ru?'Готово':'Done'}}</button></div>
  </div>
 </ParityDialog>
</template>
