import type {WorldState} from '../domain/kernel';
import {brakeVisual} from './brake-visual';
// Same normalized SVG paths and calm palette as the accepted B01 UI-kit.
const body=new Path2D('M20 70c8-5 14-8 27-8 10 0 15-6 17-16l2-7c2-6 10-6 12 0 4 15-8 32-24 35H20c-3 0-3-2 0-4Z');
const spiral=new Path2D('M39 62c-17 0-21-20-9-28 11-7 24 3 20 13-3 8-14 9-17 2-2-5 4-9 8-5');
const antenna=new Path2D('m69 38 1-13m5 15 6-13');
const gloss=new Path2D('M9 25V20Q9 9 21 9H27Q32 9 28 14L14 28Q9 33 9 25Z');
const bright=(hex:string,amount:number)=>'#'+hex.slice(1).match(/../g)!.map(v=>Math.min(255,Math.round(parseInt(v,16)*amount)).toString(16).padStart(2,'0')).join('');
export function paintBrake(c:CanvasRenderingContext2D,s:WorldState,reduced:boolean,settings:Record<string,unknown>={}){
 const b=s.brake;if(!b||!b.enabled)return;
 const v=brakeVisual(b,s.playing&&!s.dead,reduced,settings),brightness=1+.3*v.flash;
 c.save();c.translate(190-s.player.size/2,190-s.player.size/2);c.scale(s.player.size/100,s.player.size/100);
 if(v.flash>0){c.save();c.globalAlpha=.5*v.flash;c.shadowColor='#a7e9cf';c.shadowBlur=4;c.strokeStyle='#a7e9cf';c.lineWidth=2;c.beginPath();c.roundRect(3.5,3.5,93,93,17.5);c.stroke();c.restore();}
 const fill=c.createLinearGradient(5,5,95,95);fill.addColorStop(0,bright('#194558',brightness*(v.pressing?1.12:1)));fill.addColorStop(1,bright('#103247',brightness*(v.pressing?1.12:1)));c.fillStyle=fill;c.beginPath();c.roundRect(5,5,90,90,16);c.fill();
 c.save();c.globalAlpha=.13;c.fillStyle='#c2e9ef';c.fill(gloss);c.restore();
 c.strokeStyle=bright(v.charged?'#81c6b4':'#52849a',brightness);c.lineWidth=1.6;c.stroke();
 if(!v.charged){
  c.lineCap='round';c.lineWidth=4;c.strokeStyle='#31576cd9';c.beginPath();c.arc(50,47,33,0,Math.PI*2);c.stroke();
  if(b.charge>0){c.strokeStyle='#74c0dc';c.beginPath();c.arc(50,47,33,-Math.PI/2,-Math.PI/2+Math.PI*2*b.charge);c.stroke();}
  c.fillStyle='#cee4ec';c.textAlign='center';c.textBaseline='alphabetic';c.font='600 26px "Segoe UI",Arial,sans-serif';c.fillText(v.timer,50,52);c.font='13px "Segoe UI",Arial,sans-serif';c.fillText('с',50,68);
 }else{
  const mint=c.createLinearGradient(0,22,0,74);mint.addColorStop(0,bright('#b3e9d3',brightness));mint.addColorStop(1,bright('#95dabe',brightness));c.fillStyle=mint;c.fill(body);c.beginPath();c.arc(39,47,20,0,Math.PI*2);c.fill();
  c.strokeStyle='#164450';c.lineWidth=3.6;c.lineCap='round';c.lineJoin='round';c.stroke(spiral);c.strokeStyle=bright('#a5ddc3',brightness);c.lineWidth=2.6;c.stroke(antenna);
  for(const [x,y]of [[70,24],[82,25]]){c.beginPath();c.arc(x!,y!,2.6,0,Math.PI*2);c.fill();}
 }
 if(v.flash>0){c.save();c.globalAlpha=.2*v.flash;c.fillStyle='#d4ffed';c.beginPath();c.roundRect(5,5,90,90,16);c.fill();c.restore();}
 if(v.pressing){c.save();c.globalAlpha=.6;c.strokeStyle='#afdcca';c.lineWidth=1.3;c.beginPath();c.roundRect(3,3,94,94,18);c.stroke();c.restore();}
 c.restore();
 // Existing world-space wave stays below the moving bodies.
 if(s.dead||!s.playing||b.pressAgeMs<0||b.pressAgeMs>840)return;
 c.save();c.strokeStyle='#b0f6d1';
 for(let i=0;i<(reduced?1:3);i++) {const t=(b.pressAgeMs-i*80)/680;if(t<0||t>1)continue;c.globalAlpha=(1-t)*.5;c.lineWidth=2*(1-t)+.5;c.beginPath();c.arc(190,190,reduced?30:12+270*t,0,Math.PI*2);c.stroke();}c.restore();
}
export function paintBrakeHit(c:CanvasRenderingContext2D,s:WorldState,e:{x:number;y:number;w:number;h:number;angle:number},reduced:boolean){
 const b=s.brake;if(!b||!b.enabled||reduced||s.dead||b.pressAgeMs<0||b.pressAgeMs>680)return;
 const radius=12+270*b.pressAgeMs/680,d=Math.hypot(e.x+e.w/2-190,e.y+e.h/2-190);
 if(radius<d||radius>d+55)return;
 c.save();c.globalAlpha=(1-(radius-d)/55)*.8;c.translate(e.x+e.w/2,e.y+e.h/2);c.rotate(e.angle*Math.PI/180);c.strokeStyle='#c4ffe0';c.lineWidth=1.8;c.beginPath();c.roundRect(-e.w/2-1,-e.h/2-1,e.w+2,e.h+2,4);c.stroke();c.restore();
}
