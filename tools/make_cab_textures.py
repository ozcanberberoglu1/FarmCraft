#!/usr/bin/env python3
"""Draws the cab interior's textures (art/textures/cab), shared by every vehicle:
tiling grain sets for moulded plastic, vinyl, woven seat cloth, ribbed rubber matting
and perforated headliner (colour near white, to be tinted; a normal map; a map with
the cavities in red and the roughness in green), and one atlas of printed faces (the
instrument cluster, the radio, the heater panel, a speaker grille, the gear pattern, a
sun visor label). vehicle_interior.gdshader lays the grain over a part by its position
(no UVs needed); tools/blender/cab_kit.py maps the atlas (DECALS below).

No outside assets: noise, weaves and drawing only (lettering in Barlow Condensed Bold,
art/fonts, SIL Open Font License). Run: python3 tools/make_cab_textures.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "art", "textures", "cab")
FONT = os.path.join(ROOT, "art", "fonts", "BarlowCondensed-Bold.ttf")
N = 1024

# Atlas rectangles in pixels (x, y, w, h) of the 1024 x 1024 decal sheet.
DECALS = {
    "cluster": (0, 0, 640, 240),
    "radio": (0, 256, 512, 152),
    "heater": (0, 424, 512, 120),
    "speaker": (656, 0, 256, 256),
    "shift": (656, 272, 128, 128),
    "label": (800, 272, 208, 104),
    "slats": (656, 416, 256, 128),
}

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality={hq}
compress/lossy_quality=0.7
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/size_limit=0
detect_3d/compress_to=0
"""

rng = np.random.default_rng(1990)


def noise(lo: float, hi: float) -> np.ndarray:
    """Tiling noise with features between `lo` and `hi` cycles across the tile, 0..1."""
    spec = np.fft.fft2(rng.standard_normal((N, N)))
    fx = np.fft.fftfreq(N) * N
    f = np.sqrt(fx[None, :] ** 2 + fx[:, None] ** 2)
    band = np.exp(-((f - (lo + hi) * 0.5) / max((hi - lo) * 0.5, 1e-3)) ** 2)
    out = np.real(np.fft.ifft2(spec * band))
    out -= out.min()
    return out / max(out.max(), 1e-9)


def blur(a: np.ndarray, sigma: float) -> np.ndarray:
    """Wrap-around Gaussian blur."""
    fx = np.fft.fftfreq(N)
    g = np.exp(-2.0 * (math.pi * sigma) ** 2 * (fx[None, :] ** 2 + fx[:, None] ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def normal_from(height: np.ndarray, strength: float) -> np.ndarray:
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5 * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5 * strength
    n = np.stack([-dx, dy, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def save(name: str, arr: np.ndarray, normal=False, hq=False) -> None:
    os.makedirs(OUT, exist_ok=True)
    a = np.clip(arr, 0.0, 1.0)
    if a.ndim == 2:
        a = np.stack([a, a, a], -1)
    path = os.path.join(OUT, name)
    Image.fromarray((a * 255.0 + 0.5).astype(np.uint8), "RGB").save(path, optimize=True)
    if not os.path.exists(path + ".import"):
        with open(path + ".import", "w") as fh:
            fh.write(IMPORT.format(normal=int(normal), hq="true" if hq else "false"))


def save_set(kind: str, albedo, height, strength, rough, cavity) -> None:
    save(kind + "_albedo.png", albedo, hq=True)
    save(kind + "_nor.png", normal_from(height, strength), normal=True)
    save(kind + "_orm.png", np.stack([cavity, rough, np.zeros_like(rough)], -1))


def plastic() -> None:
    """Moulded dash plastic: a pebbled grain a millimetre across (the tile is 12 cm)."""
    cells = noise(70, 130)
    fine = noise(180, 300)
    height = cells * 0.75 + fine * 0.25
    mottle = noise(1, 5)
    albedo = 0.84 + 0.1 * (mottle - 0.5) + 0.08 * (height - 0.5)
    rough = 0.62 + 0.16 * (height - 0.5) + 0.08 * (mottle - 0.5)
    cavity = np.clip(0.55 + (height - 0.35) * 1.3, 0, 1)
    save_set("plastic", albedo, height, 9.0, rough, cavity)


def vinyl() -> None:
    """Seat and door vinyl: a leather grain of creased cells (the tile is 20 cm)."""
    a = noise(34, 62)
    b = noise(38, 70)
    creases = np.minimum(np.abs(a - 0.5), np.abs(b - 0.5)) * 2.0  # 0 on a crease line
    creases = np.clip(creases * 5.0, 0, 1) ** 0.6
    pores = noise(150, 260)
    height = creases * 0.8 + pores * 0.2
    mottle = noise(1, 4)
    wrinkles = noise(3, 9)
    albedo = 0.82 + 0.1 * (mottle - 0.5) + 0.12 * (creases - 0.7) + 0.05 * (wrinkles - 0.5)
    rough = 0.5 + 0.2 * (1.0 - creases) + 0.1 * (mottle - 0.5)
    save_set("vinyl", albedo, height + 0.6 * blur(wrinkles, 2.0), 7.0, rough, np.clip(creases * 0.8 + 0.2, 0, 1))


def cloth() -> None:
    """Woven seat cloth: a plain weave of 1.2 mm yarns with a pin stripe every 2.5 cm
    (the tile is 10 cm)."""
    y, x = np.mgrid[0:N, 0:N].astype(np.float64)
    yarns = 80.0
    u = x / N * yarns
    v = y / N * yarns
    over = ((np.floor(u) + np.floor(v)) % 2.0)  # 1: the warp is on top
    warp = np.sin(math.pi * (u % 1.0)) ** 0.7 * (0.55 + 0.45 * np.cos(math.pi * ((v % 1.0) - 0.5)) ** 2)
    weft = np.sin(math.pi * (v % 1.0)) ** 0.7 * (0.55 + 0.45 * np.cos(math.pi * ((u % 1.0) - 0.5)) ** 2)
    height = np.where(over > 0.5, warp, weft)
    fuzz = noise(120, 320)
    heather = noise(40, 90)
    height = height * 0.8 + fuzz * 0.2
    stripe = (np.cos(2.0 * math.pi * x / N * 4.0) > 0.92).astype(np.float64)
    stripe2 = (np.cos(2.0 * math.pi * (x / N * 4.0 + 0.5)) > 0.975).astype(np.float64)
    tone = np.where(over > 0.5, 0.86, 0.72)
    albedo = tone * (0.72 + 0.34 * height) + 0.14 * (heather - 0.5)
    albedo = albedo * (1.0 - 0.38 * stripe) + 0.16 * stripe2
    mottle = noise(1, 4)
    albedo += 0.07 * (mottle - 0.5)
    rough = np.full((N, N), 0.93) - 0.06 * height
    save_set("cloth", albedo, height, 6.0, rough, np.clip(0.35 + height * 0.75, 0, 1))


def rubber() -> None:
    """Floor matting: ribs 1.25 cm apart with a cross break every 10 cm (the tile is
    20 cm); the grooves hold the dust (cavity)."""
    y, x = np.mgrid[0:N, 0:N].astype(np.float64)
    ribs = 16.0
    r = (x / N * ribs) % 1.0
    rib = np.clip((0.5 - np.abs(r - 0.5)) * 5.0, 0, 1) ** 0.6
    cross = np.clip(np.abs(((y / N * 2.0) % 1.0) - 0.5) * 40.0 - 0.6, 0, 1)
    height = rib * cross
    grit = noise(140, 300)
    scuff = noise(2, 7)
    height = height * 0.9 + grit * 0.1
    albedo = 0.8 + 0.1 * (height - 0.5) + 0.1 * (scuff - 0.5)
    rough = 0.78 - 0.2 * height * np.clip(scuff * 1.6 - 0.3, 0, 1) + 0.06 * (grit - 0.5)
    save_set("rubber", albedo, height, 14.0, rough, np.clip(height * 1.1, 0, 1))


def liner() -> None:
    """Perforated vinyl headliner: pin holes on a 6 mm staggered grid (the tile is 12 cm)."""
    y, x = np.mgrid[0:N, 0:N].astype(np.float64)
    cells = 20.0
    u = x / N * cells
    v = y / N * cells
    u2 = u + 0.5 * (np.floor(v) % 2.0)
    d = np.sqrt(((u2 % 1.0) - 0.5) ** 2 + ((v % 1.0) - 0.5) ** 2)
    hole = np.clip((0.2 - d) * 12.0, 0, 1)
    grain = noise(90, 200)
    sag = noise(1, 4)
    height = (1.0 - hole) * 0.85 + grain * 0.15
    albedo = (0.86 + 0.06 * (grain - 0.5) + 0.08 * (sag - 0.5)) * (1.0 - 0.72 * hole)
    rough = 0.72 + 0.1 * (grain - 0.5) + 0.2 * hole
    save_set("liner", albedo, height, 8.0, rough, 1.0 - hole * 0.9)


# --- The printed faces --------------------------------------------------------------------

def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT, size)


def dial(d: ImageDraw.ImageDraw, c, r, a0, a1, lo, hi, major, minor, labels, size, unit=None):
    """A dial face: ticks from angle a0 (at `lo`) clockwise to a1 (at `hi`), degrees
    anticlockwise from the right as the driver sees it."""
    ivory = (232, 226, 205)
    steps = int(round((hi - lo) / minor))
    for k in range(steps + 1):
        val = lo + k * minor
        a = math.radians(a0 + (a1 - a0) * (val - lo) / (hi - lo))
        big = abs(val / major - round(val / major)) < 1e-6
        r0 = r * (0.8 if big else 0.88)
        d.line([c[0] + math.cos(a) * r0, c[1] - math.sin(a) * r0, c[0] + math.cos(a) * r * 0.97, c[1] - math.sin(a) * r * 0.97],
               fill=ivory, width=4 if big else 2)
        if big and labels:
            t = "%d" % val
            f = font(size)
            box = d.textbbox((0, 0), t, font=f)
            rr = r * 0.62
            d.text((c[0] + math.cos(a) * rr - (box[2] - box[0]) * 0.5, c[1] - math.sin(a) * rr - (box[3] + box[1]) * 0.5), t,
                   fill=ivory, font=f)
    if unit:
        f = font(int(size * 0.8))
        box = d.textbbox((0, 0), unit, font=f)
        d.text((c[0] - (box[2] - box[0]) * 0.5, c[1] + r * 0.36), unit, fill=(170, 165, 150), font=f)


def decals() -> None:
    S = 4  # drawn four times the size, then scaled down
    img = Image.new("RGB", (N * S, N * S), (10, 10, 11))
    d = ImageDraw.Draw(img)

    def R(key, pad=0):
        x, y, w, h = DECALS[key]
        return [(x + pad) * S, (y + pad) * S, (x + w - pad) * S, (y + h - pad) * S]

    ivory = (232, 226, 205)
    # Instrument cluster: speedometer, fuel and temperature, the odometer, tell-tales.
    x, y, w, h = [v * S for v in DECALS["cluster"]]
    d.rectangle(R("cluster"), fill=(14, 14, 15))
    d.rounded_rectangle([x + 6 * S, y + 6 * S, x + w - 6 * S, y + h - 6 * S], radius=14 * S, fill=(5, 5, 6))
    sc = (x + 170 * S, y + 125 * S)
    d.ellipse([sc[0] - 104 * S, sc[1] - 104 * S, sc[0] + 104 * S, sc[1] + 104 * S], fill=(9, 9, 10), outline=(40, 40, 42), width=2 * S)
    dial(d, sc, 100 * S, 225, -45, 0, 160, 20, 10, True, 19 * S, "km/h")
    # Odometer window.
    ox, oy = sc[0] - 40 * S, sc[1] + 52 * S
    d.rectangle([ox, oy, ox + 80 * S, oy + 20 * S], fill=(2, 2, 2), outline=(60, 60, 60), width=S)
    for k, ch in enumerate("184306"):
        cell = [ox + (2 + k * 13) * S, oy + 2 * S, ox + (2 + k * 13 + 12) * S, oy + 18 * S]
        d.rectangle(cell, fill=(225, 220, 205) if k == 5 else (20, 20, 20))
        d.text((cell[0] + 3 * S, cell[1] - 2 * S), ch, fill=(15, 15, 15) if k == 5 else ivory, font=font(16 * S))
    for cx, name, lab in ((430, "fuel", ("E", "F")), (560, "temp", ("C", "H"))):
        c = (x + cx * S, y + 95 * S)
        d.ellipse([c[0] - 62 * S, c[1] - 62 * S, c[0] + 62 * S, c[1] + 62 * S], fill=(9, 9, 10), outline=(40, 40, 42), width=2 * S)
        dial(d, c, 58 * S, 150, 30, 0, 4, 2, 1, False, 14 * S)
        d.text((c[0] - 44 * S, c[1] - 14 * S), lab[0], fill=ivory, font=font(18 * S))
        d.text((c[0] + 34 * S, c[1] - 14 * S), lab[1], fill=(205, 60, 40) if name == "temp" else ivory, font=font(18 * S))
        if name == "fuel":
            a = math.radians(150)
            d.line([c[0] + math.cos(a) * 46 * S, c[1] - math.sin(a) * 46 * S, c[0] + math.cos(a) * 57 * S, c[1] - math.sin(a) * 57 * S],
                   fill=(205, 60, 40), width=5 * S)
            # A pump pictogram.
            d.rectangle([c[0] - 8 * S, c[1] + 22 * S, c[0] + 4 * S, c[1] + 40 * S], outline=ivory, width=2 * S)
            d.line([c[0] + 4 * S, c[1] + 28 * S, c[0] + 10 * S, c[1] + 26 * S, c[0] + 10 * S, c[1] + 38 * S], fill=ivory, width=2 * S)
        else:
            d.line([c[0] - 8 * S, c[1] + 24 * S, c[0] - 8 * S, c[1] + 40 * S], fill=ivory, width=3 * S)
            for k in range(3):
                d.line([c[0] - 8 * S, c[1] + (26 + k * 6) * S, c[0] + 2 * S, c[1] + (26 + k * 6) * S], fill=ivory, width=2 * S)
    # Tell-tales along the bottom, unlit.
    for k, col in enumerate(((60, 22, 18), (60, 22, 18), (62, 50, 16), (18, 46, 24), (18, 46, 24), (18, 28, 60))):
        bx = x + (372 + k * 40) * S
        d.rounded_rectangle([bx, y + 178 * S, bx + 30 * S, y + 204 * S], radius=4 * S, fill=col)
    # The radio: a cassette deck, its display window left dark for the lit display.
    x, y, w, h = [v * S for v in DECALS["radio"]]
    d.rectangle(R("radio"), fill=(16, 16, 17))
    d.rounded_rectangle(R("radio", 5), radius=6 * S, fill=(8, 8, 9), outline=(52, 52, 54), width=S)
    d.rectangle([x + 150 * S, y + 22 * S, x + 362 * S, y + 60 * S], fill=(3, 5, 4), outline=(70, 70, 72), width=2 * S)
    d.rounded_rectangle([x + 150 * S, y + 74 * S, x + 362 * S, y + 100 * S], radius=3 * S, fill=(2, 2, 2), outline=(58, 58, 60), width=2 * S)
    for k in range(5):
        bx = x + (128 + k * 52) * S
        d.rounded_rectangle([bx, y + 112 * S, bx + 44 * S, y + 136 * S], radius=3 * S, fill=(26, 26, 28), outline=(64, 64, 66), width=S)
        d.text((bx + 18 * S, y + 113 * S), "%d" % (k + 1), fill=(190, 186, 170), font=font(18 * S))
    d.text((x + 384 * S, y + 22 * S), "FM", fill=(200, 120, 40), font=font(16 * S))
    d.text((x + 384 * S, y + 42 * S), "AM", fill=(120, 118, 108), font=font(16 * S))
    for cx, lab in ((62, "VOL"), (450, "TUNE")):
        d.ellipse([x + (cx - 34) * S, y + 36 * S, x + (cx + 34) * S, y + 104 * S], outline=(58, 58, 60), width=2 * S)
        f = font(15 * S)
        box = d.textbbox((0, 0), lab, font=f)
        d.text((x + cx * S - (box[2] - box[0]) * 0.5, y + 116 * S), lab, fill=(170, 166, 150), font=f)
    # The heater panel: three slider slots (temperature blue to red, air, fan).
    x, y, w, h = [v * S for v in DECALS["heater"]]
    d.rectangle(R("heater"), fill=(15, 15, 16))
    d.rounded_rectangle(R("heater", 4), radius=5 * S, fill=(9, 9, 10), outline=(50, 50, 52), width=S)
    for k in range(3):
        sy = y + (30 + k * 32) * S
        d.rounded_rectangle([x + 70 * S, sy - 4 * S, x + 440 * S, sy + 4 * S], radius=4 * S, fill=(1, 1, 1), outline=(46, 46, 48), width=S)
        if k == 0:
            for px in range(70 * S, 440 * S, S):
                t = (px - 70 * S) / (370.0 * S)
                d.line([x + px, sy - 12 * S, x + px, sy - 8 * S], fill=(int(40 + 180 * t), 50, int(200 - 170 * t)))
        elif k == 2:
            for j, t in enumerate(("0", "1", "2", "3")):
                d.text((x + (76 + j * 119) * S, sy - 24 * S), t, fill=(190, 186, 170), font=font(14 * S))
        else:
            for j in range(4):
                bx = x + (84 + j * 116) * S
                d.polygon([bx, sy - 20 * S, bx + 12 * S, sy - 20 * S, bx + 6 * S, sy - 10 * S], fill=(170, 166, 150))
    for k, t in enumerate(("TEMP", "AIR", "FAN")):
        d.text((x + 16 * S, y + (20 + k * 32) * S), t, fill=(170, 166, 150), font=font(15 * S))
    # A speaker grille: punched holes in a dished disc.
    x, y, w, h = [v * S for v in DECALS["speaker"]]
    d.rectangle(R("speaker"), fill=(20, 20, 21))
    c = (x + w * 0.5, y + h * 0.5)
    d.ellipse([c[0] - 120 * S, c[1] - 120 * S, c[0] + 120 * S, c[1] + 120 * S], fill=(13, 13, 14), outline=(44, 44, 46), width=3 * S)
    for j in range(-12, 13):
        for i in range(-12, 13):
            px = c[0] + (i + 0.5 * (j % 2)) * 9.2 * S
            py = c[1] + j * 8.0 * S
            if math.hypot(px - c[0], py - c[1]) < 108 * S:
                d.ellipse([px - 2.6 * S, py - 2.6 * S, px + 2.6 * S, py + 2.6 * S], fill=(0, 0, 0))
    # The gear pattern on the knob.
    x, y, w, h = [v * S for v in DECALS["shift"]]
    d.rectangle(R("shift"), fill=(12, 12, 13))
    for k, gx in enumerate((34, 64, 94)):
        d.line([x + gx * S, y + 40 * S, x + gx * S, y + 88 * S], fill=ivory, width=3 * S)
    d.line([x + 34 * S, y + 64 * S, x + 94 * S, y + 64 * S], fill=ivory, width=3 * S)
    for t, tx, ty in (("1", 28, 14), ("3", 58, 14), ("5", 88, 14), ("2", 28, 90), ("4", 58, 90), ("R", 88, 90)):
        d.text((x + tx * S, y + ty * S), t, fill=ivory, font=font(22 * S))
    # A sun visor label: a yellowed sticker with a few lines of small print.
    x, y, w, h = [v * S for v in DECALS["label"]]
    d.rectangle(R("label"), fill=(206, 198, 170))
    d.rectangle([x + 6 * S, y + 6 * S, x + w - 6 * S, y + 26 * S], fill=(150, 40, 30))
    d.text((x + 12 * S, y + 4 * S), "DİKKAT", fill=(235, 228, 205), font=font(20 * S))
    for k in range(5):
        d.line([x + 10 * S, y + (40 + k * 12) * S, x + (w / S - 14 - (k * 23) % 60) * S, y + (40 + k * 12) * S], fill=(70, 66, 58), width=3 * S)
    # Vent slats: dark louvres with a lit top edge.
    x, y, w, h = [v * S for v in DECALS["slats"]]
    d.rectangle(R("slats"), fill=(3, 3, 3))
    for k in range(6):
        sy = y + (8 + k * 20) * S
        d.rectangle([x, sy, x + w, sy + 9 * S], fill=(26, 26, 27))
        d.rectangle([x, sy, x + w, sy + 2 * S], fill=(52, 52, 54))
    img = img.filter(ImageFilter.GaussianBlur(0.6 * S)).resize((N, N), Image.LANCZOS)
    arr = np.asarray(img).astype(np.float64) / 255.0
    # Printing and dust: a trace of noise so the black is not a flat void.
    arr = arr + (0.012 * (noise(60, 200) - 0.5))[..., None]
    save("decals_albedo.png", arr, hq=True)


if __name__ == "__main__":
    plastic()
    vinyl()
    cloth()
    rubber()
    liner()
    decals()
    print("wrote", OUT)
