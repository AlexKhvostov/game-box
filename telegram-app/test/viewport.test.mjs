import {test} from 'node:test';
import assert from 'node:assert/strict';
import {viewportGeometry,textScale} from '../src/domain/viewport.ts';
test('field, hero and enemy areas preserve Android proportions across viewports',()=>{
  for(const width of [320,360,390,412,430,820]) for(const height of [480,640,844]){
    const g=viewportGeometry(width,height,24,16);
    assert.equal(g.fieldSide,380*Math.min(width/412,1));
    assert.ok(Math.abs(43.2*g.scale/g.fieldSide-43.2/380)<1e-15);
    assert.ok(Math.abs((g.fieldSide+2*g.margin)-g.width)<1e-10);
    assert.ok(g.hudHeight<=(height-40)*.2+1e-10);
    assert.ok(textScale(width,height,2,40)<=1.4);
  }
});
