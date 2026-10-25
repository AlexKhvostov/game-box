import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {createTelegramStars,validWebhookSecret} from '../functions/_shared/telegram-stars.mjs';
import {createTelegramBotUpdates} from '../functions/_shared/telegram-bot-updates.mjs';
import {createTelegramApi} from '../functions/_shared/telegram-api.mjs';
import {initialPlatformSettings} from '../functions/_shared/platform-config-schema.mjs';
import {patchScopedTemplate} from '../functions/_shared/platform-config.mjs';
import {defaults,hash} from '../functions/_shared/core/policy.mjs';
const local=await testDatabase();after(()=>local.close());const db=new PostgresStore(local.pool),engine=createEngine({db});
const botId='8773345829',otherBot='8819798973',settings=initialPlatformSettings(defaults.config).telegram;
settings.stars.salesEnabled=true;let serial=0;const op=()=>hash('main-stars-'+(++serial)),calls=[];
const botApi=async(method,args)=>{calls.push({method,args});return method==='createInvoiceLink'?'https://t.me/$fixture-main':true;};
const main=createTelegramStars({db,botApi,botId,getSettings:async()=>settings,integrationAccepted:true});
const other=createTelegramStars({db,botApi,botId:otherBot,getSettings:async()=>settings,integrationAccepted:true});
async function player(){const uid='main-stars-'+(++serial),i={uid,botId,subject:String(900000+serial),platform:'telegram',telegramVerified:true};await engine.execute(uid,{action:'guest'},i);return i;}
const query=(o,i)=>({id:op(),from:{id:Number(i.subject)},invoice_payload:o.orderId,currency:'XTR',total_amount:o.offer.price});
const paid=(o,i,charge=op())=>({message:{from:{id:Number(i.subject)},successful_payment:{currency:'XTR',total_amount:o.offer.price,invoice_payload:o.orderId,telegram_payment_charge_id:charge}}});
const reject=(p,code)=>assert.rejects(p,e=>e.code===code);
test('Webhook secret validation works without Node global Buffer',()=>{
 const saved=globalThis.Buffer;try{globalThis.Buffer=undefined;assert.equal(validWebhookSecret('x'.repeat(48),'x'.repeat(48)),true);assert.equal(validWebhookSecret('y'.repeat(48),'x'.repeat(48)),false);}finally{globalThis.Buffer=saved;}
});
test('Main Stars reject test identities and bind order, checkout, charge, subscription updates to one bot',async()=>{
 const i=await player();await reject(main.invoice({...i,botId:otherBot},{requestId:op(),productId:'energy_100_v1'}),'stars_bot_mismatch');
 const o=await main.invoice(i,{requestId:op(),productId:'energy_100_v1'}),event=paid(o,i);
 assert.equal((await db.collection('telegramOrders').doc(o.orderId).get()).data().botId,botId);
 assert.equal((await other.update({pre_checkout_query:query(o,i)})).accepted,false);
 await reject(other.update(event),'payment_invalid');
 assert.equal((await main.update({pre_checkout_query:query(o,i)})).accepted,true);
 await main.update(event);await main.update(event);
 const charge=event.message.successful_payment.telegram_payment_charge_id;
 assert.equal((await db.collection('telegramCharges').doc(hash(`${botId}:${charge}`)).get()).data().botId,botId);
 await reject(other.update({update_id:1,subscription:{user:{id:Number(i.subject)},invoice_payload:o.orderId,state:'canceled'}}),'payment_owner_invalid');
 assert.equal((await engine.execute(i.uid,{action:'profile'},i)).profile.wallet.energy,150);
});
test('Approved payments fulfill and refunds reverse once even after sales are disabled',async()=>{
 const i=await player(),o=await main.invoice(i,{requestId:op(),productId:'energy_100_v1'});await main.update({pre_checkout_query:query(o,i)});
 settings.stars.salesEnabled=false;try{
  const event=paid(o,i);await main.update(event);await main.update(event);
  assert.equal((await engine.execute(i.uid,{action:'profile'},i)).profile.wallet.energy,150);
  const refund={message:{from:event.message.from,refunded_payment:event.message.successful_payment}};
  await main.update(refund);await main.update(refund);assert.equal((await engine.execute(i.uid,{action:'profile'},i)).profile.wallet.energy,50);
 }finally{settings.stars.salesEnabled=true;}
});
test('Blocked fulfillment is retained and its refund never subtracts energy that was not granted',async()=>{
 const i=await player(),o=await main.invoice(i,{requestId:op(),productId:'energy_100_v1'});await main.update({pre_checkout_query:query(o,i)});
 await db.collection('players').doc(i.uid).update({supportDisabled:true});const event=paid(o,i);
 assert.equal((await main.update(event)).fulfillmentBlocked,true);
 await db.collection('players').doc(i.uid).update({supportDisabled:false});
 await main.update({message:{from:event.message.from,refunded_payment:event.message.successful_payment}});
 assert.equal((await engine.execute(i.uid,{action:'profile'},i)).profile.wallet.energy,50);
});
test('Sales can be enabled only by explicit trusted integration acceptance',()=>{
 const template={parameters:{android_config_v1:{defaultValue:{value:JSON.stringify(defaults)}}}},patch=[{path:'stars.salesEnabled',value:true}];
 assert.throws(()=>patchScopedTemplate(template,defaults,'telegram',patch),e=>e.code==='stars_acceptance_required');
 assert.equal(patchScopedTemplate(template,defaults,'telegram',patch,{telegramStarsAccepted:true}).envelope.platforms.telegram.stars.salesEnabled,true);
});
test('Refund removes an already granted pack even while the existing player is disabled',async()=>{
 const i=await player(),o=await main.invoice(i,{requestId:op(),productId:'energy_100_v1'});await main.update({pre_checkout_query:query(o,i)});
 const event=paid(o,i);await main.update(event);await db.collection('players').doc(i.uid).update({supportDisabled:true});
 const refund={message:{from:event.message.from,refunded_payment:event.message.successful_payment}};await main.update(refund);await main.update(refund);
 const p=(await db.collection('players').doc(i.uid).get()).data();assert.equal(p.wallet.energy,50);assert.equal(p.supportDisabled,true);
});
test('Webhook replies only to private explicit commands, deduplicates, and routes money events',async()=>{
 const seen=[],handler=createTelegramBotUpdates({stars:{update:async x=>{seen.push(x);return{ok:true,payment:true};}},botApi,db,botId,appUrl:'https://untouch-telegram-app.onrender.com/'});
 const before=calls.length,u={update_id:100,message:{from:{id:500},chat:{id:500,type:'private'},text:'/paysupport'}};
 assert.equal((await handler(u)).replied,true);assert.equal((await handler(u)).duplicate,true);assert.equal(calls.length,before+1);assert.ok(calls.at(-1).args.text.includes('support@untouch.fun'));
 assert.equal((await handler({...u,update_id:101,message:{...u.message,chat:{id:500,type:'group'}}})).ignored,true);
 assert.equal((await handler({update_id:102,pre_checkout_query:{id:'fixture'}})).payment,true);assert.equal(seen.length,1);
});
test('Missing production monetization bot ID disables both services instead of admitting the fallback bot',async()=>{
 const i=await player(),config={ads:{enabled:true,rewardedBlockId:'55424'},stars:{salesEnabled:true}};
 const api=createTelegramApi({engine,resolveIdentity:async()=>i,platformConfig:async()=>config,monetizationBotId:''});
 const profile=await api('fixture',{action:'profile'});assert.equal(profile.platformConfig.ads.enabled,false);assert.equal(profile.platformConfig.stars.salesEnabled,false);
 assert.equal(config.ads.enabled,true);await reject(api('fixture',{action:'wallet_operation',kind:'rewarded_ad_start'}),'ad_unavailable');
});
test('Blocked recurring payment retains verified expiry and first charge for support cancellation/refund',async()=>{
 const i=await player(),o=await main.invoice(i,{requestId:op(),productId:'energy_batteries_2_v1'});await main.update({pre_checkout_query:query(o,i)});
 await db.collection('players').doc(i.uid).update({supportDisabled:true});const event=paid(o,i),payment=event.message.successful_payment;
 payment.is_recurring=true;payment.is_first_recurring=true;payment.subscription_expiration_date=Math.floor(Date.now()/1000)+2592000;
 await main.update(event);const order=(await db.collection('telegramOrders').doc(o.orderId).get()).data(),charge=(await db.collection('telegramCharges').doc(hash(`${botId}:${payment.telegram_payment_charge_id}`)).get()).data();
 assert.equal(order.firstChargeId,payment.telegram_payment_charge_id);assert.equal(charge.expiresAt,payment.subscription_expiration_date*1000);assert.equal(charge.isFirstRecurring,true);
});
