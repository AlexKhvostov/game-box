import './share-download.css';
import {createApp} from 'vue';
import LoadingClock from './components/LoadingClock.vue';
import {decodeShareDownload,downloadCardData,sharePngName} from './domain/share-download';
import {renderShareCard} from './services/share-card';
import {loadShareArtwork,type ShareArtworkResource} from './services/share-artwork';
const status=document.querySelector<HTMLElement>('#status')!,preview=document.querySelector<HTMLImageElement>('#preview')!,download=document.querySelector<HTMLButtonElement>('#download')!,retry=document.querySelector<HTMLButtonElement>('#retry')!,hint=document.querySelector<HTMLElement>('#hint')!,loading=document.querySelector<HTMLElement>('#loading')!;
// Only the approved clock is mounted: no application/bootstrap/authentication.
createApp(LoadingClock,{size:24}).mount(loading);
let url='',name='';
type Operation={controller:AbortController;art?:ShareArtworkResource};let operation:Operation|undefined;
function clear(){if(url)URL.revokeObjectURL(url);url='';preview.hidden=true;preview.removeAttribute('src');download.disabled=true;}
function cancel(){const old=operation;operation=undefined;old?.controller.abort();old?.art?.dispose();clear();loading.hidden=true;}
async function fonts(signal:AbortSignal){
 let timer:ReturnType<typeof setTimeout>|undefined,abort:(()=>void)|undefined;
 try{
  const faces=await Promise.race([Promise.all([500,700,900].map(weight=>document.fonts.load(`${weight} 46px RobotoResult`))),new Promise<never>((_,reject)=>{timer=setTimeout(()=>reject(Error('share_fonts_unavailable')),15000);}),new Promise<never>((_,reject)=>{abort=()=>reject(new DOMException('Aborted','AbortError'));signal.addEventListener('abort',abort,{once:true});if(signal.aborted)abort();})]);
  // FontFaceSet.check alone can return true for a family absent from CSS.
  if(faces.some(group=>group.length===0)||![500,700,900].every(weight=>document.fonts.check(`${weight} 46px RobotoResult`)))throw Error('share_fonts_unavailable');
 }finally{clearTimeout(timer);if(abort)signal.removeEventListener('abort',abort);}
}
async function prepare(){
 cancel();const op:Operation={controller:new AbortController()};operation=op;const current=()=>operation===op&&!op.controller.signal.aborted;retry.hidden=true;loading.hidden=false;
 try{
  const dto=decodeShareDownload(location.hash),data=downloadCardData(dto),ru=dto.locale==='ru';document.documentElement.lang=dto.locale;
  status.textContent=ru?'Готовим картинку…':'Preparing image…';download.textContent=ru?'Скачать PNG':'Download PNG';retry.textContent=ru?'Повторить':'Retry';hint.textContent=ru?'Нажмите «Скачать PNG». Если загрузка недоступна, откройте эту страницу в браузере.':'Select Download PNG. If downloading is unavailable, open this page in your browser.';
  await fonts(op.controller.signal);if(!current())return;
  const art=await loadShareArtwork(0,op.controller.signal);if(!current()){art.dispose();return;}op.art=art;
  const canvas=await renderShareCard(data,art.image);if(!current())return;
  const blob=await new Promise<Blob>((resolve,reject)=>canvas.toBlob(b=>b?resolve(b):reject(Error('share_image_unavailable')),'image/png'));if(!current())return;
  url=URL.createObjectURL(blob);name=sharePngName(dto.time);preview.src=url;await preview.decode();if(!current())return;preview.hidden=false;download.disabled=false;status.textContent=ru?'Картинка готова.':'Image ready.';
 }catch{if(current()){clear();status.textContent='Картинка недоступна. Проверьте ссылку и подключение. / Image unavailable. Check the link and connection.';retry.hidden=false;}}
 finally{op.art?.dispose();op.art=undefined;if(current())loading.hidden=true;}
}
download.addEventListener('click',()=>{if(!url||download.disabled)return;const a=document.createElement('a');a.href=url;a.download=name;document.body.append(a);a.click();a.remove();});
retry.addEventListener('click',()=>void prepare());window.addEventListener('hashchange',()=>void prepare());
window.addEventListener('pagehide',()=>{cancel();status.textContent='Вернитесь на страницу или повторите подготовку. / Return to this page or retry preparing the image.';retry.hidden=false;});
window.addEventListener('pageshow',event=>{if(event.persisted)void prepare();});void prepare();
