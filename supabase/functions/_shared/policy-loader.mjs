import {requireThat} from './core/policy.mjs';
// A successful admin publication invalidates a warm Edge instance immediately.
// Direct Firebase-console changes are still discovered by the bounded cache.
export function createPolicyLoader({pool,remote,now=Date.now,maxAgeMs=300000}){
  const cache=new Map(),loads=new Map();
  const load=async(platform='android')=>{
    requireThat(['android','telegram'].includes(platform),'platform_invalid',400);
    const latest=await pool.query("select id from untouch.config_audit where status='published' order by completed_at desc,id desc limit 1");
    const auditId=latest.rows[0]?.id??null;
    const cached=cache.get(platform);
    if(cached&&cached.auditId===auditId&&now()-cached.at<maxAgeMs)return cached.snapshot;
    if(!loads.has(platform))loads.set(platform,(async()=>{
      const result=await (remote.getPlatform?remote.getPlatform(platform):remote.get());requireThat(result.initialized,'android_policy_not_published',503);
      await pool.query('insert into untouch.policy_revisions(revision,snapshot) values($1,$2::jsonb) on conflict(revision) do nothing',[result.snapshot.revision,JSON.stringify(result.snapshot)]);
      cache.set(platform,{at:now(),snapshot:result.snapshot,platformConfig:result.platformConfig??null,auditId});return result.snapshot;
    })().finally(()=>{loads.delete(platform);}));
    return loads.get(platform);
  };
  load.platformSettings=async platform=>{await load(platform);return structuredClone(cache.get(platform).platformConfig);};
  return load;
}
