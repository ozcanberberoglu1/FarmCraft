#!/usr/bin/env python3
"""Paints the town's textures procedurally: the decals (oil stains, asphalt patches,
sealed cracks, dirt along the kerbs, the worn zebra crossing and road lines, rain
streaks, tyre marks, pen mud) and the print atlas (the flag, street name plates, road
signs, shop posters, the dealer's banners) used by scripts/world/town.gd.

Run from the project root:  python3 art/textures/town/make_town_textures.py
Needs numpy and Pillow; the lettering uses the game's Barlow fonts (art/fonts).
Output: art/textures/town/decal_*.png (RGBA, straight alpha), town_print_albedo.png and
vet_print_albedo.png (the vet clinic's sign, posters and labels; "... make_town_textures.py
vet" paints only that one).
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


# --- The vet clinic's prints -------------------------------------------------------

# name -> (x, y, w, h) in pixels of vet_print_albedo.png (VetClinic.PRINT).
VET_REGIONS = {
    "sign": (0, 0, 1024, 128),
    "logo": (0, 128, 256, 256),
    "hours": (256, 128, 256, 128),
    "open": (512, 128, 256, 128),
    "closed": (768, 128, 256, 128),
    "door_plate": (256, 256, 256, 64),
    "scale": (256, 320, 128, 64),
    "clock": (384, 320, 64, 64),
    "screen": (512, 256, 256, 128),
    "diploma": (768, 256, 256, 128),
    "poster_rabies": (0, 384, 256, 384),
    "poster_parasite": (256, 384, 256, 384),
    "poster_farm": (512, 384, 256, 384),
    "poster_care": (768, 384, 256, 384),
    "bag_dog": (0, 768, 128, 192),
    "bag_cat": (128, 768, 128, 192),
    "bag_puppy": (256, 768, 128, 192),
    "bag_feed": (384, 768, 128, 192),
    "box_meds": (512, 768, 256, 128),
    "chart": (768, 768, 256, 256),
}
GREEN_DARK = (18, 92, 62)
GREEN = (36, 140, 84)


def paw(d, cx, cy, r, fill):
    """A paw print: the big pad and four toes over it, `r` the pad's half width."""
    d.ellipse((cx - r, cy - r * 0.55, cx + r, cy + r * 0.95), fill=fill)
    for tx, ty, tr in ((-0.95, -0.95, 0.36), (-0.36, -1.45, 0.38), (0.36, -1.45, 0.38), (0.95, -0.95, 0.36)):
        d.ellipse((cx + tx * r - tr * r, cy + ty * r - tr * r * 1.25, cx + tx * r + tr * r, cy + ty * r + tr * r * 1.25), fill=fill)


def vet_logo(d, box, ring=True):
    """The clinic's badge: a white cross on a green disc, a green paw on the cross."""
    x, y, w, h = box
    cx, cy = x + w / 2, y + h / 2
    r = min(w, h) * 0.47
    if ring:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(250, 250, 246))
        r2 = r * 0.9
        d.ellipse((cx - r2, cy - r2, cx + r2, cy + r2), fill=GREEN)
    a = r * 0.56
    b = r * 0.2
    d.rounded_rectangle((cx - b, cy - a, cx + b, cy + a), radius=b * 0.3, fill=(250, 250, 246))
    d.rounded_rectangle((cx - a, cy - b, cx + a, cy + b), radius=b * 0.3, fill=(250, 250, 246))
    paw(d, cx, cy + r * 0.06, r * 0.13, GREEN_DARK)


def dog(d, x, y, s, fill):
    """A standing dog in profile (facing right), `s` pixels a unit, its feet on y."""
    pts = [(0.0, -1.0), (0.15, -1.35), (0.1, -1.05), (0.25, -1.0), (1.35, -1.05), (1.5, -1.4), (1.62, -1.62),
           (1.72, -1.56), (1.78, -1.62), (1.82, -1.5), (2.1, -1.4), (2.12, -1.3), (1.86, -1.22), (1.64, -1.1),
           (1.55, -0.6), (1.6, 0.0), (1.48, 0.0), (1.4, -0.55), (1.2, -0.6), (1.18, 0.0), (1.06, 0.0), (1.0, -0.6),
           (0.5, -0.6), (0.45, 0.0), (0.33, 0.0), (0.3, -0.6), (0.2, -0.65), (0.12, 0.0), (0.0, 0.0), (0.05, -0.7)]
    d.polygon([(x + px * s, y + py * s) for px, py in pts], fill=fill)


def cat(d, x, y, s, fill):
    """A sitting cat seen from the front-side, `s` pixels a unit, sitting on y."""
    d.ellipse((x - 0.55 * s, y - 1.25 * s, x + 0.55 * s, y), fill=fill)
    d.ellipse((x - 0.38 * s, y - 1.75 * s, x + 0.38 * s, y - 1.05 * s), fill=fill)
    for sx in (-1, 1):
        d.polygon([(x + sx * 0.36 * s, y - 1.5 * s), (x + sx * 0.33 * s, y - 1.95 * s), (x + sx * 0.1 * s, y - 1.7 * s)], fill=fill)
    d.line([(x + 0.3 * s, y - 0.12 * s), (x + 0.8 * s, y - 0.1 * s), (x + 1.0 * s, y - 0.3 * s), (x + 1.02 * s, y - 0.62 * s)],
           fill=fill, width=int(0.16 * s), joint="curve")


def cow(d, x, y, s, fill):
    """A cow in profile (facing left), `s` pixels a unit, its feet on y."""
    d.rounded_rectangle((x, y - 1.55 * s, x + 2.2 * s, y - 0.6 * s), radius=0.25 * s, fill=fill)
    d.polygon([(x + 0.05 * s, y - 1.45 * s), (x - 0.55 * s, y - 1.25 * s), (x - 0.62 * s, y - 0.95 * s), (x - 0.4 * s, y - 0.85 * s),
               (x + 0.1 * s, y - 1.0 * s)], fill=fill)
    d.polygon([(x - 0.05 * s, y - 1.55 * s), (x - 0.2 * s, y - 1.78 * s), (x + 0.08 * s, y - 1.5 * s)], fill=fill)
    for lx in (0.12, 0.42, 1.65, 1.95):
        d.rectangle((x + lx * s, y - 0.75 * s, x + (lx + 0.18) * s, y), fill=fill)
    d.line([(x + 2.2 * s, y - 1.45 * s), (x + 2.35 * s, y - 0.75 * s)], fill=fill, width=int(0.07 * s))
    d.ellipse((x + 1.4 * s, y - 0.72 * s, x + 1.75 * s, y - 0.5 * s), fill=fill)


def vet_print():
    """The clinic's sign, its hours plate and door signs, posters, the diploma, the labels
    of the pet food and medicine boxes, the scale's readout, the monitor and the clock."""
    img = Image.new("RGBA", (ATLAS, ATLAS), (128, 128, 128, 255))
    d = ImageDraw.Draw(img)
    R = VET_REGIONS
    white = (248, 248, 244)
    ink = (34, 38, 36)
    # The fascia: a white panel, a green band along the foot, the badge, the name.
    x, y, w, h = R["sign"]
    d.rectangle((x, y, x + w, y + h), fill=white)
    d.rectangle((x, y + h - 22, x + w, y + h), fill=GREEN)
    vet_logo(d, (x + 8, y + 4, 112, 100))
    text_c(d, (x + 124, y + 4, 640, 64), "YEŞİLOVA VETERİNER KLİNİĞİ", 60, GREEN_DARK)
    text_c(d, (x + 124, y + 64, 640, 40), "KÜÇÜK VE BÜYÜKBAŞ HAYVAN SAĞLIĞI", 30, (60, 70, 64), weight="SemiBold")
    d.line((x + 774, y + 14, x + 774, y + h - 34), fill=(200, 205, 200), width=3)
    for k, line in enumerate(("AŞI · MUAYENE", "CERRAHİ · ACİL")):
        text_c(d, (x + 780, y + 10 + k * 46, 240, 44), line, 34, (60, 70, 64), weight="SemiBold")
    text_c(d, (x, y + h - 22, w, 22), "Dr. Selin Aydın  ·  Veteriner Hekim", 18, white, weight="SemiBold")
    # The badge alone (the blade sign over the pavement).
    x, y, w, h = R["logo"]
    d.rectangle((x, y, x + w, y + h), fill=white)
    vet_logo(d, (x, y, w, h))
    # Opening hours on the glass by the door.
    x, y, w, h = R["hours"]
    d.rectangle((x, y, x + w, y + h), fill=white)
    d.rectangle((x + 4, y + 4, x + w - 4, y + h - 4), outline=GREEN, width=4)
    text_c(d, (x, y + 8, w, 34), "ÇALIŞMA SAATLERİ", 30, GREEN_DARK)
    text_c(d, (x, y + 44, w, 44), "HER GÜN 08:00 - 20:00", 36, ink)
    text_c(d, (x, y + 88, w, 30), "PAZAR DAHİL", 24, (90, 96, 92), weight="SemiBold")
    # The hanging sign in the door: open (green) or closed (red).
    for key, bg, text in (("open", GREEN, "AÇIK"), ("closed", (190, 28, 34), "KAPALI")):
        x, y, w, h = R[key]
        d.rectangle((x, y, x + w, y + h), fill=(128, 128, 128, 0))
        d.rounded_rectangle((x + 6, y + 10, x + w - 6, y + h - 6), 16, fill=bg)
        d.rounded_rectangle((x + 14, y + 18, x + w - 14, y + h - 14), 10, outline=white, width=4)
        text_c(d, (x, y + 10, w, h - 16), text, 72, white, dy=2)
    # The treatment room's door plate.
    x, y, w, h = R["door_plate"]
    d.rectangle((x, y, x + w, y + h), fill=(214, 216, 212))
    d.rectangle((x + 3, y + 3, x + w - 3, y + h - 3), outline=(160, 162, 158), width=2)
    text_c(d, (x, y, w, h), "MUAYENE", 44, ink)
    # The floor scale's readout and the wall clock.
    x, y, w, h = R["scale"]
    d.rectangle((x, y, x + w, y + h), fill=(30, 34, 32))
    d.rectangle((x + 8, y + 8, x + w - 8, y + h - 8), fill=(130, 170, 120))
    text_c(d, (x + 8, y + 8, w - 16, h - 16), "0.00 kg", 36, (24, 36, 22))
    x, y, w, h = R["clock"]
    d.rectangle((x, y, x + w, y + h), fill=(128, 128, 128, 0))
    cx, cy, r = x + h / 2, y + h / 2, h / 2 - 2
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(40, 40, 40))
    d.ellipse((cx - r + 4, cy - r + 4, cx + r - 4, cy + r - 4), fill=white)
    for k in range(12):
        a = k * np.pi / 6
        d.line((cx + np.sin(a) * r * 0.72, cy - np.cos(a) * r * 0.72, cx + np.sin(a) * r * 0.86, cy - np.cos(a) * r * 0.86), fill=ink, width=2)
    d.line((cx, cy, cx + r * 0.45, cy - r * 0.2), fill=ink, width=3)
    d.line((cx, cy, cx - r * 0.1, cy - r * 0.7), fill=ink, width=2)
    # A clock face for the monitor's corner is not needed: the monitor shows the day's list.
    x, y, w, h = R["screen"]
    d.rectangle((x, y, x + w, y + h), fill=(232, 238, 242))
    d.rectangle((x, y, x + w, y + 22), fill=(28, 110, 160))
    text_c(d, (x, y, w, 22), "RANDEVULAR", 18, white)
    f = font(16, weight="SemiBold")
    for k, (t, n) in enumerate((("09:30", "Karabaş - aşı"), ("11:00", "Sarıkız - muayene"), ("14:15", "Pamuk - parazit"), ("16:40", "Minnoş - kontrol"))):
        yy = y + 30 + k * 24
        d.rectangle((x + 6, yy, x + w - 6, yy + 20), fill=(250, 252, 252) if k % 2 == 0 else (222, 232, 238))
        d.text((x + 12, yy + 1), t, font=f, fill=(28, 110, 160))
        d.text((x + 70, yy + 1), n, font=f, fill=ink)
    # The diploma in its frame behind the counter.
    x, y, w, h = R["diploma"]
    d.rectangle((x, y, x + w, y + h), fill=(240, 232, 212))
    d.rectangle((x + 6, y + 6, x + w - 6, y + h - 6), outline=(170, 140, 80), width=3)
    text_c(d, (x, y + 12, w, 30), "DİPLOMA", 28, (90, 60, 30))
    text_c(d, (x, y + 44, w, 24), "VETERİNER FAKÜLTESİ", 20, (60, 50, 40), weight="SemiBold")
    text_c(d, (x, y + 70, w, 24), "Selin AYDIN", 22, (40, 40, 60), condensed=False, weight="SemiBold")
    d.ellipse((x + w - 54, y + h - 50, x + w - 18, y + h - 14), fill=(170, 40, 40))
    for k in range(3):
        d.line((x + 30, y + h - 24 + k * 0, x + 110, y + h - 24), fill=(120, 110, 100), width=1)
    # Posters: rabies jabs (dog), parasites (cat), the herd's vaccinations (cow), care tips.
    for key, top, title, animal, lines in (
            ("poster_rabies", (28, 92, 170), "KUDUZ AŞISI", "dog", ("Kedi ve köpeklerinizin", "kuduz aşısını", "her yıl yaptırın")),
            ("poster_parasite", (226, 120, 30), "PARAZİT", "cat", ("İç ve dış parazit", "uygulaması", "3 ayda bir")),
            ("poster_farm", GREEN, "ŞAP · BRUSELLA", "cow", ("Büyükbaş ve küçükbaş", "hayvanlarınızın aşılarını", "aksatmayın")),
            ("poster_care", (120, 70, 140), "SEVGİ VE BAKIM", "paw", ("Düzenli kontrol,", "temiz su ve dengeli mama", "uzun ve sağlıklı ömür"))):
        x, y, w, h = R[key]
        d.rectangle((x, y, x + w, y + h), fill=white)
        d.rectangle((x, y, x + w, y + 80), fill=top)
        text_c(d, (x, y + 6, w, 70), title, 54, white)
        light = tuple(int(c + (255 - c) * 0.82) for c in top)
        d.ellipse((x + 38, y + 96, x + w - 38, y + 96 + w - 76), fill=light)
        ax, ay = x + w / 2, y + 96 + (w - 76) * 0.82
        if animal == "dog":
            dog(d, ax - 1.05 * 62, ay, 62, top)
        elif animal == "cat":
            cat(d, ax - 10, ay, 70, top)
        elif animal == "cow":
            cow(d, ax - 0.8 * 56, ay, 56, top)
        else:
            paw(d, ax, ay - 60, 34, top)
        for k, line in enumerate(lines):
            text_c(d, (x + 6, y + 290 + k * 30, w - 12, 30), line, 26, ink, weight="SemiBold")
    # Fronts of the food bags (fictional brands) and the medicine boxes' labels.
    for key, bg, brand, what, animal in (("bag_dog", (196, 40, 36), "PATİ", "KÖPEK MAMASI", "dog"),
                                         ("bag_cat", (110, 60, 150), "MİNNOŞ", "KEDİ MAMASI", "cat"),
                                         ("bag_puppy", (40, 120, 190), "PATİ", "YAVRU KÖPEK", "dog"),
                                         ("bag_feed", (60, 130, 60), "BEREKET", "BUZAĞI YEMİ", "cow")):
        x, y, w, h = R[key]
        d.rectangle((x, y, x + w, y + h), fill=bg)
        d.rectangle((x, y + 8, x + w, y + 48), fill=white)
        text_c(d, (x, y + 8, w, 40), brand, 36, bg)
        d.ellipse((x + 18, y + 58, x + w - 18, y + 58 + w - 36), fill=tuple(min(255, c + 60) for c in bg))
        if animal == "dog":
            dog(d, x + 22, y + 58 + w - 50, 40, white)
        elif animal == "cat":
            cat(d, x + w / 2 - 6, y + 58 + w - 44, 40, white)
        else:
            cow(d, x + 36, y + 58 + w - 52, 30, white)
        text_c(d, (x, y + h - 36, w, 30), what, 22, white)
    x, y, w, h = R["box_meds"]
    for k, (bg, name) in enumerate((((236, 236, 232), "AMOKSİSİLİN"), ((210, 228, 240), "MELOKSİKAM"), ((240, 226, 200), "İVERMEKTİN"),
                                    ((222, 238, 220), "VİTAMİN AD3E"))):
        bx = x + (k % 2) * 128
        by = y + (k // 2) * 64
        d.rectangle((bx, by, bx + 128, by + 64), fill=bg)
        d.rectangle((bx, by + 44, bx + 128, by + 52), fill=[(200, 40, 40), (30, 100, 170), (200, 130, 20), (40, 140, 70)][k])
        text_c(d, (bx + 4, by + 6, 120, 34), name, 22, ink)
    # A chart on the wall: a dog's and a cat's outline with the vaccination calendar.
    x, y, w, h = R["chart"]
    d.rectangle((x, y, x + w, y + h), fill=(246, 246, 238))
    d.rectangle((x, y, x + w, y + 36), fill=(28, 92, 170))
    text_c(d, (x, y, w, 36), "AŞI TAKVİMİ", 30, white)
    f = font(17, weight="SemiBold")
    for k, (age, jab) in enumerate((("6-8 hafta", "Karma aşı 1"), ("10-12 hafta", "Karma aşı 2"), ("12 hafta", "Kuduz"),
                                    ("14-16 hafta", "Karma aşı 3"), ("Her yıl", "Karma + Kuduz"), ("3 ayda bir", "Parazit"))):
        yy = y + 46 + k * 34
        d.rectangle((x + 8, yy, x + w - 8, yy + 28), fill=(255, 255, 255) if k % 2 == 0 else (226, 234, 244))
        d.text((x + 14, yy + 4), age, font=f, fill=(28, 92, 170))
        d.text((x + 122, yy + 4), jab, font=f, fill=ink)
    img.save(os.path.join(OUT, "vet_print_albedo.png"))
    print("wrote vet_print_albedo.png")
    print("const PRINT := {")
    for k, (x, y, w, h) in VET_REGIONS.items():
        print('\t"%s": Rect2(%g, %g, %g, %g),' % (k, x / ATLAS, y / ATLAS, w / ATLAS, h / ATLAS))
    print("}")


if __name__ == "__main__":
    import sys
    # "vet": only the clinic's prints.
    if "vet" not in sys.argv[1:]:
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
    vet_print()
