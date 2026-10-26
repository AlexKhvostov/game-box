export interface BonusEntryState {
  owner:string|null;
  revision:unknown;
  safe:boolean;
  ready:boolean;
  alreadyOpen:boolean;
}

// Entry-only presentation policy. Refresh/open are existing application actions;
// this policy never claims a reward, writes a wallet or starts a countdown.
export class BonusEntryOffer {
  private owner:string|null=null;
  private epoch=0;
  private active=true;
  private disposed=false;
  private handled=false;
  private verified=false;
  private refreshing=false;
  private attempted=false;
  private revision:unknown;
  private read:()=>BonusEntryState;
  private refresh:()=>Promise<boolean>;
  private open:()=>void;
  constructor(read:()=>BonusEntryState,refresh:()=>Promise<boolean>,open:()=>void){
    this.read=read;this.refresh=refresh;this.open=open;
  }
  private reset(){this.epoch++;this.verified=false;this.handled=this.read().alreadyOpen;this.attempted=false;}
  setActive(active:boolean){
    if(this.active===active)return;
    this.active=active;
    if(!active)this.reset();
    this.check();
  }
  check(){
    if(this.disposed)return;
    const s=this.read();
    if(s.owner!==this.owner){this.owner=s.owner;this.reset();}
    if(!this.active||!s.owner)return;
    if(s.alreadyOpen){this.handled=true;return;}
    if(!s.safe||this.handled||this.refreshing)return;
    if(this.verified){this.handled=true;if(s.ready)this.open();return;}
    if(this.attempted&&this.revision===s.revision)return;
    this.attempted=true;this.revision=s.revision;this.refreshing=true;
    const epoch=this.epoch,owner=s.owner;
    void this.refresh().then(ok=>{
      if(!this.disposed&&epoch===this.epoch&&owner===this.read().owner)this.verified=ok;
    }).catch(()=>{/* Existing connection worker owns retries. */}).finally(()=>{
      this.refreshing=false;this.check();
    });
  }
  dispose(){this.disposed=true;this.epoch++;}
}
