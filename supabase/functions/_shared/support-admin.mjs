import {hash,requireThat,ApiError} from './core/policy.mjs';
import {publicNickname} from './public-content.mjs';
import {moderationAdmin} from './moderation-admin.mjs';
const uuid=value=>typeof value==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(value);
export const supportReasons={compensation:'Компенсация по обращению',correction:'Исправление баланса',testing:'Проверка игры'};
export function createSupportAdmin({db,auth,now=Date.now}){
  async function admin(actor){const result=await db.query('select enabled from untouch.admin_users where id=$1',[actor]);requireThat(result.rows[0]?.enabled===true,'admin_required',403);}
  async function transaction(callback){
    const connection=await db.connect();try{await connection.query('begin isolation level serializable');await connection.query("set local statement_timeout='8000ms'");const result=await callback(connection);await connection.query('commit');return result;}
    catch(error){await connection.query('rollback').catch(()=>{});if(['40001','40P01','23505'].includes(error.code))throw new ApiError('support_conflict',409);throw error;}finally{connection.release();}
  }
  async function authUser(uid){const {data,error}=await auth.getUserById(uid);if(error&&error.status!==404)throw new ApiError('auth_lookup_unavailable',503);return data?.user??null;}
  function summary(row,user){const p=row.body??{},subscription=p.wallet?.energySubscription;const google=user?.identities?.find(i=>i.provider==='google');return{
    id:row.key,nickname:p.nickname??google?.identity_data?.full_name??'Аккаунт без игрового профиля',energy:p.wallet?.energy??0,version:p.version??0,createdAt:p.createdAt??user?.created_at??row.created_at??null,
    lastActiveAt:p.lastActiveAt??p.createdAt??null,platform:row.platform??p.platform??'android',telegramUsername:p.telegramUsername??row.telegram_username??null,googleLinked:!!google,email:google?.identity_data?.email??null,
    completedGames:p.completedGames??0,bestTimeMs:Number.isSafeInteger(p.wallet?.bestTimeMs)&&p.wallet.bestTimeMs>=0?p.wallet.bestTimeMs:0,
    status:p.supportDisabled?'deleting':!row.body?'not_started':user||p.platform==='telegram'&&p.telegramVerified?'active':'auth_missing',
    subscription:subscription?{tier:subscription.batteryCount,expiresAt:subscription.expiresAt,awaitingReconciliation:!subscription.endConfirmed&&subscription.expiresAt<=now()}:null
  };}
  async function player(uid,connection=db){const result=await connection.query("select key,body,updated_at from untouch.documents where path=$1",[`players/${uid}`]);requireThat(result.rows[0],'player_not_found',404);return result.rows[0];}
  return async function execute(actor,body){
    await admin(actor);
    if(['moderation_list','moderation_resolve'].includes(body.action))return moderationAdmin({db,transaction,actor,body,stamp:now()});
    if(body.action==='feedback_list'){
      const search=(body.search??''),offset=body.offset??0,rating=body.rating??null;
      requireThat(typeof search==='string'&&search.length<=160,'search_invalid',400);
      requireThat(Number.isSafeInteger(offset)&&offset>=0&&offset<=100000,'page_invalid',400);
      requireThat(rating===null||rating==='unrated'||(Number.isInteger(rating)&&rating>=1&&rating<=5),'rating_invalid',400);
      const filter=" from untouch.documents f left join untouch.documents p on p.path='players/'||(f.body->>'uid') where f.parent='feedback' and ($1='' or position(lower($1) in lower(concat_ws(' ',f.body->>'uid',p.body->>'nickname',f.body->>'comment')))>0) and ($2::text is null or coalesce(f.body->>'rating','unrated')=$2)";
      const args=[search.trim(),rating===null?null:String(rating)];
      const count=await db.query('select count(*)::integer as total'+filter,args);
      const rows=await db.query('select f.key,f.body,p.body as profile'+filter+" order by (f.body->>'createdAt')::bigint desc,f.key desc limit 26 offset $3",[...args,offset]);
      const identities=new Map(),feedback=[];
      for(const row of rows.rows.slice(0,25)){
        const uid=row.body.uid;
        if(!identities.has(uid))identities.set(uid,uuid(uid)&&row.profile?.platform!=='telegram'?await authUser(uid):null);
        const user=identities.get(uid),google=user?.identities?.find(i=>i.provider==='google');
        feedback.push({id:row.key,userId:uid,nickname:row.profile?.nickname??'Игрок без профиля',email:google?.identity_data?.email??null,
          userAvailable:!!row.profile||!!user,comment:row.body.comment,rating:row.body.rating??null,createdAt:row.body.createdAt});
      }
      return{ok:true,feedback,total:count.rows[0].total,nextOffset:rows.rows.length>25?offset+25:null};
    }
    if(body.action==='list'){
      requireThat(typeof (body.search??'')==='string'&&(body.search??'').length<=160,'search_invalid',400);
      requireThat(Number.isSafeInteger(body.offset??0)&&(body.offset??0)>=0&&(body.offset??0)<=100000,'page_invalid',400);
      const options={search:(body.search??'').trim(),offset:body.offset??0,platform:body.platform??'all',connection:body.connection??'all',status:body.status??'all',subscription:body.subscription??'all',sort:body.sort??'created',direction:body.direction??'desc',now:now()};
      for(const [key,allowed] of Object.entries({platform:['all','android','telegram'],connection:['all','google','guest','telegram'],status:['all','active','not_started','deleting','auth_missing'],subscription:['all','active','without','pending','expired','none'],sort:['created','nickname','energy','games','activity','record'],direction:['asc','desc']}))requireThat(allowed.includes(options[key]),'filter_invalid',400);
      // A private SQL directory must sort the complete matching set before LIMIT;
      // sorting a returned JavaScript page would hide higher records on later pages.
      const query=options.sort==='record'?'select untouch.support_directory_v4($1::jsonb) as directory':body.platform===undefined?'select untouch.support_directory_v2($1::jsonb) as directory':'select untouch.support_directory_v3($1::jsonb) as directory';
      const result=await db.query(query,[JSON.stringify(options)]);
      const directory=result.rows[0].directory;
      const users=directory.rows.slice(0,25).map(row=>summary({key:row.id,body:row.body,created_at:row.created_at,platform:row.platform,telegram_username:row.telegram_username},row.status==='auth_missing'?null:{created_at:row.created_at,identities:row.google?[{provider:'google',identity_data:row.google}]:[]}));
      return{ok:true,users,total:Number(directory.total),nextOffset:directory.rows.length>25?options.offset+25:null};
    }
    requireThat(uuid(body.userId),'user_id_invalid',400);
    if(body.action==='detail'||body.action==='delete_preview'){
      const profile=await db.query('select key,body,updated_at from untouch.documents where path=$1',[`players/${body.userId}`]);
      const row=profile.rows[0]??{key:body.userId,body:null},user=row.body?.platform==='telegram'?null:await authUser(body.userId);
      requireThat(row.body||user,'player_not_found',404);
      const activity=await db.query('select id,actor,kind,status,details,created_at from untouch.support_actions where target=$1 order by created_at desc limit 20',[body.userId]);
      const scoreCount=await db.query("select count(*)::integer as count from untouch.documents where parent='scores' and body->>'uid'=$1",[body.userId]);
      const feedback=await db.query("select body->>'comment' as comment,body->'rating' as rating,body->'createdAt' as created_at from untouch.documents where parent='feedback' and body->>'uid'=$1 order by (body->>'createdAt')::bigint desc limit 10",[body.userId]);
      const protectedUser=await db.query('select id from untouch.admin_users where id=$1',[body.userId]);
      const pending=activity.rows.find(item=>item.kind==='delete_user'&&item.status==='pending');
      return{ok:true,user:summary(row,user),activity:activity.rows,feedback:feedback.rows,feedbackSpentEnergy:row.body?.wallet?.feedbackSpentEnergy??0,scoreCount:scoreCount.rows[0].count,
        pendingDelete:pending?.actor===actor?{requestId:pending.id,expectedVersion:pending.details.expectedVersion}:null,
        deleteAllowed:actor!==body.userId&&!protectedUser.rows.length&&(!pending||pending.actor===actor)};
    }
    requireThat(uuid(body.requestId),'request_id_invalid',400);
    requireThat(['set_energy','set_nickname','delete_user'].includes(body.action),'action_invalid',400);
    const {userId,requestId}=body;
    const fingerprint=hash(JSON.stringify({actor,userId,action:body.action,energy:body.energy,nickname:body.nickname,reason:body.reason,expectedVersion:body.expectedVersion,confirmation:body.confirmation}));
    if(body.action==='set_nickname'){
      const nickname=publicNickname(body.nickname),nameKey=hash(nickname.toLocaleLowerCase('ru'));
      return transaction(async connection=>{
        const previous=await connection.query('select actor,fingerprint,details from untouch.support_actions where id=$1',[requestId]);
        if(previous.rows.length){requireThat(previous.rows[0].actor===actor&&previous.rows[0].fingerprint===fingerprint,'operation_conflict',409);return{ok:true,replayed:true,...previous.rows[0].details};}
        const locked=await connection.query('select body from untouch.documents where path=$1 for update',[`players/${userId}`]);const p=locked.rows[0]?.body;
        requireThat(p,'player_not_found',404);requireThat(!p.supportDisabled,'profile_disabled',409);requireThat(p.version===body.expectedVersion,'support_conflict',409);
        const taken=await connection.query('select body from untouch.documents where path=$1 for update',[`names/${nameKey}`]);
        requireThat(!taken.rows.length||taken.rows[0].body.uid===userId,'nickname_taken',409);
        const details={before:p.nickname,after:nickname};
        await connection.query("insert into untouch.documents(path,parent,key,body) values($1,'names',$2,$3::jsonb) on conflict(path) do update set body=excluded.body,updated_at=now()",[`names/${nameKey}`,nameKey,JSON.stringify({uid:userId})]);
        if(p.nameKey&&p.nameKey!==nameKey)await connection.query("delete from untouch.documents where path=$1 and body->>'uid'=$2",[`names/${p.nameKey}`,userId]);
        p.nickname=nickname;p.nameKey=nameKey;p.version++;
        await connection.query('update untouch.documents set body=$2::jsonb,updated_at=now() where path=$1',[`players/${userId}`,JSON.stringify(p)]);
        await connection.query("insert into untouch.support_actions(id,actor,target,kind,fingerprint,status,details,completed_at) values($1,$2,$3,'set_nickname',$4,'completed',$5::jsonb,now())",[requestId,actor,userId,fingerprint,JSON.stringify(details)]);
        return{ok:true,...details};
      });
    }
    if(body.action==='set_energy'){
      requireThat(Number.isSafeInteger(body.energy)&&body.energy>=0&&body.energy<=1000000,'energy_invalid',400);
      requireThat(Object.hasOwn(supportReasons,body.reason),'support_reason_required',400);
      return transaction(async connection=>{
        const previous=await connection.query('select actor,fingerprint,details from untouch.support_actions where id=$1',[requestId]);
        if(previous.rows.length){requireThat(previous.rows[0].actor===actor&&previous.rows[0].fingerprint===fingerprint,'operation_conflict',409);return{ok:true,replayed:true,...previous.rows[0].details};}
        const locked=await connection.query('select body from untouch.documents where path=$1 for update',[`players/${userId}`]);const p=locked.rows[0]?.body;
        requireThat(p,'player_not_found',404);requireThat(!p.supportDisabled,'profile_disabled',409);requireThat(p.version===body.expectedVersion,'support_conflict',409);
        const details={before:p.wallet.energy,after:body.energy,delta:body.energy-p.wallet.energy,reason:body.reason};p.wallet.energy=body.energy;p.version++;
        await connection.query('update untouch.documents set body=$2::jsonb,updated_at=now() where path=$1',[`players/${userId}`,JSON.stringify(p)]);
        await connection.query("insert into untouch.support_actions(id,actor,target,kind,fingerprint,status,details,completed_at) values($1,$2,$3,'set_energy',$4,'completed',$5::jsonb,now())",[requestId,actor,userId,fingerprint,JSON.stringify(details)]);
        return{ok:true,...details};
      });
    }
    requireThat(actor!==userId,'cannot_delete_administrator',409);
    const protectedUser=await db.query('select id from untouch.admin_users where id=$1',[userId]);requireThat(!protectedUser.rows.length,'cannot_delete_administrator',409);
    const deletionProfile=await db.query('select body from untouch.documents where path=$1',[`players/${userId}`]);
    const targetAuth=deletionProfile.rows[0]?.body?.platform==='telegram'?null:await authUser(userId);
    const started=await transaction(async connection=>{
      const previous=await connection.query('select actor,fingerprint,status from untouch.support_actions where id=$1',[requestId]);
      if(previous.rows.length){requireThat(previous.rows[0].actor===actor&&previous.rows[0].fingerprint===fingerprint,'operation_conflict',409);return previous.rows[0].status;}
      const locked=await connection.query('select body from untouch.documents where path=$1 for update',[`players/${userId}`]);
      requireThat(locked.rows[0]||targetAuth,'player_not_found',404);
      const p=locked.rows[0]?.body??{uid:userId,version:0};
      requireThat(!p.supportDisabled,'deletion_already_pending',409);requireThat(p.version===body.expectedVersion,'support_conflict',409);
      requireThat(body.confirmation===userId&&body.acceptSubscriptionNotice===true,'delete_confirmation_required',400);
      p.supportDisabled=true;p.version++;
      await connection.query("insert into untouch.documents(path,parent,key,body) values($1,'players',$2,$3::jsonb) on conflict(path) do update set body=excluded.body,updated_at=now()",[`players/${userId}`,userId,JSON.stringify(p)]);
      await connection.query("insert into untouch.support_actions(id,actor,target,kind,fingerprint,status,details) values($1,$2,$3,'delete_user',$4,'pending',$5::jsonb)",[requestId,actor,userId,fingerprint,JSON.stringify({expectedVersion:body.expectedVersion})]);return'pending';
    });
    if(started==='completed')return{ok:true,deleted:true,replayed:true};
    const targetProfile=await db.query('select body from untouch.documents where path=$1',[`players/${userId}`]);
    if(targetProfile.rows[0]?.body?.platform!=='telegram'){
      const removal=await auth.deleteUser(userId);requireThat(!removal.error||removal.error.status===404,'auth_delete_unavailable',503);
    }
    await transaction(async connection=>{
      // Keep receipt hashes as anonymous anti-replay tombstones. Delete raw
      // store tokens and links to the removed user; no automatic Play refund.
      await connection.query("update untouch.documents set body=jsonb_build_object('deleted',true,'revoked',true,'acknowledged',true),updated_at=now() where parent='purchases' and body->>'uid'=$1",[userId]);
      await connection.query("update untouch.documents set body=jsonb_build_object('deleted',true,'revoked',true,'acknowledged',true),updated_at=now() where parent in ('telegramOrders','telegramCharges') and body->>'uid'=$1",[userId]);
      await connection.query('delete from untouch.external_identities where uid=$1::uuid',[userId]);
      await connection.query("delete from untouch.documents where path=$1 or parent=$1||'/operations' or parent=$1||'/quotes' or (parent<>'purchases' and (body->>'uid'=$2 or body->>'inviteeUid'=$2 or (parent='invitations' and body->>'inviterUid'=$2)))",[`players/${userId}`,userId]);
      await connection.query("delete from untouch.documents where parent='publicReports' and (body->>'reporterUid'=$1 or body->>'targetUid'=$1)",[userId]);
      await connection.query(`update untouch.documents p set body=jsonb_set(p.body,'{hiddenPlayers}',
        coalesce((select jsonb_agg(v) from jsonb_array_elements(p.body->'hiddenPlayers') v where v<>to_jsonb($1::text)),'[]'::jsonb)),updated_at=now()
        where p.parent='players' and p.body->'hiddenPlayers' ? $1`,[userId]);
      await connection.query("update untouch.documents set body=jsonb_set(jsonb_set(body,'{inviterUid}','\"deleted\"'),'{inviterCode}','\"XXXXXXXXXXXX\"'),updated_at=now() where parent='players' and body->>'inviterUid'=$1",[userId]);
      await connection.query("update untouch.support_actions set status='completed',completed_at=now() where id=$1",[requestId]);
    });return{ok:true,deleted:true};
  };
}
