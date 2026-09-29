#!/usr/bin/env python3
"""Downloads the CC0 PBR textures used by the game from Poly Haven (polyhaven.com).

Run from the project root:  python3 tools/fetch_textures.py
Files land in art/textures/<name>/ as <name>_diff.jpg, _nor.jpg (OpenGL normal) and
_arm.jpg (R = ambient occlusion, G = roughness, B = metallic). Foliage sets are saved
as src/diff, src/alpha and src/normal (ignored by Godot) and combined into an RGBA atlas by tools/build_foliage.gd.
All assets are CC0 (public domain); see art/textures/CREDITS.md.
"""
import json
import os
import urllib.request

ROOT = os.path.join(os.path.dirname(__file__), "..", "art", "textures")
API = "https://api.polyhaven.com/files/"
HEADERS = {"User-Agent": "FarmCraft-texture-fetcher/1.0"}

# name -> resolution, or (resolution, maps) to fetch only some of "diff", "nor", "arm"
SURFACES = {
    "leafy_grass": "2k",
    "aerial_grass_rock": "1k",
    "rocky_trail": "2k",
    "rocky_trail_02": "1k",
    "raked_dirt": "2k",
    "coast_sand_01": "1k",
    "rock_face_03": "1k",
    "mossy_rock": "1k",
    "weathered_brown_planks": "2k",
    "old_wood_floor": "1k",
    "roof_tiles_14": "2k",
    "stone_wall": "1k",
    "rough_wood": "1k",
    "bark_brown_02": "1k",
    "pine_bark": "1k",
    # Town (phase 11): road, pavements, walls, roofs.
    "asphalt_02": "2k",
    "concrete_floor_worn_001": "1k",
    "painted_plaster_wall": "1k",
    "red_brick_03": "1k",
    "corrugated_iron_02": "1k",
    # Farm structures (realism pass): the rusted tin of Grandpa's old roofs.
    "rusty_corrugated_iron": "1k",
    # Town (realism pass): interlocking concrete pavers on the pavements.
    "patterned_concrete_pavers": "1k",
    # Vehicles: pitting and blistered paint on painted steel (rust mask and bumps),
    # coarse rust where the paint is gone.
    "rusty_metal_02": ("1k", ("diff", "nor")),
    "rust_coarse_01": ("1k", ("diff", "nor")),
}

# model asset -> (output folder, [(map key, format, output suffix)], resolution)
FOLIAGE = {
    "tree_small_02": ("leaves_broad", [("leaves_diff", "jpg", "src/diff.jpg"), ("leaves_alpha", "png", "src/alpha.png"),
                                       ("leaves_nor_gl", "jpg", "src/nor.jpg")], "2k"),
    "fir_tree_01": ("leaves_fir", [("twig_diff", "jpg", "src/diff.jpg"), ("twig_alpha", "png", "src/alpha.png"),
                                   ("twig_nor_gl", "jpg", "src/nor.jpg")], "2k"),
    # Single scanned leaves: tools/build_foliage.gd arranges them into the leaf-cluster
    # atlas of the broadleaf trees and bushes (art/textures/leaves_cluster).
    "island_tree_02": ("leaves_island", [("leaves_diff", "jpg", "src/diff.jpg"), ("leaves_alpha", "png", "src/alpha.png"),
                                         ("leaves_nor_gl", "jpg", "src/nor.jpg")], "2k"),
}

# Ground overhaul: terrain layers (meadow litter / forest floor, gravel lanes, packed
# yard dirt, pond-shore mud) and tilled bed soil. Colour and normal maps only: the
# ground shaders derive roughness themselves. name -> resolution.
GROUND = {
    "forrest_ground_01": "2k",
    "gravel_ground_01": "2k",
    "dirt": "2k",
    "brown_mud_03": "1k",
    "farm_soil": "2k",
}

# Photo grass tufts for the meadow cards: the green and the dry colour map and the alpha
# of grass_medium_01's atlas, cropped and packed by tools/build_grass_cards.gd.
GRASS_CARDS = ("grass_medium_01", "grass_cards", [("Diffuse", "jpg", "src/diff.jpg"),
                                                  ("dry_diff", "jpg", "src/dry.jpg"),
                                                  ("Alpha", "png", "src/alpha.png")], "2k")


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
    for name, spec in SURFACES.items():
        res, maps = (spec, ("diff", "nor", "arm")) if isinstance(spec, str) else spec
        files = fetch_json(name)
        for key, suffix in (("Diffuse", "diff"), ("nor_gl", "nor"), ("arm", "arm")):
            if suffix not in maps:
                continue
            url = files[key][res]["jpg"]["url"]
            total += download(url, os.path.join(ROOT, name, f"{name}_{suffix}.jpg"))
        print(f"ok  {name} ({res})")
    for asset, (folder, maps, res) in FOLIAGE.items():
        files = fetch_json(asset)
        for key, fmt, out in maps:
            url = files[key][res][fmt]["url"]
            total += download(url, os.path.join(ROOT, folder, out))
        print(f"ok  {folder} <- {asset} ({res})")
    for name, res in GROUND.items():
        files = fetch_json(name)
        for key, suffix in (("Diffuse", "diff"), ("nor_gl", "nor")):
            url = files[key][res]["jpg"]["url"]
            total += download(url, os.path.join(ROOT, name, f"{name}_{suffix}.jpg"))
        print(f"ok  {name} ({res})")
    asset, folder, maps, res = GRASS_CARDS
    files = fetch_json(asset)
    for key, fmt, out in maps:
        total += download(files[key][res][fmt]["url"], os.path.join(ROOT, folder, out))
    # The sources are combined into one atlas; Godot must not import them.
    open(os.path.join(ROOT, folder, "src", ".gdignore"), "a").close()
    print(f"ok  {folder} <- {asset} ({res})")
    print(f"downloaded {total / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
