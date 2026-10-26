// Exact timing/geometry from the frozen EnergyRewardFrame (Android 188).
export const clamp = (n: number) => Math.max(0,Math.min(1,n));
export const ease = (n: number) => 1-(1-n)**3;
// Current shared Android/Telegram integer counter; frozen kernel geometry stays compatible.
export const energyRoll=(progress:number,reduced=false)=>ease(clamp((progress-(reduced ? .5 : .8))/(reduced ? .5 : .2)));
export function rewardFrame(progress: number, reduced = false) {
  const p=clamp(progress), appearance=clamp(p/.1125), flight=reduced?0:clamp((p-.4)/.4);
  const fly=flight<.5?4*flight**3:1-(-2*flight+2)**3/2;
  const pop=1+2.70158*(appearance-1)**3+1.70158*(appearance-1)**2;
  return {p,appearance,flight,fly,scale:reduced?1:(.82+.18*pop)*(1-.78*fly),opacity:appearance*(1-clamp((flight-.76)/.24)),roll:reduced?p:clamp((p-.8)/.2),hit:reduced?0:Math.sin(Math.PI*clamp((p-.83)/.17))};
}
