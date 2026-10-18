'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const host='http://127.0.0.1:5080';
test('Firebase Hosting invitation preserves a validated Play referrer without PHP',async()=>{
  const script=fs.readFileSync('hosting/invite.js','utf8');
  const run=pathname=>{let target=null;const elements={message:{},play:{}};
    vm.runInNewContext(script,{URL,location:{pathname,search:'',hash:'',replace:url=>{target=url;}},document:{getElementById:id=>elements[id]}});return target;
  };
  for(const code of ['ABCDEFGH2345','abcdefgh2345']) {
    const r=await fetch(`${host}/a/${code}`,{redirect:'manual'});
    assert.equal(r.status,200);assert.match(await r.text(),/invite\.js/);const dest=new URL(run(`/a/${code}`));
    assert.equal(dest.origin,'https://play.google.com');assert.equal(dest.searchParams.get('id'),'com.best4u.untouch');
    assert.equal(dest.searchParams.get('referrer'),`invite=${code.toUpperCase()}`);
  }
  for(const path of ['/a/invalid','/a/ABCDEFGHIJKL','/a/ABCDEFGH2345/extra','/a/%41BCDEFGH2345']) assert.equal(run(path),null);
});
test('Firebase Hosting serves Android association and both public support pages',async()=>{
  const r=await fetch(`${host}/.well-known/assetlinks.json`);assert.equal(r.status,200);assert.match(r.headers.get('content-type'),/application\/json/);
  const links=await r.json();assert.equal(links[0].target.package_name,'com.best4u.untouch');assert.equal(links[0].target.sha256_cert_fingerprints.length,2);
  for(const path of ['/privacy/','/delete-account/','/legal.css']) {
    const page=await fetch(host+path);assert.equal(page.status,200);assert.equal((await page.text()).includes('Hostland'),false);
  }
});
