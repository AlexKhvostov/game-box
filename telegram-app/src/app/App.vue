<script setup lang="ts">
import { computed, ref, onMounted, onBeforeUnmount, watch, nextTick } from 'vue';
import { state, world, initialize, attemptCost, back, refreshBoards, action, errorText } from '../services/game-store';
import { localQa } from '../services/api';
import { loadKernel } from '../domain/kernel';
import { viewportGeometry, textScale } from '../domain/viewport';
import { GameController } from '../game/controller';
import { setupTelegram, telegram, safeInsets } from '../platform/telegram';
import GameHud from '../components/GameHud.vue';
import TouchpadFloor from '../components/TouchpadFloor.vue';
import EnergyWindow from '../features/EnergyWindow.vue';
import ProfileWindow from '../features/ProfileWindow.vue';
import RankingWindow from '../features/RankingWindow.vue';
import ResultWindow from '../features/ResultWindow.vue';
import HelpWindow from '../features/HelpWindow.vue';
import AgeWindow from '../features/AgeWindow.vue';
import EnergyRewardMotion from '../components/EnergyRewardMotion.vue';
import { deliverAdReward, maybeResultInterstitial, completedRound } from '../services/ads';
import { adPresenter } from '../platform/adsgram';
import { offerStartupAge } from '../platform/audience';
import { warmArtwork } from '../services/artwork';
const canvas = ref<HTMLCanvasElement>(), touchpad = ref<HTMLElement>();
const nativeQa=import.meta.env.VITE_QA_MODE==='true';
const width = ref(window.innerWidth), height = ref(window.innerHeight), insets = ref(safeInsets());
const usableWidth=computed(()=>Math.max(1,width.value-insets.value.left-insets.value.right));
const geometry = computed(() => viewportGeometry(usableWidth.value, height.value, insets.value.top, insets.value.bottom));
const css = computed(() => ({ '--scale': geometry.value.scale, '--logical-height': `${geometry.value.logicalHeight}px`, '--hud-height': `${geometry.value.hudHeight / geometry.value.scale}px`, '--text-scale': textScale(usableWidth.value, height.value, 1, insets.value.top + insets.value.bottom), width: `${geometry.value.width}px`, height: `${Math.max(0,height.value - insets.value.top - insets.value.bottom)}px`, marginTop: `${insets.value.top}px`, left:`${(insets.value.left-insets.value.right)/2}px` }));
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
let controller: GameController | undefined;
function resize() { controller?.reanchor(); width.value = window.innerWidth; height.value = window.innerHeight; insets.value = safeInsets(); }
async function start() {
  warmArtwork();
  state.error = ''; await Promise.all([loadKernel(), initialize()]); await nextTick();
  if (state.initialized && canvas.value && touchpad.value) { controller?.dispose(); controller = new GameController(canvas.value, touchpad.value); offerStartupAge(); void action(refreshBoards); void deliverAdReward().catch(error => state.notice = errorText(error)); }
}
watch(() => [state.helmet, state.jump, state.config?.revision], () => { if (!world.value?.playing && !world.value?.dead) controller?.reset(); }, { flush: 'sync' });
watch(() => state.screen, (screen, before) => {
  if (before==='result') adPresenter.destroy();
  if (screen==='result') { completedRound(state.resultId); setTimeout(() => { void maybeResultInterstitial().catch(() => {}); }, 480); }
  const tg = nativeBack(); if (screen) tg?.BackButton.show(); else { tg?.BackButton.hide(); if (before === 'result' || world.value?.dead) controller?.reset(); }
});
function nativeBack() { const tg = telegram(); return tg?.initData && tg.isVersionAtLeast('6.1') ? tg : undefined; }
onMounted(() => { setupTelegram(); window.addEventListener('resize', resize); window.visualViewport?.addEventListener('resize', resize); telegram()?.onEvent('viewportChanged', resize); telegram()?.onEvent('safeAreaChanged', resize); telegram()?.onEvent('contentSafeAreaChanged', resize); nativeBack()?.BackButton.onClick(back); void start(); });
onBeforeUnmount(() => { controller?.dispose(); adPresenter.destroy(); window.removeEventListener('resize', resize); window.visualViewport?.removeEventListener('resize', resize); telegram()?.offEvent('viewportChanged', resize); telegram()?.offEvent('safeAreaChanged', resize); telegram()?.offEvent('contentSafeAreaChanged', resize); nativeBack()?.BackButton.offClick(back); });
</script>
<template>
  <main class="viewport" :style="css">
    <EnergyRewardMotion />
    <div class="game-shell">
      <TouchpadFloor :height="geometry.logicalHeight - geometry.hudHeight / geometry.scale - 133 - 16" />
      <div class="gameplay-layer" :inert="state.screen ? true : undefined" :aria-hidden="state.screen ? true : undefined">
      <GameHud />
      <div ref="touchpad" class="touchpad" :aria-label="t('Игровое поле. Перемещайте палец; второй палец — прыжок.','Game field. Move your finger; a second finger jumps.')">
        <canvas ref="canvas" class="game-field" width="760" height="760" :aria-label="t('Поле Untouch','Untouch field')"></canvas>
        <div v-if="!world?.playing && !world?.dead" class="start-caption"><strong><img src="/assets/branding/ui/hero-ready-v1.png" alt="">Untouch</strong><p>{{ state.initialized ? t(`Попытка: ${attemptCost} ϟ · коснитесь поля`,`Run: ${attemptCost} ϟ · touch the field`) : t('Подключение…','Connecting…') }}</p><small>{{ t('Двигайте палец, чтобы уклоняться','Move your finger to dodge') }}</small></div>
      </div>
      </div>
      <div v-if="!state.initialized && state.error" class="startup-error" role="alert"><p>{{ state.error }}</p><button class="primary" @click="start">{{ t('Повторить','Retry') }}</button></div>
      <span v-if="localQa||nativeQa" class="qa-label">{{ nativeQa?'Telegram QA · изолированные данные':'Локальная проверка · тестовые данные' }}</span>
      <span v-if="!state.online" class="connection-label" role="status">{{ t('Нет связи · результаты сохраняются','Offline · results are saved') }}</span>
      <EnergyWindow v-if="['energy','subscription','video','friends','feedback','packs','helmet','jump'].includes(state.screen)" />
      <ProfileWindow v-else-if="state.screen === 'profile'" />
      <RankingWindow v-else-if="['ranking','history','chart','player-result','name-actions'].includes(state.screen)" />
      <ResultWindow v-else-if="['result','share'].includes(state.screen)" />
      <AgeWindow v-else-if="state.screen==='age'" />
      <HelpWindow v-else-if="state.screen" />
      <div v-if="state.notice && !state.screen" class="toast" role="status" @click="state.notice = ''">{{ state.notice }}</div>
    </div>
  </main>
</template>
