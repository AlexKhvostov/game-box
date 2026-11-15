import {paintConfetti} from './confetti.mjs';

const defaultAssets={
  'celebration.mp4':new URL('./assets/celebration.mp4',import.meta.url).href,
  'poster.png':new URL('./assets/poster.png',import.meta.url).href,
  'final-frame.png':new URL('./assets/final-frame.png',import.meta.url).href,
  'shields/level-1.svg':new URL('./assets/shields/level-1.svg',import.meta.url).href,
  'shields/level-2.svg':new URL('./assets/shields/level-2.svg',import.meta.url).href,
  'shields/level-3.svg':new URL('./assets/shields/level-3.svg',import.meta.url).href,
  'shields/level-4.svg':new URL('./assets/shields/level-4.svg',import.meta.url).href,
  'shields/level-5.svg':new URL('./assets/shields/level-5.svg',import.meta.url).href,
  'shields/level-6.svg':new URL('./assets/shields/level-6.svg',import.meta.url).href,
  'shields/level-7.svg':new URL('./assets/shields/level-7.svg',import.meta.url).href,
};
export function checkedLevel(value){
  if(!Number.isInteger(value)||value<1||value>7)throw new RangeError('Level Up expects an integer level from 1 to 7.');
  return value;
}

// Some PNG decoders resolve decode() after recovering only the received rows.
// Validate every complete PNG chunk/CRC and IEND before exposing a local blob.
const crcTable=Uint32Array.from({length:256},(_,n)=>{let c=n;for(let i=0;i<8;i++)c=c&1?0xedb88320^(c>>>1):c>>>1;return c>>>0;});
function completePng(buffer){
  const b=new Uint8Array(buffer),v=new DataView(buffer);if(b.length<20||[137,80,78,71,13,10,26,10].some((n,i)=>b[i]!==n))return false;
  let offset=8,header=false,data=false;
  while(offset+12<=b.length){const length=v.getUint32(offset),end=offset+8+length;if(end+4>b.length)return false;let crc=0xffffffff;for(let i=offset+4;i<end;i++)crc=crcTable[(crc^b[i])&255]^(crc>>>8);if(((crc^0xffffffff)>>>0)!==v.getUint32(end))return false;
    const type=String.fromCharCode(...b.subarray(offset+4,offset+8));if(!header&&(type!=='IHDR'||length!==13))return false;header=true;if(type==='IDAT')data=true;if(type==='IEND')return length===0&&data&&end+4===b.length;offset=end+4;
  }return false;
}

/** Accepted V6 scene. One MP4 for every level; the original SVG is independent. */
export class LevelUpAnimation{
  constructor(host,{level=3,autoplay=true,muted=true,locale='ru',assetBase,onPhaseChange,reduced=matchMedia('(prefers-reduced-motion: reduce)').matches,onComplete}={}){
    this.locale=locale==='en'?'en':'ru';this.watchdog=0;this.playRequested=false;this.progressTime=0;this.plates={poster:{state:'loading',attempts:0},final:{state:'loading',attempts:0}};this.plateLoads=new Set();this.blobs=new Set();
    this.assetBase=assetBase?new URL(assetBase,import.meta.url):null;this.onPhaseChange=onPhaseChange;
    this.level=checkedLevel(level);this.host=host;this.reduced=reduced;this.onComplete=onComplete;
    this.events=new AbortController();this.raf=0;this.endedAt=0;this.destroyed=false;this.manualFinal=false;this.completed=false;
    host.innerHTML=`<div class="lu-stage" data-levelup-stage data-phase="ready">
      <video playsinline preload="${autoplay?'auto':'none'}" aria-label="Праздничная анимация повышения уровня"></video>
      <img class="lu-final" alt="" hidden>
      <canvas class="lu-confetti" width="768" height="960" aria-hidden="true"></canvas>
      <div class="lu-shield" aria-hidden="true"><span class="lu-shield-rays" aria-hidden="true"><span class="lu-ray-band lu-ray-band--wide"></span><span class="lu-ray-band lu-ray-band--medium"></span><span class="lu-ray-band lu-ray-band--fine"></span></span><img data-levelup-badge alt=""></div>
      <span class="lu-media-notice" data-levelup-media-status role="status"></span>
      <span class="lu-screen-reader" role="status" data-levelup-status></span>
    </div>`;
    this.stage=host.firstElementChild;this.video=this.stage.querySelector('video');this.still=this.stage.querySelector('.lu-final');
    this.shield=this.stage.querySelector('.lu-shield');this.badge=this.shield.querySelector('img');this.status=this.stage.querySelector('[data-levelup-status]');
    this.notice=this.stage.querySelector('.lu-media-notice');
    this.canvas=this.stage.querySelector('canvas');this.context=this.canvas.getContext('2d');
    this.video.muted=muted;this.video.src=this.asset('celebration.mp4');this.setLevel(level);
    void this.loadPlate('poster','poster.png');void this.loadPlate('final','final-frame.png');
    const listen=(target,event,handler)=>target.addEventListener(event,handler,{signal:this.events.signal});
    for(const event of ['loadedmetadata','timeupdate','seeked','play','pause','ended'])listen(this.video,event,()=>this.sync());
    listen(this.video,'loadedmetadata',()=>{this.canvas.width=this.video.videoWidth||768;this.canvas.height=this.video.videoHeight||960;});
    listen(this.video,'play',()=>this.startFrames());
    listen(this.video,'pause',()=>{if(!this.video.paused)return;const unexpected=this.playRequested&&!this.finished()&&!document.hidden;this.playRequested=false;this.clearWatchdog();if(unexpected)this.finish({animate:false});else if(!this.finished())this.clearParticles();});
    listen(this.video,'timeupdate',()=>{if(this.video.currentTime>this.progressTime+.001){this.progressTime=this.video.currentTime;this.armWatchdog();}});
    listen(this.video,'ended',()=>{this.playRequested=false;this.clearWatchdog();this.startFrames();if(!this.completed){this.completed=true;this.onComplete?.({level:this.level});}});
    listen(this.video,'error',()=>this.finish({animate:false}));
    listen(document,'visibilitychange',()=>{
      this.stage.classList.toggle('suspended',document.hidden);
      if(document.hidden){this.resumeOnVisible=!this.video.paused&&!this.video.ended;this.pause();for(const plate of Object.values(this.plates))if(plate.state==='loading')plate.state='suspended';for(const controller of this.plateLoads)controller.abort();}
      else{this.resumePlates();if(this.resumeOnVisible){this.resumeOnVisible=false;this.playRequested=true;this.armWatchdog();this.video.play().catch(()=>this.finish({animate:false}));}}
    });
    if(autoplay)this.play();else this.sync();
  }
  clearWatchdog(){clearTimeout(this.watchdog);this.watchdog=0;}
  armWatchdog(){this.clearWatchdog();if(this.destroyed||this.manualFinal||!this.playRequested||document.hidden)return;this.watchdog=setTimeout(()=>{this.watchdog=0;this.finish({animate:false});},8000);}
  resumePlates(){if(this.destroyed||document.hidden)return;for(const[key,name]of[['poster','poster.png'],['final','final-frame.png']])if(this.plates[key].state==='suspended')void this.loadPlate(key,name);}
  async loadPlate(key,name){
    const plate=this.plates[key];if(this.destroyed||plate.loading||plate.state==='ready'||plate.state==='failed')return;
    if(document.hidden){plate.state='suspended';this.updatePlate();return;}
    plate.loading=true;plate.state='loading';
    try{while(plate.attempts<2&&!this.destroyed){
      if(document.hidden){plate.state='suspended';break;}const attempt=plate.attempts++;
      const controller=new AbortController();this.plateLoads.add(controller);const timer=setTimeout(()=>controller.abort(),8000);let objectUrl='',image;
      try{
        const url=new URL(this.asset(name));if(attempt)url.searchParams.set('lu-image-retry','1');
        const response=await fetch(url,{signal:controller.signal,cache:attempt?'reload':'default'});if(!response.ok)throw Error('image_unavailable');
        const blob=await response.blob();if(!completePng(await blob.arrayBuffer()))throw Error('image_unavailable');if(controller.signal.aborted)throw Error('image_unavailable');objectUrl=URL.createObjectURL(blob);image=new Image();
        controller.signal.addEventListener('abort',()=>{image.src='';},{once:true});image.src=objectUrl;await image.decode();
        if(this.destroyed||controller.signal.aborted)throw Error('image_unavailable');this.blobs.add(objectUrl);plate.state='ready';plate.url=objectUrl;objectUrl='';
        if(key==='poster')this.video.poster=this.plates.poster.url;this.updatePlate();return;
      }catch{if(objectUrl)URL.revokeObjectURL(objectUrl);if(this.destroyed)break;if(document.hidden||plate.state==='suspended'){plate.state='suspended';break;}}
      finally{clearTimeout(timer);this.plateLoads.delete(controller);}
    }
    if(!this.destroyed){if(plate.state!=='suspended'||plate.attempts>=2)plate.state='failed';this.updatePlate();}
    }finally{plate.loading=false;if(!this.destroyed&&!document.hidden&&plate.state==='suspended')this.resumePlates();}
  }
  setLocale(locale){this.locale=locale==='en'?'en':'ru';this.updatePlate();}
  updatePlate(){
    if(this.destroyed)return;const plate=this.plates.final.state==='ready'?this.plates.final:this.plates.poster.state==='ready'?this.plates.poster:null;
    if(this.manualFinal){this.still.hidden=!plate;if(plate&&this.still.src!==plate.url)this.still.src=plate.url;}
    const visible=this.manualFinal?this.plates.final.state!=='ready':this.video.readyState<2&&this.plates.poster.state!=='ready';
    if(this.notice.hidden!==!visible)this.notice.hidden=!visible;const failed=this.plates.final.state==='failed'&&(this.manualFinal||this.plates.poster.state==='failed');
    const message=this.locale==='en'?(failed?'Animation unavailable':'Loading animation…'):(failed?'Анимация недоступна':'Загружаем анимацию…');
    if(this.notice.textContent!==message)this.notice.textContent=message;
    if(this.stage.dataset.finalImage!==this.plates.final.state)this.stage.dataset.finalImage=this.plates.final.state;if(this.stage.dataset.posterImage!==this.plates.poster.state)this.stage.dataset.posterImage=this.plates.poster.state;
  }
  asset(name){return this.assetBase?new URL(name,this.assetBase).href:defaultAssets[name];}
  setMuted(value){if(!this.destroyed)this.video.muted=Boolean(value);}
  finished(){return this.manualFinal||this.video.ended;}
  setLevel(level){
    this.level=checkedLevel(level);
    this.badge.src=this.asset(`shields/level-${level}.svg`);
    this.badge.alt=`Уровень ${level}`;this.stage.dataset.level=String(level);this.status.textContent=`Новый уровень: ${level}`;
  }
  sync(){
    if(this.destroyed)return;this.updatePlate();
    const done=this.finished(),show=done||this.video.currentTime>=2;
    this.shield.classList.toggle('arrived',show);this.shield.classList.toggle('rays-stopped',done||this.video.paused);
    this.shield.setAttribute('aria-hidden',String(!show));
    const phase=done?'complete':this.video.paused?'paused':show?'rank':'intro';
    if(this.stage.dataset.phase!==phase){this.stage.dataset.phase=phase;this.onPhaseChange?.({phase,level:this.level});}
  }
  clearParticles(){
    cancelAnimationFrame(this.raf);this.raf=0;this.context.clearRect(0,0,this.canvas.width,this.canvas.height);this.canvas.dataset.active='false';
  }
  tick(now){
    this.raf=0;if(this.destroyed||document.hidden||this.reduced)return this.clearParticles();
    this.sync();let time=this.video.currentTime,alpha=1;
    if(this.finished()){
      if(!this.endedAt)this.endedAt=now;const tail=(now-this.endedAt)/1000;
      if(tail>=2.4)return this.clearParticles();
      time=(Number.isFinite(this.video.duration)?this.video.duration:5.175)+tail;alpha=tail<=1.6?1:Math.max(0,1-(tail-1.6)/.8);
    }else if(this.video.paused)return this.clearParticles();
    paintConfetti(this.context,time,this.canvas.width,this.canvas.height);this.canvas.style.opacity=String(alpha);
    this.canvas.dataset.active='true';this.canvas.dataset.time=time.toFixed(3);this.raf=requestAnimationFrame(t=>this.tick(t));
  }
  startFrames(){if(this.destroyed||this.reduced||document.hidden)return;cancelAnimationFrame(this.raf);this.raf=requestAnimationFrame(t=>this.tick(t));}
  play(){
    if(this.destroyed)return;
    if(this.reduced){this.finish({animate:false});return;}
    this.clearParticles();this.manualFinal=false;this.playRequested=true;this.progressTime=0;this.completed=false;this.endedAt=0;this.still.hidden=true;this.stage.classList.remove('is-static','is-final');
    this.shield.classList.remove('arrived');this.video.currentTime=0;this.sync();
    this.armWatchdog();this.video.play().catch(()=>{if(!this.destroyed)this.finish({animate:false});});
  }
  pause(){this.playRequested=false;this.clearWatchdog();this.video.pause();this.clearParticles();this.sync();}
  finish({animate=true}={}){
    if(this.destroyed)return;
    this.playRequested=false;this.resumeOnVisible=false;this.clearWatchdog();this.manualFinal=true;this.video.pause();this.stage.classList.add('is-final');this.updatePlate();this.stage.classList.toggle('is-static',!animate||this.reduced);this.clearParticles();this.sync();
  }
  destroy(){
    if(this.destroyed)return;this.destroyed=true;this.clearWatchdog();for(const controller of this.plateLoads)controller.abort();this.plateLoads.clear();for(const url of this.blobs)URL.revokeObjectURL(url);this.blobs.clear();this.events.abort();this.clearParticles();this.video.pause();
    this.video.removeAttribute('src');this.video.load();this.host.replaceChildren();
  }
}
