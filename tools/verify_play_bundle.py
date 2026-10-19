"""Verify signed Play bundle resources, assets and upload certificate."""
import argparse,hashlib,json,re,subprocess,zipfile
from pathlib import Path
from verify_android_bundle import fields

def labels(data):
    found=[]
    for k,pkg in fields(data):
        if k!=2:continue
        for k,t in fields(pkg):
            if k!=3:continue
            for k,e in fields(t):
                if k!=3:continue
                ef=list(fields(e))
                if not any(k==2 and v==b'app_name' for k,v in ef):continue
                for k,cv in ef:
                    if k!=6:continue
                    for k,value in fields(cv):
                        if k!=2:continue
                        for k,item in fields(value):
                            if k!=4:continue
                            for k,string in fields(item):
                                if k!=2:continue
                                for k,raw in fields(string):
                                    if k==1:found.append(raw.decode())
    return found

def main():
    p=argparse.ArgumentParser();p.add_argument('bundle',type=Path);p.add_argument('--baseline',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();java=Path('C:/Program Files/Android/Android Studio/jbr/bin')
    def command(name,*args):return subprocess.check_output([str(java/(name+'.exe')),*map(str,args)],stderr=subprocess.STDOUT).decode('utf-8',errors='replace')
    def cert(file):
        text=command('keytool','-printcert','-jarfile',file)
        return re.search(r'SHA256:\s*([A-Fa-f0-9:]+)',text).group(1).replace(':','').lower()
    signed=command('jarsigner','-verify',a.bundle);assert 'jar verified' in signed.lower()
    digest=cert(a.bundle);assert digest==cert(a.baseline)
    with zipfile.ZipFile(a.bundle) as z,zipfile.ZipFile(a.baseline) as old:
        assert z.testzip() is None
        names=labels(z.read('base/resources.pb'));assert names and all(n=='untouch' for n in names)
        examples=['rewarded-next-example.png','rewarded-close-example.png']
        declared=Path('pubspec.yaml').read_text(encoding='utf-8')
        images=[n for n in examples if 'assets/branding/ui/'+n in declared]
        for name in images:assert z.read('base/assets/flutter_assets/assets/branding/ui/'+name)==Path('assets/branding/ui/'+name).read_bytes()
        for name in set(examples)-set(images):assert 'base/assets/flutter_assets/assets/branding/ui/'+name not in z.namelist()
        raw=z.read('base/assets/flutter_assets/assets/config/android-firebase.json');assert raw==Path('assets/config/android-firebase.json').read_bytes()
        snap=json.loads(raw);assert snap['config']['ranking']['average']['minAttempts']==1
        assert snap['config']['ranking']['average']['minDurationMs']==0
        def oauth(archive):return set(re.findall(rb'[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com',archive.read('base/lib/arm64-v8a/libapp.so')))
        assert len(oauth(z))==1 and oauth(z)==oauth(old)
        binary=z.read('base/lib/arm64-v8a/libapp.so')
        assert b'R-M-20184253-1' in binary and b'R-M-20184253-2' in binary
    result=dict(sha256=hashlib.sha256(a.bundle.read_bytes()).hexdigest(),applicationLabels=names,
        jarVerified=True,uploadCertificateMatches184=True,certificateSha256=digest,zipCrc=True,
        sdkScreenshotAssetsVerified=images,guideMode='screenshot' if images else 'schematic',bundledRevision=snap['revision'],minAttempts=1,minDurationMs=0,
        oauthClientPreserved=True,yandexPublisherUnitsPresent=True,installedThroughPlay=False,published=False)
    a.output.write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result))

if __name__=='__main__':main()
