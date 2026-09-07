"""Short looping demo GIF for BotFather /newapp (640x360)."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 640, 360
FRAMES = 16
DURATION_MS = 70
OUT = Path(__file__).resolve().parents[1] / "telegram-web" / "assets" / "branding" / "botfather_demo.gif"


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def rounded_cube(draw: ImageDraw.ImageDraw, x: float, y: float, size: float, fill: str, radius: float) -> None:
    box = [x, y, x + size, y + size]
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def add_glow(base: Image.Image, mask_color: tuple[int, int, int], radius: int) -> Image.Image:
    glow = Image.new("RGB", base.size, (14, 20, 25))
    blur = base.filter(ImageFilter.GaussianBlur(radius))
    return Image.blend(glow, blur, 0.55)


def draw_face(draw: ImageDraw.ImageDraw, x: float, y: float, size: float, worried: bool) -> None:
    eye_y = y + size * 0.38
    eye_r = size * 0.09
    lx = x + size * 0.32
    rx = x + size * 0.68
    draw.ellipse([lx - eye_r, eye_y - eye_r, lx + eye_r, eye_y + eye_r], fill="#F4FCFF")
    draw.ellipse([rx - eye_r, eye_y - eye_r, rx + eye_r, eye_y + eye_r], fill="#F4FCFF")
    pupil = size * 0.035
    off = size * 0.02 if worried else 0
    draw.ellipse([lx - pupil + off, eye_y - pupil, lx + pupil + off, eye_y + pupil], fill="#0E1419")
    draw.ellipse([rx - pupil + off, eye_y - pupil, rx + pupil + off, eye_y + pupil], fill="#0E1419")
    if worried:
        brow = size * 0.018
        draw.line([(lx - eye_r, eye_y - eye_r * 1.55), (lx + eye_r * 0.4, eye_y - eye_r * 1.15)], fill="#0E1419", width=max(2, int(brow * 2)))
        draw.line([(rx - eye_r * 0.4, eye_y - eye_r * 1.15), (rx + eye_r, eye_y - eye_r * 1.55)], fill="#0E1419", width=max(2, int(brow * 2)))
    else:
        brow = max(3, int(size * 0.05))
        draw.line([(lx - eye_r, eye_y - eye_r * 1.4), (lx + eye_r, eye_y - eye_r * 1.85)], fill="#1A0505", width=brow)
        draw.line([(rx - eye_r, eye_y - eye_r * 1.85), (rx + eye_r, eye_y - eye_r * 1.4)], fill="#1A0505", width=brow)


def frame_at(t: float) -> Image.Image:
    img = Image.new("RGB", (W, H), "#0E1419")
    draw = ImageDraw.Draw(img)

    # Field
    margin = 28
    field = [margin, 54, W - margin, H - 28]
    draw.rounded_rectangle(field, radius=22, fill="#172028", outline="#2A3A44", width=3)

    # Floor speed ticks
    for i in range(7):
        x = margin + 40 + (i * 78 + t * 90) % (W - margin * 2 - 80)
        y = H - 58
        draw.line([(x, y), (x + 18, y)], fill="#3A4A54", width=2)

    hero_size = 58
    red_size = 50
    path_y = 168 + math.sin(t * math.pi * 2) * 28
    hero_x = 250 + math.sin(t * math.pi * 2) * 70
    hero_y = path_y
    red_x = hero_x - 92 - math.sin(t * math.pi * 2 + 0.4) * 10
    red_y = path_y + 8 + math.cos(t * math.pi * 2) * 10

    # Red motion streaks
    for i in range(4):
        sx = red_x - 18 - i * 14
        sy = red_y + 12 + i * 3
        draw.rounded_rectangle([sx, sy, sx + 16, sy + 10], radius=4, fill="#7A2024")

    rounded_cube(draw, red_x, red_y, red_size, "#FF5A5F", 11)
    draw_face(draw, red_x, red_y, red_size, worried=False)

    rounded_cube(draw, hero_x, hero_y, hero_size, "#5EE6B0", 13)
    # cyan highlight
    draw.rounded_rectangle(
        [hero_x + 6, hero_y + 6, hero_x + 22, hero_y + 18],
        radius=6,
        fill="#7EE0FF",
    )
    draw_face(draw, hero_x, hero_y, hero_size, worried=True)

    # Title
    try:
        font = ImageFont.truetype("arialbd.ttf", 28)
        small = ImageFont.truetype("arial.ttf", 14)
    except OSError:
        font = ImageFont.load_default()
        small = font
    draw.text((40, 14), "UNTOUCH", fill="#F4FCFF", font=font)
    draw.text((178, 24), "dodge  ·  survive  ·  record", fill="#8B9AAB", font=small)
    return img


def main() -> None:
    frames = [frame_at(i / FRAMES) for i in range(FRAMES)]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        OUT,
        save_all=True,
        append_images=frames[1:],
        duration=DURATION_MS,
        loop=0,
        optimize=True,
    )
    print(OUT, OUT.stat().st_size)


if __name__ == "__main__":
    main()
