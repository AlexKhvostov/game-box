export interface AwardArtwork {id:string;src:string|null;dispose:()=>void}
export const awardStudio='/assets/achievements/scene/stage-studio-portrait.webp';
export const awardFanfare='/assets/achievements/scene/tada.mp3';
const aborted=()=>new DOMException('Aborted','AbortError');

/** Load one existing still. A stalled image falls back to the collection thumbnail. */
export async function loadAwardArtwork(id:string,signal:AbortSignal):Promise<AwardArtwork>{
  if(!/^(?:[a-z]+-)+(?:\d+|day|week|month|year|first)$/.test(id))throw Error('invalid_award_id');
  if(signal.aborted)throw aborted();
  const controller=new AbortController();
  let image:HTMLImageElement|undefined,src:string|null=null;
  const dispose=()=>{if(src){URL.revokeObjectURL(src);src=null;}};
  const interrupt=()=>{controller.abort();image?.removeAttribute('src');};
  signal.addEventListener('abort',interrupt,{once:true});
  const timer=setTimeout(interrupt,2200);
  try{
    const response=await fetch('/assets/achievements/art-768/'+id+'.webp',{signal:controller.signal});
    if(!response.ok)throw Error('award_artwork_unavailable');
    const blob=await response.blob();
    if(controller.signal.aborted)throw aborted();
    src=URL.createObjectURL(blob);
    image=new Image();image.src=src;
    await image.decode();
    if(controller.signal.aborted)throw aborted();
    return {id,src,dispose};
  }catch(error){
    dispose();
    if(signal.aborted)throw error;
    return {id,src:null,dispose};
  }finally{
    clearTimeout(timer);signal.removeEventListener('abort',interrupt);
  }
}
type Entry={controller:AbortController;promise:Promise<AwardArtwork>;value?:AwardArtwork};
/** At most current+next. Eviction aborts requests and releases decoded image URLs. */
export class AwardArtworkPool {
 private entries=new Map<string,Entry>();private disposed=false;
 private loader:typeof loadAwardArtwork;
 constructor(loader=loadAwardArtwork){this.loader=loader;}
 retain(current:string|null,next:string|null=null){
  if(this.disposed)return;
  const keep=new Set([current,next].filter((id):id is string=>!!id));
  for(const [id,entry] of this.entries)if(!keep.has(id)){this.entries.delete(id);entry.controller.abort();entry.value?.dispose();}
  for(const id of keep)if(!this.entries.has(id)){
   const controller=new AbortController(),entry={} as Entry;entry.controller=controller;
   entry.promise=this.loader(id,controller.signal).then(value=>{
    if(controller.signal.aborted||this.disposed||this.entries.get(id)!==entry){value.dispose();throw new DOMException('Aborted','AbortError');}
    entry.value=value;return value;
   });this.entries.set(id,entry);void entry.promise.catch(()=>{});
  }
 }
 prepared(id:string){return this.entries.get(id)?.value??null;}
 ready(id:string){const entry=this.entries.get(id);return entry?entry.promise:Promise.reject(Error('award_not_retained'));}
 get size(){return this.entries.size;}
 dispose(){if(this.disposed)return;this.retain(null);this.disposed=true;}
}
let studioPrepared=false;
export function prepareAwardStudio(){
  if(studioPrepared)return;
  studioPrepared=true;
  const image=new Image();
  image.src=awardStudio;
  void image.decode().catch(()=>{});
  // Warm the short fanfare in the HTTP cache without blocking the picture.
  void fetch(awardFanfare).catch(()=>{});
}
