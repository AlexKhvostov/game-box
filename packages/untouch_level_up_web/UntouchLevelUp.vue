<script setup lang="ts">
import {onMounted,onBeforeUnmount,watch} from 'vue';
import {LevelUpModal,type LevelNumber,type LevelUpResult,type LevelUpPhase} from './index.js';
import './level-up.css';
const props=withDefaults(defineProps<{level:LevelNumber;open?:boolean;muted?:boolean;reduced?:boolean;assetBase?:string}>(),{open:true,muted:true,reduced:undefined});
const emit=defineEmits<{'update:open':[boolean];accept:[{level:LevelNumber}];close:[LevelUpResult];open:[];phase:[{phase:LevelUpPhase;level:LevelNumber}]}>();
let modal:LevelUpModal|null=null;
function show(){
  if(modal||!props.open)return;
  modal=new LevelUpModal({level:props.level,muted:props.muted,reduced:props.reduced,assetBase:props.assetBase,
    onPhaseChange:event=>emit('phase',event),onAccept:event=>emit('accept',event),
    onClose:event=>{modal=null;emit('update:open',false);emit('close',event);}});
  emit('open');
}
onMounted(show);
watch(()=>props.open,value=>{if(value)show();else modal?.close();});
watch(()=>props.level,value=>modal?.setLevel(value));
watch(()=>props.muted,value=>modal?.setMuted(value));
onBeforeUnmount(()=>{modal?.destroy();modal=null;});
</script>
<template><span hidden aria-hidden="true"></span></template>
