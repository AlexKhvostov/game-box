// Rasterize text before gameplay. Collisions only look up an existing cell.
const marks=['#','※','✕','✦'];
const colors=['#7EE0FF','#35F5C6','#5CE1FF','#FFFFFF','#FFE566','#B8F2FF','#F0363E','#FF3D7F','#FF8A5B'];
const cell=64,baseFont=40,density=3;
export interface ImpactGlyph {atlas:HTMLCanvasElement;sx:number;sy:number}
const glyphs=new Map<string,ImpactGlyph>();
let preparing:Promise<void>|undefined;
export function prepareImpactGlyphs():Promise<void>{
  return preparing??=(async()=>{
    if(!document.fonts)return;
    let fontTimer:ReturnType<typeof setTimeout>|undefined;
    let ready=false;
    try{
      // A slow optional font must not prevent starting the game.
      ready=await Promise.race([document.fonts.load('900 40px Roboto',marks.join('')).then(()=>true,()=>false),new Promise<boolean>(resolve=>{fontTimer=setTimeout(()=>resolve(false),2000);})]);
    }finally{if(fontTimer)clearTimeout(fontTimer);}
    if(!ready||!document.fonts.check('900 40px Roboto',marks.join('')))return;
    const atlas=document.createElement('canvas');atlas.width=marks.length*cell*density;atlas.height=colors.length*cell*density;
    const c=atlas.getContext('2d');if(!c)return;
    c.setTransform(density,0,0,density,0,0);c.font=`900 ${baseFont}px Roboto,Arial,sans-serif`;c.textAlign='center';c.textBaseline='middle';
    for(let row=0;row<colors.length;row++)for(let col=0;col<marks.length;col++){
      const m=c.measureText(marks[col]),bounds=[m.actualBoundingBoxLeft,m.actualBoundingBoxRight,m.actualBoundingBoxAscent,m.actualBoundingBoxDescent];
      // Keep a transparent gutter. Unsupported/oversized fallback glyphs retain
      // the original text path rather than being clipped into a neighbouring cell.
      if(!bounds.every(Number.isFinite)||Math.max(...bounds)>cell/2-2)continue;
      c.fillStyle=colors[row];c.fillText(marks[col],(col+.5)*cell,(row+.5)*cell);
      glyphs.set(`${marks[col]}:${colors[row]}`,{atlas,sx:col*cell*density,sy:row*cell*density});
    }
  })().catch(()=>{glyphs.clear();});
}
export const impactGlyph=(mark:string,color:string)=>glyphs.get(`${mark}:${color}`);
export function paintImpactGlyph(c:CanvasRenderingContext2D,glyph:ImpactGlyph,fontSize:number){
  const side=cell*fontSize/baseFont;
  c.drawImage(glyph.atlas,glyph.sx,glyph.sy,cell*density,cell*density,-side/2,-side/2,side,side);
}
