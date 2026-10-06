#!/usr/bin/env python3
"""Measures how loud every music file is and writes the table the game levels them by.

Run from the project root after adding, swapping or re-encoding any track:

    python3 tools/music_levels.py            (rewrites scripts/audio/music_levels.gd)
    python3 tools/music_levels.py --check    (only prints the table; exit 1 if the file is stale)

Needs numpy, scipy and soundfile (pip install numpy scipy soundfile). Nothing else has
to be edited: the game reads the table by file (MusicLevels.trim, MusicLevels.speaker_trim)
and a file that is not in it plays at the table's median trim until the tool is run again.
An exported game cannot list a folder, which is why this is a const table in a script.

What it measures, for every .mp3/.ogg/.wav under art/audio/music (radio/ and the
carnival tunes included):
  loudness   the whole file's integrated loudness (ITU-R BS.1770-4: K-weighted, 400 ms
             blocks, gated; the same measure tools/fetch_radio_music.py levels by), LUFS.
  speaker    the same after the car radio's dashboard speaker (CarRadio's bus: the
             high-pass and low-pass at SPEAKER_LOW and SPEAKER_HIGH read from
             scripts/vehicles/car_radio.gd, one biquad each as Godot's filters are at
             their default, see STAGES, and the stereo pulled in by pan_pullout): what
             the driver hears in the cab.
  rms        the plain RMS (dBFS), printed for reference only.
The trims are what brings each file to REFERENCE: TRIM as the world's music plays it
(Audio._update_music), SPEAKER_TRIM as the radio does (CarRadio). How far above or below
the reference each kind of music plays is set in the game (Audio.MUSIC_DB,
Audio.CARNIVAL_DB, CarRadio.VOLUME_DB), not here.
"""
import os
import re
import sys

import numpy as np
import soundfile as sf
from scipy import signal

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
AUDIO = os.path.join(ROOT, "art", "audio")
MUSIC = os.path.join(AUDIO, "music")
OUT = os.path.join(ROOT, "scripts", "audio", "music_levels.gd")
RADIO = os.path.join(ROOT, "scripts", "vehicles", "car_radio.gd")
# The loudness every track is brought to (LUFS): calm background music. For this game's
# day and night tracks it comes to about -23 dBFS of plain RMS.
REFERENCE = -20.0
# No file is turned up by more than this (dB): a nearly silent recording stays quiet
# rather than being lifted into its own noise.
MAX_BOOST = 9.0
EXTENSIONS = (".mp3", ".ogg", ".wav")
# Biquads in each of the speaker's two filters: Godot's AudioEffectFilter runs db + 1 of
# them and CarRadio leaves db at its default, FILTER_6DB (0), so one. (Measured with two,
# the radio's trims came out 1 to 2.5 dB too high.) The scenario "radio22" holds the
# game's filters against the number written into the table.
STAGES = 1


def k_loudness(x, sr):
    """Integrated loudness in LUFS (ITU-R BS.1770-4: K-weighting, 400 ms blocks, gated)."""
    def shelf():
        f0, gain, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
        k = np.tan(np.pi * f0 / sr)
        vh, vb = 10 ** (gain / 20.0), (10 ** (gain / 20.0)) ** 0.4996667741545416
        a0 = 1.0 + k / q + k * k
        return [(vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0], \
            [1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0]

    def highpass():
        f0, q = 38.13547087602444, 0.5003270373238773
        k = np.tan(np.pi * f0 / sr)
        a0 = 1.0 + k / q + k * k
        return [1.0, -2.0, 1.0], [1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0]

    y = x.astype(np.float64)
    for b, a in (shelf(), highpass()):
        y = signal.lfilter(b, a, y, axis=0)
    block, hop = int(0.4 * sr), int(0.1 * sr)
    if len(y) < block:
        return -70.0
    power = np.cumsum(np.concatenate([np.zeros((1, y.shape[1])), y ** 2]), axis=0)
    starts = np.arange(0, len(y) - block + 1, hop)
    z = ((power[starts + block] - power[starts]) / block).sum(axis=1)
    lk = -0.691 + 10.0 * np.log10(np.maximum(z, 1e-12))
    z = z[lk > -70.0]
    if len(z) == 0:
        return -70.0
    rel = -0.691 + 10.0 * np.log10(np.mean(z)) - 10.0
    z = z[-0.691 + 10.0 * np.log10(z) > rel]
    return float(-0.691 + 10.0 * np.log10(np.mean(z))) if len(z) else -70.0


def godot_filter(x, sr, cutoff, high):
    """Godot's AudioEffectHighPassFilter / LowPassFilter at their defaults (resonance 0.5,
    db FILTER_6DB: one biquad, see STAGES)."""
    omega = 2.0 * np.pi * min(cutoff, sr / 2.0 - 1.0) / sr
    sin_v, cos_v = np.sin(omega), np.cos(omega)
    alpha = sin_v / (2.0 * 0.5)
    a = [1.0 + alpha, -2.0 * cos_v, 1.0 - alpha]
    b = [(1.0 + cos_v) / 2.0, -(1.0 + cos_v), (1.0 + cos_v) / 2.0] if high \
        else [(1.0 - cos_v) / 2.0, 1.0 - cos_v, (1.0 - cos_v) / 2.0]
    for _ in range(STAGES):
        x = signal.lfilter(b, a, x, axis=0)
    return x


def radio_constants():
    """The dashboard speaker as CarRadio builds it: (low Hz, high Hz, pan pullout)."""
    text = open(RADIO, encoding="utf-8").read() if os.path.exists(RADIO) else ""
    def number(pattern, default):
        m = re.search(pattern, text)
        return float(m.group(1)) if m else default
    return (number(r"const SPEAKER_LOW := ([\d.]+)", 170.0), number(r"const SPEAKER_HIGH := ([\d.]+)", 5600.0),
            number(r"pan_pullout = ([\d.]+)", 0.4))


def through_speaker(x, sr, low, high, pullout):
    y = godot_filter(godot_filter(x.astype(np.float64), sr, low, True), sr, high, False)
    if y.shape[1] == 2:
        centre = y.mean(axis=1, keepdims=True)
        y = centre + (y - centre) * pullout
    return y


def measure():
    """[(path under art/audio, loudness, speaker loudness, plain rms dB)] for every track."""
    low, high, pullout = radio_constants()
    rows = []
    for folder, _dirs, names in sorted(os.walk(MUSIC)):
        for name in sorted(names):
            if not name.lower().endswith(EXTENSIONS):
                continue
            path = os.path.join(folder, name)
            x, sr = sf.read(path, always_2d=True)
            # A mono file is played on both speakers.
            if x.shape[1] == 1:
                x = np.repeat(x, 2, axis=1)
            rms = 10.0 * np.log10(max(float(np.mean(x ** 2)), 1e-12))
            rel = os.path.relpath(path, AUDIO).replace(os.sep, "/")
            rows.append((rel, k_loudness(x, sr), k_loudness(through_speaker(x, sr, low, high, pullout), sr), rms))
    return rows


def trim(level):
    return round(min(REFERENCE - level, MAX_BOOST), 1)


def script(rows):
    low, high, pullout = radio_constants()
    full = [trim(r[1]) for r in rows]
    speaker = [trim(r[2]) for r in rows]
    width = max(len(r[0]) for r in rows) + 3
    out = [
        "class_name MusicLevels",
        "## How loud each music file is, so that the game can play them all at one level.",
        "## GENERATED by tools/music_levels.py: do not edit; after adding or swapping a track run",
        "##     python3 tools/music_levels.py",
        "## from the project root (an exported game cannot list the folder, hence a table).",
        "## The trims (dB) bring a file to REFERENCE (LUFS, ITU-R BS.1770): TRIM as it is, for",
        "## the world's music (Audio._update_music); SPEAKER_TRIM as it sounds through the car",
        "## radio's dashboard speaker (%d-%d Hz, stereo pulled in to %s), for CarRadio. A file" % (low, high, pullout),
        "## that is not in the table gets the median trim (DEFAULT_TRIM, DEFAULT_SPEAKER_TRIM).",
        "",
        "const REFERENCE := %.1f" % REFERENCE,
        "## Biquads in each of the speaker's filters as measured (AudioEffectFilter.db + 1).",
        "const SPEAKER_STAGES := %d" % STAGES,
        "const DEFAULT_TRIM := %.1f" % float(np.median(full)),
        "const DEFAULT_SPEAKER_TRIM := %.1f" % float(np.median(speaker)),
        "## File under res://art/audio/ -> dB. (Measured: loudness LUFS, plain RMS dBFS.)",
        "const TRIM := {",
    ]
    for r, t in zip(rows, full):
        out.append("\t%-*s %5.1f,  # %6.1f LUFS, %6.1f dB RMS" % (width, '"%s":' % r[0], t, r[1], r[3]))
    out += ["}", "## (Measured: loudness through the speaker, LUFS.)", "const SPEAKER_TRIM := {"]
    for r, t in zip(rows, speaker):
        out.append("\t%-*s %5.1f,  # %6.1f LUFS" % (width, '"%s":' % r[0], t, r[2]))
    out += [
        "}",
        "",
        "",
        "## dB that brings `rel` (a file under res://art/audio/) to REFERENCE.",
        "static func trim(rel: String) -> float:",
        "\treturn float(TRIM.get(rel, DEFAULT_TRIM))",
        "",
        "",
        "## The same as heard through the car radio's speaker.",
        "static func speaker_trim(rel: String) -> float:",
        "\treturn float(SPEAKER_TRIM.get(rel, DEFAULT_SPEAKER_TRIM))",
        "",
    ]
    return "\n".join(out)


def main():
    rows = measure()
    if not rows:
        sys.exit("no music under " + MUSIC)
    text = script(rows)
    print("%-48s %8s %8s %8s %6s %8s" % ("file", "LUFS", "speaker", "RMS", "trim", "sp.trim"))
    for r in rows:
        print("%-48s %8.1f %8.1f %8.1f %+6.1f %+8.1f" % (r[0], r[1], r[2], r[3], trim(r[1]), trim(r[2])))
    if "--check" in sys.argv:
        stale = not os.path.exists(OUT) or open(OUT, encoding="utf-8").read() != text
        print("scripts/audio/music_levels.gd is %s" % ("STALE: run tools/music_levels.py" if stale else "up to date"))
        sys.exit(1 if stale else 0)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote %s (%d tracks, reference %.1f LUFS)" % (os.path.relpath(OUT, ROOT), len(rows), REFERENCE))


if __name__ == "__main__":
    main()
