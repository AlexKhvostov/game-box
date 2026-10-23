export const enemyPaceDefaults=Object.freeze({"initialSpeed": 0, "growthMultiplier": 70, "growthExponent": 0.2, "startSmoothingSec": 3, "initialCompensation": 1, "brakeCooldownSec": 6, "brakeFirstReadySec": 6, "brakeRewindSec": 6, "brakeEnabled": true, "speedBarEnabled": true});
export const enemyPaceRanges=Object.freeze({"initialSpeed": [0, 150, 0.01, "шаг/с"], "growthMultiplier": [0, 200, 0.01], "growthExponent": [0.01, 1, 0.01], "startSmoothingSec": [0.01, 60, 0.01, "с"], "initialCompensation": [0, 10, 0.01], "brakeCooldownSec": [0.1, 120, 0.1, "с"], "brakeFirstReadySec": [0.1, 120, 0.1, "с"], "brakeRewindSec": [0, 120, 0.1, "с"]});
export function enemyPaceValid(config){
 const c=config?.enemyPace??{};
 if(typeof c!=='object'||Array.isArray(c))return false;
 return Object.entries(enemyPaceDefaults).every(([k,d])=>{
  if(typeof d==='boolean')return c[k]===undefined||typeof c[k]==='boolean';
  const v=c[k]??d,[lo,hi]=enemyPaceRanges[k];
  return typeof v==='number'&&Number.isFinite(v)&&v>=lo&&v<=hi;
 });
}
