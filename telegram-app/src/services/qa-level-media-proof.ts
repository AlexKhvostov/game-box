import {ref} from 'vue';

// QA-only, in-memory media observations. Never retain an asset URL or auth data.
export const qaLevelMediaProof=ref<{level:number;samples:Record<string,unknown>[]}[]>([]);
export function observeQaLevelMedia(video:HTMLVideoElement,level:number){
  if(import.meta.env.VITE_QA_MODE!=='true')return()=>{};
  const session={level,samples:[] as Record<string,unknown>[]};
  qaLevelMediaProof.value=[...qaLevelMediaProof.value.slice(-1),session];
  let attached=true;
  const finite=(n:number)=>Number.isFinite(n)?n:null;
  function record(event:string,error?:unknown){
    if(!attached||session.samples.length>=64)return;
    let decodedFrames:number|null=null,droppedFrames:number|null=null;
    try{const q=video.getVideoPlaybackQuality();decodedFrames=q.totalVideoFrames;droppedFrames=q.droppedVideoFrames;}catch{}
    let sameOrigin=false;try{sameOrigin=new URL(video.currentSrc||video.src,location.href).origin===location.origin;}catch{}
    const name=error&&typeof error==='object'&&'name' in error?String(error.name):'';
    session.samples.push({event,atMs:Math.round(performance.now()),currentTime:finite(video.currentTime),duration:finite(video.duration),readyState:video.readyState,networkState:video.networkState,
      width:video.videoWidth,height:video.videoHeight,paused:video.paused,ended:video.ended,muted:video.muted,volume:video.volume,errorCode:video.error?.code??0,
      ...(name?{playError:['NotAllowedError','NotSupportedError','AbortError'].includes(name)?name:'OtherError'}:{}),decodedFrames,droppedFrames,sameOrigin});
  }
  const events=['loadedmetadata','loadeddata','canplay','play','playing','timeupdate','waiting','stalled','ended','error','pause'];
  const listeners=events.map(event=>{const listener=()=>record(event);video.addEventListener(event,listener);return()=>video.removeEventListener(event,listener);});
  const ownPlay=Object.getOwnPropertyDescriptor(video,'play'),originalPlay=video.play;
  video.play=function(){record('play-request');const result=originalPlay.call(video);void result.then(()=>record('play-resolved'),error=>record('play-rejected',error));return result;};
  record('attached');
  return()=>{record('detached');attached=false;for(const stop of listeners)stop();if(ownPlay)Object.defineProperty(video,'play',ownPlay);else Reflect.deleteProperty(video,'play');};
}
