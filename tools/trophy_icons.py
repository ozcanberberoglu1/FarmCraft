#!/usr/bin/env python3
"""Makes the trophy fish icons (art/icons/items/fish_<species>_trophy.png): the species'
own icon (tools/icon_studio.gd) with a gold rosette in its top right corner, so a giant
reads apart from an ordinary catch in the bag. Run from the project root after the icon
studio:  python3 tools/trophy_icons.py   (needs Pillow; reruns give the same files)
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "icons", "items")
SPECIES = ["rudd", "crucian", "perch", "crayfish", "carp", "tench", "trout", "zander", "pike", "catfish"]


def star(cx, cy, r_out, r_in, n=5):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = -math.pi / 2 + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def badge(size):
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    # Ribbon tails under the medal.
    for dx in (-1, 1):
        x = c + dx * s * 0.14
        d.polygon([(x - s * 0.1, c), (x + s * 0.1, c), (x + s * 0.08 + dx * s * 0.04, s * 0.98),
                   (x + dx * s * 0.02, s * 0.88), (x - s * 0.08 + dx * s * 0.04, s * 0.98)], fill=(176, 38, 34, 255))
    r = s * 0.36
    d.ellipse([c - r - s * 0.03, c - r - s * 0.06, c + r + s * 0.03, c + r], fill=(122, 78, 18, 255))
    d.ellipse([c - r, c - r - s * 0.03, c + r, c + r - s * 0.03], fill=(236, 186, 72, 255))
    r2 = r * 0.8
    d.ellipse([c - r2, c - r2 - s * 0.03, c + r2, c + r2 - s * 0.03], fill=(250, 214, 110, 255))
    d.polygon(star(c, c - s * 0.03, r2 * 0.78, r2 * 0.34), fill=(255, 250, 225, 255))
    img = img.resize((size, size), Image.LANCZOS)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 110), mask=img.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.04))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, (int(size * 0.03), int(size * 0.04)))
    out.alpha_composite(img)
    return out


def main():
    for sp in SPECIES:
        src = os.path.join(DIR, f"fish_{sp}.png")
        if not os.path.exists(src):
            continue
        icon = Image.open(src).convert("RGBA")
        w = icon.width
        b = badge(int(w * 0.36))
        icon.alpha_composite(b, (w - b.width - int(w * 0.02), int(w * 0.02)))
        icon.save(os.path.join(DIR, f"fish_{sp}_trophy.png"))
        print("trophy icon", sp)


if __name__ == "__main__":
    main()
