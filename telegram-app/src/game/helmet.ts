import type {WorldState} from '../domain/kernel';
import type {ImpactEffect} from './impact';
export const helmetDim='#4D879B',helmetBright='#A4EFFF';
export function helmetFlash(s:WorldState,reduced=false) {
  const age=s.helmetCharge?.readyAgeMs;
  return reduced||!s.helmet||age==null||age<0||age>=420?0:Math.sin(Math.PI*age/420);
}
// Build the charged geometry itself. Canvas dash lengths can scale differently
// from the already transformed path in a mobile WebView.
function rim(c:CanvasRenderingContext2D,x:number,y:number,size:number,r:number,progress=1) {
  r=Math.min(r,size/2);
  let left=(4*(size-2*r)+2*Math.PI*r)*progress,px=x+size/2,py=y;
  c.beginPath();c.moveTo(px,py);
  const line=(tx:number,ty:number)=>{
    const length=Math.hypot(tx-px,ty-py),amount=Math.min(left,length);
    if(amount>0){c.lineTo(px+(tx-px)*amount/length,py+(ty-py)*amount/length);left-=amount;}
    px=tx;py=ty;return left>1e-9;
  };
  const corner=(cx:number,cy:number,start:number)=>{
    const amount=Math.min(left,Math.PI*r/2);
    if(amount>0){c.arc(cx,cy,r,start,start+amount/r);left-=amount;}
    px=cx+r*Math.cos(start+Math.PI/2);py=cy+r*Math.sin(start+Math.PI/2);return left>1e-9;
  };
  if(!line(x+size-r,y)||!corner(x+size-r,y+r,-Math.PI/2))return;
  if(!line(x+size,y+size-r)||!corner(x+size-r,y+size-r,0))return;
  if(!line(x+r,y+size)||!corner(x+r,y+size-r,Math.PI/2))return;
  if(!line(x,y+r)||!corner(x+r,y+r,Math.PI))return;
  line(x+size/2,y);
}
export function paintHelmet(c:CanvasRenderingContext2D,s:WorldState,x:number,y:number,size:number,reduced=false) {
  const charge=s.helmetCharge;if(!charge?.equipped)return;
  const k=size/44,p=s.helmet?1:Math.max(0,Math.min(1,Number.isFinite(charge.progress)?charge.progress:0));
  c.save();c.setLineDash([]);c.lineDashOffset=0;
  const f=helmetFlash(s,reduced);rim(c,x-3.5*k,y-3.5*k,size+7*k,8*k);
  for(const [width,color] of [[4.8,'#05182e'],[3.6,s.helmet?'#4c93b3':'#36536b'],[2.5,'#092439']] as [number,string][]) {
    c.lineWidth=width*k;c.strokeStyle=color;c.stroke();
  }
  if(p>0){
    rim(c,x-3.5*k,y-3.5*k,size+7*k,8*k,p);c.lineCap='round';
    c.shadowColor='#36d9ff';c.shadowBlur=(s.helmet?4+f*2:2.5)*k;
    c.lineWidth=(3.2+f*.6)*k;c.strokeStyle=s.helmet?'#a0f5ff':'#39dbff';c.stroke();
    c.shadowBlur=0;c.lineWidth=(1.05+f*.35)*k;c.strokeStyle=s.helmet?'#edffff':'#b6f8ff';c.stroke();
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
