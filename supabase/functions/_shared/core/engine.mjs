// Canonical Supabase game core. Maintained and tested here; no Firebase runtime dependency.
import {Buffer} from 'node:buffer';
import crypto from 'node:crypto';
import {defaults, validatePolicy, product, hash, requireThat, integer, nonce} from './policy.mjs';
import {averageRanking} from '../average-ranking.mjs';
import {attemptHistory} from '../attempt-history.mjs';
import {recordRankings} from '../record-ranking.mjs';
import {plausibleAndroidResult} from '../android-constraints.mjs';
import {ApiError} from './policy.mjs';
import {androidRoundProof} from '../android-replay.mjs';
import {rewardedQuota} from '../rewarded-quota.mjs';
import {publicNickname,requirePublicWords,requireCommunityRules,publicContentAction,maskViewerNames} from '../public-content.mjs';
import {verifiedIdentity,verifiedPlayer,playerPlatform} from '../platform-identity.mjs';
import {fallbackNickname,reservePlayerName} from '../player-names.mjs';
const clone = v => structuredClone(v);
const owner = uid => `supabase:${uid}`;
const canonical = v => Array.isArray(v) ? v.map(canonical) : v && typeof v === 'object' ? Object.fromEntries(Object.keys(v).sort().map(k => [k, canonical(v[k])])) : v;
const digest = v => hash(canonical(v));
const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const codeFor = uid => [...Buffer.from(hash(`invite:${uid}`), 'hex').subarray(0, 12)].map(b => alphabet[b & 31]).join('');
// invite-short-alias: retain legacy aliases; reserve short aliases inside SERIALIZABLE tx.
const shortCodeFor = (uid, attempt) => [...Buffer.from(hash(`invite:v2:${uid}:${attempt}`), 'hex').subarray(0, 6)].map(b => alphabet[b & 31]).join('');
function seed(uid, policy, now) {
  return {
    uid, nickname:fallbackNickname(uid), nicknameSource:'fallback', hasEverStarted:false, hideGoogleAccount:true, version:1, createdAt:now,
    ownCode:codeFor(uid), inviterUid:null, inviterCode:null, inviteRewarded:false, completedGames:0, rewardTotal:0,
    wallet:{lives:0,tokens:0,dailyStreak:0,lastDailyAt:0,lastTimedAt:0,lastAdAt:0,jumpUntil:0,helmetUntil:0,
      bestTimeMs:0,gamesStarted:0,plusUntil:0,claimed:[],unlocked:[],energyVersion:2,
      feedbackSpentEnergy:0,energy:policy.config.economy.androidEnergyV2.simpleBonus.initialEnergy,batteries:[],energySubscription:null,
      simpleBonus:{contract:3,nextAt:0,durationMs:policy.config.economy.androidEnergyV2.simpleBonus.periodSec*1000,lastClaimAt:0}}
  };
}
function publicProfile(p, policy, identity, now) {
  const wallet = clone(p.wallet), config = clone(policy.config.economy.androidEnergyV2), b = config.simpleBonus;
  const sub = wallet.energySubscription;
  const pending = sub && sub.expiresAt <= now && !sub.endConfirmed;
  if (pending) sub.awaitingReconciliation = true;
  const tier = sub && (sub.expiresAt > now || pending) ? sub.batteryCount : 1;
  wallet.simpleBonus = {...wallet.simpleBonus, policy:b, tier, reward:tier === 5 ? b.tier5Reward : tier === 2 ? b.tier2Reward : b.reward};
  config.initialEnergy=b.initialEnergy; config.rewards.ad=b.videoReward; config.rewards.invite=b.inviterReward;
  config.watchAdCooldownSec=b.videoCooldownSec;
  config.watchAdDailyLimit=b.videoDailyLimit??20;
  wallet.adQuota=rewardedQuota(p,b,now);
  wallet.energyConfig=config; wallet.energyGoogleReady=identity.googleLinked;
  wallet.energyIdentityReady=verifiedIdentity(identity);
  wallet.nickname=p.nickname;wallet.feedbackMinimumSpend=100;wallet.feedbackSpentEnergy=Math.max(0,wallet.feedbackSpentEnergy ?? 0);
  return {id:owner(p.uid),nickname:p.nickname,platform:playerPlatform(p),telegramVerified:p.telegramVerified===true,
    telegramUsername:p.hideTelegramAccount===false?p.telegramUsername??null:null,
    hideTelegramAccount:p.hideTelegramAccount!==false,identityReady:verifiedIdentity(identity),googleLinked:identity.googleLinked,
    googleName:identity.googleLinked ? identity.name ?? null : null, googleEmail:identity.googleLinked ? identity.email ?? null : null,
    hideGoogleAccount:p.hideGoogleAccount, communityRulesVersion:p.communityRulesVersion??0,
    hiddenPlayers:p.hiddenPlayers??[],publicNameRestricted:p.publicNameRestricted===true,wallet, walletVersion:p.version, serverNow:now, timezoneOffset:180};
}
function createEngine({db, getPolicy = async () => defaults, verifyPlay, googleLinkedForUid, identityForUid, roundProof=androidRoundProof, now = Date.now}) {
  const playerRef = uid => db.collection('players').doc(uid);
  const linked=async (uid,knownPlayer)=>{
    const p=knownPlayer??(await playerRef(uid).get()).data();
    if(playerPlatform(p)==='telegram')return knownPlayer?verifiedPlayer(p):identityForUid?verifiedIdentity(await identityForUid(uid)):verifiedPlayer(p);
    return googleLinkedForUid?googleLinkedForUid(uid):verifiedPlayer(p);
  };
  async function execute(uid, input, identity = {}) {
    requireThat(typeof uid === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(uid), 'unauthorized', 401);
    requireThat(input && typeof input.action === 'string', 'action_invalid', 400);
    identity = {googleLinked:false,platform:'android',...identity};
    requireThat(['android','telegram'].includes(identity.platform),'identity_invalid',401);
    if(identity.platform==='telegram'){
      requireThat(identity.telegramVerified===true&&!identity.googleLinked,'identity_invalid',401);
      requireThat(!input.action.startsWith('play_')&&!input.action.startsWith('google_'),'platform_action_invalid',400);
    }
    const policy = validatePolicy(await getPolicy(identity.platform));
    const stamp = now();
    // A ranking/audio/text edit must not invalidate an installed client's
    // otherwise identical simulation and prices. Accept only a known, validated
    // published snapshot; never accept a client-authored rules object.
    let roundPolicy=policy;
    if(input.action==='round_start' && input.rulesRevision!==policy.revision &&
       /^[a-f0-9]{64}$/.test(input.rulesRevision??'') && db.pool) {
      const saved=await db.pool.query('select snapshot from untouch.policy_revisions where revision=$1',[input.rulesRevision]);
      if(saved.rows[0]?.snapshot) {
        const previous=saved.rows[0].snapshot;
        // PostgreSQL JSONB normalizes object order. The row was written only by
        // the trusted publisher; validate its schema with that order, retain
        // its original published revision for receipt idempotency.
        validatePolicy({...previous,revision:hash(previous.config)});
        requireThat(previous.revision===input.rulesRevision,'policy_invalid',503);
        const gameplay=c=>Object.fromEntries(['enemies','player','field','game','mobileEnemies','economy'].map(key=>[key,c[key]]));
        if(digest(gameplay(previous.config))===digest(gameplay(policy.config)))roundPolicy=previous;
      }
    }
    if (input.action === 'attempts_history') {
      // Use the same authenticated profile/rate gate as rankings, then one
      // owner-scoped SQL snapshot. Body UID/aggregates are never trusted.
      await execute(uid,{action:'profile'},identity);
      return attemptHistory({db,config:policy.config,uid,stamp,cursor:input.cursor,limit:input.limit});
    }
    if (input.action === 'scores') {
      // Rate-limit once per board request, including a single all-period fetch.
      const viewer=await execute(uid,{action:'profile'},identity);
      if(input.period === 'average') return maskViewerNames(await averageRanking({db,config:policy.config,uid,stamp}),viewer.profile.hiddenPlayers);
      const records=await recordRankings({db,uid,stamp,period:input.period});
      if(input.period === 'allPeriods') records.average=await averageRanking({db,config:policy.config,uid,stamp});
      return maskViewerNames(records,viewer.profile.hiddenPlayers);
    }
    // External Play verification occurs outside the retryable Firestore transaction.
    let verified;
    if (input.action === 'play_verify') {
      requireThat(typeof input.purchaseToken === 'string' && input.purchaseToken.length >= 8 && input.purchaseToken.length <= 4096,'purchase_invalid',400);
      const receipt=await db.collection('purchases').doc(hash(input.purchaseToken)).get();
      requireThat(identity.googleLinked || receipt.exists && receipt.data().uid === uid, 'purchase_requires_recovery');
      requireThat(verifyPlay, 'play_verification_unavailable', 503);
      verified = await verifyPlay(uid, input.productId, input.purchaseToken);
    }
    if (input.action === 'play_sync') return syncPlay(uid, identity, policy);
    // CPU work must run before acquiring transactional player/round locks.
    let verifiedProofRound;
    if(input.action==='round_finish') {
      const id=nonce(input.roundId),saved=(await db.collection('rounds').doc(id).get()).data();
      requireThat(saved?.uid===uid,'round_not_found',404);
      if([1,2,3].includes(saved.proofVersion)&&!saved.finishedAt) {
        requireThat(!saved.canceled,'round_canceled');requireThat(saved.activatedAt!=null,'round_not_activated');
        integer(input.timeMs,1,3600000,'result_invalid');
        integer(input.runDistance,0,10000000,'result_invalid');integer(input.riskCount,0,10000,'result_invalid');
        if(input.timeMs>stamp-saved.activatedAt+1200){const error=new ApiError('result_time_invalid');error.retryAfterMs=input.timeMs-(stamp-saved.activatedAt+1200);throw error;}
        requireThat(plausibleAndroidResult(input),'result_metrics_invalid');
        // Charge the normal per-owner request limit before expensive replay,
        // including invalid proofs. No player transaction is held during CPU work.
        await execute(uid,{action:'profile'},identity);
        roundProof.finish(input,saved);verifiedProofRound=id;
      }
    }
    return db.runTransaction(async tx => {
      const ref=playerRef(uid), snap=await tx.get(ref);
      const p=snap.exists ? snap.data() : seed(uid,policy,stamp);
      requireThat(!p.supportDisabled,'profile_disabled',403);
      requireThat(!snap.exists||playerPlatform(p)===identity.platform,'platform_owner_invalid',403);
      p.platform=identity.platform;p.googleLinked=identity.googleLinked;
      if(identity.platform==='telegram'){
        p.telegramVerified=true;p.telegramUsername=identity.username??null;
      }
      const writes=[];
      const put=(ref,data) => writes.push([ref,data]);
      if (!snap.exists) {
        const codeRef=db.collection('inviteCodes').doc(p.ownCode), code=await tx.get(codeRef);
        requireThat(!code.exists || code.data().uid === uid, 'invite_code_collision', 503);
        put(codeRef,{uid,createdAt:stamp});
        await reservePlayerName({db,tx,p,identity,put,newPlayer:true});
      }
      // Local durable attempts may predate their background round_start ACK.
      // This hint can only lock automatic renaming, never authorize anything.
      if(input.nicknameAutoLocked===true)p.hasEverStarted=true;
      if(snap.exists&&['guest','profile','google_link','google_restore'].includes(input.action))
        await reservePlayerName({db,tx,p,identity,put});
      const limit=stamp - (p.rateSince ?? 0) < 60000;
      requireThat(!limit || (p.rateCount ?? 0) < 180, 'rate_limited', 429);
      p.rateCount=limit ? (p.rateCount ?? 0)+1 : 1; p.rateSince=limit ? p.rateSince : stamp;
      let response={};
      const action=input.action;
      if (['guest','profile','google_link','google_restore','google_details','google_unlink'].includes(action)) {
        // Auth SDK owns link/restore/unlink. The HTTP server trusts only Admin
        // getUser(), not an identity flag or raw Google token sent by the client.
        if (['google_link','google_restore'].includes(action)) requireThat(identity.googleLinked,'google_not_linked');
      } else if (['public_rules_accept','public_name_report','public_name_hide','public_names_reset'].includes(action)) {
        response=await publicContentAction({db,tx,p,input,stamp,put});
      } else if (action === 'rename') {
        // Updated clients identify their rules contract. Keep already-installed
        // legacy clients usable during the Play rollout; never invent acceptance
        // for them. They remain subject to the same name filter and moderation.
        if(input.communityRulesVersion!=null){requireThat(input.communityRulesVersion===1,'community_rules_invalid',400);requireCommunityRules(p);}
        const name=publicNickname(input.nickname);
        const nr=db.collection('names').doc(hash(name.toLocaleLowerCase('ru'))), taken=await tx.get(nr);
        requireThat(!taken.exists || taken.data().uid === uid, 'nickname_taken');
        if (p.nameKey && p.nameKey !== nr.id) writes.push([db.collection('names').doc(p.nameKey), null]);
        if(name!==p.nickname&&p.publicNameRestricted){p.publicNameRestricted=false;p.publicNameRestrictionId=null;p.hideGoogleAccount=true;p.publicGoogleName=null;}
        put(nr,{uid}); p.nameKey=nr.id;p.nickname=name;p.nicknameSource='custom';
      } else if (action === 'wallet_operation') {
        const opId=nonce(input.operationId), args=input.args ?? {}, kind=input.kind;
        requireThat(args && typeof args === 'object' && !Array.isArray(args), 'operation_invalid',400);
        const opRef=ref.collection('operations').doc(opId), old=await tx.get(opRef), fingerprint=digest({kind,args});
        if (old.exists) {
          requireThat(old.data().fingerprint === fingerprint,'operation_conflict'); response=old.data().response;
        } else {
          const beforeEnergy=p.wallet.energy;
          response=await walletOperation(tx,p,kind,args,opId,policy,identity,stamp,put);
          const granted=p.wallet.energy-beforeEnergy;
          if(Number.isSafeInteger(granted)&&granted>0)response={...response,energyGrant:{kind,operationId:opId,amount:granted}};
          put(opRef,{fingerprint,response,createdAt:stamp,policyRevision:policy.revision});
        }
      } else if (['round_start','round_activate','round_cancel','round_finish'].includes(action)) {
        response=await round(tx,p,input,roundPolicy,stamp,put,verifiedProofRound);
        if(action==='round_start')p.hasEverStarted=true;
      } else if (action === 'play_quote') {
        const sku=input.productId, originalTerms=product(sku), requestId=nonce(input.requestId);
        const config=policy.config.economy.androidEnergyV2;
        const terms=originalTerms?.kind === 'energy_subscription' ? {...originalTerms,chargeHours:Math.min(originalTerms.chargeHours,config.chargeHours)} : originalTerms;
        requireThat(terms && [...config.packages,...config.subscriptions].some(o => o.id === sku),'offer_invalid');
        const qr=ref.collection('quotes').doc(requestId), old=await tx.get(qr);
        if (old.exists) { requireThat(old.data().productId === sku,'operation_conflict');response={quote:old.data()}; }
        else { const quote={requestId,productId:sku,owner:owner(uid),revision:config.revision,terms,originalTerms,immutableSku:true,createdAt:stamp};put(qr,quote);response={quote}; }
      } else if (action === 'play_verify') {
        const pr=db.collection('purchases').doc(hash(input.purchaseToken)), old=await tx.get(pr);
        requireThat(!old.exists || old.data().uid === uid,'purchase_owner_invalid');requireThat(!old.exists || !old.data().revoked,'purchase_canceled');
        requireThat(!old.exists || old.data().productId === input.productId,'purchase_product_invalid');
        const terms=product(input.productId);
        requireThat(terms && verified?.valid === true,'purchase_invalid');
        const tokenHash=hash(input.purchaseToken);
        const record={...(old.exists ? old.data() : {}),uid,productId:input.productId,token:input.purchaseToken,kind:terms.kind,...verified,checkedAt:stamp};
        if (terms.kind === 'energy') {
          requireThat(!verified.consumed || old.exists,'purchase_already_consumed');
          if (!old.exists) p.wallet.energy+=terms.amount;
        } else {
          if(verified.linkedPurchaseToken) {
            const linkedRef=db.collection('purchases').doc(hash(verified.linkedPurchaseToken)),linked=await tx.get(linkedRef);
            requireThat(!linked.exists || linked.data().uid === uid,'purchase_owner_invalid');
            put(linkedRef,{...(linked.exists ? linked.data() : {}),uid,kind:'energy_subscription',supersededBy:tokenHash});
          }
          const sub=p.wallet.energySubscription;
          const activeProductId=verified.activeProductId ?? input.productId,activeTerms=product(activeProductId);
          requireThat(activeTerms?.kind === 'energy_subscription','purchase_product_invalid');
          if (!record.supersededBy && (!sub || sub.tokenHash === tokenHash ||
              verified.linkedPurchaseToken && sub.tokenHash === hash(verified.linkedPurchaseToken) ||
              sub.expiresAt <= stamp || activeTerms.batteryCount >= sub.batteryCount)) {
            p.wallet.energySubscription=verified.expiresAt > stamp ? {productId:activeProductId,tokenHash,batteryCount:activeTerms.batteryCount,
              expiresAt:verified.expiresAt,periodId:verified.orderId,capacity:20,durationMs:28800000,revision:policy.revision,endConfirmed:verified.endConfirmed === true} : null;
          }
        }
        put(pr,record);
      } else if (['invites_state','invites_bind','invites_list'].includes(action)) {
        if (!p.ownShortCode) {
          for (let attempt=0; attempt<32; attempt++) {
            const candidate=shortCodeFor(uid,attempt), alias=db.collection('inviteCodes').doc(candidate);
            const occupied=await tx.get(alias);
            if (!occupied.exists || occupied.data().uid === uid) {
              p.ownShortCode=candidate;put(alias,{uid,createdAt:stamp});break;
            }
          }
          requireThat(p.ownShortCode,'invite_code_collision',503);
        }
        if (action === 'invites_bind') {
          const rawCode=typeof input.code === 'string' ? input.code.trim() : '';
          const code=/^(?:[A-Za-z2-9]{6}|[A-Za-z2-9]{12})$/.test(rawCode) ? rawCode.toUpperCase() : '';
          requireThat(/^(?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}|[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12})$/.test(code),'invite_code_invalid',400);
          const target=await tx.get(db.collection('inviteCodes').doc(code));
          requireThat(!p.inviterUid || target.exists && target.data().uid === p.inviterUid,'invite_already_bound');
          requireThat(target.exists,'invite_not_found'); const targetUid=target.data().uid;
          requireThat(targetUid !== uid,'invite_self');
          if (!p.inviterUid) {
            p.inviterUid=targetUid;p.inviterCode=code;
            put(db.collection('invitations').doc(uid),{inviterUid:targetUid,inviteeUid:uid,boundAt:stamp,rewardedAt:null});
          }
        }
      } else { requireThat(false,'action_invalid',400); }
      // Atomic invitation reward: five server-finished rounds + verified identity on each platform.
      if (p.inviterUid && !p.inviteRewarded && p.completedGames >= 5 && verifiedIdentity(identity)) {
        const inviterRef=playerRef(p.inviterUid), inviterSnap=await tx.get(inviterRef);
        if (inviterSnap.exists && !inviterSnap.data().supportDisabled && verifiedPlayer(inviterSnap.data()) && await linked(p.inviterUid,inviterSnap.data())) {
          const inviter=inviterSnap.data(), amount=policy.config.economy.androidEnergyV2.simpleBonus.inviterReward;
          inviter.wallet.energy+=amount;inviter.rewardTotal+=amount;inviter.version++;
          put(inviterRef,inviter);p.inviteRewarded=true;
          const inviteeAmount=policy.config.economy.androidEnergyV2.rewards.invite;
          p.wallet.energy+=inviteeAmount;
          const ir=db.collection('invitations').doc(uid), previous=await tx.get(ir);
          put(ir,{...(previous.exists ? previous.data() : {inviterUid:p.inviterUid,inviteeUid:uid,boundAt:stamp}),rewardedAt:stamp,amount,inviteeAmount,nickname:p.nickname});
        }
      }
      p.publicGoogleName=identity.googleLinked && !p.hideGoogleAccount
        ? Object.hasOwn(identity,'name') ? identity.name ?? null : p.publicGoogleName ?? null : null;
      if(!identity.background)p.lastActiveAt=stamp;p.version++;put(ref,p);
      for (const [r,data] of writes) { if (data === null) tx.delete(r); else tx.set(r,data); }
      // Respond after transaction commit, including latest server-owned wallet.
      return {ok:true,...response,profile:publicProfile(p,policy,identity,stamp),serverNow:stamp,
        ...(['guest','profile'].includes(action) && input.includeGameConfig===true ? {gameConfig:clone(policy)} : {}),
        ...(['invites_state','invites_bind','invites_list'].includes(action) ? {_invitePlayer:p} : {})};
    }).then(async result => {
      if(identity.googleLinked && ['google_link','google_restore'].includes(input.action)) {
        let cursor=null;
        for(let batch=0;batch<1;batch++) {
          let query=db.collection('invitations').where('inviterUid','==',uid).where('rewardedAt','==',null).orderBy('__name__').limit(10);
          if(cursor) query=query.startAfter(cursor);
          const page=await query.get();
          for(const doc of page.docs) {
            if(await linked(doc.id)) {
              const member=(await playerRef(doc.id).get()).data();
              const recipient=identityForUid?await identityForUid(doc.id):playerPlatform(member)==='telegram'
                ?{platform:'telegram',telegramVerified:verifiedPlayer(member),username:member?.telegramUsername??null}
                :{googleLinked:true};
              if(verifiedIdentity(recipient))await execute(doc.id,{action:'profile'},{...recipient,background:true});
            }
          }
          if(page.size < 10) break;cursor=page.docs.at(-1);
        }
        // Incoming rewards can update this player's wallet in another tx.
        const current=await playerRef(uid).get();
        result.profile=publicProfile(current.data(),policy,identity,stamp);
        if(result._invitePlayer) result._invitePlayer=current.data();
      }
      if (result._invitePlayer) {result.invites=maskViewerNames(await inviteState(result._invitePlayer,identity,policy,input),result._invitePlayer.hiddenPlayers);delete result._invitePlayer;}
      return result;
    });
  }
  async function walletOperation(tx,p,kind,args,opId,policy,identity,stamp,put) {
    const w=p.wallet,e=policy.config.economy.androidEnergyV2,b=e.simpleBonus;
    const empty=() => requireThat(Object.keys(args).length === 0,'operation_invalid',400);
    if (kind === 'energy_hidden_tap') {empty();w.energy+=20;return {energyGrant:{kind,operationId:opId,amount:20}};}
    if (kind === 'energy_bonus_claim') {
      empty();const sub=w.energySubscription;
      requireThat(!sub || sub.expiresAt > stamp || sub.endConfirmed,'subscription_verification_pending');
      requireThat(stamp >= w.simpleBonus.nextAt,'bonus_not_ready');
      const tier=sub && sub.expiresAt > stamp ? sub.batteryCount : 1;
      const amount=tier === 5 ? b.tier5Reward : tier === 2 ? b.tier2Reward : b.reward;
      w.energy+=amount;w.simpleBonus={contract:3,nextAt:stamp+b.periodSec*1000,durationMs:b.periodSec*1000,lastClaimAt:stamp};
      return {bonusClaim:{kind,operationId:opId,amount,tier,claimedAt:stamp}};
    }
    if (kind === 'google_privacy') {requireThat(typeof args.hide === 'boolean','operation_invalid',400);
      if(!args.hide)requirePublicWords(identity.name??p.publicGoogleName);
      if(!args.hide&&args.communityRulesVersion!=null){requireThat(args.communityRulesVersion===1,'community_rules_invalid',400);requireCommunityRules(p);}
      p.hideGoogleAccount=args.hide;return {};}
    if(kind==='telegram_privacy'){
      requireThat(playerPlatform(p)==='telegram'&&typeof args.hide==='boolean','operation_invalid',400);
      p.hideTelegramAccount=args.hide;return {};
    }
    if (kind === 'energy_age_completed') {empty();w.energyAgeCompleted=true;return {};}
    if (kind === 'energy_reward') {requireThat(['google','telegram','age'].includes(args.id),'legacy_operation_disabled');
      const id=args.id, claim=['survive_10s','record_20s','risks_5'].includes(id) ? id : `energy_${id}`;
      if (w.claimed.includes(claim)) return {};
      if (id === 'google') requireThat(identity.googleLinked,'bonus_locked');
      else if(id==='telegram') requireThat(identity.platform==='telegram'&&identity.telegramVerified,'bonus_locked');
      else if (id === 'age') requireThat(w.energyAgeCompleted,'bonus_locked');
      else requireThat(w.unlocked.includes(id) && ['survive_10s','record_20s','risks_5'].includes(id),'bonus_locked');
      w.energy+=e.rewards[id==='telegram'?'google':['google','age'].includes(id) ? id : 'achievement'];w.claimed.push(claim);return {};
    }
    if (kind === 'energy_feedback') {
      if (w.claimed.includes('energy_feedback')) return {};requireThat((w.feedbackSpentEnergy ?? 0) >= 100,'feedback_locked');
      const comment=typeof args.comment === 'string' ? args.comment.trim() : '';
      requireThat([...comment].length >= 20 && [...comment].length <= 1000,'feedback_length',400);
      if (args.rating != null) integer(args.rating,1,5,'feedback_rating');
      put(db.collection('feedback').doc(hash(`${p.uid}:${opId}`)),{uid:p.uid,comment,rating:args.rating ?? null,createdAt:stamp,revision:policy.revision});
      w.energy+=e.rewards.feedback;w.claimed.push('energy_feedback');return {};
    }
    if (kind === 'rewarded_ad_start' || kind === 'watch_ad') {
      // Yandex supports onRewarded, not signed server callbacks. This session
      // binds a single claim to its owner/quoted reward; it is not proof of view.
      requireThat(typeof args.sessionId === 'string','ad_session_required',400);
      const sessionId=nonce(args.sessionId);
      requireThat(Object.keys(args).length===1,'operation_invalid',400);
      const sessionRef=playerRef(p.uid).collection('adSessions').doc(sessionId);
      const saved=await tx.get(sessionRef), session=saved.exists ? saved.data() : null;
      const quota=rewardedQuota(p,b,stamp);
      if(kind==='rewarded_ad_start') {
        if(session) {
          requireThat(!session.claimedAt && stamp<session.expiresAt,'ad_session_expired');
          return {adSession:{sessionId,expiresAt:session.expiresAt,amount:session.amount}};
        }
        requireThat(b.videoReward>0,'ad_unavailable');
        requireThat(quota.remaining>0,'ad_daily_limit');
        requireThat(!w.lastAdAt || stamp-w.lastAdAt>=b.videoCooldownSec*1000,'ad_not_ready');
        const value={createdAt:stamp,expiresAt:stamp+86400000,amount:b.videoReward,revision:policy.revision,claimedAt:null};
        put(sessionRef,value);
        return {adSession:{sessionId,expiresAt:value.expiresAt,amount:value.amount}};
      }
      requireThat(session,'ad_session_invalid');
      requireThat(!session.claimedAt,'ad_session_claimed');
      requireThat(stamp<session.expiresAt,'ad_session_expired');
      requireThat(quota.remaining>0,'ad_daily_limit');
      requireThat(!w.lastAdAt || stamp-w.lastAdAt>=b.videoCooldownSec*1000,'ad_not_ready');
      w.energy+=session.amount;w.lastAdAt=stamp;
      p.adRewardsDaily={day:quota.day,count:quota.used+1};
      put(sessionRef,{...session,claimedAt:stamp,operationId:opId});
      return {adReward:{sessionId,operationId:opId,amount:session.amount}};
    }
    requireThat(false,'legacy_operation_disabled');
  }
  async function round(tx,p,input,policy,stamp,put,verifiedProofRound) {
    const start=input.action === 'round_start', finish=input.action === 'round_finish';
    const roundId=finish ? nonce(input.roundId) : hash(`${p.uid}:${nonce(input.requestId)}`);
    const rr=db.collection('rounds').doc(roundId), old=await tx.get(rr);
    if (start) {
      const fingerprint=digest({helmet:input.helmet === true,jump:input.jump === true,rulesRevision:input.rulesRevision,revision:input.revision,...([2,3].includes(input.proofVersion)?{proofVersion:input.proofVersion}:{})});
      if (old.exists) {
        const r=old.data();requireThat(r.uid === p.uid && r.fingerprint === fingerprint,'operation_conflict');
        requireThat(!r.canceled,'round_canceled');return {roundId,activated:r.activatedAt != null,finished:r.finishedAt != null,hadHelmet:r.hadHelmet,hadJump:r.hadJump,attemptCost:r.cost};
      }
      requireThat(input.rulesRevision === policy.revision,'rules_changed');
      roundProof.start(input);
      const e=policy.config.economy.androidEnergyV2;
      requireThat(!input.revision || input.revision === e.revision,'revision_mismatch');
      const hadHelmet=input.helmet === true,hadJump=input.jump === true;
      requireThat(!hadHelmet || policy.config.game.helmetEnabled !== false,'result_boost_invalid');
      requireThat(!hadJump || policy.config.game.jumpEnabled !== false,'result_boost_invalid');
      const cost=e.baseAttemptCost+(hadHelmet ? e.helmetExtraCost : 0)+(hadJump ? e.jumpExtraCost : 0);
      requireThat(p.wallet.energy >= cost,'insufficient_energy');p.wallet.energy-=cost;p.wallet.gamesStarted++;
      p.activeRound=roundId;
      put(rr,{uid:p.uid,platform:playerPlatform(p),requestId:input.requestId,proofVersion:input.proofVersion??1,fingerprint,startedAt:stamp,activatedAt:null,finishedAt:null,canceled:false,hadHelmet,hadJump,cost,policy});
      return {roundId,activated:false,finished:false,hadHelmet,hadJump,attemptCost:cost};
    }
    requireThat(old.exists && old.data().uid === p.uid,'round_not_found',404);
    const r=old.data();requireThat(!r.canceled || input.action === 'round_cancel','round_canceled');
    if (input.action === 'round_cancel') {
      requireThat(!r.activatedAt && !r.finishedAt,'round_already_started');
      if (!r.canceled) {p.wallet.energy+=r.cost;p.wallet.gamesStarted--;r.canceled=true;delete p.activeRound;put(rr,r);}
      return {canceled:true};
    }
    if (input.action === 'round_activate') {
      requireThat(!r.finishedAt,'round_already_started');
      if (!r.activatedAt) {r.activatedAt=stamp;p.wallet.feedbackSpentEnergy=(p.wallet.feedbackSpentEnergy ?? 0)+r.cost;put(rr,r);}return {activated:true};
    }
    const result={timeMs:input.timeMs,runDistance:input.runDistance,riskCount:input.riskCount,hadJump:input.hadJump === true,hadHelmet:input.hadHelmet === true};
    const resultHash=digest(result);
    if (r.finishedAt) {requireThat(r.resultHash === resultHash,'operation_conflict');return r.result;}
    requireThat(![1,2,3].includes(r.proofVersion)||verifiedProofRound===roundId,'result_proof_invalid');
    requireThat(r.activatedAt != null,'round_not_activated');
    integer(result.timeMs,1,3600000,'result_invalid');integer(result.runDistance,0,10000000,'result_invalid');integer(result.riskCount,0,10000,'result_invalid');
    if(result.timeMs > stamp-r.activatedAt+1200) {const error=new ApiError('result_time_invalid');error.retryAfterMs=result.timeMs-(stamp-r.activatedAt+1200);throw error;}
    requireThat(plausibleAndroidResult(result),'result_metrics_invalid');
    requireThat(result.hadHelmet === r.hadHelmet && result.hadJump === r.hadJump,'result_boost_invalid');
    const e=r.policy.config.economy;
    const reward=Math.floor(result.runDistance/e.runRewardEvery)+Math.floor(result.riskCount/e.riskRewardEvery);
    p.wallet.energy+=reward;p.wallet.bestTimeMs=Math.max(p.wallet.bestTimeMs,result.timeMs);p.completedGames++;
    const answer={scoreId:roundId,energyReward:reward,score:Math.round(result.timeMs/1000*result.runDistance*(1+result.riskCount))};
    put(db.collection('scores').doc(roundId),{...result,platform:r.platform??playerPlatform(p),id:roundId,userId:owner(p.uid),uid:p.uid,playerName:p.nickname,createdAt:stamp,attemptAt:r.startedAt});
    r.finishedAt=stamp;r.result=answer;r.resultHash=resultHash;put(rr,r);delete p.activeRound;
    return answer;
  }
  async function inviteState(p,identity,policy,input) {
    let query=db.collection('invitations').where('inviterUid','==',p.uid).orderBy('boundAt','desc').orderBy('__name__','desc');
    if (input.before != null) {
      requireThat(typeof input.before === 'string' && /^\d+_[A-Za-z0-9_-]+$/.test(input.before),'invite_cursor_invalid',400);
      const separator=input.before.indexOf('_'),at=Number(input.before.slice(0,separator)),id=input.before.slice(separator+1);
      requireThat(Number.isSafeInteger(at),'invite_cursor_invalid',400);query=query.startAfter(at,id);
    }
    const rows=await query.limit(51).get();
    const total=await db.collection('invitations').where('inviterUid','==',p.uid).count().get();
    const paid=[],pending=[];
    const page=rows.docs.slice(0,50);
    const invitees=page.length ? await db.getAll(...page.map(d => playerRef(d.id))) : [];
    for (let i=0;i<page.length;i++) { const doc=page[i],r=doc.data(),member=invitees[i].data();const id=BigInt('0x'+hash(doc.id).slice(0,14)).toString();
      const nickname=member?.publicNameRestricted?'Игрок':member?.nickname??null;
      if (r.rewardedAt) paid.push({id,userId:owner(doc.id),nickname,rewardedAt:r.rewardedAt,amount:r.amount,currency:'energy',energyEquivalent:r.amount});
      else pending.push({id,userId:owner(doc.id),nickname,platform:playerPlatform(member),identityReady:verifiedPlayer(member),games:Math.min(5,member?.completedGames ?? 0),googleLinked:member?.googleLinked === true,bonusStatus:(member?.completedGames ?? 0) < 5 ? 'waiting_games' : playerPlatform(member)==='telegram'?'waiting_identity':'waiting_google'});
    }
    return {profileId:owner(p.uid),ownCode:p.ownShortCode,inviteUrl:`https://untouch.fun/a/${p.ownShortCode}`,inviterAssigned:!!p.inviterUid,
      inviterCode:p.inviterCode,googleLinked:identity.googleLinked,identityReady:verifiedIdentity(identity),platform:playerPlatform(p),completedGames:Math.min(5,p.completedGames),
      bonusStatus:p.inviteRewarded ? 'rewarded' : !p.inviterUid ? 'unbound' : p.completedGames < 5 ? 'waiting_games' : playerPlatform(p)==='telegram'?'waiting_identity':'waiting_google',
      reward:policy.config.economy.androidEnergyV2.simpleBonus.inviterReward,currency:'energy',requiredGames:5,rewardTotal:p.rewardTotal,energyRewardTotal:p.rewardTotal,
      invitedCount:total.data().count,paidRows:paid,pendingRows:pending,
      nextCursor:rows.size > 50 ? `${page.at(-1).data().boundAt}_${page.at(-1).id}` : null,pendingNextCursor:null};
  }
  async function syncPlay(uid,identity,policy) {
    const player=await playerRef(uid).get(), tokenHash=player.data()?.wallet.energySubscription?.tokenHash;
    if(tokenHash) {
      const receipt=await db.collection('purchases').doc(tokenHash).get(),r=receipt.data();
      requireThat(r?.uid === uid && r.token && !r.supersededBy,'purchase_owner_invalid');
      await execute(uid,{action:'play_verify',productId:r.productId,purchaseToken:r.token},identity);
    }
    return execute(uid,{action:'profile'},identity);
  }
  async function revokePurchase(uid,token) {
    const receiptRef=db.collection('purchases').doc(hash(token));
    await db.runTransaction(async tx=>{
      const receipt=await tx.get(receiptRef),player=await tx.get(playerRef(uid));
      requireThat(receipt.exists && receipt.data().uid === uid && player.exists,'purchase_owner_invalid');
      const r=receipt.data(),p=player.data();if(r.revoked) return;
      const terms=product(r.productId);
      if(terms.kind === 'energy') p.wallet.energy=Math.max(0,p.wallet.energy-terms.amount);
      else if(p.wallet.energySubscription?.tokenHash === receiptRef.id) p.wallet.energySubscription=null;
      r.revoked=true;r.revokedAt=now();p.version++;
      tx.set(receiptRef,r);tx.set(playerRef(uid),p);
    });
  }
  return {execute,revokePurchase};
}
export {createEngine,seed,publicProfile,owner,codeFor,shortCodeFor};
