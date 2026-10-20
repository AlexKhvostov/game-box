<script setup lang="ts">
import { ref, watch, onBeforeUnmount } from 'vue';
import { state } from '../services/game-store';
import { rewardMotion } from '../services/energy-motion';
import { rewardFrame, clamp, ease } from '../domain/reward-motion';
import { telegram } from '../platform/telegram';
const canvas=ref<HTMLCanvasElement>(), card=ref<HTMLElement>(), event=ref<{amount:number;after:number}|null>(null);
let frame=0, owner='', balance=0, live=false, started=0;
let from={x:0,y:0}, to={x:0,y:0}, width=230, reduced=false;
const queue:{owner:string;amount:number;after:number}[]=[];
function cancel() { cancelAnimationFrame(frame); queue.length=0; event.value=null; rewardMotion.held=0; rewardMotion.revealed=0; rewardMotion.active=false; }
function start() {
  const next=queue.shift(); if(!next) { rewardMotion.active=false; return; }
  if(document.hidden||telegram()?.isActive===false||next.owner!==state.profile?.id) { rewardMotion.held-=next.amount; start(); return; }
  event.value=next; rewardMotion.active=true; reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const source=(document.querySelector('.bonus-orb')??document.querySelector('.window-body')??document.querySelector('.game-field'))?.getBoundingClientRect(), target=document.querySelector('.energy-capsule')?.getBoundingClientRect();
  width=Math.min(230,(source?.width??window.innerWidth)*.86,window.innerWidth-40);
  from={x:Math.max(width/2+16,Math.min(window.innerWidth-width/2-16,source?source.x+source.width/2:window.innerWidth/2)),y:Math.max(104,Math.min(window.innerHeight-104,source?source.y+source.height/2:window.innerHeight/2))};
  to={x:target?target.x+target.width/2:60,y:target?target.y+target.height/2:40};
  started=performance.now(); frame=requestAnimationFrame(tick);
}
function glow(c:CanvasRenderingContext2D,x:number,y:number,w:number,h:number,colors:[number,string][],opacity:number) {
  if(opacity<=0)return;c.save();c.globalAlpha=opacity;c.translate(x,y);c.scale(w/2,h/2);const g=c.createRadialGradient(0,0,0,0,0,1);for(const[at,color]of colors)g.addColorStop(at,color);c.fillStyle=g;c.beginPath();c.arc(0,0,1,0,Math.PI*2);c.fill();c.restore();
}
function tick(stamp:number) {
  if(!event.value)return;
  const p=clamp((stamp-started)/(reduced?180:1600)),f=rewardFrame(p,reduced);
  const x=from.x+(to.x-from.x)*f.fly,y=from.y+(to.y-from.y)*f.fly-(reduced?0:Math.sin(Math.PI*f.flight)*30);
  if(card.value){card.value.style.width=`${width}px`;card.value.style.transform=`translate(${x-width/2}px,${y-93}px) scale(${f.scale})`;card.value.style.opacity=String(f.opacity);}
  rewardMotion.revealed=Math.round(event.value.amount*f.roll);
  if(canvas.value){const c=canvas.value.getContext('2d')!,dpr=Math.min(devicePixelRatio,2);const w=window.innerWidth,h=window.innerHeight;if(canvas.value.width!==Math.round(w*dpr)||canvas.value.height!==Math.round(h*dpr)){canvas.value.width=Math.round(w*dpr);canvas.value.height=Math.round(h*dpr);}c.setTransform(dpr,0,0,dpr,0,0);c.clearRect(0,0,w,h);
    if(!reduced){const celebration=clamp(p/.6),shine=Math.sin(Math.PI*celebration),aura=.7+ease(celebration)*.5,flash=clamp((p-.04)/.27),wave=clamp((p-.08)/.32),flashSize=130*(.35+ease(flash)*1.15);
      glow(c,from.x,from.y,width*1.45*aura,width*1.35*aura,[[0,'#04223bf5'],[.26,'#04223bea'],[.47,'#ffdc3233'],[.7,'#00000000']],clamp(p/.1)*(1-clamp((p-.4)/.22)));
      glow(c,from.x,from.y-18,flashSize,flashSize,[[0,'#fffde6'],[.15,'#fff8ab99'],[.4,'#ffd52c44'],[.7,'#00000000']],Math.sin(Math.PI*flash)*.75);
      c.save();c.translate(from.x,from.y-18);c.rotate(p*18*Math.PI/180);c.globalAlpha=shine*.3;const g=c.createRadialGradient(0,0,0,0,0,130);for(const[at,color]of [[.14,'#00000000'],[.18,'#ffe67caa'],[.45,'#ffe67c5a'],[.7,'#00000000']] as [number,string][])g.addColorStop(at,color);c.fillStyle=g;for(let i=0;i<8;i++){c.beginPath();c.moveTo(0,0);c.arc(0,0,130,(-90+6+i*45)*Math.PI/180,(-90+12+i*45)*Math.PI/180);c.closePath();c.fill();}c.restore();
      c.save();c.globalAlpha=Math.sin(Math.PI*wave)*.55;c.strokeStyle='#fff3a4';c.lineWidth=.3+ease(wave)*1.5;c.beginPath();c.arc(from.x,from.y-18,65*c.lineWidth,0,Math.PI*2);c.stroke();c.restore();
      for(let i=0;i<28;i++){const t=clamp((p-.055-(i%4)*.012)/.46);if(t<=0||t>=1)continue;const a=i*2.399963,r=45+(25+i%5*12)*ease(t);c.save();c.globalAlpha=Math.min(1,t*12,(1-t)*4);c.translate(from.x+Math.cos(a)*r,from.y-18+Math.sin(a)*r+t*t*18);c.rotate((i*25+t*45)*Math.PI/180);c.scale(1-t*.5,1-t*.5);c.fillStyle=(i+12)%3===0?'#a3f8ff':'#fff2a0';if(i%3===0){c.beginPath();for(const [j,k]of [[0,-4],[.88,-.96],[4,0],[.88,.96],[0,4],[-.96,.96],[-4,0],[-.96,-.96]])c.lineTo(j!,k!);c.closePath();c.fill();}else{c.beginPath();c.arc(0,0,1.5,0,Math.PI*2);c.fill();}c.restore();}
      glow(c,to.x,to.y,76,54,[[0,'#ffeb6d60'],[1,'#00000000']],f.hit);
      for(let i=0;i<6;i++){const t=clamp((p-.4-i*.012)/.34);if(t<=0||t>=1)continue;const v=t*t*(3-2*t),cx=from.x+(i%2?1:-1)*(20+i*4),cy=from.y-60-i*4;const xx=from.x*(1-v)**2+cx*2*(1-v)*v+to.x*v*v,yy=from.y*(1-v)**2+cy*2*(1-v)*v+to.y*v*v;c.save();c.globalAlpha=Math.min(1,t*12,(1-t)*10);c.fillStyle='#fff596';c.translate(xx,yy);c.scale(.55+Math.sin(Math.PI*t)*.65,.55+Math.sin(Math.PI*t)*.65);if(i%3===0){c.beginPath();for(const [j,k]of [[2,-12],[-9,1],[-2,1],[-4,12],[9,-3],[1,-3]])c.lineTo(j!,k!);c.closePath();c.fill();}else{c.beginPath();c.arc(0,0,2.5,0,Math.PI*2);c.fill();}c.restore();}
    }
  }
  if(p<1)frame=requestAnimationFrame(tick);else{rewardMotion.held-=event.value.amount;rewardMotion.revealed=0;event.value=null;start();}
}
watch(()=>state.profile,p=>{const wasLive=live,oldOwner=owner,before=balance;owner=p?.id??'';balance=p?.wallet.energy??0;live=!!p;if(oldOwner!==owner){cancel();return;}if(wasLive&&live&&balance>before){const amount=balance-before;rewardMotion.held+=amount;queue.push({owner,amount,after:balance});if(!event.value)start();}},{flush:'sync',immediate:true});
const hidden=()=>{if(document.hidden)cancel();};document.addEventListener('visibilitychange',hidden);window.addEventListener('resize',cancel);
telegram()?.onEvent('deactivated',cancel);telegram()?.onEvent('viewportChanged',cancel);
onBeforeUnmount(()=>{cancel();document.removeEventListener('visibilitychange',hidden);window.removeEventListener('resize',cancel);telegram()?.offEvent('deactivated',cancel);telegram()?.offEvent('viewportChanged',cancel);});
</script>
<template><Teleport to="body"><div v-if="event" class="energy-reward-overlay" role="status" :aria-label="state.locale==='ru'?`Получено ${event.amount} энергии. Баланс ${event.after}`:`Received ${event.amount} energy. Balance ${event.after}`"><canvas ref="canvas"/><div ref="card" class="energy-reward-card" aria-hidden="true"><span>{{ state.locale==='ru'?'Энергия получена!':'Energy received!' }}</span><img src="/assets/branding/ui/energy-reward-core.svg" alt=""><strong :style="{fontSize:`${Math.min(56,(width-72)/(String(event.amount).length+1)/.75)}px`}">+{{ event.amount }}</strong><small>{{ state.locale==='ru'?'энергии':'energy' }}</small></div></div></Teleport></template>
