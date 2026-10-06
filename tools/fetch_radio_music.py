#!/usr/bin/env python3
"""Downloads the car radio's own music (CarRadio.STATIONS) into art/audio/music/radio/.

Run from the project root:  python3 tools/fetch_radio_music.py   [--force] [--list]
Needs numpy, scipy and soundfile (pip install numpy scipy soundfile).

Five recordings (the owner asked for five to begin with; the game's own tracks fill the
rest of each station's list; see art/audio/CREDITS.md for the full credits):
  Yeşilova FM   two Anatolian folk tunes on saz, oud, violin and drums: Turku, Nomads of the
                Silk Road, "Alleys of Istanbul" (CC BY 4.0; the files on Wikimedia Commons).
  Radyo Yol     two easy country tunes for the road: Kevin MacLeod, incompetech.com (CC BY 4.0).
  Radyo Huzur   quiet piano: Satie's first Gymnopédie from Musopen (public domain; the file
                on Wikimedia Commons).
No account is needed for any of them. Every download is checked against the size (and,
for Wikimedia Commons, the SHA-1) the source published.

Each recording has the silence before and after it cut, is brought to one loudness
(LOUDNESS, ITU-R BS.1770, so that no station is louder than the next) under a limiter,
and is written as Ogg Vorbis (the changes made to the CC BY recordings; CREDITS.md says so). The seconds of each track in scripts/vehicles/car_radio.gd
are then set from the files written (the stations' clock is worked out from them).
Downloads are cached in $FARMCRAFT_AUDIO_CACHE (default: the system temp folder).
Existing outputs are skipped unless --force is given. --list only prints what would be
downloaded. After a run: import the project, then run the scenario "radio20".
"""
import hashlib
import os
import re
import sys
import tempfile
import urllib.parse
import urllib.request

PROJECT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ROOT = os.path.join(PROJECT, "art", "audio")
RADIO_GD = os.path.join(PROJECT, "scripts", "vehicles", "car_radio.gd")
CACHE = os.environ.get("FARMCRAFT_AUDIO_CACHE", os.path.join(tempfile.gettempdir(), "farmcraft_audio_src"))
HEADERS = {"User-Agent": "FarmCraftAudioFetcher/1.0 (game audio build script)"}
COMMONS = "https://upload.wikimedia.org/wikipedia/commons/"
INCOMPETECH = "https://incompetech.com/music/royalty-free/mp3-royaltyfree/"

# Integrated loudness every track is brought to (LUFS; the game's own music is between -14
# and -6), the limiter's ceiling, and the most it may take off a peak (dB): a recording
# that would need more (a solo piano's wide dynamics) stays that much quieter instead.
LOUDNESS = -14.0
CEILING = 0.89
MAX_LIMIT = 6.0
# Vorbis quality is 1 - this (0.6: about 128 kbit/s; the set is a small speaker).
COMPRESSION = 0.6
# Silence (below SILENCE_DB) kept before the first note and after the last (seconds).
SILENCE_DB = -55.0
LEAD = 0.25
TAIL = 1.2

# Output (under art/audio) -> (source URL, bytes, SHA-1 or None).
TRACKS = {
    # --- Yeşilova FM: Turku, Nomads of the Silk Road, "Alleys of Istanbul" (CC BY 4.0) ---
    "music/radio/yesilova_yesilim.ogg": (
        COMMONS + "a/ad/Turku_Nomads_of_the_Silk_Road_-_08_-_-Yesilim.ogg",
        2527150, "c64495ecfb9cffe79f9af871db53884820837f6c"),
    "music/radio/yesilova_uskudara_gider_iken.ogg": (
        COMMONS + "4/41/Turku_Nomads_of_the_Silk_Road_-_01_-_-Uskudara_Gideriken.ogg",
        4979217, "99ef790712e845cd9d2c2935d19eec7ce7b88028"),
    # --- Radyo Yol: Kevin MacLeod, incompetech.com (CC BY 4.0) ---
    "music/radio/yol_bama_country.ogg": (INCOMPETECH + "Bama Country.mp3", 8536896, None),
    "music/radio/yol_cattails.ogg": (INCOMPETECH + "Cattails.mp3", 6365435, None),
    # --- Radyo Huzur: Musopen (public domain) ---
    "music/radio/huzur_satie_gymnopedie_1.ogg": (
        COMMONS + "9/90/Erik_Satie_-_gymnopedies_-_la_1_ere._lent_et_douloureux.ogg",
        3696351, "96b2343c81047abd9723488d8540b5a2af688233"),
}


def cached(rel):
    """Where the source of `rel` is kept once downloaded."""
    url = TRACKS[rel][0]
    name = os.path.basename(rel)[:-4] + os.path.splitext(urllib.parse.unquote(url))[1]
    return os.path.join(CACHE, "radio_" + name)


def source(rel):
    """Downloads the source of `rel` (once) and checks it is the file its source published."""
    url, size, sha1 = TRACKS[rel]
    path = cached(rel)
    if not os.path.exists(path):
        os.makedirs(CACHE, exist_ok=True)
        req = urllib.request.Request(urllib.parse.quote(url, safe=":/%"), headers=HEADERS)
        with urllib.request.urlopen(req, timeout=300) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    with open(path, "rb") as f:
        data = f.read()
    if len(data) != size or (sha1 and hashlib.sha1(data).hexdigest() != sha1):
        raise RuntimeError(f"{path}: not the file listed ({len(data)} bytes); delete it and run again, "
                           "or look the track up again if its source changed")
    return path


def loudness(x, sr):
    """Integrated loudness in LUFS (ITU-R BS.1770-4: K-weighting, 400 ms blocks, gated)."""
    import numpy as np
    from scipy import signal

    # The K-weighting's two filters, worked out for this sample rate.
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


def trimmed(x, sr):
    """`x` without the silence before its first note and after its last (LEAD, TAIL kept)."""
    import numpy as np
    loud = np.flatnonzero(np.max(np.abs(x), axis=1) > 10 ** (SILENCE_DB / 20.0))
    if len(loud) == 0:
        return x
    start = max(int(loud[0]) - int(LEAD * sr), 0)
    end = min(int(loud[-1]) + int(TAIL * sr), len(x))
    x = x[start:end].copy()
    # No click where the cut falls inside a room's hiss.
    k = min(int(0.02 * sr), len(x) // 2)
    x[:k] *= np.linspace(0.0, 1.0, k)[:, None]
    x[len(x) - k:] *= np.linspace(1.0, 0.0, k)[:, None]
    return x


def levelled(x, sr):
    """`x` at LOUDNESS, its peaks held under CEILING by a look-ahead limiter (by MAX_LIMIT
    at most). Returns it with the gain given (dB) and the most the limiter took off (dB)."""
    import numpy as np
    from scipy import ndimage
    peak = np.maximum(np.max(np.abs(x), axis=1), 1e-9)
    gain = 10 ** ((LOUDNESS - loudness(x, sr)) / 20.0)
    gain = min(gain, CEILING * 10 ** (MAX_LIMIT / 20.0) / float(peak.max()))
    # The gain every sample needs, held 20 ms either side and smoothed over as long: never
    # above what is needed, and without steps.
    need = np.minimum(1.0, CEILING / (peak * gain))
    w = int(0.04 * sr) | 1
    g = ndimage.uniform_filter1d(ndimage.minimum_filter1d(need, w, mode="nearest"), w, mode="nearest")
    g = np.minimum(g, need)
    return x * (gain * g)[:, None], 20.0 * np.log10(gain), -20.0 * np.log10(max(float(g.min()), 1e-9))


def build(force=False):
    """Writes every missing track; returns {output: seconds} for all that are there."""
    import numpy as np
    import soundfile as sf
    lengths = {}
    for rel in TRACKS:
        out = os.path.join(ROOT, rel)
        if os.path.exists(out) and not force:
            lengths[rel] = sf.info(out).duration
            continue
        x, sr = sf.read(source(rel), always_2d=True, dtype="float32")
        before = loudness(x, sr)
        x = trimmed(x, sr)
        x, gain, limited = levelled(x, sr)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        # libsndfile's Vorbis encoder crashes on long buffers written at once: in blocks.
        x = np.ascontiguousarray(x, dtype=np.float32)
        with sf.SoundFile(out, "w", sr, x.shape[1], format="OGG", subtype="VORBIS", compression_level=COMPRESSION) as f:
            for i in range(0, len(x), 8192):
                f.write(x[i:i + 8192])
        lengths[rel] = sf.info(out).duration
        print(f"{rel}: {lengths[rel]:.2f} s, {os.path.getsize(out) / 1e6:.2f} MB, {sr} Hz, "
              f"{before:.1f} -> {loudness(x, sr):.1f} LUFS ({gain:+.1f} dB, limiter {limited:.1f} dB)")
    return lengths


def set_seconds(lengths):
    """Writes each track's length into the stations' table (CarRadio.STATIONS)."""
    with open(RADIO_GD, encoding="utf-8") as f:
        text = f.read()
    changed = 0
    for rel, seconds in lengths.items():
        row = re.compile(r'(\["%s", "[^"\n]*", )[0-9.]+(\])' % re.escape(rel))
        if not row.search(text):
            raise RuntimeError(f"{rel} is not in CarRadio.STATIONS ({RADIO_GD})")
        new = row.sub(lambda m: "%s%.2f%s" % (m.group(1), seconds, m.group(2)), text)
        changed += new != text
        text = new
    with open(RADIO_GD, "w", encoding="utf-8") as f:
        f.write(text)
    return changed


if __name__ == "__main__":
    if "--list" in sys.argv:
        for rel, (url, size, sha1) in TRACKS.items():
            print(f"{rel}  <-  {url}  ({size / 1e6:.2f} MB)")
        print(f"{len(TRACKS)} files, {sum(t[1] for t in TRACKS.values()) / 1e6:.1f} MB to download")
        sys.exit(0)
    made = build("--force" in sys.argv)
    total = sum(os.path.getsize(os.path.join(ROOT, rel)) for rel in made)
    print(f"{len(made)} tracks, {sum(made.values()) / 60.0:.1f} min, {total / 1e6:.1f} MB; "
          f"{set_seconds(made)} lengths changed in car_radio.gd")
