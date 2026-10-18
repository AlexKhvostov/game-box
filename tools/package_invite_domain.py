"""Package only invitation routing; preserve the live landing version and files."""
from datetime import datetime,timezone
from pathlib import Path
import hashlib,json,shutil,argparse

def package(root,before):
    baseline=json.loads(before.read_text(encoding='utf8'))
    paths=['.htaccess','invite.php','.well-known/assetlinks.json']
    assert all(baseline[p].get('absent') is True for p in paths),'Expected a reviewed absent route baseline'
    build='invite-domain-v1.0.1_'+datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S_%f')
    out=root/'releases'/build
    (out/'site').mkdir(parents=True,exist_ok=False)
    for name in paths:
        source=root/'telegram-web/landing'/name
        target=out/'site'/name;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,target)
    version={'artifact':'invitation-route','version':'1.0.1','buildId':build,'codeLengths':[6,12]}
    (out/'site/invite-route-release.json').write_text(json.dumps(version,indent=2),encoding='utf8')
    paths.append('invite-route-release.json')
    manifest={**version,'expectedBeforeHashes':{p:None for p in paths},'files':[{'path':p,'sha256':hashlib.sha256((out/'site'/p).read_bytes()).hexdigest()} for p in paths]}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    print(json.dumps({'release':str(out),'buildId':build,'files':len(paths)}))
    return out

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--before',type=Path,required=True)
    package(Path(__file__).resolve().parents[1],parser.parse_args().before)
