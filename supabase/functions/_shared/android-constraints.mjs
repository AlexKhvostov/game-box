// Shared by publication and the runtime. The Android world has fixed 380-unit
// geometry; a syntactically valid Remote Config must also be playable.
export function androidGeometryIssues(config) {
  const errors=[];
  const hero=config.player.size*1.2;
  if(!Number.isFinite(hero)||hero/380<0.03||hero/380>0.25)
    errors.push({path:'player.size',error:'Размер игрока не помещается в допустимые пропорции поля Android.'});
  const aspects=config.enemies.aspects;
  if(!Array.isArray(aspects)||aspects.length!==4||aspects.some(v=>!Number.isFinite(v)||v<=0.05||v>=50))
    errors.push({path:'enemies.aspects',error:'Android требует четыре формы врагов с отношением сторон больше 0,05 и меньше 50.'});
  if(Array.isArray(aspects)) {
    const border=config.field.borderWidth;
    const inset=Math.min(12,Math.max(0.5,border/2+0.5))+border/2;
    const pad=Math.max(8,inset+2), quadrant=190-2*pad;
    const area=hero*hero*Math.max(0.2,Math.min(20,config.enemies.areaMultiplier));
    const spinning=Math.abs(config.enemies.spinDegPerSec)>0.01;
    if(aspects.some(aspect=>{
      const w=Math.sqrt(area*aspect),h=Math.sqrt(area/aspect);
      return !Number.isFinite(w+h)||(spinning?Math.hypot(w,h)>quadrant:w>quadrant||h>quadrant);
    })) errors.push({path:'enemies.areaMultiplier',error:'Сочетание размеров игрока, врагов, вращения и границы не помещается в стартовые области поля.'});
  }
  return errors;
}

// Deliberately generous admission bounds, not proof that an unmodified game
// was played. The server still owns elapsed time, equipment, reward and nonce.
// A full replay verifier would be a separate protocol; never claim these
// plausibility checks authenticate arbitrary metrics supplied by a client.
export function plausibleAndroidResult(result) {
  const seconds=result.timeMs/1000;
  return result.runDistance<=32+Math.ceil(seconds*4000)
    && result.riskCount<=4+Math.ceil(seconds*64);
}
