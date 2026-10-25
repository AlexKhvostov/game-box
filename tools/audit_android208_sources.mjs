// Read-only audit of an immutable release checkpoint and local branch contributions.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
const root=process.cwd();
const output=process.argv[2];
if(!output)throw Error('Output JSON path required');
const git=(...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8',maxBuffer:16*1024*1024}).trim();
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p))).digest('hex');
const checkpoint=JSON.parse(fs.readFileSync('docs/release-evidence/google-play-final-internal-20261025/android-source-checkpoint.json','utf8'));
const changed=checkpoint.files.filter(f=>!fs.existsSync(f.path)||sha(f.path)!==f.sha256).map(f=>f.path);
const runtimePaths=git('ls-files','--cached','--others','--exclude-standard','--','lib','assets').split('\n').filter(Boolean);
const added=runtimePaths.filter(p=>!checkpoint.files.some(f=>f.path===p));
const branches=['codex/android-appmetrica','codex/android-helmet-recharge','codex/android-brake-speed','cursor/life-packs-rc-override','codex/telegram-render'];
const contributions=branches.map(branch=>{
 let base;try{base=git('merge-base','HEAD',branch);}catch{return{branch,head:git('rev-parse',branch),base:null,uniqueCommits:[],inspected:[],note:'Independent deployment history; no common ancestor, not an Android implementation branch'};}
 const files=git('diff','--name-only',base,branch).split('\n').filter(Boolean);
 const inspected=files.filter(p=>/^(lib\/|assets\/|android\/|test\/|supabase\/functions\/|supabase\/test\/|admin-console\/src\/|tools\/|pubspec\.)/.test(p)).map(p=>{
  let branchBytes;try{branchBytes=execFileSync('git',['show',`${branch}:${p}`],{cwd:root,maxBuffer:16*1024*1024});}catch{return{path:p,status:'deleted-in-branch'};}
  const exists=fs.existsSync(p);const equal=exists&&fs.readFileSync(p).equals(branchBytes);
  return{path:p,status:equal?'identical':exists?'modified-after-integration':'missing'};
 });
 return{branch,head:git('rev-parse',branch),base,uniqueCommits:git('log','--format=%h %s',`HEAD..${branch}`).split('\n').filter(Boolean),inspected};
});
const artifacts=['releases/android-v1.0.207_20261025_024737_584/Untouch-1.0.207+208.aab','releases/android-v1.0.207_20261025_024245_355/Untouch-1.0.207+208.apk'].map(p=>({path:p,sha256:sha(p),bytes:fs.statSync(p).size}));
const result={checkedAt:new Date().toISOString(),branch:git('branch','--show-current'),head:git('rev-parse','HEAD'),checkpointFiles:checkpoint.files.length,changedSince208:changed,addedSince208:added,artifacts,contributions};
fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(result,null,2));
console.log(JSON.stringify({...result,contributions:contributions.map(c=>({...c,inspected:undefined,counts:c.inspected.reduce((a,f)=>(a[f.status]=(a[f.status]||0)+1,a),{}),differences:c.inspected.filter(f=>f.status!=='identical')}))},null,2));
