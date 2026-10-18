"""Compile native Flutter screenshots into an offline UI kit and overview PNGs."""
import argparse
import html
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--directory', type=Path, default=ROOT / 'docs/design/neon-ui-kit-20261015')
args = parser.parse_args()
OUT = args.directory.resolve()
catalog = json.loads((OUT / 'catalog.json').read_text(encoding='utf-8-sig'))
rows = catalog['screens']
for row in rows:
    assert (OUT / 'screens' / (row['id'] + '.png')).is_file(), row['id']

FONT = Path('C:/Windows/Fonts/segoeui.ttf')
BOLD = Path('C:/Windows/Fonts/segoeuib.ttf')
BG = '#061B2D'
TEXT = '#F0FBFF'
MUTED = '#A9CBE4'
CYAN = '#79F1F5'
YELLOW = '#FFEE73'
GROUP_TITLES = {'home': 'Главный экран', 'energy': 'Энергия', 'store': 'Магазин и подключение батарей',
                'rewards': 'Награды и обратная связь', 'abilities': 'Усиления', 'account': 'Аккаунт',
                'ranking': 'Рейтинг', 'result': 'Результат игры', 'kit': 'Компоненты интерфейса'}


def font(size, bold=False):
    return ImageFont.truetype(str(BOLD if bold else FONT), size)


def screenshot(row):
    # Remove only Android's status/navigation chrome for the catalogue layout.
    im = Image.open(OUT / 'screens' / (row['id'] + '.png')).convert('RGB')
    if im.size == (1080, 2312):
        im = im.crop((0, 81, 1080, 2231))
    return im


def wrap(draw, text, width, ft):
    result = []
    line = ''
    for word in text.split():
        candidate = (line + ' ' + word).strip()
        if line and draw.textlength(candidate, font=ft) > width:
            result.append(line)
            line = word
        else:
            line = candidate
    if line:
        result.append(line)
    return result


def overview(items, path, title, cols=4, tile_width=280):
    gap = 22
    picture_height = round(tile_width * 2150 / 1080)
    tile_height = picture_height + 88
    width = gap + cols * (tile_width + gap)
    height = 138 + math.ceil(len(items) / cols) * (tile_height + gap)
    sheet = Image.new('RGB', (width, height), BG)
    d = ImageDraw.Draw(sheet)
    d.text((gap, 22), title, font=font(34, True), fill=CYAN)
    d.text((gap, 76), 'Untouch · объёмный игровой неон · настоящая отрисовка Flutter · тестовые данные', font=font(19), fill=MUTED)
    for i, row in enumerate(items):
        x = gap + (i % cols) * (tile_width + gap)
        y = 138 + (i // cols) * (tile_height + gap)
        im = screenshot(row)
        im.thumbnail((tile_width, picture_height), Image.Resampling.LANCZOS)
        d.rounded_rectangle((x - 2, y - 2, x + tile_width + 2, y + picture_height + 2), radius=12, outline='#245A70', width=2)
        sheet.paste(im, (x + (tile_width - im.width) // 2, y))
        for j, line in enumerate(wrap(d, row['title'], tile_width, font(20, True))[:2]):
            d.text((x, y + picture_height + 10 + j * 24), line, font=font(20, True), fill=TEXT)
        d.text((x, y + picture_height + 65), row['id'], font=font(14), fill=MUTED)
    sheet.save(path, optimize=True)


(OUT / 'sheets').mkdir(exist_ok=True)
overview(rows, OUT / 'ui-kit-all.png', 'UI KIT / ВСЕ ОКНА И СОСТОЯНИЯ', cols=6, tile_width=248)
core_ids = ['home', 'charge-one', 'charge-two', 'charge-five', 'tasks', 'friends', 'buy', 'subscription']
overview([next(row for row in rows if row['id'] == item) for item in core_ids],
         OUT / 'ui-kit-core.png', 'ОСНОВНЫЕ ОКНА / ЭНЕРГИЯ', cols=4, tile_width=340)
groups = list(dict.fromkeys(row['group'] for row in rows))
pages = []
for group_index, group in enumerate(groups, 1):
    items = [row for row in rows if row['group'] == group]
    for index in range(0, len(items), 8):
        filename = f'{group_index:02d}-{index // 8 + 1:02d}.png'
        overview(items[index:index+8], OUT / 'sheets' / filename, GROUP_TITLES.get(group, group).upper(), cols=4)
        pages.append({'group': GROUP_TITLES.get(group, group), 'path': 'sheets/' + filename})

five = next(row for row in rows if row.get('screen') == 'charge' and str(row.get('params', {}).get('slots')) == '5' and row.get('params', {}).get('state') != 'pending')
im = screenshot(five)
im.save(OUT / 'five-batteries.png', optimize=True)

cards = []
for i, row in enumerate(rows):
    esc = html.escape
    cards.append(f'''<article class="card" data-group="{esc(row['group'])}" data-title="{esc(row['title'].lower())}">
<button class="preview" data-index="{i}" aria-label="Открыть: {esc(row['title'])}"><img loading="lazy" src="screens/{esc(row['id'])}.png" alt="{esc(row['title'])}"></button>
<div class="caption"><small>{esc(GROUP_TITLES.get(row['group'], row['group']))}</small><h2>{esc(row['title'])}</h2><p>{esc(row.get('description', ''))}</p><a href="screens/{esc(row['id'])}.png" target="_blank" rel="noopener">Открыть PNG ↗</a></div></article>''')
options = ''.join(f'<option value="{html.escape(group)}">{html.escape(GROUP_TITLES.get(group, group))}</option>' for group in groups)
page = '''<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Untouch — неоновый UI kit</title><style>
*{box-sizing:border-box}body{margin:0;background:#061b2d;color:#f0fbff;font:16px/1.5 system-ui,sans-serif}header{padding:36px max(24px,4vw) 24px;background:radial-gradient(ellipse at 30% 0,#145b70,transparent 65%)}h1{margin:0;font-size:clamp(30px,4vw,56px);line-height:1.12;color:#b3faff}header p{max-width:870px;color:#a9cbe4;margin:15px 0}.eyebrow{color:#43ecc0;letter-spacing:.18em;font-size:12px;font-weight:800}.toolbar{position:sticky;top:0;z-index:2;padding:14px max(24px,4vw);display:flex;gap:12px;flex-wrap:wrap;background:#061b2df2;border-block:1px solid #24546a;backdrop-filter:blur(15px)}select,input,.link{border:1px solid #59c9dc;border-radius:12px;background:#0c3046;color:#f0fbff;padding:10px 14px;font:inherit;min-height:46px}input{min-width:210px;flex:1}.link{text-decoration:none;box-shadow:inset 0 1px #8bedff50,0 0 10px #34dcff15}.link:hover{border-color:#a5faff}main{padding:24px max(24px,4vw) 60px}.palette{display:flex;gap:14px;flex-wrap:wrap;margin:0 0 26px}.swatch{display:flex;align-items:center;gap:9px;padding:10px 13px;background:#0a2639;border-radius:10px;color:#a9cbe4;font-size:13px}.swatch i{width:24px;height:24px;border-radius:6px;background:var(--color);box-shadow:0 0 12px color-mix(in srgb,var(--color),transparent 75%)}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:24px}.card{overflow:hidden;border:1px solid #29556b;border-radius:18px;background:linear-gradient(145deg,#113b51,#082133)}.card[hidden]{display:none}.preview{cursor:zoom-in;display:block;border:0;padding:0;width:100%;background:#031623}.preview img{display:block;width:100%;aspect-ratio:1080/2312;object-fit:contain}.caption{padding:16px}h2{font-size:17px;line-height:1.3;margin:5px 0 9px}.caption small{color:#43ecc0;font-size:12px}.caption p{font-size:13px;color:#a9cbe4;margin:0 0 12px;min-height:2.8em}.caption a{color:#79f1f5;font-size:13px}.count{align-self:center;color:#a9cbe4;white-space:nowrap;font-size:13px}dialog{border:1px solid #61f4ff;border-radius:18px;padding:0;max-width:96vw;max-height:96vh;background:#041a29;color:#f0fbff;box-shadow:0 0 40px #12cfff20}dialog::backdrop{background:#000d}.viewerbar{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:10px 16px;position:sticky;top:0;background:#062339}dialog button{border:1px solid #59c9dc;background:#103c54;color:#f0fbff;border-radius:8px;padding:8px 13px;cursor:pointer;min-width:44px}dialog img{display:block;max-height:82vh;max-width:93vw;object-fit:contain;margin:auto}.viewerbar span{font-size:14px}footer{padding:22px max(24px,4vw);color:#a9cbe4;border-top:1px solid #21485c;font-size:13px}
</style></head><body><header><div class="eyebrow">UNTOUCH / UI KIT</div><h1>Объёмный игровой неон</h1><p>Все актуальные окна Android-игры и важные состояния. Короткая кнопка сбора, круглый плюс накопителя и пять аккумуляторов — в единой системе.</p><p>Снимки текущего Flutter-интерфейса. Балансы, игроки и цены в каталоге тестовые; реальные платежи не выполняются.</p></header><nav class="toolbar"><select id="group" aria-label="Раздел"><option value="">Все разделы</option>__OPTIONS__</select><input id="search" type="search" placeholder="Найти окно…" aria-label="Найти окно"><a class="link" href="ui-kit-core.png" target="_blank">Основные окна PNG ↗</a><a class="link" href="ui-kit-all.png" target="_blank">Все окна PNG ↗</a><a class="link" href="five-batteries.png" target="_blank">Пять аккумуляторов ↗</a><span class="count" id="count"></span></nav><main><div class="palette"><div class="swatch"><i style="--color:#061b2d"></i>Тёмное стекло</div><div class="swatch"><i style="--color:#79f1f5"></i>Неоновый контур</div><div class="swatch"><i style="--color:#43ecc0"></i>Заряд и готовность</div><div class="swatch"><i style="--color:#ffee73"></i>Энергия</div><div class="swatch"><i style="--color:#ff6b7a"></i>Опасность</div></div><div class="grid">__CARDS__</div></main><dialog id="viewer"><div class="viewerbar"><button id="previous" aria-label="Предыдущее окно">←</button><span id="title"></span><button id="next" aria-label="Следующее окно">→</button><button id="close" aria-label="Закрыть">✕</button></div><img id="full" alt=""></dialog><footer>Кнопки покупки и недоступных тестовых сервисов показывают предложение. При выполнении появляется сообщение об ограничении теста. Рабочие игровые действия сохраняются.</footer><script>
const data=__DATA__;let current=0;const cards=[...document.querySelectorAll('.card')],group=document.querySelector('#group'),search=document.querySelector('#search'),viewer=document.querySelector('#viewer');function filter(){let count=0;for(const card of cards){card.hidden=Boolean((group.value&&card.dataset.group!==group.value)||!card.dataset.title.includes(search.value.trim().toLowerCase()));if(!card.hidden)count++}document.querySelector('#count').textContent=count+' / '+data.length+' окон'}function show(index){current=(index+data.length)%data.length;const item=data[current];document.querySelector('#full').src='screens/'+item.id+'.png';document.querySelector('#full').alt=item.title;document.querySelector('#title').textContent=item.title;if(!viewer.open)viewer.showModal()}document.querySelectorAll('.preview').forEach(button=>button.addEventListener('click',()=>show(Number(button.dataset.index))));group.addEventListener('change',filter);search.addEventListener('input',filter);document.querySelector('#close').onclick=()=>viewer.close();document.querySelector('#previous').onclick=()=>show(current-1);document.querySelector('#next').onclick=()=>show(current+1);document.addEventListener('keydown',event=>{if(viewer.open&&event.key==='ArrowLeft')show(current-1);if(viewer.open&&event.key==='ArrowRight')show(current+1)});viewer.addEventListener('click',event=>{if(event.target===viewer)viewer.close()});filter();
</script></body></html>'''
page = page.replace('__OPTIONS__', options).replace('__CARDS__', ''.join(cards)).replace('__DATA__', json.dumps(rows, ensure_ascii=False).replace('</', '<\\/'))
(OUT / 'gallery.html').write_text(page, encoding='utf-8')
links = '\n'.join(f"- [{row['title']}](screens/{row['id']}.png)" for row in rows)
sheets = '\n'.join(f"- [{row['group']}]({row['path']})" for row in pages)
(OUT / 'GALLERY.md').write_text(f'# Untouch: неоновый UI kit\n\n{len(rows)} окон и состояний из реального Flutter UI с изолированными тестовыми данными.\n\n[Открыть галерею](gallery.html) · [Основные окна](ui-kit-core.png) · [Общий лист](ui-kit-all.png) · [Пять аккумуляторов](five-batteries.png)\n\n## Обзорные листы\n\n{sheets}\n\n## Все окна\n\n{links}\n', encoding='utf-8')
print(json.dumps({'screens': len(rows), 'groups': len(groups), 'overviewSheets': len(pages), 'gallery': str(OUT / 'gallery.html')}, ensure_ascii=False))
