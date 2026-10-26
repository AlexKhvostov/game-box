import {jumpReadyFlash as jumpFlash} from './jump-ready-signal.ts';
export interface JumpBarState {enabled:boolean;ready:boolean;progress:number;readyAgeMs?:number|null;reduced?:boolean}
export function jumpBarStyle({enabled,ready,progress,readyAgeMs=null,reduced=false}:JumpBarState){
  const p=ready?1:Math.max(0,Math.min(1,Number.isFinite(progress)?progress:0));
  const flash=enabled&&ready?Math.min(1,jumpFlash(readyAgeMs,reduced)*1.65):0;
  return {phase:!enabled?'off':!ready?'charging':flash>0?'pulse':'ready',progress:enabled?p:0,flash,
    fill:ready?(flash>.01?'#ffffeb':'#edff37'):'#a3933c',core:ready?(flash>0?'#ffffff':'#fdffd1'):null,glow:ready?1.8+flash*4.5:0,burst:enabled&&ready?flash*14:0};
}
export function paintJumpChargeBar(c:CanvasRenderingContext2D,{x,y,size,jump,reduced=false}:{x:number;y:number;size:number;jump:JumpBarState;reduced?:boolean}){
  const style=jumpBarStyle({...jump,reduced});if(style.phase==='off')return;
  // Proportions measured from the approved picture B, including its glass wall.
  const k=size/44,w=size*.78,h=size*.115,bx=x+(size-w)/2,by=y+size*.84;
  const pill=(px:number,py:number,pw:number,ph:number)=>{c.beginPath();c.roundRect(px,py,pw,ph,ph/2);};
  const gradient=(py:number,ph:number,stops:[number,string][])=>{const g=c.createLinearGradient(0,py,0,py+ph);for(const [p,color]of stops)g.addColorStop(p,color);return g;};
  c.save();
  // A single broad light spill outside the glass, separate from its inner glow.
  if(style.burst>0){
    c.save();c.globalCompositeOperation='lighter';c.translate(bx+w/2,by+h/2);
    c.scale(w/2+14*k,h/2+14*k);
    const halo=c.createRadialGradient(0,0,0,0,0,1),f=style.flash;
    halo.addColorStop(0,`rgba(255,255,220,${.78*f})`);halo.addColorStop(.25,`rgba(255,255,160,${.5*f})`);
    halo.addColorStop(.5,`rgba(244,255,70,${.28*f})`);halo.addColorStop(.75,`rgba(232,255,31,${.12*f})`);halo.addColorStop(1,'rgba(232,255,31,0)');
    c.fillStyle=halo;c.fillRect(-1,-1,2,2);c.restore();
  }
  // Soft grounding shadow and, only when ready, a warm neon halo.
  c.shadowColor=jump.ready?style.fill:'#001f20';c.shadowBlur=(jump.ready?style.glow:.5)*k;
  c.fillStyle=jump.ready?'#dfff724d':'#001c2470';pill(bx,by+.35*k,w,h);c.fill();c.shadowBlur=0;
  // The outer glass sleeve has a lit lip, a shaded underside and a clear edge.
  c.fillStyle=gradient(by,h,[[0,'#4c9c8c'],[.12,'#c1f7dd'],[.27,'#7ec4ac'],[.5,'#315e52'],[.78,'#315e52'],[1,'#a5d9b7']]);
  pill(bx,by,w,h);c.fill();c.lineWidth=.32*k;c.strokeStyle='#b9ffe0';c.stroke();
  const inset=.63*k,ix=bx+inset,iy=by+inset,iw=w-2*inset,ih=h-2*inset;
  c.fillStyle=gradient(iy,ih,[[0,'#0b3028'],[.26,'#1b3f2d'],[.7,'#21452f'],[1,'#46654a']]);
  pill(ix,iy,iw,ih);c.fill();c.lineWidth=.42*k;c.strokeStyle='#153c31';c.stroke();
  // Liquid stays dimensional even at half charge; the empty chamber stays dark.
  c.save();pill(ix+.2*k,iy+.18*k,iw-.4*k,ih-.36*k);c.clip();
  if(style.progress>0){
    const fill:[number,string][]=jump.ready?[[0,'#fdffc5'],[.2,'#f2ff70'],[.48,'#d9f908'],[.76,'#e8ff36'],[1,'#fbff9b']]:[[0,'#c2b36b'],[.25,'#a59543'],[.52,'#8f7f2c'],[.76,'#a39239'],[1,'#c7b46a']];
    c.fillStyle=gradient(iy,ih,fill);c.fillRect(ix,iy,iw*style.progress,ih);
    if(!jump.ready&&style.progress<1){c.strokeStyle='#d8cd878c';c.lineWidth=.35*k;c.beginPath();c.moveTo(ix+iw*style.progress,iy);c.lineTo(ix+iw*style.progress,iy+ih);c.stroke();}
    if(style.flash>0){const alpha=c.globalAlpha;c.globalAlpha*=style.flash*.95;c.fillStyle=style.core??'#ffffff';c.fillRect(ix,iy,iw,ih);c.globalAlpha=alpha;}
  }
  // Reflections belong to the glass, so they remain visible over the empty half.
  c.strokeStyle='#e9ffdf70';c.lineWidth=.48*k;c.beginPath();c.moveTo(ix+ih/2,iy+.55*k);c.lineTo(ix+iw-ih/2,iy+.55*k);c.stroke();
  c.restore();
  c.strokeStyle='#72d7ad99';c.lineWidth=.3*k;c.beginPath();c.moveTo(bx+h/2,by+h-.35*k);c.lineTo(bx+w-h/2,by+h-.35*k);c.stroke();
  c.restore();
}
