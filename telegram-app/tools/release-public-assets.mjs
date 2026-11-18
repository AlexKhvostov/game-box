import {cp} from 'node:fs/promises';
import {resolve} from 'node:path';

export function releasePublicAssets(){
  let publicDir,outDir;
  return {
    name:'untouch-release-public-assets',
    apply:'build',
    configResolved(config){
      publicDir=config.publicDir;
      outDir=resolve(config.root,config.build.outDir);
    },
    async writeBundle(){
      if(!publicDir)return;
      const achievements=resolve(publicDir,'assets/achievements');
      // Keep the authoring originals and their manifest in the project.
      const excluded=new Set([
        resolve(achievements,'animations-v1'),
        resolve(achievements,'scene/stage-studio-portrait.png'),
        resolve(achievements,'source-manifest.json'),
      ]);
      await cp(publicDir,outDir,{recursive:true,filter:source=>!excluded.has(resolve(source))});
    },
  };
}
