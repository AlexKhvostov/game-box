<script setup lang="ts">
import EnergyAmount from './EnergyAmount.vue';
defineProps<{ reward:number; locale:string }>();
</script>
<template>
  <div class="rewarded-guide">
    <h2>{{locale==='ru'?'Досмотрите рекламу':'Watch the whole ad'}}</h2>
    <template v-for="step in [1,2]" :key="step">
      <div class="ad-guide-step"><svg viewBox="0 0 300 100" aria-hidden="true">
        <defs><linearGradient :id="`guide-clock-${step}`" x2="0" y2="1"><stop stop-color="#d5faff"/><stop offset=".5" stop-color="#53cde8"/><stop offset="1" stop-color="#08728d"/></linearGradient><linearGradient :id="`guide-phone-${step}`" x2="0" y2="1"><stop stop-color="#155170"/><stop offset="1" stop-color="#00172b"/></linearGradient></defs>
        <circle cx="65" cy="49" r="30" fill="#052337" stroke="#54e9ff" stroke-width="3"/><circle cx="65" cy="49" r="25" :fill="`url(#guide-clock-${step})`"/><path d="M65 30v20l13 8" fill="none" stroke="#05364b" stroke-width="4" stroke-linecap="round"/>
        <path d="M112 44h19V33l23 17-23 17V56h-19z" fill="#56e5f7" stroke="#bdf8ff"/>
        <rect x="168" y="8" width="120" height="82" rx="13" :fill="`url(#guide-phone-${step})`" stroke="#54e9ff" stroke-width="2"/><rect x="178" y="18" width="100" height="55" rx="5" fill="#082e46" stroke="#337f9d"/><path d="m217 32 18 12-18 12z" fill="#468ea8"/>
        <circle cx="274" cy="76" r="18" fill="#0a6689" stroke="#b9f9ff" stroke-width="2"/><path v-if="step===1" d="m269 68 8 8-8 8" fill="none" stroke="white" stroke-width="4" stroke-linecap="round"/><path v-else d="m267 69 14 14m0-14-14 14" fill="none" stroke="white" stroke-width="4" stroke-linecap="round"/>
        <circle cx="18" cy="18" r="13" fill="#0c4967" stroke="#54e9ff"/><text x="18" y="23" text-anchor="middle" fill="white" font-size="15" font-weight="700">{{step}}</text>
      </svg><div><strong>{{locale==='ru'?(step===1?'Подождите':'Ещё немного'):(step===1?'Wait':'Wait a little')}}</strong><strong>{{locale==='ru'?(step===1?'Перейдите':'Закройте'):(step===1?'Continue':'Close')}}</strong></div></div>
      <div class="guide-flow-arrow" aria-hidden="true">↓</div>
    </template>
    <div class="guide-reward"><EnergyAmount :amount="reward" prefix="+"/><strong>{{locale==='ru'?'Бонус ваш!':'Your bonus!'}}</strong></div>
  </div>
</template>
