import {watch} from 'vue';
import {state,world} from '../services/game-store';
import {telegram} from './telegram';
import {GameAudio,effects,celebrationVolume,type SoundName} from './audio-engine';
import {enemyReactionsAllowed,type GamePresentationPolicy,type GamePresentationPreferences} from '../game/presentation-policy';
let paused=false;
const inhibitions=new Set<symbol>(),previews=new Set<symbol>();
const active=()=>!inhibitions.size&&!paused&&!document.hidden&&telegram()?.isActive!==false&&!state.externalBusy;
// Celebrations own externalBusy independently of the game-audio paused flag.
// Neither flag mutes their presentation; foreground/inhibition still apply.
const celebrationActive=()=>!inhibitions.size&&!document.hidden&&telegram()?.isActive!==false;
const enemyVoices=()=>enemyReactionsAllowed((state as typeof state&{presentation?:GamePresentationPolicy}).presentation,state.preferences as typeof state.preferences&GamePresentationPreferences);
const engine=new GameAudio(()=>{const config=state.config?.config.audio??{},preview=previews.size>0;return{active:active(),sound:preview||state.preferences.sound,music:preview||state.preferences.music,enemyVoicesEnabled:preview||enemyVoices(),config:preview?{...config,music:true,...Object.fromEntries(Object.values(effects).map(effect=>[effect.flag,true]))}:config};});
export function awardVolume(kind:'medal'|'level'){return celebrationVolume(kind,{active:celebrationActive(),sound:state.preferences.sound,config:state.config?.config.audio??{}});}
export async function prepareAudio(){await engine.prepare();engine.sync();}
function prepareMissingAudioWhenIdle(){if(state.initialized&&active()&&!world.value?.playing&&!state.screen&&!state.windowClosing&&!state.busy)void prepareAudio();}
export function enableAudio(){paused=false;void engine.unlock();}
export function syncMusic(){paused=document.hidden||telegram()?.isActive===false||state.externalBusy;engine.sync();if(!paused){engine.resumeIfUnlocked();prepareMissingAudioWhenIdle();}}
export function sound(name:SoundName){if(name==='start')engine.startFromGesture();else engine.play(name);}
export function stopAudio(){paused=true;engine.stop();}
export function inhibitAudio(){const token=Symbol();inhibitions.add(token);engine.stop();return()=>{inhibitions.delete(token);};}
export function previewAllAudioEffects(){if(!import.meta.env.DEV&&import.meta.env.VITE_QA_MODE!=='true')return()=>{};const token=Symbol();previews.add(token);engine.sync();return()=>{previews.delete(token);engine.sync();};}
export function audioDiagnostics(){return engine.diagnostics();}
export function installAudio(){
  const gesture=(event:Event)=>{if(event.isTrusted)enableAudio();};
  window.addEventListener('pointerdown',gesture,{capture:true,passive:true});
  window.addEventListener('keydown',gesture,{capture:true});
  const unwatch=watch(()=>[state.preferences.sound,state.preferences.music,enemyVoices(),state.config?.config.audio],()=>engine.sync(),{deep:true});
  const stopIdleRetry=watch([()=>state.initialized,()=>!!world.value?.playing,()=>state.screen,()=>state.windowClosing,()=>state.busy,()=>state.externalBusy],prepareMissingAudioWhenIdle);
  return()=>{unwatch();stopIdleRetry();window.removeEventListener('pointerdown',gesture,true);window.removeEventListener('keydown',gesture,true);engine.dispose();};
}
