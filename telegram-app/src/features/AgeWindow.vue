<script setup lang="ts">
import { ref, onBeforeUnmount, onMounted } from 'vue';
import GameWindow from '../components/GameWindow.vue';
import { state, back, errorText, walletOperation } from '../services/game-store';
import { ageBand, saveAgeBand, finishAgePrompt, type AgeBand } from '../platform/audience';
const t = (ru: string, en: string) => state.locale === 'ru' ? ru : en;
const selected = ref<AgeBand | null>(ageBand());
const options=ref<HTMLElement>(),large=ref(false);let observer:ResizeObserver|undefined;
function measure(){const el=options.value;if(el)large.value=el.clientWidth<265||(Number.parseFloat(getComputedStyle(el).getPropertyValue('--text-scale'))||1)*13>18;}
onMounted(()=>{measure();if(options.value){observer=new ResizeObserver(measure);observer.observe(options.value);}window.addEventListener('resize',measure);});
onBeforeUnmount(()=>{observer?.disconnect();window.removeEventListener('resize',measure);});
function save() {
  if (!selected.value) return;
  try {
    saveAgeBand(selected.value); finishAgePrompt(true); back();
    // Only completion is sent, never the selected band or a birth date.
    void walletOperation('energy_age_completed').catch(() => {});
  } catch (error) { state.error = errorText(error); }
}
onBeforeUnmount(() => finishAgePrompt(false));
</script>
<template>
  <GameWindow :title="t('Вам уже исполнилось 18 лет?','Are you 18 or older?')" class="age-window">
    <div ref="options" class="button-row age-options" :class="{'age-large':large}"><button class="secondary" :class="{selected:selected==='adult18plus'}" :aria-pressed="selected==='adult18plus'" @click="selected='adult18plus'"><span class="age-radio" aria-hidden="true"/>{{ t('Да, мне есть 18','Yes, I am 18 or older') }}</button><button class="secondary" :class="{selected:selected==='under18'}" :aria-pressed="selected==='under18'" @click="selected='under18'"><span class="age-radio" aria-hidden="true"/>{{ t('Нет, я младше 18','No, I am under 18') }}</button></div>
    <p>{{ t('Можно играть и сохранять результат без ответа. Возраст потребуется перед получением ресурсов.','You can play and save scores without answering. A declaration is required before receiving resources.') }}</p>
    <button class="primary full" :disabled="!selected" @click="save">{{ t('Подтвердить и продолжить','Confirm and continue') }}</button>
    <p v-if="state.error" class="error-message" role="alert">{{ state.error }}</p>
  </GameWindow>
</template>
