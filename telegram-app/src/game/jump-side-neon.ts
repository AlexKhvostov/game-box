import {createJumpGlowPixels} from './jump-glow.ts';
import {jumpReadyFlash as jumpFlash} from './jump-ready-signal.ts';
export interface JumpSideState {enabled:boolean;ready:boolean;progress:number;readyAgeMs?:number|null;reduced?:boolean}
interface SidePlacement {x:number;y:number;size:number;jump:JumpSideState;reduced?:boolean}

export function jumpSideNeonStyle({enabled,ready,progress,readyAgeMs=null,reduced=false}:JumpSideState){
  const flash=enabled&&ready?Math.min(1,jumpFlash(readyAgeMs,reduced)*1.65):0;
  return {phase:!enabled?'off':!ready?'charging':flash>0?'pulse':'ready',
    progress:enabled?(ready?1:Math.max(0,Math.min(1,Number.isFinite(progress)?progress:0))):0,
    flash,lit:enabled&&ready,fill:ready?'#e8ff69':'#f4ffff'};
}
let draw:ReturnType<typeof createDrawer>|undefined;
function createDrawer(){
  const source=createJumpGlowPixels(256,{radius:.1});
  const texture=(rgb:number[],gain:number)=>{const cv=document.createElement('canvas');cv.width=cv.height=256;const c=cv.getContext('2d')!,im=c.createImageData(256,256);im.data.set(source);for(let n=0;n<im.data.length;n+=4){im.data[n]=rgb[0];im.data[n+1]=rgb[1];im.data[n+2]=rgb[2];im.data[n+3]=Math.min(255,Math.round(im.data[n+3]*gain));}c.putImageData(im,0,0);return cv;};
  const white=texture([244,255,255],1.05),neon=texture([232,255,105],1.3);
  const buffer=document.createElement('canvas');buffer.width=buffer.height=256;const bc=buffer.getContext('2d')!;
  return (c:CanvasRenderingContext2D,{x,y,size,jump,reduced=false}:SidePlacement)=>{
    const s=jumpSideNeonStyle({...jump,reduced});if(s.phase==='off')return;
    c.save();c.beginPath();c.roundRect(x,y,size,size,size*.1);c.clip();
    if(!jump.ready){
      bc.clearRect(0,0,256,256);bc.globalCompositeOperation='source-over';bc.drawImage(white,0,0);
      const cut=256*(1-s.progress),mask=bc.createLinearGradient(0,cut,0,cut+22);mask.addColorStop(0,'#0000');mask.addColorStop(1,'#000');
      bc.globalCompositeOperation='destination-in';bc.fillStyle=mask;bc.fillRect(0,0,256,256);bc.globalCompositeOperation='source-over';
    }
    c.drawImage(jump.ready?neon:buffer,x,y,size,size);c.restore();
  };
}
export function paintJumpSideNeon(c:CanvasRenderingContext2D,options:SidePlacement){draw??=createDrawer();draw(c,options);}

/** One light-bulb flash: a bright outer bloom and soft white illumination. */
export function paintJumpBodyFlash(c:CanvasRenderingContext2D,{x,y,size,jump,reduced=false}:SidePlacement){
  const s=jumpSideNeonStyle({...jump,reduced});if(s.flash<=0)return;
  const k=size/44,f=s.flash;
  c.save();c.globalAlpha*=f*.85;
  c.shadowBlur=18*f*k;c.shadowColor='#e8ff69';c.strokeStyle='#f5ffb5';c.lineWidth=(2+f*4)*k;
  c.beginPath();c.roundRect(x-1.5*k,y-1.5*k,size+3*k,size+3*k,size*.1+1.5*k);c.stroke();
  c.shadowBlur=0;c.globalCompositeOperation='screen';
  const light=c.createRadialGradient(x+size*.5,y+size*.45,0,x+size*.5,y+size*.45,size*.7);
  light.addColorStop(0,'rgba(255,255,240,.55)');light.addColorStop(.65,'rgba(255,255,238,.12)');light.addColorStop(1,'rgba(255,255,238,0)');
  c.fillStyle=light;c.beginPath();c.roundRect(x,y,size,size,size*.1);c.fill();c.restore();
}
