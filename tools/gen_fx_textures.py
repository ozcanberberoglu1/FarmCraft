#!/usr/bin/env python3
"""Paints the textures of the work effects (scripts/fx): no downloads, fixed seeds.

Run from the project root:  python3 tools/gen_fx_textures.py
Writes art/textures/fx/:
  dust_puff.png   2x2 atlas of soft, billowy dust puffs (white, alpha = density,
                  lit from the upper left) for the dust of axe, pick, hoe and building work
  wet_spot.png    a splash of water soaked into soil (dark, irregular, with a few
                  separate drops around it) for the watering can's decals
  wet_spot_orm.png  its occlusion/roughness/metal: wet ground is glossy
Needs numpy and Pillow.
"""
import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "art", "textures", "fx")


def value_noise(size, cells, rng):
    """Smooth tileable value noise in 0..1 on a size x size grid."""
    g = rng.random((cells, cells))
    x = np.linspace(0, cells, size, endpoint=False)
    i0 = np.floor(x).astype(int)
    f = x - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    a = g[np.ix_(i0, i0)]
    b = g[np.ix_(i0, i1)]
    c = g[np.ix_(i1, i0)]
    d = g[np.ix_(i1, i1)]
    fy = f[:, None]
    fx = f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size, base, octaves, rng):
    v = np.zeros((size, size))
    amp = 0.5
    total = 0.0
    cells = base
    for _ in range(octaves):
        v += amp * value_noise(size, cells, rng)
        total += amp
        amp *= 0.5
        cells *= 2
    return v / total


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def puff(size, rng):
    y, x = np.mgrid[0:size, 0:size] / (size - 1) * 2 - 1
    ang = np.arctan2(y, x)
    # A lumpy outline: the radius wobbles with the angle.
    wob = 1.0 + 0.07 * np.sin(ang * 3 + rng.random() * 6) + 0.05 * np.sin(ang * 5 + rng.random() * 6)
    r = np.sqrt(x * x + y * y) * wob
    n = fbm(size, 4, 5, rng)
    body = smoothstep(1.0, 0.25, r)
    dens = np.clip(body * (0.35 + 0.95 * n) - 0.18, 0, 1)
    dens = smoothstep(0.0, 0.75, dens) * smoothstep(1.0, 0.7, r)
    # Self-shading: lit from the upper left, darker underneath.
    shade = 0.78 + 0.22 * np.clip(0.5 - 0.5 * (x * 0.5 + y * 0.8) + (n - 0.5) * 0.6, 0, 1)
    rgb = np.clip(shade, 0, 1)
    return rgb, dens * 0.9


def dust_atlas():
    rng = np.random.default_rng(7)
    s = 256
    img = np.zeros((s * 2, s * 2, 4))
    for k in range(4):
        rgb, a = puff(s, rng)
        oy, ox = (k // 2) * s, (k % 2) * s
        img[oy:oy + s, ox:ox + s, 0] = rgb
        img[oy:oy + s, ox:ox + s, 1] = rgb
        img[oy:oy + s, ox:ox + s, 2] = rgb
        img[oy:oy + s, ox:ox + s, 3] = a
    Image.fromarray((img * 255).astype(np.uint8)).save(os.path.join(OUT, "dust_puff.png"))


def wet_spot():
    rng = np.random.default_rng(11)
    s = 256
    y, x = np.mgrid[0:s, 0:s] / (s - 1) * 2 - 1
    ang = np.arctan2(y, x)
    wob = 1.0 + 0.08 * np.sin(ang * 3 + 1.3) + 0.06 * np.sin(ang * 5 + 0.4) + 0.04 * np.sin(ang * 11 + 2.0)
    r = np.sqrt(x * x + y * y) * wob
    n = fbm(s, 8, 5, rng)
    edge = 0.62 + (n - 0.5) * 0.35
    a = smoothstep(edge + 0.06, edge - 0.08, r)
    # Separate drops soaked in around the splash.
    for _ in range(26):
        t = rng.random() * np.pi * 2
        d = 0.62 + rng.random() * 0.3
        cx, cy = np.cos(t) * d, np.sin(t) * d
        rad = 0.02 + rng.random() * 0.045
        dd = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
        a = np.maximum(a, smoothstep(rad, rad * 0.4, dd) * 0.9)
    # Soaked unevenly: wetter in the middle, mottled by the soil.
    a *= 0.72 + 0.28 * smoothstep(0.8, 0.0, r) - (n - 0.5) * 0.25
    a = np.clip(a, 0, 1) * smoothstep(1.0, 0.9, np.sqrt(x * x + y * y))
    img = np.zeros((s, s, 4))
    # Nearly black, half covering: darkens soil and grass alike rather than painting mud.
    img[..., 0] = 0.05
    img[..., 1] = 0.042
    img[..., 2] = 0.034
    img[..., 3] = a * 0.62
    Image.fromarray((img * 255).astype(np.uint8)).save(os.path.join(OUT, "wet_spot.png"))
    orm = np.zeros((s, s, 3))
    orm[..., 0] = 1.0
    orm[..., 1] = 0.28 + (n - 0.5) * 0.15
    orm[..., 2] = 0.0
    Image.fromarray((np.clip(orm, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "wet_spot_orm.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    dust_atlas()
    wet_spot()
    print("wrote", OUT)
