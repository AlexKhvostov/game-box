<script setup lang="ts">
import { computed, ref, watch, onBeforeUnmount, onMounted } from 'vue';
import { state, world, openScreen, now, observeDailyBestDay } from '../services/game-store';
import LoadingClock from './LoadingClock.vue';
import EasterEgg from './EasterEgg.vue';
import GameArt from './GameArt.vue';
import HelmetIndicator from './HelmetIndicator.vue';
import JumpIndicator from './JumpIndicator.vue';
import EnergyBolt from './EnergyBolt.vue';
import {telegram} from '../platform/telegram';
import { displayEnergy } from '../services/energy-motion';
const ms = computed(() => world.value?.timeMs ?? 0);
const timer = computed(() => `${String(Math.floor(ms.value / 60000)).padStart(2, '0')}:${String(Math.floor(ms.value / 1000) % 60).padStart(2, '0')}.${String(ms.value % 1000).padStart(3, '0')}`);
const seconds = (n?: number) => n == null ? '—' : (n / 1000).toFixed(3);
const playing = computed(() => world.value?.playing === true);
const easterOpen=ref(false);let easterCount=0,easterFirst=0;
watch(playing,()=>{easterCount=0;easterFirst=0;});
function closeEaster(){easterOpen.value=false;state.externalBusy=false;}
function timerTap(){
  if(playing.value||state.externalBusy||state.screen||state.config?.config.easterEgg?.enabled===false){easterCount=0;return;}
  const stamp=Date.now();if(!easterCount||stamp<easterFirst||stamp-easterFirst>1200){easterFirst=stamp;easterCount=0;}
  if(++easterCount===3){easterCount=0;easterOpen.value=true;state.externalBusy=true;}
}
 onBeforeUnmount(()=>{if(easterOpen.value)state.externalBusy=false;});
const recordCard=ref<HTMLElement>(),clockNode=ref<HTMLElement>(),hudNode=ref<HTMLElement>(),clockWidth=ref(100),hudNarrow=ref(false),narrow=ref(false);let sizeObserver:ResizeObserver|undefined;
onMounted(()=>{sizeObserver=new ResizeObserver(entries=>{for(const entry of entries){if(entry.target===recordCard.value)narrow.value=entry.contentRect.width<85;else if(entry.target===clockNode.value)clockWidth.value=entry.contentRect.width;else if(entry.target===hudNode.value)hudNarrow.value=entry.contentRect.width<285;}});for(const node of [recordCard.value,clockNode.value,hudNode.value])if(node)sizeObserver.observe(node);});
const clock=ref(now()),foreground=ref(!document.hidden&&telegram()?.isActive!==false);
const motion=typeof window.matchMedia==='function'?window.matchMedia('(prefers-reduced-motion: reduce)'):undefined,reducedMotion=ref(motion?.matches??false);
let tick:ReturnType<typeof setInterval>|undefined;
function syncClock(){
  const visible=foreground.value&&state.initialized&&!!state.profile&&!state.screen&&!state.windowClosing&&!state.externalBusy&&!state.inviteNoticeOpen;
  if(!visible){if(tick!==undefined){clearInterval(tick);tick=undefined;}return;}
  clock.value=now();observeDailyBestDay();if(tick===undefined)tick=setInterval(()=>{clock.value=now();observeDailyBestDay();},1000);
}
const activity=()=>{foreground.value=!document.hidden&&telegram()?.isActive!==false;},motionChanged=()=>{reducedMotion.value=motion?.matches??false;};
watch(()=>[foreground.value,state.initialized,!!state.profile,state.screen,state.windowClosing,state.externalBusy,state.inviteNoticeOpen],syncClock,{immediate:true});
onMounted(()=>{document.addEventListener('visibilitychange',activity);telegram()?.onEvent('activated',activity);telegram()?.onEvent('deactivated',activity);motion?.addEventListener?.('change',motionChanged);});
onBeforeUnmount(()=>{if(tick!==undefined)clearInterval(tick);sizeObserver?.disconnect();document.removeEventListener('visibilitychange',activity);telegram()?.offEvent('activated',activity);telegram()?.offEvent('deactivated',activity);motion?.removeEventListener?.('change',motionChanged);});
const dailyLoading=computed(()=>state.dailyBest.timeMs===null&&(state.dailyBest.loading||!state.dailyBest.attempted&&!state.error));
const dailyValue=computed(()=>state.dailyBest.error?'—':seconds(state.dailyBest.timeMs??undefined));
const bonusReady=computed(()=>!!state.profile&&state.profile.wallet.simpleBonus.nextAt<=clock.value);
const bonusProgress=computed(()=>{const b=state.profile?.wallet.simpleBonus;return b?Math.max(0,Math.min(1,1-(b.nextAt-clock.value)/(b.durationMs||b.policy.periodSec*1000))):0;});
const bonusGlow=computed(()=>bonusReady.value&&!reducedMotion.value ? .86+.14*Math.sin(clock.value/2800*Math.PI*2) : 1);

</script>
<template>
  <header ref="hudNode" class="game-hud" :class="{'narrow-abilities':hudNarrow}">
    <div class="hud-cards">
      <button v-analytics="{feature: 'energy', placement: 'hud'}" class="capsule energy-capsule" :disabled="playing || state.externalBusy || !state.initialized" :aria-label="state.locale==='ru'?'Энергия':'Energy'" @click="openScreen('energy')"><EnergyBolt class="lightning"/><strong :style="{fontSize:`${Math.min(25,115/String(displayEnergy).length)}px`}">{{ state.profile ? displayEnergy : '—' }}</strong><span class="capsule-plus" :class="{ready:bonusReady}" aria-hidden="true"><svg viewBox="0 0 38 38"><circle cx="19" cy="19" r="17" class="bonus-ring-track"/><circle cx="19" cy="19" r="17" class="bonus-ring-progress" :style="{opacity:bonusGlow}" pathLength="1" :stroke-dasharray="`${bonusProgress} 1`"/></svg>＋</span></button>
      <button v-analytics="{feature: 'ranking', placement: 'hud'}" ref="recordCard" class="capsule record-capsule" :class="{narrow}" :disabled="playing || state.externalBusy || !state.initialized" @click="state.period='day';state.rankingTab='record';openScreen('ranking')"><GameArt class="hud-trophy" src="/assets/branding/ranking/trophy.svg"/><span><span v-if="dailyLoading" class="hud-day-loading"><LoadingClock :size="14" :active="foreground&&!playing&&!state.screen&&!state.windowClosing&&!state.externalBusy&&!state.inviteNoticeOpen"/></span><strong v-else>{{dailyValue}}</strong><small>{{ state.locale === 'ru' ? 'Топ дня' : 'Today’s best' }}</small></span></button>
      <button v-analytics="{feature: 'profile', placement: 'hud'}" class="capsule account-capsule" :disabled="playing || state.externalBusy || !state.initialized" @click="openScreen('profile')"><GameArt class="hud-account-portrait" src="/assets/branding/ui/hud-player-portrait-v1.png"/><span class="hud-account-label">{{ state.locale === 'ru' ? 'Аккаунт' : 'Account' }}</span></button>
    </div>
    <div class="hud-bottom">
      <HelmetIndicator :equipped="state.helmet" :snapshot="world" :locale="state.locale" :disabled="playing || state.externalBusy || !state.initialized" @open="openScreen('helmet')"/>
      <div ref="clockNode" class="clock" @click="timerTap"><strong :style="{fontSize:Math.max(7,Math.min(30,(clockWidth-4)/6.4))+'px'}">{{ timer }}</strong><small>{{ state.locale === 'ru' ? 'Риск' : 'Risk' }} {{ world?.riskCount ?? 0 }} · {{ state.locale === 'ru' ? 'Шаги' : 'Steps' }} {{ world?.runDistance ?? 0 }}</small></div>
      <JumpIndicator :equipped="state.jump" :snapshot="world" :locale="state.locale" :disabled="playing || state.externalBusy || !state.initialized" :game="state.config?.config.game??{}" @open="openScreen('jump')"/>
    </div>
    <Teleport to="body"><EasterEgg v-if="easterOpen" @close="closeEaster"/></Teleport>
  </header>
</template>

<style scoped>
.hud-day-loading{display:flex;justify-content:center;align-items:center;height:14px;min-width:14px}.clock>strong{letter-spacing:.3px}.narrow-abilities .ability-tube{width:80px}.narrow-abilities .hud-bottom{padding-inline:4px;gap:4px}
.account-capsule{flex-direction:column;gap:0}.hud-account-portrait{width:28px;height:28px;max-height:calc(100% - 10px);object-fit:contain;flex:none}.hud-account-label{font-size:10px;line-height:10px;font-weight:700;white-space:nowrap;color:#f0fbff}
</style>
