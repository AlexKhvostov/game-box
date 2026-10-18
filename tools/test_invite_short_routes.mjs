// Synthetic local checks only: browser redirect VM, loopback PHP, native contract/JVM regex.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import net from 'node:net';
import os from 'node:os';
import {spawn,spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
const results=[];
const check=(name,callback)=>{callback();results.push({name,pass:true});};
const script=fs.readFileSync('supabase/hosting/invite.js','utf8');
const codes=['ABC234','ABCDEFGH2345'];
function browser(pathname,search='',hash=''){
  const elements={play:{hidden:true},message:{textContent:''}},redirects=[];
  vm.runInNewContext(script,{URL,document:{getElementById:id=>elements[id]},location:{pathname,search,hash,replace:value=>redirects.push(value)}});
  return{elements,redirects};
}
for(const code of codes){
  check(`browser ${code.length} fixed Play/referrer`,()=>{
    const result=browser(`/a/${code.toLowerCase()}/`),target=new URL(result.redirects[0]);
    assert.equal(target.origin,'https://play.google.com');assert.equal(target.pathname,'/store/apps/details');
    assert.equal(target.searchParams.get('id'),'com.best4u.untouch');assert.equal(target.searchParams.get('referrer'),`invite=${code}`);
    assert.equal(result.elements.play.hidden,false);
  });
}
for(const pathname of ['/a/ABCDE','/a/ABCDEFG','/a/ABCDEFGH','/a/ABCDEFGH234','/a/ABC01I','/a/ABCDEſ','/a/%41BC234','/i/ABC234','/a/ABC234/evil']){
  check(`browser rejects ${pathname}`,()=>assert.equal(browser(pathname).redirects.length,0));
}
for(const [query,fragment]of [['?to=https://evil.invalid',''],['','#invite']])check('browser rejects query/fragment',()=>assert.equal(browser('/a/ABC234',query,fragment).redirects.length,0));
const ht=fs.readFileSync('telegram-web/landing/.htaccess','utf8');
check('Apache route only exact 6/12, fixed target and no appended query',()=>{
  const line=ht.split(/\r?\n/).find(l=>l.includes('RewriteRule'));
  assert.ok(line.endsWith('invite.php?code=$1 [L,NC]'));
  const route=new RegExp(line.trim().split(' ')[1],'i');
  for(const code of codes)assert.ok(route.test(`a/${code}`));
  for(const code of ['ABCDE','ABCDEFG','ABCDEFGH','ABCDEFGH234','ABC01I'])assert.ok(!route.test(`a/${code}`));
});
const kotlin=fs.readFileSync('android/app/src/main/kotlin/com/boxgame/game_box/AndroidInvites.kt','utf8');
const pattern=kotlin.match(/allowedPath = Regex\("([^"]+)"/)[1];
check('native retains exact host/scheme/port/user/query/fragment and encoded path guards',()=>{
  for(const guard of ['uri.scheme != "https"','uri.host !in setOf("untouch.fun", "untouch-android-game-box-b30d4.web.app")','uri.port != -1','uri.userInfo != null','uri.query != null','uri.fragment != null','allowedPath.matches(uri.encodedPath'])assert.ok(kotlin.includes(guard),guard);
});
const manifest=fs.readFileSync('android/app/src/main/AndroidManifest.xml','utf8');
check('two independent autoVerify filters',()=>{
  const filters=[...manifest.matchAll(/<intent-filter android:autoVerify="true">([\s\S]*?)<\/intent-filter>/g)].map(m=>m[1]);
  assert.equal(filters.length,2);
  for(const host of ['untouch.fun','untouch-android-game-box-b30d4.web.app'])assert.equal(filters.filter(f=>f.includes(`android:host="${host}"`)&&f.includes('android:pathPrefix="/a/"')).length,1);
  assert.ok(filters.every(f=>(f.match(/<data /g)||[]).length===1));
});
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'untouch-invite-route-'));
let php;
try{
  const java=process.env.INVITE_TEST_JAVA||'C:/Program Files/Android/Android Studio/jbr/bin/java.exe';
  const source=path.join(temp,'NativeInviteRegex.java');
  fs.writeFileSync(source,`import java.util.regex.Pattern; class NativeInviteRegex {public static void main(String[] a){Pattern p=Pattern.compile(${JSON.stringify(pattern)},Pattern.CASE_INSENSITIVE);for(String s:new String[]{"ABC234","abcdefgh2345"})if(!p.matcher("/a/"+s).matches())throw new Error(s);for(String s:new String[]{"ABCDE","ABCDEFG","ABCDEFGH","ABCDEFGH234","ABC01I","ABCDEſ","%41BC234"})if(p.matcher("/a/"+s).matches())throw new Error(s);}}`);
  const compiled=spawnSync(java,[source],{encoding:'utf8'});
  check('actual JVM native regex accepts 6/12, rejects middle lengths/Unicode/encoding',()=>assert.equal(compiled.status,0,compiled.stderr));
  const server=net.createServer();await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const port=server.address().port;await new Promise(resolve=>server.close(resolve));
  php=spawn(process.env.INVITE_TEST_PHP||'C:/xampp/php/php.exe',['-S',`127.0.0.1:${port}`,'-t','telegram-web/landing'],{stdio:'ignore',windowsHide:true});
  const base=`http://127.0.0.1:${port}/invite.php`;
  let ready=false;
  for(let i=0;i<30;i++){try{await fetch(base);ready=true;break;}catch{await new Promise(resolve=>setTimeout(resolve,100));}}
  assert.ok(ready,'PHP loopback server started');
  for(const code of codes){
    const response=await fetch(`${base}?code=${code.toLowerCase()}`,{redirect:'manual'});
    check(`PHP actual HTTP ${code.length} fixed encoded referrer`,()=>{
      assert.equal(response.status,302);const url=new URL(response.headers.get('location'));
      assert.equal(url.origin,'https://play.google.com');assert.equal(url.searchParams.get('id'),'com.best4u.untouch');assert.equal(url.searchParams.get('referrer'),`invite=${code}`);
      assert.equal(response.headers.get('cache-control'),'no-store');
    });
  }
  for(const query of ['code=ABCDE','code=ABCDEFG','code=ABCDEFGH234','code=ABC01I','code=%3Cscript%3E','code[]=ABC234','code=ABC234%26to%3Dhttps%3A%2F%2Fevil.invalid']){
    const response=await fetch(`${base}?${query}`,{redirect:'manual'});
    check(`PHP invalid ${query}`,()=>{assert.equal(response.status,404);assert.equal(response.headers.get('location'),null);});
  }
}finally{
  if(php){const exit=new Promise(resolve=>php.once('exit',resolve));php.kill();await exit;}
  // This tool owns only its fresh OS-temp directory, never project/cache or player files.
  fs.rmSync(temp,{recursive:true,force:true});
}
console.log(JSON.stringify({pass:results.length,fail:0,phpStopped:true,checks:results},null,2));
