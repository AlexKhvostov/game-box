// Shared by the admin browser and server. No runtime credentials or Node APIs.
export const adKeys=['interstitialSessionGraceSec','interstitialSessionFreeRounds','interstitialGraceSec','interstitialCooldownSec','interstitialMinLives'];
// Timing/energy gates belong to the shared economy. Provider IDs and switches
// stay platform-specific because Android and Telegram use different SDKs.
export const configFieldScope=path=>'common';
const field=(path,label,type,min=0,max=100000)=>({path,label,type,section:'platform',readOnly:false,default:type==='boolean'?false:type==='string'?'':0,min,max,step:1,help:'Применяется только к выбранной платформе.'});
export const platformFields={
  android:[],
  telegram:[
    field('ads.rewardedBlockId','AdsGram: блок с наградой','string'),field('ads.interstitialBlockId','AdsGram: полноэкранный блок','string'),
    field('ads.enabled','Реклама включена','boolean'),
    {...field('ads.interstitialEnabled','Автоматическая полноэкранная реклама','boolean'),help:'Автоматические показы в Telegram; по умолчанию выключено. Не влияет на рекламу за энергию. Также должен быть включён пункт «Реклама включена».'},
    field('stars.salesEnabled','Продажи Stars включены','boolean'),
    ...['100','250','500','1000'].map(n=>field(`stars.pack${n}Price`,`${n} энергии: стоимость в Stars`,'number',1,100000)),
    field('stars.tier2Price','Подписка ×2: Stars','number',1,10000),field('stars.tier5Price','Подписка ×5: Stars','number',1,10000),
    field('stars.periodSec','Срок подписки, секунды','number',2592000,2592000)]
};
export function initialPlatformSettings(config){
  return {android:{ads:{}},telegram:{ads:{enabled:false,interstitialEnabled:false,rewardedBlockId:'',interstitialBlockId:''},
    stars:{salesEnabled:false,pack100Price:25,pack250Price:55,pack500Price:99,pack1000Price:179,tier2Price:149,tier5Price:399,periodSec:2592000}}};
}
