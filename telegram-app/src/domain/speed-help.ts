import {version} from '../../package.json';
export const ENEMY_SPEED_SLOT_HEIGHT=32;
export interface PacePoint {t:number;target:number;phase?:string}
export interface PaceEvent {t:number;before:number;after:number;pastT:number;waitedSec:number;readyAtBefore:number;readyTarget:number}
export interface PaceSnapshot extends PacePoint {ok:boolean;effective:number;ready:boolean;remaining:number;cooldown:number;rewind:number;readyAt:number;readyTarget:number|null;presses:number;ended:boolean;event?:PaceEvent}
export interface PacePreview {ok:boolean;duration:number;baseline:PacePoint[];actual:PacePoint[];events:PaceEvent[];rewind:number}
declare global {var untouchSpeedHelp:((input:string)=>string)|undefined}
let loading:Promise<void>|undefined;
export function loadSpeedHelp(){
 return loading??=new Promise<void>((resolve,reject)=>{
  if(globalThis.untouchSpeedHelp){resolve();return;}
  const script=document.createElement('script');
  script.src=`${import.meta.env.BASE_URL}kernel/speed-help-model-v1.js?v=${version}`;
  script.onload=()=>globalThis.untouchSpeedHelp?resolve():reject(Error('speed_help_unavailable'));
  script.onerror=()=>reject(Error('speed_help_unavailable'));document.head.append(script);
 }).catch(error=>{loading=undefined;throw error;});
}
export function speedHelpCall<T>(input:Record<string,unknown>):T{
 if(!globalThis.untouchSpeedHelp)throw Error('speed_help_unavailable');
 return JSON.parse(globalThis.untouchSpeedHelp(JSON.stringify(input))) as T;
}
