"""Apply only the reviewed ad delta onto the current deployed Edge bundles."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

root=Path(__file__).resolve().parents[1]
stage=root/'.private/ad-formats-deploy'
base_dir=stage/'reviewed-base'
base_dir.mkdir(exist_ok=True)
changed=['functions/_shared/config-schema.mjs','functions/_shared/core/policy.mjs','functions/_shared/core/engine.mjs']
def digest(data):return hashlib.sha256(data).hexdigest()
report=[]
for slug in ['remote-config-admin','android-api','telegram-api']:
    prod=stage/'production'/slug
    candidate=stage/'candidate'/slug
    assert not candidate.exists(), 'Candidate exists; inspect before overwriting'
    shutil.copytree(prod,candidate)
    changes=[]
    for name in changed:
        current=prod/name
        if not current.exists():continue
        repo_name='supabase/'+name
        paths=[]
        for ref,label in [('b489c990','base'),('fa6a4e0f','ads')]:
            path=base_dir/(label+'-'+name.replace('/','_'))
            path.write_bytes(subprocess.check_output(['git','show',ref+':'+repo_name],cwd=root))
            paths.append(path)
        merge=subprocess.run(['git','merge-file','-p',str(current),str(paths[0]),str(paths[1])],capture_output=True)
        assert merge.returncode in [0,1],merge.stderr.decode(errors='replace')
        text=merge.stdout.decode('utf-8')
        if merge.returncode:
            # Both production and the ad patch extend one fallback expression.
            # Preserve the production invite fallback, prepend only ad fallback.
            matches=list(re.finditer(r'^<<<<<<< .*?\n(.*?)^=======\n(.*?)^>>>>>>> .*?\n',text,re.M|re.S))
            assert len(matches)==1 and all(part.strip().startswith('export const getValue=') for part in matches[0].groups()),name
            prod_line=matches[0].group(1).strip()
            assert 'inviteMinimumEnergy' in prod_line and 'adFormatsDefaults' not in prod_line
            resolved=prod_line.replace('??(',"??(path.startsWith('advertising.')?path.split('.').slice(1).reduce((v,k)=>v?.[k],adFormatsDefaults):",1)+'\n'
            text=text[:matches[0].start()]+resolved+text[matches[0].end():]
        assert '<<<<<<<' not in text and '>>>>>>>' not in text
        dest=candidate/name
        dest.write_text(text,encoding='utf-8',newline='\n')
        if dest.read_bytes()!=current.read_bytes():
            changes.append({'name':name,'before':digest(current.read_bytes()),'after':digest(dest.read_bytes())})
    added='functions/_shared/ad-formats-config.mjs'
    shutil.copyfile(root/'supabase'/added,candidate/added)
    allowed={item['name'] for item in changes}|{added}
    for path in prod.rglob('*'):
        if path.is_file() and path.relative_to(prod).as_posix() not in allowed:
            assert path.read_bytes()==(candidate/path.relative_to(prod)).read_bytes()
    report.append({'function':slug,'changed':changes,'added':[added],'otherFilesIdentical':True})
(stage/'candidate-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
