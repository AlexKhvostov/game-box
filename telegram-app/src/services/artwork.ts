// Keep the result illustration decoded before the first round finishes, as
// Android GameHomeScreen does. Retain successful loads for the WebView session.
const decoded = new Map<string, Promise<HTMLImageElement>>();
const prepared = new Map<string, string>();
export const resultArtwork = '/assets/branding/ui/result-scene-v1.png';
export const resultTrophy = '/assets/branding/ranking/trophy.svg';
export const preparedArtwork = (src:string) => prepared.get(src);
export function loadArtwork(src: string): Promise<HTMLImageElement> {
  let pending = decoded.get(src);
  if (!pending) {
    pending = (async()=>{
      const abort=new AbortController();
      const art = new Image();
      let objectUrl='',timer:ReturnType<typeof setTimeout>|undefined;
      const deadline=new Promise<never>((_,reject)=>{
        timer=setTimeout(()=>{abort.abort();reject(Error('artwork_unavailable'));},2000);
      });
      const load=async()=>{
        const response=await fetch(src,{signal:abort.signal});
        if(!response.ok)throw Error('artwork_unavailable');
        const file=await response.blob();
        if(abort.signal.aborted)throw Error('artwork_unavailable');
        objectUrl=URL.createObjectURL(file);art.src=objectUrl;
        await art.decode();
      };
      try{
        await Promise.race([load(),deadline]);
        prepared.set(src,objectUrl);return art;
      }catch(error){
        if(objectUrl){art.removeAttribute('src');URL.revokeObjectURL(objectUrl);}
        decoded.delete(src);throw error;
      }finally{clearTimeout(timer);}
    })();
    decoded.set(src, pending);
  }
  return pending;
}
export function warmResultArtwork() {
  return Promise.allSettled([loadArtwork(resultArtwork),loadArtwork(resultTrophy)]);
}
