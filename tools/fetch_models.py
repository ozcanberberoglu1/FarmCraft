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
    # Town of Yeşilova (realism pass): street furniture and clutter.
    "water_manhole_cover": ("town", "1k"),
    "utility_box_02": ("town", "1k"),
    "barrel_03": ("town", "1k"),
    "propane_tank": ("town", "1k"),
    "old_tyre": ("town", "1k"),
    "cement_bag": ("town", "1k"),
    "plastic_monobloc_chair_01": ("town", "1k"),
    "trashbag": ("town", "1k"),
    "planter_pot_clay": ("town", "1k"),
    # Nature: boulders for the breakable rocks and the scattered stones, forest-floor
    # undergrowth (ferns, nettles, fallen branches, stumps, a fallen trunk).
    "rock_moss_set_01": ("nature", "2k"),
    "rock_moss_set_02": ("nature", "2k"),
    "boulder_01": ("nature", "2k"),
    "rock_09": ("nature", "1k"),
    "fern_02": ("nature", "1k"),
    "nettle_plant": ("nature", "1k"),
    "dry_branches_medium_01": ("nature", "1k"),
    "tree_stump_01": ("nature", "1k"),
    "dead_tree_trunk": ("nature", "1k"),
}


# Maps the glTF leaves out (its leaf cards need their cut-out): asset -> [map key].
# Saved as textures/<asset>_<key>_<res>.jpg beside the model's own textures.
EXTRA_MAPS = {
    "fern_02": ["Alpha"],
    "nettle_plant": ["Alpha"],
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
        for key in EXTRA_MAPS.get(asset, []):
            url = fetch_json(asset)[key][res]["jpg"]["url"]
            total += download(url, os.path.join(folder, "textures", f"{asset}_{key.lower()}_{res}.jpg"))
        print(f"{asset}: ok")
    print(f"downloaded {total / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
