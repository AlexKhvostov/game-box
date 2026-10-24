import {loadArtwork} from './artwork';
import {prepareResultFonts} from './result-fonts';
export const shareArtwork='/assets/branding/ui/share-scene-square-v1.png';
export interface ShareCardData {timeMs:number;riskCount:number;steps:number;locale:'ru'|'en'}
const font=(size:number,weight=900)=>`${weight} ${size}px RobotoResult, Roboto, sans-serif`;
function text(c:CanvasRenderingContext2D,value:string,x:number,y:number,size:number,max:number,color:string,weight=900){
  c.font=font(size,weight);while(c.measureText(value).width>max&&size>18)c.font=font(--size,weight);
  c.fillStyle=color;c.fillText(value,x,y,max);
}
function roundedCard(c:CanvasRenderingContext2D){
  c.beginPath();c.moveTo(40,2.5);c.arcTo(1077.5,2.5,1077.5,1077.5,40);c.arcTo(1077.5,1077.5,2.5,1077.5,40);c.arcTo(2.5,1077.5,2.5,2.5,40);c.arcTo(2.5,2.5,1077.5,2.5,40);c.closePath();
}
/** Full-card PNG, with the same high scene and live values as the preview. */
export async function renderShareCard(data:ShareCardData):Promise<HTMLCanvasElement>{
  await prepareResultFonts();
  const art=await loadArtwork(shareArtwork),canvas=document.createElement('canvas');
  canvas.width=canvas.height=1080;const c=canvas.getContext('2d');if(!c)throw new Error('share_canvas_unavailable');
  c.fillStyle='#03182d';c.fillRect(0,0,1080,1080);
  c.save();
  // Use arcTo rather than roundRect: supported by all target WebViews.
  roundedCard(c);c.clip();
  c.drawImage(art,0,0,1080,1080);
  const shade=c.createLinearGradient(0,0,0,1080);shade.addColorStop(0,'#00172a2b');shade.addColorStop(.35,'#00172a00');shade.addColorStop(.68,'#00172a00');shade.addColorStop(1,'#001428b8');c.fillStyle=shade;c.fillRect(0,0,1080,1080);
  c.textAlign='left';c.textBaseline='alphabetic';
  text(c,'untouch',40,94,64,1000,'#4bedff');
  c.save();c.shadowColor='#ffe74b77';c.shadowBlur=14;
  text(c,`${(data.timeMs/1000).toFixed(3)} ${data.locale==='ru'?'с':'s'}`,40,235,136,1000,'#fff06a');c.restore();
  c.save();c.shadowColor='#001020';c.shadowBlur=6;
  c.fillStyle='#ff9eae';c.beginPath();c.moveTo(66,875);c.lineTo(94,925);c.lineTo(38,925);c.closePath();c.fill();
  text(c,'!',58,917,38,22,'#082237');
  text(c,`${data.locale==='ru'?'Риск':'Risk'} ${data.riskCount}`,115,923,44,370,'#f0fbff',700);
  c.fillStyle='#69ebff';c.beginPath();c.ellipse(553,894,11,20,.3,0,Math.PI*2);c.ellipse(580,910,11,20,.3,0,Math.PI*2);c.fill();
  text(c,`${data.locale==='ru'?'Шаги':'Steps'} ${data.steps}`,615,923,44,425,'#f0fbff',700);
  text(c,data.locale==='ru'?'Сколько продержитесь вы?':'How long can you survive?',40,1020,56,1000,'#f0fbff');c.restore();
  c.restore();roundedCard(c);c.strokeStyle='#04e4f3';c.lineWidth=5;c.stroke();
  return canvas;
}
