export interface SubscriptionOffer {
  tier: 2 | 5; base: number; reward: number; extra: number; portions: number | null;
  daily: number; price: number | null; days: number; discount: number | null; comparison: number | null;
}
/** Energy comes from the game policy; Stars prices and duration come from Telegram. */
export function subscriptionOffers(policy: Record<string, any> | undefined, stars: Record<string, any> | undefined, periodSec: number): SubscriptionOffer[] {
  const base=policy?.reward;
  if(!Number.isFinite(base)||base<=0||!Number.isFinite(periodSec)||periodSec<=0)return [];
  const days=(stars?.periodSec??0)/86400;
  const offers=([2,5] as const).flatMap(tier=>{
    const reward=policy?.[tier===2?'tier2Reward':'tier5Reward'];
    if(!Number.isFinite(reward)||reward<base)return [];
    const extra=reward-base,rawPrice=stars?.[tier===2?'tier2Price':'tier5Price'];
    const price=Number.isSafeInteger(rawPrice)&&rawPrice>0&&days>0?rawPrice:null;
    return [{tier,base,reward,extra,portions:extra>0&&Number.isInteger(extra/base)&&extra/base<=8?extra/base:null,
      daily:Math.floor(86400/periodSec)*reward,price,days,discount:null,comparison:null} as SubscriptionOffer];
  });
  const first=offers.find(o=>o.tier===2),second=offers.find(o=>o.tier===5);
  if(first?.price&&first.extra>0&&second?.price){
    const comparison=first.price*second.extra/first.extra;
    const saving=Math.floor((1-second.price/comparison)*100+1e-8);
    if(Number.isFinite(comparison)&&comparison>second.price&&saving>0){second.comparison=comparison;second.discount=saving;}
  }
  return offers;
}
