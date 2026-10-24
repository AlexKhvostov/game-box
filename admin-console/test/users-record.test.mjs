import test from 'node:test';
import assert from 'node:assert/strict';
import {mountUsers,formatUserRecord,userTableRow} from '../src/users.js';
const tick=()=>new Promise(r=>setImmediate(r));
const user={id:'player',nickname:'Player',platform:'telegram',bestTimeMs:16090,energy:50,completedGames:2,status:'active',lastActiveAt:0,subscription:null};
test('record is shown in seconds to three decimals and absent or unsafe values stay empty',()=>{
 assert.equal(formatUserRecord(16090),'16,090');assert.equal(formatUserRecord(1),'0,001');assert.equal(formatUserRecord(3600000),'3600,000');
 for(const value of [0,null,undefined,-1,1.5,NaN,Infinity,'16090','<img src=x onerror=alert(1)>',Number.MAX_SAFE_INTEGER+1])assert.equal(formatUserRecord(value),'—');
 const html=userTableRow(user);assert.match(html,/<td class="user-record"><b>16,090<\/b><\/td>/);
});
test('record and untrusted nickname, ID, email never create HTML or attributes',()=>{
 const attack='\"><img src=x onerror=alert(1)><script>alert(2)</script>';
 const html=userTableRow({...user,id:attack,nickname:attack,email:attack,bestTimeMs:attack});
 assert.equal(html.includes('<img'),false);assert.equal(html.includes('<script'),false);assert.match(html,/&lt;img/);assert.match(html,/data-user="&quot;&gt;/);assert.match(html,/<td class="user-record"><b>—<\/b>/);
});
test('record filter sends both directions and platform to server, paging resets after change',async()=>{
 const elements=new Map(),element=()=>({innerHTML:'',textContent:'',hidden:false,disabled:false,value:''});
 for(const id of ['user-query','user-rows','users-empty','users-total','users-prev','users-next','users-page','user-search','filters-reset','filter-platform','filter-connection','filter-subscription','filter-status','filter-sort','filter-direction'])elements.set('#'+id,element());
 const container={innerHTML:'',querySelector:s=>elements.get(s)??null,querySelectorAll:()=>[]},calls=[],toasts=[];
 mountUsers({container,preview:false,toast:s=>toasts.push(s),request:async(action,body)=>{calls.push({action,...body});return {users:[user],total:26,nextOffset:body.offset===0?25:null};}});await tick();
 assert.match(container.innerHTML,/<option value="record">Рекорду<\/option>/);assert.match(container.innerHTML,/<th>Рекорд, с<\/th>/);
 elements.get('#filter-sort').onchange({target:{value:'record'}});await tick();assert.equal(calls.at(-1).sort,'record');assert.equal(calls.at(-1).direction,'desc');
 elements.get('#users-next').onclick();await tick();assert.equal(calls.at(-1).offset,25);
 elements.get('#filter-direction').onchange({target:{value:'asc'}});await tick();assert.equal(calls.at(-1).offset,0);assert.equal(calls.at(-1).direction,'asc');
 elements.get('#filter-platform').onchange({target:{value:'telegram'}});await tick();assert.equal(calls.at(-1).platform,'telegram');assert.equal(calls.at(-1).sort,'record');assert.equal(calls.at(-1).direction,'asc');assert.equal(toasts.length,0);
});
