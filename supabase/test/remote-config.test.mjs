import {test} from 'node:test';
import assert from 'node:assert/strict';
import {defaults} from '../functions/_shared/core/policy.mjs';
import {patchAndroidTemplate,readAndroidTemplate} from '../functions/_shared/remote-config.mjs';
const fixture=()=>({version:{versionNumber:'10'},conditions:[{name:'legacy',expression:"'app.id' in ['legacy']"}],
  parameters:{economy:{defaultValue:{value:'do-not-touch'},conditionalValues:{legacy:{value:'old-test'}}}},
  parameterGroups:{old:{description:'keep',parameters:{other:{defaultValue:{value:'keep'}}}}}});
test('Remote Config publication changes only Android key, preserves unrelated parameters/conditions/groups',()=>{
  const original=fixture(),saved=structuredClone(original);
  const result=patchAndroidTemplate(original,[{path:'mobileEnemies.startSpeedSteps',value:21}]);
  assert.deepEqual(original,saved);assert.deepEqual(result.template.parameters.economy,original.parameters.economy);
  assert.deepEqual(result.template.conditions,original.conditions);assert.deepEqual(result.template.parameterGroups,original.parameterGroups);
  assert.equal(result.template.version,undefined);assert.equal(result.snapshot.config.mobileEnemies.startSpeedSteps,21);
  assert.equal(readAndroidTemplate(original).initialized,false);
});
test('existing grouped Android parameter stays grouped and conditional economic policy is refused',()=>{
  const original=fixture();original.parameterGroups.android={parameters:{android_config_v1:{defaultValue:{value:JSON.stringify(defaults)}}}};
  const result=patchAndroidTemplate(original,[]);assert.equal(result.template.parameters.android_config_v1,undefined);
  assert.equal(readAndroidTemplate(result.template).initialized,true);
  original.parameterGroups.android.parameters.android_config_v1.conditionalValues={experiment:{value:'{}'}};
  assert.throws(()=>patchAndroidTemplate(original,[]),e=>e.code==='android_conditional_policy_unsupported');
});
