<script setup lang="ts">
import { computed, ref, onMounted, onBeforeUnmount, watch } from 'vue';
import { state, world, impactActive, initialize, attemptCost, energy, back,closeScreen, errorText, openScreen, failedFinish,achievementPanel,refreshAchievements,setPreference,installReplayGate } from '../services/game-store';
import {controlHintState} from '../services/control-hint-store';
import ControlHint from '../components/ControlHint.vue';
import LoadingClock from '../components/LoadingClock.vue';
import AchievementsDrawer from '../components/AchievementsDrawer.vue';
import GameSettingsButton from '../components/GameSettingsButton.vue';
import {activeMedalCount} from '../domain/achievement-presentation';
import FieldDrawer from '../components/FieldDrawer.vue';
import AchievementsWindow from '../features/AchievementsWindow.vue';
import GameSettingsWindow from '../features/GameSettingsWindow.vue';
import AwardFlow from '../features/AwardFlow.vue';
import AnalyticsConsentWindow from '../features/AnalyticsConsentWindow.vue';
import AnalyticsEntryPrompt from '../features/AnalyticsEntryPrompt.vue';
import {awardFlow,prepareRunPresentation,allowRunPresentation} from '../services/award-flow';
import {syncMusic} from '../platform/audio';
import {qaLevelMediaProof} from '../services/qa-level-media-proof';
import {activeOverlayCount} from '../services/ui-overlays';
import { ApiError, localQa } from '../services/api';
import { loadKernel } from '../domain/kernel';
import { viewportGeometry, textScale } from '../domain/viewport';
import { GameController } from '../game/controller';
import { setupTelegram, telegram, safeInsets } from '../platform/telegram';
import EnemySpeed from '../components/EnemySpeed.vue';
import SpeedHelpWindow from '../features/SpeedHelpWindow.vue';
import {ENEMY_SPEED_SLOT_HEIGHT} from '../domain/speed-help';
import GameHud from '../components/GameHud.vue';
import TouchpadFloor from '../components/TouchpadFloor.vue';
import GameFloorBrand from '../components/GameFloorBrand.vue';
import EnergyWindow from '../features/EnergyWindow.vue';
import AudioDiagnostics from '../features/AudioDiagnostics.vue';
import ProfileWindow from '../features/ProfileWindow.vue';
import RankingWindow from '../features/RankingWindow.vue';
import ResultWindow from '../features/ResultWindow.vue';
import HelpWindow from '../features/HelpWindow.vue';
import AgeWindow from '../features/AgeWindow.vue';
import EnergyRewardMotion from '../components/EnergyRewardMotion.vue';
import InviteRewardHost from '../features/InviteRewardHost.vue';
import BonusEntryPrompt from '../features/BonusEntryPrompt.vue';
import { deliverAdReward, maybeResultInterstitial, completedRound } from '../services/ads';
import { adPresenter } from '../platform/adsgram';
import { offerStartupAge } from '../platform/audience';
import { warmResultArtwork } from '../services/artwork';
import { version as appVersion } from '../../package.json';
import { motionProbe } from '../game/motion-probe';
import GameWindow from '../components/GameWindow.vue';
import StatusOverlay from '../components/StatusOverlay.vue';
import EnergyAmount from '../components/EnergyAmount.vue';
import {prepareImpactGlyphs} from '../game/impact-glyphs';
import {prepareAudio,installAudio} from '../platform/audio';
import {prepareResultFonts} from '../services/result-fonts';
const canvas = ref<HTMLCanvasElement>(), touchpad = ref<HTMLElement>(), playingInput=ref<HTMLElement>();
const fieldBackground=ref<HTMLCanvasElement>(),fieldBorder=ref<HTMLCanvasElement>();
const drawerExpanded=ref(true);
const drawerOpen=computed({get:()=>!world.value?.playing&&drawerExpanded.value,set:value=>{if(!world.value?.playing)drawerExpanded.value=value;}});
const playingInputActive=computed(()=>!!world.value?.playing&&!state.screen&&!state.inviteNoticeOpen&&!state.externalBusy&&arenaReady.value);
watch(()=>!!world.value?.playing,(playing,wasPlaying)=>{if(wasPlaying&&!playing)drawerExpanded.value=true;});
const nativeQa=import.meta.env.VITE_QA_MODE==='true';
const motionReportText=computed(()=>state.screen==='motion-diagnostics'?`UNTOUCH_MOTION ${JSON.stringify({...motionProbe.report(),gameCanvas:{logicalWidth:canvas.value?.clientWidth,pixelWidth:canvas.value?.width,displayWidth:canvas.value?.getBoundingClientRect().width,displayHeight:canvas.value?.getBoundingClientRect().height,devicePixelRatio:window.devicePixelRatio,contextAttributes:canvas.value?.getContext('2d')?.getContextAttributes?.()}})}`:'');
const mediaReportText=computed(()=>state.screen==='motion-diagnostics'?`UNTOUCH_MEDIA ${JSON.stringify(qaLevelMediaProof.value)}`:'');
const legacyInputPaint=ref(false);
const width = ref(window.innerWidth), height = ref(window.innerHeight), insets = ref(safeInsets());
const usableWidth=computed(()=>Math.max(1,width.value-insets.value.left-insets.value.right));
const geometry = computed(() => viewportGeometry(usableWidth.value, height.value, insets.value.top, insets.value.bottom));
const touchpadHeight = computed(() => geometry.value.logicalHeight - geometry.value.hudHeight / geometry.value.scale - (world.value?.brake?.speedBarEnabled ? ENEMY_SPEED_SLOT_HEIGHT : 0));
const css = computed(() => ({ '--scale': geometry.value.scale, '--logical-height': `${geometry.value.logicalHeight}px`, '--hud-height': `${geometry.value.hudHeight / geometry.value.scale}px`, '--text-scale': textScale(usableWidth.value, height.value, 1, insets.value.top + insets.value.bottom), width: `${geometry.value.width}px`, height: `${Math.max(0,height.value - insets.value.top - insets.value.bottom)}px`, marginTop: `${insets.value.top}px`, left:`${(insets.value.left-insets.value.right)/2}px` }));
const t=(ru:string,en:string)=>state.locale==='ru'?ru:en;
let controller: GameController | undefined;
const arenaReady=ref(false);
const arenaPreparing=ref(false);
let kernelReady=false,resources:Promise<unknown>|undefined,extrasFrame=0,awardFrame=0,unmounted=false;
function startFromAchievements(event:PointerEvent,origin:{x:number;y:number}){controller?.startFromAchievements(event,origin);}
function closeParityScreen(){closeScreen({immediate:true});}
function openStatistic(kind:'record'|'history'){if(kind==='history')openScreen('history','achievements');else{state.period='all';openScreen('ranking','achievements');}}
function settingChanged(key:keyof typeof state.preferences,value:number|boolean){setPreference(key,value);syncMusic();}
const controlHintAvailable=computed(()=>state.config?.config.game.startHintEnabled!==false&&controlHintState.successfulStarts<2);
const showControlHint=computed(()=>arenaReady.value&&state.initialized&&!state.screen&&!state.externalBusy&&!state.inviteNoticeOpen&&world.value&&!world.value.playing&&!world.value.dead&&
  controlHintAvailable.value&&!controlHintState.dismissed&&energy.value>=attemptCost.value);
let disposeAudio:(()=>void)|undefined;
const removeReplayGate=installReplayGate(maybeResultInterstitial);
function openLastResult(){if(failedFinish.value)return;const last=state.history.find(row=>!!row.result);if(last){state.resultId=last.requestId;openScreen('result','motion-diagnostics');}}
function resize() { controller?.reanchor(); width.value = window.innerWidth; height.value = window.innerHeight; insets.value = safeInsets(); }
async function start() {
  state.error='';
  try{
    await Promise.all([initialize(),loadKernel().then(()=>{kernelReady=true;attachController();})]);
    attachController();
  }catch(error){if(!unmounted)state.error=errorText(error);}
}
function attachController(){
  if(unmounted||!kernelReady||!state.initialized||controller||!canvas.value||!fieldBackground.value||!fieldBorder.value||!touchpad.value||!playingInput.value)return;
  controller=new GameController(canvas.value,touchpad.value,()=>geometry.value.fieldSide,{background:fieldBackground.value,border:fieldBorder.value},{onFinished:id=>{
    prepareRunPresentation(id);
    openScreen('result');
  }},playingInput.value);
  const attached=controller;
  arenaPreparing.value=true;
  cancelAnimationFrame(extrasFrame);
  // The controller has drawn the field. Let it reach the display before doing
  // the one-time preparation, then arm input only after it settles.
  extrasFrame=requestAnimationFrame(()=>{
    extrasFrame=requestAnimationFrame(async()=>{
      if(controller!==attached||unmounted)return;
      resources??=Promise.allSettled([prepareImpactGlyphs(),prepareAudio(2000),prepareResultFonts(),warmResultArtwork()]);
      await resources;
      if(controller!==attached||unmounted)return;
      arenaPreparing.value=false;arenaReady.value=true;offerStartupAge();
      if(!state.screen&&!world.value?.playing)void deliverAdReward().catch(backgroundError);
    });
  });
}
function backgroundError(error:unknown){if(error instanceof ApiError&&(error.source==='transport'||error.code==='service_unavailable'))return;state.notice=errorText(error);}
watch(()=>state.initialized,ready=>{
  if(ready){try{attachController();}catch(error){state.error=errorText(error);}}
  else{arenaPreparing.value=false;arenaReady.value=false;controller?.dispose();controller=undefined;}
},{flush:'post'});
watch(() => [state.helmet, state.jump, state.config?.revision], () => { if (!world.value?.playing && !world.value?.dead) controller?.reset(); }, { flush: 'sync' });
watch(() => state.screen, (screen, before) => {
  if (before==='result') adPresenter.destroy();
  if(screen==='achievements')void refreshAchievements().catch(backgroundError);

  if(!screen&&!state.inviteNoticeOpen&&(before==='result'||world.value?.dead))controller?.reset();
});
watch(()=>[state.screen,state.resultId,awardFlow.runId,!!failedFinish.value],()=>{
  cancelAnimationFrame(awardFrame);
  const id=awardFlow.runId;
  if(!id||state.screen!=='result'||state.resultId!==id||failedFinish.value||awardFlow.presentationAllowed||
    !state.history.some(a=>a.requestId===id&&a.owner===state.profile?.id&&a.result))return;
  // Let the result paint before a prepared medal or level presentation can cover it.
  awardFrame=requestAnimationFrame(()=>{awardFrame=requestAnimationFrame(()=>{
    if(state.screen==='result'&&state.resultId===id&&!failedFinish.value){completedRound(id);allowRunPresentation(id);}
  });});
},{flush:'post'});
function nativeBack() { const tg = telegram(); return tg?.initData && tg.isVersionAtLeast('6.1') ? tg : undefined; }
function syncNativeBack(){const tg=nativeBack();if(state.screen||state.inviteNoticeOpen||activeOverlayCount.value>0)tg?.BackButton.show();else tg?.BackButton.hide();}
watch([()=>state.screen,()=>state.inviteNoticeOpen,()=>activeOverlayCount.value],syncNativeBack,{immediate:true});
onMounted(() => { disposeAudio=installAudio(); setupTelegram(); window.addEventListener('resize', resize); window.visualViewport?.addEventListener('resize', resize); telegram()?.onEvent('viewportChanged', resize); telegram()?.onEvent('safeAreaChanged', resize); telegram()?.onEvent('contentSafeAreaChanged', resize); nativeBack()?.BackButton.onClick(back); void start(); });
onBeforeUnmount(() => {unmounted=true;cancelAnimationFrame(extrasFrame);cancelAnimationFrame(awardFrame);removeReplayGate(); controller?.dispose(); disposeAudio?.(); adPresenter.destroy(); window.removeEventListener('resize', resize); window.visualViewport?.removeEventListener('resize', resize); telegram()?.offEvent('viewportChanged', resize); telegram()?.offEvent('safeAreaChanged', resize); telegram()?.offEvent('contentSafeAreaChanged', resize); nativeBack()?.BackButton.offClick(back); });
</script>
<template>
  <main class="viewport" :style="css">
    <EnergyRewardMotion />
    <div class="game-shell" :data-control-hint-starts="controlHintState.successfulStarts" :data-control-hint-dismissed="controlHintState.dismissed">
      <TouchpadFloor :height="geometry.logicalHeight - geometry.hudHeight / geometry.scale - 133 - 16" />
      <div class="gameplay-layer" :inert="state.screen || state.inviteNoticeOpen || impactActive || !arenaReady ? true : undefined" :aria-hidden="state.screen || state.inviteNoticeOpen || impactActive || !arenaReady ? true : undefined" :data-impact-active="impactActive||undefined">
      <GameHud />
      <EnemySpeed />
      <div ref="touchpad" class="touchpad" :style="{height:`${touchpadHeight}px`}" :aria-label="t('Игровое поле. Перемещайте палец; второй палец — прыжок.','Game field. Move your finger; a second finger jumps.')">
        <div class="live-field-drawer" :class="{'is-running':world?.playing}"><FieldDrawer v-model:open="drawerOpen" :retained-progress="achievementPanel.confirmed?activeMedalCount(achievementPanel.earnedIds):undefined" :label="t('Достижения','Achievements')" :interactive="!world?.playing&&!state.screen&&!state.externalBusy&&arenaReady">
          <template #arena>
            <canvas ref="fieldBackground" class="field-background" width="760" height="760" aria-hidden="true"></canvas>
            <canvas ref="canvas" class="game-field" width="760" height="760" :aria-label="t('Поле Untouch','Untouch field')" style="margin:0"></canvas>
            <canvas ref="fieldBorder" class="field-border" width="760" height="760" aria-hidden="true"></canvas>
          </template>
          <AchievementsDrawer embedded :show-settings="false" :model="achievementPanel" :locale="state.locale" :playing="!!world?.playing" :interactive="!state.screen&&!state.externalBusy&&arenaReady" @drag="startFromAchievements" @open="openScreen('achievements')"/>
        </FieldDrawer><div class="live-settings-reveal" :class="{'is-running':!!world?.playing}" :inert="world?.playing?true:undefined" :aria-hidden="!!world?.playing"><GameSettingsButton :locale="state.locale" :disabled="!!world?.playing||!!state.screen||state.externalBusy||!arenaReady" @click="openScreen('game-settings')"/></div></div>
        <GameFloorBrand :height="touchpadHeight - 380" />
        <div v-if="arenaReady && !world?.playing && !world?.dead && !controlHintState.dismissed" class="start-caption" :style="{opacity:showControlHint ? 'var(--control-hint-copy-opacity,1)' : 1}"><strong><img src="/assets/branding/ui/hero-ready-v1.png" alt="">Untouch</strong><p class="attempt-caption">{{t('Попытка:','Run:')}} <EnergyAmount :amount="attemptCost"/> · {{t('коснитесь поля','touch the field')}}</p></div>
      </div>
      <aside v-if="!arenaReady&&!state.screen" class="arena-connection" :role="state.error?'alert':'status'">
        <LoadingClock v-if="!state.error" :size="19"/>
        <p>{{state.error||(arenaPreparing?t('Готовим арену…','Preparing the arena…'):t('Подключаем игру…','Connecting to the game…'))}}</p>
        <button v-if="state.error" type="button" class="secondary" @click="start">{{t('Повторить','Retry')}}</button>
      </aside>
      </div>
      <button v-if="localQa||nativeQa" class="qa-label" style="pointer-events:auto;border:0;background:none;padding:0;min-height:0" :disabled="world?.playing||impactActive" @click="openScreen('motion-diagnostics',state.screen)">{{ nativeQa?`Telegram QA · ${appVersion}`:'Локальная проверка · тестовые данные' }}</button>
      <GameWindow v-if="(localQa||nativeQa)&&state.screen==='motion-diagnostics'" title="QA · Плавность"><label><input :checked="legacyInputPaint" type="checkbox" @change="legacyInputPaint=($event.target as HTMLInputElement).checked;motionProbe.setLegacyInputPaint(legacyInputPaint)"> QA: прежняя отрисовка на каждом касании</label><button class="secondary full" @click="openScreen('audio-diagnostics','motion-diagnostics')">Проверка звуков без энергии</button><button v-if="state.history.some(row=>!!row.result)" class="secondary full" @click="openLastResult">Последний сохранённый результат</button><pre style="white-space:pre-wrap;overflow-wrap:anywhere;font-size:9px">{{motionReportText}}</pre><pre style="white-space:pre-wrap;overflow-wrap:anywhere;font-size:9px">{{mediaReportText}}</pre></GameWindow>
      <AudioDiagnostics v-else-if="(localQa||nativeQa)&&state.screen==='audio-diagnostics'"/>
      <EnergyWindow v-else-if="['energy','subscription','video','friends','feedback','packs','helmet','jump'].includes(state.screen)" />
      <AchievementsWindow v-else-if="state.screen==='achievements'" :model="achievementPanel" :locale="state.locale" :loading="!achievementPanel.confirmed" :error="state.error" @close="closeParityScreen" @retry="refreshAchievements" @open-statistic="openStatistic"/>
      <GameSettingsWindow v-else-if="state.screen==='game-settings'" :locale="state.locale" :preferences="state.preferences" :character-settings-enabled="state.presentation.characterSettingsEnabled" :error="state.error" @close="closeParityScreen" @change="settingChanged"/>
      <ProfileWindow v-else-if="state.screen === 'profile'" />
      <RankingWindow v-else-if="['ranking','history','player-result','name-actions'].includes(state.screen)" />
      <ResultWindow v-else-if="['result','share'].includes(state.screen)" />
      <AnalyticsConsentWindow v-else-if="state.screen==='analytics-consent'"/>
      <AgeWindow v-else-if="state.screen==='age'" />
      <SpeedHelpWindow v-else-if="state.screen==='speed-help'" />
      <HelpWindow v-else-if="state.screen" />
      <StatusOverlay v-if="!state.screen && arenaReady"/>
      <AwardFlow :ready="arenaReady"/>
      <InviteRewardHost :ready="arenaReady&&(!world?.dead||awardFlow.presentationAllowed)"/>
      <AnalyticsEntryPrompt :ready="arenaReady"/>
      <BonusEntryPrompt :ready="arenaReady"/>
    </div>
    <ControlHint v-if="showControlHint" :field="canvas" :player="world?.player" :active="!state.screen && !state.inviteNoticeOpen && !state.externalBusy" />
    <div ref="playingInput" class="playing-input-surface" :class="{'is-active':playingInputActive}" aria-hidden="true"></div>
  </main>
</template>
<style scoped>
.playing-input-surface{position:fixed;inset:0;z-index:1001;pointer-events:none;touch-action:none;user-select:none;-webkit-user-select:none}
.playing-input-surface.is-active{pointer-events:auto}
.live-field-drawer{position:relative;width:380px;height:380px;margin:0 16px;z-index:2}
.field-background,.field-border{position:absolute;inset:0;width:380px;height:380px;border-radius:18px;pointer-events:none}
.live-field-drawer .game-field{position:relative}
.live-field-drawer>.field-drawer{position:absolute;top:0;left:0}
.live-field-drawer :deep(.field-drawer-mouth){right:66px}
.live-settings-reveal{position:absolute;top:0;left:0;width:380px;height:488px;clip-path:inset(380px -12px -12px);pointer-events:none;z-index:1}
.live-settings-reveal>.port-settings-entry{position:absolute;top:377px;right:20px;transform:translateY(0);transition:transform 420ms cubic-bezier(.2,.75,.25,1);pointer-events:auto}
.live-settings-reveal.is-running>.port-settings-entry{transform:translateY(calc(-100% - 8px))}
.live-field-drawer.is-running :deep(.field-drawer-panel),.live-settings-reveal.is-running>.port-settings-entry{transition:none}
@media(prefers-reduced-motion:reduce){.live-settings-reveal>.port-settings-entry{transition:none}}
.touchpad .start-caption{padding-top:108px}
.arena-connection{position:absolute;z-index:8;top:calc(var(--hud-height) + 138px);left:50%;transform:translateX(-50%);width:max-content;max-width:84%;display:flex;align-items:center;flex-wrap:wrap;justify-content:center;gap:8px;padding:8px 11px;border:1px solid #386679;border-radius:10px;background:#0b2639;color:#d6f2f2;font-size:14px;text-align:center}
.arena-connection p{margin:0}
</style>
