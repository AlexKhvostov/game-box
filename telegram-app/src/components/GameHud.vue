<script setup lang="ts">
import { computed, ref, onBeforeUnmount, onMounted } from 'vue';
import { state, world, openScreen, now } from '../services/game-store';
import GameArt from './GameArt.vue';
import HelmetIndicator from './HelmetIndicator.vue';
import JumpIndicator from './JumpIndicator.vue';
import EnergyBolt from './EnergyBolt.vue';
import { displayEnergy } from '../services/energy-motion';
const ms = computed(() => world.value?.timeMs ?? 0);
const timer = computed(() => `${String(Math.floor(ms.value / 60000)).padStart(2, '0')}:${String(Math.floor(ms.value / 1000) % 60).padStart(2, '0')}.${String(ms.value % 1000).padStart(3, '0')}`);
const seconds = (n?: number) => n == null ? '—' : (n / 1000).toFixed(3);
const playing = computed(() => world.value?.playing === true);
const recordCard=ref<HTMLElement>(),clockNode=ref<HTMLElement>(),hudNode=ref<HTMLElement>(),clockWidth=ref(100),hudNarrow=ref(false),narrow=ref(false);let sizeObserver:ResizeObserver|undefined;
onMounted(()=>{sizeObserver=new ResizeObserver(entries=>{for(const entry of entries){if(entry.target===recordCard.value)narrow.value=entry.contentRect.width<85;else if(entry.target===clockNode.value)clockWidth.value=entry.contentRect.width;else if(entry.target===hudNode.value)hudNarrow.value=entry.contentRect.width<285;}});for(const node of [recordCard.value,clockNode.value,hudNode.value])if(node)sizeObserver.observe(node);});
const clock=ref(now()),tick=setInterval(()=>{if(!document.hidden)clock.value=now();},1000);
onBeforeUnmount(()=>{clearInterval(tick);sizeObserver?.disconnect();});
const bonusReady=computed(()=>!!state.profile&&state.profile.wallet.simpleBonus.nextAt<=clock.value);
const bonusProgress=computed(()=>{const b=state.profile?.wallet.simpleBonus;return b?Math.max(0,Math.min(1,1-(b.nextAt-clock.value)/(b.durationMs||b.policy.periodSec*1000))):0;});

</script>
<template>
  <header ref="hudNode" class="game-hud" :class="{'narrow-abilities':hudNarrow}">
    <div class="hud-cards">
      <button v-analytics="{feature: 'energy', placement: 'hud'}" class="capsule energy-capsule" :disabled="playing || state.externalBusy || !state.initialized" :aria-label="state.locale==='ru'?'Энергия':'Energy'" @click="openScreen('energy')"><EnergyBolt class="lightning"/><strong :style="{fontSize:`${Math.min(25,115/String(displayEnergy).length)}px`}">{{ state.profile ? displayEnergy : '—' }}</strong><span class="capsule-plus" :class="{ready:bonusReady}" aria-hidden="true"><svg viewBox="0 0 38 38"><circle cx="19" cy="19" r="17" class="bonus-ring-track"/><circle cx="19" cy="19" r="17" class="bonus-ring-progress" pathLength="1" :stroke-dasharray="`${bonusProgress} 1`"/></svg>＋</span></button>
      <button v-analytics="{feature: 'ranking', placement: 'hud'}" ref="recordCard" class="capsule record-capsule" :class="{narrow}" :disabled="playing || state.externalBusy || !state.initialized" @click="state.period='day';state.rankingTab='record';openScreen('ranking')"><GameArt class="hud-trophy" src="/assets/branding/ranking/trophy.svg"/><span><strong>{{ seconds(state.periods.day?.[0]?.timeMs) }}</strong><small>{{ state.locale === 'ru' ? 'Топ дня' : 'Today’s best' }}</small></span></button>
      <button v-analytics="{feature: 'profile', placement: 'hud'}" class="capsule record-capsule" :class="{narrow}" :disabled="playing || state.externalBusy || !state.initialized" @click="openScreen('profile')"><GameArt class="hud-portrait" src="/assets/branding/ui/hud-player-portrait-v1.png"/><span><strong>{{ seconds(state.profile?.wallet.bestTimeMs) }}</strong><small>{{ state.locale === 'ru' ? 'Аккаунт' : 'Account' }}</small></span></button>
    </div>
    <div class="hud-bottom">
      <HelmetIndicator :equipped="state.helmet" :snapshot="world" :locale="state.locale" :disabled="playing || state.externalBusy || !state.initialized" @open="openScreen('helmet')"/>
      <div ref="clockNode" class="clock"><strong :style="{fontSize:Math.max(7,Math.min(30,(clockWidth-4)/6.4))+'px'}">{{ timer }}</strong><small>{{ state.locale === 'ru' ? 'Риск' : 'Risk' }} {{ world?.riskCount ?? 0 }} · {{ state.locale === 'ru' ? 'Шаги' : 'Steps' }} {{ world?.runDistance ?? 0 }}</small></div>
      <JumpIndicator :equipped="state.jump" :snapshot="world" :locale="state.locale" :disabled="playing || state.externalBusy || !state.initialized" :game="state.config?.config.game??{}" @open="openScreen('jump')"/>
    </div>
  </header>
</template>

<style scoped>
.clock>strong{letter-spacing:.3px}.narrow-abilities .ability-tube{width:80px}.narrow-abilities .hud-bottom{padding-inline:4px;gap:4px}
</style>
