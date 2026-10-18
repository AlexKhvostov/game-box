import {hash,requireThat} from './core/policy.mjs';
const uuid=v=>typeof v==='string'&&/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/.test(v);

// Called only after support-admin has verified the administrator's identity.
export async function moderationAdmin({db,transaction,actor,body,stamp}){
  if(body.action==='moderation_list'){
    const offset=body.offset??0;
    requireThat(Number.isSafeInteger(offset)&&offset>=0&&offset<=100000,'page_invalid',400);
    const status=body.status??'pending';
    requireThat(['pending','resolved','dismissed','all'].includes(status),'status_invalid',400);
    const {rows}=await db.query(`select r.key,r.body,p.body as profile from untouch.documents r
      left join untouch.documents p on p.path='players/'||(r.body->>'targetUid')
      where r.parent='publicReports' and ($1='all' or r.body->>'status'=$1)
      order by (r.body->>'createdAt')::bigint desc,r.key limit 26 offset $2`,[status,offset]);
    return{ok:true,reports:rows.slice(0,25).map(r=>({id:r.key,targetUid:r.body.targetUid,
      content:r.body.content,reason:r.body.reason,status:r.body.status,createdAt:r.body.createdAt,
      fingerprint:r.body.fingerprint,currentNickname:r.profile?.nickname??null,
      restricted:r.profile?.publicNameRestricted===true,restrictionId:r.profile?.publicNameRestrictionId??null})),
      nextOffset:rows.length>25?offset+25:null};
  }
  requireThat(body.action==='moderation_resolve'&&uuid(body.requestId),'request_id_invalid',400);
  requireThat(typeof body.reportId==='string'&&/^[a-f0-9]{64}$/.test(body.reportId),'report_invalid',400);
  requireThat(['hide','dismiss','restore'].includes(body.decision),'decision_invalid',400);
  const fingerprint=hash({actor,reportId:body.reportId,decision:body.decision,expectedFingerprint:body.expectedFingerprint});
  return transaction(async connection=>{
    const old=await connection.query('select actor,fingerprint,details from untouch.support_actions where id=$1',[body.requestId]);
    if(old.rows.length){requireThat(old.rows[0].actor===actor&&old.rows[0].fingerprint===fingerprint,'operation_conflict',409);return{ok:true,replayed:true,...old.rows[0].details};}
    const report=await connection.query('select body from untouch.documents where path=$1 for update',[`publicReports/${body.reportId}`]);
    const r=report.rows[0]?.body;requireThat(r&&r.fingerprint===body.expectedFingerprint,'report_changed',409);
    const target=await connection.query('select body from untouch.documents where path=$1 for update',[`players/${r.targetUid}`]);
    const p=target.rows[0]?.body;
    if(body.decision!=='dismiss'){
      requireThat(p&&!p.supportDisabled,'player_not_found',404);
      if(body.decision==='hide'){
        const current={nickname:p.nickname,googleName:p.hideGoogleAccount?null:p.publicGoogleName??null};
        requireThat(hash(current)===r.fingerprint,'public_name_changed',409);
        p.publicNameRestricted=true;p.publicNameRestrictionId=body.reportId;
      }else{
        requireThat(p.publicNameRestrictionId===body.reportId,'public_name_changed',409);
        p.publicNameRestricted=false;p.publicNameRestrictionId=null;
      }
      p.version++;
      await connection.query('update untouch.documents set body=$2::jsonb,updated_at=now() where path=$1',[`players/${r.targetUid}`,JSON.stringify(p)]);
    }
    r.status=body.decision==='hide'?'resolved':'dismissed';r.resolvedAt=stamp;
    await connection.query('update untouch.documents set body=$2::jsonb,updated_at=now() where path=$1',[`publicReports/${body.reportId}`,JSON.stringify(r)]);
    const details={decision:body.decision,reportId:body.reportId};
    await connection.query("insert into untouch.support_actions(id,actor,target,kind,fingerprint,status,details,completed_at) values($1,$2,$3,'public_name_moderation',$4,'completed',$5::jsonb,now())",[body.requestId,actor,r.targetUid,fingerprint,JSON.stringify(details)]);
    return{ok:true,...details};
  });
}
