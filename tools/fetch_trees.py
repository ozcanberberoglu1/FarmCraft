#!/usr/bin/env python3
"""Downloads the CC0 Poly Haven tree models the game's trees are built from, then has
Blender turn them into game trees (tools/blender/build_trees.py).

The source models are film-quality (millions of triangles, every needle and leaf
modelled, 50 MB - 1 GB each), so they are kept out of the project in a cache folder;
only the built trees (art/models/trees/*.glb: trunk and limbs, leaf-cluster cards with
their LODs, the multi-angle impostor pictures) go into the game.

Run from the project root:
    python3 tools/fetch_trees.py                 # download into ~/.cache/farmcraft_trees
    python3 tools/fetch_trees.py --build         # ... and build every tree with Blender
    python3 tools/fetch_trees.py --build fir_tree_01   # one source only
    python3 tools/fetch_trees.py --compose       # the impostor atlas of all built trees
Options: --cache <dir> (download folder), --blender <path to the Blender executable>.
--build ends with --compose. Then import in Godot (godot --headless --path . --import).
All assets are CC0 (public domain); see art/models/trees/CREDITS.md.
"""
import json
import os
import subprocess
import sys
import urllib.request

API = "https://api.polyhaven.com/files/"
HEADERS = {"User-Agent": "FarmCraft-tree-fetcher/1.0"}
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DEFAULT_CACHE = os.path.expanduser("~/.cache/farmcraft_trees")
DEFAULT_BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"

# Source models (all Poly Haven, CC0). Texture resolution 2k: the leaf-cluster cards
# and impostors are rendered from them.
SOURCES = [
    "fir_tree_01",       # three silver firs
    "pine_tree_01",      # three pines (same trunks, pine twigs)
    "tree_small_02",     # small broadleaf tree
    "island_tree_01",    # gnarled, olive-like tree
    "jacaranda_tree",    # big, open broadleaf crown of feathery leaves (read as a locust)
]
RES = "2k"
# Maps the glTF leaves out: the twig and leaf cards' cut-out. Saved as
# textures/<asset>_<key>_<res>.jpg beside the model's own textures.
EXTRA_MAPS = {
    "fir_tree_01": ["twig_alpha"],
    "pine_tree_01": ["twig_alpha"],
    "tree_small_02": ["leaves_alpha"],
    "island_tree_01": ["leaves_alpha"],
    "jacaranda_tree": ["leaves_alpha"],
}


def fetch_json(asset):
    req = urllib.request.Request(API + asset, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def download(url, path):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return 0
    os.makedirs(os.path.dirname(path), exist_ok=True)
    req = urllib.request.Request(url, headers=HEADERS)
    tmp = path + ".part"
    with urllib.request.urlopen(req, timeout=600) as r, open(tmp, "wb") as f:
        size = 0
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
            size += len(chunk)
    os.replace(tmp, path)
    return size


def fetch(asset, cache):
    files = fetch_json(asset)
    info = files["gltf"][RES]["gltf"]
    folder = os.path.join(cache, asset)
    got = download(info["url"], os.path.join(folder, "%s_%s.gltf" % (asset, RES)))
    for rel, entry in info.get("include", {}).items():
        got += download(entry["url"], os.path.join(folder, rel))
    for key in EXTRA_MAPS.get(asset, []):
        entry = files[key][RES]["jpg"]
        got += download(entry["url"], os.path.join(folder, "textures", "%s_%s_%s.jpg" % (asset, key, RES)))
    print("%s: %.1f MB downloaded" % (asset, got / 1e6))
    return os.path.join(folder, "%s_%s.gltf" % (asset, RES))


def main():
    args = sys.argv[1:]
    cache = DEFAULT_CACHE
    blender = DEFAULT_BLENDER
    build = False
    compose = False
    only = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--cache":
            cache = os.path.abspath(args[i + 1])
            i += 1
        elif a == "--blender":
            blender = args[i + 1]
            i += 1
        elif a == "--build":
            build = True
        elif a == "--compose":
            compose = True
        else:
            only.append(a)
        i += 1
    script = os.path.join(ROOT, "tools", "blender", "build_trees.py")
    out = os.path.join(ROOT, "art", "models", "trees")
    if not compose or build:
        for asset in only or SOURCES:
            gltf = fetch(asset, cache)
            if build:
                subprocess.check_call([blender, "-b", "--factory-startup", "--python", script, "--",
                        "--source", gltf, "--asset", asset, "--out", out])
    if build or compose:
        subprocess.check_call([blender, "-b", "--factory-startup", "--python", script, "--",
                "--compose", cache, "--out", out])


if __name__ == "__main__":
    main()
