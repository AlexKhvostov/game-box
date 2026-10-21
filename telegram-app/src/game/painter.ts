import type {ImpactBurst} from './impact';
import type { Body, WorldState } from '../domain/kernel';
import {motionProbe} from './motion-probe';
import {createJumpGlowDrawer, type JumpGlowDrawer} from './jump-glow';
import {jumpGlowProgress} from './jump-glow-progress';
// Direct Canvas translation of GameFieldPainter/paintHeroFace. Geometry comes
// exclusively from the compiled Dart world; visible effects never alter bodies.
function rounded(c: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  r = Math.max(0, Math.min(r, w / 2, h / 2)); c.beginPath(); c.moveTo(x + r, y); c.lineTo(x + w - r, y); c.quadraticCurveTo(x + w, y, x + w, y + r); c.lineTo(x + w, y + h - r); c.quadraticCurveTo(x + w, y + h, x + w - r, y + h); c.lineTo(x + r, y + h); c.quadraticCurveTo(x, y + h, x, y + h - r); c.lineTo(x, y + r); c.quadraticCurveTo(x, y, x + r, y); c.closePath();
}
function ellipse(c: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, fill: string) { c.beginPath(); c.ellipse(x, y, w / 2, h / 2, 0, 0, Math.PI * 2); c.fillStyle = fill; c.fill(); }
function mix(a: string, b: string, t: number) { const channel=(hex:string,i:number)=>parseInt(hex.slice(i,i+2),16);return '#'+[1,3,5].map(i=>Math.round(channel(a,i)+(channel(b,i)-channel(a,i))*t).toString(16).padStart(2,'0')).join(''); }
function enemy(c: CanvasRenderingContext2D, e: Body, fill: string | CanvasGradient, shift = 0, inflate = 0, stroke = false) {
  c.save(); c.translate(e.x + e.w / 2 + shift, e.y + e.h / 2 + shift * 7 / 5.5); c.rotate(e.angle * Math.PI / 180);
  rounded(c, -e.w / 2 - inflate, -e.h / 2 - inflate, e.w + inflate * 2, e.h + inflate * 2, 3 + inflate);
  if (stroke) { c.strokeStyle = fill; c.lineWidth = 1; c.stroke(); } else { c.fillStyle = fill; c.fill(); } c.restore();
}
export class FieldPainter {
  private c: CanvasRenderingContext2D;
  private background: HTMLCanvasElement;
  private jumpGlow: JumpGlowDrawer;
  constructor(private canvas: HTMLCanvasElement) {
    this.c = canvas.getContext('2d', { alpha: false })!;
    this.background = document.createElement('canvas'); this.background.width = 760; this.background.height = 760;
    // Warm the approved artwork before play; no texture work in the frame loop.
    this.jumpGlow = createJumpGlowDrawer({radius: .1});
  }
  configure(config: Record<string, any>) {
    const c = this.background.getContext('2d')!; c.setTransform(2, 0, 0, 2, 0, 0);
    const gradient = c.createRadialGradient(190, 152, 0, 190, 152, 323);
    let base = config.field.colorHex || '#08253B'; if (/^#[a-f0-9]{8}$/i.test(base)) base='#'+base.slice(3);
    const brightness=Math.max(.4,Math.min(1.8,config.field.brightness??1));
    if(brightness>1)base=mix(base,'#ffffff',(brightness-1)/.8);else if(brightness<1)base=mix(base,'#000000',(1-brightness)/.6);
    gradient.addColorStop(0, mix(base,'#168899',.18)); gradient.addColorStop(1, base);
    c.fillStyle = '#061B2D'; c.fillRect(0, 0, 380, 380); rounded(c, 0, 0, 380, 380, config.field.cornerRadius); c.fillStyle = gradient; c.fill();
    c.save(); c.clip(); c.beginPath(); for (let i = 1; i < 12; i++) { const v = 380 * i / 12; c.moveTo(v, 0); c.lineTo(v, 380); c.moveTo(0, v); c.lineTo(380, v); } c.strokeStyle = '#58E2EC16'; c.lineWidth = .7; c.stroke(); c.restore();
    rounded(c, 0, 0, 380, 380, config.field.cornerRadius); c.strokeStyle = '#0000001f'; c.lineWidth = 380 * .08; c.stroke();
  }
  draw(s: WorldState, config: Record<string, any>, frame: number, impacts:ImpactBurst[] = []) {
    const t0=motionProbe.clock();
    const c = this.c, dpr = Math.min(devicePixelRatio || 1, 3), side = this.canvas.clientWidth;
    const pixels = Math.max(1, Math.round(side * dpr)); if (this.canvas.width !== pixels) { this.canvas.width = pixels; this.canvas.height = pixels; }
    const t1=t0?motionProbe.clock():0;
    c.setTransform(pixels / 380, 0, 0, pixels / 380, 0, 0); c.drawImage(this.background, 0, 0, 380, 380);c.save();rounded(c,0,0,380,380,config.field.cornerRadius);c.clip();
    const t2=t0?motionProbe.clock():0;
    const brightness = Math.max(.4, Math.min(2.5, config.field.shadowBrightness ?? 1));
    for (const e of s.enemies) enemy(c, e, `rgba(0,0,0,${Math.min(.85, .42 / brightness)})`, 5.5);
    const p = s.player, vis = p.size * p.visualScale, x = p.x + (p.size - vis) / 2, y = p.y + (p.size - vis) / 2 - p.jumpLift * 8;
    const shadow = () => { rounded(c, x + 5 + p.jumpLift * 10, y + 6 + p.jumpLift * 12, vis, vis, 4); c.fillStyle = `rgba(0,0,0,${.4 * (1 - p.jumpLift * .25) / brightness})`; c.fill(); };
    if (p.jumpLift <= .02 && s.playing) shadow();
    for (const e of s.enemies) {
      enemy(c, e, '#f0363e3d', 0, 3);
      c.save(); c.translate(e.x + e.w / 2, e.y + e.h / 2); c.rotate(e.angle * Math.PI / 180);
      const fill = c.createLinearGradient(-e.w / 2, -e.h / 2, e.w / 2, e.h / 2);
      for (const [at, color] of [[0, '#FE837D'], [.22, '#F0363E'], [.7, '#F0363E'], [1, '#DC2433']] as [number, string][]) fill.addColorStop(at, color);
      rounded(c, -e.w / 2, -e.h / 2, e.w, e.h, 3); c.fillStyle = fill; c.fill(); c.strokeStyle = '#FFC8B9b3'; c.lineWidth = 1; c.stroke();
      if (config.enemies.collideWithEachOther) { rounded(c, -e.w / 2 - 1.2, -e.h / 2 - 1.2, e.w + 2.4, e.h + 2.4, 4.2); c.strokeStyle = '#ffffffd1'; c.lineWidth = 2; c.stroke(); } c.restore();
    }
    const t3=t0?motionProbe.clock():0;
    if (p.jumpLift > .02) shadow();
    c.save(); c.globalAlpha = s.invulnerable ? .22 + .78 * (Math.sin(frame * 1.35) + 1) / 2 : 1;
    rounded(c, x - 4, y - 4, vis + 8, vis + 8, 8); c.fillStyle = '#35F5C633'; c.fill();
    const hero = c.createLinearGradient(x, y, x + vis, y + vis); hero.addColorStop(0, mix('#35F5C6','#ffffff',.62)); hero.addColorStop(.35, '#35F5C6'); hero.addColorStop(1, mix('#35F5C6','#007D74',.4));
    rounded(c, x, y, vis, vis, 4); c.fillStyle = hero; c.fill(); c.strokeStyle = '#8AFFCD'; c.lineWidth = 1.4; c.stroke();
    const jumpProgress = jumpGlowProgress(s, config.game);
    if (jumpProgress > 0) {
      c.save();
      rounded(c, x, y, vis, vis, 4); c.clip();
      this.jumpGlow(c, {x, y, size: vis, progress: jumpProgress});
      c.restore();
    }
    if (s.helmet) { rounded(c, x - 2.5, y - 2.5, vis + 5, vis + 5, 6.5); c.strokeStyle = '#7EE0FFf2'; c.lineWidth = 2.6; c.stroke();rounded(c,x-5,y-5,vis+10,vis+10,9);c.strokeStyle='#ffffff59';c.lineWidth=1.2;c.stroke(); }
    c.beginPath(); c.moveTo(x + vis * .17, y + vis * .083); c.lineTo(x + vis * .83, y + vis * .083); c.strokeStyle = '#C4FFE3a6'; c.lineWidth = 1.2; c.stroke();
    if (config.player.showFace) {
      const center={x:p.x+p.size/2,y:p.y+p.size/2};
      const nearest = s.enemies.reduce<Body|undefined>((a,b)=>!a||Math.hypot(b.x+b.w/2-center.x,b.y+b.h/2-center.y)<Math.hypot(a.x+a.w/2-center.x,a.y+a.h/2-center.y)?b:a,undefined);
      const dx=nearest?nearest.x+nearest.w/2-center.x:0,dy=nearest?nearest.y+nearest.h/2-center.y:0,len=Math.hypot(dx,dy);
      const gx=len>.001?dx/len:Math.sin(frame*.042)*.45,gy=len>.001?dy/len:Math.cos(frame*.031)*.25;
      const startled=s.startled===true,blink=!startled&&frame>0&&frame%230<5;
      c.strokeStyle='#122C38';c.lineWidth=vis*.035;c.lineCap='round';
      for(const sign of [-1,1]){
        const ex=x+vis*(.5+sign*.21),ey=y+vis*.39;
        if(blink){c.beginPath();c.ellipse(ex,ey,vis*.1,vis*.05,0,0,Math.PI);c.stroke();continue;}
        ellipse(c,ex,ey,vis*.23,vis*(startled?.36:.32),'#F4FFFF');
        const px=ex+gx*vis*.035,py=ey+gy*vis*.027;
        ellipse(c,px,py,vis*.15,vis*.24,'#122C38');ellipse(c,px,py+vis*.06,vis*.125,vis*.1,'#179CB0');
        ellipse(c,px-vis*.035,py-vis*.065,vis*.076,vis*.076,'#F4FFFF');ellipse(c,px+vis*.035,py+vis*.04,vis*.036,vis*.036,'#F4FFFF');
      }
      for(const sign of [-1,1])ellipse(c,x+vis*(.5+sign*.29),y+vis*.62,vis*.13,vis*.065,'#FF89ADa6');
      if(startled){
        for(const sign of [-1,1]){const ex=x+vis*(.5+sign*.21);c.beginPath();c.moveTo(ex-vis*.075,y+vis*.17);c.quadraticCurveTo(ex,y+vis*.105,ex+vis*.075,y+vis*.15);c.stroke();}
        ellipse(c,x+vis*.5,y+vis*.73,vis*.13,vis*.16,'#122C38');
      }else{c.beginPath();c.moveTo(x+vis*.4,y+vis*.69);c.quadraticCurveTo(x+vis*.5,y+vis*.82,x+vis*.6,y+vis*.69);c.stroke();}
    }
    c.restore();
    if (!s.playing && !s.dead) { rounded(c, x - 5, y - 5, vis + 10, vis + 10, 9); c.strokeStyle = '#B1FFD777'; c.lineWidth = 1; c.stroke(); }
    const t4=t0?motionProbe.clock():0;
    const border = config.field.borderWidth, inset = Math.max(.5, Math.min(12, border / 2 + .5));
    rounded(c, inset, inset, 380 - inset * 2, 380 - inset * 2, Math.max(0, config.field.cornerRadius - inset));
    const wall = config.game.wallsKillPlayer ? '#F0363E' : '#58E2EC'; c.strokeStyle = `${wall}47`; c.lineWidth = border + 4; c.stroke(); c.strokeStyle = wall; c.lineWidth = border; c.stroke();
    const t5=t0?motionProbe.clock():0;
    for(const impact of impacts)impact.paint(c);
    for(const fx of s.nearMissFx??[]){const t=Math.min(1,fx.age/.42),a=(1-t)*.9,r=6+t*26;c.save();c.globalAlpha=a;c.strokeStyle='#FFC107';c.lineWidth=2.4*(1-t*.5);c.beginPath();c.arc(fx.x,fx.y,r,0,Math.PI*2);c.stroke();c.globalAlpha=a*.55;c.fillStyle='#FFF59D';c.beginPath();c.arc(fx.x,fx.y,r*.35,0,Math.PI*2);c.fill();c.restore();}
    c.restore();
    if(t0)motionProbe.paint([t1-t0,t2-t1,t3-t2,t4-t3,t5-t4,motionProbe.clock()-t5]);
  }
}
