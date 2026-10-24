import type {WorldState} from '../domain/kernel';
import type {ImpactEffect} from './impact';
export const helmetDim='#4D879B',helmetBright='#A4EFFF';
export function helmetFlash(s:WorldState,reduced=false) {
  const age=s.helmetCharge?.readyAgeMs;
  return reduced||!s.helmet||age==null||age<0||age>=420?0:Math.sin(Math.PI*age/420);
}
// Clockwise rounded contour, starting at the middle of the top edge.
function rim(c:CanvasRenderingContext2D,x:number,y:number,size:number,r:number) {
  r=Math.min(r,size/2);c.beginPath();c.moveTo(x+size/2,y);c.lineTo(x+size-r,y);
  c.arcTo(x+size,y,x+size,y+r,r);c.lineTo(x+size,y+size-r);
  c.arcTo(x+size,y+size,x+size-r,y+size,r);c.lineTo(x+r,y+size);
  c.arcTo(x,y+size,x,y+size-r,r);c.lineTo(x,y+r);
  c.arcTo(x,y,x+r,y,r);c.lineTo(x+size/2,y);
  return 4*(size-2*r)+2*Math.PI*r;
}
export function paintHelmet(c:CanvasRenderingContext2D,s:WorldState,x:number,y:number,size:number,reduced=false) {
  const charge=s.helmetCharge;if(!charge?.equipped)return;
  c.save();const f=helmetFlash(s,reduced),length=rim(c,x-2.5,y-2.5,size+5,6.5);
  if(s.helmet){
    c.strokeStyle=f>.01?`rgb(${164+Math.round(73*f)},${239+Math.round(16*f)},255)`:helmetBright;c.lineWidth=2.6+.8*f;c.stroke();
    rim(c,x-5-f,y-5-f,size+10+2*f,9+f);c.strokeStyle=helmetBright;c.globalAlpha*=.48+.45*f;c.lineWidth=1.2;c.stroke();
  }else{
    c.strokeStyle=helmetDim;c.lineWidth=1.2;c.globalAlpha*=.25;c.stroke();c.globalAlpha/=.25;
    const p=Math.max(0,Math.min(1,charge.progress));
    if(p>0){c.setLineDash([length*p,length+1]);c.lineWidth=2.2;c.lineCap='round';c.stroke();}
  }c.restore();
}
// The same six small cyan pieces and .4 s fade as Android HelmetShatter.
export class HelmetShatter implements ImpactEffect {
  age=0;private x:number;private y:number;private size:number;
  constructor(s:WorldState){const p=s.player;this.size=p.size*p.visualScale;this.x=p.x+p.size/2;this.y=p.y+p.size/2-p.jumpLift*8;}
  update(dt:number){this.age+=dt;return this.age<.4;}
  paint(c:CanvasRenderingContext2D,reduced=false){
    const t=Math.min(1,this.age/.4);if(t>=1)return;const k=this.size/44,travel=(reduced?1:2+7*t)*k;
    const pieces=[[-.48,-.48,-1,-1],[.48,-.48,1,-1],[.48,.48,1,1],[-.48,.48,-1,1],[-.55,0,-1,0],[.55,0,1,0]];
    c.save();c.globalAlpha*=1-t;c.strokeStyle=helmetBright;c.lineWidth=1.8*k;c.lineCap='round';c.lineJoin='round';
    pieces.forEach((q,i)=>{c.save();c.translate(this.x+q[0]!*this.size+q[2]!*travel,this.y+q[1]!*this.size+q[3]!*travel);c.rotate((i<4?i*Math.PI/2:Math.PI/2)+(reduced?0:(i%2?1:-1)*t*.3));c.beginPath();
      if(i<4){c.moveTo(0,8*k);c.lineTo(0,0);c.quadraticCurveTo(0,-2*k,2*k,-2*k);c.lineTo(9*k,-2*k);}else{c.moveTo(-4*k,0);c.lineTo(4*k,0);}c.stroke();c.restore();});c.restore();
  }
}
