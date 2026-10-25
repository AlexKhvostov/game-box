import {watch,type Directive} from 'vue';
import {state} from './game-store';
import {analyticsClick,analyticsWindows} from './analytics';
const windowName=(screen:string)=>({ranking:'leaderboard',history:'my_attempts',chart:'average_chart','player-result':'player_result','name-actions':'public_name'}[screen]??screen.replace(/-/g,'_'));
export function installAnalyticsUi(){
 watch(()=>state.screen,screen=>analyticsWindows(screen?[windowName(screen)]:[]),{immediate:true,flush:'sync'});
}
type Binding={feature:string;placement:string};
const observations=new WeakMap<HTMLElement,{stop:()=>void;update:(value:Binding)=>void}>();
export const analyticsDirective:Directive<HTMLElement,Binding>={
 mounted(el,binding){
  let value=binding.value;
  const click=()=>{if(!(el as HTMLButtonElement).disabled&&el.getAttribute('aria-disabled')!=='true'&&!el.closest('[inert],[aria-hidden="true"]'))analyticsClick(value.placement,value.feature);};
  // Capture before Vue navigation makes the previous window inert or unmounts it.
  el.addEventListener('click',click,true);observations.set(el,{update:next=>value=next,stop:()=>el.removeEventListener('click',click,true)});
 },
 updated(el,binding){observations.get(el)?.update(binding.value);},unmounted(el){observations.get(el)?.stop();observations.delete(el);}
};
