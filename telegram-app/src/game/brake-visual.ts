import type {BrakeState} from '../domain/kernel';
export function brakeCountdownText(remaining:number){return (Math.ceil(Math.max(0,remaining)*10-1e-9)/10).toFixed(1).replace('.',',');}
export function brakeReadyFlash(ageMs:number,reduced=false){
 if(reduced||ageMs<0||ageMs>=520)return 0;
 const t=ageMs/520,ramp=t<.35?t/.35:(1-t)/.65;
 return ramp*ramp*(3-2*ramp);
}
export function brakeVisual(b:BrakeState,playing:boolean,reduced:boolean,settings:Record<string,unknown>={}){
 const valid=(key:string,fallback:number)=>{const v=settings[key];return typeof v==='number'&&Number.isFinite(v)?Math.max(.1,Math.min(120,v)):fallback;};
 const duration=b.presses===0?valid('brakeFirstReadySec',6):valid('brakeCooldownSec',6);
 const pressing=playing&&b.pressAgeMs>=0&&b.pressAgeMs<120;
 return {pressing,charged:b.ready||pressing,timer:brakeCountdownText(Math.max(.1,(1-Math.max(0,Math.min(1,b.charge)))*duration)),flash:b.ready&&playing?brakeReadyFlash(b.readyAgeMs,reduced):0};
}
