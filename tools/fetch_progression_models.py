#!/usr/bin/env python3
"""Downloads the CC0 Poly Haven scans behind the workbench's new things: the fish knife,
the worm tin, the dough bowl, the carpenter's tools dressing the workbench and the
sapling's young tree (see the CREDITS.md in each group folder).

Run from the project root:  python3 tools/fetch_progression_models.py
Same layout as tools/fetch_models.py (art/models/<group>/<asset>/<asset>_<res>.gltf).
"""
from fetch_models import fetch_json, download, ROOT
import os

# asset -> (group folder, resolution)
MODELS = {
    "fish_knife": ("tools", "1k"),
    # The workbench's tools: a saw on its back board, a hammer and a plane on the top.
    "handsaw_wood": ("props", "1k"),
    "wooden_hammer_01": ("props", "1k"),
    "hand_plane_no4": ("props", "1k"),
    # Bait: an old tin for the worms, a carved bowl for the dough.
    "can_rusted": ("items", "1k"),
    "wooden_bowl_01": ("items", "1k"),
}


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
