export const AWARD_CELEBRATION_MS=3250;
export const AWARD_FRAME_MS=1000/30;
const colors=['#ffb432','#fff39a','#42f5ff','#ff5ad7','#9d86ff','#63ffb6','#ff7c5c'];
let seed=48195;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
const papers=Array.from({length:128},(_,i)=>({sign:i%2?1:-1,offset:random()*.23,vx:.06+random()*.44,vy:-.42-random()*.66,size:3.5+random()*9.5,phase:random()*Math.PI*2,spin:random()*7-3.5,color:i%7}));
const burstPositions=[[.19,.244],[.81,.29],[.12,.46],[.87,.435],[.69,.19],[.28,.145],[.83,.59]],delays=[0,.06,.27,.35,.51,.70,.90];
const bursts=burstPositions.map(([x,y],i)=>({x:x!,y:y!,delay:delays[i]!,rays:Array.from({length:39},(_,j)=>({angle:j/39*Math.PI*2+random()*.13,speed:.28+random()*.26})),color:i}));
const spray=Array.from({length:42},(_,i)=>({sign:i%2?1:-1,offset:random()*.19,vx:.16+random()*.4,vy:-.22-random()*.68}));

export function paintAwardParticles(context:CanvasRenderingContext2D,width:number,height:number,elapsedMs:number,cup:boolean){
 context.clearRect(0,0,width,height);
 if(elapsedMs<0||elapsedMs>=AWARD_CELEBRATION_MS)return;
 const after=elapsedMs/1000,unit=Math.min(width,height),cx=width/2,cy=height*(cup?.45:.44);
 context.save();context.lineCap='round';
 for(const burst of bursts){const age=after-burst.delay;if(age<0||age>1.42)continue;const x=burst.x*width,y=burst.y*height,travel=unit*(1-Math.exp(-2.7*age))/2.55;context.strokeStyle=colors[burst.color]!;context.globalAlpha=(1-age/1.42)**1.5;
  context.lineWidth=1.5;context.beginPath();
  for(const ray of burst.rays){const dx=Math.cos(ray.angle)*ray.speed*travel,dy=Math.sin(ray.angle)*ray.speed*travel;context.moveTo(x+dx*.83,y+dy*.83+age*age*unit*.025);context.lineTo(x+dx,y+dy+age*age*unit*.025);}
  context.stroke();
 }
 if(!cup)for(const drop of spray){const age=after-drop.offset;if(age<0||age>1.02)continue;const x=cx+(drop.sign*.13+drop.sign*drop.vx*age)*unit,y=cy+(.19+drop.vy*age+.46*age*age)*unit;context.strokeStyle='#fff39a';context.globalAlpha=(1-age/1.02)**.8;context.lineWidth=1.2;context.beginPath();context.moveTo(x,y);context.lineTo(x-drop.sign*unit*.015,y-(drop.vy+.92*age)*unit*.025);context.stroke();}
 for(const bit of papers){const age=after-bit.offset;if(age<0||(cup&&bit.phase>4.8))continue;const fold=Math.abs(Math.cos(bit.phase+age*6));context.save();context.translate(cx+bit.sign*unit*(.11+bit.vx*age/(1+.21*age)),cy+unit*(.18+bit.vy*age+.37*age*age));context.rotate(bit.phase+bit.spin*age);context.globalAlpha=Math.max(0,Math.min(1,(3.15-after)*.9))*(.68+.30*fold);context.fillStyle=colors[bit.color]!;context.fillRect(-bit.size/2,-bit.size*(.1+.2*fold)/2,bit.size,bit.size*(.1+.2*fold));context.restore();}
 context.restore();
}
