// Local dialogs consume Back before changing the page or a saved result.
import {analyticsOverlay} from './analytics';
import {ref,readonly} from 'vue';
const handlers:{close:()=>void}[]=[];
const overlayCount=ref(0);
export const activeOverlayCount=readonly(overlayCount);
export function registerOverlayBack(close:()=>void,name='dialog'){
  const stopAnalytics=analyticsOverlay(name);
  const entry={close};handlers.push(entry);
  overlayCount.value=handlers.length;
  let released=false;
  return()=>{if(released)return;released=true;stopAnalytics();const index=handlers.indexOf(entry);if(index>=0)handlers.splice(index,1);overlayCount.value=handlers.length;};
}
export function closeTopOverlay(){const entry=handlers.at(-1);if(!entry)return false;entry.close();return true;}
