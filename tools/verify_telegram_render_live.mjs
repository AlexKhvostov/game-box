import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'..'),origin='https://untouch-telegram-app.onrender.com';
const [release,commit]=process.argv.slice(2);
assert.match(release??'',/^vue-v\d+\.\d+\.\d+_\d{8}_\d{6}_\d{3}$/);assert.match(commit??'',/^[a-f0-9]{40}$/);
const manifest=JSON.parse((await fs.readFile(path.join(root,'releases',release,'manifest.json'),'utf8')).replace(/^\uFEFF/,''));
const expectedVersion=JSON.parse((await fs.readFile(path.join(root,'releases',release,'site/version.json'),'utf8')).replace(/^\uFEFF/,''));
const api='https://exinizzxqtjnysgibide.supabase.co/functions/v1/telegram-api';
const sha=b=>createHash('sha256').update(b).digest('hex');
const results=[];let cursor=0;
await Promise.all(Array.from({length:4},async()=>{
  while(cursor<manifest.files.length){
    const file=manifest.files[cursor++];
    const response=await fetch(`${origin}/${file.path}`,{signal:AbortSignal.timeout(30000)});
    assert.equal(response.status,200,file.path);
    const bytes=Buffer.from(await response.arrayBuffer());
    if(file.path==='version.json'){
      const v=JSON.parse(bytes.toString());assert.equal(v.version,manifest.version);assert.equal(v.commit,commit);assert.equal(v.paymentsEnabled,false);assert.equal(v.apiUrl,api);assert.equal(v.qa,manifest.qa);assert.equal(v.appUrl,expectedVersion.appUrl);
    }else if(sha(bytes)!==file.sha256){
      assert.equal(path.extname(file.path),'.png',file.path);
      // The CDN may recompress PNGs and normalize invisible RGB at alpha=0.
      // Accept only identical dimensions, alpha and visible composites, never an arbitrary hash mismatch.
      const comparison=spawnSync('python',['-c',`import sys,io
from PIL import Image,ImageChops
a=Image.open(sys.argv[1]).convert('RGBA'); b=Image.open(io.BytesIO(sys.stdin.buffer.read())).convert('RGBA')
assert a.size==b.size
assert ImageChops.difference(a.getchannel('A'),b.getchannel('A')).getbbox() is None
for color in ['black','white']:
 bg=Image.new('RGBA',a.size,color)
 assert ImageChops.difference(Image.alpha_composite(bg,a).convert('RGB'),Image.alpha_composite(bg,b).convert('RGB')).getbbox() is None
print('pixel-equivalent')`,path.join(root,'releases',release,'site',file.path)],{input:bytes});
      assert.equal(comparison.status,0,`${file.path}: visible PNG pixels differ`);
    }
    results.push({path:file.path,status:200,sha256:sha(bytes),identicalBytes:sha(bytes)===file.sha256,pixelEquivalent:file.path.endsWith('.png')?true:undefined,type:response.headers.get('content-type')});
  }
}));
const probe=async(method,requestOrigin,body)=>{
  const r=await fetch(api,{method,headers:{Origin:requestOrigin,'Content-Type':'application/json',...(method==='OPTIONS'?{'Access-Control-Request-Method':'POST'}:{})},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(30000)});
  return {status:r.status,allowOrigin:r.headers.get('access-control-allow-origin'),body:method==='OPTIONS'?null:await r.json()};
};
const preflight=await probe('OPTIONS',origin);assert.equal(preflight.status,204);assert.equal(preflight.allowOrigin,origin);
const badOrigin=await probe('POST','https://example.org',{action:'guest'});assert.equal(badOrigin.status,403);assert.equal(badOrigin.body.error,'origin_denied');assert.equal(badOrigin.allowOrigin,null);
const noAuth=await probe('POST',origin,{action:'guest'});assert.equal(noAuth.status,401);assert.equal(noAuth.body.error,'telegram_unauthorized');
const report={ok:true,createdAt:new Date().toISOString(),origin,release,staticFiles:results.sort((a,b)=>a.path.localeCompare(b.path)),
  identicalReleaseFiles:results.filter(r=>r.identicalBytes).length,pixelEquivalentPngs:results.filter(r=>r.pixelEquivalent&&!r.identicalBytes).length,versionMetadataVerified:true,preflight,badOrigin,noAuth,paymentWebhookDeployed:false,nativeVerified:false};
const directory=path.join(root,'docs/release-evidence/telegram-port/render');await fs.mkdir(directory,{recursive:true});
await fs.writeFile(path.join(directory,'live-delivery.json'),JSON.stringify(report,null,2)+'\n');
await fs.writeFile(path.join(directory,`live-delivery-${manifest.version}.json`),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({ok:true,staticFiles:results.length,identicalReleaseFiles:report.identicalReleaseFiles,pixelEquivalentPngs:report.pixelEquivalentPngs,version:manifest.version,preflight:preflight.status,badOrigin:badOrigin.status,noAuth:noAuth.status,nativeVerified:false}));
