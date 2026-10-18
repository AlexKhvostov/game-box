"""Read-only Android Firebase candidate integrity; never installs/publishes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import zipfile
ROOT=Path(__file__).resolve().parents[1]
SDK=Path.home()/'AppData/Local/Android/Sdk/build-tools/36.0.0'
def main(apk,previous,out):
    env=os.environ.copy();env['JAVA_HOME']='C:/Program Files/Android/Android Studio/jbr'
    def tool(name,*args):
        r=subprocess.run([str(SDK/name),*map(str,args)],env=env,capture_output=True,text=True,encoding='utf-8',errors='replace')
        assert r.returncode==0,r.stderr
        return r.stdout
    old=tool('apksigner.bat','verify','--print-certs',previous)
    current=tool('apksigner.bat','verify','--verbose','--print-certs',apk)
    pattern=r'Signer #1 certificate SHA-256 digest: ([0-9a-f]+)'
    certificate=re.search(pattern,current).group(1)
    assert certificate==re.search(pattern,old).group(1)
    assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in current
    manifest=tool('aapt.exe','dump','badging',apk)
    package,code,version=re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'",manifest).groups()
    assert package=='com.best4u.untouch' and int(code)>141 and 'application-debuggable' not in manifest
    tool('zipalign.exe','-c','-P','16','-v','4',apk)
    expected=json.loads((ROOT/'assets/config/android-firebase.json').read_text(encoding='utf-8'))
    libraries=[]
    with zipfile.ZipFile(apk) as archive,zipfile.ZipFile(previous) as old_archive:
        assert archive.testzip() is None
        assert json.loads(archive.read('assets/flutter_assets/assets/config/android-firebase.json'))==expected
        app=archive.read('lib/arm64-v8a/libapp.so')
        for marker in [b'firebase_android_v1_',b'8307d5aa04c14140d4e132',b'androidApi',b'untouch-android-game-box-b30d4.web.app']:
            assert marker in app,marker
        oauth=rb'[0-9]+-[a-zA-Z0-9-]+[.]apps[.]googleusercontent[.]com'
        assert set(re.findall(oauth,app))==set(re.findall(oauth,old_archive.read('lib/arm64-v8a/libapp.so')))
        for name in archive.namelist():
            if not name.startswith('lib/') or not name.endswith('.so'):continue
            data=archive.read(name)
            if data[4]!=2:continue
            endian='<' if data[5]==1 else '>'
            offset=struct.unpack_from(endian+'Q',data,32)[0];size,count=struct.unpack_from(endian+'HH',data,54)
            alignment=[struct.unpack_from(endian+'Q',data,offset+i*size+48)[0] for i in range(count) if struct.unpack_from(endian+'I',data,offset+i*size)[0]==1]
            assert alignment and min(alignment)>=16384
            libraries.append(name)
    links=json.loads((ROOT/'firebase-android/hosting/.well-known/assetlinks.json').read_text())
    assert certificate.upper() in [v.replace(':','') for v in links[0]['target']['sha256_cert_fingerprints']]
    metadata=json.loads((apk.parent/'build.json').read_text(encoding='utf-8-sig'))
    digest=hashlib.sha256(apk.read_bytes()).hexdigest()
    assert metadata['sha256']==digest and metadata['versionCode']==int(code)
    assert metadata['backend']=='firebase-android-v1' and metadata['googlePlayBilling']
    assert not metadata['testTools'] and not metadata['gameplayDebug'] and not metadata['testServicePreview']
    result={'ok':True,'artifact':str(apk),'versionName':version,'versionCode':int(code),'package':package,'sha256':digest,
        'sameSigningKeyAs141':True,'signatureV2':True,'zipCRC':True,'zipAndElf16KB':True,'libraries':libraries,
        'firebaseConfigRevision':expected['revision'],'firebaseAppId':'1:332169968823:android:8307d5aa04c14140d4e132',
        'firebaseAppLinkHost':True,'oauthMatches141':True,'deviceInstalled':False,'cloudVerified':False,'playPublished':False}
    out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='libraries'},ensure_ascii=False))
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('apk',type=Path);parser.add_argument('--previous',type=Path,required=True);parser.add_argument('--out',type=Path,required=True);args=parser.parse_args();main(args.apk.resolve(),args.previous.resolve(),args.out.resolve())
