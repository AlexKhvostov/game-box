// Shared curve and rewind clock. Units: hero steps/second, seconds of active play.
import 'dart:math' as math;

class EnemyPace {
  EnemyPace(dynamic raw) {
    final m = raw is Map ? raw : const {};
    double value(String key,double fallback,double lo,double hi) {
      final v=m[key] ?? fallback;
      if(v is! num || !v.isFinite || v<lo || v>hi) throw FormatException('enemy_pace_$key');
      return v.toDouble();
    }
    bool flag(String key){
      final v=m.containsKey(key)?m[key]:true;
      if(v is! bool)throw FormatException('enemy_pace_$key');
      return v;
    }
    brakeEnabled=flag('brakeEnabled');
    speedBarEnabled=flag('speedBarEnabled');
    initial=value('initialSpeed',0,0,150);
    multiplier=value('growthMultiplier',70,0,200);
    exponent=value('growthExponent',.2,.01,1);
    smoothing=value('startSmoothingSec',3,.01,60);
    compensation=value('initialCompensation',1,0,10);
    cooldown=value('brakeCooldownSec',6,.1,120);
    firstReady=value('brakeFirstReadySec',6,.1,120);
    rewind=value('brakeRewindSec',6,0,120);
    readyAt=firstReady;
  }
  late final bool brakeEnabled,speedBarEnabled;
  late final double initial,multiplier,exponent,smoothing,compensation,cooldown,firstReady,rewind;
  double elapsed=0,effective=0,readyAt=0,lastPress=-100,lastReady=0;
  double loss=0,before=0,after=0;
  int presses=0;
  static const settleSec=.18;
  double speedAt(double x)=>math.max(0,initial+multiplier*(math.pow(math.max(0,x)+smoothing,exponent)-compensation));
  double get target=>speedAt(effective);
  double get speed=>target+loss*(1-(elapsed-lastPress)/settleSec).clamp(0,1);
  bool get ready=>brakeEnabled && elapsed+1e-9>=readyAt;
  double get charge=>!brakeEnabled?0:ready?1:((elapsed-(presses==0?0:lastPress))/(presses==0?firstReady:cooldown)).clamp(0,1);
  void advance(double dt){elapsed+=dt;effective+=dt;}
  bool press(){
    if(!ready)return false;
    before=speed;effective=math.max(0,effective-rewind);after=target;
    loss=math.max(0,before-after);lastPress=elapsed;readyAt=elapsed+cooldown;presses++;
    return true;
  }
  Map<String,dynamic> get snapshot=>{'enabled':brakeEnabled,'speedBarEnabled':speedBarEnabled,'effectiveSec':effective,'speed':speed,'targetSpeed':target,'charge':charge,'ready':ready,'presses':presses,'pressAgeMs':presses==0?-1:(elapsed-lastPress)*1000,'readyAgeMs':ready?(elapsed-readyAt)*1000:-1,'beforeSpeed':before,'afterSpeed':after};
}
