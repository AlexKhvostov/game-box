<script setup lang="ts">
import {computed,shallowRef,watch,onBeforeUnmount} from 'vue';
import AwardCeremony from './AwardCeremony.vue';
import LevelUpCeremony from './LevelUpCeremony.vue';
import {AwardArtworkPool,prepareAwardStudio,type AwardArtwork} from '../services/award-artwork';
import type {AwardPresentationReceipt,AwardCloseReason} from '../domain/achievement-presentation';
const props=withDefaults(defineProps<{receipt:AwardPresentationReceipt|null;prepareNext?:AwardPresentationReceipt|null;level?:number|null;locale:string;muted:boolean;volume?:number;levelVolume?:number;active?:boolean}>(),{active:false,level:null,prepareNext:null,volume:.25,levelVolume:.1});
const emit=defineEmits<{prepared:[id:string,ready:boolean];presented:[id:string];close:[id:string,reason:AwardCloseReason];'level-close':[level:number,reason:'accept'|'dismiss'];'level-presented':[level:number];energy:[{id:string;amount:number;source:HTMLElement}]}>();
const pool=new AwardArtworkPool(),artwork=shallowRef<AwardArtwork|null>(null);let generation=0,alive=true;
const currentKey=computed(()=>props.receipt?`${props.receipt.owner}:${props.receipt.id}`:'');
function retain(){const receipt=props.receipt,next=props.prepareNext?.owner===receipt?.owner?props.prepareNext:null;pool.retain(receipt?.awardId??null,next?.awardId??null);}
watch(()=>[currentKey.value,props.receipt?.awardId],()=>{
 const serial=++generation,receipt=props.receipt;artwork.value=null;
 retain();
 if(!receipt)return;emit('prepared',receipt.id,false);
 void Promise.all([pool.ready(receipt.awardId),prepareAwardStudio()]).then(([value])=>{if(alive&&serial===generation){artwork.value=value;emit('prepared',receipt.id,true);}}).catch(()=>{if(alive&&serial===generation)emit('prepared',receipt.id,false);});
},{immediate:true,flush:'sync'});
// A late receipt changes only the look-ahead resource. Never remount/replay the
// current ceremony, its sound or energy just because the following award changed.
watch(()=>[props.prepareNext?.owner,props.prepareNext?.awardId],retain,{flush:'sync'});
onBeforeUnmount(()=>{alive=false;generation++;pool.dispose();});
</script>
<template><AwardCeremony v-if="active&&receipt&&artwork" :key="currentKey" :receipt="receipt" :artwork="artwork" :locale="locale" :muted="muted" :volume="volume" @presented="emit('presented',$event)" @close="(id,reason)=>emit('close',id,reason)" @energy="emit('energy',$event)"/><LevelUpCeremony v-else-if="active&&!receipt&&level&&level>=2&&level<=6" :key="level" :level="level" :locale="locale" :muted="muted" :volume="levelVolume" @presented="emit('level-presented',$event)" @close="(value,reason)=>emit('level-close',value,reason)"/></template>
