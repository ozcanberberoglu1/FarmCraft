#!/usr/bin/env python3
"""Builds the fishing assets: sounds (art/audio/sfx/fishing) and models (art/models/fish).

Run from the project root:  python3 tools/fetch_fishing.py [--sounds] [--models] [--force]
(both when neither is given). Needs numpy, scipy and soundfile for the sounds and
Blender (BLENDER env var, default /Applications/Blender.app/Contents/MacOS/Blender) for
the models.

Sources (see art/audio/CREDITS.md and art/models/fish/CREDITS.md), all free for
commercial use without attribution:
  - Freesound (CC0) recordings of casting, reels, lure plops, splashing fish and fish
    flopping on the ground (the 'hq' previews), and Mixkit (Mixkit free licence) water
    bubbles, splashes and a fish flapping; cut, cleaned and levelled here.
  - Poly Haven (CC0) 'Rubber Boots' for the old boot that comes up from the pond.
  - The fish, crayfish, rod and float are modelled by tools/blender/make_fishing.py
    (glTF files with their textures in art/models/fish/textures).
Sources are cached in $FARMCRAFT_FISH_CACHE (default: the temp dir).
"""
import os
import subprocess
import sys
import tempfile
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.join(HERE, "..")
AUDIO = os.path.join(PROJECT, "art", "audio", "sfx", "fishing")
MODELS = os.path.join(PROJECT, "art", "models", "fish")
CACHE = os.environ.get("FARMCRAFT_FISH_CACHE", os.path.join(tempfile.gettempdir(), "farmcraft_fish_src"))
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
HEADERS = {"User-Agent": "Mozilla/5.0 (FarmCraft asset fetcher)"}
SR = 44100
CEILING = 0.89

FS = "https://cdn.freesound.org/previews/"
MIXKIT = "https://assets.mixkit.co/active_storage/sfx/{0}/{0}-preview.mp3"
SOURCES = {
    # Freesound, CC0.
    "cast_el_boss": FS + "853/853287_9129912-hq.mp3",      # el_boss: Casting Fishing Rod for Game Fishing SFX
    "cast_swoosh": FS + "725/725426_14375679-hq.mp3",      # mwchristian95: Fishing Rod Cast - Swoosh
    "cast_throw": FS + "464/464697_7358035-hq.mp3",        # BranndyBottle: fishingreel_throw
    "lure_plop": FS + "853/853279_9129912-hq.mp3",         # el_boss: Fishing Lure Plop Water
    "droplet": FS + "792/792931_71257-hq.mp3",             # qubodup: Quick Water Droplet
    "drop_splash": FS + "451/451126_2927958-hq.mp3",       # bolkmar: Water drop (splash)
    "tiny_splash": FS + "321/321490_5485024-hq.mp3",       # dslrguide: Tiny Splash
    "fish_splash_1": FS + "507/507094_8682843-hq.mp3",     # paulprit: Fish Splashing Release 1
    "fish_splash_2": FS + "507/507093_8682843-hq.mp3",     # paulprit: Fish Splashing Release 2
    "water_flutter": FS + "679/679400_14805886-hq.mp3",    # adviseme333: fast water flutter
    "reel_spin": FS + "509/509902_10725617-hq.mp3",        # tosha73: Spinning reel
    "reel_wind": FS + "831/831928_11611892-hq.mp3",        # 1bob: Fishing reel winding
    "reel_mw": FS + "725/725424_14375679-hq.mp3",          # mwchristian95: Fishing Reel
    "flop_snow": FS + "450/450829_612689-hq.mp3",          # kyles: fish slaps on snow writhing after caught
    "flop_sand": FS + "679/679389_14805886-hq.mp3",        # adviseme333: Fish flopping over on sand
    # Mixkit, free licence.
    "mk_flap": MIXKIT.format(2457),                         # Fish flapping
    "mk_bubble": MIXKIT.format(1317),                       # Water bubble
    "mk_fish_water": MIXKIT.format(2921),                   # Fish moving in water
    "mk_sea_splash": MIXKIT.format(1198),                   # Sea water splash
}
POLYHAVEN_BOOTS = "https://api.polyhaven.com/files/rubber_boots"

# Output take -> [(source, start s, length s, gain dB, options)], target loudness (dBFS of
# the loudest 50 ms). Options: hp/lp (Hz), fin/fout (s), pitch (resample factor).
TAKES = {
    # The rod swishing through the air and the line whizzing off the spool.
    "cast_0": ([("cast_el_boss", 0.0, 1.1, 0.0, {"fout": 0.35, "hp": 150})], -17.0),
    "cast_1": ([("cast_swoosh", 0.0, 1.2, 0.0, {"fout": 0.3, "hp": 150})], -17.0),
    "cast_2": ([("cast_throw", 0.08, 0.75, 0.0, {"fout": 0.25, "hp": 150})], -17.0),
    # The float landing on the water.
    "plop_0": ([("lure_plop", 0.0, 0.38, 0.0, {"fout": 0.1})], -19.0),
    "plop_1": ([("mk_bubble", 0.0, 0.42, 0.0, {"fout": 0.12, "pitch": 0.85})], -19.0),
    "plop_2": ([("tiny_splash", 0.2, 0.4, 0.0, {"fout": 0.15, "fin": 0.005})], -19.0),
    # A fish nibbling: small bloops and drips around the float.
    "nibble_0": ([("droplet", 0.0, 0.2, 0.0, {"fout": 0.06, "pitch": 0.75})], -25.0),
    "nibble_1": ([("drop_splash", 0.15, 0.35, 0.0, {"fout": 0.12})], -25.0),
    "nibble_2": ([("mk_bubble", 0.0, 0.42, 0.0, {"fout": 0.12, "pitch": 1.2})], -26.0),
    # The bite: the float pulled under and the fish thrashing at the surface.
    "bite_0": ([("fish_splash_1", 0.5, 1.3, 0.0, {"fin": 0.01, "fout": 0.35})], -15.0),
    "bite_1": ([("fish_splash_2", 0.48, 1.6, 0.0, {"fin": 0.01, "fout": 0.4})], -15.0),
    "bite_2": ([("mk_fish_water", 0.35, 1.5, 0.0, {"fin": 0.01, "fout": 0.4})], -16.0),
    # The fish yanked out of the water.
    "splash_0": ([("mk_sea_splash", 0.3, 1.1, 0.0, {"fin": 0.01, "fout": 0.45})], -16.0),
    "splash_1": ([("fish_splash_2", 1.8, 0.9, 0.0, {"fin": 0.01, "fout": 0.35})], -16.0),
    # Reeling in (played while the line comes back, faded out when it is in).
    "reel_0": ([("reel_spin", 1.0, 3.0, 0.0, {"fin": 0.05, "fout": 0.2, "hp": 200})], -21.0),
    "reel_1": ([("reel_wind", 0.0, 2.9, 0.0, {"fin": 0.03, "fout": 0.2, "hp": 200})], -21.0),
    "reel_2": ([("reel_mw", 0.0, 2.6, 0.0, {"fin": 0.03, "fout": 0.2, "hp": 200})], -21.0),
    # A fish slapping the ground as it flops about.
    "flop_0": ([("mk_flap", 0.0, 0.45, 0.0, {"fout": 0.15})], -17.0),
    "flop_1": ([("flop_snow", 29.3, 0.4, 0.0, {"fin": 0.005, "fout": 0.15})], -17.0),
    "flop_2": ([("flop_snow", 38.27, 0.4, 0.0, {"fin": 0.005, "fout": 0.15})], -17.0),
    "flop_3": ([("flop_snow", 41.88, 0.4, 0.0, {"fin": 0.005, "fout": 0.15})], -17.0),
    "flop_4": ([("flop_sand", 3.22, 0.42, 0.0, {"fin": 0.005, "fout": 0.15})], -17.0),
    "flop_5": ([("flop_snow", 42.87, 0.4, 0.0, {"fin": 0.005, "fout": 0.15})], -17.0),
}


def _fetch(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.read()


def _cached(key, url):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, key + os.path.splitext(url.split("?")[0])[1])
    if not os.path.exists(path):
        print("fetching", url)
        with open(path, "wb") as f:
            f.write(_fetch(url))
    return path


def sounds(force=False):
    import numpy as np
    import soundfile as sf
    from scipy import signal

    loaded = {}

    def load(key):
        if key not in loaded:
            x, r = sf.read(_cached(key, SOURCES[key]), always_2d=True, dtype="float32")
            x = x.mean(axis=1)
            if r != SR:
                g = np.gcd(int(r), SR)
                x = signal.resample_poly(x, SR // g, int(r) // g).astype(np.float32)
            loaded[key] = x
        return loaded[key]

    def filt(x, kind, hz):
        sos = signal.butter(2, hz / (SR / 2), kind, output="sos")
        return signal.sosfilt(sos, x).astype(np.float32)

    def loudness(x):
        n = int(0.05 * SR)
        if len(x) < n:
            return 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-9)
        c = np.cumsum(np.concatenate([[0.0], x.astype(np.float64) ** 2]))
        w = (c[n::441] - c[:-n:441][: len(c[n::441])]) / n
        return 20 * np.log10(np.sqrt(w.max()) + 1e-9)

    os.makedirs(AUDIO, exist_ok=True)
    made = 0
    for name, (layers, target) in TAKES.items():
        path = os.path.join(AUDIO, name + ".ogg")
        if os.path.exists(path) and not force:
            continue
        mix = None
        for key, t0, length, gain, opt in layers:
            x = load(key)
            a = int(t0 * SR)
            y = x[a:a + int(length * SR)].copy()
            if "pitch" in opt:
                # Resampled: lower pitch plays longer (like slowing a tape).
                p = opt["pitch"]
                y = signal.resample(y, int(len(y) / p)).astype(np.float32)
            y = filt(y, "high", opt.get("hp", 60.0))
            if "lp" in opt:
                y = filt(y, "low", opt["lp"])
            fin, fout = int(opt.get("fin", 0.004) * SR), int(opt.get("fout", 0.05) * SR)
            if fin > 0:
                y[:fin] *= np.linspace(0.0, 1.0, fin) ** 2
            if fout > 0:
                y[-fout:] *= np.linspace(1.0, 0.0, fout) ** 2
            y *= 10 ** (gain / 20)
            mix = y if mix is None else np.pad(mix, (0, max(0, len(y) - len(mix)))) + np.pad(y, (0, max(0, len(mix) - len(y))))
        mix *= 10 ** ((target - loudness(mix)) / 20)
        peak = np.abs(mix).max()
        if peak > CEILING:
            mix *= CEILING / peak
        sf.write(path, mix, SR, format="OGG", subtype="VORBIS")
        made += 1
    print(f"sounds: {made} written to {AUDIO}")


def models():
    import json
    meta = json.loads(_fetch(POLYHAVEN_BOOTS))["gltf"]["1k"]["gltf"]
    folder = os.path.join(CACHE, "rubber_boots")
    gltf = os.path.join(folder, os.path.basename(meta["url"]))
    for url, dst in [(meta["url"], gltf)] + [(inc["url"], os.path.join(folder, rel)) for rel, inc in meta["include"].items()]:
        if not os.path.exists(dst):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            print("fetching", url)
            with open(dst, "wb") as f:
                f.write(_fetch(url))
    # The textures are painted into the cache, then written next to the .gltf files.
    subprocess.run([BLENDER, "-b", "--factory-startup", "--python", os.path.join(HERE, "blender", "make_fishing.py"),
                    "--", "--out", MODELS, "--boots", gltf, "--tmp", os.path.join(CACHE, "textures")], check=True)


if __name__ == "__main__":
    want_sounds = "--sounds" in sys.argv or "--models" not in sys.argv
    want_models = "--models" in sys.argv or "--sounds" not in sys.argv
    if want_sounds:
        sounds("--force" in sys.argv)
    if want_models:
        models()
