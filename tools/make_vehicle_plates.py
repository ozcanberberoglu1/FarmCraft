#!/usr/bin/env python3
"""Draws the vehicles' Turkish number plates (the two-line 32 x 15 cm plate that fits a
US-size plate recess: blue TR band on the left, province code and letters over the
number) into art/models/vehicles/plates/<vehicle>.png. Yeşilova is in Burdur (15).
Grandpa's plate is sun-yellowed, grimy from the bottom up, with rust run from its bolts.
Needs Pillow; uses the game's Barlow Condensed (SIL OFL). Run from the project root:
python3 tools/make_vehicle_plates.py"""
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "art", "models", "vehicles", "plates")
FONT = os.path.join(ROOT, "art", "fonts", "BarlowCondensed-Bold.ttf")
W, H = 512, 248
# vehicle -> (top line, bottom line, worn)
PLATES = {
    "pickup_90": ("15 BK", "905", False),
    "pickup_old": ("15 AY", "172", True),
}
# Kept at or below ~0.8 sRGB like every bright albedo in the game.
WHITE = (206, 206, 200)
INK = (22, 22, 24)
BLUE = (18, 52, 140)


def plate(top, bottom, worn, seed):
    rng = random.Random(seed)
    img = Image.new("RGB", (W, H), WHITE)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((3, 3, W - 4, H - 4), radius=14, outline=INK, width=5)
    band = 64
    d.rounded_rectangle((8, 8, 8 + band, H - 9), radius=9, fill=BLUE)
    d.rectangle((8 + band - 10, 8, 8 + band, H - 9), fill=BLUE)
    small = ImageFont.truetype(FONT, 46)
    d.text((8 + band / 2, H - 30), "TR", font=small, fill=(232, 232, 228), anchor="ms")
    big = ImageFont.truetype(FONT, 112)
    cx = (8 + band + W - 8) / 2
    d.text((cx, 112), top, font=big, fill=INK, anchor="ms")
    d.text((cx, 226), bottom, font=big, fill=INK, anchor="ms")
    bolts = [(8 + band + 40, 30), (W - 40, 30)]
    for bx, by in bolts:
        d.ellipse((bx - 9, by - 9, bx + 9, by + 9), fill=(150, 150, 146), outline=(90, 90, 88), width=2)
    if not worn:
        return img
    # Sun-yellowed sheeting, grime rising from the bottom edge, specks and runs of rust
    # under the bolts, the band faded.
    img = ImageChops.multiply(img, Image.new("RGB", (W, H), (236, 226, 196)))
    grime = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(grime)
    for y in range(H):
        a = max(0.0, (y / H - 0.35) / 0.65) ** 1.6
        gd.line((0, y, W, y), fill=int(150 * a))
    for _ in range(900):
        x, y = rng.randrange(W), rng.randrange(H)
        r = rng.choice((1, 1, 2, 3))
        gd.ellipse((x - r, y - r, x + r, y + r), fill=rng.randrange(40, 150))
    grime = grime.filter(ImageFilter.GaussianBlur(1.6))
    img = Image.composite(Image.new("RGB", (W, H), (118, 100, 76)), img, grime)
    rust = Image.new("L", (W, H), 0)
    rd = ImageDraw.Draw(rust)
    for bx, by in bolts:
        rd.ellipse((bx - 12, by - 12, bx + 12, by + 12), fill=200)
        for _ in range(7):
            x = bx + rng.randint(-8, 8)
            rd.line((x, by, x + rng.randint(-3, 3), by + rng.randint(30, 90)), fill=rng.randrange(60, 140), width=rng.choice((2, 3)))
    rust = rust.filter(ImageFilter.GaussianBlur(2.2))
    img = Image.composite(Image.new("RGB", (W, H), (112, 58, 26)), img, rust)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for i, (vehicle, (top, bottom, worn)) in enumerate(PLATES.items()):
        path = os.path.join(OUT, f"{vehicle}.png")
        plate(top, bottom, worn, 17 + i).save(path, optimize=True)
        print("wrote", path)


if __name__ == "__main__":
    main()
