#!/usr/bin/env python3
"""Paints the textures of the food made at the food table (art/textures/food):

  fish_flesh          the cut face of a headed fish: the skin's rim (dark back, silver
                      belly), the pale fat line under it, pink-white flesh in its
                      muscle rings, the dark red strip along the flanks, the backbone
                      and the emptied belly cavity
  fish_flesh_cooked   the same face grilled: opaque white flakes, a browned rim
  meat                raw game meat (tiles): dark red muscle fibres along V, streaks of
                      fat and patches of silverskin
  meat_cooked         the same meat roasted: a golden to dark brown crust with char

Each as <name>_albedo.jpg and <name>_nor.png (OpenGL normal map from a painted height).
The fish faces fill the square as the cross-section's outline does (FoodModels maps the
cut's bounding box onto it). Run from the project root:

    python3 tools/make_food_textures.py

Needs numpy and Pillow. Deterministic (fixed seeds): rerunning gives the same files.
"""
import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "textures", "food")
N = 512


def periodic_noise(rng, n, cutoff, power=2.0):
    """Tileable noise: white noise filtered in the frequency domain (wraps at the edges)."""
    white = rng.standard_normal((n, n))
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx ** 2 + fy ** 2)
    filt = 1.0 / (1.0 + (r / cutoff) ** power)
    x = np.real(np.fft.ifft2(np.fft.fft2(white) * filt))
    x -= x.min()
    return x / max(x.max(), 1e-9)


def aniso_noise(rng, n, cu, cv):
    """Tileable noise stretched along V (fibres running down the texture)."""
    white = rng.standard_normal((n, n))
    f = np.fft.fftfreq(n)
    fu, fv = np.meshgrid(f, f)
    r = np.sqrt((fu / cu) ** 2 + (fv / cv) ** 2)
    x = np.real(np.fft.ifft2(np.fft.fft2(white) / (1.0 + r ** 2)))
    x -= x.min()
    return x / max(x.max(), 1e-9)


def mix(a, b, t):
    t = np.clip(t, 0.0, 1.0)[..., None]
    return a * (1.0 - t) + b * t


def col(c):
    return np.array(c, dtype=np.float64)[None, None, :]


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def normal_map(h, strength, wrap):
    if wrap:
        dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
        dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    else:
        dy, dx = np.gradient(h)
    nx = -dx * strength * N / 64.0
    ny = dy * strength * N / 64.0
    nz = np.ones_like(h)
    ln = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    n = np.stack([nx / ln, ny / ln, nz / ln], -1)
    return (n * 0.5 + 0.5)


def save(name, albedo, nor):
    os.makedirs(OUT, exist_ok=True)
    a = (np.clip(albedo, 0, 1) ** (1 / 2.2) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(a).save(os.path.join(OUT, name + "_albedo.jpg"), quality=92)
    b = (np.clip(nor, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(b).save(os.path.join(OUT, name + "_nor.png"))
    print("wrote", name)


def fish_face(cooked):
    """The cut face: u across the fish (its width), v down (back at the top)."""
    rng = np.random.default_rng(11 if not cooked else 12)
    v, u = np.mgrid[0:N, 0:N] / (N - 1.0)
    p = (u - 0.5) * 2.0
    q = (v - 0.5) * 2.0
    # The outline is a rounded diamond-ish superellipse, like the lofted body's section.
    r = (np.abs(p) ** 2.5 + np.abs(q) ** 2.5) ** (1 / 2.5)
    noise = periodic_noise(rng, N, 0.05)
    fine = periodic_noise(rng, N, 0.3)
    # Linear colours.
    if not cooked:
        flesh = mix(col((0.55, 0.28, 0.25)), col((0.7, 0.4, 0.36)), smooth(0.2, 0.8, noise))
    else:
        flesh = mix(col((0.66, 0.55, 0.42)), col((0.8, 0.72, 0.6)), smooth(0.2, 0.8, noise))
    # Muscle rings (myomeres seen end on): arcs round the backbone above and below.
    cy = -0.08
    d = np.sqrt((p * 1.25) ** 2 + (q - cy) ** 2)
    rings = 0.5 + 0.5 * np.sin(d * 34.0 + fine * 3.0)
    line = smooth(0.82, 0.98, rings)
    flesh = mix(flesh, flesh * (0.82 if not cooked else 0.88), line * 0.6)
    height = 0.35 * fine - 0.25 * line
    if cooked:
        # Flakes: the rings part a little and catch the light.
        height += 0.3 * smooth(0.6, 0.95, rings)
    # The dark red strip along each flank, level with the backbone.
    strip = smooth(0.12, 0.04, np.abs(q - cy)) * smooth(0.45, 0.75, np.abs(p))
    dark = col((0.36, 0.08, 0.07)) if not cooked else col((0.55, 0.42, 0.32))
    flesh = mix(flesh, dark, strip * 0.85)
    # The backbone: a vertebra with its ring, the spines above and below.
    vb = np.sqrt((p / 0.085) ** 2 + ((q - cy) / 0.085) ** 2)
    bone = col((0.86, 0.84, 0.78)) if not cooked else col((0.75, 0.72, 0.66))
    flesh = mix(flesh, bone, smooth(1.05, 0.9, vb))
    flesh = mix(flesh, bone * 0.55, smooth(0.35, 0.2, vb) * 0.8)
    height += 0.5 * smooth(1.05, 0.7, vb)
    spine = smooth(0.018, 0.006, np.abs(p)) * ((q < cy - 0.07) & (q > -0.8))
    flesh = mix(flesh, bone * 0.9, spine * 0.7)
    # The belly cavity, emptied: a dark hollow with a thin lining.
    cav = np.sqrt((p / 0.32) ** 2 + ((q - 0.46) / 0.3) ** 2)
    lining = col((0.25, 0.07, 0.06)) if not cooked else col((0.36, 0.2, 0.1))
    hollow = col((0.1, 0.02, 0.02)) if not cooked else col((0.2, 0.1, 0.05))
    flesh = mix(flesh, lining, smooth(1.05, 0.95, cav))
    flesh = mix(flesh, hollow, smooth(0.85, 0.55, cav))
    height -= 0.9 * smooth(1.0, 0.5, cav)
    # Fat just under the skin, then the skin: dark along the back, silver at the belly.
    fat = smooth(0.88, 0.92, r) * smooth(0.97, 0.93, r)
    flesh = mix(flesh, col((0.8, 0.72, 0.64)) if not cooked else col((0.7, 0.55, 0.36)), fat * 0.7)
    back = col((0.06, 0.07, 0.05)) if not cooked else col((0.2, 0.1, 0.04))
    belly = col((0.7, 0.72, 0.72)) if not cooked else col((0.55, 0.36, 0.18))
    skin = mix(back, belly, smooth(-0.3, 0.6, q))
    flesh = mix(flesh, skin, smooth(0.93, 0.96, r))
    height += 0.25 * smooth(0.93, 0.97, r)
    if cooked:
        # Browned where the fire reached the edge.
        flesh = mix(flesh, col((0.42, 0.22, 0.08)), smooth(0.75, 1.0, r) * 0.55 * (0.6 + 0.4 * noise))
    # Wet sheen variation is in the roughness of the material; a touch of speckle here.
    flesh *= (0.94 + 0.12 * fine)[..., None]
    return flesh, height


def meat(cooked):
    rng = np.random.default_rng(21 if not cooked else 22)
    fibres = aniso_noise(rng, N, 0.2, 0.012)
    grain = aniso_noise(rng, N, 0.05, 0.004)
    blotch = periodic_noise(rng, N, 0.02)
    fine = periodic_noise(rng, N, 0.25)
    marble = aniso_noise(rng, N, 0.03, 0.01)
    if not cooked:
        base = mix(col((0.2, 0.025, 0.025)), col((0.42, 0.07, 0.06)), smooth(0.25, 0.75, blotch))
        base = mix(base, col((0.11, 0.012, 0.012)), smooth(0.45, 0.85, fibres) * 0.7)
        base = mix(base, base * 1.35, smooth(0.6, 0.9, grain) * 0.5)
        # Streaks of fat and patches of pearly silverskin.
        fat = smooth(0.8, 0.9, marble)
        base = mix(base, col((0.8, 0.66, 0.56)), fat * 0.85)
        silver = smooth(0.66, 0.8, blotch) * smooth(0.4, 0.7, fine)
        base = mix(base, col((0.62, 0.55, 0.56)), silver * 0.5)
        height = 0.6 * fibres + 0.3 * grain + 0.2 * fat
    else:
        base = mix(col((0.13, 0.05, 0.015)), col((0.4, 0.19, 0.055)), smooth(0.2, 0.8, blotch))
        base = mix(base, col((0.07, 0.025, 0.01)), smooth(0.45, 0.85, fibres) * 0.6)
        fat = smooth(0.8, 0.9, marble)
        base = mix(base, col((0.6, 0.36, 0.12)), fat * 0.6)
        char = smooth(0.74, 0.88, periodic_noise(rng, N, 0.04)) * smooth(0.3, 0.7, fine)
        base = mix(base, col((0.02, 0.012, 0.008)), char * 0.9)
        height = 0.5 * fibres + 0.35 * grain + 0.4 * blotch - 0.2 * char
    base *= (0.92 + 0.16 * fine)[..., None]
    return base, height


def main():
    for cooked in (False, True):
        a, h = fish_face(cooked)
        save("fish_flesh_cooked" if cooked else "fish_flesh", a, normal_map(h, 2.0, False))
        a, h = meat(cooked)
        save("meat_cooked" if cooked else "meat", a, normal_map(h, 3.0, True))


if __name__ == "__main__":
    main()
