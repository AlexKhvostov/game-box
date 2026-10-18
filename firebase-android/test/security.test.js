'use strict';
const {test} = require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc}=require('firebase/firestore');
test('Firestore rules deny anonymous/authenticated balance edits and private reads',async()=>{
  const env=await initializeTestEnvironment({projectId:'demo-untouch-android-rules',firestore:{host:'127.0.0.1',port:8088,rules:fs.readFileSync('firestore.rules','utf8')}});
  try {
    for(const context of [env.unauthenticatedContext(),env.authenticatedContext('owner')]) {
      const db=context.firestore();
      await assertFails(setDoc(doc(db,'players/owner'),{energy:999999}));
      await assertFails(getDoc(doc(db,'players/owner')));
      await assertFails(setDoc(doc(db,'scores/fake'),{timeMs:100000}));
      await assertFails(getDoc(doc(db,'purchases/private-token')));
    }
  } finally {await env.cleanup();}
});
test('actual HTTP function rejects missing/malformed Firebase authentication',async()=>{
  const url='http://127.0.0.1:5001/demo-untouch-android/europe-west1/androidApi';
  for(const auth of ['', 'Bearer forged']) {
    const r=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json',Authorization:auth},body:JSON.stringify({action:'profile',owner:'firebase:victim'})});
    assert.equal(r.status,401);assert.equal((await r.json()).error,'unauthorized');
  }
});
test('actual Auth → HTTP → Firestore pipeline uses token UID and confirms +20 once',async()=>{
  const signup=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key',{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({returnSecureToken:true})
  });
  assert.equal(signup.status,200);const auth=await signup.json();
  const url='http://127.0.0.1:5001/demo-untouch-android/europe-west1/androidApi';
  const call=async payload=>{
    const r=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${auth.idToken}`},body:JSON.stringify(payload)});
    const body=await r.json();assert.equal(r.status,200,JSON.stringify(body));return body;
  };
  const p=await call({action:'guest',owner:'firebase:victim',energy:99999});assert.equal(p.profile.id,`firebase:${auth.localId}`);assert.equal(p.profile.wallet.energy,50);
  const operationId=require('node:crypto').randomBytes(32).toString('hex');
  for(let i=0;i<2;i++) {const tap=await call({action:'wallet_operation',kind:'energy_hidden_tap',args:{},operationId});assert.equal(tap.profile.wallet.energy,70);}
});
