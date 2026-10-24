import {test} from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import {createServer} from '../node_modules/vite/dist/node/index.js';

test('glyphs warm once before gameplay; cached painting preserves the animated size and avoids new text rasterization',async()=>{
  const previous=Object.getOwnPropertyDescriptor(globalThis,'document'),calls=[];
  let fonts=0;
  const context=new Proxy({}, {get:(_target,name)=>name==='measureText'?()=>({actualBoundingBoxLeft:20,actualBoundingBoxRight:20,actualBoundingBoxAscent:20,actualBoundingBoxDescent:20}):(...args)=>calls.push([name,...args]),set:()=>true});
  const atlas={width:0,height:0,getContext:()=>context};
  Object.defineProperty(globalThis,'document',{configurable:true,value:{fonts:{check:()=>true,load:async(font,marks)=>{fonts++;assert.equal(font,'900 40px Roboto');assert.equal(marks,'#※✕✦');}},createElement:name=>{if(name==='template')return{content:{}};assert.equal(name,'canvas');return atlas;}}});
  const server=await createServer({root:path.resolve('telegram-app'),server:{middlewareMode:true},appType:'custom'});
  try{
    const glyph=await server.ssrLoadModule('/src/game/impact-glyphs.ts'),impact=await server.ssrLoadModule('/src/game/impact.ts');
    const state={player:{x:100,y:100,size:40},againstWall:false},rng=()=>{let n=123;return()=>((n=(1664525*n+1013904223)>>>0)/2**32);};
    const cold=new impact.ImpactBurst(state,true,rng());
    const first=glyph.prepareImpactGlyphs();assert.equal(glyph.prepareImpactGlyphs(),first);await first;
    assert.equal(fonts,1);assert.equal(atlas.width,768);assert.equal(atlas.height,1728);assert.equal(calls.filter(c=>c[0]==='fillText').length,36);
    const warm=new impact.ImpactBurst(state,true,rng());
    const geometry=b=>b.glyphs.map(({sprite,...rest})=>rest);assert.deepEqual(geometry(warm),geometry(cold));
    const draws=[],painter=new Proxy({}, {get:(_target,name)=>(...args)=>draws.push([name,...args]),set:()=>true});
    warm.update(.1);warm.paint(painter);assert.ok(draws.some(c=>c[0]==='drawImage'));assert.equal(draws.filter(c=>c[0]==='fillText').length,0);
    assert.equal(calls.filter(c=>c[0]==='fillText').length,36,'Live painting cannot rebuild glyphs');
    const direct=[];glyph.paintImpactGlyph({drawImage:(...args)=>direct.push(args)},glyph.impactGlyph('#','#FFFFFF'),32);
    assert.deepEqual(direct[0].slice(3),[192,192,-25.6,-25.6,51.2,51.2]);
    assert.equal(glyph.impactGlyph('unknown','#FFFFFF'),undefined);
  }finally{await server.close();if(previous)Object.defineProperty(globalThis,'document',previous);else delete globalThis.document;}
});
