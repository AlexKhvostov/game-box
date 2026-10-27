"""Verify official Google splits match the reviewed AAB before updating a phone."""
from pathlib import Path
import argparse,subprocess,re,json,zipfile,hashlib

def main():
    p=argparse.ArgumentParser();p.add_argument('bundle',type=Path);p.add_argument('download_receipt',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    receipt=json.loads(a.download_receipt.read_text(encoding='utf-8'))
    assert receipt['ok'] and receipt['versionCode']==229 and len(receipt['files'])==5
    expected='a1282130e301ebabb44f8804f4a6f69ae98d3de9e464f56a034c9da0f1f0d701'
    signer=Path.home()/'AppData/Local/Android/Sdk/build-tools/36.0.0/apksigner.bat'
    assert signer.is_file()
    for f in receipt['files']:
        file=Path(f['path']);assert file.is_file()
        assert hashlib.sha256(file.read_bytes()).hexdigest()==f['sha256']
        result=subprocess.check_output([str(signer),'verify','--verbose','--print-certs',str(file)],stderr=subprocess.STDOUT).decode('utf-8',errors='replace')
        digest=re.search(r'Signer #1 certificate SHA-256 digest: ([a-fA-F0-9]+)',result)[1].lower()
        assert digest==expected,(file.name,digest)
        with zipfile.ZipFile(file) as z:assert z.testzip() is None
    files={f['splitId']:Path(f['path']) for f in receipt['files']}
    with zipfile.ZipFile(a.bundle) as bundle,zipfile.ZipFile(files['base']) as base,zipfile.ZipFile(files['config.arm64_v8a']) as arm:
        assets=[n for n in bundle.namelist() if n.startswith('base/assets/') and not n.endswith('/')]
        for name in assets:assert base.read(name[5:])==bundle.read(name),name
        libs=[n for n in bundle.namelist() if n.startswith('base/lib/arm64-v8a/') and n.endswith('.so')]
        for name in libs:assert arm.read(name[5:])==bundle.read(name),name
        binary=arm.read('lib/arm64-v8a/libapp.so')
        assert b'unlockAfterGames' in binary
        assert b'android_config_v1' in binary and b'android_ad_formats_qa_v1' not in binary
        assert b'R-M-20184253-1' in binary and b'R-M-20184253-2' in binary
    result={'passed':True,'versionCode':229,'playCertificate':expected,'splitSignaturesAndCrcVerified':5,'assetsMatchReviewedBundle':len(assets),'arm64LibrariesMatchReviewedBundle':len(libs),'productionRcKeyPresent':True,'qaRcKeyAbsent':True,'livePublisherUnitsPresent':True,'bundleSha256':hashlib.sha256(a.bundle.read_bytes()).hexdigest()}
    a.output.write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result))
if __name__=='__main__':main()
