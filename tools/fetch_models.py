#!/usr/bin/env python3
"""Downloads the CC0 photo-scanned models used for tools, farm props and goods from Poly Haven
(polyhaven.com).

Run from the project root:  python3 tools/fetch_models.py
Each model lands in art/models/<group>/<asset>/ as <asset>_<res>.gltf with its .bin and
textures/ folder, the layout Poly Haven serves. All assets are CC0 (public domain);
see the CREDITS.md in each group folder.
"""
import json
import os
import urllib.request

ROOT = os.path.join(os.path.dirname(__file__), "..", "art", "models")
API = "https://api.polyhaven.com/files/"
HEADERS = {"User-Agent": "FarmCraft-model-fetcher/1.0"}

# asset -> (group folder, resolution)
MODELS = {
    "wooden_axe": ("tools", "1k"),
    "picke_dirty_01": ("tools", "1k"),
    "watering_can_metal_01": ("tools", "1k"),
    "wooden_bucket_01": ("tools", "1k"),
    # Machines, sprinkler and the order board.
    "spinning_wheel_01": ("props", "1k"),
    "bench_vice_01": ("props", "1k"),
    "garden_sprinkler_01": ("props", "1k"),
    "wine_barrel_01": ("props", "1k"),
    "standing_chalkboard_01": ("props", "1k"),
    "barrel_stove": ("props", "1k"),
    # Farm goods: milk can (milk) and a compost bag (fertilizer).
    "metal_jug": ("items", "1k"),
    "compost_bag_02": ("items", "1k"),
}


def fetch_json(asset):
    req = urllib.request.Request(API + asset, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def download(url, path):
    if os.path.exists(path):
        return 0
    os.makedirs(os.path.dirname(path), exist_ok=True)
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=120) as r, open(path, "wb") as f:
        data = r.read()
        f.write(data)
    return len(data)


def main():
    total = 0
    for asset, (group, res) in MODELS.items():
        entry = fetch_json(asset)["gltf"][res]["gltf"]
        folder = os.path.join(ROOT, group, asset)
        total += download(entry["url"], os.path.join(folder, os.path.basename(entry["url"])))
        for rel, inc in entry.get("include", {}).items():
            total += download(inc["url"], os.path.join(folder, rel))
        print(f"{asset}: ok")
    print(f"downloaded {total / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
