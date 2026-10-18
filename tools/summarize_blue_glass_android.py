"""Build review sheets from the existing revision-two Android captures."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/release-evidence/android-blue-glass-rev2-20261010'
WINDOWS = ('game', 'result', 'profile', 'ranking', 'player', 'lives', 'daily',
           'purchases', 'rent', 'earn', 'plus', 'age', 'restore', 'reset', 'share', 'billing')
FONT = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 15)


def sheet(names, target, columns=4):
    tiles = []
    for name in names:
        frame = Image.open(OUT / (name + '.png')).convert('RGB')
        frame.thumbnail((260, 600))
        tile = Image.new('RGB', (280, 635), '#e8eef4')
        ImageDraw.Draw(tile).text((10, 7), name.split('-scaled-')[0], font=FONT, fill='#082e4c')
        tile.paste(frame, ((280 - frame.width) // 2, 30))
        tiles.append(tile)
    result = Image.new('RGB', (columns * 280, ((len(tiles) + columns - 1) // columns) * 635), 'white')
    for i, tile in enumerate(tiles):
        result.paste(tile, ((i % columns) * 280, (i // columns) * 635))
    result.save(OUT / target, quality=90)


def main():
    items = []
    errors = []
    missing = []
    for path in sorted(OUT.glob('*-scaled-*.json')):
        state = json.loads(path.read_text(encoding='utf-8'))
        items.append(dict(file=path.name, **state))
        if state['errors']:
            errors.append(dict(file=path.name, errors=state['errors']))
        frame = Image.open(path.with_suffix('.png')).convert('RGB')
        frame.thumbnail((160, 350))
        bright = sum(r > 85 and g > 140 and b > 170 for r, g, b in frame.get_flattened_data()) / (frame.width * frame.height)
        if state['window'] not in ('game', 'notice') and bright < .03:
            missing.append(path.name)
    (OUT / 'android-final-inventory.json').write_text(json.dumps(dict(
        revision=2, captures=len(items), renderErrors=errors,
        missingVisibleWindowCandidates=missing, items=items), ensure_ascii=False, indent=2), encoding='utf-8')
    for lang in ('ru', 'en'):
        for width, height, scale in ((320, 560, 1), (320, 560, 2), (390, 844, 1), (430, 932, 1)):
            sheet([f'{window}-{lang}-{width}x{height}-scaled-{scale}' for window in WINDOWS],
                  f'contact-{lang}-{width}-text{scale}.jpg')
        for scale in (1, 2):
            sheet([f'{window}-{lang}-320x480-scaled-{scale}' for window in ('game', 'result', 'profile', 'daily', 'age', 'ranking')],
                  f'contact-short-{lang}-text{scale}.jpg', columns=3)
    frames = [Image.open(OUT / f'game-ru-{width}x{height}-scaled-1.png').convert('RGB')
              for width, height in ((320, 560), (390, 844), (430, 932))]
    for height, target in ((510, 'home-header-sizes.png'), (1880, 'home-field-sizes.png')):
        result = Image.new('RGB', (sum(frame.width for frame in frames) + 80, height + 50), '#e8eef4')
        draw = ImageDraw.Draw(result)
        x = 20
        for frame, label in zip(frames, ('320 x 560', '390 x 844', '430 x 932')):
            draw.text((x, 12), label + ' | same Android density', font=FONT, fill='#082e4c')
            result.paste(frame.crop((0, 0, frame.width, min(height, frame.height))), (x, 50))
            x += frame.width + 20
        result.save(OUT / target)
    print(json.dumps(dict(captures=len(items), renderErrors=errors, missingVisibleWindowCandidates=missing)))
    if errors or missing:
        raise SystemExit('Android evidence has failed captures')


if __name__ == '__main__':
    main()
