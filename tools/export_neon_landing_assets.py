"""Web delivery exports of existing canonical art and verified Android captures."""
from pathlib import Path
from PIL import Image
import json, hashlib
root = Path(__file__).resolve().parents[1]
out = root / 'telegram-web/landing/assets'
out.mkdir(exist_ok=True)
items = {
 'neon-reaction-benefit.webp': ('assets/branding/landing/reaction-benefit-v1.png', 800),
 'neon-office-kettle-benefit.webp': ('assets/branding/landing/office-kettle-benefit-v1.png', 800),
 'neon-metro-case.webp': ('assets/branding/landing/metro-case-v1.png', 800),
 'neon-company-case.webp': ('assets/branding/landing/company-case-v1.png', 800),
 'neon-favicon.webp': ('assets/branding/app_icon.png', 64),
 'neon-icon.webp': ('assets/branding/app_icon.png', 800),
 'neon-result.webp': ('assets/branding/ui/result-scene-v1.png', 1000),
 'neon-player.webp': ('assets/branding/ui/profile-player-cube-v1.png', 800),
 'neon-rest.webp': ('assets/branding/ui/lives-room-v2.png', 1000),
 'neon-portrait.webp': ('assets/branding/ui/hud-player-portrait-v1.png', 128),
 'neon-helmet.webp': ('assets/branding/ui/ability-helmet.png', 128),
 'neon-jump.webp': ('assets/branding/ui/ability-jump.png', 128),
 'neon-home.webp': ('docs/release-evidence/modal-abilities-prices-20261012/final-physical/game-active.png', 650),
 'neon-result-screen.webp': ('docs/release-evidence/modal-abilities-prices-20261012/final-physical/result-rich.png', 650),
}
records=[]
for name, (source, width) in items.items():
    im=Image.open(root/source)
    im.thumbnail((width, width*3), Image.Resampling.LANCZOS)
    im.save(out/name, 'WEBP', quality=85, method=6)
    records.append(dict(path='assets/'+name,source=source,width=im.width,height=im.height,bytes=(out/name).stat().st_size,sha256=hashlib.sha256((out/name).read_bytes()).hexdigest()))
evidence=root/'docs/release-evidence/neon-landing-20261013'
evidence.mkdir(parents=True,exist_ok=True)
(evidence/'asset-sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(assets=len(records),bytes=sum(i['bytes'] for i in records))))
