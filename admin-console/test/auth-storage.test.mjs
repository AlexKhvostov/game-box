import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createAuthStorage} from '../src/auth-storage.js';
const memory=()=>{const map=new Map();return{getItem:key=>map.get(key)??null,setItem:(key,value)=>map.set(key,value),removeItem:key=>map.delete(key)};};
test('unchecked login is tab-only; remembered session survives another tab and signout clears both stores',()=>{
 const local=memory(),tab=memory(),storage=createAuthStorage(local,tab);
 storage.setItem('auth','temporary');assert.equal(local.getItem('auth'),null);assert.equal(storage.getItem('auth'),'temporary');
 assert.equal(createAuthStorage(local,memory()).getItem('auth'),null);
 storage.setRemember(true);storage.setItem('auth-code-verifier','pkce');storage.setItem('auth','saved');
 const reopened=createAuthStorage(local,memory());assert.equal(reopened.getItem('auth'),'saved');assert.equal(reopened.getItem('auth-code-verifier'),'pkce');assert.equal(tab.getItem('auth'),null);
 reopened.removeItem('auth');assert.equal(storage.getItem('auth'),null);
 storage.setRemember(false);storage.setItem('auth','temporary again');assert.equal(local.getItem('auth'),null);
});
