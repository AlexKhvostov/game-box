import {awardPose} from './achievement-presentation.ts';
import type {AwardArtwork} from '../services/award-artwork';
const colors=['#ffb432','#fff39a','#42f5ff','#ff5ad7','#9d86ff','#63ffb6','#ff7c5c'];
let seed=48195;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
const papers=Array.from({length:178},(_,i)=>({sign:i%2?1:-1,offset:random()*.23,vx:.06+random()*.44,vy:-.42-random()*.66,size:3.5+random()*9.5,phase:random()*Math.PI*2,spin:random()*7-3.5,color:i%7}));
const burstPositions=[[.19,.244],[.81,.29],[.12,.46],[.87,.435],[.69,.19],[.28,.145],[.83,.59]],delays=[0,.06,.27,.35,.51,.70,.90];
const bursts=burstPositions.map(([x,y],i)=>({x:x!,y:y!,delay:delays[i]!,rays:Array.from({length:39},(_,j)=>({angle:j/39*Math.PI*2+random()*.13,speed:.28+random()*.26})),color:i}));
const spray=Array.from({length:60},(_,i)=>({sign:i%2?1:-1,offset:random()*.19,vx:.16+random()*.4,vy:-.22-random()*.68}));
export function paintAward(context:CanvasRenderingContext2D,width:number,height:number,art:AwardArtwork,elapsedMs:number,cup:boolean,reduced:boolean){
 const pose=awardPose(elapsedMs,cup,reduced),{t,after,lift}=pose,unit=Math.min(width,height),scale=.73+.27*lift;
 const bounce=reduced||after<0?0:Math.sin(after*10)*Math.exp(-after*4.4)*width*.026;
 const cx=width/2,cy=height*(cup?.45:.44)+(1-lift)*height*.1-bounce,side=width*(cup?.90:.78)*scale;
 context.clearRect(0,0,width,height);let image:CanvasImageSource|null,source:number[]|null=null;
 if(reduced)image=pose.p<.25?art.start:art.end;
 else if(art.atlas&&t<art.metadata.orientationDuration){image=art.atlas;const frame=Math.max(0,Math.min(art.metadata.frames-1,Math.round(t/art.metadata.orientationDuration*(art.metadata.frames-1)))),tile=art.metadata.tileSize;source=[frame%art.metadata.columns*tile,Math.floor(frame/art.metadata.columns)*tile,tile,tile];}
 else image=art.end??art.start;
 image??=art.start??art.end;
 if(image){if(source)context.drawImage(image,source[0]!,source[1]!,source[2]!,source[3]!,cx-side/2,cy-side/2,side,side);else context.drawImage(image,cx-side/2,cy-side/2,side,side);}
 if(reduced||after<0||after>3.25)return pose;
 context.save();context.lineCap='round';
 for(const burst of bursts){const age=after-burst.delay;if(age<0||age>1.42)continue;const x=burst.x*width,y=burst.y*height,travel=unit*(1-Math.exp(-2.7*age))/2.55;context.strokeStyle=colors[burst.color]!;context.globalAlpha=(1-age/1.42)**1.5;
  for(const ray of burst.rays){const dx=Math.cos(ray.angle)*ray.speed*travel,dy=Math.sin(ray.angle)*ray.speed*travel;context.lineWidth=1.5;context.beginPath();context.moveTo(x+dx*.83,y+dy*.83+age*age*unit*.025);context.lineTo(x+dx,y+dy+age*age*unit*.025);context.stroke();}
 }
 if(!cup)for(const drop of spray){const age=after-drop.offset;if(age<0||age>1.02)continue;const x=cx+(drop.sign*.13+drop.sign*drop.vx*age)*unit,y=cy+(.19+drop.vy*age+.46*age*age)*unit;context.strokeStyle='#fff39a';context.globalAlpha=(1-age/1.02)**.8;context.lineWidth=1.2;context.beginPath();context.moveTo(x,y);context.lineTo(x-drop.sign*unit*.015,y-(drop.vy+.92*age)*unit*.025);context.stroke();}
 for(const bit of papers){const age=after-bit.offset;if(age<0||(cup&&bit.phase>4.8))continue;const fold=Math.abs(Math.cos(bit.phase+age*6));context.save();context.translate(cx+bit.sign*unit*(.11+bit.vx*age/(1+.21*age)),cy+unit*(.18+bit.vy*age+.37*age*age));context.rotate(bit.phase+bit.spin*age);context.globalAlpha=Math.max(0,Math.min(1,(3.15-after)*.9))*(.68+.30*fold);context.fillStyle=colors[bit.color]!;context.fillRect(-bit.size/2,-bit.size*(.1+.2*fold)/2,bit.size,bit.size*(.1+.2*fold));context.restore();}
 context.restore();return pose;
}
