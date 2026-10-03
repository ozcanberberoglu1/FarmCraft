#!/usr/bin/env python3
"""Builds the fishing contest crowd's voices (FishingContest) into art/audio/sfx/contest/.

Run from the project root:  python3 tools/build_contest_crowd_audio.py
Needs numpy and soundfile (pip install numpy soundfile).

Made only from recordings already in the game (nothing is downloaded; see
art/audio/CREDITS.md):
  ambience/carnival_crowd.ogg   kyles' CC0 park crowd (Freesound 629887), also the
                                contest's murmur loop as it is
  sfx/contest/applause.ogg      Mixkit "Medium size crowd applause" (485)
Outputs:
  sfx/contest/crowd_call_1..5.ogg   a voice calling out or laughing over the murmur: the
                                    moments where someone near the microphone speaks up
  sfx/contest/cheer_1..2.ogg        the crowd's cheer at a new biggest fish: the applause
                                    breaking out with a few voices raised over it
Each is trimmed, faded, mono and matched in loudness.
"""
import os

import numpy as np
import soundfile as sf

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "audio")
CEILING = 0.89

# Voices speaking up out of the crowd recording (its loudest stretches, seconds).
CALLS = [(28.45, 29.85), (31.45, 32.75), (61.05, 62.45), (71.0, 72.3), (112.1, 113.45)]
# The cheers: [applause start, end], the calls laid over it [(call index, at s, pitch)].
CHEERS = [
    ((0.25, 4.6), [(2, 0.05, 1.12), (1, 0.35, 1.04), (4, 0.7, 1.18)]),
    ((0.35, 4.4), [(4, 0.0, 1.08), (0, 0.3, 1.15), (3, 0.6, 1.02)]),
]


def mono(rel):
    d, sr = sf.read(os.path.join(ROOT, rel), always_2d=True)
    return d.mean(axis=1), sr


def resample(x, sr_from, sr_to, pitch=1.0):
    """`x` at sr_from played back at sr_to, `pitch` times faster (and higher)."""
    n = int(len(x) * sr_to / sr_from / pitch)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


def fade(x, sr, fi, fo):
    x = x.copy()
    n = len(x)
    if fi > 0:
        k = min(n, int(fi * sr))
        x[:k] *= np.linspace(0.0, 1.0, k)
    if fo > 0:
        k = min(n, int(fo * sr))
        x[n - k:] *= np.linspace(1.0, 0.0, k) ** 1.5
    return x


def level(x, rms_db):
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * 10 ** (rms_db / 20.0) / rms
    peak = np.max(np.abs(x))
    return x * (CEILING / peak) if peak > CEILING else x


def high_pass(x, sr, hz):
    """A gentle one-pole high-pass: less of the crowd's low rumble under a voice."""
    a = np.exp(-2.0 * np.pi * hz / sr)
    y = np.zeros_like(x)
    prev_x = 0.0
    prev_y = 0.0
    for i, v in enumerate(x):
        prev_y = a * (prev_y + v - prev_x)
        prev_x = v
        y[i] = prev_y
    return y


def write(rel, x, sr):
    out = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sf.write(out, x.astype(np.float32), sr, format="OGG", subtype="VORBIS")
    print(rel, "%.2fs" % (len(x) / sr))


def main():
    crowd, csr = mono("ambience/carnival_crowd.ogg")
    applause, asr = mono("sfx/contest/applause.ogg")
    calls = []
    for a, b in CALLS:
        x = crowd[int(a * csr):int(b * csr)]
        x = high_pass(x, csr, 180.0)
        x = resample(x, csr, asr)
        calls.append(x)
    for i, x in enumerate(calls):
        write("sfx/contest/crowd_call_%d.ogg" % (i + 1), level(fade(x, asr, 0.12, 0.35), -21.0), asr)
    for i, ((a, b), over) in enumerate(CHEERS):
        x = fade(applause[int(a * asr):int(b * asr)], asr, 0.08, 1.6)
        x = level(x, -19.0)
        for k, at, pitch in over:
            v = level(fade(resample(calls[k], asr, asr, pitch), asr, 0.05, 0.4), -22.0)
            s = int(at * asr)
            e = min(len(x), s + len(v))
            x[s:e] += v[:e - s]
        write("sfx/contest/cheer_%d.ogg" % (i + 1), level(x, -17.0), asr)


if __name__ == "__main__":
    main()
