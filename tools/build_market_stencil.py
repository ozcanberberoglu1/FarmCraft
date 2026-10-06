"""Generates the delivery crate's stencil (white paint mask on transparent): the market's
name sprayed through a stencil plate, bridges in the letters, the paint worn by the boards.

Run from the project root:
  python3 tools/build_market_stencil.py art/textures/generated/market_stencil.png
(DeliveryCrate tints it; needs Pillow and macOS's Impact.ttf.)"""
import random
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

out = sys.argv[1]
W, H = 1024, 512
S = 2
font_path = "/System/Library/Fonts/Supplemental/Impact.ttf"
img = Image.new("L", (W * S, H * S), 0)
d = ImageDraw.Draw(img)


def line(text, size, y, track):
    f = ImageFont.truetype(font_path, size * S)
    widths = [d.textlength(ch, font=f) for ch in text]
    total = sum(widths) + track * S * (len(text) - 1)
    x = (W * S - total) / 2
    for ch, w in zip(text, widths):
        d.text((x, y * S), ch, font=f, fill=255)
        if ch.strip():
            # A stencil plate's bridge: a thin gap down the middle of the letter.
            bx = x + w / 2
            bw = 5 * S
            box = d.textbbox((x, y * S), ch, font=f)
            if ch not in "Iİ":
                d.rectangle([bx - bw / 2, box[1] - 4 * S, bx + bw / 2, box[3] + 4 * S], fill=0)
        x += w + track * S


line("YEŞİLOVA", 212, 6, 14)
line("MARKET", 150, 262, 46)
# A rule above and below the second line, broken like the plate's.
for y in (258, 452):
    for x0, x1 in ((120, 480), (544, 904)):
        d.rectangle([x0 * S, y * S, x1 * S, (y + 9) * S], fill=255)
img = img.resize((W, H), Image.LANCZOS)
# Sprayed paint: soft edges, a faint overspray, worn patches and the grain showing through.
soft = img.filter(ImageFilter.GaussianBlur(1.2))
over = img.filter(ImageFilter.GaussianBlur(9)).point(lambda v: int(v * 0.16))
rnd = random.Random(7)
wear = Image.new("L", (W // 8, H // 8))
wear.putdata([rnd.randint(0, 255) for _ in range((W // 8) * (H // 8))])
wear = wear.resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(5))
wear = wear.point(lambda v: 255 if v > 84 else int(165 + v * 0.9))
# The boards' grain shows through as faint streaks along them (X).
streak = Image.new("L", (W // 64, H))
streak.putdata([rnd.randint(205, 255) for _ in range((W // 64) * H)])
streak = streak.resize((W, H), Image.BILINEAR).filter(ImageFilter.GaussianBlur(0.8))
a = ImageChops.lighter(soft, over)
a = ImageChops.multiply(a, wear)
a = ImageChops.multiply(a, streak)
rgba = Image.merge("RGBA", (Image.new("L", (W, H), 255),) * 3 + (a,))
rgba.save(out)
print("saved", out)
