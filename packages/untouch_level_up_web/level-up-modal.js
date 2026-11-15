import {levelUpContents,levelTitle} from './view.js';
import {LevelUpAnimation,checkedLevel} from './level-up-animation.js';
let sequence=0;

export class LevelUpModal{
  constructor({level=3,muted=true,assetBase,onPhaseChange,reduced=matchMedia('(prefers-reduced-motion: reduce)').matches,onAccept,onClose}={}){
    this.level=checkedLevel(level);this.onAccept=onAccept;this.onClose=onClose;this.reduced=reduced;
    this.result=new Promise(resolve=>{this.resolveResult=resolve;});
    this.events=new AbortController();this.previousFocus=document.activeElement;this.closed=false;this.closing=false;
    const id=`levelup-${++sequence}`;
    this.dialog=document.createElement('dialog');this.dialog.className='lu-dialog lu-window';
    this.dialog.setAttribute('aria-labelledby',`${id}-title`);this.dialog.setAttribute('aria-describedby',`${id}-copy`);
    this.dialog.innerHTML=levelUpContents(level,{titleId:`${id}-title`,copyId:`${id}-copy`});
    document.body.append(this.dialog);
    this.animation=new LevelUpAnimation(this.dialog.querySelector('[data-levelup-scene]'),{level,muted,reduced,assetBase,onPhaseChange,autoplay:false});
    this.dialog.addEventListener('cancel',event=>{event.preventDefault();this.close();},{signal:this.events.signal});
    this.dialog.querySelector('[data-levelup-close]').addEventListener('click',()=>this.close(),{signal:this.events.signal});
    this.dialog.querySelector('[data-levelup-accept]').addEventListener('click',()=>this.close('accept'),{signal:this.events.signal});
    this.dialog.showModal();this.dialog.querySelector('[data-levelup-accept]').focus({preventScroll:true});
    // Start the scene after the accepted B window entrance (160 ms).
    this.startTimer=setTimeout(()=>{if(!this.closed&&!this.closing)this.animation.play();},reduced?0:160);
  }
  setMuted(value){if(!this.closed)this.animation.setMuted(value);}
  setLevel(level){
    if(this.closed)return;
    this.level=checkedLevel(level);this.animation.setLevel(level);this.dialog.querySelector('[data-levelup-copy]').textContent=levelTitle(level);
  }
  close(reason='dismiss'){
    if(this.closed||this.closing)return;
    this.closing=true;clearTimeout(this.startTimer);this.animation.pause();this.events.abort();
    this.dialog.querySelector('[data-levelup-accept]').disabled=true;this.dialog.classList.add('is-closing');
    this.closeTimer=setTimeout(()=>this.finalize(reason,true),this.reduced?0:100);
  }
  finalize(reason,notify){
    if(this.closed)return;this.closed=true;clearTimeout(this.startTimer);clearTimeout(this.closeTimer);this.events.abort();this.animation.destroy();
    this.dialog.close();this.dialog.remove();this.resolveResult({reason,level:this.level});if(this.previousFocus?.isConnected)this.previousFocus.focus({preventScroll:true});
    if(notify){try{if(reason==='accept')this.onAccept?.({level:this.level});}finally{this.onClose?.({reason,level:this.level});}}
  }
  destroy(){this.finalize('dispose',false);}
}
