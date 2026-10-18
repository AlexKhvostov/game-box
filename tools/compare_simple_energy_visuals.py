"""Evidence layout only: untouched reference beside cropped native screenshot."""
import json
import argparse
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'docs/release-evidence/android-simple-energy-20261016'
REF=ROOT/'docs/design/simple-energy-bonus-20261016/live-kit/references'
PAIRS={
 'e01-ready':'windows/energy-ready.png','e01-ready-x2':'windows/energy-ready.png','e01-ready-x5':'windows/energy-subscribed.png',
 'e01-cooldown':'windows/energy-cooldown.png','e01-cooldown-x2':'windows/energy-cooldown.png','e01-cooldown-x5':'windows/energy-subscribed.png',
 'e02-free':'windows/subscription.png','e02-x2':'windows/subscription.png','e02-x5':'windows/subscription.png',
 'e03-video':'windows/video.png','e03-cooldown':'windows/video.png','e04-friends':'windows/friends.png',
 'e05-packs':'windows/packs.png','a01-helmet-on':'windows/helmet.png','a02-jump-on':'windows/jump.png',
 'h01-50':'details/balance-50.png','h01-1500':'details/balance-1500.png','h01-99999':'details/balance-99999.png',
}
def main():
    folder=BASE/'physical/design-ready';out=BASE/'comparisons';out.mkdir(parents=True,exist_ok=True)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
    thumbs=[];md=['# Оригиналы рядом с фактическим Flutter на Huawei','',
      '16.10.2026. Слева оригинал PDF; справа фактический снимок нативного Flutter. Для сопоставления окно/капсула вырезаны по измеренным координатам и пропорционально масштабированы. Полные исходные снимки сохранены. Данные и цены тестового пакета искусственные; системные SDK/Google окна этим не проверялись.','',
      'Круг, кнопки, рамки, таймеры и тексты — Flutter/Canvas; картинки целых окон в игре не используются. У шлема одна исходная иллюстрация. Сравнение не означает утверждение внешности Алексеем.','',
      '| Состояние | Сравнение | Полный снимок |','|---|---|---|']
    for name,ref in PAIRS.items():
        data=json.loads((folder/(name+'.json')).read_text(encoding='utf-8'))
        key='hud-energy-card' if name.startswith('h01') else 'simple-energy-window'
        r=data['rectangles'][key]
        native=Image.open(folder/(name+'.png')).convert('RGB').crop((round(r['left']),round(r['top']),round(r['left']+r['width']),round(r['top']+r['height'])))
        original=Image.open(REF/ref).convert('RGB')
        height=180 if name.startswith('h01') else 720
        panels=[]
        for img in [original,native]:panels.append(img.resize((round(img.width*height/img.height),height),Image.Resampling.LANCZOS))
        canvas=Image.new('RGB',(panels[0].width+panels[1].width+44,height+65),'#041426');draw=ImageDraw.Draw(canvas)
        draw.text((12,10),'Original PDF',font=font,fill='#c5eaff');draw.text((panels[0].width+32,10),'Huawei / Flutter / synthetic data',font=font,fill='#c5eaff')
        canvas.paste(panels[0],(8,44));canvas.paste(panels[1],(panels[0].width+32,44));canvas.save(out/(name+'.png'))
        thumb=canvas.copy();thumb.thumbnail((510,380));tile=Image.new('RGB',(530,415),'#041426');tile.paste(thumb,((530-thumb.width)//2,28));ImageDraw.Draw(tile).text((10,3),name,font=font,fill='white');thumbs.append(tile)
        md.append(f'| {name} | [Рядом](comparisons/{name}.png) | [Android](physical/design-ready/{name}.png) |')
    contact=Image.new('RGB',(530*3,415*((len(thumbs)+2)//3)),'#041426')
    for i,tile in enumerate(thumbs):contact.paste(tile,((i%3)*530,(i//3)*415))
    contact.save(out/'contact.png')
    md+=['','[Контактный лист](comparisons/contact.png). [Нативная приёмка](physical/design-ready/acceptance.json).',
      '', 'Отличия от растрового оригинала: рамки/контуры и световые рисунки пересобраны кодом, стандартные пиктограммы заменяют часть нарисованных значков; точного совпадения пикселей нет. Шлем и прыжок используют точные исходные иллюстрации. Подписи цен/сроков и статусы берутся из данных; реальная локализованная цена может отличаться от макета. Суммы на состояниях ×2/×5 сравниваются по структуре, исходный лист содержит только выбранные образцы.',
      '', 'S01/S02 не рисовались: их открывают настоящий рекламный SDK и Google Play. Новые реальные показы/покупки здесь не выполнялись.']
    (BASE/'GALLERY.md').write_text('\n'.join(md)+'\n',encoding='utf-8')
    print('Created',len(PAIRS),'native/reference comparisons')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-base',type=Path,default=BASE)
    args=parser.parse_args();BASE=args.output_base.resolve()
    main()
