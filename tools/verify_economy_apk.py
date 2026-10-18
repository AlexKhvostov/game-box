"""Read-only packaged economy comparison with the public HTTPS config."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile

p = argparse.ArgumentParser()
p.add_argument('apk',type=Path)
p.add_argument('--out',required=True,type=Path)
a=p.parse_args()
with urllib.request.urlopen('https://untouch.ballaball.xyz/api/config.php',timeout=30) as response:
    online = json.load(response)
with zipfile.ZipFile(a.apk) as archive:
    bundled = archive.read('assets/flutter_assets/assets/config/published-gameplay.json')
    assert bundled == Path('assets/config/published-gameplay.json').read_bytes()
    config = json.loads(bundled)
    assert config == online
    economy = config['config']['economy']
    assert [(x['costTokens'],x['lives']) for x in economy['lifePacks']] == [(1,1),(10,15),(25,50),(49,100)]
    assert economy['dailyRewardTokens'] == [2,4,8,12,18,24,36]
    assert economy['timedBonusTokens'] == 4
    native = archive.read('lib/arm64-v8a/libapp.so')
    for marker in [b'lives-heart-pulse',b'lives-balance-amount',b'crystal-pack-price-',
                   b'$0.99',b'$1.99',b'$3.99',b'$9.99']:
        assert marker in native,marker
result={'ok':True,'artifact':str(a.apk),'sha256':hashlib.sha256(a.apk.read_bytes()).hexdigest(),
        'packagedAssetMatchesLocalBytes':True,'packagedConfigEqualsCurrentHTTPS':True,
        'plannedUSDPriceStringsVerified':True,'newLifeAndPackageMarkers':True,
        'economy':economy,'playerDataTouched':False}
a.out.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS: packaged economy equals HTTPS; planned prices and life/package design present.')
