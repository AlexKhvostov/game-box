import fs from 'node:fs';
import { GameWorld, EnemyBody } from '../telegram-web/js/game-world.js';
import { visualWallInset, runStepsFromPx, calcScore } from '../telegram-web/js/util.js';

// Expected values come from the actual Mini App implementation, not a copy of it.
const snapshot = JSON.parse(fs.readFileSync('assets/config/published-gameplay.json', 'utf8'));
const config = snapshot.config;
if (!config) throw new Error('Missing public configuration');
const enemy = (x, y, angle = 0, vx = 0, vy = 0, spin = 0) => ({
  pos: {dx:x, dy:y}, vel:{dx:vx, dy:vy}, w:40, h:20, aspect:2,
  angleDeg:0, quadrantN:1, fieldQuadrant:0, initialSpeed:Math.hypot(vx,vy),
  acceleration:0, orientDeg:angle, spinDegPerSec:spin,
});
const cases = [
  {name:'clamp and actual distance', player:[120,120], enemies:[], actions:[['move',-1000,-1000],['move',-10,-10],['move',1000,1000]]},
  {name:'near miss enter then leave', player:[100,100], enemies:[enemy(150,100)], actions:[['move',2,0],['move',-40,0],['move',40,0],['move',-40,0]]},
  {name:'jump overlap counted once', player:[100,100], enemies:[enemy(105,105)], actions:[['jump',0],['move',1,0],['move',1,0],['jump',2000],['jumpTick',1],['jump',1999],['jump',2000],['move',1,0]]},
  {name:'rotated collision', player:[100,100], enemies:[enemy(135,110,45)], actions:[['move',5,0],['move',-20,0]]},
  {name:'rotating wall bounce', player:[120,120], enemies:[enemy(5,50,30,-100,40,90)], actions:[['play',0.05,0.05,1],['play',0.05,0.1,1],['play',0.05,0.15,1]]},
  {name:'enemy collision', player:[200,200], enemies:[enemy(90,90,25,100,0),enemy(125,90,-25,-100,0)], actions:[['play',0.05,0.05,1],['play',0.05,0.1,1]]},
];
for (const c of cases) {
  const w = new GameWorld({config, fieldW:300, fieldH:300, wallInset:visualWallInset(config.field.borderWidth)});
  w.player={dx:c.player[0],dy:c.player[1]};
  w.enemies=c.enemies.map(e=>new EnemyBody(e));
  c.expected=c.actions.map(([op,...args])=>{
    let result=null;
    if(op==='move') w.movePlayerBy({dx:args[0],dy:args[1]});
    if(op==='jump') result=w.tryJump(args[0]);
    if(op==='jumpTick') w.tickJump(args[0]);
    if(op==='play') w.tickPlay(...args);
    return {player:[w.player.dx,w.player.dy], distance:w.playerDistance,
      risks:w.nearMissCount, jumping:w.isJumping, hit:w.playerHitsEnemy(), result,
      enemies:w.enemies.map(e=>[e.pos.dx,e.pos.dy,e.vel.dx,e.vel.dy,e.orientDeg])};
  });
}
const scores=[ [1234,199.5,36,4], [10000,718.2,36,5], [0,0,36,0], [999,300,30,2] ].map(([ms,px,size,risk])=>{
  const steps=Math.round(runStepsFromPx(px,size));
  return {ms,px,size,risk,steps,score:calcScore(ms,steps,risk)};
});
fs.mkdirSync('test/fixtures',{recursive:true});
fs.writeFileSync('test/fixtures/miniapp-rules.json',JSON.stringify({revision:snapshot.revision,cases,scores},null,2)+'\n');
console.log(`Generated ${cases.length} physics scenarios and ${scores.length} score scenarios.`);
