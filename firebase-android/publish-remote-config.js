'use strict';
// Run only after cloud authorization and ADC/Firebase login are configured.
// Merges one Android parameter, preserving all existing parameters/conditions.
const fs=require('node:fs');
const path=require('node:path');
const functionsRequire=require('node:module').createRequire(path.join(__dirname,'functions/package.json'));
const {initializeApp,applicationDefault}=functionsRequire('firebase-admin/app');
const {getRemoteConfig}=functionsRequire('firebase-admin/remote-config');
const {validatePolicy}=require('./functions/src/policy');
async function main() {
  const projectId=process.argv[2];
  if(projectId !== 'game-box-b30d4') throw new Error('Explicit reviewed project required');
  const rc=getRemoteConfig(initializeApp({projectId,credential:applicationDefault()}));
  const template=await rc.getTemplate();
  const backup=path.resolve(__dirname,'../.private/firebase-transition-20261016');fs.mkdirSync(backup,{recursive:true});
  fs.writeFileSync(path.join(backup,`remoteconfig-before-${Date.now()}.json`),JSON.stringify(template,null,2),{flag:'wx'});
  const newParameter=JSON.parse(fs.readFileSync(path.join(__dirname,'remoteconfig.template.json'),'utf8')).parameters.android_config_v1;
  const snapshot=validatePolicy(JSON.parse(newParameter.defaultValue.value));
  template.parameters.android_config_v1=newParameter;
  const validated=await rc.validateTemplate(template);
  if(!process.argv.includes('--publish')) {console.log(JSON.stringify({validated:true,revision:snapshot.revision,published:false}));return;}
  const published=await rc.publishTemplate(validated);
  console.log(JSON.stringify({published:true,revision:snapshot.revision,version:published.version?.versionNumber}));
}
main().catch(e=>{console.error(e.code ?? e.name);process.exitCode=1;});
