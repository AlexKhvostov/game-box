<script setup lang="ts">
import {ref,onMounted, onBeforeUnmount} from 'vue';
import GameWindow from './GameWindow.vue';
import {state} from '../services/game-store';
import {registerOverlayBack} from '../services/ui-overlays';
import type {AverageBoard} from '../services/contracts';
defineProps<{rules: AverageBoard['rules']; incomplete?: boolean}>();
const emit = defineEmits<{close: []}>();
const t = (ru: string, en: string) => state.locale === 'ru' ? ru : en;
const closing=ref(false);let closeTimer:ReturnType<typeof setTimeout>|undefined;
function close(){if(closing.value)return;closing.value=true;closeTimer=setTimeout(()=>emit('close'),matchMedia('(prefers-reduced-motion: reduce)').matches?0:100);}
let removeBack: (() => void) | undefined;
onMounted(() => {removeBack = registerOverlayBack(close,'average_help');});
onBeforeUnmount(() => {clearTimeout(closeTimer);removeBack?.();});
</script>
<template>
  <GameWindow class="attempts-average-help" :closing="closing" :title="t('Как считается среднее','How the average is calculated')">
    <p>{{t('Среднее показывает ваш текущий уровень игры в секундах.','The average shows your current playing level in seconds.')}}</p>
    <p>{{rules.algorithm==='ew_rms_v2'?t('Среднее обновляется после каждой попытки без фиксированного окна. Влияние прежних результатов плавно уменьшается.','Your average updates after each run without a fixed window. Earlier results gradually lose influence.'):t(`Учитываем последние ${rules.windowSize} подтверждённых попыток.`,`We use your last ${rules.windowSize} confirmed attempts.`)}} {{rules.previousWeightPercent===100?t('Все они имеют одинаковый вес.','They all have equal weight.'):t('Последние попытки влияют сильнее старых.','Recent attempts have more influence than older ones.')}}</p>
    <p v-if="['weighted_rms_v1','ew_rms_v2'].includes(rules.algorithm)">{{t('Это не обычное среднее: высокие результаты влияют сильнее низких.','This is not a simple average: higher results have more influence than lower ones.')}}</p>
    <p>{{rules.minDurationMs===0?t('Короткие попытки тоже учитываются.','Short attempts also count.'):t(`Учитываются попытки дольше ${rules.minDurationMs/1000} с.`,`Only attempts longer than ${rules.minDurationMs/1000} s count.`)}} {{t(`В общем списке — после ${rules.minAttempts} подходящих попыток. Чем выше среднее, тем выше место.`,`Listed after ${rules.minAttempts} eligible attempts. A higher average means a higher rank.`)}}</p>
    <p v-if="incomplete" class="attempts-help-note">{{t('На этом устройстве есть не вся подтверждённая история. График может отличаться от среднего в рейтинге.','This device does not contain the complete confirmed history. The chart may differ from the ranking average.')}}</p>
    <p class="attempts-help-note">{{t('Лучшая попытка — ваш отдельный рекорд за всё время.','Your best attempt is a separate all-time record.')}}</p>
    <template #footer><button class="secondary full" @click="close">{{t('Понятно','Got it')}}</button></template>
  </GameWindow>
</template>
<style scoped>
.attempts-average-help{z-index:30;background:#00111ed6}
.attempts-average-help :deep(.game-window){background:radial-gradient(ellipse at 50% 0,#12516e,transparent 65%),linear-gradient(#07354e,#021d31);border:2px solid #62f4ff;border-radius:22px;box-shadow:inset 0 0 0 3px #052a40,inset 0 0 0 4px #31c9e766,0 0 22px #1edcff66,0 16px 35px #0009}
.attempts-average-help :deep(h1){font-size:21px;color:#f2fdff}
.attempts-average-help :deep(.window-body){padding:4px 16px 12px}
.attempts-average-help p{font-size:14px;color:#eafaff;line-height:1.45;margin-bottom:12px}
.attempts-average-help ol{padding-left:21px;margin:0 0 14px;color:#b2ddec;font-size:13px;line-height:1.5}
.attempts-average-help li{margin-bottom:10px}
.attempts-average-help .attempts-help-note{border-top:1px solid #287c98;padding-top:11px;font-size:12px;color:#b2ddec}
</style>
