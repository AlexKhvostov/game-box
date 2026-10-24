import type {WorldState} from '../domain/kernel';
import {impactGlyph,paintImpactGlyph,type ImpactGlyph} from './impact-glyphs';
// Canvas port of frozen Android ImpactBurst. Cosmetic randomness is separate
// from replay RNG and never feeds back into the simulation or proof.
export class ImpactBurst {
  age=0;
  private glyphs:{x:number;y:number;vx:number;vy:number;rot:number;rotVel:number;life:number;size:number;color:string;mark:string;sprite?:ImpactGlyph}[]=[];
  private x:number;private y:number;private color:string;
  constructor(s:WorldState,helmet=false,random:()=>number=Math.random){
    this.x=s.impactOrigin?.x??s.player.x+s.player.size/2;this.y=s.impactOrigin?.y??s.player.y+s.player.size/2;
    const accent=helmet?'#7EE0FF':'#35F5C6',danger=helmet?'#35F5C6':'#F0363E';
    this.color=s.againstWall?accent:danger;
    const palette=s.againstWall?[accent,'#5CE1FF','#FFFFFF','#FFE566','#B8F2FF']:[danger,'#FF3D7F','#FFE566','#FFFFFF',accent,'#FF8A5B'],marks=['#','#','#','※','✕','✦'];
    const count=11+Math.floor(random()*4);
    for(let i=0;i<count;i++){const a=i/count*Math.PI*2+random()*.35,speed=90+random()*160;
      const glyph={x:this.x,y:this.y,vx:Math.cos(a)*speed,vy:Math.sin(a)*speed,rot:random()*Math.PI,rotVel:(random()-.5)*10,life:.38+random()*.22,size:14+random()*18,color:palette[Math.floor(random()*palette.length)]!,mark:marks[Math.floor(random()*marks.length)]!};
      this.glyphs.push({...glyph,sprite:impactGlyph(glyph.mark,glyph.color)});}
  }
  update(dt:number){this.age+=dt;for(const g of this.glyphs){if(g.life<=0)continue;g.life-=dt;g.x+=g.vx*dt;g.y+=g.vy*dt;g.vx*=.08**dt;g.vy*=.08**dt;g.rot+=g.rotVel*dt;}return this.age<.55||this.glyphs.some(g=>g.life>0);}
  paint(c:CanvasRenderingContext2D){
    c.save();const t=Math.min(1,this.age/.28),r=8+t*42,a=(1-t)*.85;
    if(a>.02){c.globalAlpha=a;c.strokeStyle=this.color;c.lineWidth=3.5*(1-t*.6);c.beginPath();c.arc(this.x,this.y,r,0,Math.PI*2);c.stroke();c.globalAlpha=a*.55;c.fillStyle='#FFFFFF';c.beginPath();c.arc(this.x,this.y,r*.45,0,Math.PI*2);c.fill();}
    if(this.age<.22){c.globalAlpha=(1-this.age/.22)*.55;c.strokeStyle='#FFFFFF';c.lineWidth=1.6;c.lineCap='round';for(let i=0;i<8;i++){const ang=i/8*Math.PI*2+this.age*2,inner=10+this.age*40,outer=28+this.age*90;c.beginPath();c.moveTo(this.x+Math.cos(ang)*inner,this.y+Math.sin(ang)*inner);c.lineTo(this.x+Math.cos(ang)*outer,this.y+Math.sin(ang)*outer);c.stroke();}}
    for(const g of this.glyphs){if(g.life<=0)continue;const fade=Math.min(1,g.life/.45),fontSize=g.size*(.85+(1-fade)*.35);c.save();c.translate(g.x,g.y);c.rotate(g.rot);c.globalAlpha=fade;c.shadowColor=g.color;c.shadowOffsetX=1.2;c.shadowOffsetY=1.2;
      if(g.sprite)paintImpactGlyph(c,g.sprite,fontSize);
      else{c.font=`900 ${fontSize}px Roboto,Arial,sans-serif`;c.textAlign='center';c.textBaseline='middle';c.fillStyle=g.color;c.fillText(g.mark,0,0);}
      c.restore();}c.restore();
  }
}
