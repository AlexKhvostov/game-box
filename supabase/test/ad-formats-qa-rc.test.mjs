import test from 'node:test';
import assert from 'node:assert/strict';
import {qaKey,patchQaTemplate,unrelated} from '../../tools/qa_ad_formats_remote_config.mjs';

test('QA publication touches only its own parameter and preserves all main/Telegram settings',()=>{
 const base={parameters:{android_config_v1:{defaultValue:{value:'main'}},untouch_platforms_v1:{defaultValue:{value:'platforms'}}},conditions:[{name:'existing'}],parameterGroups:{other:{parameters:{unchanged:{defaultValue:{value:'same'}}}}},version:{versionNumber:'100'}};
 for(const banner of [false,true])for(const automatic of [false,true]){
  const next=patchQaTemplate(base,{banner,automatic});
  assert.equal(unrelated(next.template),unrelated(base));
  assert.equal(JSON.parse(next.template.parameters[qaKey].defaultValue.value).banner.enabled,banner);
  assert.equal(next.policy.automatic.enabled,automatic);
  assert.equal(next.policy.banner.installDelaySec,0);
  assert.equal(next.policy.automatic.resumeGraceSec,180);
 }
 assert.equal(base.parameters[qaKey],undefined);
});
test('a missing QA key is safely OFF and a single change preserves the other switch',()=>{
 const off=patchQaTemplate({parameters:{}});
 assert.equal(off.policy.banner.enabled,false);
 assert.equal(off.policy.automatic.enabled,false);
 const on=patchQaTemplate(off.template,{banner:true});
 assert.equal(on.policy.banner.enabled,true);
 assert.equal(on.policy.automatic.enabled,false);
 assert.throws(()=>patchQaTemplate(on.template,{automatic:1}));
 assert.throws(()=>patchQaTemplate(on.template,{economy:false}));
});
