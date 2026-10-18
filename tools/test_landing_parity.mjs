import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'..');
const site=path.resolve(process.argv[2]||path.join(root,'telegram-web/landing'));
const {config}=await import(pathToFileURL(path.join(site,'demo-engine/config.js')));
const {GameWorld}=await import(pathToFileURL(path.join(site,'demo-engine/game-world.js')));
const {GameFieldColors}=await import(pathToFileURL(path.join(site,'demo-engine/renderer.js')));
const nativePainter=await fs.readFile(path.join(root,'lib/features/game/game_field_painter.dart'),'utf8');
for(const [name,color] of Object.entries(GameFieldColors)){
  const match=nativePainter.match(new RegExp(`static const ${name} = Color\\(0xFF([A-Fa-f0-9]{6})\\)`));
  assert.ok(match,`Native color missing: ${name}`);assert.equal(color.toUpperCase(),'#'+match[1].toUpperCase());
}
const raw=JSON.parse(await fs.readFile(path.join(root,'assets/config/published-gameplay.json'),'utf8')).config;
const native=await fs.readFile(path.join(root,'lib/app/mobile_gameplay_tuning.dart'),'utf8');
const nativeDefaults=await fs.readFile(path.join(root,'lib/domain/gameplay_config.dart'),'utf8');
const nativeWorld=await fs.readFile(path.join(root,'lib/features/game/game_world.dart'),'utf8');
const viewport=await fs.readFile(path.join(root,'lib/ui/game_viewport.dart'),'utf8');
const rules=await fs.readFile(path.join(root,'lib/domain/arcade_rules.dart'),'utf8');
const number=(text,re)=>Number(text.match(re)[1]);
const scale=number(nativeWorld,/characterSizeScale = ([\d.]+)/);
const side=number(viewport,/referenceFieldSide = ([\d.]+)/);
const stepFactor=number(rules,/\* (0\.1)\)/);
const startSteps=number(nativeDefaults,/this\.startSpeedSteps = ([\d.]+)/);
const accelerationSteps=number(nativeDefaults,/this\.accelerationSteps = ([\d.]+)/);
const speedVariation=number(native,/speedVariation = ([\d.]+)/);
const accelerationVariation=number(native,/accelerationVariation = ([\d.]+)/);
const expectedPlayer=raw.player.size*scale,step=expectedPlayer*stepFactor;
const close=(a,b)=>assert.ok(Math.abs(a-b)<1e-8,`${a} differs from ${b}`);
close(config.player.size,expectedPlayer);
close(config.enemies.speedMin,startSteps*step*(1-speedVariation));
close(config.enemies.speedMax,startSteps*step*(1+speedVariation));
close(config.enemies.accelMin,accelerationSteps*step*(1-accelerationVariation));
close(config.enemies.accelMax,accelerationSteps*step*(1+accelerationVariation));
assert.equal(config.game.speedRampSeconds,0);
assert.equal(config.game.startInvulnSec,raw.game.startInvulnSec);
assert.equal(config.game.wallsKillPlayer,raw.game.wallsKillPlayer);
assert.deepEqual(config.enemies.aspects,raw.enemies.aspects);
close(config.enemies.areaMultiplier,raw.enemies.areaMultiplier);
let seed=106;const rng=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/2**32);
for(let run=0;run<50;run++){
  const world=new GameWorld({config,fieldW:side,fieldH:side,rng,wallInset:3.5});world.resetLayout();
  assert.equal(world.enemies.length,4);close(world.playerSize,expectedPlayer);assert.equal(world.playerHitsEnemy(),false);
  for(const enemy of world.enemies){close(enemy.w*enemy.h,expectedPlayer**2*config.enemies.areaMultiplier);assert.ok(enemy.pos.dx>=0&&enemy.pos.dy>=0&&enemy.pos.dx+enemy.w<=side+1e-6&&enemy.pos.dy+enemy.h<=side+1e-6);}
  for(const seconds of [0,1,5,10]){world.tickPlay(.01,seconds,1);for(const enemy of world.enemies)close(Math.hypot(enemy.vel.dx,enemy.vel.dy),enemy.initialSpeed+enemy.acceleration*seconds);}
  world.movePlayerBy({dx:10000,dy:10000});close(world.player.dx,side-world.wallInset-world.playerSize);close(world.player.dy,side-world.wallInset-world.playerSize);assert.equal(world.wallsKillPlayer(),false);
}
const demo=await fs.readFile(path.join(site,'demo.js'),'utf8');
assert.ok(demo.includes('tickPlay(dt,this.elapsed/1000,1)'));
assert.ok(!demo.includes('ENEMY_ACCELERATION_SCALE'));
assert.ok(demo.includes('wallsKillPlayer() && this.world.playerHitsBorder()'));
const report={androidParity:true,field:side,playerSize:expectedPlayer,playerFieldRatio:expectedPlayer/side,startSpeedBase:startSteps*step,startSpeedRange:[config.enemies.speedMin,config.enemies.speedMax],accelerationBase:accelerationSteps*step,accelerationRange:[config.enemies.accelMin,config.enemies.accelMax],linearSpeedTimes:[0,1,5,10],randomLayouts:50,startInvulnerability:config.game.startInvulnSec,wallsKill:config.game.wallsKillPlayer};
const stationary=[];
for(let run=0;run<30;run++){const world=new GameWorld({config,fieldW:side,fieldH:side,rng,wallInset:3.5});world.resetLayout();let t=0;for(;t<30&&!world.playerHitsEnemy();t+=1/60)world.tickPlay(1/60,t,1);stationary.push(t);}
stationary.sort((a,b)=>a-b);report.stationarySimulation={runs:30,medianSeconds:stationary[15],maximumSecondsCappedAt30:Math.min(30,stationary.at(-1)),survived30Seconds:stationary.filter(t=>t>=30).length};
await fs.writeFile(path.join(root,'docs/release-evidence/neon-landing-20261013/android-demo-parity.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify(report));
