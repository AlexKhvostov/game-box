<script setup lang="ts">
import {onMounted, onBeforeUnmount} from 'vue';
import GameWindow from './GameWindow.vue';
import {state} from '../services/game-store';
import {registerOverlayBack} from '../services/ui-overlays';
import type {AverageBoard} from '../services/contracts';
defineProps<{rules: AverageBoard['rules']; incomplete?: boolean}>();
const emit = defineEmits<{close: []}>();
const t = (ru: string, en: string) => state.locale === 'ru' ? ru : en;
const seconds = (ms: number) => (ms / 1000).toFixed(3).replace('.', state.locale === 'ru' ? ',' : '.');
let removeBack: (() => void) | undefined;
onMounted(() => {removeBack = registerOverlayBack(() => emit('close'));});
onBeforeUnmount(() => removeBack?.());
</script>
<template>
  <GameWindow class="attempts-average-help" :title="t('Как считается среднее','How the average is calculated')">
    <p>{{t('Среднее показывает ваш текущий уровень игры в секундах.','The average shows your current playing level in seconds.')}}</p>
    <ol>
      <li>{{t(`Берём последние ${rules.windowSize} подходящих подтверждённых попыток. Если их меньше, учитываем доступные.`,`We take the latest ${rules.windowSize} qualifying confirmed attempts, or all available if there are fewer.`)}} <template v-if="rules.minDurationMs>0">{{t(`Время должно быть строго больше ${seconds(rules.minDurationMs)} с.`,`Each time must be strictly above ${seconds(rules.minDurationMs)} s.`)}}</template><template v-else>{{t('Короткие попытки тоже учитываются; время должно быть больше нуля.','Short attempts count too; the time must be above zero.')}}</template></li>
      <li>{{rules.previousWeightPercent===100?t('Все попытки имеют одинаковый вес.','All attempts have equal weight.'):t(`Свежие попытки влияют сильнее. Вес каждой предыдущей — ${rules.previousWeightPercent}% от следующей.`,`Recent attempts matter more. Each earlier attempt has ${rules.previousWeightPercent}% of the next attempt’s weight.`)}}</li>
      <li v-if="rules.algorithm==='weighted_rms_v1'">{{t('Считаем среднее квадратичное: умножаем квадрат времени на вес, делим сумму на сумму весов и извлекаем корень. Длинные попытки влияют заметнее.','We calculate the root mean square: multiply each squared time by its weight, divide the sum by the sum of weights, then take the square root. Longer attempts have a stronger effect.')}}</li>
      <li v-else-if="rules.algorithm==='weighted_arithmetic_v1'">{{t('Считаем взвешенное среднее: умножаем время на вес и делим сумму на сумму весов.','We calculate the weighted mean: multiply each time by its weight, then divide the sum by the sum of weights.')}}</li>
      <li v-else>{{t('Сервер использует новую версию расчёта. Официальное среднее доступно сверху; локальная линия для этой версии пока не строится.','The server uses a new calculation version. The official average is available in the summary; this version’s local line is not supported yet.')}}</li>
    </ol>
    <p>{{t(`Для допуска в рейтинг нужно ${rules.minAttempts} подходящих попыток. До этого среднее предварительное.`,`Ranking eligibility requires ${rules.minAttempts} qualifying attempts. Until then the average is provisional.`)}}</p>
    <p>{{t('После новой подтверждённой попытки показатель обновляется. Чем выше среднее, тем лучше.','The value updates after a new confirmed attempt. A higher average is better.')}}</p>
    <p class="attempts-help-note">{{t('Лучшая попытка — отдельный рекорд за всё время. История на устройстве может быть неполной. Среднее в плашке — официальное; новый рекорд по подтверждённой истории устройства отмечается отдельно.','The best attempt is a separate all-time record. Device history may be incomplete. The summary average is official; a newer record from confirmed device history is labelled separately.')}} <span v-if="incomplete">{{t('Историческая линия рассчитана по доступным здесь попыткам.','The historical line is calculated from the attempts available here.')}}</span></p>
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
