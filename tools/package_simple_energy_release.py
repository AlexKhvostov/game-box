"""Build a fresh offline Android3 server candidate. Never deploys or opens DB."""
import hashlib
import json
from pathlib import Path
import shutil
from datetime import datetime, timezone
import zipfile

ROOT=Path(__file__).resolve().parents[1]
FILES=['api/mobile.php','api/mobile_energy.php','api/mobile_energy_bonus.php','api/mobile_store.php',
       'api/mobile_wallet.php','api/mobile_invites.php','api/gameplay_config.php']
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    build='android-simple-energy-server-'+datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S_%f')
    out=ROOT/'releases'/build
    out.mkdir(exist_ok=False)
    frozen={}
    for name in FILES:
        source=ROOT/'telegram-web'/name;target=out/'deploy'/name
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
        frozen[name]=digest(target);assert frozen[name]==digest(source)
    shutil.copyfile(ROOT/'docs/ANDROID_SIMPLE_ENERGY_TRANSITION.md',out/'TRANSITION.md')
    policy={'enabled':False,'version':1,'initialEnergy':50,'reward':30,'periodSec':28800,
            'tier2Reward':60,'tier5Reward':150,'videoReward':40,'videoCooldownSec':120,'inviterReward':60}
    (out/'POLICY.example.json').write_text(json.dumps({'economy':{'androidEnergyV2':{'simpleBonus':policy}}},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    dependencies={p:digest(ROOT/'telegram-web'/p)for p in ['api/mobile_play.php','api/mobile_google.php','api/energy_store.php','api/mobile_identity.php']}
    manifest={'buildId':build,'contract':3,'deployed':False,'activated':False,'files':frozen,'existingDependencies':dependencies,
              'instructions':'Offline candidate only. Preserve private files, production config, data and old chargePolicy. Review TRANSITION.md before separate deployment/activation approval.'}
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    archive=out.with_suffix('.zip')
    with zipfile.ZipFile(archive,'x',zipfile.ZIP_DEFLATED)as z:
        for source in sorted(out.rglob('*')):
            if source.is_file():z.write(source,source.relative_to(out))
    with zipfile.ZipFile(archive)as z:assert z.testzip()is None
    print(json.dumps({'path':str(out),'archive':str(archive),'sha256':digest(archive)},ensure_ascii=False))
if __name__=='__main__':main()
