import {test} from 'node:test';
import assert from 'node:assert/strict';
import {moderationCard} from '../src/moderation.js';

test('untrusted public names, IDs and reasons cannot inject HTML into an administrator session',()=>{
  const attack='\"><img src=x onerror=alert(1)></button><script>alert(2)</script>';
  const html=moderationCard({id:attack,targetUid:attack,reason:attack,status:'pending',currentNickname:attack,content:{nickname:attack,googleName:attack}});
  assert.equal(html.includes('<img'),false);assert.equal(html.includes('<script'),false);
  assert.equal(html.includes('src=x onerror'),true);assert.equal(html.includes('&lt;img'),true);
  assert.equal(html.includes('data-user="&quot;&gt;'),true);
});
test('a removed target has no hide button and restore is scoped to the active moderation case',()=>{
  const base={id:'a'.repeat(64),targetUid:'fixture',content:{nickname:'Fixture'},status:'pending',currentNickname:null};
  assert.equal(moderationCard(base).includes('data-decision="hide"'),false);
  assert.equal(moderationCard({...base,status:'resolved',currentNickname:'Fixture',restricted:true,restrictionId:'b'.repeat(64)}).includes('data-decision="restore"'),false);
  assert.equal(moderationCard({...base,status:'resolved',currentNickname:'Fixture',restricted:true,restrictionId:base.id}).includes('data-decision="restore"'),true);
});
