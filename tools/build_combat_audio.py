#!/usr/bin/env python3
"""Builds the knife, bow and arrow sounds and the farmer's pain into art/audio/sfx/combat/.

Run from the project root:  python3 tools/build_combat_audio.py [--force]
Needs numpy, scipy and soundfile (pip install numpy scipy soundfile).

Cut from Mixkit recordings (Mixkit Sound Effects Free License: free for commercial use
in games, no attribution needed; see art/audio/CREDITS.md), plus some made here:
  - knife_swing_*.ogg   the knife's stab through the air (1487 Dagger woosh)
  - knife_hit_*.ogg     the knife going in: a dull body blow under a short cut, kept
                        soft (2153 Body punch quick hit, 2184 Knife fast hit,
                        2199 Body cutting impact)
  - bow_draw.ogg        the stave creaking as the string comes back: synthesised
                        (stick-slip clicks through the wood's resonances)
  - bow_letdown.ogg     the string eased back: a shorter, softer creak (synthesised)
  - bow_release_*.ogg   the loose: the string's twang and the stave's thump
                        (synthesised) with the arrow leaving (2771 Arrow shot through air)
  - arrow_wood_*.ogg    an arrow thunking into wood or a wall (2769 Metal arrow hit,
                        2770 Metal arrow fast hit, the ring filtered off)
  - arrow_ground_*.ogg  an arrow driving into the soil (2498 Body impact falling into the
                        sand, 2182 Wood hard hit, muffled)
  - arrow_flesh.ogg     an arrow striking an animal (2153 Body punch quick hit, 2788 Sword
                        cutting flesh, short and low)
  - arrow_break.ogg     an arrow's shaft snapping (2182 Wood hard hit, a synthesised crack)
  - grunt_*.ogg         the farmer hurt (2197 Man in pain, 2173 Fighting man voice of pain)
  - fall.ogg            the farmer collapsing to the ground (2498 Body impact falling into
                        the sand, 757 Falling hit)
  - heartbeat.ogg       one heartbeat as the world goes dark (490 Human single heart beat)
The downloads are cached in $FARMCRAFT_AUDIO_CACHE (default: the system temp folder).
Existing outputs are skipped unless --force is given.
"""
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_camp_audio import SR, fetch, filt, level, ramp, trimmed  # noqa: E402
import build_camp_audio  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "audio", "sfx", "combat")
build_camp_audio.SOURCES.update({
    "dagger_woosh": 1487, "body_punch": 2153, "knife_fast_hit": 2184, "body_cutting": 2199,
    "arrow_shot": 2771, "arrow_hit": 2769, "arrow_fast_hit": 2770, "sand_impact": 2498,
    "wood_hard_hit": 2182, "sword_flesh": 2788, "man_pain": 2197, "fighter_pain": 2173,
    "falling_hit": 757, "heartbeat": 490,
})


def load(key):
    x, sr = sf.read(fetch(key), always_2d=True)
    x = x.mean(axis=1)
    if sr != SR:
        g = np.gcd(sr, SR)
        x = signal.resample_poly(x, SR // g, sr // g)
    return x.astype(np.float64)


def cut_at(x, t0, length):
    a = int(t0 * SR)
    return x[a:a + int(length * SR)].copy()


def pitched(x, factor):
    """Played `factor` times slower (lower and longer), like a slowed tape."""
    return signal.resample(x, int(len(x) * factor))


def mix(parts, length):
    """[(signal, start s, gain dB)] summed into `length` s."""
    out = np.zeros(int(length * SR))
    for x, at, db in parts:
        a = int(at * SR)
        m = min(len(x), len(out) - a)
        if m > 0:
            out[a:a + m] += x[:m] * 10 ** (db / 20)
    return out


def save(name, x, force):
    path = os.path.join(OUT, name + ".ogg")
    if os.path.exists(path) and not force:
        return
    os.makedirs(OUT, exist_ok=True)
    sf.write(path, x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("wrote", path, f"{len(x) / SR:.2f} s")


def resonate(x, freqs, q):
    """`x` through a bank of band-pass resonators (a body's modes)."""
    out = np.zeros_like(x)
    for f, g in freqs:
        b, a = signal.iirpeak(f, q, fs=SR)
        out += signal.lfilter(b, a, x) * g
    return out


def creak(seconds, rate, seed, swell=True):
    """Wood under strain: stick-slip clicks, `rate` (start, end) per second, rung through a
    yew stave's modes, swelling as the strain grows."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    x = np.zeros(n)
    t = 0.0
    while t < seconds:
        u = t / seconds
        r = rate[0] + (rate[1] - rate[0]) * u
        i = int(t * SR)
        x[i] += rng.uniform(0.5, 1.0) * (0.35 + 0.65 * (u if swell else 1.0 - u))
        t += rng.uniform(0.6, 1.4) / r
    body = resonate(x, [(380, 1.0), (720, 0.7), (1240, 0.45), (2300, 0.2)], 14)
    grit = filt(rng.normal(0, 1, n), "bandpass", [250, 1800]) * 0.012
    env = np.linspace(0.4, 1.0, n) if swell else np.linspace(1.0, 0.3, n)
    return ramp((body + grit) * env, 0.02, 0.06)


def twang(seed, f0=98.0):
    """The string let go: a plucked, quickly damped string (Karplus-Strong), the stave's
    thump in the hand and the slap of the string coming home."""
    rng = np.random.default_rng(seed)
    n = int(0.5 * SR)
    period = int(SR / f0)
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    damp = 0.982
    for i in range(n):
        j = i % period
        nxt = buf[(i + 1) % period]
        out[i] = buf[j]
        buf[j] = damp * 0.5 * (buf[j] + nxt)
    out = filt(out, "lowpass", 2600) * np.exp(-np.arange(n) / (0.09 * SR))
    tt = np.arange(n) / SR
    thump = np.sin(2 * np.pi * 150 * tt) * np.exp(-tt / 0.028) * 0.9
    slap = filt(rng.normal(0, 1, n), "bandpass", [900, 5000]) * np.exp(-tt / 0.006) * 0.6
    return ramp(out * 0.8 + thump + slap, 0.0005, 0.08)


def crack(seed):
    """A dry shaft snapping: a sharp broadband crack ringing short through small wood."""
    rng = np.random.default_rng(seed)
    n = int(0.18 * SR)
    tt = np.arange(n) / SR
    noise = rng.normal(0, 1, n) * np.exp(-tt / 0.012)
    return ramp(resonate(noise, [(1800, 1.0), (3100, 0.6), (900, 0.5)], 8) + filt(noise, "highpass", 2500) * 0.3,
            0.0005, 0.03)


def build(force=False):
    swoosh = trimmed(load("dagger_woosh"), 0.01)
    save("knife_swing_0", level(ramp(filt(swoosh, "highpass", 140), 0.003, 0.05), -24.0), force)
    save("knife_swing_1", level(ramp(filt(pitched(swoosh, 1.12), "highpass", 120), 0.003, 0.05), -24.0), force)

    punch = filt(trimmed(load("body_punch"), 0.004, 0.3), "lowpass", 2500)
    knife = filt(trimmed(load("knife_fast_hit"), 0.003, 0.18), "lowpass", 5000)
    cutting = filt(trimmed(cut_at(load("body_cutting"), 0.1, 0.35), 0.003, 0.3), "lowpass", 3500)
    save("knife_hit_0", level(ramp(mix([(punch, 0.0, 0.0), (knife, 0.004, -6.0)], 0.32), 0.001, 0.08), -20.0), force)
    save("knife_hit_1", level(ramp(mix([(pitched(punch, 1.1), 0.0, 0.0), (cutting, 0.0, -7.0)], 0.34), 0.001, 0.08),
            -20.0), force)

    save("bow_draw", level(creak(0.72, (18.0, 46.0), 7), -27.0), force)
    save("bow_letdown", level(creak(0.35, (30.0, 14.0), 11, False), -30.0), force)

    shot = filt(trimmed(load("arrow_shot"), 0.005, 0.6), "highpass", 90)
    for i, f0 in enumerate([98.0, 104.0]):
        save(f"bow_release_{i}", level(ramp(mix([(twang(3 + i, f0), 0.0, 0.0), (shot, 0.01, -5.0)], 0.62), 0.0005, 0.12),
                -19.0), force)

    for i, key in enumerate(["arrow_hit", "arrow_fast_hit"]):
        x = filt(trimmed(load(key), 0.003, 0.4), "lowpass", 3200)
        save(f"arrow_wood_{i}", level(ramp(filt(x, "highpass", 80), 0.001, 0.1), -21.0), force)
    sand = filt(trimmed(load("sand_impact"), 0.003, 0.35), "lowpass", 1400)
    wood = filt(trimmed(load("wood_hard_hit"), 0.003, 0.2), "lowpass", 1100)
    save("arrow_ground_0", level(ramp(sand, 0.001, 0.1), -24.0), force)
    save("arrow_ground_1", level(ramp(mix([(sand, 0.0, -2.0), (wood, 0.0, -6.0)], 0.35), 0.001, 0.1), -24.0), force)
    flesh = filt(trimmed(load("sword_flesh"), 0.003, 0.22), "lowpass", 2800)
    save("arrow_flesh", level(ramp(mix([(punch, 0.0, 0.0), (flesh, 0.0, -9.0)], 0.3), 0.001, 0.08), -21.0), force)
    snap = filt(trimmed(load("wood_hard_hit"), 0.002, 0.2), "highpass", 600)
    save("arrow_break", level(ramp(mix([(crack(5), 0.0, 0.0), (snap, 0.0, -6.0)], 0.22), 0.0005, 0.05), -22.0), force)

    pain = load("man_pain")
    save("grunt_0", level(ramp(filt(trimmed(cut_at(pain, 0.12, 0.5), 0.01), "highpass", 90), 0.005, 0.12), -19.0), force)
    save("grunt_1", level(ramp(filt(trimmed(cut_at(pain, 0.66, 0.42), 0.01), "highpass", 90), 0.005, 0.12), -19.0), force)
    fighter = load("fighter_pain")
    save("grunt_2", level(ramp(filt(trimmed(cut_at(fighter, 0.08, 0.5), 0.01), "highpass", 90), 0.005, 0.12), -19.0),
            force)

    fall = filt(trimmed(load("sand_impact"), 0.004, 0.6), "lowpass", 1800)
    hit = filt(trimmed(load("falling_hit"), 0.004, 0.6), "lowpass", 1500)
    save("fall", level(ramp(mix([(fall, 0.0, 0.0), (hit, 0.05, -5.0)], 0.75), 0.001, 0.2), -20.0), force)
    save("heartbeat", level(ramp(filt(trimmed(load("heartbeat"), 0.005, 0.7), "lowpass", 400), 0.002, 0.15), -18.0), force)


if __name__ == "__main__":
    build("--force" in sys.argv)
