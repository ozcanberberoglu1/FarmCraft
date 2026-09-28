#!/usr/bin/env python3
"""Writes Godot import settings for 3D textures: VRAM compression, mipmaps, and
normal-map compression for normal maps. Covers the terrain/material textures under
art/textures and the textures of the downloaded models under art/models. Existing
.import files only get their [params] changed, so uids and paths stay. Run before
`godot --import`."""
import os
import re

ART = os.path.join(os.path.dirname(__file__), "..", "art")

TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality={hq}
compress/lossy_quality=0.7
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/size_limit=0
detect_3d/compress_to=0
"""


def set_param(text, key, value):
    return re.sub(rf"^{re.escape(key)}=.*$", f"{key}={value}", text, flags=re.M)


def write_import(path, normal, hq):
    imp = path + ".import"
    if not os.path.exists(imp):
        with open(imp, "w") as fh:
            fh.write(TEMPLATE.format(normal=int(normal), hq="true" if hq else "false"))
        return True
    with open(imp) as fh:
        text = fh.read()
    new = set_param(text, "compress/mode", "2")
    if hq or "compress/mode=2" not in text:  # keep a high quality format picked by hand
        new = set_param(new, "compress/high_quality", "true" if hq else "false")
    new = set_param(new, "compress/normal_map", "1" if normal else "0")
    new = set_param(new, "mipmaps/generate", "true")
    new = set_param(new, "detect_3d/compress_to", "0")
    if new == text:
        return False
    with open(imp, "w") as fh:
        fh.write(new)
    return True


count = 0
for dirpath, _, files in os.walk(os.path.join(ART, "textures")):
    if os.path.exists(os.path.join(dirpath, ".gdignore")):
        continue  # raw foliage sources, combined by tools/build_foliage.gd
    for f in files:
        if f.lower().endswith((".jpg", ".png")):
            count += write_import(os.path.join(dirpath, f), "_nor" in f, "albedo" in f)
print(f"updated {count} texture import files")

# Model textures were imported lossless without mipmaps: decoded on the main thread at
# first use (hundreds of ms for a 4k image), uncompressed in VRAM and aliasing at a
# distance. Colour maps get the high quality format (BC7 / ASTC).
count = 0
for dirpath, _, files in os.walk(os.path.join(ART, "models")):
    for f in files:
        n = f.lower()
        if not n.endswith((".jpg", ".jpeg", ".png")) or not os.path.exists(os.path.join(dirpath, f + ".import")):
            continue
        colour = any(k in n for k in ("basecolor", "diffuse", "_diff", "albedo")) or re.fullmatch(r"\d+\.png", n)
        count += write_import(os.path.join(dirpath, f), "normal" in n or "_nor" in n, bool(colour))
print(f"updated {count} model texture import files")
