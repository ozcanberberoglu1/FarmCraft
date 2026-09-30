#!/usr/bin/env python3
"""Downloads the CC0 photo-scanned shrubs the wild berry bushes are built from
(scripts/resources/berry_bush.gd) from Poly Haven (polyhaven.com).

Run from the project root:  python3 tools/fetch_wild.py
Each model lands in art/models/nature/<asset>/ as <asset>_1k.gltf with its .bin and
textures/ folder (plus the leaf cut-out map the glTF leaves out). All CC0 (public
domain); see art/models/nature/CREDITS.md.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from fetch_models import ROOT, download, fetch_json  # noqa: E402

# asset -> resolution
SHRUBS = {"shrub_01": "1k", "shrub_02": "1k", "shrub_04": "1k"}


def main():
    total = 0
    for asset, res in SHRUBS.items():
        files = fetch_json(asset)
        entry = files["gltf"][res]["gltf"]
        folder = os.path.join(ROOT, "nature", asset)
        total += download(entry["url"], os.path.join(folder, os.path.basename(entry["url"])))
        for rel, inc in entry.get("include", {}).items():
            total += download(inc["url"], os.path.join(folder, rel))
        url = files["Alpha"][res]["jpg"]["url"]
        total += download(url, os.path.join(folder, "textures", f"{asset}_alpha_{res}.jpg"))
        print(f"{asset}: ok")
    print(f"downloaded {total / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
