#!/usr/bin/env python3
"""Builds the wolves' sounds (Wolf; a night raid's pack) into art/audio/sfx/animals/.

Run from the project root:  python3 tools/build_wolf_audio.py [--force]
Needs numpy, scipy and soundfile (pip install numpy scipy soundfile).

Cut, cleaned and levelled from these recordings (none needs attribution; see
art/audio/CREDITS.md):
  - wolf_howl_*.ogg      a wolf howling close by: "Wolf howl" by NaturesTemper (Freesound
                         398430, CC0), two howls of "Cooper Creek ... solitary wolf howl very
                         clear" by betchkal (Freesound 500646, CC0), Mixkit 1729 "Lone wolf
                         howling"
  - wolf_howl_far_*.ogg  a pack howling far off in the forest (the raid's warning): "Howling
                         wolves" by Kingcornz (Freesound 378334, CC0), Mixkit 2485 "Wolves at
                         scary forest", Mixkit 1776 "Wolves pack howling" with a howl of
                         betchkal's answering; each taken far away (the highs gone, a long
                         forest echo)
  - wolf_growl_*.ogg     low growls: "dog_growling_mono_4824" by Mystikuum (Freesound
                         401820, CC0), pitched down a little for a bigger animal
  - wolf_snarl_*.ogg     a snarl as one goes in: Mixkit 1773 "Wolf attack", "R01-63-Dog
                         Snarling and Attacking" by craigsmith (Freesound 479633, CC0), "Dog
                         Growling Snarling Grumbling" by qubodup (Freesound 122183, CC0)
  - wolf_bite_*.ogg      the jaws snapping: a click of "Dog Teeth Clattering Clicking" by
                         qubodup (Freesound 841350, CC0) on a short burst of the snarl
  - wolf_yelp_*.ogg      a yelp when hit: "Dog's Yelping 7" by unfa (Freesound 160478, CC0)
  - wolf_death_*.ogg     its last cry: "dog crying" by jocelynlopez (Freesound 635114, CC0),
                         pitched down and fading
Mixkit sounds: Mixkit Sound Effects Free License (free for commercial use in games, no
attribution). Freesound: the 'hq' previews, which download without an account.
The downloads are cached in $FARMCRAFT_AUDIO_CACHE (default: the system temp folder).
Existing outputs are skipped unless --force is given.
"""
import os
import sys
import tempfile
import urllib.request

import numpy as np
import soundfile as sf
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_camp_audio import SR, filt, level, ramp  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "audio", "sfx", "animals")
CACHE = os.environ.get("FARMCRAFT_AUDIO_CACHE", os.path.join(tempfile.gettempdir(), "farmcraft_audio_src"))
HEADERS = {"User-Agent": "FarmCraftAudioFetcher/1.0 (game audio build script)"}
FREESOUND = "https://cdn.freesound.org/previews/"
MIXKIT = "https://assets.mixkit.co/active_storage/sfx/%d/%d-preview.mp3"
SOURCES = {
    "wolf_howl": FREESOUND + "398/398430_3862281-hq.mp3",
    "lone_howl": FREESOUND + "500/500646_339183-hq.mp3",
    "mk_lone": MIXKIT % (1729, 1729),
    "howling_wolves": FREESOUND + "378/378334_4804147-hq.mp3",
    "mk_forest": MIXKIT % (2485, 2485),
    "mk_pack": MIXKIT % (1776, 1776),
    "growls": FREESOUND + "401/401820_1643758-hq.mp3",
    "mk_attack": MIXKIT % (1773, 1773),
    "snarl_attack": FREESOUND + "479/479633_2524442-hq.mp3",
    "snarl_grumble": FREESOUND + "122/122183_71257-hq.mp3",
    "teeth": FREESOUND + "841/841350_71257-hq.mp3",
    "yelps": FREESOUND + "160/160478_1038806-hq.mp3",
    "crying": FREESOUND + "635/635114_13907218-hq.mp3",
}


def fetch(key):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, "wolf_" + key + ".mp3")
    if not os.path.exists(path):
        req = urllib.request.Request(SOURCES[key], headers=HEADERS)
        with urllib.request.urlopen(req, timeout=120) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    return path


def load(key):
    x, sr = sf.read(fetch(key), always_2d=True)
    x = x.mean(axis=1)
    if sr != SR:
        g = np.gcd(sr, SR)
        x = signal.resample_poly(x, SR // g, sr // g)
    return x.astype(np.float64)


def cut(x, t0, t1):
    return x[int(t0 * SR):int(t1 * SR)].copy()


def envelope(x, win=0.02):
    n = max(int(win * SR), 1)
    return np.sqrt(np.convolve(x ** 2, np.ones(n) / n, mode="same"))


def trimmed(x, threshold=0.06, pre=0.012, post=0.08):
    """`x` from just before it first reaches `threshold` of its peak loudness to just
    after it last does."""
    env = envelope(x, 0.01)
    on = np.nonzero(env > env.max() * threshold)[0]
    if len(on) == 0:
        return x
    a = max(int(on[0] - pre * SR), 0)
    b = min(int(on[-1] + post * SR), len(x))
    return x[a:b].copy()


def events(x, threshold_db=-22.0, min_len=0.12, gap=0.08):
    """The separate sounds in `x` (start, end samples): stretches louder than
    `threshold_db` under its peak, at least `min_len` s long, joined across gaps shorter
    than `gap` s; loudest first."""
    env = envelope(x, 0.015)
    loud = env > env.max() * 10 ** (threshold_db / 20)
    out = []
    i = 0
    n = len(x)
    while i < n:
        if not loud[i]:
            i += 1
            continue
        j = i
        quiet = 0
        while j < n and quiet < gap * SR:
            quiet = 0 if loud[j] else quiet + 1
            j += 1
        end = j - quiet
        if end - i > min_len * SR:
            out.append((i, end))
        i = j
    out.sort(key=lambda se: -np.sqrt(np.mean(x[se[0]:se[1]] ** 2)))
    return out


def loud_spots(x, count, length, min_gap):
    """Starts of the `count` loudest `length`-s stretches of `x`, `min_gap` s apart."""
    win = int(length * SR)
    env = np.convolve(x ** 2, np.ones(win) / win, mode="valid")
    order = np.argsort(env)[::-1]
    picked = []
    for i in order:
        if len(picked) >= count:
            break
        if all(abs(i - j) > min_gap * SR for j in picked):
            picked.append(i)
    return sorted(picked)


def pitched(x, factor):
    """Played `factor` times as fast (and as high): < 1 lower and slower, a bigger animal."""
    up, down = 100, int(round(100 * factor))
    return signal.resample_poly(x, up, down)


def far_away(x, seed):
    """Heard from far off in the forest: the highs gone (the air takes them), the lows
    thinned, and a long, soft echo off the trees and the hills."""
    rng = np.random.default_rng(seed)
    dry = filt(filt(x, "lowpass", 1600, 2), "highpass", 180)
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t / 0.55)
    ir = filt(ir, "lowpass", 1300)
    ir[: int(0.03 * SR)] = 0.0
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = signal.fftconvolve(dry, ir)
    out = np.zeros(len(wet))
    out[: len(dry)] += dry * 0.55
    out += wet * 0.75
    return out


def save(name, x, force):
    path = os.path.join(OUT, name + ".ogg")
    if os.path.exists(path) and not force:
        return
    sf.write(path, x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print("wrote", path, f"{len(x) / SR:.2f} s")


def main():
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    # Howls close by: whole howls, the rumble and hiss off.
    lone = load("lone_howl")
    howls = [trimmed(load("wolf_howl"), 0.04)]
    segs = sorted(events(lone, -18.0, 2.0, 0.4)[:4])
    howls += [trimmed(lone[a:b], 0.05) for a, b in (segs[0], segs[2])]
    howls.append(trimmed(load("mk_lone"), 0.03))
    for k, h in enumerate(howls):
        y = filt(filt(h, "highpass", 140), "lowpass", 9000)
        save(f"wolf_howl_{k}", level(ramp(y, 0.05, 0.6), -16.0), force)
    # Far off: a pack's chorus, far away in the forest.
    choruses = [trimmed(load("howling_wolves"), 0.03), trimmed(load("mk_forest"), 0.03)]
    pack = trimmed(load("mk_pack"), 0.03)
    answer = pitched(trimmed(lone[segs[3][0]:segs[3][1]], 0.05), 0.94)
    mix = np.zeros(max(len(pack), int(1.3 * SR) + len(answer)))
    mix[: len(pack)] += pack
    mix[int(1.3 * SR): int(1.3 * SR) + len(answer)] += answer * 0.6
    choruses.append(mix)
    for k, c in enumerate(choruses):
        y = far_away(ramp(c, 0.2, 0.8), 30 + k)
        save(f"wolf_howl_far_{k}", level(ramp(y, 0.3, 1.2), -22.0, crest_db=12.0), force)
    # Growls: each alone, a little lower.
    growl = filt(load("growls"), "highpass", 55)
    takes = sorted(events(growl, -20.0, 0.6, 0.15)[:4])
    for k, (a, b) in enumerate(takes):
        y = pitched(growl[a:b], 0.9)
        y = filt(y, "lowpass", 6500)
        save(f"wolf_growl_{k}", level(ramp(y, 0.04, 0.25), -18.0), force)
    # Snarls: the attack burst, and the loudest second of two snarling recordings.
    snarls = [trimmed(load("mk_attack"), 0.05)]
    for key in ("snarl_attack", "snarl_grumble"):
        x = filt(load(key), "highpass", 90)
        s = loud_spots(x, 1, 1.1, 2.0)[0]
        snarls.append(x[s:s + int(1.1 * SR)])
    for k, y in enumerate(snarls):
        y = filt(filt(pitched(y, 0.93), "highpass", 90), "lowpass", 9500)
        save(f"wolf_snarl_{k}", level(ramp(y, 0.01, 0.15), -16.0, crest_db=12.0), force)
    # Bites: a sharp click of the teeth on a short burst of the snarl, dying fast.
    teeth = filt(load("teeth"), "highpass", 400)
    env = envelope(teeth, 0.004)
    peaks, _ = signal.find_peaks(env, distance=int(0.12 * SR), height=env.max() * 0.4)
    peaks = sorted(peaks, key=lambda p: -env[p])[:3]
    burst = trimmed(load("mk_attack"), 0.05)
    for k, p in enumerate(peaks):
        click = teeth[max(p - int(0.01 * SR), 0): p + int(0.12 * SR)]
        click = click * np.exp(-np.arange(len(click)) / (0.03 * SR))
        body = burst[int((0.15 + 0.2 * k) * SR): int((0.5 + 0.2 * k) * SR)]
        body = body * np.exp(-np.arange(len(body)) / (0.09 * SR))
        y = np.zeros(max(len(click), len(body) + int(0.02 * SR)))
        y[: len(click)] += click * 2.2
        y[int(0.02 * SR): int(0.02 * SR) + len(body)] += body * 0.8
        save(f"wolf_bite_{k}", level(ramp(y, 0.002, 0.05), -13.0, crest_db=14.0), force)
    # Yelps: the three loudest, a little lower.
    yelps = filt(load("yelps"), "highpass", 250)
    for k, (a, b) in enumerate(events(yelps, -12.0, 0.15, 0.05)[:3]):
        y = pitched(yelps[max(a - int(0.01 * SR), 0): b + int(0.06 * SR)], 0.9)
        save(f"wolf_yelp_{k}", level(ramp(y, 0.005, 0.08), -15.0), force)
    # Its last cry: a whimpering cry falling away, lower and slower.
    crying = filt(load("crying"), "highpass", 150)
    for k, (a, b) in enumerate(sorted(events(crying, -14.0, 0.5, 0.1)[:2])):
        y = pitched(crying[a: b + int(0.25 * SR)], 0.84)
        y = y * np.linspace(1.0, 0.35, len(y))
        save(f"wolf_death_{k}", level(ramp(y, 0.01, 0.4), -17.0), force)


if __name__ == "__main__":
    main()
