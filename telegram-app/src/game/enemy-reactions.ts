import type {Body, WorldState} from '../domain/kernel';

// Presentation-only port of Android385 EnemyReactions. Its clock never enters
// replay proof, body coordinates, risk accounting, or collision decisions.
export const ENEMY_CATCH_MS = 620;
const TAU = Math.PI * 2;
type Expression = {x:number;y:number;squint:number};
export function reactionEase(value:number) { const t=Math.max(0,Math.min(1,value));return t*t*(3-2*t); }
export class EnemyReactions {
  private timeMs=0;
  private lastPaintMs=0;
  private surpriseAt:number|null=null;
  private caughtAt:number|null=null;
  private expressions:Expression[]=[];
  get caught(){return this.caughtAt!==null;}
  advance(ms:number){if(Number.isFinite(ms)&&ms>0)this.timeMs+=ms;}
  brake(){this.surpriseAt=this.timeMs;}
  finish(caught:boolean){this.surpriseAt=null;this.caughtAt=caught?this.timeMs:null;}
  reset(){this.timeMs=this.lastPaintMs=0;this.surpriseAt=this.caughtAt=null;this.expressions=[];}
  beginPaint(){const elapsed=this.timeMs-this.lastPaintMs;this.lastPaintMs=this.timeMs;return elapsed;}
  surprise(reduced=false){
    if(this.caught||this.surpriseAt===null)return 0;
    const age=this.timeMs-this.surpriseAt;
    return age<1000?(reduced?1:reactionEase(age/70)):(reduced?0:1-reactionEase((age-1000)/1000));
  }
  laugh(index:number,reduced=false){
    if(this.caughtAt===null)return 0;
    if(reduced)return .75;
    const age=this.timeMs-this.caughtAt-index*40;
    if(age<=0)return 0;
    const beat=Math.sin(Math.PI*age/290);
    return reactionEase(age/85)*(.32+.68*beat*beat);
  }
  pose(index:number,reduced=false){
    if(this.caughtAt===null||reduced)return {lift:0,tilt:0};
    const strength=this.laugh(index),swing=Math.sin(Math.PI*(this.timeMs-this.caughtAt-index*40)/290);
    return {lift:2.4*strength,tilt:(index%2===0?1:-1)*2.5*strength*swing};
  }
  paintFace(c:CanvasRenderingContext2D,enemy:Body,world:WorldState,index:number,elapsedMs:number,tilt:number,reduced=false){
    const p=world.player,dx=p.x+p.size/2-enemy.x-enemy.w/2,dy=p.y+p.size/2-enemy.y-enemy.h/2;
    const distance=Math.max(1,Math.hypot(dx,dy)),angle=(enemy.angle+tilt)*Math.PI/180,cos=Math.cos(angle),sin=Math.sin(angle);
    const x=(dx*cos+dy*sin)/distance,y=(dy*cos-dx*sin)/distance;
    const gapX=Math.max(0,enemy.x-p.x-p.size,p.x-enemy.x-enemy.w),gapY=Math.max(0,enemy.y-p.y-p.size,p.y-enemy.y-enemy.h);
    const target=reactionEase((31-Math.hypot(gapX,gapY))/23),expression=this.expressions[index]??={x,y,squint:target};
    const gaze=reduced?1:1-Math.exp(-elapsedMs/72),lid=reduced?1:1-Math.exp(-elapsedMs/(target>expression.squint?105:185));
    expression.x+=(x-expression.x)*gaze;expression.y+=(y-expression.y)*gaze;expression.squint+=(target-expression.squint)*lid;
    const surprise=this.surprise(reduced),giggle=this.laugh(index,reduced),period=3300+index*480;
    const phase=(this.timeMs+index*670)%period-(period-150);
    const blink=!reduced&&phase>=0&&surprise===0&&giggle===0?Math.sin(Math.PI*phase/150)*(1-expression.squint):0;
    this.drawFace(c,enemy,expression,blink,surprise,giggle);
  }
  private drawFace(c:CanvasRenderingContext2D,enemy:Body,expression:Expression,blink:number,surprise:number,giggle:number){
    const scale = Math.min(enemy.w, enemy.h, 54);
    const aspect = enemy.w / enemy.h;
    const lean = aspect > 2 ? .038 : aspect < .4 ? -.024 : 0;
    const squint = Math.min(1.38, expression.squint + giggle * .42);
    const angular = 1 - surprise;
    c.save();

    c.scale(scale, scale);
    c.translate(0, -giggle * .043);

    const iris = c.createRadialGradient(0, .054, .003, 0, 0, .09);
    iris.addColorStop(0, `hsl(45 100% ${Math.round((78 + squint * 10) * 4) / 4}%)`);
    iris.addColorStop(.42, '#ffbd49'); iris.addColorStop(.74, '#e65f21'); iris.addColorStop(1, '#86202a');
    const sclera = c.createLinearGradient(0, -.17, 0, .055);
    sclera.addColorStop(0, '#e59773'); sclera.addColorStop(.72, '#ffebca'); sclera.addColorStop(1, '#ffd6a5');
    const eyelid = c.createLinearGradient(0, -.26, 0, -.02);
    eyelid.addColorStop(0, '#ad3540'); eyelid.addColorStop(1, '#64101f');
    for (const side of [-1, 1]) {
      const outer = side * (.353 - surprise * .015);
      const inner = side * (.036 + surprise * .025);
      const span = outer - inner;
      const outerY = (-.199 + side * lean + squint * .034) * angular - .076 * surprise;
      const innerY = (-.040 + squint * .014) * angular - .076 * surprise;
      const bottom = .202 - squint * .091;
      const closedY = innerY + (outerY - innerY) * .84;
      const lowerControl = bottom + (closedY - bottom) * blink;
      const openArc = surprise * .180;
      c.beginPath();
      c.moveTo(outer, outerY);
      if (surprise > 0) {
        // Blend the slanted lid into two arcs. Both arcs meet at the same corners.
        c.bezierCurveTo(outer - span * angular / 3, outerY + (innerY - outerY) * angular / 3 - openArc,
          inner + span * angular / 3, innerY + (outerY - innerY) * angular / 3 - openArc, inner, innerY);
        c.bezierCurveTo(inner + span * .56 * angular, innerY + (lowerControl - innerY) * (2 / 3) * angular + openArc,
          outer - span * (.16 * 2 / 3) * angular, outerY + (lowerControl - outerY) * (2 / 3) * angular + openArc, outer, outerY);
      } else {
        c.lineTo(inner, innerY);
        c.quadraticCurveTo(inner + span * .84, lowerControl, outer, outerY);
      }
      c.closePath();
      c.fillStyle = sclera;
      c.fill();
      c.lineWidth = .026;
      c.strokeStyle = '#711b25';
      c.stroke();

      c.save();
      c.clip();
      const pupilX = side * (.222 - surprise * .022) + expression.x * (.061 - surprise * .015);
      const pupilY = (outerY + innerY) / 2 + .057 * angular + expression.y * .034;
      c.translate(pupilX, pupilY);
      c.beginPath();
      c.ellipse(0, 0, .088, .083, 0, 0, TAU);
      c.fillStyle = iris;
      c.fill();
      c.beginPath();
      c.ellipse(0, -.008, .043 - surprise * .009, .058 - surprise * .012, 0, 0, TAU);
      c.fillStyle = '#381322';
      c.fill();
      c.beginPath();
      c.arc(-.020, -.032, .022, 0, TAU);
      c.fillStyle = '#fff8dd';
      c.fill();
      c.restore();

      c.beginPath();
      c.moveTo(outer, outerY - .043);
      c.quadraticCurveTo(side * .204, (outerY + innerY) / 2 - .050, inner, innerY - .012);
      c.lineTo(inner, innerY + .017);
      c.lineTo(outer, outerY + .022);
      c.quadraticCurveTo(side * .371, outerY + .002, outer, outerY - .043);
      c.closePath();
      c.fillStyle = eyelid;
      c.globalAlpha = angular;
      c.fill();
      if (surprise > 0) {
        c.globalAlpha = surprise;
        c.beginPath();
        c.moveTo(side * .104, -.230);
        c.quadraticCurveTo(side * .198, -.317, side * .298, -.232);
        c.strokeStyle = '#711b25';
        c.lineWidth = .033;
        c.lineCap = 'round';
        c.stroke();
      }
      c.globalAlpha = 1;
    }

    const smirk = (aspect > 2 ? .053 : .027) + expression.squint * .036;
    const mouthX = -.106 - giggle * .043;
    const mouthY = .125 - giggle * .035;
    c.beginPath();
    c.moveTo(mouthX, mouthY);
    c.quadraticCurveTo(.018, .174, .115 + giggle * .045, .127 - smirk - giggle * .015);
    c.quadraticCurveTo(.048, .227 + giggle * .165, mouthX, mouthY);
    c.fillStyle = '#6e1828';
    c.globalAlpha = angular;
    c.fill();
    if (surprise > 0) {
      c.globalAlpha = surprise;
      c.beginPath();
      c.ellipse(0, .176, .060, .077, 0, 0, TAU);
      c.fill();
    }
    c.restore();
  }
}
