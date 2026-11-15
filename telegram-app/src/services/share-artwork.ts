import {validateSettingsPng} from './settings-artwork';
export const shareArtwork='/assets/branding/ui/share-scene-square-v1.png';
export interface ShareArtworkResource {url:string;image:HTMLImageElement;dispose:()=>void}
const MAX_BYTES=8*1024*1024;
/** One share-window resource, verified before either preview or PNG export sees it. */
export async function loadShareArtwork(revision:number,signal:AbortSignal,timeoutMs=40000):Promise<ShareArtworkResource>{
 const controller=new AbortController();let url='',image:HTMLImageElement|undefined,disposed=false;
 const check=()=>{if(controller.signal.aborted)throw new DOMException('Aborted','AbortError');};
 const dispose=()=>{if(disposed)return;disposed=true;image?.removeAttribute('src');if(url)URL.revokeObjectURL(url);};
 const relay=()=>controller.abort();signal.addEventListener('abort',relay,{once:true});if(signal.aborted)relay();
 let rejectAbort:(()=>void)|undefined;
 const aborted=new Promise<never>((_,reject)=>{rejectAbort=()=>reject(new DOMException('Aborted','AbortError'));controller.signal.addEventListener('abort',rejectAbort,{once:true});if(controller.signal.aborted)rejectAbort();});
 const timer=setTimeout(()=>controller.abort(),timeoutMs);
 const work=Promise.resolve().then(async()=>{
  check();const response=await fetch(shareArtwork+(revision?`?artRetry=${revision}`:''),{signal:controller.signal});check();
  if(!response.ok||!/^image\/png(?:;|$)/i.test(response.headers.get('content-type')??''))throw Error('share_artwork_unavailable');
  if(Number(response.headers.get('content-length'))>MAX_BYTES)throw Error('share_artwork_too_large');
  const parts:Uint8Array[]=[];let size=0;
  if(response.body){const reader=response.body.getReader();try{for(;;){const part=await reader.read();check();if(part.done)break;size+=part.value.byteLength;if(size>MAX_BYTES){await reader.cancel();throw Error('share_artwork_too_large');}parts.push(part.value);}}finally{reader.releaseLock();}}
  else{const bytes=new Uint8Array(await response.arrayBuffer());check();size=bytes.length;parts.push(bytes);}
  check();if(size>MAX_BYTES)throw Error('share_artwork_too_large');const bytes=new Uint8Array(size);let offset=0;for(const part of parts){bytes.set(part,offset);offset+=part.length;}validateSettingsPng(bytes);check();
  url=URL.createObjectURL(new Blob([bytes.buffer],{type:'image/png'}));image=new Image();image.src=url;await image.decode();check();
  if(!image.naturalWidth||!image.naturalHeight)throw Error('share_artwork_unavailable');return{url,image,dispose};
 });
 try{return await Promise.race([work,aborted]);}catch(error){controller.abort();dispose();throw error;}
 finally{clearTimeout(timer);signal.removeEventListener('abort',relay);if(rejectAbort)controller.signal.removeEventListener('abort',rejectAbort);}
}
