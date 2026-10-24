<script setup lang="ts">
import { computed, ref, onMounted, onBeforeUnmount, watch, nextTick } from 'vue';
import { state, world, initialize, attemptCost, back, refreshBoards, errorText, openScreen, failedFinish } from '../services/game-store';
import { ApiError, localQa } from '../services/api';
import { loadKernel } from '../domain/kernel';
import { viewportGeometry, textScale } from '../domain/viewport';
import { GameController } from '../game/controller';
import { setupTelegram, telegram, safeInsets } from '../platform/telegram';
import EnemySpeed from '../components/EnemySpeed.vue';
import GameHud from '../components/GameHud.vue';
import TouchpadFloor from '../components/TouchpadFloor.vue';
import EnergyWindow from '../features/EnergyWindow.vue';
import AudioDiagnostics from '../features/AudioDiagnostics.vue';
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
import { version as appVersion } from '../../package.json';
import { motionProbe } from '../game/motion-probe';
import GameWindow from '../components/GameWindow.vue';
import StatusOverlay from '../components/StatusOverlay.vue';
import EnergyAmount from '../components/EnergyAmount.vue';
import {prepareImpactGlyphs} from '../game/impact-glyphs';
import {prepareAudio,installAudio} from '../platform/audio';
import {prepareResultFonts} from '../services/result-fonts';
const canvas = ref<HTMLCanvasElement>(), touchpad = ref<HTMLElement>();
const nativeQa=import.meta.env.VITE_QA_MODE==='true';
const motionReportText=computed(()=>state.screen==='motion-diagnostics'?`UNTOUCH_MOTION ${JSON.stringify(motionProbe.report())}`:'');
const legacyInputPaint=ref(false);
const width = ref(window.innerWidth), height = ref(window.innerHeight), insets = ref(safeInsets());
const usableWidth=computed(()=>Math.max(1,width.value-insets.value.left-insets.value.right));
const geometry = computed(() => viewportGeometry(usableWidth.value, height.value, insets.value.top, insets.value.bottom));
const css = computed(() => ({ '--scale': geometry.value.scale, '--logical-height': `${geometry.value.logicalHeight}px`, '--hud-height': `${geometry.value.hudHeight / geometry.value.scale}px`, '--text-scale': textScale(usableWidth.value, height.value, 1, insets.value.top + insets.value.bottom), width: `${geometry.value.width}px`, height: `${Math.max(0,height.value - insets.value.top - insets.value.bottom)}px`, marginTop: `${insets.value.top}px`, left:`${(insets.value.left-insets.value.right)/2}px` }));
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
let controller: GameController | undefined;
const resourcesReady=ref(false);
let disposeAudio:(()=>void)|undefined;
let previewResultId='';
function openLastResult(){if(failedFinish.value)return;const last=state.history.find(row=>!!row.result);if(last){previewResultId=last.requestId;state.resultId=last.requestId;openScreen('result','motion-diagnostics');}}
function resize() { controller?.reanchor(); width.value = window.innerWidth; height.value = window.innerHeight; insets.value = safeInsets(); }
async function start() {
  warmArtwork();
  state.error = ''; await Promise.all([loadKernel(), initialize(), prepareImpactGlyphs(),prepareAudio(),prepareResultFonts()]); await nextTick();
  resourcesReady.value=true;await attachController();
}
async function attachController(){
  if(!resourcesReady.value||!state.initialized||controller)return;
  await nextTick();
  if (state.initialized && !controller && canvas.value && touchpad.value) { controller = new GameController(canvas.value, touchpad.value); offerStartupAge(); void refreshBoards().catch(backgroundError); void deliverAdReward().catch(backgroundError); }
}
function backgroundError(error:unknown){if(error instanceof ApiError&&(error.source==='transport'||error.code==='service_unavailable'))return;state.notice=errorText(error);}
watch(()=>state.initialized,ready=>{if(ready)void attachController();else{controller?.dispose();controller=undefined;}});
watch(() => [state.helmet, state.jump, state.config?.revision], () => { if (!world.value?.playing && !world.value?.dead) controller?.reset(); }, { flush: 'sync' });
watch(() => state.screen, (screen, before) => {
  if (before==='result') adPresenter.destroy();
  if (screen==='result'&&state.resultId!==previewResultId) { completedRound(state.resultId); setTimeout(() => { void maybeResultInterstitial().catch(() => {}); }, 480); }
  const tg = nativeBack(); if (screen) tg?.BackButton.show(); else { tg?.BackButton.hide(); if (before === 'result' || world.value?.dead) controller?.reset(); }
});
function nativeBack() { const tg = telegram(); return tg?.initData && tg.isVersionAtLeast('6.1') ? tg : undefined; }
onMounted(() => { disposeAudio=installAudio(); setupTelegram(); window.addEventListener('resize', resize); window.visualViewport?.addEventListener('resize', resize); telegram()?.onEvent('viewportChanged', resize); telegram()?.onEvent('safeAreaChanged', resize); telegram()?.onEvent('contentSafeAreaChanged', resize); nativeBack()?.BackButton.onClick(back); void start(); });
onBeforeUnmount(() => { controller?.dispose(); disposeAudio?.(); adPresenter.destroy(); window.removeEventListener('resize', resize); window.visualViewport?.removeEventListener('resize', resize); telegram()?.offEvent('viewportChanged', resize); telegram()?.offEvent('safeAreaChanged', resize); telegram()?.offEvent('contentSafeAreaChanged', resize); nativeBack()?.BackButton.offClick(back); });
</script>
<template>
  <main class="viewport" :style="css">
    <EnergyRewardMotion />
    <div class="game-shell">
      <TouchpadFloor :height="geometry.logicalHeight - geometry.hudHeight / geometry.scale - 133 - 16" />
      <div class="gameplay-layer" :inert="state.screen || !state.initialized || !resourcesReady ? true : undefined" :aria-hidden="state.screen || !state.initialized || !resourcesReady ? true : undefined">
      <GameHud />
      <EnemySpeed />
      <div ref="touchpad" class="touchpad" :aria-label="t('Игровое поле. Перемещайте палец; второй палец — прыжок.','Game field. Move your finger; a second finger jumps.')">
        <canvas ref="canvas" class="game-field" width="760" height="760" :aria-label="t('Поле Untouch','Untouch field')"></canvas>
        <div v-if="!world?.playing && !world?.dead" class="start-caption"><strong><img src="/assets/branding/ui/hero-ready-v1.png" alt="">Untouch</strong><p class="attempt-caption"><template v-if="state.initialized">{{t('Попытка:','Run:')}} <EnergyAmount :amount="attemptCost"/> · {{t('коснитесь поля','touch the field')}}</template><template v-else>{{t('Подключение…','Connecting…')}}</template></p><small>{{ t('Двигайте палец, чтобы уклоняться','Move your finger to dodge') }}</small></div>
      </div>
      </div>
      <div v-if="(!state.initialized || !resourcesReady) && !state.error" class="startup-loading" role="status" aria-live="polite"><span class="loading-spinner" aria-hidden="true"></span><strong>{{t(state.initialized?'Загружаем игру…':'Подключаемся…',state.initialized?'Loading game…':'Connecting…')}}</strong></div>
      <div v-if="!state.initialized && state.error" class="startup-error" role="alert"><p>{{ state.error }}</p><button class="primary" @click="start">{{ t('Повторить','Retry') }}</button></div>
      <button v-if="localQa||nativeQa" class="qa-label" style="pointer-events:auto;border:0;background:none;padding:0;min-height:0" :disabled="world?.playing" @click="openScreen('motion-diagnostics',state.screen)">{{ nativeQa?`Telegram QA · ${appVersion}`:'Локальная проверка · тестовые данные' }}</button>
      <GameWindow v-if="(localQa||nativeQa)&&state.screen==='motion-diagnostics'" title="QA · Плавность"><label><input :checked="legacyInputPaint" type="checkbox" @change="legacyInputPaint=($event.target as HTMLInputElement).checked;motionProbe.setLegacyInputPaint(legacyInputPaint)"> QA: прежняя отрисовка на каждом касании</label><button class="secondary full" @click="openScreen('audio-diagnostics','motion-diagnostics')">Проверка звуков без энергии</button><button v-if="state.history.some(row=>!!row.result)" class="secondary full" @click="openLastResult">Последний сохранённый результат</button><pre style="white-space:pre-wrap;overflow-wrap:anywhere;font-size:9px">{{motionReportText}}</pre></GameWindow>
      <AudioDiagnostics v-else-if="(localQa||nativeQa)&&state.screen==='audio-diagnostics'"/>
      <EnergyWindow v-else-if="['energy','subscription','video','friends','feedback','packs','helmet','jump'].includes(state.screen)" />
      <ProfileWindow v-else-if="state.screen === 'profile'" />
      <RankingWindow v-else-if="['ranking','history','chart','player-result','name-actions'].includes(state.screen)" />
      <ResultWindow v-else-if="['result','share'].includes(state.screen)" />
      <AgeWindow v-else-if="state.screen==='age'" />
      <HelpWindow v-else-if="state.screen" />
      <StatusOverlay v-if="!state.screen && state.initialized"/>
    </div>
  </main>
</template>
