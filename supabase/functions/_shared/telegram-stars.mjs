// Main-bot Stars. Every order and charge is bound to the configured bot.
import crypto from 'node:crypto';
import {Buffer} from 'node:buffer';
import {hash,nonce,product,integer,requireThat} from './core/policy.mjs';
export function starsOffer(id,settings){
  const contents=product(id);requireThat(contents,'offer_invalid',400);
  const subscription=contents.kind==='energy_subscription';
  const price=subscription?settings.stars[`tier${contents.batteryCount}Price`]:settings.stars[`pack${contents.amount}Price`];
  integer(price,1,100000,'offer_invalid');
  if(subscription)requireThat(settings.stars.periodSec===2592000&&price<=10000,'offer_invalid',503);
  return {id,kind:contents.kind,price,currency:'XTR',...(subscription?{batteryCount:contents.batteryCount,periodSec:2592000}:{amount:contents.amount})};
}
export function validWebhookSecret(actual,expected){
  if(typeof actual!=='string'||typeof expected!=='string'||expected.length<32)return false;
  const a=Buffer.from(actual),b=Buffer.from(expected);return a.length===b.length&&crypto.timingSafeEqual(a,b);
}
export function createTelegramStars({db,botApi,getSettings,botId,now=Date.now,integrationAccepted=false,checkoutBudgetMs=5000}){
  const orders=db.collection('telegramOrders'),charges=db.collection('telegramCharges');
  const configured=()=>requireThat(/^\d{5,15}$/.test(botId??''),'stars_unavailable',409);
  const enabled=async()=>{configured();const settings=await getSettings();requireThat(integrationAccepted&&settings.stars.salesEnabled===true,'stars_unavailable',409);return settings;};
  const user=identity=>{requireThat(identity?.platform==='telegram'&&identity.telegramVerified===true&&typeof identity.uid==='string'&&/^\d+$/.test(identity.subject??''),'telegram_unauthorized',401);requireThat(identity.botId===botId,'stars_bot_mismatch',403);return identity;};
  async function invoice(identity,input){
    user(identity);const settings=await enabled(),requestId=nonce(input.requestId),offer=starsOffer(input.productId,settings),id=hash(`stars:${botId}:${identity.uid}:${requestId}`),ref=orders.doc(id);
    const order=await db.runTransaction(async tx=>{
      const saved=await tx.get(ref);if(saved.exists){const o=saved.data();requireThat(o.botId===botId&&o.uid===identity.uid&&o.subject===identity.subject&&o.offer.id===offer.id,'operation_conflict');return o;}
      const player=(await tx.get(db.collection('players').doc(identity.uid))).data();requireThat(player?.platform==='telegram'&&!player.supportDisabled,'profile_disabled',403);
      if(offer.kind==='energy_subscription')requireThat(!player.wallet.energySubscription||player.wallet.energySubscription.expiresAt<=now(),'subscription_already_active');
      const o={uid:identity.uid,subject:identity.subject,botId,offer,createdAt:now(),expiresAt:now()+900000,state:'quoted'};tx.set(ref,o);return o;
    });
    requireThat(order.state==='quoted'&&order.expiresAt>now(),'invoice_expired');
    if(order.url)return {ok:true,invoiceUrl:order.url,orderId:id,offer:order.offer};
    // Bot API call outside retryable DB transaction; repeated links carry the
    // same payload and the checkout/charge ledger controls fulfillment.
    const params={title:order.offer.kind==='energy'?'Untouch · энергия':`Untouch · ×${order.offer.batteryCount}`,description:order.offer.kind==='energy'?`${order.offer.amount} энергии`:`×${order.offer.batteryCount} энергии в бонусе · 30 дней`,payload:id,currency:'XTR',provider_token:'',prices:[{label:'Untouch',amount:order.offer.price}],...(order.offer.periodSec?{subscription_period:order.offer.periodSec}:{})};
    const url=await botApi('createInvoiceLink',params);requireThat(typeof url==='string'&&/^https:\/\/t\.me\//.test(url),'invoice_invalid',503);
    await db.runTransaction(async tx=>{const current=(await tx.get(ref)).data();requireThat(current,'invoice_invalid',503);tx.set(ref,{...current,url});});
    return {ok:true,invoiceUrl:url,orderId:id,offer:order.offer};
  }
  async function preCheckout(query){
    let accepted=false,active=true,timer,timedOut=false,transactionStarted=false;
    const live=()=>requireThat(active,'checkout_expired',409);
    try{
      const check=async()=>{
      await enabled();live();const id=nonce(query.invoice_payload);transactionStarted=true;
      await db.runTransaction(async tx=>{
        live();
        const ref=orders.doc(id),o=(await tx.get(ref)).data();
        requireThat(o&&o.botId===botId&&o.state==='quoted'&&o.expiresAt>now()&&String(query.from?.id)===o.subject&&query.currency==='XTR'&&query.total_amount===o.offer.price,'checkout_invalid');
        requireThat(!o.checkoutId||o.checkoutId===query.id,'checkout_in_progress');
        const p=(await tx.get(db.collection('players').doc(o.uid))).data();requireThat(p?.platform==='telegram'&&!p.supportDisabled,'profile_disabled');
        live();
        if(o.offer.kind==='energy_subscription'){
          requireThat(!p.wallet.energySubscription||p.wallet.energySubscription.expiresAt<=now(),'subscription_already_active');
          requireThat(!p.starsPendingOrder||p.starsPendingOrder.id===id||p.starsPendingOrder.until<=now(),'checkout_in_progress');
          p.starsPendingOrder={id,checkoutId:query.id,until:now()+900000};tx.set(db.collection('players').doc(o.uid),p);
        }
        tx.set(ref,{...o,checkoutId:query.id,checkoutApprovedAt:now()});
      });live();};
      const checking=check();
      const cleanup=checking.catch(()=>{}).then(async()=>{
        if(!timedOut||!transactionStarted)return;
        // The database may commit after our reject deadline. Undo only this
        // unpaid checkout's approval/reservation; never a later buyer action.
        await db.runTransaction(async tx=>{
          const id=nonce(query.invoice_payload),ref=orders.doc(id),o=(await tx.get(ref)).data();
          if(!o||o.botId!==botId||o.state!=='quoted'||o.checkoutId!==query.id)return;
          const playerRef=db.collection('players').doc(o.uid),p=(await tx.get(playerRef)).data();
          const clean={...o};delete clean.checkoutId;delete clean.checkoutApprovedAt;tx.set(ref,clean);
          if(p?.starsPendingOrder?.id===id&&p.starsPendingOrder.checkoutId===query.id){delete p.starsPendingOrder;tx.set(playerRef,p);}
        });
      }).catch(()=>{});
      if(globalThis.EdgeRuntime?.waitUntil)globalThis.EdgeRuntime.waitUntil(cleanup);
      await Promise.race([checking,new Promise((_,reject)=>timer=setTimeout(()=>{active=false;timedOut=true;reject(Error('checkout_deadline'));},Math.min(5000,checkoutBudgetMs)))]);accepted=true;
    }catch{accepted=false;}
    finally{active=false;clearTimeout(timer);}
    await botApi('answerPreCheckoutQuery',{pre_checkout_query_id:query.id,ok:accepted,...(!accepted?{error_message:'Покупка недоступна. Откройте игру и повторите.'}:{})},{timeoutMs:3000});
    return {ok:true,accepted};
  }
  async function payment(message,refund=false){
    const payment=refund?message.refunded_payment:message.successful_payment,id=nonce(payment?.invoice_payload);
    requireThat(typeof payment.telegram_payment_charge_id==='string'&&payment.telegram_payment_charge_id.length<=512,'payment_invalid',400);
    const chargeRef=charges.doc(hash(`${botId}:${payment.telegram_payment_charge_id}`)),orderRef=orders.doc(id);
    return db.runTransaction(async tx=>{
      const o=(await tx.get(orderRef)).data(),old=(await tx.get(chargeRef)).data();
      if(o?.deleted===true||old?.deleted===true)return {ok:true,ignored:true,deleted:true};
      requireThat(o&&o.botId===botId&&String(message.from?.id)===o.subject&&payment.currency==='XTR'&&payment.total_amount===o.offer.price,'payment_invalid',400);
      if(old){requireThat(old.botId===botId&&old.orderId===id,'payment_owner_invalid',403);if(!refund||old.refundedAt)return {ok:true,duplicate:true};}
      requireThat(!refund||old,'refund_unknown',409);
      requireThat(refund||o.checkoutApprovedAt,'payment_unapproved',409);
      if(!refund&&o.offer.kind==='energy')requireThat(!o.paidCharge,'payment_duplicate_order',409);
      let subscriptionExpiresAt=null;
      if(!refund&&o.offer.kind==='energy_subscription'){
        requireThat(payment.is_recurring===true,'payment_invalid',400);
        integer(payment.subscription_expiration_date,1,9007199254740,'payment_invalid');subscriptionExpiresAt=payment.subscription_expiration_date*1000;
        requireThat(subscriptionExpiresAt>=o.createdAt&&subscriptionExpiresAt<=now()+o.offer.periodSec*1000+86400000,'payment_invalid',400);
      }
      const playerRef=db.collection('players').doc(o.uid),p=(await tx.get(playerRef)).data();
      // Deleted profiles are never recreated by a delayed payment/renewal.
      if(p?.platform!=='telegram'||p.supportDisabled&&!refund){
        // Payment may already have completed after checkout approval. Retain a
        // durable charge for support/refund; do not grant or recreate a profile.
        if(refund)tx.set(chargeRef,{...old,refundedAt:now()});
        else tx.set(chargeRef,{uid:o.uid,botId,orderId:id,chargeId:payment.telegram_payment_charge_id,amount:o.offer.price,currency:'XTR',createdAt:now(),refundedAt:null,fulfillmentBlocked:true,expiresAt:subscriptionExpiresAt,isRecurring:payment.is_recurring===true,isFirstRecurring:payment.is_first_recurring===true});
        tx.set(orderRef,{...o,state:refund?'refunded':'paid_blocked',paidCharge:o.paidCharge??payment.telegram_payment_charge_id,...(payment.is_first_recurring===true?{firstChargeId:payment.telegram_payment_charge_id}:{})});
        return {ok:true,fulfillmentBlocked:true};
      }
      const sub=p.wallet.energySubscription;
      if(refund){
        if(o.offer.kind==='energy'&&!old.fulfillmentBlocked)p.wallet.energy=Math.max(0,p.wallet.energy-o.offer.amount);
        else if(sub?.chargeId===payment.telegram_payment_charge_id)p.wallet.energySubscription=null;
        tx.set(chargeRef,{...old,refundedAt:now()});
      }else{
        let expiresAt=null;
        if(o.offer.kind==='energy')p.wallet.energy+=o.offer.amount;
        else{
          expiresAt=subscriptionExpiresAt;
          requireThat(!sub||sub.orderId===id||sub.expiresAt<=now(),'subscription_conflict');
          const firstChargeId=payment.is_first_recurring===true?payment.telegram_payment_charge_id:o.firstChargeId??(sub?.orderId===id?sub.firstChargeId:null);
          if(!sub||expiresAt>sub.expiresAt)p.wallet.energySubscription={provider:'telegram',botId,orderId:id,chargeId:payment.telegram_payment_charge_id,firstChargeId,tokenHash:hash(id),productId:o.offer.id,batteryCount:o.offer.batteryCount,expiresAt,endConfirmed:true,autoRenew:!o.subscriptionState||o.subscriptionState==='active'};
          else if(sub.orderId===id&&firstChargeId)sub.firstChargeId=firstChargeId;
        }
        tx.set(chargeRef,{uid:o.uid,botId,orderId:id,chargeId:payment.telegram_payment_charge_id,amount:o.offer.price,currency:'XTR',createdAt:now(),expiresAt,refundedAt:null});
        tx.set(orderRef,{...o,state:o.offer.kind==='energy'?'paid':'subscription',paidCharge:o.paidCharge??payment.telegram_payment_charge_id,
          ...(payment.is_first_recurring===true?{firstChargeId:payment.telegram_payment_charge_id}:{})});
      }
      if(p.starsPendingOrder?.id===id)p.starsPendingOrder=null;
      p.version++;tx.set(playerRef,p);return {ok:true,duplicate:false};
    });
  }
  async function cancel(identity,input){
    user(identity);const p=(await db.collection('players').doc(identity.uid).get()).data(),sub=p?.wallet.energySubscription;
    requireThat(sub?.provider==='telegram'&&sub.botId===botId&&sub.firstChargeId,'subscription_not_found',404);
    const original=(await orders.doc(sub.orderId).get()).data();requireThat(original?.botId===botId&&original.uid===identity.uid&&original.subject===identity.subject,'payment_owner_invalid',403);
    await botApi('editUserStarSubscription',{user_id:identity.subject,telegram_payment_charge_id:sub.firstChargeId,is_canceled:input.cancel!==false});
    await db.runTransaction(async tx=>{
      const ref=db.collection('players').doc(identity.uid),current=(await tx.get(ref)).data(),orderRef=orders.doc(sub.orderId),order=(await tx.get(orderRef)).data();
      if(order)tx.set(orderRef,{...order,subscriptionState:input.cancel===false?'active':'canceled'});
      if(current?.wallet.energySubscription?.orderId===sub.orderId){current.wallet.energySubscription.autoRenew=input.cancel===false;current.version++;tx.set(ref,current);}
    });
    return {ok:true};
  }
  async function update(body){
    configured();requireThat(integrationAccepted,'stars_unavailable',409);
    if(body?.pre_checkout_query)return preCheckout(body.pre_checkout_query);
    const message=body?.message;
    if(message?.successful_payment)return payment(message);
    if(message?.refunded_payment)return payment(message,true);
    if(body?.subscription){
      const event=body.subscription,id=nonce(event.invoice_payload);
      requireThat(['active','canceled','failed'].includes(event.state)&&Number.isSafeInteger(body.update_id),'subscription_invalid',400);
      return db.runTransaction(async tx=>{
        const ref=orders.doc(id),o=(await tx.get(ref)).data();if(o?.deleted===true)return {ok:true,ignored:true,deleted:true};requireThat(o&&o.botId===botId&&String(event.user?.id)===o.subject,'payment_owner_invalid',403);
        if((o.subscriptionUpdate??-1)>=body.update_id)return {ok:true,duplicate:true};
        const playerRef=db.collection('players').doc(o.uid),p=(await tx.get(playerRef)).data();
        if(p?.wallet.energySubscription?.orderId===id){p.wallet.energySubscription.autoRenew=event.state==='active';p.version++;tx.set(playerRef,p);}
        tx.set(ref,{...o,subscriptionUpdate:body.update_id,subscriptionState:event.state});return {ok:true};
      });
    }
    return {ok:true,ignored:true};
  }
  return {invoice,cancel,update};
}
