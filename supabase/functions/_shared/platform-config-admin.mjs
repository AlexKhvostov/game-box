import {randomUUID} from 'node:crypto';
import {requireThat} from './core/policy.mjs';
import {patchScopedTemplate,readPlatformTemplate,scopedView,materializePlatform} from './platform-config.mjs';

// Uses the existing administrator membership, publication audit and Firebase ETag.
export function createPlatformConfigAdmin({db,remote,telegramStarsAccepted=false}){
  return async(actor,body)=>{
    const permission=await db.query('select enabled from untouch.admin_users where id=$1',[actor]);
    requireThat(permission.rows[0]?.enabled===true,'admin_required',403);
    requireThat(['common','android','telegram'].includes(body.scope),'platform_invalid',400);
    const current=await remote.get(),envelope=readPlatformTemplate(current.template,current.snapshot);
    if(body.action==='get'){
      const draft=await db.query('select base_etag,patches,updated_at from untouch.config_scoped_drafts where actor=$1 and scope=$2',[actor,body.scope]);
      return{ok:true,scope:body.scope,snapshot:scopedView(envelope,body.scope),etag:current.etag,initialized:current.initialized,
        version:current.template.version?.versionNumber??null,draft:draft.rows[0]??null};
    }
    requireThat(body.baseEtag===current.etag,'remote_config_conflict',409);
    requireThat(['save_draft','preview','publish'].includes(body.action),'action_invalid',400);
    const candidate=patchScopedTemplate(current.template,current.snapshot,body.scope,body.patches,{telegramStarsAccepted});
    if(body.action==='save_draft'){
      await db.query('insert into untouch.config_scoped_drafts(actor,scope,base_etag,patches) values($1,$2,$3,$4::jsonb) on conflict(actor,scope) do update set base_etag=excluded.base_etag,patches=excluded.patches,updated_at=now()',
        [actor,body.scope,current.etag,JSON.stringify(body.patches)]);
      return{ok:true,saved:true,changes:candidate.changes};
    }
    if(body.action==='preview')return{ok:true,scope:body.scope,snapshot:candidate.snapshot,changes:candidate.changes};
    requireThat(body.confirmRevision===candidate.snapshot.revision,'preview_required',409);
    const id=randomUUID();
    await db.query("insert into untouch.config_audit(id,actor,status,base_etag,base_version,before_snapshot,after_snapshot,changes) values($1,$2,'pending',$3,$4,$5::jsonb,$6::jsonb,$7::jsonb)",
      [id,actor,current.etag,current.template.version?.versionNumber??null,JSON.stringify(candidate.before),JSON.stringify(candidate.snapshot),JSON.stringify(candidate.changes)]);
    try{
      const published=await remote.publishScoped(current,body.scope,body.patches);
      await db.query("update untouch.config_audit set status='published',published_version=$2,completed_at=now() where id=$1",[id,published.publishedVersion]);
      for(const platform of ['android','telegram']){
        const snapshot=materializePlatform(candidate.envelope,platform);
        await db.query('insert into untouch.policy_revisions(revision,snapshot) values($1,$2::jsonb) on conflict(revision) do nothing',[snapshot.revision,JSON.stringify(snapshot)]);
      }
      await db.query('delete from untouch.config_scoped_drafts where actor=$1 and scope=$2 and base_etag=$3 and patches=$4::jsonb',[actor,body.scope,current.etag,JSON.stringify(body.patches)]);
      return{ok:true,published:true,scope:body.scope,version:published.publishedVersion,revision:candidate.snapshot.revision};
    }catch(error){
      await db.query('update untouch.config_audit set error_code=$2 where id=$1',[id,error.code??'publication_outcome_unknown']).catch(()=>{});throw error;
    }
  };
}
