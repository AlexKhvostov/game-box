// Local dialogs consume Back before changing the page or a saved result.
import {analyticsOverlay} from './analytics';
const handlers:(()=>void)[]=[];
export function registerOverlayBack(close:()=>void,name='dialog'){
  const stopAnalytics=analyticsOverlay(name);
  handlers.push(close);
  return()=>{stopAnalytics();const index=handlers.lastIndexOf(close);if(index>=0)handlers.splice(index,1);};
}
export function closeTopOverlay(){const close=handlers.at(-1);if(!close)return false;close();return true;}
