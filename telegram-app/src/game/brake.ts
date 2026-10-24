import type {WorldState} from '../domain/kernel';
// Approved UI-kit paths, drawn below bodies in the same Canvas coordinate system.
const body=new Path2D('M23 63h21c10 0 17-4 18-14l1-10c.4-6 9-7 11-1 4 13-4 29-17 32H23c-8 0-8-7 0-7Z');
const spiral=new Path2D('M39 60c-15 0-19-17-9-24 9-7 21 1 18 10-2 7-12 8-14 2-1-4 4-7 7-4');
const antenna=new Path2D('m65 34-3-9m9 9 5-10');
const rim=new Path2D('M50 8H80Q92 8 92 20V80Q92 92 80 92H20Q8 92 8 80V20Q8 8 20 8Z');
export function paintBrake(c:CanvasRenderingContext2D,s:WorldState,reduced:boolean){
 const b=s.brake;if(!b||!b.enabled)return;
 const pressing=s.playing&&b.pressAgeMs>=0&&b.pressAgeMs<120;
 const opacity=pressing?1-b.pressAgeMs/120:b.charge,q=pressing?1:b.charge,ready=b.ready,flash=ready&&b.readyAgeMs<320&&!reduced?Math.sin(b.readyAgeMs/320*Math.PI):0;
 c.save();c.translate(190-s.player.size/2,190-s.player.size/2);c.scale(s.player.size/100,s.player.size/100);c.globalAlpha=opacity;
 if(ready){c.fillStyle='#00000070';c.beginPath();c.roundRect(8,16,84,80,12);c.fill();c.fillStyle='#092331';c.beginPath();c.roundRect(8,12,84,82,12);c.fill();}
 c.translate(0,pressing?2:ready?-4:0);c.beginPath();c.roundRect(8,8,84,84,12);c.save();c.clip();
 const base=c.createLinearGradient(8,8,92,92);base.addColorStop(0,'#0b293b');base.addColorStop(1,'#071f31');c.fillStyle=base;c.fillRect(8,8,84,84);
 if(q>0){c.beginPath();c.moveTo(50,50);c.arc(50,50,72,-Math.PI/2,-Math.PI/2+Math.PI*2*q);c.closePath();const fill=c.createLinearGradient(8,8,92,92);fill.addColorStop(0,ready?'#1c4857':'#153b4d');fill.addColorStop(1,ready?'#0d2e40':'#0c2b3f');c.fillStyle=fill;c.fill();}c.restore();
 c.strokeStyle=ready?'#9bc8ad':'#5e7985';c.lineWidth=2;c.stroke(rim);c.strokeStyle=ready?'#bde9cb':'#8ea9b1';c.setLineDash([352*q,352]);c.stroke(rim);c.setLineDash([]);
 if(flash){c.fillStyle=`rgba(185,255,213,${flash*.36})`;c.beginPath();c.roundRect(8,8,84,84,12);c.fill();}
 c.globalAlpha=opacity*(ready||pressing?1:.72);c.fillStyle=ready||pressing?'#e7f5ef':'#96a1a6';c.strokeStyle=ready?'#31515b':'#50616c';c.lineWidth=3.1;c.lineCap='round';c.lineJoin='round';c.fill(body);c.stroke(body);c.beginPath();c.arc(39,47,18,0,Math.PI*2);c.fill();c.stroke();c.strokeStyle=ready?'#234c59':'#50616c';c.stroke(spiral);c.stroke(antenna);for(const [x,y]of [[62,23],[77,22]]){c.beginPath();c.arc(x!,y!,1.5,0,Math.PI*2);c.fill();}
 c.restore();
 // Independent wave: the plate itself can already be transparent.
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
