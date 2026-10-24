<script setup lang="ts">
import {onMounted, onBeforeUnmount} from 'vue';
import GameWindow from './GameWindow.vue';
import {state} from '../services/game-store';
import {registerOverlayBack} from '../services/ui-overlays';
import type {AverageBoard} from '../services/contracts';
defineProps<{rules: AverageBoard['rules']; incomplete?: boolean}>();
const emit = defineEmits<{close: []}>();
const t = (ru: string, en: string) => state.locale === 'ru' ? ru : en;
let removeBack: (() => void) | undefined;
onMounted(() => {removeBack = registerOverlayBack(() => emit('close'));});
onBeforeUnmount(() => removeBack?.());
</script>
<template>
  <GameWindow class="attempts-average-help" :title="t('Как считается среднее','How the average is calculated')">
    <p>{{t('Среднее показывает ваш текущий уровень игры в секундах.','The average shows your current playing level in seconds.')}}</p>
    <p>{{t('Учитываем последние подтверждённые попытки.','We use your recent confirmed attempts.')}} {{rules.previousWeightPercent===100?t('Все они имеют одинаковый вес.','They all have equal weight.'):t('Свежие попытки влияют сильнее старых.','Recent attempts matter more than older ones.')}}</p>
    <p v-if="rules.algorithm==='weighted_rms_v1'">{{t('Большие результаты влияют сильнее маленьких. Поэтому удачная длинная попытка заметнее повышает среднее.','Higher results matter more than lower ones, so a good long attempt gives your average a bigger boost.')}}</p>
    <p>{{t('Среднее обновляется после подтверждения попытки. Чем оно выше, тем лучше.','Your average updates after an attempt is confirmed. Higher is better.')}}</p>
    <p class="attempts-help-note">{{t('Лучшая попытка — ваш отдельный рекорд за всё время.','Your best attempt is a separate all-time record.')}}</p>
    <template #footer><button class="secondary full" @click="emit('close')">{{t('Понятно','Got it')}}</button></template>
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
