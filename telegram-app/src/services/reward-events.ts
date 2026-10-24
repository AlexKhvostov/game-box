import {shallowRef} from 'vue';
export interface RewardEvent {key:string;owner:string;amount:number;after:number;provisional:boolean;kind:'round'|'wallet'}
export const resultRewardEvent=shallowRef<RewardEvent|null>(null);
export function emitResultReward(event:RewardEvent){resultRewardEvent.value=event;}
