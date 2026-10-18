import {requireThat} from './core/policy.mjs';
// A successful admin publication invalidates a warm Edge instance immediately.
// Direct Firebase-console changes are still discovered by the bounded cache.
export function createPolicyLoader({pool,remote,now=Date.now,maxAgeMs=300000}){
  let cached,loading;
  return async()=>{
    const latest=await pool.query("select id from untouch.config_audit where status='published' order by completed_at desc,id desc limit 1");
    const auditId=latest.rows[0]?.id??null;
    if(cached&&cached.auditId===auditId&&now()-cached.at<maxAgeMs)return cached.snapshot;
    if(!loading)loading=(async()=>{
      const result=await remote.get();requireThat(result.initialized,'android_policy_not_published',503);
      await pool.query('insert into untouch.policy_revisions(revision,snapshot) values($1,$2::jsonb) on conflict(revision) do nothing',[result.snapshot.revision,JSON.stringify(result.snapshot)]);
      cached={at:now(),snapshot:result.snapshot,auditId};return result.snapshot;
    })().finally(()=>{loading=null;});
    return loading;
  };
}
