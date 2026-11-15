import {prepareResultFonts} from './result-fonts';
import type {ShareInvitation} from '../domain/share-invitation';
export {shareArtwork} from './share-artwork';
type InvitationBadge=Pick<ShareInvitation,'code'|'codeLabel'|'title'>;
export interface ShareCardData {timeMs:number;riskCount:number;steps:number;locale:'ru'|'en';invitation?:InvitationBadge|null;textScale?:number;artRevision?:number}
const font=(size:number,weight=900)=>`${weight} ${size}px RobotoResult, Roboto, sans-serif`;
function text(c:CanvasRenderingContext2D,value:string,x:number,y:number,size:number,max:number,color:string,weight=900){
  c.font=font(size,weight);while(c.measureText(value).width>max&&size>18)c.font=font(--size,weight);
  c.fillStyle=color;c.fillText(value,x,y,max);
}
function roundedCard(c:CanvasRenderingContext2D){
  c.beginPath();c.moveTo(40,2.5);c.arcTo(1077.5,2.5,1077.5,1077.5,40);c.arcTo(1077.5,1077.5,2.5,1077.5,40);c.arcTo(2.5,1077.5,2.5,2.5,40);c.arcTo(2.5,2.5,1077.5,2.5,40);c.closePath();
}
function invitationBadge(c:CanvasRenderingContext2D,invitation:InvitationBadge,stacked:boolean){
  const x=stacked?40:600,y=stacked?270:32,w=stacked?1000:438,h=stacked?180:220;
  c.save();c.beginPath();c.moveTo(x+28,y);c.arcTo(x+w,y,x+w,y+h,28);c.arcTo(x+w,y+h,x,y+h,28);c.arcTo(x,y+h,x,y,28);c.arcTo(x,y,x+w,y,28);c.closePath();c.fillStyle='#03263dbb';c.fill();c.strokeStyle='#2794a7';c.lineWidth=3;c.stroke();
  c.textAlign='center';text(c,invitation.codeLabel,x+w/2,y+42,32,w-40,'#f0fbff',500);text(c,invitation.code,x+w/2,y+116,64,w-40,'#35f5c6');
  const words=invitation.title.split(' '),rows:string[]=[];let row='';c.font=font(35,500);for(const word of words){const next=row?`${row} ${word}`:word;if(row&&c.measureText(next).width>w-40){rows.push(row);row=word;}else row=next;}if(row)rows.push(row);
  for(let i=0;i<rows.length;i++)text(c,rows[i]!,x+w/2,y+158+i*39,35,w-40,'#f0fbff',500);c.restore();
}
/** Full-card PNG, with the same high scene and live values as the preview. */
export async function renderShareCard(data:ShareCardData,art:HTMLImageElement):Promise<HTMLCanvasElement>{
  await prepareResultFonts();
  const canvas=document.createElement('canvas');
  canvas.width=canvas.height=1080;const c=canvas.getContext('2d');if(!c)throw new Error('share_canvas_unavailable');
  c.fillStyle='#03182d';c.fillRect(0,0,1080,1080);
  c.save();
  // Use arcTo rather than roundRect: supported by all target WebViews.
  roundedCard(c);c.clip();
  c.drawImage(art,0,0,1080,1080);
  const shade=c.createLinearGradient(0,0,0,1080);shade.addColorStop(0,'#00172a2b');shade.addColorStop(.35,'#00172a00');shade.addColorStop(.68,'#00172a00');shade.addColorStop(1,'#001428b8');c.fillStyle=shade;c.fillRect(0,0,1080,1080);
  c.textAlign='left';c.textBaseline='alphabetic';
  const stacked=!!data.invitation&&(data.invitation.code.length>8||(data.textScale??1)>1.3);
  text(c,'untouch',40,94,64,1000,'#4bedff');
  c.save();c.shadowColor='#ffe74b77';c.shadowBlur=14;
  text(c,`${(data.timeMs/1000).toFixed(3)} ${data.locale==='ru'?'с':'s'}`,40,235,data.invitation&&!stacked?84:136,data.invitation&&!stacked?520:1000,'#fff06a');c.restore();
  if(data.invitation)invitationBadge(c,data.invitation,stacked);
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
