// Prepare only result typography; gameplay uses its existing Roboto/atlas.
let ready:Promise<void>|undefined;
export function prepareResultFonts(){return ready??=(async()=>{
  if(!document.fonts?.load)return;
  let timer:ReturnType<typeof setTimeout>|undefined;
  try{await Promise.race([Promise.all([document.fonts.load('900 46px RobotoResult'),document.fonts.load('500 13px RobotoResult'),document.fonts.load('700 13px RobotoResult')]),new Promise(resolve=>{timer=setTimeout(resolve,2000);})]);}catch{}finally{if(timer)clearTimeout(timer);}
})();}
