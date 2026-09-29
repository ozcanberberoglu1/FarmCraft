#!/usr/bin/env python3
"""Paints the town's textures procedurally: the decals (oil stains, asphalt patches,
sealed cracks, dirt along the kerbs, the worn zebra crossing and road lines, rain
streaks, tyre marks, pen mud) and the print atlas (the flag, street name plates, road
signs, shop posters, the dealer's banners) used by scripts/world/town.gd.

Run from the project root:  python3 art/textures/town/make_town_textures.py
Needs numpy and Pillow; the lettering uses the game's Barlow fonts (art/fonts).
Output: art/textures/town/decal_*.png (RGBA, straight alpha) and town_print_albedo.png.
The decals stay small (256-512 px): Godot copies them into its uncompressed decal atlas.
Deterministic (fixed seeds), so re-running gives the same images. The atlas regions
are printed as the GDScript dictionary Town.PRINT (keep the two in step).
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.dirname(os.path.abspath(__file__))


def value_noise(shape, cells, rng):
    """Smooth value noise in [0, 1]: a random grid of `cells` upsampled bicubically."""
    h, w = shape
    cy, cx = max(2, int(cells[0])), max(2, int(cells[1]))
    grid = rng.random((cy + 3, cx + 3)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8))
    # Oversize and crop so the edge cells don't stretch.
    big = img.resize((int(w * (cx + 3) / cx), int(h * (cy + 3) / cy)), Image.BICUBIC)
    a = np.asarray(big, dtype=np.float32)[: h, : w] / 255.0
    return a


def fbm(shape, base, octaves, rng, gain=0.5):
    out = np.zeros(shape, np.float32)
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        f = 2 ** o
        out += value_noise(shape, (base[0] * f, base[1] * f), rng) * amp
        norm += amp
        amp *= gain
    return out / norm


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def save(name, rgb, alpha):
    h, w = alpha.shape
    img = np.zeros((h, w, 4), np.float32)
    img[..., :3] = rgb
    img[..., 3] = np.clip(alpha, 0.0, 1.0)
    # Straight alpha: fill fully transparent texels with the average colour so mips don't
    # darken the rim.
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, name))
    print("wrote", name)


def radial(shape):
    h, w = shape
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    return np.hypot((x + 0.5) / w * 2 - 1, (y + 0.5) / h * 2 - 1)


def oil_stain():
    """Dark engine-oil drips: overlapping soft blobs, darker where they pool, a faint
    dried rim; the ORM makes the fresh oil glossy."""
    rng = np.random.default_rng(11)
    s = (256, 256)
    r = radial(s)
    warp = fbm(s, (4, 4), 4, rng)
    shape = 1.0 - smoothstep(0.35, 0.95, r + (warp - 0.5) * 0.7)
    pools = np.zeros(s, np.float32)
    h, w = s
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    for _ in range(9):
        cx, cy = rng.normal(0.5, 0.14, 2) * np.array([w, h])
        rad = rng.uniform(0.04, 0.13) * w
        d = np.hypot(x - cx, y - cy) / rad
        pools = np.maximum(pools, 1.0 - smoothstep(0.5, 1.2, d + (fbm(s, (8, 8), 2, rng) - 0.5) * 0.6))
    detail = fbm(s, (24, 24), 3, rng)
    alpha = np.clip(shape * (0.35 + 0.35 * detail) + pools * 0.45, 0, 0.92)
    rim = smoothstep(0.02, 0.1, shape) * (1.0 - smoothstep(0.1, 0.3, shape))
    alpha = np.clip(alpha + rim * 0.12, 0, 0.92)
    col = np.stack([np.full(s, 0.055), np.full(s, 0.048), np.full(s, 0.04)], -1)
    col *= (0.8 + 0.4 * detail)[..., None]
    save("decal_oil.png", col, alpha)
    # ORM: AO 1, roughness low where the oil pools, metal 0.
    rough = 0.55 - 0.35 * np.clip(pools, 0, 1)
    orm = np.stack([np.ones(s), rough, np.zeros(s)], -1)
    save("decal_oil_orm.png", orm, np.clip(alpha * 1.2, 0, 1))


def asphalt_patch():
    """A cut-and-filled patch of newer asphalt: dark binder with lighter stones, laid
    partly see-through so the road's own aggregate shows, blotchy where it has
    weathered, a ragged saw-cut outline and a thin glossy bead of tar sealant along it.
    The ORM makes the seam glossier than the patch."""
    rng = np.random.default_rng(23)
    s = (256, 512)
    h, w = s
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    dx = np.abs((x + 0.5) / w * 2 - 1)
    dy = np.abs((y + 0.5) / h * 2 - 1)
    # Rounded-rectangle distance, a slow wobble and fine chipping of the cut edge.
    wob = (fbm(s, (3, 6), 3, rng) - 0.5) * 0.08 + (fbm(s, (26, 52), 2, rng) - 0.5) * 0.045
    d = (dx ** 8 + dy ** 8) ** 0.125 + wob
    inside = 1.0 - smoothstep(0.855, 0.875, d)
    seam = smoothstep(0.845, 0.865, d) * (1.0 - smoothstep(0.878, 0.905, d))
    stones = smoothstep(0.55, 0.75, fbm(s, (100, 200), 2, rng))
    blotch = fbm(s, (4, 8), 3, rng)
    tone = 0.85 + 0.3 * blotch
    col = np.stack([np.full(s, 0.085), np.full(s, 0.082), np.full(s, 0.078)], -1) * tone[..., None]
    col = col * (1.0 - stones[..., None]) + np.array([0.19, 0.185, 0.175]) * stones[..., None]
    col = col * (1.0 - seam[..., None]) + np.array([0.028, 0.027, 0.025]) * seam[..., None]
    alpha = inside * (0.4 + 0.2 * blotch) * (1.0 - stones * 0.35)
    alpha = np.clip(np.maximum(alpha, seam * 0.9), 0, 0.92)
    save("decal_patch.png", col, alpha)
    rough = 0.82 - 0.08 * blotch - 0.45 * seam
    orm = np.stack([np.ones(s), rough, np.zeros(s)], -1)
    save("decal_patch_orm.png", orm, alpha)


def cracks():
    """Branching cracks sealed with tar (dark, glossy bands), as on an old country road."""
    rng = np.random.default_rng(37)
    size = 1024
    line = Image.new("L", (size, size), 0)
    halo = Image.new("L", (size, size), 0)
    dl = ImageDraw.Draw(line)
    dh = ImageDraw.Draw(halo)

    def walk(x, y, ang, n, width, depth):
        pts = [(x, y)]
        for _ in range(n):
            ang += rng.normal(0, 0.16)
            step = rng.uniform(12, 26)
            x += np.cos(ang) * step
            y += np.sin(ang) * step
            pts.append((x, y))
            if depth < 2 and rng.random() < 0.05:
                walk(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.6, 1.3), int(n * 0.4), max(2, width - 2), depth + 1)
        dl.line(pts, fill=255, width=int(width), joint="curve")
        dh.line(pts, fill=255, width=int(width * 4), joint="curve")

    # One long crack along the road, one across it and a few short ones.
    walk(size * 0.04, size * rng.uniform(0.4, 0.6), rng.uniform(-0.15, 0.15), 48, 7, 0)
    walk(size * rng.uniform(0.4, 0.6), size * 0.04, np.pi * 0.5 + rng.uniform(-0.2, 0.2), 44, 6, 0)
    for k in range(3):
        walk(rng.uniform(0.2, 0.8) * size, rng.uniform(0.2, 0.8) * size, rng.uniform(0, np.pi * 2), 12, 4, 1)
    line = line.filter(ImageFilter.GaussianBlur(1.2))
    halo = halo.filter(ImageFilter.GaussianBlur(7))
    fade = 1.0 - smoothstep(0.75, 1.0, radial((size, size)))
    a_line = np.asarray(line, np.float32) / 255.0
    a_halo = np.asarray(halo, np.float32) / 255.0
    alpha = np.clip(a_line * 0.9 + a_halo * 0.28, 0, 0.92) * fade
    img = Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8)).resize((512, 512), Image.LANCZOS)
    alpha = np.asarray(img, np.float32) / 255.0
    s = alpha.shape
    col = np.stack([np.full(s, 0.03), np.full(s, 0.03), np.full(s, 0.028)], -1)
    save("decal_cracks.png", col, alpha)


def dirt_edge():
    """Grit, sand and leaf litter washed against the kerb: dense along the top edge of
    the texture (v = 0), thinning out into the road."""
    rng = np.random.default_rng(41)
    s = (128, 512)
    h, w = s
    y = (np.mgrid[0:h, 0:w][0].astype(np.float32) + 0.5) / h
    edge = 1.0 - smoothstep(0.0, 0.55, y + (fbm(s, (3, 14), 4, rng) - 0.5) * 0.45)
    speck = fbm(s, (24, 95), 2, rng)
    clumps = fbm(s, (6, 26), 3, rng)
    alpha = np.clip(edge * (0.55 + 0.5 * clumps) * (0.7 + 0.5 * speck), 0, 0.85)
    # Fade out at both ends so strips overlap seamlessly.
    xw = (np.mgrid[0:h, 0:w][1].astype(np.float32) + 0.5) / w
    alpha *= smoothstep(0.0, 0.12, xw) * smoothstep(0.0, 0.12, 1.0 - xw)
    tone = 0.75 + 0.5 * fbm(s, (10, 40), 3, rng)
    col = np.stack([0.33 * tone, 0.29 * tone, 0.22 * tone], -1)
    # A few dark leaf and twig flecks.
    leaves = smoothstep(0.72, 0.8, fbm(s, (30, 120), 2, rng)) * edge
    col = col * (1.0 - leaves[..., None] * 0.6)
    save("decal_dirt.png", col, alpha)


def zebra():
    """A worn zebra crossing: six painted bars, half a metre wide with half-metre gaps,
    across the road (u = along the road, v = across it). The paint wears through in
    fine grain, most in the two wheel tracks of each lane, streaked along the traffic."""
    rng = np.random.default_rng(53)
    s = (512, 256)  # v across the 7 m road, u 3.5 m along it
    h, w = s
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = (yy + 0.5) / h * 7.0  # metres across
    u = (xx + 0.5) / w * 3.5  # metres along
    # Bars from 0.75 m to 6.25 m across (clear of the gutters), a slightly ragged edge.
    edge = (fbm(s, (60, 30), 2, rng) - 0.5) * 0.03
    phase = (v - 0.75 + edge) % 1.0
    bars = ((phase < 0.5) & (v > 0.72) & (v < 6.28) & (u > 0.25) & (u < 3.25)).astype(np.float32)
    img = Image.fromarray((bars * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
    bars = np.asarray(img, np.float32) / 255.0
    # Wheel tracks at +-0.9 m round each lane centre (1.75 m and 5.25 m across).
    wheel = np.zeros(s, np.float32)
    for c in (0.85, 2.65, 4.35, 6.15):
        wheel = np.maximum(wheel, np.exp(-((v - c) / 0.3) ** 2))
    # Fine grain, stretched along the traffic (u).
    grain = fbm(s, (140, 18), 3, rng) * 0.65 + fbm(s, (260, 40), 2, rng) * 0.35
    keep = smoothstep(0.3, 0.42, grain + 0.2 - wheel * 0.3)
    chips = smoothstep(0.66, 0.72, fbm(s, (160, 80), 2, rng))
    alpha = bars * keep * (1.0 - chips * 0.7) * 0.82
    tone = 0.72 + 0.1 * fbm(s, (30, 15), 2, rng)
    col = np.stack([tone, tone * 0.99, tone * 0.95], -1)
    save("decal_zebra.png", col, alpha)


def streaks():
    """Rain run-off streaks down a wall from a sill or a parapet (top edge = v 0)."""
    rng = np.random.default_rng(67)
    s = (512, 256)
    h, w = s
    yy = (np.mgrid[0:h, 0:w][0].astype(np.float32) + 0.5) / h
    xx = (np.mgrid[0:h, 0:w][1].astype(np.float32) + 0.5) / w
    cols = fbm((h, w), (2, 26), 3, rng)
    length = 0.35 + 0.6 * value_noise((h, w), (2, 12), rng)
    run = smoothstep(0.45, 0.75, cols) * (1.0 - smoothstep(0.0, 1.0, yy / length))
    top = (1.0 - smoothstep(0.0, 0.08, yy)) * 0.5
    sides = smoothstep(0.0, 0.15, xx) * smoothstep(0.0, 0.15, 1.0 - xx)
    alpha = np.clip((run * 0.55 + top * 0.6) * sides, 0, 0.7)
    tone = 0.8 + 0.3 * fbm(s, (20, 10), 2, rng)
    col = np.stack([0.16 * tone, 0.15 * tone, 0.13 * tone], -1)
    save("decal_streaks.png", col, alpha)


def tyre_marks():
    """Two faint dark rubber tracks (a car that braked or turned in), u along them."""
    rng = np.random.default_rng(79)
    s = (128, 512)
    h, w = s
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = (yy + 0.5) / h
    u = (xx + 0.5) / w
    bend = 0.08 * np.sin(u * 2.4)
    tracks = np.zeros(s, np.float32)
    for c in (0.3, 0.7):
        tracks += np.exp(-((v - c - bend) / 0.05) ** 2)
    tread = 0.6 + 0.4 * fbm(s, (6, 45), 2, rng)
    fade = smoothstep(0.0, 0.2, u) * smoothstep(0.0, 0.35, 1.0 - u)
    alpha = np.clip(tracks * tread * fade * 0.45, 0, 0.5)
    col = np.stack([np.full(s, 0.04), np.full(s, 0.04), np.full(s, 0.04)], -1)
    save("decal_tyre.png", col, alpha)


def ground_mud():
    """Trampled mud and straw for the livestock pen (tiles well enough when rotated)."""
    rng = np.random.default_rng(83)
    s = (512, 512)
    r = radial(s)
    shape = 1.0 - smoothstep(0.55, 1.0, r + (fbm(s, (5, 5), 4, rng) - 0.5) * 0.5)
    wet = smoothstep(0.55, 0.75, fbm(s, (6, 6), 4, rng))
    tone = 0.75 + 0.5 * fbm(s, (30, 30), 3, rng)
    col = np.stack([0.24 * tone, 0.19 * tone, 0.13 * tone], -1)
    col = col * (1.0 - wet[..., None] * 0.35)
    straw = smoothstep(0.74, 0.8, fbm(s, (90, 30), 2, rng)) * 0.6
    col = col * (1 - straw[..., None]) + np.array([0.5, 0.42, 0.26]) * straw[..., None]
    alpha = np.clip(shape * (0.75 + 0.25 * tone), 0, 0.95)
    save("decal_mud.png", col, alpha)


def road_line():
    """A worn painted line (parking bays, stop lines): u along the line."""
    rng = np.random.default_rng(97)
    s = (32, 512)
    h, w = s
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = (yy + 0.5) / h
    u = (xx + 0.5) / w
    band = smoothstep(0.06, 0.14, v) * smoothstep(0.06, 0.14, 1.0 - v)
    keep = smoothstep(0.28, 0.55, fbm(s, (4, 60), 4, rng) + 0.3)
    chips = smoothstep(0.64, 0.72, fbm(s, (5, 80), 2, rng))
    ends = smoothstep(0.0, 0.02, u) * smoothstep(0.0, 0.02, 1.0 - u)
    alpha = band * keep * (1.0 - chips * 0.85) * ends * 0.9
    tone = 0.74 + 0.1 * fbm(s, (6, 90), 2, rng)
    col = np.stack([tone, tone * 0.99, tone * 0.95], -1)
    save("decal_line.png", col, alpha)


# --- Print atlas ------------------------------------------------------------------

FONTS = os.path.join(OUT, "..", "..", "fonts")
ATLAS = 1024
# name -> (x, y, w, h) in pixels.
REGIONS = {
    "flag_tr": (0, 0, 384, 256),
    "banner": (384, 0, 640, 160),
    "plate_ataturk": (384, 160, 320, 96),
    "plate_carsi": (704, 160, 320, 96),
    "feather_blue": (0, 256, 128, 512),
    "feather_red": (128, 256, 128, 512),
    "sign_crossing": (256, 256, 128, 128),
    "sign_50": (384, 256, 128, 128),
    "sign_parking": (512, 256, 128, 128),
    "sign_bus": (640, 256, 128, 128),
    "open": (768, 256, 256, 128),
    "poster_sale": (256, 384, 256, 384),
    "poster_fresh": (512, 384, 256, 384),
    "poster_bread": (768, 384, 256, 256),
    "poster_oil": (768, 640, 256, 384),
    "poster_ice": (0, 768, 256, 256),
    "hours": (256, 768, 256, 128),
    "lpg": (256, 896, 256, 128),
    "timetable": (512, 768, 256, 256),
}


def font(size, condensed=True, weight="Bold"):
    name = ("BarlowCondensed-%s.ttf" if condensed else "Barlow-%s.ttf") % weight
    from PIL import ImageFont
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def text_c(d, box, text, size, fill, condensed=True, dy=0, weight="Bold"):
    """Text centred in box (x, y, w, h), shrunk until it fits the width."""
    x, y, w, h = box
    while True:
        f = font(size, condensed, weight)
        l, t, r, b = d.textbbox((0, 0), text, font=f)
        if r - l <= w * 0.92 or size <= 8:
            break
        size -= 2
    d.text((x + (w - (r - l)) / 2 - l, y + (h - (b - t)) / 2 - t + dy), text, font=f, fill=fill)


def star(cx, cy, r_out, r_in, rot):
    pts = []
    for k in range(10):
        a = rot + k * np.pi / 5
        r = r_out if k % 2 == 0 else r_in
        pts.append((cx + np.cos(a) * r, cy + np.sin(a) * r))
    return pts


def print_atlas():
    img = Image.new("RGBA", (ATLAS, ATLAS), (128, 128, 128, 255))
    d = ImageDraw.Draw(img)
    R = REGIONS
    # The Turkish flag (proportions of the flag law, G = height).
    x, y, w, h = R["flag_tr"]
    red = (200, 16, 46)
    d.rectangle((x, y, x + w, y + h), fill=red)
    g = h
    cx, cy = x + 0.5 * g, y + 0.5 * g
    d.ellipse((cx - 0.25 * g, cy - 0.25 * g, cx + 0.25 * g, cy + 0.25 * g), fill=(255, 255, 255))
    ix = cx + 0.0625 * g
    d.ellipse((ix - 0.2 * g, cy - 0.2 * g, ix + 0.2 * g, cy + 0.2 * g), fill=red)
    sx = ix + 0.2 * g + 0.083 * g + 0.125 * g
    d.polygon(star(sx, cy, 0.125 * g, 0.125 * g * 0.382, np.pi), fill=(255, 255, 255))
    # The dealer's banner.
    x, y, w, h = R["banner"]
    d.rectangle((x, y, x + w, y + h), fill=(196, 28, 30))
    d.rectangle((x + 8, y + 8, x + w - 8, y + h - 8), outline=(250, 220, 60), width=5)
    text_c(d, (x, y + 10, w, 96), "KAMPANYA", 104, (255, 255, 255))
    text_c(d, (x, y + 104, w, 44), "TAKAS · KREDİ · SIFIR FAİZ", 40, (250, 220, 60))
    # Street name plates: dark blue, white rim and lettering.
    for key, name in (("plate_ataturk", "ATATÜRK CD."), ("plate_carsi", "ÇARŞI SK.")):
        x, y, w, h = R[key]
        d.rectangle((x, y, x + w, y + h), fill=(22, 52, 120))
        d.rectangle((x + 6, y + 6, x + w - 6, y + h - 6), outline=(240, 240, 240), width=4)
        text_c(d, (x, y, w, h), name, 60, (245, 245, 245))
    # Feather flags (the text runs up the pole).
    for key, bg, fg, text in (("feather_blue", (20, 70, 160), (255, 255, 255), "2. EL OTO"),
                              ("feather_red", (205, 30, 30), (255, 230, 80), "KAMPANYA")):
        x, y, w, h = R[key]
        band = Image.new("RGBA", (h, w), bg + (255,))
        bd = ImageDraw.Draw(band)
        bd.rectangle((0, w - 22, h, w), fill=(255, 255, 255, 255))
        text_c(bd, (20, 0, h - 60, w - 22), text, 86, fg)
        img.paste(band.rotate(90, expand=True), (x, y))
    # Road signs.
    x, y, w, h = R["sign_crossing"]
    d.rectangle((x, y, x + w, y + h), fill=(255, 255, 255))
    d.rectangle((x + 5, y + 5, x + w - 5, y + h - 5), fill=(20, 80, 170))
    d.polygon([(x + 64, y + 16), (x + 114, y + 108), (x + 14, y + 108)], fill=(255, 255, 255))
    # A walking figure and the crossing's bars.
    d.ellipse((x + 58, y + 38, x + 70, y + 50), fill=(20, 20, 20))
    d.line([(x + 64, y + 50), (x + 60, y + 76)], fill=(20, 20, 20), width=7)
    d.line([(x + 60, y + 76), (x + 50, y + 96)], fill=(20, 20, 20), width=6)
    d.line([(x + 60, y + 76), (x + 72, y + 94)], fill=(20, 20, 20), width=6)
    d.line([(x + 63, y + 56), (x + 52, y + 70)], fill=(20, 20, 20), width=5)
    d.line([(x + 63, y + 56), (x + 75, y + 66)], fill=(20, 20, 20), width=5)
    for k in range(4):
        d.rectangle((x + 30 + k * 18, y + 100, x + 40 + k * 18, y + 104), fill=(20, 20, 20))
    x, y, w, h = R["sign_50"]
    d.rectangle((x, y, x + w, y + h), fill=(128, 128, 128, 0))
    d.ellipse((x + 2, y + 2, x + w - 2, y + h - 2), fill=(210, 20, 30))
    d.ellipse((x + 16, y + 16, x + w - 16, y + h - 16), fill=(250, 250, 250))
    text_c(d, (x, y, w, h), "50", 70, (20, 20, 20), dy=2)
    x, y, w, h = R["sign_parking"]
    d.rectangle((x, y, x + w, y + h), fill=(255, 255, 255))
    d.rectangle((x + 5, y + 5, x + w - 5, y + h - 5), fill=(20, 80, 170))
    text_c(d, (x, y, w, h), "P", 104, (255, 255, 255), condensed=False, dy=2)
    x, y, w, h = R["sign_bus"]
    d.rectangle((x, y, x + w, y + h), fill=(255, 255, 255))
    d.rectangle((x + 5, y + 5, x + w - 5, y + h - 5), fill=(20, 80, 170))
    d.rounded_rectangle((x + 26, y + 22, x + 102, y + 78), 8, fill=(255, 255, 255))
    d.rectangle((x + 32, y + 30, x + 96, y + 52), fill=(20, 80, 170))
    d.ellipse((x + 34, y + 70, x + 48, y + 84), fill=(20, 20, 20))
    d.ellipse((x + 80, y + 70, x + 94, y + 84), fill=(20, 20, 20))
    text_c(d, (x, y + 86, w, 36), "DURAK", 34, (255, 255, 255))
    # The "open" sign in the shop door.
    x, y, w, h = R["open"]
    d.rounded_rectangle((x + 4, y + 4, x + w - 4, y + h - 4), 18, fill=(250, 248, 240), outline=(200, 20, 30), width=8)
    text_c(d, (x, y, w, h), "AÇIK", 96, (200, 20, 30), dy=4)
    # Shop posters.
    x, y, w, h = R["poster_sale"]
    d.rectangle((x, y, x + w, y + h), fill=(250, 214, 40))
    d.rectangle((x, y, x + w, y + 110), fill=(210, 24, 30))
    text_c(d, (x, y + 8, w, 96), "İNDİRİM", 92, (255, 255, 255))
    text_c(d, (x, y + 120, w, 170), "%30", 170, (210, 24, 30))
    text_c(d, (x, y + 290, w, 44), "TÜM SEBZELERDE", 40, (40, 30, 20))
    text_c(d, (x, y + 334, w, 36), "BU HAFTA", 32, (40, 30, 20), weight="SemiBold")
    x, y, w, h = R["poster_fresh"]
    d.rectangle((x, y, x + w, y + h), fill=(34, 110, 56))
    rng = np.random.default_rng(5)
    for k in range(14):
        c = [(215, 40, 30), (240, 140, 30), (250, 210, 50), (120, 180, 60), (150, 40, 90)][k % 5]
        px, py = x + rng.uniform(20, w - 20), y + rng.uniform(210, h - 30)
        r = rng.uniform(14, 26)
        d.ellipse((px - r, py - r, px + r, py + r), fill=c)
    text_c(d, (x, y + 20, w, 80), "TAZE", 88, (255, 255, 255))
    text_c(d, (x, y + 100, w, 60), "MEYVE SEBZE", 60, (250, 230, 120))
    text_c(d, (x, y + 160, w, 40), "HER SABAH", 34, (230, 245, 230), weight="SemiBold")
    x, y, w, h = R["poster_bread"]
    d.rectangle((x, y, x + w, y + h), fill=(244, 236, 214))
    d.rectangle((x + 8, y + 8, x + w - 8, y + h - 8), outline=(150, 90, 40), width=4)
    text_c(d, (x, y + 30, w, 90), "SICAK", 90, (170, 70, 20))
    text_c(d, (x, y + 118, w, 90), "EKMEK", 90, (170, 70, 20))
    text_c(d, (x, y + 204, w, 40), "VAR", 40, (60, 40, 20))
    x, y, w, h = R["poster_oil"]
    d.rectangle((x, y, x + w, y + h), fill=(24, 30, 40))
    d.rectangle((x, y + h - 120, x + w, y + h), fill=(230, 180, 30))
    d.rounded_rectangle((x + 78, y + 120, x + 178, y + 250), 10, fill=(230, 180, 30))
    d.rectangle((x + 108, y + 100, x + 148, y + 122), fill=(230, 180, 30))
    text_c(d, (x, y + 20, w, 80), "MOTOR YAĞI", 70, (255, 255, 255))
    text_c(d, (x, y + h - 110, w, 50), "YAĞ DEĞİŞİMİ", 50, (24, 30, 40))
    text_c(d, (x, y + h - 60, w, 44), "BURADA", 40, (24, 30, 40), weight="SemiBold")
    x, y, w, h = R["poster_ice"]
    d.rectangle((x, y, x + w, y + h), fill=(70, 160, 220))
    d.polygon([(x + 98, y + 150), (x + 158, y + 150), (x + 128, y + 240)], fill=(210, 160, 90))
    d.ellipse((x + 92, y + 96, x + 164, y + 164), fill=(250, 200, 210))
    d.ellipse((x + 100, y + 62, x + 156, y + 118), fill=(120, 70, 40))
    text_c(d, (x, y + 8, w, 60), "DONDURMA", 58, (255, 255, 255))
    x, y, w, h = R["hours"]
    d.rectangle((x, y, x + w, y + h), fill=(245, 245, 240))
    text_c(d, (x, y + 10, w, 50), "AÇILIŞ 08:00", 44, (30, 30, 30))
    text_c(d, (x, y + 64, w, 50), "KAPANIŞ 21:00", 44, (30, 30, 30))
    x, y, w, h = R["lpg"]
    d.rectangle((x, y, x + w, y + h), fill=(210, 30, 30))
    text_c(d, (x, y + 4, w, 80), "TÜP", 84, (255, 255, 255))
    text_c(d, (x, y + 84, w, 36), "EVE SERVİS", 32, (255, 235, 150))
    x, y, w, h = R["timetable"]
    d.rectangle((x, y, x + w, y + h), fill=(250, 250, 246))
    d.rectangle((x, y, x + w, y + 48), fill=(20, 80, 170))
    text_c(d, (x, y, w, 48), "YEŞİLOVA - MERKEZ", 36, (255, 255, 255))
    f = font(26, weight="SemiBold")
    times = ["07:15", "08:30", "10:00", "12:30", "14:00", "16:30", "18:00", "19:45"]
    for k, t in enumerate(times):
        d.text((x + 24 + (k % 2) * 120, y + 64 + (k // 2) * 40), t, font=f, fill=(30, 30, 30))
    img.save(os.path.join(OUT, "town_print_albedo.png"))
    print("wrote town_print_albedo.png")
    print("const PRINT := {")
    for k, (x, y, w, h) in REGIONS.items():
        print('\t"%s": Rect2(%g, %g, %g, %g),' % (k, x / ATLAS, y / ATLAS, w / ATLAS, h / ATLAS))
    print("}")


if __name__ == "__main__":
    oil_stain()
    asphalt_patch()
    cracks()
    dirt_edge()
    zebra()
    streaks()
    tyre_marks()
    ground_mud()
    road_line()
    print_atlas()
