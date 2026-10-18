import {test} from 'node:test';
import assert from 'node:assert/strict';
import {prepareGoogleUnlink} from '../functions/_shared/google-unlink.mjs';
const user={id:'verified_user',email:'owner@example.invalid',is_anonymous:false,identities:[{provider:'google',identity_data:{email:'owner@example.invalid',email_verified:true}}]};
test('unlink prepares only the server-verified Google email, same UID, without password or mail request',async()=>{
  let calls=0;const auth={updateUserById:async(uid,params)=>{
    calls++;assert.equal(uid,user.id);assert.deepEqual(params,{email:user.email,email_confirm:true});return{data:{user:{...user,identities:[...user.identities,{provider:'email'}]}}};
  }};assert.equal((await prepareGoogleUnlink(user,auth)).ready,true);assert.equal(calls,1);
});
test('unverified or mismatched primary email cannot create a recovery identity',async()=>{
  const auth={updateUserById:()=>{throw Error('must_not_call');}};
  for(const bad of [{...user,email:'someone_else@example.invalid'},{...user,is_anonymous:true},{...user,identities:[{provider:'google',identity_data:{email:user.email,email_verified:false}}]}])
    await assert.rejects(prepareGoogleUnlink(bad,auth),e=>e.code==='google_unlink_requires_verified_email');
});
test('already prepared accounts need no change; failed Auth update cannot claim unlink readiness',async()=>{
  assert.equal((await prepareGoogleUnlink({...user,identities:[...user.identities,{provider:'email'}]},{})).ready,true);
  await assert.rejects(prepareGoogleUnlink(user,{updateUserById:async()=>({error:{status:503}})}),e=>e.code==='google_unlink_preparation_failed');
});
