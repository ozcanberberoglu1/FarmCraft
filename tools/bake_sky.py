#!/usr/bin/env python3
"""Bakes the textures of the sky (shaders/sky.gdshader) into art/sky/.

Run from the project root:  python3 tools/bake_sky.py   (numpy + Pillow, ~1 minute)
then `godot --headless --import`.

Atmosphere (a Hillaire 2020 style model: Rayleigh, Mie and ozone over a spherical Earth):
  transmittance.exr   256x64  transmittance to the top of the atmosphere, per (height,
                              view zenith cosine), Hillaire's parametrisation.
  multiscatter.exr    32x32   multiple-scattering transfer (Psi_ms) per (sun zenith
                              cosine, height).
  sky_irradiance.exr  128x1   rgb: sky irradiance on level ground per sun height for a
                              sun of irradiance 1; a: log of the exposure that brings the
                              physical sky to the brightness the game was tuned for
                              (the old hand-tuned sky's irradiance, see old_sky()).
Clouds:
  cloud_shape.png     128^3 tileable volume, 16x8 slices: r Perlin-Worley, gba Worley fbm
                      at rising frequencies (the base shape of the cumulus).
  cloud_detail.png    32^3 tileable volume, 8x4 slices: rgb Worley fbm (edge erosion).
  cloud_weather.png   1024^2 tileable: r where cumulus gather, g how tall they grow,
                      b cirrus streaks, a fine texture of stratiform decks. Each channel is
                      histogram-equalised, so a threshold of 1 - c covers a share c.
  blue_noise.png      64^2 blue noise: where each pixel's cloud ray starts.
Moon:
  moon.png            512^2 near side of the Moon in orthographic view, baked from the
                      NASA LRO colour map (downloaded to art/sky/src/, see CREDITS.md).
"""
import os
import struct
import urllib.request

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "art", "sky")
SRC = os.path.join(OUT, "src")
MOON_URL = "https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_poles_1k.jpg"

# --- Atmosphere (km). Must match shaders/include/sky_atmosphere.gdshaderinc. ---------
RG = 6360.0
RT = 6460.0
RAY_S = np.array([5.802, 13.558, 33.1], np.float64) * 1e-3
RAY_H = 8.0
# A little more haze than Hillaire's clear-sky default: a rural summer sky.
MIE_S = 3.996e-3 * 1.4
MIE_A = 0.444e-3 * 1.4
MIE_H = 1.2
OZO_A = np.array([0.650, 1.881, 0.085], np.float64) * 1e-3
OZO_C = 25.0
OZO_W = 15.0
GROUND_ALBEDO = 0.3
MIE_G = 0.8
# Observer height above the ground sphere (the farm's hills).
OBS_H = 0.3

T_W, T_H = 256, 64
MS_N = 32
IRR_N = 128
IRR_MIN = -0.3


# --- EXR writer (uncompressed, 32-bit float, RGBA) -------------------------------------
def write_exr(path, rgba):
    """Writes an (h, w, 4) float array as an uncompressed scanline OpenEXR file."""
    h, w, _ = rgba.shape
    rgba = rgba.astype(np.float32)

    def attr(name, typ, data):
        return name.encode() + b"\0" + typ.encode() + b"\0" + struct.pack("<i", len(data)) + data

    chans = b""
    for c in "ABGR":  # channel list sorted by name
        chans += c.encode() + b"\0" + struct.pack("<iB3xii", 2, 0, 1, 1)
    chans += b"\0"
    box = struct.pack("<iiii", 0, 0, w - 1, h - 1)
    header = b"\x76\x2f\x31\x01" + struct.pack("<i", 2)
    header += attr("channels", "chlist", chans)
    header += attr("compression", "compression", b"\0")
    header += attr("dataWindow", "box2i", box)
    header += attr("displayWindow", "box2i", box)
    header += attr("lineOrder", "lineOrder", b"\0")
    header += attr("pixelAspectRatio", "float", struct.pack("<f", 1.0))
    header += attr("screenWindowCenter", "v2f", struct.pack("<ff", 0.0, 0.0))
    header += attr("screenWindowWidth", "float", struct.pack("<f", 1.0))
    header += b"\0"
    line_bytes = w * 4 * 4
    table_start = len(header)
    first = table_start + 8 * h
    offsets = b"".join(struct.pack("<Q", first + y * (8 + line_bytes)) for y in range(h))
    body = bytearray()
    for y in range(h):
        body += struct.pack("<ii", y, line_bytes)
        for ch in (3, 2, 1, 0):  # A, B, G, R
            body += rgba[y, :, ch].tobytes()
    with open(path, "wb") as fh:
        fh.write(header + offsets + bytes(body))


# --- Atmosphere --------------------------------------------------------------------------
def media(h):
    """Scattering (rayleigh rgb, mie) and extinction rgb at heights h (any shape)."""
    h = np.maximum(h, 0.0)[..., None]
    dr = np.exp(-h / RAY_H)
    dm = np.exp(-h / MIE_H)
    do = np.maximum(0.0, 1.0 - np.abs(h - OZO_C) / OZO_W)
    ray = dr * RAY_S
    mie = dm * MIE_S
    ext = ray + dm * (MIE_S + MIE_A) + do * OZO_A
    return ray, mie, ext


def dist_top(r, mu):
    disc = r * r * (mu * mu - 1.0) + RT * RT
    return np.maximum(0.0, -r * mu + np.sqrt(np.maximum(disc, 0.0)))


def hits_ground(r, mu):
    return (mu < 0.0) & (r * r * (mu * mu - 1.0) + RG * RG >= 0.0)


def dist_ground(r, mu):
    disc = r * r * (mu * mu - 1.0) + RG * RG
    return np.maximum(0.0, -r * mu - np.sqrt(np.maximum(disc, 0.0)))


def trans_uv(r, mu):
    H = np.sqrt(RT * RT - RG * RG)
    rho = np.sqrt(np.maximum(0.0, r * r - RG * RG))
    d = dist_top(r, mu)
    d_min = RT - r
    d_max = rho + H
    x_mu = (d - d_min) / np.maximum(d_max - d_min, 1e-9)
    x_r = rho / H
    return np.clip(x_mu, 0.0, 1.0), np.clip(x_r, 0.0, 1.0)


def bake_transmittance():
    H = np.sqrt(RT * RT - RG * RG)
    x_mu = np.arange(T_W) / (T_W - 1.0)
    x_r = np.arange(T_H) / (T_H - 1.0)
    XM, XR = np.meshgrid(x_mu, x_r)
    rho = H * XR
    r = np.sqrt(rho * rho + RG * RG)
    d_min = RT - r
    d_max = rho + H
    d = d_min + XM * (d_max - d_min)
    mu = np.where(d == 0.0, 1.0, (H * H - rho * rho - d * d) / np.maximum(2.0 * r * d, 1e-9))
    mu = np.clip(mu, -1.0, 1.0)
    steps = 96
    tau = np.zeros(r.shape + (3,))
    for i in range(steps):
        t = (i + 0.5) / steps * d
        hr = np.sqrt(r * r + t * t + 2.0 * r * t * mu) - RG
        _, _, ext = media(hr)
        tau += ext * (d / steps)[..., None]
    return np.exp(-tau)


class Lut2D:
    """Bilinear lookups in a baked LUT with unit-range texel centres."""

    def __init__(self, data):
        self.data = data
        self.h, self.w = data.shape[:2]

    def sample(self, u, v):
        x = np.clip(u, 0.0, 1.0) * (self.w - 1)
        y = np.clip(v, 0.0, 1.0) * (self.h - 1)
        x0 = np.floor(x).astype(int)
        y0 = np.floor(y).astype(int)
        x1 = np.minimum(x0 + 1, self.w - 1)
        y1 = np.minimum(y0 + 1, self.h - 1)
        fx = (x - x0)[..., None]
        fy = (y - y0)[..., None]
        d = self.data
        return (d[y0, x0] * (1 - fx) + d[y0, x1] * fx) * (1 - fy) + (d[y1, x0] * (1 - fx) + d[y1, x1] * fx) * fy


def sun_trans(tlut, r, mu_s):
    u, v = trans_uv(r, mu_s)
    t = tlut.sample(u, v)
    return np.where(hits_ground(r, mu_s)[..., None], 0.0, t)


def sphere_dirs(n):
    """n*n*2 stratified directions over the whole sphere (uniform)."""
    a = (np.arange(2 * n) + 0.5) / (2 * n) * 2.0 * np.pi
    b = (np.arange(n) + 0.5) / n
    A, B = np.meshgrid(a, b)
    ct = 1.0 - 2.0 * B
    st = np.sqrt(1.0 - ct * ct)
    return np.stack([st * np.cos(A), ct, st * np.sin(A)], -1).reshape(-1, 3)


def bake_multiscatter(tlut):
    dirs = sphere_dirs(12)  # 288 directions
    steps = 40
    out = np.zeros((MS_N, MS_N, 3))
    for j in range(MS_N):
        r = RG + (RT - RG) * j / (MS_N - 1.0)
        r = min(max(r, RG + 0.01), RT - 0.01)
        for i in range(MS_N):
            mu_s = -1.0 + 2.0 * i / (MS_N - 1.0)
            sun = np.array([np.sqrt(max(0.0, 1.0 - mu_s * mu_s)), mu_s, 0.0])
            mu = dirs[:, 1]
            ground = hits_ground(r, mu)
            tmax = np.where(ground, dist_ground(r, mu), dist_top(r, mu))
            L = np.zeros((len(dirs), 3))
            f = np.zeros((len(dirs), 3))
            thr = np.ones((len(dirs), 3))
            dt = tmax / steps
            for k in range(steps):
                t = (k + 0.5) * dt
                p = np.array([0.0, r, 0.0]) + dirs * t[:, None]
                pr = np.linalg.norm(p, axis=1)
                mus = (p @ sun) / pr
                ray, mie, ext = media(pr - RG)
                scat = ray + mie
                ts = sun_trans(tlut, pr, mus)
                st = np.exp(-ext * dt[:, None])
                integ = (1.0 - st) / np.maximum(ext, 1e-12)
                L += thr * scat * ts / (4.0 * np.pi) * integ
                f += thr * scat * integ
                thr *= st
            # Light the ground reflects back into the air (Lambertian).
            pg = np.array([0.0, r, 0.0]) + dirs * tmax[:, None]
            pgr = np.linalg.norm(pg, axis=1)
            mug = (pg @ sun) / pgr
            tg = sun_trans(tlut, pgr, mug)
            L += np.where(ground[:, None], thr * tg * np.clip(mug, 0.0, 1.0)[:, None] * GROUND_ALBEDO / np.pi, 0.0)
            l2 = L.mean(axis=0)
            fms = f.mean(axis=0)
            out[j, i] = l2 / (1.0 - fms)
    return out


def phase_rayleigh(c):
    return 3.0 / (16.0 * np.pi) * (1.0 + c * c)


def phase_mie(c, g=MIE_G):
    # Cornette-Shanks
    k = 3.0 / (8.0 * np.pi) * (1.0 - g * g) / (2.0 + g * g)
    return k * (1.0 + c * c) / np.power(1.0 + g * g - 2.0 * g * c, 1.5)


def sky_radiance(tlut, mslut, dirs, sun, steps=48):
    """Radiance of the sky seen from the observer along dirs (n,3) for a sun of irradiance 1."""
    r = RG + OBS_H
    mu = dirs[:, 1]
    ground = hits_ground(r, mu)
    tmax = np.where(ground, dist_ground(r, mu), dist_top(r, mu))
    cos_t = dirs @ sun
    pr_ = phase_rayleigh(cos_t)[:, None]
    pm_ = phase_mie(cos_t)[:, None]
    L = np.zeros((len(dirs), 3))
    thr = np.ones((len(dirs), 3))
    # Samples crowd near the observer, where the air is densest.
    edges = (np.arange(steps + 1) / steps) ** 2
    for k in range(steps):
        t0 = edges[k] * tmax
        t1 = edges[k + 1] * tmax
        dt = t1 - t0
        t = 0.5 * (t0 + t1)
        p = np.array([0.0, r, 0.0]) + dirs * t[:, None]
        prr = np.linalg.norm(p, axis=1)
        mus = (p @ sun) / prr
        ray, mie, ext = media(prr - RG)
        ts = sun_trans(tlut, prr, mus)
        ms = mslut.sample(mus * 0.5 + 0.5, (prr - RG) / (RT - RG))
        S = ts * (ray * pr_ + mie * pm_) + ms * (ray + mie)
        st = np.exp(-ext * dt[:, None])
        L += thr * S * (1.0 - st) / np.maximum(ext, 1e-12)
        thr *= st
    return L


def hemisphere(n_el=24, n_az=48):
    """Directions over the upper hemisphere with their cosine-weighted solid angles."""
    el_edges = np.linspace(0.0, np.pi / 2, n_el + 1)
    el = 0.5 * (el_edges[:-1] + el_edges[1:])
    az = (np.arange(n_az) + 0.5) / n_az * 2.0 * np.pi
    E, A = np.meshgrid(el, az, indexing="ij")
    d = np.stack([np.cos(E) * np.cos(A), np.sin(E), np.cos(E) * np.sin(A)], -1).reshape(-1, 3)
    dw = (np.sin(el_edges[1:]) - np.sin(el_edges[:-1]))[:, None] * (2.0 * np.pi / n_az)
    w = (np.sin(E) * np.broadcast_to(dw, E.shape)).reshape(-1)  # cos(zenith) * solid angle
    return d, w


# --- The sky the game was tuned against (shaders/sky.gdshader before the physical sky) ---
def srgb_to_linear(c):
    c = np.asarray(c, np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def game_sunlight(sin_h):
    """DayNightCycle.sunlight(): colour of the sunlight (brightest channel 1)."""
    ext = np.array([0.03, 0.05, 0.1])
    h = max(np.degrees(np.arcsin(np.clip(sin_h, -1.0, 1.0))), 0.0)
    mass = 1.0 / (np.sin(np.radians(h)) + 0.50572 * (h + 6.07995) ** -1.6364)
    t = np.exp(-mass * ext)
    return t / t.max()


def old_sky(dirs, sd):
    zenith_day = srgb_to_linear([0.17, 0.37, 0.77])
    horizon_day = srgb_to_linear([0.66, 0.78, 0.92])
    sunset_glow = srgb_to_linear([1.0, 0.5, 0.2])
    sunset_zenith = srgb_to_linear([0.22, 0.38, 0.6])
    golden_horizon = srgb_to_linear([0.98, 0.9, 0.64])
    belt_of_venus = srgb_to_linear([0.8, 0.62, 0.64])
    earth_shadow = srgb_to_linear([0.3, 0.36, 0.52])
    sun_h = sd[1]
    sun_color = game_sunlight(sun_h)
    twilight = smoothstep(-0.22, -0.02, sun_h) * (1.0 - smoothstep(0.0, 0.12, sun_h))
    sundown = smoothstep(0.03, -0.02, sun_h)
    dusk = sundown * (1.0 - smoothstep(-0.1, -0.18, sun_h))
    h = np.maximum(dirs[:, 1], 0.0)[:, None]
    cos_sun = (dirs @ sd)[:, None]
    fd = dirs[:, [0, 2]] + 1e-5
    fd /= np.linalg.norm(fd, axis=1, keepdims=True)
    fs = sd[[0, 2]] + 1e-5
    fs /= np.linalg.norm(fs)
    toward = (fd @ fs)[:, None] * 0.5 + 0.5

    def mix(a, b, t):
        return a + (b - a) * t

    zen = mix(zenith_day, sunset_zenith, twilight * 0.75)
    away = (1.0 - toward) ** 2 * dusk
    hor = mix(horizon_day, earth_shadow, away * (1.0 - smoothstep(0.0, 0.1, h)) * 0.8)
    zen = mix(zen, belt_of_venus, away * smoothstep(0.03, 0.12, h) * (1.0 - smoothstep(0.12, 0.35, h)) * 0.55)
    col = mix(hor, zen, 1.0 - np.exp(-h * mix(3.4, 5.0, twilight)))
    side = toward ** 3
    golden = (1.0 - smoothstep(0.03, 0.35, sun_h)) * smoothstep(-0.1, 0.02, sun_h)
    glow_w = twilight * mix(0.25, 1.0, side)
    col = mix(col, golden_horizon, np.maximum(golden * side * 0.6, glow_w * 0.7) * np.exp(-h * 3.5))
    glow = sunset_glow * mix(0.6, 1.3, toward ** 4)
    col = mix(col, glow, glow_w * np.exp(-h * 10.0))
    col = mix(col, np.array([0.92, 0.62, 0.48]), twilight * sundown * toward ** 2 * np.exp(-h * 7.0) * 0.45)
    cs = np.maximum(cos_sun, 0.0)
    g = 0.78
    hg = (1.0 - g * g) / np.power(1.0 + g * g - 2.0 * g * cos_sun, 1.5)
    mie = sun_color * hg * 0.012 + mix(sun_color, np.array([1.0, 0.95, 0.82]), 0.5) * cs ** 12 * 0.07
    mie = mie * (1.0 + twilight * 0.6 + (1.0 - h) * 0.3)
    col = col + mie * smoothstep(-0.1, 0.02, sun_h)
    bright = mix(0.3, 1.0, smoothstep(0.0, 0.6, sun_h)) if sun_h >= 0.0 else 0.3 * np.exp(sun_h * 14.0)
    return col * bright


def lum(c):
    return c[..., 0] * 0.2126 + c[..., 1] * 0.7152 + c[..., 2] * 0.0722


def bake_irradiance(tlut, mslut):
    dirs, w = hemisphere()
    out = np.zeros((1, IRR_N, 4))
    for i in range(IRR_N):
        mu_s = IRR_MIN + (1.0 - IRR_MIN) * i / (IRR_N - 1.0)
        # The game's sun culminates in the south-east: any azimuth will do here.
        sun = np.array([np.sqrt(max(0.0, 1.0 - mu_s * mu_s)), mu_s, 0.0])
        L = sky_radiance(tlut, mslut, dirs, sun)
        E = (L * w[:, None]).sum(axis=0)
        E_old = (old_sky(dirs, sun) * w[:, None]).sum(axis=0)
        scale = lum(E_old) / max(lum(E), 1e-12)
        out[0, i, :3] = E
        # Stored as a logarithm: it spans six orders of magnitude through twilight.
        out[0, i, 3] = np.log(scale)
        if i % 16 == 0 or i == IRR_N - 1:
            zen = sky_radiance(tlut, mslut, np.array([[0.0, 1.0, 0.0]]), sun)[0]
            print(f"  sun {np.degrees(np.arcsin(mu_s)):6.1f} deg  E_sky {E.round(4)}  E_old {E_old.round(3)}"
                  f"  scale {scale:9.2f}  zenith*scale {(zen * scale).round(3)}")
    return out


# --- Tileable noise ----------------------------------------------------------------------
def worley3(n, cells, rng):
    """1 - distance to the nearest feature point (in cells), tileable, over an n^3 grid."""
    pts = rng.random((cells, cells, cells, 3)).astype(np.float32)
    c = ((np.arange(n) + 0.5) / n * cells).astype(np.float32)
    ci = np.floor(c).astype(np.int64)
    X, Y, Z = c[:, None, None], c[None, :, None], c[None, None, :]
    IX, IY, IZ = ci[:, None, None], ci[None, :, None], ci[None, None, :]
    best = np.full((n, n, n), 1e9, np.float32)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                fp = pts[(IX + dx) % cells, (IY + dy) % cells, (IZ + dz) % cells]
                d2 = (IX + dx + fp[..., 0] - X) ** 2 + (IY + dy + fp[..., 1] - Y) ** 2 + (IZ + dz + fp[..., 2] - Z) ** 2
                np.minimum(best, d2, out=best)
    return 1.0 - np.clip(np.sqrt(best), 0.0, 1.0)


def perlin3(n, period, rng):
    """Tileable 3D gradient noise in about [-1, 1]."""
    g = rng.normal(size=(period, period, period, 3)).astype(np.float32)
    g /= np.linalg.norm(g, axis=-1, keepdims=True)
    c = ((np.arange(n) + 0.5) / n * period).astype(np.float32)
    i0 = np.floor(c).astype(np.int64)
    f = c - i0
    u = f * f * f * (f * (f * 6 - 15) + 10)
    fx, fy, fz = f[:, None, None], f[None, :, None], f[None, None, :]
    ix, iy, iz = i0[:, None, None], i0[None, :, None], i0[None, None, :]
    ux, uy, uz = u[:, None, None], u[None, :, None], u[None, None, :]

    def corner(a, b, cc):
        gg = g[(ix + a) % period, (iy + b) % period, (iz + cc) % period]
        return gg[..., 0] * (fx - a) + gg[..., 1] * (fy - b) + gg[..., 2] * (fz - cc)

    x00 = corner(0, 0, 0) + ux * (corner(1, 0, 0) - corner(0, 0, 0))
    x10 = corner(0, 1, 0) + ux * (corner(1, 1, 0) - corner(0, 1, 0))
    x01 = corner(0, 0, 1) + ux * (corner(1, 0, 1) - corner(0, 0, 1))
    x11 = corner(0, 1, 1) + ux * (corner(1, 1, 1) - corner(0, 1, 1))
    y0 = x00 + uy * (x10 - x00)
    y1 = x01 + uy * (x11 - x01)
    return (y0 + uz * (y1 - y0)) * 1.15


def perlin2(n, px, py, rng, warp=None):
    """Tileable 2D gradient noise over n x n with px, py lattice cells (about [-1, 1])."""
    ang = rng.random((px, py)) * 2.0 * np.pi
    g = np.stack([np.cos(ang), np.sin(ang)], -1)
    cx = (np.arange(n) + 0.5) / n
    X, Y = np.meshgrid(cx * px, cx * py, indexing="ij")
    if warp is not None:
        X = X + warp[0] * px
        Y = Y + warp[1] * py
    ix = np.floor(X).astype(np.int64)
    iy = np.floor(Y).astype(np.int64)
    fx = X - ix
    fy = Y - iy
    ux = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
    uy = fy * fy * fy * (fy * (fy * 6 - 15) + 10)

    def corner(a, b):
        gg = g[(ix + a) % px, (iy + b) % py]
        return gg[..., 0] * (fx - a) + gg[..., 1] * (fy - b)

    x0 = corner(0, 0) + ux * (corner(1, 0) - corner(0, 0))
    x1 = corner(0, 1) + ux * (corner(1, 1) - corner(0, 1))
    return (x0 + uy * (x1 - x0)) * 1.4


def worley2(n, cells, rng):
    pts = rng.random((cells, cells, 2))
    c = (np.arange(n) + 0.5) / n * cells
    X, Y = np.meshgrid(c, c, indexing="ij")
    IX = np.floor(X).astype(np.int64)
    IY = np.floor(Y).astype(np.int64)
    best = np.full((n, n), 1e9)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            fp = pts[(IX + dx) % cells, (IY + dy) % cells]
            d2 = (IX + dx + fp[..., 0] - X) ** 2 + (IY + dy + fp[..., 1] - Y) ** 2
            best = np.minimum(best, d2)
    return 1.0 - np.clip(np.sqrt(best), 0.0, 1.0)


def fbm2(n, p, rng, octaves=5, stretch=1, warp=None):
    v = np.zeros((n, n))
    a = 0.5
    tot = 0.0
    for o in range(octaves):
        v += a * perlin2(n, p * 2 ** o, p * 2 ** o * stretch, rng, warp)
        tot += a
        a *= 0.5
    return v / tot


def blur_wrap(x, sigma):
    """Gaussian blur of a square tileable image (wraps around), sigma in pixels."""
    f = np.fft.fftfreq(x.shape[0])
    g = np.exp(-2.0 * (np.pi * sigma) ** 2 * (f[:, None] ** 2 + f[None, :] ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(x) * g))


def equalise(x):
    """Histogram equalisation to a uniform [0, 1] distribution."""
    flat = x.reshape(-1)
    ranks = np.empty(flat.size)
    ranks[np.argsort(flat, kind="stable")] = np.arange(flat.size)
    return (ranks / (flat.size - 1)).reshape(x.shape)


def stretch01(x, lo=0.5, hi=99.5):
    a, b = np.percentile(x, [lo, hi])
    return np.clip((x - a) / (b - a), 0.0, 1.0)


def to_u8(x):
    return np.clip(np.round(x * 255.0), 0, 255).astype(np.uint8)


def slices_png(vol, cols, rows, path):
    """Saves an (n, n, n, c) volume as a grid of z slices (Godot's Texture3D import)."""
    n = vol.shape[0]
    img = np.zeros((rows * n, cols * n, vol.shape[3]), np.uint8)
    for z in range(n):
        r, c = divmod(z, cols)
        # Rows of a slice run along y, columns along x.
        img[r * n:(r + 1) * n, c * n:(c + 1) * n] = to_u8(vol[:, :, z].transpose(1, 0, 2))
    Image.fromarray(img).save(path, optimize=True)


def bake_shape(rng):
    n = 128
    print("  shape: perlin")
    perlin = (perlin3(n, 4, rng) * 0.5 + perlin3(n, 8, rng) * 0.3 + perlin3(n, 16, rng) * 0.2)
    perlin = stretch01(perlin * 0.5 + 0.5)
    print("  shape: worley")
    w4 = worley3(n, 4, rng)
    w8 = worley3(n, 8, rng)
    w16 = worley3(n, 16, rng)
    w32 = worley3(n, 32, rng)
    w64 = worley3(n, 64, rng)
    wfbm = w8 * 0.625 + w16 * 0.25 + w32 * 0.125
    # Perlin-Worley (Schneider, GPU Pro 7): billowy Worley cells carved into the Perlin.
    pw = stretch01(wfbm + perlin * (1.0 - wfbm))
    g = stretch01(w4 * 0.625 + w8 * 0.25 + w16 * 0.125)
    b = stretch01(w8 * 0.625 + w16 * 0.25 + w32 * 0.125)
    a = stretch01(w16 * 0.625 + w32 * 0.25 + w64 * 0.125)
    vol = np.stack([pw, g, b, a], -1)
    slices_png(vol, 16, 8, os.path.join(OUT, "cloud_shape.png"))


def bake_detail(rng):
    n = 32
    w2 = worley3(n, 2, rng)
    w4 = worley3(n, 4, rng)
    w8 = worley3(n, 8, rng)
    w16 = worley3(n, 16, rng)
    r = stretch01(w2 * 0.625 + w4 * 0.25 + w8 * 0.125)
    g = stretch01(w4 * 0.625 + w8 * 0.25 + w16 * 0.125)
    b = stretch01(w8 * 0.75 + w16 * 0.25)
    vol = np.stack([r, g, b, np.ones_like(r)], -1)
    slices_png(vol, 8, 4, os.path.join(OUT, "cloud_detail.png"))


def bake_weather(rng):
    n = 1024
    # Where cumulus gather: smooth, so the 3D noise shapes each cloud (a sharp map
    # would cut straight walls through them), with broader clearer and cloudier stretches.
    r = equalise(fbm2(n, 4, rng, 5) * 0.7 + fbm2(n, 2, rng, 3) * 0.5)
    # Height of the tops: some towers among flatter cumulus.
    g = equalise(fbm2(n, 5, rng, 4))
    # Cirrus: fibres combed out by the wind and bent into hooks by a strong warp, in
    # patches.
    warp = (fbm2(n, 3, rng, 4) * 0.12, fbm2(n, 3, rng, 4) * 0.12)
    streak = fbm2(n, 4, rng, 6, stretch=4, warp=warp)
    patches = fbm2(n, 2, rng, 3)
    b = equalise(streak * 0.6 + patches * 0.6)
    # Fine texture for stratiform decks (rolls and cells of stratocumulus).
    a = equalise(blur_wrap(fbm2(n, 16, rng, 4) * 0.7 + worley2(n, 64, rng) * 0.3, 2.0))
    img = np.stack([r, g, b, a], -1)
    Image.fromarray(to_u8(img).transpose(1, 0, 2)).save(os.path.join(OUT, "cloud_weather.png"), optimize=True)


def bake_blue_noise(rng, n=64):
    """Blue noise (white noise with its low frequencies filtered out, re-equalised a few
    times): the per-pixel start of the cloud rays, so their banding turns into a fine,
    even grain instead of a pattern."""
    x = rng.random((n, n))
    for _ in range(8):
        x = equalise(x - blur_wrap(x, 1.2))
    Image.fromarray(to_u8(x)).save(os.path.join(OUT, "blue_noise.png"), optimize=True)


def bake_moon():
    os.makedirs(SRC, exist_ok=True)
    src = os.path.join(SRC, "lroc_color_poles_1k.jpg")
    if not os.path.exists(src):
        print("  downloading", MOON_URL)
        req = urllib.request.Request(MOON_URL, headers={"User-Agent": "FarmCraft-sky-baker/1.0"})
        with urllib.request.urlopen(req) as resp, open(src, "wb") as fh:
            fh.write(resp.read())
    eq = np.asarray(Image.open(src).convert("RGB"), np.float64) / 255.0
    H, W, _ = eq.shape
    n = 512
    c = (np.arange(n) + 0.5) / n * 2.0 - 1.0
    X, Y = np.meshgrid(c, -c)  # y up
    rr = np.sqrt(X * X + Y * Y)
    # Outside the disc: the limb's colour carried outwards, so filtering adds no dark rim.
    k = np.minimum(1.0, 0.999 / np.maximum(rr, 1e-9))
    Xc, Yc = X * k, Y * k
    Z = np.sqrt(np.maximum(0.0, 1.0 - Xc * Xc - Yc * Yc))
    lon = np.arctan2(Xc, Z)
    lat = np.arcsin(np.clip(Yc, -1.0, 1.0))
    u = (0.5 + lon / (2.0 * np.pi)) * W - 0.5
    v = (0.5 - lat / np.pi) * H - 0.5
    x0 = np.floor(u).astype(int)
    y0 = np.clip(np.floor(v).astype(int), 0, H - 1)
    fx = (u - x0)[..., None]
    fy = (v - np.floor(v))[..., None]
    y1 = np.clip(y0 + 1, 0, H - 1)
    x0w = x0 % W
    x1w = (x0 + 1) % W
    img = (eq[y0, x0w] * (1 - fx) + eq[y0, x1w] * fx) * (1 - fy) + (eq[y1, x0w] * (1 - fx) + eq[y1, x1w] * fx) * fy
    Image.fromarray(to_u8(img)).save(os.path.join(OUT, "moon.png"), optimize=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    print("transmittance")
    t = bake_transmittance()
    tlut = Lut2D(t)
    write_exr(os.path.join(OUT, "transmittance.exr"), np.concatenate([t, np.ones(t.shape[:2] + (1,))], -1))
    print("multiple scattering")
    ms = bake_multiscatter(tlut)
    mslut = Lut2D(ms)
    write_exr(os.path.join(OUT, "multiscatter.exr"), np.concatenate([ms, np.ones(ms.shape[:2] + (1,))], -1))
    print("sky irradiance")
    irr = bake_irradiance(tlut, mslut)
    write_exr(os.path.join(OUT, "sky_irradiance.exr"), irr)
    rng = np.random.default_rng(20260929)
    print("cloud shape")
    bake_shape(rng)
    print("cloud detail")
    bake_detail(rng)
    print("weather map")
    bake_weather(np.random.default_rng(20260930))
    print("blue noise")
    bake_blue_noise(np.random.default_rng(64))
    print("moon")
    bake_moon()
    print("done")


if __name__ == "__main__":
    main()
