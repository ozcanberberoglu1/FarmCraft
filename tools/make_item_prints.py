#!/usr/bin/env python3
"""Paints the printed faces of packaged items procedurally: the bag of dog food Zeynep
asks for (ItemModels._dog_food): its front (the brand, a smiling dog, a bowl of kibble,
the weight) on the left half of the atlas and its back (the brand small, a feeding table
and the small print as grey lines, a barcode) on the right half.

Run from the project root:  python3 tools/make_item_prints.py
Needs Pillow; the lettering uses the game's Barlow fonts (art/fonts). Deterministic.
Output: art/textures/items/dog_food_print.png (1024 x 768, RGB).
"""
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "art", "textures", "items")
FONTS = os.path.join(ROOT, "art", "fonts")

W, H = 512, 768
RED = (196, 62, 38)
RED_DARK = (150, 40, 26)
CREAM = (250, 240, 222)
GOLD = (236, 176, 64)
BROWN = (120, 72, 38)
TAN = (206, 146, 84)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def centered(d, cx, y, text, f, fill):
    w = d.textlength(text, font=f)
    d.text((cx - w / 2, y), text, font=f, fill=fill)


def backdrop(img, x0):
    d = ImageDraw.Draw(img)
    # A warm red face, a little darker toward the foot.
    for y in range(H):
        t = y / H
        c = tuple(int(RED[i] * (1.0 - 0.25 * t) + RED_DARK[i] * 0.25 * t) for i in range(3))
        d.line([(x0, y), (x0 + W, y)], fill=c)
    # The cream band across the top and a gold rule under it.
    d.rectangle([x0, 0, x0 + W, 190], fill=CREAM)
    d.rectangle([x0, 190, x0 + W, 204], fill=GOLD)
    return d


def dog_head(d, cx, cy, s):
    # Floppy ears, the head, a lighter muzzle, eyes, the nose and a tongue.
    d.ellipse([cx - 1.05 * s, cy - 0.55 * s, cx - 0.45 * s, cy + 0.75 * s], fill=BROWN)
    d.ellipse([cx + 0.45 * s, cy - 0.55 * s, cx + 1.05 * s, cy + 0.75 * s], fill=BROWN)
    d.ellipse([cx - 0.78 * s, cy - 0.8 * s, cx + 0.78 * s, cy + 0.72 * s], fill=TAN)
    d.ellipse([cx - 0.45 * s, cy + 0.05 * s, cx + 0.45 * s, cy + 0.72 * s], fill=(240, 214, 176))
    for ex in (-0.32, 0.32):
        d.ellipse([cx + (ex - 0.1) * s, cy - 0.28 * s, cx + (ex + 0.1) * s, cy - 0.06 * s], fill=(40, 26, 18))
        d.ellipse([cx + (ex - 0.03) * s, cy - 0.24 * s, cx + (ex + 0.02) * s, cy - 0.18 * s], fill=(255, 255, 255))
    d.ellipse([cx - 0.16 * s, cy + 0.12 * s, cx + 0.16 * s, cy + 0.32 * s], fill=(34, 22, 16))
    d.arc([cx - 0.22 * s, cy + 0.2 * s, cx + 0.22 * s, cy + 0.52 * s], 20, 160, fill=(34, 22, 16), width=max(2, int(s * 0.04)))
    d.ellipse([cx - 0.1 * s, cy + 0.44 * s, cx + 0.1 * s, cy + 0.66 * s], fill=(222, 96, 104))


def kibble_bowl(d, cx, cy, s, rng):
    d.ellipse([cx - s, cy - 0.25 * s, cx + s, cy + 0.25 * s], fill=(96, 56, 30))
    for _ in range(70):
        a = rng.uniform(-0.9, 0.9)
        b = rng.uniform(-0.18, 0.1)
        r = rng.uniform(0.07, 0.11) * s
        x, y = cx + a * s, cy + b * s - 0.08 * s
        tone = rng.randint(-18, 18)
        d.ellipse([x - r, y - r * 0.8, x + r, y + r * 0.8], fill=(150 + tone, 92 + tone, 48 + tone))
    d.chord([cx - 1.02 * s, cy - 0.1 * s, cx + 1.02 * s, cy + 0.75 * s], 0, 180, fill=(226, 228, 230))
    d.rectangle([cx - 1.02 * s, cy + 0.02 * s, cx + 1.02 * s, cy + 0.06 * s], fill=(200, 202, 206))


def front(img, rng):
    d = backdrop(img, 0)
    centered(d, W / 2, 14, "PATİ", font("BarlowCondensed-Bold.ttf", 118), RED)
    centered(d, W / 2, 146, "YETİŞKİN KÖPEK MAMASI", font("Barlow-Bold.ttf", 29), BROWN)
    # The dog in a cream roundel.
    d.ellipse([W / 2 - 170, 250, W / 2 + 170, 590], fill=(236, 110, 72))
    d.ellipse([W / 2 - 158, 262, W / 2 + 158, 578], fill=CREAM)
    dog_head(d, W / 2, 400, 112)
    kibble_bowl(d, W / 2, 610, 96, rng)
    centered(d, W / 2, 684, "Tavuklu & Pirinçli", font("Barlow-Bold.ttf", 34), CREAM)
    # The weight on a gold seal.
    d.ellipse([W - 150, 212, W - 30, 332], fill=GOLD)
    d.ellipse([W - 142, 220, W - 38, 324], outline=CREAM, width=3)
    centered(d, W - 90, 236, "3", font("BarlowCondensed-Bold.ttf", 60), RED_DARK)
    centered(d, W - 90, 292, "kg", font("Barlow-Bold.ttf", 24), RED_DARK)


def back(img, rng):
    x0 = W
    d = backdrop(img, x0)
    centered(d, x0 + W / 2, 40, "PATİ", font("BarlowCondensed-Bold.ttf", 96), RED)
    centered(d, x0 + W / 2, 146, "Günlük Besleme", font("Barlow-Bold.ttf", 30), BROWN)
    # A feeding table and the small print, as lines of text too small to read.
    d.rounded_rectangle([x0 + 40, 240, x0 + W - 40, 470], 14, fill=CREAM)
    for k in range(6):
        y = 262 + k * 34
        d.rectangle([x0 + 60, y, x0 + 230, y + 12], fill=(150, 130, 110))
        d.rectangle([x0 + 300, y, x0 + 450, y + 12], fill=(150, 130, 110))
        if k:
            d.line([(x0 + 52, y - 11), (x0 + W - 52, y - 11)], fill=(214, 200, 180), width=2)
    for k in range(9):
        w = rng.randint(260, 420)
        d.rectangle([x0 + 44, 500 + k * 22, x0 + 44 + w, 510 + k * 22], fill=(236, 190, 170))
    # The barcode.
    d.rectangle([x0 + W - 200, 640, x0 + W - 40, 730], fill=(255, 255, 255))
    x = x0 + W - 190
    while x < x0 + W - 52:
        bw = rng.choice([2, 2, 3, 4])
        d.rectangle([x, 648, x + bw - 1, 712], fill=(20, 20, 20))
        x += bw + rng.choice([2, 3, 4])
    centered(d, x0 + W - 120, 712, "8 690000 123456", font("Barlow-Bold.ttf", 14), (20, 20, 20))


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = random.Random(7)
    img = Image.new("RGB", (W * 2, H), CREAM)
    front(img, rng)
    back(img, rng)
    # A breath of blur so the print isn't sharper than the rest of the game.
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT, "dog_food_print.png"))
    print("wrote", os.path.join(OUT, "dog_food_print.png"))


if __name__ == "__main__":
    main()
