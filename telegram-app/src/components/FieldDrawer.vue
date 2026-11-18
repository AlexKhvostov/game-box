<script setup lang="ts">
import {computed, ref, useId, watch} from 'vue';
import {achievements} from '../domain/achievements';
const props = withDefaults(defineProps<{open:boolean; label?:string; interactive?:boolean; retainedProgress?:number}>(), {label:'Игровая панель',interactive:true});
const emit = defineEmits<{'update:open':[value:boolean]}>();
const id = useId(), content = ref<HTMLElement>(), handle = ref<HTMLButtonElement>(), progressHandle=ref<HTMLButtonElement>();
const progressCount=computed(()=>Math.max(0,Math.min(achievements.length,Math.trunc(Number(props.retainedProgress)||0))));
watch(()=>props.open, value=>{
  if(!value&&props.interactive&&(content.value?.contains(document.activeElement)||handle.value===document.activeElement))
    (props.retainedProgress===undefined?handle.value:progressHandle.value)?.focus({preventScroll:true});
}, {flush:'post'});
</script>

<template>
  <div class="field-drawer" :class="{'is-open':open,'is-passive':!interactive,'has-retained-progress':retainedProgress!==undefined}">
    <div class="field-drawer-arena"><slot name="arena"/></div>
    <div class="field-drawer-mouth" @pointerdown.stop @pointerup.stop @pointermove.stop @pointercancel.stop @touchstart.stop @touchend.stop @click.stop>
      <button v-if="retainedProgress!==undefined" ref="progressHandle" type="button" class="field-drawer-progress" :disabled="open||!interactive" :aria-hidden="open" :aria-label="`Показать: ${label}. Медали: ${progressCount} из ${achievements.length}`" :aria-expanded="open" :aria-controls="id" @keydown.stop @keyup.stop @click="emit('update:open',true)"><span class="field-drawer-progress-track" aria-hidden="true"><i v-for="n in achievements.length" :key="n" :class="{lit:n<=progressCount}"></i></span></button>
      <section class="field-drawer-panel" :aria-label="label" @keydown.esc.stop="emit('update:open',false)">
        <div :id="id" ref="content" class="field-drawer-content" :inert="!open||!interactive ? true : undefined" :aria-hidden="!open"><slot/></div>
        <button ref="handle" type="button" class="field-drawer-handle" :disabled="!interactive||(retainedProgress!==undefined&&!open)" :aria-hidden="retainedProgress!==undefined&&!open" :aria-label="`${open?'Скрыть':'Показать'}: ${label}`" :aria-expanded="open" :aria-controls="id" @click="emit('update:open',!open)"><span></span><svg viewBox="0 0 16 8" aria-hidden="true"><path d="m3 2 5 4 5-4"/></svg><span></span></button>
      </section>
    </div>
  </div>
</template>

<style scoped>
/* The arena owns its geometry. The mouth starts exactly at its lower edge;
   only the panel moves. Its hidden portion never paints over the arena. */
.field-drawer{position:relative;isolation:isolate;padding-bottom:108px;width:100%}
.field-drawer-arena{position:relative;z-index:2;border-radius:18px;box-shadow:0 5px 12px #0004}
.field-drawer-mouth{position:absolute;top:0;left:20px;right:20px;height:100%;clip-path:inset(calc(100% - 108px) -12px -12px);pointer-events:none;z-index:1}
.field-drawer-panel{position:absolute;top:calc(100% - 108px);left:0;right:0;transform:translateY(calc(-100% + 14px));transition:transform 300ms cubic-bezier(.4,0,.6,1);pointer-events:auto;border:1px solid #78cbd3;border-top:0;border-radius:0 0 13px 13px;background:linear-gradient(135deg,#24627b,#184359 65%,#1e5367);box-shadow:inset 0 -1px #b7f5ec24,0 5px 9px #0004;overflow:hidden}
.has-retained-progress:not(.is-open) .field-drawer-panel{transform:translateY(-105%)}
.has-retained-progress .field-drawer-panel{z-index:1}
.field-drawer-progress{position:absolute;top:calc(100% - 108px);left:0;right:0;height:24px;padding:0;border:0;background:transparent;pointer-events:auto;cursor:pointer;touch-action:manipulation}
.field-drawer-progress-track{position:absolute;top:4px;left:0;right:0;height:4px;display:flex;gap:1px;padding-inline:5px;overflow:hidden;border-radius:0 0 5px 5px;background:#193a4d}
.field-drawer-progress-track i{display:block;flex:1;min-width:0;background:#3f5768}
.field-drawer-progress-track i.lit{background:#80f0d3}
.field-drawer-progress:focus-visible{outline:2px solid #ffd54a;outline-offset:-2px}
.field-drawer-progress:disabled{opacity:1;cursor:default}
.is-passive .field-drawer-mouth,.is-passive .field-drawer-mouth *{pointer-events:none!important}
.is-open .field-drawer-panel{transform:translateY(-3px);transition-duration:420ms;transition-timing-function:cubic-bezier(.2,.75,.25,1)}
.field-drawer-content{padding:15px 12px 3px;min-height:76px}
.field-drawer-handle{display:flex;align-items:center;justify-content:center;gap:9px;width:100%;height:22px;padding:0 8px;border:0;background:transparent;color:#b5e8ec;cursor:pointer;touch-action:manipulation}
.field-drawer-handle span{width:28px;height:2px;background:#96c8ce66;border-radius:2px}
.field-drawer-handle svg{width:12px;height:6px;fill:none;stroke:currentColor;stroke-width:1.8;transition:transform 300ms}
.is-open .field-drawer-handle svg{transform:rotate(180deg)}
.field-drawer-handle:focus-visible{outline:2px solid #ffd54a;outline-offset:-3px}
@media(prefers-reduced-motion:reduce){.field-drawer-panel,.field-drawer-handle svg{transition:none!important}}
</style>
