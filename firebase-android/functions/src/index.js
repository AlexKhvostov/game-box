'use strict';
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');
const {getRemoteConfig} = require('firebase-admin/remote-config');
const {onRequest} = require('firebase-functions/v2/https');
const {onMessagePublished} = require('firebase-functions/v2/pubsub');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {createEngine} = require('./engine');
const {createPlayVerifier} = require('./play');
const {defaults,validatePolicy,ApiError,requireThat} = require('./policy');
const app=initializeApp();
const db=getFirestore(app,'android-v1');
const play=createPlayVerifier();
let cachedPolicy, policyLoadedAt=0;
async function getPolicy() {
  if (process.env.FUNCTIONS_EMULATOR === 'true') return defaults;
  if (cachedPolicy && Date.now()-policyLoadedAt < 300000) return cachedPolicy;
  // Fail closed on missing/invalid production RC. No silent switch of economics.
  const template=await getRemoteConfig(app).getTemplate();
  const parameter=template.parameters.android_config_v1;
  requireThat(parameter && Object.keys(parameter.conditionalValues ?? {}).length === 0,'policy_invalid',503);
  const snapshot=validatePolicy(JSON.parse(parameter.defaultValue.value));
  cachedPolicy=snapshot;policyLoadedAt=Date.now();return cachedPolicy;
}
const engine=createEngine({db,getPolicy,verifyPlay:(...args) => play.verify(...args),
  googleLinkedForUid:async uid=>(await getAuth(app).getUser(uid)).providerData.some(p=>p.providerId === 'google.com')});
exports.androidApi=onRequest({region:'europe-west1',memory:'256MiB',cpu:'gcf_gen1',concurrency:1,minInstances:0,maxInstances:2,timeoutSeconds:60},async (req,res) => {
  res.set('Cache-Control','no-store');
  if (req.method !== 'POST') {res.status(405).json({ok:false,error:'method_invalid'});return;}
  try {
    requireThat(req.is('application/json') && Number(req.get('content-length') ?? 0) <= 16384,'request_invalid',400);
    const bearer=/^Bearer (.+)$/.exec(req.get('authorization') ?? '');
    requireThat(bearer,'unauthorized',401);
    let token,user;
    try {token=await getAuth(app).verifyIdToken(bearer[1],true);user=await getAuth(app).getUser(token.uid);}
    catch (_) {throw new ApiError('unauthorized',401);}
    const google=user.providerData.find(p => p.providerId === 'google.com');
    const identity={googleLinked:!!google,name:google?.displayName,email:google?.email};
    const result=await engine.execute(user.uid,req.body,identity);
    if (req.body.action === 'play_verify') {
      const {productId,purchaseToken}=req.body;
      const {hash}=require('./policy');const ref=db.collection('purchases').doc(hash(purchaseToken));
      const purchase=await ref.get();
      if (!purchase.data().acknowledged) {
        try {await play.acknowledge(productId,purchaseToken);await ref.update({acknowledged:true});}
        catch (_) {throw new ApiError('purchase_ack_pending',503);}
      }
    }
    res.status(200).json(result);
  } catch (e) {
    // Never log bodies, auth tokens, purchase receipts or private profiles.
    const known=e instanceof ApiError;
    if (!known) console.error('androidApi internal error',e.name ?? 'Error');
    res.status(known ? e.status : 503).json({ok:false,error:known ? e.code : 'service_unavailable'});
  }
});
// Google Play publishes to this new Firebase topic after explicit IAM setup.
// No PHP forwarding, publicly writable webhook or client-triggered refund.
exports.androidPlayNotifications=onMessagePublished({topic:'untouch-android-play',region:'europe-west1',memory:'256MiB',cpu:'gcf_gen1',concurrency:1,minInstances:0,maxInstances:2,retry:true},async event=>{
  const message=event.data.message.json;
  if(message.packageName !== 'com.best4u.untouch') return;
  const notice=message.subscriptionNotification ?? message.oneTimeProductNotification ?? message.voidedPurchaseNotification;
  const token=notice?.purchaseToken;
  if(typeof token !== 'string' || token.length < 8 || token.length > 4096) return;
  const {hash}=require('./policy');
  const receipt=await db.collection('purchases').doc(hash(token)).get();
  // A notification arriving before the first client verification never grants
  // ownership. Billing restore will verify and attach that receipt normally.
  if(!receipt.exists || !receipt.data().token || receipt.data().supersededBy) return;
  const r=receipt.data(),user=await getAuth(app).getUser(r.uid);
  const googleLinked=user.providerData.some(p=>p.providerId === 'google.com');
  try {await engine.execute(r.uid,{action:'play_verify',productId:r.productId,purchaseToken:token},{googleLinked});}
  catch(e) {
    if(e.code === 'purchase_canceled') {await engine.revokePurchase(r.uid,token);return;}
    if(['purchase_pending','purchase_owner_invalid','purchase_product_invalid'].includes(e.code)) return;
    // Retry transient Developer API failures; do not log receipt contents.
    throw new Error('Play reconciliation temporarily unavailable');
  }
});
// A committed receipt must be acknowledged even if the phone closes or its
// HTTP response is lost. Retried events read current state and never credit it.
exports.androidPlayReceiptFinalize=onDocumentWritten({database:'android-v1',document:'purchases/{receipt}',region:'europe-west1',memory:'256MiB',cpu:'gcf_gen1',concurrency:1,minInstances:0,maxInstances:2,retry:true},async event=>{
  // Emulator fixtures deliberately use invented tokens. External Play traffic
  // is tested through injected REST responses, never from local event hooks.
  if(process.env.FUNCTIONS_EMULATOR === 'true') return;
  const ref=event.data?.after.ref;if(!ref) return;
  const current=await ref.get();if(!current.exists) return;
  const receipt=current.data();
  if(!receipt.token || receipt.acknowledged || receipt.revoked || receipt.supersededBy) return;
  try {await play.acknowledge(receipt.productId,receipt.token);await ref.update({acknowledged:true});}
  catch(e) {
    if(e.code === 'purchase_canceled') {await engine.revokePurchase(receipt.uid,receipt.token);return;}
    throw new Error('Play acknowledgement temporarily unavailable');
  }
});
