import {randomUUID} from 'node:crypto';
import {requireThat} from './core/policy.mjs';
import {patchAndroidTemplate} from './remote-config.mjs';
import {createPlatformConfigAdmin} from './platform-config-admin.mjs';
export function createConfigAdmin({db,remote,telegramStarsAccepted=false}){
  const scoped=createPlatformConfigAdmin({db,remote,telegramStarsAccepted});
  return async function execute(actor,body){
    if(body.scope!==undefined&&body.action!=='history')return scoped(actor,body);
    const permission=await db.query('select enabled from untouch.admin_users where id=$1',[actor]);
    requireThat(permission.rows[0]?.enabled===true,'admin_required',403);
    if(body.action==='history'){
      const result=await db.query('select id,status,base_version,published_version,changes,error_code,created_at,completed_at from untouch.config_audit order by created_at desc limit 50');
      return{ok:true,history:result.rows};
    }
    const current=await remote.get();
    const view=()=>({ok:true,snapshot:current.snapshot,etag:current.etag,initialized:current.initialized,version:current.template.version?.versionNumber??null});
    if(body.action==='get'){
      const draft=await db.query('select base_etag,patches,updated_at from untouch.config_drafts where actor=$1',[actor]);
      return{...view(),draft:draft.rows[0]??null};
    }
    requireThat(body.baseEtag===current.etag,'remote_config_conflict',409);
    requireThat(['save_draft','preview','publish'].includes(body.action),'action_invalid',400);
    const candidate=patchAndroidTemplate(current.template,body.patches);
    if(body.action==='save_draft'){
      await db.query('insert into untouch.config_drafts(actor,base_etag,patches) values($1,$2,$3::jsonb) on conflict(actor) do update set base_etag=excluded.base_etag,patches=excluded.patches,updated_at=now()',
        [actor,current.etag,JSON.stringify(body.patches)]);
      return{ok:true,saved:true,changes:candidate.changes};
    }
    if(body.action==='preview')return{ok:true,changes:candidate.changes,snapshot:candidate.snapshot};
    requireThat(body.confirmRevision===candidate.snapshot.revision,'preview_required',409);
    const id=randomUUID();
    await db.query('insert into untouch.config_audit(id,actor,status,base_etag,base_version,before_snapshot,after_snapshot,changes) values($1,$2,\'pending\',$3,$4,$5::jsonb,$6::jsonb,$7::jsonb)',
      [id,actor,current.etag,current.template.version?.versionNumber??null,JSON.stringify(candidate.before),JSON.stringify(candidate.snapshot),JSON.stringify(candidate.changes)]);
    try{
      const published=await remote.publish(current,body.patches);
      await db.query("update untouch.config_audit set status='published',published_version=$2,completed_at=now() where id=$1",[id,published.publishedVersion]);
      await db.query('insert into untouch.policy_revisions(revision,snapshot) values($1,$2::jsonb) on conflict(revision) do nothing',[candidate.snapshot.revision,JSON.stringify(candidate.snapshot)]);
      // A saved draft may have changed in another tab; clear only this revision.
      await db.query('delete from untouch.config_drafts where actor=$1 and base_etag=$2 and patches=$3::jsonb',[actor,current.etag,JSON.stringify(body.patches)]);
      return{ok:true,published:true,version:published.publishedVersion,revision:candidate.snapshot.revision};
    }catch(error){
      // Pending entries allow reconciliation after a lost external response;
      // never retry a publication automatically using an unconditional ETag.
      await db.query('update untouch.config_audit set error_code=$2 where id=$1',[id,error.code??'publication_outcome_unknown']).catch(()=>{});
      throw error;
    }
  };
}
