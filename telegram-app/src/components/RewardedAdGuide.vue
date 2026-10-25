<script setup lang="ts">
import EnergyAmount from './EnergyAmount.vue';
defineProps<{ reward:number; locale:string }>();
</script>
<template>
  <div class="rewarded-guide">
    <h2>{{locale==='ru'?'Дождитесь окончания рекламы':'Wait for the ad to finish'}}</h2>
    <div class="ad-guide-watch">
      <svg viewBox="0 0 300 118" aria-hidden="true">
        <rect x="65" y="12" width="170" height="94" rx="18" fill="#082e46" stroke="#54e9ff" stroke-width="2"/>
        <rect x="76" y="23" width="148" height="72" rx="11" fill="#052337"/>
        <path d="m136 38 32 20-32 20z" fill="#45edc0"/>
        <circle cx="226" cy="87" r="24" fill="#07334a" stroke="#54e9ff" stroke-width="2"/>
        <path d="M226 72v16l10 6" fill="none" stroke="#bdf8ff" stroke-width="3.5" stroke-linecap="round"/>
      </svg>
      <p>{{locale==='ru'?'Не закрывайте рекламу раньше времени.':'Please do not close the ad early.'}}</p>
    </div>
    <div class="guide-reward"><EnergyAmount :amount="reward" prefix="+"/><strong>{{locale==='ru'?'За полный просмотр':'For watching to the end'}}</strong></div>
    <p class="ad-guide-caption">{{locale==='ru'?'После полного просмотра энергия добавится автоматически.':'Energy is added automatically after a complete viewing.'}}</p>
  </div>
</template>
<style scoped>
.ad-guide-watch{margin:14px auto 18px;max-width:300px;text-align:center}
.ad-guide-watch svg{display:block;width:100%;height:auto;filter:drop-shadow(0 0 9px #30c9ed30)}
.ad-guide-watch p,.ad-guide-caption{font-size:13px;line-height:1.45;text-align:center;color:#b8d7e9}
.ad-guide-watch p{margin:5px 0 0}.ad-guide-caption{margin:14px 4px 0}
</style>
