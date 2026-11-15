<script setup lang="ts">
import {ref,onMounted,onBeforeUnmount,nextTick} from 'vue';
import FieldDrawer from '../components/FieldDrawer.vue';
import LevelBadge from '../components/LevelBadge.vue';
import {FieldPainter} from '../game/painter';
import type {WorldState} from '../domain/kernel';
import snapshot from '../generated/android-config.json';
const open=ref(false), narrow=ref(false), slow=ref(false), canvas=ref<HTMLCanvasElement>();
let observer:ResizeObserver|undefined;
const world:WorldState={playing:false,dead:false,timeMs:0,runDistance:0,riskCount:0,helmet:false,invulnerable:false,jumpCooldownMs:0,player:{x:173,y:173,size:34,visualScale:1,jumpLift:0},enemies:[{x:35,y:42,w:48,h:48,angle:12,speed:0},{x:281,y:65,w:48,h:48,angle:-13,speed:0},{x:52,y:270,w:48,h:48,angle:-8,speed:0},{x:282,y:269,w:48,h:48,angle:18,speed:0}],wallBounces:0,enemyBounces:0,againstWall:false};
onMounted(async()=>{await nextTick();const painter=new FieldPainter(canvas.value!);painter.configure(snapshot.config);const paint=()=>painter.draw(world,snapshot.config,0);observer=new ResizeObserver(paint);observer.observe(canvas.value!);paint();});
onBeforeUnmount(()=>observer?.disconnect());
</script>

<template>
  <main>
    <header><small>UNTOUCH · ЖИВАЯ ПРИМЕРКА</small><h1>Панель из-за поля</h1><p>Квадрат остаётся на месте. Панель выходит из-под его нижнего края.</p></header>
    <div class="preview" :class="{narrow,slow}">
      <div class="time">00:00.000<small>Риск 0 · Шаги 0</small></div>
      <FieldDrawer v-model:open="open" label="Достижения">
        <template #arena><canvas ref="canvas" width="760" height="760" aria-label="Игровое поле Untouch, неподвижный пример"></canvas></template>
        <div class="summary"><LevelBadge :level="2"/><div><small>Рекорд</small><strong>42.8<em> с</em></strong></div><div><small>Среднее</small><strong>25.6<em> с</em></strong></div><div class="medals"><strong>12<span>/40</span></strong><small>медалей</small></div></div>
      </FieldDrawer>
    </div>
    <div class="controls"><button type="button" :aria-expanded="open" @click="open=!open">{{open?'Скрыть панель':'Показать панель'}}</button><label><input v-model="slow" type="checkbox"> Медленно</label><label><input v-model="narrow" type="checkbox"> Узкий экран · 320</label></div>
    <p class="hint">Можно нажать на язычок под полем. Данные — пример.</p>
  </main>
</template>

<style>
@font-face{font-family:Roboto;src:url('/fonts/Roboto-Regular.ttf')}*{box-sizing:border-box}html{color-scheme:dark}body{margin:0;background:#061b2d;color:#eaf9ff;font-family:Roboto,Arial,sans-serif}button,input{font:inherit}main{max-width:560px;margin:0 auto;padding:28px 16px 40px}header{margin-bottom:22px}header>small{font-size:10px;letter-spacing:2px;color:#8cc8d3}h1{font-size:24px;margin:10px 0}p{color:#a9cbe4;font-size:13px;line-height:1.5;margin:0}small{display:block;font-size:10px;color:#b9d6e5}.preview{width:380px;max-width:100%;margin:auto}.preview.narrow{width:288px}.time{text-align:center;font-size:27px;font-weight:800;letter-spacing:1px;margin-bottom:14px;font-variant-numeric:tabular-nums}.time small{font-size:10px;font-weight:400;letter-spacing:0;margin-top:4px}.preview canvas{display:block;width:100%;aspect-ratio:1}.summary{display:flex;gap:12px;align-items:center;justify-content:space-between}.summary .port-level-badge{width:38px;height:46px}.summary strong{display:block;font-size:17px;margin-top:3px;font-variant-numeric:tabular-nums}.summary em{font-size:11px;font-style:normal;color:#c5e5ed}.medals{text-align:right}.medals strong{color:#a7f9dc}.medals strong span{font-size:12px;color:#9dc3d0}.medals small{margin-top:3px}.controls{display:flex;align-items:center;justify-content:center;gap:14px;flex-wrap:wrap;margin-top:3px}.controls button{min-height:42px;border:1px solid #88d5d6;border-radius:9px;background:linear-gradient(#2b6272,#164354);color:#dcfff7;padding:8px 15px;cursor:pointer}.controls label{display:flex;align-items:center;gap:6px;font-size:12px;color:#b9d6e5;cursor:pointer}.controls input{accent-color:#43ecc0}.controls button:focus-visible{outline:2px solid #ffd54a;outline-offset:3px}.hint{text-align:center;margin-top:17px;font-size:11px}.slow .field-drawer-panel{transition-duration:1400ms!important}.slow .field-drawer-handle svg{transition-duration:1400ms!important}@media(max-width:350px){main{padding-top:20px}.summary{gap:7px}.summary strong{font-size:15px}}@media(prefers-reduced-motion:reduce){.slow .field-drawer-panel,.slow .field-drawer-handle svg{transition:none!important}}
</style>
