import {reactive} from 'vue';
import {ControlHintProgress} from '../game/control-hint';
const progress=new ControlHintProgress({getItem:key=>localStorage.getItem(key),setItem:(key,value)=>localStorage.setItem(key,value)});
export const controlHintState=reactive({lowerStarts:progress.lowerStarts,dismissed:false});
export function resetControlHint(){controlHintState.dismissed=false;}
export function dismissControlHint(){controlHintState.dismissed=true;}
export function recordControlHintStart(fromLower:boolean,attemptId:string){
  progress.recordSuccessfulStart(fromLower,attemptId);controlHintState.lowerStarts=progress.lowerStarts;
}
