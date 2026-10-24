// Local dialogs consume Back before changing the page or a saved result.
const handlers:(()=>void)[]=[];
export function registerOverlayBack(close:()=>void){
  handlers.push(close);
  return()=>{const index=handlers.lastIndexOf(close);if(index>=0)handlers.splice(index,1);};
}
export function closeTopOverlay(){const close=handlers.at(-1);if(!close)return false;close();return true;}
