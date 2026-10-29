<script setup lang="ts">
import {computed} from 'vue';
import EnergyAmount from './EnergyAmount.vue';
import type {SubscriptionOffer} from '../domain/subscription-choice';
const props=defineProps<{offers:SubscriptionOffer[];selected:number;active:number;locale:string;periodHours:number;busy:boolean;available:boolean;showAds:boolean}>();
const emit=defineEmits<{select:[tier:number];buy:[]}>();
const t=(ru:string,en:string)=>props.locale==='ru'?ru:en;
const chosen=computed(()=>props.offers.find(o=>o.tier===props.selected));
const number=(v:number)=>v.toLocaleString(props.locale==='ru'?'ru-RU':'en-US',{maximumFractionDigits:2});
const coins=(o:SubscriptionOffer)=>o.portions??1;
function keys(event:KeyboardEvent){
  if(!['ArrowLeft','ArrowRight','Home','End'].includes(event.key)||props.busy)return;
  event.preventDefault();const index=props.offers.findIndex(o=>o.tier===props.selected);
  const next=event.key==='Home'?0:event.key==='End'?props.offers.length-1:(index+(event.key==='ArrowLeft'?-1:1)+props.offers.length)%props.offers.length;
  const offer=props.offers[next];if(offer){emit('select',offer.tier);(event.currentTarget as HTMLElement).querySelector<HTMLButtonElement>(`[data-tier="${offer.tier}"]`)?.focus();}
}
</script>
<template>
  <section class="subscription-sheet sub-v9 sub-additive" :aria-label="t('Выбор подписки','Choose a subscription')">
    <header class="sub-head sub-hero-head"><img class="sub-header-art" src="/assets/branding/ui/subscription/scene-wink-v2.png" alt=""><div class="sub-header-copy"><h2>{{t('Подписка','Subscription')}}</h2><p>{{t('Больше энергии','More energy')}}<span>{{t(`Бонусы каждые ${number(periodHours)} ч`,`Bonuses every ${number(periodHours)} h`)}}</span></p></div></header>
    <div class="sub-body">
      <div class="sub-options" role="radiogroup" :aria-label="t('Размер бонуса подписки','Subscription bonus size')" @keydown="keys">
        <button v-for="offer in offers" :key="offer.tier" v-analytics="{feature:'select_subscription',placement:'energy'}" type="button" role="radio" class="sub-plan" :class="{selected:selected===offer.tier}" :data-tier="offer.tier" :aria-checked="selected===offer.tier" :tabindex="selected===offer.tier?0:-1" :disabled="busy" :aria-label="t(`Дополнительно ${offer.extra} к бесплатным ${offer.base}. Итого ${offer.reward} за бонус, до ${offer.daily} в сутки. ${offer.price??'Недоступно'} Stars за ${number(offer.days)} дней.`,`Add ${offer.extra} to the free ${offer.base}. Total ${offer.reward} per bonus, up to ${offer.daily} per day. ${offer.price??'Unavailable'} Stars for ${number(offer.days)} days.`)" @click="emit('select',offer.tier)">
          <span v-if="offer.discount" class="sub-discount">{{t('Скидка','Save')}} {{offer.discount}}%</span><span class="sub-select-mark" aria-hidden="true">{{selected===offer.tier?'✓':''}}</span>
          <span class="sub-plan-art" aria-hidden="true"><span class="sub-coin-stack" :data-portions="coins(offer)"><span class="sub-base-portion" :style="{'--base-shift':`${-coins(offer)*7}px`}"><span class="sub-orb"><strong class="sub-orb-base">{{offer.base}}</strong><svg viewBox="0 0 24 30"><path d="M14 1 3 17h9l-2 12L22 12h-9Z" fill="currentColor"/></svg></span></span><span v-for="i in coins(offer)" :key="i" class="sub-portion" :style="{'--coin-index':i-1,'--coin-shift':`${(i-1-(coins(offer)-2)/2)*14}px`}"><span class="sub-orb"><strong class="sub-orb-base">{{offer.portions?offer.base:offer.extra}}</strong><svg viewBox="0 0 24 30"><path d="M14 1 3 17h9l-2 12L22 12h-9Z" fill="currentColor"/></svg></span></span></span><span class="sub-coin-caption">{{offer.portions?t(`+${offer.portions} × ${offer.base}`,`+${offer.portions} × ${offer.base}`):t('Дополнительная энергия','Extra energy')}}</span></span>
          <span class="sub-reward"><EnergyAmount :amount="offer.extra" prefix="+"/></span><span class="sub-per-claim">{{t('к каждому бонусу','with every bonus')}}</span>
          <span class="sub-total">{{t('Итого','Total')}} <EnergyAmount :amount="offer.reward"/></span><span class="sub-daily">{{t('До','Up to')}} <EnergyAmount :amount="offer.daily"/> {{t('в сутки','per day')}}</span>
          <span class="sub-price"><span class="sub-price-box"><span class="sub-money-line"><del v-if="offer.comparison" class="sub-old-price">{{number(offer.comparison)}}</del><strong class="sub-price-amount">{{offer.price??'—'}} ★</strong></span><span class="sub-price-period">{{t(`за ${number(offer.days)} дней`,`for ${number(offer.days)} days`)}}</span></span></span>
          <span class="sub-owned">{{active===offer.tier?t('Подключено','Active'):'\u00a0'}}</span>
        </button>
      </div>
      <div v-if="showAds" class="sub-ad-benefit"><svg class="sub-shield" viewBox="0 0 64 70" fill="none" stroke="currentColor" stroke-width="3" aria-hidden="true"><path d="M32 4 57 14v20c0 16-14 27-25 32C20 60 7 49 7 34V14Z"/><rect x="18" y="22" width="29" height="22" rx="3"/><path d="m28 28 10 5-10 5ZM14 13l38 43"/></svg><div><h3>{{t('Без автоматической рекламы','No automatic ads')}}</h3><p>{{t('Включено в оба варианта','Included in both options')}}</p></div></div>
      <button v-if="chosen" v-analytics="{feature:'buy_subscription',placement:'energy'}" type="button" class="sub-connect" :disabled="busy||!available||chosen.price===null||active>1" @click="emit('buy')"><span class="sub-connect-emblems"><span class="sub-badge sub-added-badge" aria-hidden="true">+{{chosen.extra}}</span></span><span class="sub-connect-copy"><strong>{{active>1?(active===selected?t('Подписка подключена','Subscription active'):t('Уже есть подписка','Already subscribed')):t('Подключить подписку','Subscribe')}}</strong><span class="sub-price-box"><span class="sub-money-line"><del v-if="chosen.comparison" class="sub-old-price">{{number(chosen.comparison)}}</del><strong class="sub-price-amount">{{chosen.price??'—'}} ★</strong></span><span class="sub-price-period">{{t(`за ${number(chosen.days)} дней`,`for ${number(chosen.days)} days`)}}</span></span></span></button>
      <p v-if="chosen" class="sub-terms">{{t(`${number(chosen.days)} дней · автопродление`,`${number(chosen.days)} days · auto-renewal`)}}<br>{{t('Управление и отмена в Telegram','Manage and cancel in Telegram')}}<br>{{t('Максимум в сутки — при каждом получении бонуса.','Daily maximum requires collecting each bonus.')}}</p>
      <p v-if="!available||!offers.length" class="sub-terms">{{t('Покупки пока недоступны.','Purchases are not available yet.')}}</p>
    </div>
  </section>
</template>
<style scoped src="./subscription-choice.css"></style>
<style scoped>
.sub-v9{border:0;box-shadow:none;width:100%;max-width:none;background:transparent;container-type:inline-size}.sub-body{padding:0 2px 6px}.sub-plan:disabled{cursor:default}.sub-reward{display:flex;justify-content:center}.sub-total,.sub-daily{display:block}.sub-additive .sub-header-copy{box-sizing:content-box;padding-left:40px;width:55%}.sub-connect-copy{min-width:0}.sub-connect .sub-price-box{flex-wrap:wrap}.sub-terms{font-size:11px;color:#aacbd7;text-align:center;line-height:1.4}.sub-daily{white-space:normal}.sub-plan .sub-price-box{width:100%;box-sizing:border-box}.sub-money-line{flex-wrap:wrap}.sub-price-amount{white-space:nowrap}.sub-old-price{white-space:nowrap}.sub-options{gap:10px}.sub-connect-emblems{flex-shrink:0}.sub-orb svg{display:block}
@container(max-width:300px){.sub-header-copy h2{font-size:23px}.sub-header-copy p{font-size:14px}.sub-price-amount{font-size:23px}.sub-connect-copy>strong{font-size:15px}.sub-money-line{gap:3px}.sub-plan{padding-left:6px;padding-right:6px}}
</style>
