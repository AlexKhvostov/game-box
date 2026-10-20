<script setup lang="ts">
import { computed, ref, onBeforeUnmount, onMounted } from 'vue';
import { state, world, openScreen, now } from '../services/game-store';
import GameArt from './GameArt.vue';
import { displayEnergy } from '../services/energy-motion';
const ms = computed(() => world.value?.timeMs ?? 0);
const timer = computed(() => `${String(Math.floor(ms.value / 60000)).padStart(2, '0')}:${String(Math.floor(ms.value / 1000) % 60).padStart(2, '0')}.${String(ms.value % 1000).padStart(3, '0')}`);
const seconds = (n?: number) => n == null ? '—' : (n / 1000).toFixed(3);
const playing = computed(() => world.value?.playing === true);
const recordCard=ref<HTMLElement>(),narrow=ref(false);let sizeObserver:ResizeObserver|undefined;
onMounted(()=>{if(recordCard.value){sizeObserver=new ResizeObserver(([entry])=>narrow.value=(entry?.contentRect.width??100)<85);sizeObserver.observe(recordCard.value);}});
const clock=ref(now()),tick=setInterval(()=>{if(!document.hidden)clock.value=now();},1000);
onBeforeUnmount(()=>{clearInterval(tick);sizeObserver?.disconnect();});
const bonusReady=computed(()=>!!state.profile&&state.profile.wallet.simpleBonus.nextAt<=clock.value);
const bonusProgress=computed(()=>{const b=state.profile?.wallet.simpleBonus;return b?Math.max(0,Math.min(1,1-(b.nextAt-clock.value)/(b.durationMs||b.policy.periodSec*1000))):0;});
const broken=computed(()=>state.helmet&&world.value?.helmet===false);
const cooldown=computed(()=>Math.max(0,world.value?.jumpCooldownMs??0));
const jumpProgress=computed(()=>Math.max(0,Math.min(1,1-cooldown.value/(Math.max(.001,state.config?.config.game.jumpCooldownSec??1.7)*1000))));
const jumpStatus=computed(()=>!state.jump?(state.locale==='ru'?'Выкл.':'Off'):cooldown.value>0?`${(cooldown.value/1000).toFixed(1).replace('.',state.locale==='ru'?',':'.')} ${state.locale==='ru'?'с':'s'}`:(state.locale==='ru'?'Готов':'Ready'));
</script>
<template>
  <header class="game-hud">
    <div class="hud-cards">
      <button class="capsule energy-capsule" :disabled="playing || state.externalBusy || !state.initialized" :aria-label="state.locale==='ru'?'Энергия':'Energy'" @click="openScreen('energy')"><svg class="lightning" viewBox="0 0 24 24" aria-hidden="true"><path d="M14 2 4 14h7l-1 8 10-13h-7z" fill="currentColor"/></svg><strong :style="{fontSize:`${Math.min(25,115/String(displayEnergy).length)}px`}">{{ state.profile ? displayEnergy : '—' }}</strong><span class="capsule-plus" :class="{ready:bonusReady}" aria-hidden="true"><svg viewBox="0 0 38 38"><circle cx="19" cy="19" r="17" class="bonus-ring-track"/><circle cx="19" cy="19" r="17" class="bonus-ring-progress" pathLength="1" :stroke-dasharray="`${bonusProgress} 1`"/></svg>＋</span></button>
      <button ref="recordCard" class="capsule record-capsule" :class="{narrow}" :disabled="playing || state.externalBusy || !state.initialized" @click="state.period='day';state.rankingTab='record';openScreen('ranking')"><GameArt class="hud-trophy" src="/assets/branding/ranking/trophy.svg"/><span><strong>{{ seconds(state.periods.day?.[0]?.timeMs) }}</strong><small>{{ state.locale === 'ru' ? 'Топ дня' : 'Today’s best' }}</small></span><i>›</i></button>
      <button class="capsule record-capsule" :class="{narrow}" :disabled="playing || state.externalBusy || !state.initialized" @click="openScreen('profile')"><GameArt class="hud-portrait" src="/assets/branding/ui/hud-player-portrait-v1.png"/><span><strong>{{ seconds(state.profile?.wallet.bestTimeMs) }}</strong><small>{{ state.locale === 'ru' ? 'Мой рекорд' : 'My best' }}</small></span><i>›</i></button>
    </div>
    <div class="hud-bottom">
      <button class="ability" :class="{ selected: state.helmet, broken }" :disabled="playing || state.externalBusy || !state.initialized" :aria-label="state.locale==='ru'?'Шлем':'Helmet'" @click="openScreen('helmet')"><GameArt class="helmet-hud-art" src="/assets/branding/ui/simple-energy-helmet.png"/><svg v-if="broken" class="ability-ring" viewBox="0 0 31 31" aria-hidden="true"><circle cx="15.5" cy="15.5" r="12.5" pathLength="5" stroke-dasharray=".82 .18"/></svg><span><b class="status-dot">●</b><strong>{{ !state.helmet ? (state.locale==='ru'?'Выкл.':'Off') : broken ? (state.locale==='ru'?'Разбит':'Broken') : (state.locale==='ru'?'Вкл.':'On') }}</strong></span><i>›</i></button>
      <div class="clock"><strong>{{ timer }}</strong><small>{{ state.locale === 'ru' ? 'Риск' : 'Risk' }} {{ world?.riskCount ?? 0 }} · {{ state.locale === 'ru' ? 'Пробег' : 'Run' }} {{ world?.runDistance ?? 0 }}</small></div>
      <button class="ability" :class="{ selected: state.jump, cooling:state.jump&&cooldown>0 }" :disabled="playing || state.externalBusy || !state.initialized" :aria-label="state.locale==='ru'?'Прыжок':'Jump'" @click="openScreen('jump')"><GameArt src="/assets/branding/ui/jump-v1.png"/><svg v-if="state.jump&&cooldown>0" class="ability-ring" viewBox="0 0 31 31" aria-hidden="true"><circle class="ring-track" cx="15.5" cy="15.5" r="12.5"/><circle cx="15.5" cy="15.5" r="12.5" pathLength="1" :stroke-dasharray="`${jumpProgress} 1`"/></svg><span><b v-if="!cooldown||!state.jump" class="status-dot">●</b><strong>{{ jumpStatus }}</strong></span><i>›</i></button>
    </div>
  </header>
</template>
