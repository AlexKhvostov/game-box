import { state, request } from './game-store';
import { DurableStorage, operationId } from './storage';
import { ensureResourceAge } from '../platform/audience';
import { telegram, isNativeTelegram } from '../platform/telegram';
import { stopAudio, syncMusic } from '../platform/audio';
const storage=new DurableStorage();
export const starsAvailable=()=>isNativeTelegram()&&state.platform?.stars.salesEnabled===true&&!!telegram()?.openInvoice;
let purchasing=false;
const ownerIs=(owner:string)=>state.profile?.id===owner;
function eligible(owner:string,screen:string){return ownerIs(owner)&&starsAvailable()&&state.screen===screen&&!document.hidden&&telegram()?.isActive!==false;}
export async function buyStarsProduct(productId:string){
  if(purchasing)throw Error('checkout_in_progress');
  const owner=state.profile?.id,screen=state.screen;
  if(!owner||!eligible(owner,screen))throw Error('stars_unavailable');
  purchasing=true;
  try{
    if(!await ensureResourceAge())return;
    if(!ownerIs(owner))throw Error('owner_changed');
    if(!eligible(owner,screen))throw Error('stars_unavailable');
    const key=`stars-order:${owner}:${productId}`,requestId=storage.get<string|null>(key,null)??operationId();storage.set(key,requestId);
    const retire=()=>{if(storage.get(key,null)===requestId)storage.set(key,null);};
    let quote;
    try{quote=await request({action:'stars_invoice',productId,requestId});}
    catch(error){if(error instanceof Error&&error.message==='invoice_expired')retire();throw error;}
    if(!ownerIs(owner))throw Error('owner_changed');
    if(!eligible(owner,screen))throw Error('stars_unavailable');
    if(typeof quote.invoiceUrl!=='string'||!/^https:\/\/t\.me\/\$[A-Za-z0-9_-]+$/.test(quote.invoiceUrl))throw Error('invoice_invalid');
    state.externalBusy=true;stopAudio();
    try{
      const status=await new Promise<string>((resolve,reject)=>{
        const timeout=setTimeout(()=>resolve('pending'),180000);
        try{telegram()!.openInvoice!(quote.invoiceUrl,value=>{clearTimeout(timeout);resolve(value);});}catch{clearTimeout(timeout);reject(Error('stars_unavailable'));}
      });
      if(!ownerIs(owner))throw Error('owner_changed');
      if(['paid','cancelled','failed'].includes(status))retire();
      // UI payment events never credit locally. Only the server webhook does.
      await request({action:'profile'});
      if(!ownerIs(owner))throw Error('owner_changed');
      state.notice=state.locale==='ru'?(status==='paid'?'Платёж завершён. Начисление подтверждает сервер; при задержке обновите баланс.':status==='cancelled'?'Покупка отменена.':status==='failed'?'Платёж не прошёл.':'Платёж ожидает подтверждения.'):(status==='paid'?'Payment completed. The server confirms delivery; refresh the balance if delayed.':status==='cancelled'?'Purchase cancelled.':status==='failed'?'Payment failed.':'Payment is awaiting confirmation.');
    }finally{state.externalBusy=false;syncMusic();}
  }finally{purchasing=false;}
}
export async function cancelStarsSubscription(){const owner=state.profile?.id;if(!owner||!isNativeTelegram())throw Error('stars_unavailable');await request({action:'stars_cancel',cancel:true});if(!ownerIs(owner))throw Error('owner_changed');await request({action:'profile'});}
