#!/usr/bin/env python3
"""Builds the recorded tool and farm-work sounds (axe, pickaxe, hoe, scythe, harvest,
planting, watering, felled trees, split boulders) into art/audio/sfx/tools/.

Run from the project root:  python3 tools/build_foley.py   (tools/fetch_audio.py runs it too)
Needs numpy, scipy and soundfile (pip install numpy scipy soundfile) and `tar` for the
.7z pack (bsdtar: macOS, Windows 10+, libarchive-tools on Linux).

Every take is cut from a real recording (sources below and in art/audio/CREDITS.md):
trimmed so it lands on the frame of the hit, layered where one recording alone is thin
(a rock hit gets its debris, a felled tree its leaves and ground thud), given a touch of
outdoor early reflections for the big impacts, and matched in loudness. The downloads are
cached in $FARMCRAFT_AUDIO_CACHE (default: the system temp folder). Existing outputs are
skipped unless --force is given.
"""
import io
import os
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "audio")
CACHE = os.environ.get("FARMCRAFT_AUDIO_CACHE", os.path.join(tempfile.gettempdir(), "farmcraft_audio_src"))
HEADERS = {"User-Agent": "FarmCraftAudioFetcher/1.0 (game audio build script)"}
SR = 44100
# Peak ceiling of every take (-1 dBFS).
CEILING = 0.89

OGA = "https://opengameart.org/sites/default/files/"
COMMONS = "https://upload.wikimedia.org/wikipedia/commons/"
# Freesound's high-quality previews (192 kbps mp3) download without an account.
FREESOUND = "https://cdn.freesound.org/previews/"


def mixkit(sid):
    return f"https://assets.mixkit.co/active_storage/sfx/{sid}/{sid}-preview.mp3"


# Source key -> (url, member inside an archive or None). Licences: see CREDITS.md.
SOURCES = {
    # "tomattka", CC0, Freesound: a tree cut down with an axe (Zoom H1, outdoors).
    "felling": (FREESOUND + "401/401730_6351775-hq.mp3", None),
    # "stephan", public domain, Wikimedia Commons (mp3 transcodes of the .ogg originals).
    "grain": (COMMONS + "transcoded/9/9f/Pouring_particles_like_grain.ogg/Pouring_particles_like_grain.ogg.mp3", None),
    "trickle": (COMMONS + "transcoded/4/4f/Water_flowing_pouring_trickling.ogg/Water_flowing_pouring_trickling.ogg.mp3", None),
    # OpenGameArt, CC0.
    "tree_fall": (OGA + "chop-tree-fall.ogg", None),  # kheetor
    "shovel": (OGA + "shovel.ogg", None),  # themightyglider
    "weeds": (OGA + "rustling_of_the_weeds.wav", None),  # Spring Spring
    **{f"rock_{n}": (OGA + "sfx_breaking_and_falling.zip", f"bfh1_rock_{n}.ogg") for n in  # rubberduck
       ["breaking_01", "breaking_02", "breaking_03", "falling_04", "falling_06", "falling_08"]},
    **{f"stones_{n}": (OGA + "sfx_100_v2.zip", f"sfx100v2_stones_{n}.ogg") for n in ["01", "02", "03"]},  # rubberduck
    **{f"crack{n}": (OGA + "independent_nu_ljudbank-wood_crack_hit_destruction.7z", f"crack{n}.mp3.flac")
       for n in ["04", "05", "10"]},  # Independent.nu
    # Mixkit (free licence; see CREDITS.md).
    "grass_handling": (mixkit(1925), None), "hay_steps": (mixkit(541), None), "dirt_debris": (mixkit(402), None),
    "gravel_hit": (mixkit(756), None), "stone_avalanche": (mixkit(1272), None), "stones_falling": (mixkit(1271), None),
    "sand_impact": (mixkit(2498), None), "mud_fall": (mixkit(385), None), "mud_stomp": (mixkit(3058), None),
    "leaves_fall": (mixkit(751), None), "shovel_stab_hard": (mixkit(1923), None), "shovel_stab": (mixkit(1918), None),
    "dig_1": (mixkit(1915), None), "dig_2": (mixkit(1917), None), "dig_3": (mixkit(1916), None),
}

# One layer: (source, start s, length s, gain dB, {options}). Options: at (s into the
# take), pitch (resample ratio), hp / lp (Hz), fin / fout (fade s), burst (decay s of an
# exponential envelope), duck ((s, dB): everything after s turned down). Takes: {layers,
# space (outdoor reflections), target (loudness, dBFS of the loudest 50 ms), cap (most dB
# a hit's peak is limited by), release (s)}.
A = "sfx/tools/"


def axe(t):
    # The high-pass keeps the thunk (100-400 Hz) but tames the 54 Hz boom the trunk rings with.
    return {"layers": [("felling", t - 0.004, 0.42, 0.0, {"hp": 80, "fout": 0.2}),
                       # The trunk answering the blow: the same bite an octave down, only its lows.
                       ("felling", t - 0.004, 0.21, -9.0, {"pitch": 0.5, "hp": 70, "lp": 380, "fout": 0.2})],
            "space": True, "target": -14.0, "cap": 9.0}


def pick(src, t0, length, debris=None):
    # Later knocks in the recording become the small chips landing (12 dB down).
    layers = [(src, t0, length, 0.0, {"hp": 90, "fout": 0.08, "duck": (0.06, -12.0)}),
              # The weight of the pick: a dull thump under the crack.
              ("gravel_hit", 0.04, 0.16, -13.0, {"lp": 420, "fout": 0.08})]
    if debris:
        layers.append(("stones_falling", debris, 0.45, -15.0, {"at": 0.05, "hp": 400, "fin": 0.02, "fout": 0.2}))
    return {"layers": layers, "space": True, "target": -14.0, "cap": 10.0, "release": 0.02}


def hoe(src, t0, length, crumbs):
    return {"layers": [(src, t0, length, 0.0, {"hp": 70, "fout": 0.06}),
                       ("dirt_debris", crumbs, 0.5, -11.0, {"at": 0.07, "hp": 180, "lp": 9000, "fin": 0.01, "fout": 0.25})],
            "target": -18.0}


def rustle(src, t0, length, burst, gain=0.0, lp=11000, extra=None, pitch=1.0):
    layers = [(src, t0, length, gain, {"hp": 150, "lp": lp, "fin": 0.025, "burst": burst, "pitch": pitch})]
    if extra:
        layers.append(extra)
    return {"layers": layers, "target": -19.0}


TAKES = {
    # The axe biting into the trunk: eight different blows, from a dull thunk to a sharp bite
    # (ones where the axe head's 4.8 kHz ring stays faint).
    **{A + f"axe_{i}.ogg": axe(t) for i, t in enumerate([
        5.536, 12.295, 1.591, 6.191, 4.282, 13.247, 0.879, 3.631])},
    # The trunk giving way as it starts to lean (fibres tearing, a creak), then the crown
    # crashing down through its own branches, leaves and the ground thud.
    A + "tree_crack_0.ogg": {"layers": [("crack04", 0.15, 1.9, 0.0, {"hp": 70, "lp": 7000, "fout": 0.4}),
                                        ("tree_fall", 0.42, 1.1, -12.0, {"hp": 120, "lp": 5000, "fin": 0.1, "fout": 0.4})],
                             "space": True, "target": -16.0},
    A + "tree_crack_1.ogg": {"layers": [("crack05", 0.05, 1.5, 0.0, {"hp": 70, "lp": 7000, "fout": 0.4}),
                                        ("crack10", 0.08, 0.9, -6.0, {"at": 0.45, "hp": 90, "lp": 6000, "fout": 0.3})],
                             "space": True, "target": -16.0},
    A + "tree_fall_0.ogg": {"layers": [("tree_fall", 1.6, 1.07, -2.0, {"hp": 40, "fout": 0.3}),
                                       ("leaves_fall", 0.02, 0.9, -5.0, {"hp": 200, "fout": 0.35}),
                                       ("sand_impact", 0.14, 0.7, 0.0, {"lp": 260, "fout": 0.3}),
                                       ("gravel_hit", 0.04, 0.5, -8.0, {"lp": 900, "fout": 0.3})],
                            "space": True, "target": -10.0, "cap": 9.0},
    A + "tree_fall_1.ogg": {"layers": [("tree_fall", 1.6, 1.07, -3.0, {"hp": 40, "pitch": 0.9, "fout": 0.3}),
                                       ("leaves_fall", 0.02, 0.9, -4.0, {"at": 0.05, "hp": 200, "pitch": 0.94, "fout": 0.35}),
                                       ("mud_fall", 0.02, 0.6, -2.0, {"lp": 240, "fout": 0.3}),
                                       ("sand_impact", 0.14, 0.7, -3.0, {"at": 0.03, "lp": 300, "fout": 0.3})],
                            "space": True, "target": -10.0, "cap": 9.0},
    # The pick's point cracking stone, with the chips that fly and land.
    A + "pick_0.ogg": pick("rock_breaking_01", 0.02, 0.5),
    A + "pick_1.ogg": pick("rock_breaking_02", 0.055, 0.42),
    A + "pick_2.ogg": pick("rock_breaking_03", 0.055, 0.42),
    A + "pick_3.ogg": pick("rock_falling_04", 0.07, 0.3, debris=0.24),
    A + "pick_4.ogg": pick("rock_falling_08", 0.075, 0.3, debris=0.4),
    A + "pick_5.ogg": pick("rock_falling_06", 0.02, 0.35, debris=0.55),
    A + "pick_6.ogg": pick("stones_01", 0.02, 0.45),
    A + "pick_7.ogg": pick("stones_02", 0.02, 0.5),
    # A boulder splitting: the heavy crack, rubble sliding off, a deep thump.
    A + "rock_break_0.ogg": {"layers": [("gravel_hit", 0.04, 1.15, 0.0, {"hp": 50, "fout": 0.3}),
                                        ("rock_breaking_02", 0.05, 0.8, -3.0, {"hp": 120, "fout": 0.2}),
                                        ("stone_avalanche", 0.1, 1.3, -6.0, {"at": 0.12, "hp": 150, "fin": 0.05, "fout": 0.5}),
                                        ("sand_impact", 0.14, 0.5, -4.0, {"lp": 220, "fout": 0.3})],
                             "space": True, "target": -12.0},
    A + "rock_break_1.ogg": {"layers": [("gravel_hit", 0.04, 1.15, 0.0, {"hp": 50, "pitch": 0.9, "fout": 0.3}),
                                        ("rock_breaking_01", 0.02, 0.6, -3.0, {"hp": 120, "fout": 0.2}),
                                        ("stone_avalanche", 1.0, 1.3, -6.0, {"at": 0.1, "hp": 150, "fin": 0.05, "fout": 0.5}),
                                        ("mud_fall", 0.02, 0.5, -5.0, {"lp": 220, "fout": 0.3})],
                             "space": True, "target": -12.0},
    # The hoe's blade chopping into the soil and turning it: a crunchy, earthy scrape and
    # clods falling back.
    A + "hoe_0.ogg": hoe("shovel", 0.0, 0.9, 0.08),
    A + "hoe_1.ogg": hoe("shovel_stab_hard", 0.095, 0.34, 0.56),
    A + "hoe_2.ogg": hoe("shovel_stab", 0.095, 0.3, 0.97),
    A + "hoe_3.ogg": hoe("dig_1", 0.905, 0.36, 1.16),
    A + "hoe_4.ogg": hoe("dig_3", 0.9, 0.4, 1.4),
    A + "hoe_5.ogg": hoe("dig_2", 1.045, 0.3, 2.08),
    # The scythe's blade swishing through grass and stalks.
    A + "scythe_0.ogg": rustle("weeds", 0.0, 0.6, 0.34),
    A + "scythe_1.ogg": rustle("weeds", 0.1, 0.5, 0.3, pitch=0.9),
    A + "scythe_2.ogg": rustle("grass_handling", 7.0, 0.6, 0.3),
    A + "scythe_3.ogg": rustle("grass_handling", 11.0, 0.6, 0.3),
    A + "scythe_4.ogg": rustle("grass_handling", 13.1, 0.6, 0.3, pitch=1.08),
    # Crops coming away: dry stalks crunching, leaves and a little soil.
    A + "harvest_0.ogg": rustle("hay_steps", 17.0, 0.6, 0.3, lp=10000,
                                extra=("grass_handling", 6.8, 0.6, -4.0, {"hp": 150, "burst": 0.28, "fin": 0.02})),
    A + "harvest_1.ogg": rustle("hay_steps", 15.5, 0.6, 0.3, lp=10000,
                                extra=("grass_handling", 12.9, 0.6, -4.0, {"hp": 150, "burst": 0.28, "fin": 0.02})),
    A + "harvest_2.ogg": rustle("hay_steps", 19.3, 0.6, 0.3, lp=10000,
                                extra=("grass_handling", 10.7, 0.6, -4.0, {"hp": 150, "burst": 0.28, "fin": 0.02})),
    # Seeds leaving the hand and pattering on the soil, then the soil pressed over them.
    A + "seeds_0.ogg": {"layers": [("grain", 2.6, 0.5, 0.0, {"hp": 300, "lp": 7000, "fin": 0.03, "burst": 0.16})], "target": -24.0},
    A + "seeds_1.ogg": {"layers": [("grain", 4.1, 0.5, 0.0, {"hp": 300, "lp": 7000, "fin": 0.02, "burst": 0.13})], "target": -24.0},
    A + "seeds_2.ogg": {"layers": [("grain", 30.5, 0.5, 0.0, {"hp": 300, "lp": 7000, "fin": 0.03, "burst": 0.18})], "target": -24.0},
    A + "plant_0.ogg": {"layers": [("sand_impact", 0.145, 0.45, 0.0, {"lp": 2600, "hp": 70, "fout": 0.2}),
                                   ("dirt_debris", 1.18, 0.3, -12.0, {"at": 0.03, "hp": 200, "fin": 0.01, "fout": 0.15})],
                        "target": -19.0},
    A + "plant_1.ogg": {"layers": [("mud_fall", 0.025, 0.4, 0.0, {"lp": 2200, "hp": 70, "fout": 0.2}),
                                   ("dirt_debris", 2.09, 0.3, -12.0, {"at": 0.02, "hp": 200, "fin": 0.01, "fout": 0.15})],
                        "target": -19.0},
    A + "plant_2.ogg": {"layers": [("mud_stomp", 0.035, 0.22, 0.0, {"lp": 1800, "hp": 70, "fout": 0.1}),
                                   ("dirt_debris", 0.26, 0.3, -10.0, {"at": 0.02, "hp": 200, "fin": 0.01, "fout": 0.15})],
                        "target": -19.0},
    # The watering can's stream on soil and into a trough (long enough for any pour; the
    # game fades it out when the can tips back).
    A + "water_can_0.ogg": {"layers": [("trickle", 31.0, 3.0, 0.0, {"hp": 120, "lp": 9000, "fin": 0.04, "fout": 0.4})], "target": -20.0},
    A + "water_can_1.ogg": {"layers": [("trickle", 44.0, 3.0, 0.0, {"hp": 120, "lp": 9000, "fin": 0.04, "fout": 0.4})], "target": -20.0},
    # A crop picked up off the ground: a short leafy rustle.
    A + "pick_crop_0.ogg": rustle("grass_handling", 7.1, 0.3, 0.12),
    A + "pick_crop_1.ogg": rustle("grass_handling", 11.3, 0.3, 0.12),
    A + "pick_crop_2.ogg": rustle("grass_handling", 13.4, 0.3, 0.12, pitch=1.1),
}


def _fetch(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.read()


def _source_path(key):
    url, member = SOURCES[key]
    os.makedirs(CACHE, exist_ok=True)
    name = os.path.basename(url.split("?")[0])
    # Single files are cached by key (Mixkit names every preview "<id>-preview.mp3").
    archive = os.path.join(CACHE, name if member else key + os.path.splitext(name)[1])
    if not os.path.exists(archive):
        print("fetching", url)
        with open(archive, "wb") as f:
            f.write(_fetch(url))
    if member is None:
        return archive
    out_dir = archive + "_x"
    found = [os.path.join(d, member) for d, _, files in os.walk(out_dir) if member in files] if os.path.isdir(out_dir) else []
    if not found:
        os.makedirs(out_dir, exist_ok=True)
        if archive.endswith(".zip"):
            zipfile.ZipFile(archive).extractall(out_dir)
        else:
            subprocess.run(["tar", "-xf", archive, "-C", out_dir], check=True)
        found = [os.path.join(d, member) for d, _, files in os.walk(out_dir) if member in files]
    if not found:
        raise FileNotFoundError(f"{member} not in {url}")
    return found[0]


def build(force=False):
    import numpy as np
    import soundfile as sf
    from scipy import signal

    loaded = {}

    def load(key):
        if key not in loaded:
            x, r = sf.read(_source_path(key), always_2d=True, dtype="float32")
            x = x.mean(axis=1)
            if r != SR:
                g = np.gcd(int(r), SR)
                x = signal.resample_poly(x, SR // g, int(r) // g).astype(np.float32)
            loaded[key] = x
        return loaded[key]

    def filt(x, kind, hz):
        sos = signal.butter(2, hz / (SR / 2), kind, output="sos")
        return signal.sosfilt(sos, x).astype(np.float32)

    def ramp(x, fin, fout):
        x = x.copy()
        a, b = int(fin * SR), int(fout * SR)
        if a > 0:
            x[:a] *= np.linspace(0.0, 1.0, a) ** 2
        if b > 0:
            x[-b:] *= np.linspace(1.0, 0.0, b) ** 2
        return x

    def loudness(x):
        y = filt(x, "high", 60.0)
        n = int(0.05 * SR)
        if len(y) < n:
            return 20 * np.log10(np.sqrt((y ** 2).mean()) + 1e-9)
        # RMS of every 50 ms window (10 ms hop); the loudest one.
        c = np.cumsum(np.concatenate([[0.0], y.astype(np.float64) ** 2]))
        w = (c[n::441] - c[:-n:441][: len(c[n::441])]) / n
        return 20 * np.log10(np.sqrt(w.max()) + 1e-9)

    def space(x):
        # Outdoor early reflections (ground, trees, buildings) and a short soft tail.
        rng = np.random.default_rng(len(x))
        out = np.concatenate([x, np.zeros(int(0.35 * SR), np.float32)])
        dark = filt(x, "low", 3200.0)
        for ms, db in [(19, -18), (37, -21), (61, -23), (89, -26), (131, -29)]:
            k = int(ms * SR / 1000)
            out[k:k + len(x)] += dark * 10 ** (db / 20)
        n = int(0.3 * SR)
        ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (0.07 * SR))
        ir = (ir / np.sqrt((ir ** 2).sum())).astype(np.float32)
        tail = filt(signal.fftconvolve(dark, ir)[: len(out)].astype(np.float32), "low", 4500.0)
        out[: len(tail)] += tail * 10 ** (-24 / 20)
        return out

    def limit(x, release=0.05):
        # Look-ahead peak limiter: the gain dips 1.5 ms before a peak, recovers over `release`.
        from scipy.ndimage import minimum_filter1d
        want = np.minimum(1.0, CEILING / np.maximum(np.abs(x), 1e-9))
        la = int(0.0015 * SR)
        want = minimum_filter1d(want, 2 * la + 1)
        g = np.empty_like(want)
        k = np.exp(-1.0 / (release * SR))
        cur = 1.0
        for i, w in enumerate(want):
            cur = w if w < cur else w + (cur - w) * k
            g[i] = cur
        g = np.convolve(g, np.ones(la) / la, mode="same")
        return (x * np.minimum(g, want)).astype(np.float32)

    made = 0
    for rel, take in TAKES.items():
        path = os.path.join(ROOT, rel)
        if os.path.exists(path) and not force:
            continue
        mix = np.zeros(int(6 * SR), np.float32)
        end = 0
        for key, t0, length, gain, o in take["layers"]:
            x = load(key)
            seg = x[int(t0 * SR): int((t0 + length) * SR)]
            if o.get("pitch", 1.0) != 1.0:
                p = o["pitch"]
                seg = signal.resample(seg, int(len(seg) / p)).astype(np.float32)
            if "hp" in o:
                seg = filt(seg, "high", o["hp"])
            if "lp" in o:
                seg = filt(seg, "low", o["lp"])
            if "duck" in o:
                hold, db = o["duck"]
                a, b = int(hold * SR), int((hold + 0.02) * SR)
                env = np.full(len(seg), 10 ** (db / 20), np.float32)
                env[:a] = 1.0
                env[a:b] = np.linspace(1.0, 10 ** (db / 20), len(env[a:b]))
                seg = seg * env
            if "burst" in o:
                seg = seg * np.exp(-np.arange(len(seg)) / (o["burst"] * SR / 3.0)).astype(np.float32)
            seg = ramp(seg, o.get("fin", 0.002), o.get("fout", 0.03))
            at = int(o.get("at", 0.0) * SR)
            mix[at: at + len(seg)] += seg * 10 ** (gain / 20)
            end = max(end, at + len(seg))
        mix = mix[:end]
        if take.get("space"):
            mix = space(mix)
        # Start on the hit: drop what is quieter than -40 dB of the peak before it.
        k = int(np.argmax(np.abs(mix) > np.abs(mix).max() * 0.01))
        mix = mix[max(0, k - int(0.002 * SR)):]
        # Drop the tail below -60 dB of the peak.
        env = np.abs(mix)
        above = np.where(env > env.max() * 0.001)[0]
        mix = ramp(mix[: above[-1] + 1], 0.001, min(0.05, len(mix) / SR / 4))
        # To the take's loudness; the first milliseconds of a hard hit are limited (by at
        # most `cap` dB) so the hits of a set sound equally loud, under a -1 dBFS ceiling.
        dry = mix
        cap = 10 ** (take.get("cap", 6.0) / 20)
        gain = 10 ** ((take.get("target", -16.0) - loudness(dry)) / 20)
        for _ in range(4):  # limiting takes some loudness away again: settle the gain
            gain = min(gain, cap * CEILING / np.abs(dry).max())
            mix = limit(dry * gain, take.get("release", 0.05))
            gain *= 10 ** ((take.get("target", -16.0) - loudness(mix)) / 20)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        sf.write(path, mix, SR, format="OGG", subtype="VORBIS", compression_level=0.35)
        made += 1
        print(f"{rel}: {len(mix) / SR:.2f} s, loudness {loudness(mix):.1f} dB, peak {20 * np.log10(np.abs(mix).max()):.1f} dB")
    print(f"built {made} sounds")


if __name__ == "__main__":
    build(force="--force" in sys.argv)
