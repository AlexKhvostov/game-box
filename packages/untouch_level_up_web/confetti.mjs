// Every foil piece is an independent falling/turning particle; none are baked into the clean plate.
const W=1000,H=1250,TAU=Math.PI*2,fract=x=>x-Math.floor(x),rnd=n=>fract(Math.sin(n*127.1+44.3)*43758.5453);
const clamp=x=>Math.max(0,Math.min(1,x)),smooth=x=>{x=clamp(x);return x*x*(3-2*x);};
export const pieces=Array.from({length:56},(_,i)=>({
 id:i,x:rnd(i+7)*W,y:rnd(i+93)*(H+240),speed:105+rnd(i+31)*200,
 size:(i%7===0?1.45:.55+rnd(i+17)*.65),width:9+rnd(i+3)*13,height:18+rnd(i+45)*29,
 phase:rnd(i+70)*TAU,spin:(i%2?-1:1)*(.8+rnd(i+11)*2.1),drift:14+rnd(i+25)*43,
 type:i%3,alpha:.68+rnd(i+82)*.30
}));
export function position(p,t){return {
 x:p.x+Math.sin(t*(.7+p.size*.45)+p.phase)*p.drift+t*(p.id%2?6:-6),
 y:((p.y+t*p.speed)%(H+240))-120,
 angle:p.phase+t*p.spin,
 flip:Math.cos(p.phase+t*(1.2+p.size*.8))
};}
function path(c,p){
 const w=p.width,h=p.height;
 c.beginPath();
 if(p.type===0){c.moveTo(-w*.5,-h*.5);c.lineTo(w*.5,-h*.42);c.lineTo(w*.42,h*.5);c.lineTo(-w*.5,h*.40);c.closePath();return;}
 const points=[];for(let k=0;k<=12;k++){
  const q=k/12,center=Math.sin(q*Math.PI*(p.type===1?1.25:2))*w*.65;
  points.push({x:center,y:(q-.5)*h});
 }
 points.forEach((q,k)=>k?c.lineTo(q.x-w*.35,q.y):c.moveTo(q.x-w*.35,q.y));
 for(let k=points.length-1;k>=0;k--)c.lineTo(points[k].x+w*.35,points[k].y);
 c.closePath();
}
export function paintConfetti(c,t,w,h){
 c.clearRect(0,0,w,h);c.save();c.scale(w/W,h/H);
 for(const p of pieces){
  const q=position(p,t),d=Math.hypot((q.x-505)/145,(q.y-590)/145);
  // A few pieces pass the foreground; reducing opacity over the face keeps its expression clear.
  const face=.35+.65*smooth((d-.55)/.7),flip=(q.flip<0?-1:1)*(.12+.88*Math.abs(q.flip));
  c.save();c.translate(q.x,q.y);c.rotate(q.angle);c.scale(p.size*flip,p.size);
  c.globalAlpha=p.alpha*face;
  const g=c.createLinearGradient(-p.width,-p.height*.35,p.width,p.height*.35);
  g.addColorStop(0,'#9d5100');g.addColorStop(.18,'#ffbf28');g.addColorStop(.43,'#fff3a9');g.addColorStop(.53,'#ffe66c');g.addColorStop(.82,'#e69b04');g.addColorStop(1,'#a55b00');
  c.fillStyle=g;path(c,p);c.fill();c.strokeStyle='rgba(255,227,129,.75)';c.lineWidth=.65;c.stroke();
  c.restore();
 }
 c.restore();
}
