export interface AwardAtlas {frames:number;columns:number;tileSize:number;orientationDuration:number;sceneDuration:number}
export interface AwardArtwork {
  id:string;atlas:CanvasImageSource|null;start:CanvasImageSource|null;end:CanvasImageSource|null;
  metadata:AwardAtlas;fallback:boolean;dispose:()=>void;
}
const defaultMetadata:AwardAtlas={frames:64,columns:8,tileSize:512,orientationDuration:2.1,sceneDuration:4.35};
type Decoded={image:CanvasImageSource;close:()=>void};
async function decode(url:string,signal:AbortSignal):Promise<Decoded>{
 const response=await fetch(url,{signal});if(!response.ok)throw Error('award_artwork_unavailable');const blob=await response.blob();
 if(signal.aborted)throw new DOMException('Aborted','AbortError');
 if(typeof createImageBitmap==='function'){
  const image=await createImageBitmap(blob);if(signal.aborted){image.close();throw new DOMException('Aborted','AbortError');}
  return {image,close:()=>image.close()};
 }
 const src=URL.createObjectURL(blob),image=new Image();
 try{image.src=src;await image.decode();if(signal.aborted)throw new DOMException('Aborted','AbortError');return {image,close:()=>{image.removeAttribute('src');URL.revokeObjectURL(src);}};}
 catch(error){URL.revokeObjectURL(src);throw error;}
}
/** Decodes only when the stopped scene needs this award. All resources owned here. */
export async function loadAwardArtwork(id:string,signal:AbortSignal):Promise<AwardArtwork>{
 if(!/^(?:[a-z]+-)+(?:\d+|day|week|month|year|first)$/.test(id))throw Error('invalid_award_id');
 const owned:Decoded[]=[];let disposed=false;
 const dispose=()=>{if(disposed)return;disposed=true;for(const asset of owned)asset.close();};
 const image=async(suffix:string)=>{const asset=await decode(`/assets/achievements/animations-v1/${id}.${suffix}.webp`,signal);if(disposed){asset.close();return null;}owned.push(asset);return asset.image;};
 let atlas:CanvasImageSource|null=null,start:CanvasImageSource|null=null,end:CanvasImageSource|null=null,metadata={...defaultMetadata},fallback=false;
 try{
  const response=await fetch(`/assets/achievements/animations-v1/${id}.json`,{signal});if(!response.ok)throw Error('award_metadata_unavailable');
  const value=await response.json();
  if(!Number.isInteger(value.frames)||value.frames<1||value.frames>128||!Number.isInteger(value.columns)||value.columns<1||value.columns>16||!Number.isInteger(value.tileSize)||value.tileSize<64||value.tileSize>1024||!Number.isFinite(value.orientationDuration)||value.orientationDuration<=0)throw Error('award_metadata_invalid');
  metadata={frames:value.frames,columns:value.columns,tileSize:value.tileSize,orientationDuration:value.orientationDuration,sceneDuration:value.sceneDuration};
  start=await image('start');end=await image('end');atlas=await image('atlas');
 }catch(error){
  if(signal.aborted){dispose();throw error;}fallback=true;
  if(!start&&!end){try{const asset=await decode(`/assets/achievements/art-768/${id}.webp`,signal);owned.push(asset);end=asset.image;}catch{/* A visible static MedalArt fallback remains in the ceremony. */}}
 }
 if(signal.aborted){dispose();throw new DOMException('Aborted','AbortError');}
 return {id,atlas,start,end,metadata,fallback,dispose};
}
type Entry={controller:AbortController;promise:Promise<AwardArtwork>;value?:AwardArtwork};
/** At most current+next. Eviction aborts requests and closes decoded bitmaps. */
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
let studio:Promise<void>|undefined;
export function prepareAwardStudio(){return studio??=new Promise<void>(resolve=>{
 const image=new Image();image.src='/assets/achievements/scene/stage-studio-portrait.png';
 void image.decode().catch(()=>{}).then(()=>resolve());
 // Fetching the short clip warms only the HTTP cache; it cannot play sound.
 void fetch('/assets/achievements/scene/tada.mp3').catch(()=>{});
});}
