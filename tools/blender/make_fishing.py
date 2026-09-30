"""Builds the fishing models: the pond's fish (raw and cooked), the crayfish, the fishing
rod, its float and the old rubber boot that comes up now and then.

    Blender -b --factory-startup --python tools/blender/make_fishing.py -- \
        --out art/models/fish [--boots <rubber_boots_1k.gltf>] [--only carp,rod]

(tools/fetch_fishing.py downloads the boot and runs this.)

Also the other rods (the bamboo cane pole, the carbon spinning rod, the carp rod) and the
market's bait (a tin of maggots, a tin of sweetcorn, cheese cubes on waxed paper, a bait
bucket of live minnows, a spinner lure).

Every fish is modelled from its species' measurements: a lofted body (depth, width and
back/belly line along its length, a slightly boxy cross-section narrowing to the dorsal
ridge), fins as thin ray fans (dorsal, caudal, anal, pectoral and pelvic pairs, the
trout's adipose fin), eyes and the barbels of carp, tench and catfish. The textures are
painted with numpy from the same body coordinates: countershading, overlapping scales
(albedo and a normal map), lateral line, gill cover, mouth and the species' markings
(the perch's bars, the pike's bean spots, the trout's pink band and black spots, the
catfish's marbling...). The cooked variant is the same fish grilled: golden to dark
brown skin with char marks, crisp fins and white eyes.

The fish lie along +X (head toward +X), back up, centred on their length; the rod
along +Y (Blender +Z), the hand at the origin, its reel and guides toward -X; the float
stands with its waterline at the origin. Blender units are metres, Z up (the glTF export
turns them to Y up). Writes <name>.gltf (+ .bin) to --out, textures to --out/textures.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGS:
        return ARGS[ARGS.index(name) + 1]
    return default


OUT = os.path.abspath(arg("--out", "art/models/fish"))
BOOTS = arg("--boots")
ONLY = arg("--only", "")
ONLY = [s for s in ONLY.split(",") if s]
import tempfile
TMP = arg("--tmp", os.path.join(tempfile.gettempdir(), "farmcraft_fish_tex"))

# --- Species ------------------------------------------------------------------------
# L: length nose to tail tip (m). tail: tail fin share of L. H, W: greatest depth and
# width as a share of the body length. h/w: (share of the body where deepest/widest,
# nose roundness exponent (0.5 round .. 1 pointed), peduncle share of H/W). asym: share
# of the depth above the centre line. scales: scales along the lateral line (0 = none).
# gill: where the head ends. eye: (s, elevation, radius as share of H). colours sRGB.
# fins: dorsal/anal: (s0, s1, [(u, height as share of H)...], rake); pectoral/pelvic:
# (s, elevation, length share of H); adipose: (s0, s1, height).
FISH = {
    "fish_rudd": {
        "L": 0.24, "tail": 0.19, "H": 0.34, "W": 0.13, "h": (0.42, 0.55, 0.32), "w": (0.33, 0.5, 0.3), "asym": 0.56,
        "scales": 40, "edge": 0.22, "gill": 0.22, "eye": (0.085, 0.28, 0.2), "fork": 0.72, "tail_half": 0.2,
        "back": (0.27, 0.29, 0.17), "flank": (0.76, 0.7, 0.5), "belly": (0.92, 0.9, 0.82), "sheen": 0.14,
        "fin": (0.82, 0.2, 0.11), "fin_base": (0.7, 0.5, 0.35), "fin_d": (0.5, 0.25, 0.14), "iris": (0.86, 0.42, 0.12),
        "dorsal": [(0.5, 0.64, [(0, 0.55), (0.12, 0.75), (0.5, 0.45), (1, 0.18)], 0.45)],
        "anal": [(0.66, 0.79, [(0, 0.45), (0.15, 0.55), (1, 0.18)], 0.35)],
        "pectoral": (0.22, -0.45, 0.42), "pelvic": (0.47, -0.8, 0.4), "mark": "rudd",
    },
    "fish_crucian": {
        "L": 0.2, "tail": 0.18, "H": 0.46, "W": 0.17, "h": (0.42, 0.5, 0.38), "w": (0.33, 0.5, 0.33), "asym": 0.6,
        "scales": 32, "edge": 0.3, "gill": 0.23, "eye": (0.085, 0.3, 0.14), "fork": 0.35, "tail_half": 0.25,
        "back": (0.3, 0.27, 0.13), "flank": (0.66, 0.53, 0.26), "belly": (0.88, 0.8, 0.56), "sheen": 0.18,
        "fin": (0.45, 0.33, 0.2), "fin_base": (0.55, 0.42, 0.24), "fin_d": (0.34, 0.26, 0.16), "iris": (0.8, 0.62, 0.26),
        "dorsal": [(0.36, 0.78, [(0, 0.4), (0.1, 0.52), (0.4, 0.5), (1, 0.2)], 0.25)],
        "anal": [(0.72, 0.82, [(0, 0.4), (0.2, 0.42), (1, 0.18)], 0.3)],
        "pectoral": (0.23, -0.5, 0.35), "pelvic": (0.46, -0.85, 0.33), "mark": "gold",
    },
    "fish_perch": {
        "L": 0.25, "tail": 0.17, "H": 0.31, "W": 0.14, "h": (0.36, 0.62, 0.28), "w": (0.3, 0.55, 0.3), "asym": 0.6,
        "scales": 62, "edge": 0.18, "gill": 0.25, "eye": (0.1, 0.32, 0.22), "fork": 0.45, "tail_half": 0.2,
        "back": (0.2, 0.26, 0.11), "flank": (0.62, 0.62, 0.3), "belly": (0.92, 0.9, 0.78), "sheen": 0.1,
        "fin": (0.86, 0.36, 0.1), "fin_base": (0.75, 0.6, 0.3), "fin_d": (0.42, 0.44, 0.34), "iris": (0.88, 0.7, 0.2),
        "dorsal": [(0.27, 0.5, [(0, 0.35), (0.15, 0.8), (0.45, 0.7), (1, 0.22)], 0.5),
                   (0.53, 0.68, [(0, 0.5), (0.2, 0.55), (1, 0.2)], 0.35)],
        "anal": [(0.67, 0.77, [(0, 0.35), (0.2, 0.45), (1, 0.18)], 0.35)],
        "pectoral": (0.26, -0.3, 0.38), "pelvic": (0.3, -0.82, 0.42), "mark": "perch",
    },
    "fish_carp": {
        "L": 0.52, "tail": 0.19, "H": 0.35, "W": 0.15, "h": (0.4, 0.5, 0.34), "w": (0.32, 0.45, 0.32), "asym": 0.63,
        "scales": 36, "edge": 0.4, "gill": 0.22, "eye": (0.1, 0.24, 0.1), "fork": 0.55, "tail_half": 0.2,
        "back": (0.2, 0.2, 0.1), "flank": (0.64, 0.49, 0.22), "belly": (0.86, 0.76, 0.5), "sheen": 0.2,
        "fin": (0.42, 0.3, 0.2), "fin_base": (0.5, 0.38, 0.2), "fin_d": (0.3, 0.27, 0.2), "iris": (0.84, 0.64, 0.22),
        "dorsal": [(0.36, 0.77, [(0, 0.3), (0.06, 0.62), (0.25, 0.3), (1, 0.18)], 0.3)],
        "anal": [(0.73, 0.8, [(0, 0.3), (0.12, 0.5), (1, 0.18)], 0.3)],
        "pectoral": (0.23, -0.55, 0.36), "pelvic": (0.45, -0.85, 0.33), "barbels": [(0.022, 0.05), (0.03, 0.02)],
        "mark": "carp",
    },
    "fish_tench": {
        "L": 0.36, "tail": 0.17, "H": 0.27, "W": 0.15, "h": (0.4, 0.5, 0.46), "w": (0.33, 0.5, 0.4), "asym": 0.55,
        "scales": 100, "edge": 0.1, "gill": 0.23, "eye": (0.07, 0.3, 0.12), "fork": 0.02, "tail_half": 0.22,
        "back": (0.14, 0.17, 0.07), "flank": (0.36, 0.38, 0.13), "belly": (0.68, 0.62, 0.3), "sheen": 0.22,
        "fin": (0.16, 0.18, 0.09), "fin_base": (0.22, 0.24, 0.1), "fin_d": (0.16, 0.18, 0.09), "iris": (0.8, 0.12, 0.06),
        "dorsal": [(0.45, 0.59, [(0, 0.5), (0.3, 0.62), (0.8, 0.5), (1, 0.3)], 0.2)],
        "anal": [(0.66, 0.77, [(0, 0.4), (0.4, 0.45), (1, 0.3)], 0.2)],
        "pectoral": (0.23, -0.5, 0.38), "pelvic": (0.45, -0.85, 0.42), "barbels": [(0.012, 0.04)], "mark": "tench",
    },
    "fish_trout": {
        "L": 0.4, "tail": 0.15, "H": 0.23, "W": 0.12, "h": (0.42, 0.55, 0.3), "w": (0.34, 0.5, 0.32), "asym": 0.53,
        "scales": 120, "edge": 0.06, "gill": 0.22, "eye": (0.085, 0.3, 0.2), "fork": 0.2, "tail_half": 0.22,
        "back": (0.2, 0.26, 0.16), "flank": (0.74, 0.75, 0.7), "belly": (0.94, 0.93, 0.9), "sheen": 0.16,
        "fin": (0.48, 0.44, 0.36), "fin_base": (0.6, 0.58, 0.5), "fin_d": (0.34, 0.36, 0.28), "iris": (0.8, 0.72, 0.5),
        "dorsal": [(0.42, 0.55, [(0, 0.55), (0.15, 0.65), (1, 0.25)], 0.35)],
        "anal": [(0.7, 0.8, [(0, 0.5), (0.15, 0.55), (1, 0.2)], 0.35)],
        "adipose": (0.8, 0.86, 0.22),
        "pectoral": (0.22, -0.55, 0.42), "pelvic": (0.5, -0.85, 0.36), "mark": "trout",
    },
    "fish_zander": {
        "L": 0.55, "tail": 0.16, "H": 0.2, "W": 0.11, "h": (0.38, 0.62, 0.28), "w": (0.3, 0.55, 0.3), "asym": 0.52,
        "scales": 85, "edge": 0.1, "gill": 0.25, "eye": (0.085, 0.36, 0.26), "fork": 0.45, "tail_half": 0.22,
        "back": (0.24, 0.27, 0.23), "flank": (0.62, 0.64, 0.6), "belly": (0.93, 0.93, 0.9), "sheen": 0.14,
        "fin": (0.62, 0.62, 0.56), "fin_base": (0.6, 0.6, 0.55), "fin_d": (0.55, 0.56, 0.5), "iris": (0.85, 0.85, 0.8),
        "dorsal": [(0.28, 0.5, [(0, 0.5), (0.15, 0.95), (0.6, 0.8), (1, 0.3)], 0.45),
                   (0.54, 0.72, [(0, 0.6), (0.2, 0.7), (1, 0.3)], 0.35)],
        "anal": [(0.67, 0.79, [(0, 0.45), (0.2, 0.6), (1, 0.25)], 0.35)],
        "pectoral": (0.26, -0.45, 0.45), "pelvic": (0.3, -0.85, 0.5), "mark": "zander",
    },
    "fish_pike": {
        "L": 0.75, "tail": 0.14, "H": 0.16, "W": 0.1, "h": (0.58, 0.75, 0.38), "w": (0.4, 0.5, 0.35), "asym": 0.48,
        "scales": 115, "edge": 0.08, "gill": 0.27, "eye": (0.13, 0.42, 0.24), "fork": 0.35, "tail_half": 0.2,
        "back": (0.13, 0.19, 0.09), "flank": (0.32, 0.4, 0.17), "belly": (0.9, 0.88, 0.74), "sheen": 0.1,
        "fin": (0.52, 0.38, 0.18), "fin_base": (0.4, 0.4, 0.2), "fin_d": (0.5, 0.4, 0.2), "iris": (0.86, 0.72, 0.3),
        "dorsal": [(0.73, 0.86, [(0, 0.6), (0.3, 1.05), (1, 0.55)], 0.3)],
        "anal": [(0.74, 0.86, [(0, 0.55), (0.3, 0.95), (1, 0.5)], 0.3)],
        "pectoral": (0.28, -0.7, 0.55), "pelvic": (0.56, -0.9, 0.55), "mark": "pike",
    },
    "fish_catfish": {
        "L": 1.1, "tail": 0.1, "H": 0.16, "W": 0.16, "h": (0.3, 0.55, 0.28), "w": (0.16, 0.45, 0.2), "asym": 0.46,
        "scales": 0, "edge": 0.0, "gill": 0.2, "eye": (0.07, 0.36, 0.08), "fork": 0.0, "tail_half": 0.16,
        "back": (0.1, 0.11, 0.09), "flank": (0.3, 0.3, 0.25), "belly": (0.78, 0.75, 0.68), "sheen": 0.06,
        "fin": (0.2, 0.2, 0.17), "fin_base": (0.25, 0.25, 0.21), "fin_d": (0.16, 0.16, 0.14), "iris": (0.55, 0.5, 0.35),
        "dorsal": [(0.3, 0.35, [(0, 0.35), (0.3, 0.45), (1, 0.2)], 0.3)],
        "anal": [(0.45, 0.97, [(0, 0.12), (0.1, 0.3), (0.9, 0.3), (1, 0.25)], 0.15)],
        "pectoral": (0.18, -0.6, 0.55), "pelvic": (0.42, -0.9, 0.35),
        "barbels": [(0.26, 0.18), (0.05, 0.12), (0.05, 0.2)], "flat_head": True, "mark": "catfish",
    },
    # --- More of the lake's fish (the bait update). Optional keys: "pelvic": None (none),
    # "hetero" (tail lobes unequal: + upper longer, - lower longer), "mouth" (the mouth
    # line's height at the nose, -0.08 = the usual), "barbel_s" (where the barbels sit).
    "fish_roach": {
        "L": 0.22, "tail": 0.19, "H": 0.31, "W": 0.13, "h": (0.42, 0.55, 0.32), "w": (0.33, 0.5, 0.3), "asym": 0.55,
        "scales": 44, "edge": 0.2, "gill": 0.22, "eye": (0.09, 0.28, 0.24), "fork": 0.65, "tail_half": 0.2,
        "back": (0.16, 0.22, 0.27), "flank": (0.74, 0.76, 0.76), "belly": (0.93, 0.93, 0.9), "sheen": 0.2,
        "fin": (0.84, 0.3, 0.12), "fin_base": (0.66, 0.46, 0.36), "fin_d": (0.4, 0.3, 0.27), "iris": (0.86, 0.14, 0.07),
        "dorsal": [(0.45, 0.58, [(0, 0.55), (0.12, 0.72), (0.5, 0.45), (1, 0.18)], 0.4)],
        "anal": [(0.67, 0.79, [(0, 0.45), (0.15, 0.52), (1, 0.18)], 0.35)],
        "pectoral": (0.22, -0.45, 0.4), "pelvic": (0.46, -0.8, 0.4), "mark": "roach",
    },
    "fish_bleak": {
        "L": 0.15, "tail": 0.2, "H": 0.21, "W": 0.09, "h": (0.45, 0.6, 0.3), "w": (0.33, 0.5, 0.3), "asym": 0.42,
        "scales": 50, "edge": 0.1, "gill": 0.22, "eye": (0.085, 0.32, 0.3), "fork": 0.85, "tail_half": 0.22,
        "back": (0.16, 0.27, 0.26), "flank": (0.84, 0.86, 0.88), "belly": (0.95, 0.95, 0.94), "sheen": 0.28,
        "fin": (0.72, 0.72, 0.68), "fin_base": (0.7, 0.7, 0.66), "fin_d": (0.45, 0.47, 0.45), "iris": (0.85, 0.85, 0.8),
        "dorsal": [(0.55, 0.64, [(0, 0.5), (0.12, 0.6), (1, 0.18)], 0.4)],
        "anal": [(0.6, 0.8, [(0, 0.4), (0.12, 0.45), (1, 0.15)], 0.3)],
        "pectoral": (0.21, -0.55, 0.42), "pelvic": (0.44, -0.85, 0.38), "mouth": 0.1, "mark": "bleak",
    },
    "fish_gudgeon": {
        "L": 0.13, "tail": 0.18, "H": 0.19, "W": 0.15, "h": (0.36, 0.62, 0.36), "w": (0.3, 0.55, 0.36), "asym": 0.52,
        "scales": 40, "edge": 0.18, "gill": 0.24, "eye": (0.1, 0.42, 0.26), "fork": 0.5, "tail_half": 0.2,
        "back": (0.3, 0.27, 0.18), "flank": (0.64, 0.6, 0.46), "belly": (0.9, 0.88, 0.8), "sheen": 0.14,
        "fin": (0.62, 0.58, 0.46), "fin_base": (0.6, 0.55, 0.42), "fin_d": (0.55, 0.5, 0.38), "iris": (0.78, 0.7, 0.45),
        "dorsal": [(0.36, 0.5, [(0, 0.6), (0.15, 0.75), (1, 0.25)], 0.4)],
        "anal": [(0.66, 0.76, [(0, 0.45), (0.15, 0.5), (1, 0.2)], 0.35)],
        "pectoral": (0.24, -0.62, 0.45), "pelvic": (0.44, -0.9, 0.4), "barbels": [(0.07, 0.35)], "mouth": -0.2,
        "mark": "gudgeon",
    },
    "fish_bream": {
        "L": 0.42, "tail": 0.18, "H": 0.4, "W": 0.1, "h": (0.44, 0.82, 0.2), "w": (0.33, 0.6, 0.28), "asym": 0.56,
        "scales": 52, "edge": 0.22, "gill": 0.2, "eye": (0.08, 0.28, 0.12), "fork": 0.7, "tail_half": 0.26,
        "back": (0.2, 0.2, 0.15), "flank": (0.6, 0.51, 0.3), "belly": (0.86, 0.8, 0.62), "sheen": 0.22,
        "fin": (0.32, 0.3, 0.26), "fin_base": (0.4, 0.36, 0.28), "fin_d": (0.24, 0.24, 0.22), "iris": (0.82, 0.74, 0.5),
        "dorsal": [(0.42, 0.53, [(0, 0.6), (0.12, 0.8), (0.4, 0.5), (1, 0.18)], 0.35)],
        "anal": [(0.54, 0.9, [(0, 0.3), (0.08, 0.42), (0.5, 0.26), (1, 0.14)], 0.25)],
        "pectoral": (0.22, -0.62, 0.3), "pelvic": (0.42, -0.9, 0.26), "hetero": -0.3, "mouth": -0.2, "mark": "bream",
    },
    "fish_chub": {
        "L": 0.42, "tail": 0.17, "H": 0.23, "W": 0.16, "h": (0.38, 0.5, 0.36), "w": (0.3, 0.45, 0.36), "asym": 0.52,
        "scales": 44, "edge": 0.55, "gill": 0.25, "eye": (0.08, 0.3, 0.14), "fork": 0.35, "tail_half": 0.21,
        "back": (0.15, 0.18, 0.13), "flank": (0.66, 0.62, 0.48), "belly": (0.9, 0.88, 0.8), "sheen": 0.16,
        "fin": (0.86, 0.38, 0.14), "fin_base": (0.62, 0.46, 0.3), "fin_d": (0.2, 0.2, 0.18), "iris": (0.8, 0.66, 0.3),
        "dorsal": [(0.45, 0.57, [(0, 0.55), (0.12, 0.66), (1, 0.28)], 0.35)],
        "anal": [(0.66, 0.77, [(0, 0.45), (0.3, 0.6), (1, 0.35)], 0.25)],
        "pectoral": (0.24, -0.55, 0.36), "pelvic": (0.46, -0.85, 0.36), "mark": "chub",
    },
    "fish_barbel": {
        "L": 0.5, "tail": 0.16, "H": 0.19, "W": 0.15, "h": (0.38, 0.68, 0.34), "w": (0.32, 0.6, 0.34), "asym": 0.64,
        "scales": 72, "edge": 0.16, "gill": 0.23, "eye": (0.11, 0.42, 0.13), "fork": 0.55, "tail_half": 0.22,
        "back": (0.27, 0.24, 0.13), "flank": (0.6, 0.5, 0.28), "belly": (0.88, 0.82, 0.62), "sheen": 0.14,
        "fin": (0.64, 0.36, 0.18), "fin_base": (0.55, 0.42, 0.26), "fin_d": (0.36, 0.3, 0.2), "iris": (0.8, 0.68, 0.36),
        "dorsal": [(0.4, 0.52, [(0, 0.7), (0.12, 0.95), (1, 0.25)], 0.4)],
        "anal": [(0.72, 0.8, [(0, 0.55), (0.2, 0.65), (1, 0.25)], 0.35)],
        "pectoral": (0.25, -0.72, 0.42), "pelvic": (0.46, -0.92, 0.38), "barbels": [(0.07, 0.6), (0.09, 0.8)],
        "mouth": -0.3, "mark": "barbel",
    },
    "fish_eel": {
        "L": 0.75, "tail": 0.04, "H": 0.085, "W": 0.07, "h": (0.25, 0.6, 0.35), "w": (0.2, 0.6, 0.25), "asym": 0.5,
        "scales": 0, "edge": 0.0, "gill": 0.13, "eye": (0.045, 0.36, 0.2), "fork": 0.0, "tail_half": 0.06,
        "back": (0.11, 0.11, 0.06), "flank": (0.34, 0.32, 0.16), "belly": (0.8, 0.74, 0.46), "sheen": 0.08,
        "fin": (0.3, 0.29, 0.17), "fin_base": (0.24, 0.24, 0.14), "fin_d": (0.24, 0.23, 0.14), "iris": (0.72, 0.62, 0.3),
        "dorsal": [(0.36, 0.995, [(0, 0.04), (0.1, 0.22), (0.7, 0.42), (1, 0.52)], 0.02)],
        "anal": [(0.52, 0.995, [(0, 0.04), (0.1, 0.26), (1, 0.52)], 0.02)],
        "pectoral": (0.15, -0.05, 0.9), "pelvic": None, "ray_scale": 7, "mark": "eel",
    },
    "fish_grass_carp": {
        "L": 0.72, "tail": 0.17, "H": 0.2, "W": 0.15, "h": (0.42, 0.55, 0.38), "w": (0.33, 0.5, 0.36), "asym": 0.55,
        "scales": 44, "edge": 0.5, "gill": 0.21, "eye": (0.08, 0.12, 0.1), "fork": 0.45, "tail_half": 0.2,
        "back": (0.18, 0.2, 0.15), "flank": (0.56, 0.54, 0.4), "belly": (0.88, 0.86, 0.76), "sheen": 0.18,
        "fin": (0.34, 0.33, 0.28), "fin_base": (0.42, 0.4, 0.32), "fin_d": (0.26, 0.26, 0.22), "iris": (0.82, 0.72, 0.4),
        "dorsal": [(0.44, 0.56, [(0, 0.55), (0.1, 0.72), (1, 0.25)], 0.35)],
        "anal": [(0.7, 0.8, [(0, 0.45), (0.15, 0.55), (1, 0.2)], 0.35)],
        "pectoral": (0.22, -0.6, 0.38), "pelvic": (0.46, -0.88, 0.34), "mark": "grass_carp",
    },
    "fish_silver_carp": {
        "L": 0.66, "tail": 0.18, "H": 0.3, "W": 0.12, "h": (0.45, 0.52, 0.3), "w": (0.33, 0.5, 0.3), "asym": 0.52,
        "scales": 110, "edge": 0.06, "gill": 0.25, "eye": (0.1, -0.22, 0.1), "fork": 0.65, "tail_half": 0.24,
        "back": (0.28, 0.31, 0.29), "flank": (0.8, 0.82, 0.82), "belly": (0.94, 0.94, 0.93), "sheen": 0.24,
        "fin": (0.58, 0.58, 0.55), "fin_base": (0.62, 0.62, 0.6), "fin_d": (0.4, 0.42, 0.4), "iris": (0.84, 0.8, 0.6),
        "dorsal": [(0.47, 0.57, [(0, 0.5), (0.12, 0.65), (1, 0.2)], 0.35)],
        "anal": [(0.62, 0.84, [(0, 0.35), (0.1, 0.45), (1, 0.15)], 0.3)],
        "pectoral": (0.26, -0.7, 0.42), "pelvic": (0.45, -0.9, 0.34), "mouth": 0.2, "mark": "silver_carp",
    },
    "fish_brown_trout": {
        "L": 0.42, "tail": 0.15, "H": 0.23, "W": 0.12, "h": (0.42, 0.55, 0.32), "w": (0.34, 0.5, 0.32), "asym": 0.53,
        "scales": 120, "edge": 0.06, "gill": 0.23, "eye": (0.085, 0.32, 0.2), "fork": 0.08, "tail_half": 0.22,
        "back": (0.22, 0.2, 0.1), "flank": (0.72, 0.6, 0.34), "belly": (0.92, 0.86, 0.66), "sheen": 0.12,
        "fin": (0.56, 0.44, 0.26), "fin_base": (0.62, 0.52, 0.34), "fin_d": (0.4, 0.34, 0.22), "iris": (0.84, 0.7, 0.36),
        "dorsal": [(0.42, 0.55, [(0, 0.55), (0.15, 0.65), (1, 0.25)], 0.35)],
        "anal": [(0.7, 0.8, [(0, 0.5), (0.15, 0.55), (1, 0.2)], 0.35)],
        "adipose": (0.8, 0.86, 0.22),
        "pectoral": (0.22, -0.55, 0.42), "pelvic": (0.5, -0.85, 0.36), "mark": "brown_trout",
    },
    # Mersin balığı: the pond's legend, a sturgeon from the old river days: a shovel snout
    # with four barbels, rows of bony plates, the upper tail lobe long.
    "fish_sturgeon": {
        "L": 1.3, "tail": 0.17, "H": 0.14, "W": 0.15, "h": (0.38, 0.95, 0.2), "w": (0.32, 0.85, 0.24), "asym": 0.56,
        "scales": 0, "edge": 0.0, "gill": 0.23, "eye": (0.16, 0.42, 0.12), "fork": 0.55, "tail_half": 0.2,
        "back": (0.24, 0.24, 0.2), "flank": (0.47, 0.46, 0.4), "belly": (0.86, 0.85, 0.8), "sheen": 0.05,
        "fin": (0.36, 0.34, 0.29), "fin_base": (0.42, 0.4, 0.34), "fin_d": (0.3, 0.3, 0.26), "iris": (0.62, 0.56, 0.4),
        "dorsal": [(0.72, 0.85, [(0, 0.35), (0.2, 1.0), (1, 0.3)], 0.45)],
        "anal": [(0.77, 0.87, [(0, 0.35), (0.2, 0.85), (1, 0.3)], 0.4)],
        "pectoral": (0.21, -0.72, 0.95), "pelvic": (0.64, -0.88, 0.5),
        "barbels": [(0.035, 0.9), (0.035, 0.9)], "barbel_s": 0.07, "flat_head": True, "hetero": 0.38, "mouth": -0.35,
        "mark": "sturgeon",
    },
}


# --- Small helpers --------------------------------------------------------------------

def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def value_noise(nv, nu, cv, cu, rng):
    """Value noise over an (nv, nu) image from a (cv, cu) grid, periodic along v (rows)."""
    g = rng.random((cv, cu + 1)).astype(np.float32)
    v = np.arange(nv) * cv / nv
    u = np.arange(nu) * cu / max(nu - 1, 1)
    v0 = np.floor(v).astype(int)
    fv = v - v0
    v1 = (v0 + 1) % cv
    u0 = np.minimum(np.floor(u).astype(int), cu - 1)
    fu = u - u0
    u1 = u0 + 1
    fv = (fv * fv * (3 - 2 * fv))[:, None]
    fu = (fu * fu * (3 - 2 * fu))[None, :]
    a = g[v0][:, u0]
    b = g[v0][:, u1]
    c = g[v1][:, u0]
    d = g[v1][:, u1]
    return (a * (1 - fu) + b * fu) * (1 - fv) + (c * (1 - fu) + d * fu) * fv


def fbm(nv, nu, cv, cu, rng, octaves=4):
    out = np.zeros((nv, nu), np.float32)
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        out += value_noise(nv, nu, cv * 2 ** o, cu * 2 ** o, rng) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def mix(a, b, t):
    return a + (b - a) * t[..., None]


def rgb(c):
    return np.array(c, np.float32)


def normal_from_height(h, strength):
    dv, du = np.gradient(h)
    n = np.stack([-du * strength, -dv * strength, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def save_image(name, arr, non_color=False):
    """arr: (rows, cols, 3) floats 0..1, row 0 at v = 0. Saved as PNG and loaded."""
    os.makedirs(TMP, exist_ok=True)
    h, w = arr.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    rgba = np.ones((h, w, 4), np.float32)
    rgba[..., :3] = np.clip(arr, 0.0, 1.0)
    img.pixels.foreach_set(rgba.ravel())
    path = os.path.join(TMP, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    img = bpy.data.images.load(path)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def material(name, color=None, image=None, normal=None, rough=0.4, metal=0.0, double=False, spec=0.5, coat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = not double
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = spec
    if coat > 0.0 and "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
    if image is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    elif color is not None:
        bsdf.inputs["Base Color"].default_value = (*srgb_to_linear(color), 1.0)
    if normal is not None:
        nt_tex = nt.nodes.new("ShaderNodeTexImage")
        nt_tex.image = normal
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nt_tex.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def srgb_to_linear(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


class Builder:
    """One bmesh with material slots and a UV layer."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []

    def slot(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def face(self, verts, uvs, mat):
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        f.material_index = self.slot(mat)
        f.smooth = True
        for loop, uv in zip(f.loops, uvs):
            loop[self.uv].uv = uv
        return f

    def grid(self, pts, mat, closed_u=False):
        """pts[i][j]: rows i along u, columns j along v; UV (u, v) over 0..1."""
        nu = len(pts)
        nv = len(pts[0])
        vs = [[self.bm.verts.new(p) for p in row] for row in pts]
        for i in range(nu - 1):
            for j in range(nv - 1):
                u0, u1 = i / (nu - 1), (i + 1) / (nu - 1)
                v0, v1 = j / (nv - 1), (j + 1) / (nv - 1)
                self.face([vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]],
                          [(u0, v0), (u1, v0), (u1, v1), (u0, v1)], mat)
        return vs

    def tube(self, pts, radii, mat, segs=6, color_v=0.5):
        rings = []
        for k, p in enumerate(pts):
            d = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
            a = d.orthogonal().normalized()
            b = d.cross(a).normalized()
            ring = []
            for s in range(segs):
                t = 2 * math.pi * s / segs
                ring.append(self.bm.verts.new(p + (a * math.cos(t) + b * math.sin(t)) * radii[k]))
            rings.append(ring)
        for k in range(len(rings) - 1):
            for s in range(segs):
                s1 = (s + 1) % segs
                self.face([rings[k][s], rings[k + 1][s], rings[k + 1][s1], rings[k][s1]],
                          [(0.5, color_v)] * 4, mat)
        tip = self.bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1])
        for s in range(segs):
            self.face([rings[-1][s], tip, rings[-1][(s + 1) % segs]], [(0.5, color_v)] * 3, mat)

    def sphere(self, center, radii, mat, rot=Matrix.Identity(3), segs=16, rings=10, uv_region=None):
        m = Matrix.Translation(center) @ rot.to_4x4() @ Matrix.Diagonal((*radii, 1.0))
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=segs, v_segments=rings, radius=1.0, matrix=m,
                                        calc_uvs=True)
        idx = self.slot(mat)
        for v in res["verts"]:
            for f in v.link_faces:
                f.material_index = idx
                f.smooth = True
        return res["verts"]

    def cone(self, a, b, r0, r1, mat, segs=12):
        d = b - a
        length = d.length
        rot = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        m = Matrix.Translation((a + b) * 0.5) @ rot
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r0,
                                    radius2=r1, depth=length, matrix=m, calc_uvs=True)
        idx = self.slot(mat)
        for v in res["verts"]:
            for f in v.link_faces:
                f.material_index = idx
                f.smooth = True
        return res["verts"]

    def to_object(self, name):
        me = bpy.data.meshes.new(name)
        bmesh.ops.triangulate(self.bm, faces=[f for f in self.bm.faces if len(f.verts) > 4])
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def export(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path = os.path.join(OUT, name + ".gltf")
    # Textures go to one shared folder (a raw fish and its cooked one share their normal
    # maps).
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", export_texture_dir="textures",
                              use_selection=True, export_yup=True, export_apply=True, export_image_format="JPEG",
                              export_jpeg_quality=90, export_tangents=True, export_materials="EXPORT")
    print("wrote", path, os.path.getsize(path) // 1024, "KB")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# --- Fish body --------------------------------------------------------------------------

class Body:
    """The fish's shape as functions of s (0 nose .. 1 tail root) and theta (around)."""

    def __init__(self, cfg):
        self.c = cfg
        self.L = cfg["L"]
        self.Lt = cfg["L"] * cfg["tail"]
        self.Lb = cfg["L"] - self.Lt
        self.H = cfg["H"] * self.Lb
        self.W = cfg["W"] * self.Lb
        self.x_nose = self.L * 0.5

    @staticmethod
    def _profile(s, peak, nose, ped):
        if s <= peak:
            t = min(max(s / peak, 0.0), 1.0)
            return (1.0 - (1.0 - t) ** 2) ** nose
        t = (s - peak) / (1.0 - peak)
        return ped + (1.0 - ped) * (0.5 + 0.5 * math.cos(math.pi * t)) ** 1.1

    def depth(self, s):
        return self.H * self._profile(s, *self.c["h"])

    def width(self, s):
        w = self.W * self._profile(s, *self.c["w"])
        if self.c.get("flat_head") and s < 0.3:
            # The catfish's broad, flat head.
            w *= 1.0 + 0.35 * (1.0 - s / 0.3)
        return w

    def x(self, s):
        return self.x_nose - s * self.Lb

    def point(self, s, theta):
        d = self.depth(s)
        w = self.width(s) * 0.5
        a = self.c["asym"]
        top = d * a
        bot = d * (1.0 - a)
        ct = math.cos(theta)
        st = math.sin(theta)
        n = 2.5
        y = w * math.copysign(abs(ct) ** (2.0 / n), ct)
        # Narrower toward the dorsal ridge, a little toward the keel.
        y *= 1.0 - 0.32 * max(st, 0.0) ** 2 - 0.1 * max(-st, 0.0) ** 3
        z = (top if st > 0 else bot) * math.copysign(abs(st) ** (2.0 / n), st)
        return Vector((self.x(s), y, z))

    def ridge(self, s, up=True):
        return self.point(s, math.pi * 0.5 if up else -math.pi * 0.5)


def body_mesh(b, body, mat, ns=72, nt=48):
    ss = [(1.0 - math.cos(math.pi * i / ns)) * 0.5 for i in range(ns + 1)]
    ss[0] = 0.006
    rings = []
    for s in ss:
        rings.append([b.bm.verts.new(body.point(s, -math.pi * 0.5 + 2 * math.pi * j / nt)) for j in range(nt)])
    for i in range(ns):
        for j in range(nt):
            j1 = (j + 1) % nt
            v0 = j / nt
            v1 = (j + 1) / nt
            # The face is wound so its normal points out of the body.
            b.face([rings[i][j], rings[i][j1], rings[i + 1][j1], rings[i + 1][j]],
                   [(ss[i], v0), (ss[i], v1), (ss[i + 1], v1), (ss[i + 1], v0)], mat)
    nose = b.bm.verts.new(Vector((body.x(0.0) + 0.002, 0.0, body.ridge(0.006).z * 0.2)))
    for j in range(nt):
        j1 = (j + 1) % nt
        b.face([rings[0][j1], rings[0][j], nose], [(0.006, (j + 1) / nt), (0.006, j / nt), (0.0, (j + 0.5) / nt)], mat)
    tail = b.bm.verts.new(Vector((body.x(1.0) - 0.001, 0.0, 0.0)))
    for j in range(nt):
        j1 = (j + 1) % nt
        b.face([rings[ns][j], rings[ns][j1], tail], [(1.0, j / nt), (1.0, (j + 1) / nt), (1.0, (j + 0.5) / nt)], mat)


def ridge_fin(b, body, s0, s1, heights, rake, up, mat, nu=14, nv=5, billow=0.02):
    us, hs = zip(*heights)
    if s1 - s0 > 0.55:
        # A fin along most of the body (the eel's): more rows so it follows the curve.
        nu = int((s1 - s0) * 60)
    pts = []
    for i in range(nu + 1):
        u = i / nu
        s = s0 + (s1 - s0) * u
        base = body.ridge(s, up)
        base.z -= 0.004 * (1 if up else -1) * body.L
        h = float(np.interp(u, us, hs)) * body.H
        tip = base + Vector((-rake * h, 0.0, h if up else -h))
        row = []
        for j in range(nv + 1):
            v = j / nv
            p = base.lerp(tip, v)
            p.y += math.sin(math.pi * v) * billow * h * math.sin(i * 1.7)
            row.append(p)
        pts.append(row)
    b.grid(pts, mat)


def tail_fin(b, body, mat, nu=16, nv=8):
    c = body.c
    s = 1.0
    x0 = body.x(s)
    hp = body.depth(s) * 0.45
    th = c["tail_half"] * body.Lb
    fork = c["fork"]
    pts = []
    for i in range(nu + 1):
        u = i / nu
        k = abs(2 * u - 1)
        rounded = 0.72 + 0.28 * math.sqrt(max(1.0 - k * k, 0.0))
        forked = 0.5 + 0.5 * k ** 1.4
        ext = body.Lt * ((1 - fork) * rounded + fork * forked)
        base = Vector((x0 + 0.004 * body.L, 0.0, (2 * u - 1) * hp))
        tip = Vector((x0 - ext, 0.0, (2 * u - 1) * th))
        het = c.get("hetero", 0.0)
        if het != 0.0:
            # Unequal lobes: the sturgeon's long upper lobe sweeping up, the bream's lower.
            side = 2 * u - 1
            ext *= 1.0 + het * side * k
            tip = Vector((x0 - ext, 0.0, side * th * (1.0 + 0.5 * het * side) + het * th * 0.3))
        row = []
        for j in range(nv + 1):
            v = j / nv
            p = base.lerp(tip, v)
            p.y += math.sin(math.pi * v) * 0.012 * body.Lt * math.sin(i * 1.9)
            row.append(p)
        pts.append(row)
    b.grid(pts, mat)


def paired_fin(b, body, s, elev, length, mat, spread, back, down, nu=8, nv=5):
    """A fin pair on the flanks (pectoral) or under the belly (pelvic): a fan from a
    short root, raked back."""
    for side in (1, -1):
        theta = math.asin(max(min(elev, 1.0), -1.0))
        if side < 0:
            theta = math.pi - theta
        root0 = body.point(s, theta)
        root1 = body.point(s + 0.035, theta)
        out = Vector((0.0, side, 0.0))
        pts = []
        L = length * body.H
        for i in range(nu + 1):
            u = i / nu
            base = root0.lerp(root1, u)
            base -= Vector((0.0, side * 0.002 * body.L, 0.0))
            ang = (u - 0.5) * spread
            d = Vector((-back, 0.0, -down)).normalized()
            d = (d + out * 0.55 + Vector((0, 0, 1)) * ang * 0.3).normalized()
            lu = L * (0.6 + 0.4 * math.sin(math.pi * min(u * 1.15, 1.0)))
            tip = base + d * lu
            row = []
            for j in range(nv + 1):
                v = j / nv
                row.append(base.lerp(tip, v))
            pts.append(row)
        if side < 0:
            pts = pts[::-1]
        b.grid(pts, mat)


def eyes(b, body, cfg, iris, pupil):
    s, elev, r = cfg["eye"]
    # Set flush in the head: a flattened ball, most of it a big dark pupil ringed by the iris.
    r *= body.H * 0.62
    for side in (1, -1):
        theta = math.asin(elev)
        if side < 0:
            theta = math.pi - theta
        p = body.point(s, theta)
        n = Vector((0.0, side, 0.2 * elev)).normalized()
        rot = n.to_track_quat("Z", "X").to_matrix()
        c = p - n * r * 0.3
        b.sphere(c, (r, r, r * 0.42), iris, rot, segs=16, rings=8)
        b.sphere(c + n * r * 0.1, (r * 0.64, r * 0.64, r * 0.36), pupil, rot, segs=14, rings=6)


def barbels(b, body, cfg, mat):
    if "barbel_s" in cfg:
        # A row of barbels hanging under the snout (the sturgeon's four).
        bs = cfg["barbel_s"]
        for k, (length, low) in enumerate(cfg["barbels"]):
            L = length * body.L
            for side in (1, -1):
                base = body.point(bs, -math.pi * 0.5 + side * (0.25 + 0.45 * k))
                pts = []
                radii = []
                n = 7
                for i in range(n + 1):
                    t = i / n
                    pts.append(base + Vector((-0.25 * L * t, side * 0.15 * L * t, -low * L * t)))
                    radii.append(max(0.0035 * body.L * (1.0 - 0.7 * t), 0.0007))
                b.tube(pts, radii, mat, segs=6)
        return
    for k, (length, low) in enumerate(cfg.get("barbels", [])):
        L = length * body.L
        for side in (1, -1):
            s = 0.02 + 0.015 * k
            base = body.point(s, math.pi - 0.25 if side < 0 else 0.25) if k == 0 else body.point(
                s + 0.02, -math.pi * 0.5 + side * 0.5)
            base.z -= low * body.H * 0.3
            pts = []
            radii = []
            n = 7
            for i in range(n + 1):
                t = i / n
                p = base + Vector((-0.35 * L * t, side * 0.5 * L * t, -0.45 * L * t * t - 0.1 * L * t))
                pts.append(p)
                radii.append(max(0.0035 * body.L * (1.0 - 0.8 * t), 0.0006))
            b.tube(pts, radii, mat, segs=6)


# --- Fish textures ------------------------------------------------------------------------

def body_texture(key, cfg, rng, nu=1024, nv=512):
    """Albedo, height (for the normal map) and a 'cooked' albedo of the body."""
    S = np.linspace(0.0, 1.0, nu, dtype=np.float32)[None, :].repeat(nv, 0)
    V = (np.arange(nv, dtype=np.float32) / nv)[:, None].repeat(nu, 1)
    TH = V * 2 * np.pi - np.pi * 0.5
    E = np.sin(TH)
    noise = fbm(nv, nu, 6, 12, rng, 5)
    noise2 = fbm(nv, nu, 10, 30, rng, 4)
    back, flank, belly = rgb(cfg["back"]), rgb(cfg["flank"]), rgb(cfg["belly"])
    # Countershading: dark back, the flank's colour, a pale belly; the line between back
    # and flank wanders a little.
    e_back = E + (noise - 0.5) * 0.25
    col = mix(np.broadcast_to(belly, (nv, nu, 3)), np.broadcast_to(flank, (nv, nu, 3)), smooth(-0.75, -0.1, E))
    col = mix(col, np.broadcast_to(back, (nv, nu, 3)), smooth(0.25, 0.85, e_back))
    # Toward the tail the back colour reaches lower.
    col = mix(col, np.broadcast_to(back, (nv, nu, 3)), smooth(0.8, 1.0, S) * smooth(-0.2, 0.5, E) * 0.35)
    height = np.zeros((nv, nu), np.float32)
    gill = cfg["gill"]
    head = 1.0 - smooth(gill - 0.01, gill + 0.02, S)
    N = cfg["scales"]
    if N > 0:
        L = cfg["L"] * (1 - cfg["tail"])
        circ = math.pi * (cfg["H"] + cfg["W"]) * 0.5
        R = max(int(round(N * circ)), 8)
        a = S * N
        bb = V * R
        row = np.floor(bb)
        fb = bb - row
        a2 = a + 0.5 * (row % 2)
        arc = 0.38 * (1.0 - (2 * fb - 1) ** 2)
        ph = np.mod(a2 - arc, 1.0)
        h = np.where(ph < 0.92, ph / 0.92, (1.0 - ph) / 0.08)
        scale_mask = (1.0 - head) * (1.0 - smooth(0.985, 1.0, S) * 0.5)
        height += h * scale_mask
        edge = np.exp(-(ph / 0.09) ** 2) * scale_mask
        col *= (1.0 - cfg["edge"] * edge)[..., None]
        # A sheen across each scale's middle (the flank catches the light).
        sheen = np.sin(np.pi * ph) * cfg["sheen"] * scale_mask * smooth(-0.6, 0.2, E) * (1.0 - smooth(0.4, 0.9, E))
        col *= (1.0 + sheen)[..., None]
        # Lateral line: a row of pores along the flank, arching over the pectoral fin.
        lat = 0.18 - 0.2 * S + 0.12 * np.exp(-((S - 0.25) / 0.2) ** 2)
        pores = np.exp(-((E - lat) / 0.012) ** 2) * (0.5 + 0.5 * np.cos(2 * np.pi * a)) * scale_mask
        col *= (1.0 - 0.35 * pores)[..., None]
    else:
        # Smooth, slimy skin: fine wrinkles.
        height += (noise2 - 0.5) * 0.6
    # Head: smooth skin, the gill cover's edge and the mouth.
    op = gill - 0.015 + 0.03 * (1.0 - E * E)
    gill_line = np.exp(-((S - op) / 0.004) ** 2) * (np.abs(E) < 0.85)
    col *= (1.0 - 0.45 * gill_line)[..., None]
    height -= gill_line * 0.6
    col = mix(col, col * np.array([1.05, 1.0, 0.92], np.float32), head * 0.5)
    mouth = np.exp(-((E - (cfg.get("mouth", -0.08) - 0.9 * S)) / 0.035) ** 2) * (1.0 - smooth(0.035, 0.06, S))
    col *= (1.0 - 0.7 * mouth)[..., None]
    col = markings(cfg, rng, col, S, E, noise, nv, nu)
    if cfg["mark"] == "sturgeon":
        plates, _ = scutes(S, nv, nu)
        col = mix(col, np.broadcast_to(rgb((0.74, 0.72, 0.64)), col.shape), plates * 0.7)
        height += plates * 0.9 + (fbm(nv, nu, 40, 120, rng, 2) - 0.5) * 0.25
    # Photo-like unevenness; a wet fish's colours are deep (the sun on the bank would
    # bleach lighter albedo).
    col *= (0.9 + 0.2 * noise2)[..., None]
    grey = col.mean(axis=-1, keepdims=True)
    col = np.clip(grey + (col - grey) * 1.25, 0.0, 1.0) * 0.8
    height += (noise2 - 0.5) * 0.08
    cooked = cook(col, S, E, rng, nv, nu)
    return col, height, cooked


def spots(rng, S, E, count, s_range, e_range, size, stretch=1.0):
    mask = np.zeros_like(S)
    nv, nu = S.shape
    for _ in range(count):
        s0 = rng.uniform(*s_range)
        e0 = rng.uniform(*e_range)
        r = size * rng.uniform(0.7, 1.3)
        i0 = max(int((s0 - r * stretch * 3) * nu), 0)
        i1 = min(int((s0 + r * stretch * 3) * nu) + 1, nu)
        th = math.asin(max(min(e0, 1.0), -1.0))
        for th0 in (th, math.pi - th):
            v0 = (th0 + math.pi * 0.5) / (2 * math.pi)
            j0 = max(int((v0 - r * 3) * nv), 0)
            j1 = min(int((v0 + r * 3) * nv) + 1, nv)
            if i1 <= i0 or j1 <= j0:
                continue
            ss = S[j0:j1, i0:i1]
            vv = (np.arange(j0, j1) / nv)[:, None]
            d = ((ss - s0) / stretch) ** 2 + (vv - v0) ** 2 * 0.25
            mask[j0:j1, i0:i1] = np.maximum(mask[j0:j1, i0:i1], np.exp(-d / (r * r) * 2.0))
    return mask


def markings(cfg, rng, col, S, E, noise, nv, nu):
    kind = cfg["mark"]
    body = smooth(0.18, 0.25, S)
    if kind == "perch":
        bars = np.zeros_like(S)
        for k, s0 in enumerate(np.linspace(0.3, 0.9, 6)):
            w = 0.022 if k % 2 == 0 else 0.016
            bars = np.maximum(bars, np.exp(-((S + 0.03 * E - s0) / w) ** 2))
        bars *= smooth(-0.55, 0.05, E + (noise - 0.5) * 0.3)
        col = mix(col, col * np.array([0.3, 0.33, 0.25], np.float32), bars * 0.85)
        col = mix(col, col * np.array([1.08, 1.05, 0.8], np.float32), smooth(-0.3, 0.2, E) * (1 - smooth(0.2, 0.6, E)) * 0.4)
    elif kind == "zander":
        bars = np.zeros_like(S)
        for s0 in np.linspace(0.3, 0.92, 9):
            bars = np.maximum(bars, np.exp(-((S + 0.02 * E - s0) / 0.018) ** 2))
        bars *= smooth(-0.2, 0.3, E) * (0.5 + noise)
        col = mix(col, col * 0.55, bars * 0.6 * body)
    elif kind == "pike":
        m = spots(rng, S, E, 260, (0.2, 0.97), (-0.35, 0.8), 0.011, 1.8)
        m *= body
        col = mix(col, np.broadcast_to(rgb((0.72, 0.7, 0.42)), col.shape), np.clip(m * 1.4, 0, 1) * 0.85)
    elif kind == "trout":
        band = np.exp(-((E - 0.02 + 0.05 * S) / 0.2) ** 2) * smooth(0.12, 0.25, S)
        col = mix(col, np.broadcast_to(rgb((0.84, 0.42, 0.44)), col.shape), band * 0.65)
        m = spots(rng, S, E, 380, (0.05, 1.0), (-0.15, 1.0), 0.0045, 1.0)
        col = mix(col, np.broadcast_to(rgb((0.06, 0.06, 0.05)), col.shape), np.clip(m * 1.8, 0, 1) * 0.9)
    elif kind == "catfish":
        marble = fbm(nv, nu, 8, 26, rng, 5)
        dark = smooth(0.5, 0.62, marble) * smooth(-0.6, 0.0, E)
        col = mix(col, col * 0.45, dark * 0.8)
        light = smooth(0.55, 0.7, fbm(nv, nu, 12, 40, rng, 4)) * smooth(-0.2, 0.3, E) * (1 - smooth(0.6, 0.9, E))
        col = mix(col, col * 1.35, light * 0.4)
    elif kind == "carp":
        col = mix(col, col * np.array([1.1, 1.0, 0.75], np.float32), smooth(-0.4, 0.1, E) * (1 - smooth(0.2, 0.6, E)) * 0.5)
    elif kind == "rudd":
        col = mix(col, col * np.array([1.08, 1.04, 0.86], np.float32), smooth(-0.5, 0.0, E) * (1 - smooth(0.1, 0.5, E)) * 0.5)
    elif kind == "tench":
        col = mix(col, col * np.array([1.15, 1.08, 0.7], np.float32), smooth(-0.7, -0.1, E) * (1 - smooth(0.1, 0.5, E)) * 0.45)
    elif kind == "roach":
        # A blue-steel sheen along the upper flank.
        col = mix(col, col * np.array([0.88, 1.0, 1.14], np.float32), smooth(0.05, 0.45, E) * (1 - smooth(0.6, 0.9, E)) * 0.55)
    elif kind == "bleak":
        # Mirror-bright flanks, a green-blue line along the back.
        col = mix(col, col * np.array([1.02, 1.06, 1.08], np.float32), smooth(-0.4, 0.3, E) * (1 - smooth(0.4, 0.7, E)) * 0.5)
        col = mix(col, col * np.array([0.7, 1.05, 1.0], np.float32), np.exp(-((E - 0.55) / 0.08) ** 2) * body * 0.5)
    elif kind == "gudgeon":
        # A row of dark blotches along the lateral line, the back freckled.
        blot = np.zeros_like(S)
        for s0 in np.linspace(0.26, 0.95, 9):
            blot = np.maximum(blot, np.exp(-(((S - s0) / 0.022) ** 2 + ((E - 0.0) / 0.13) ** 2)))
        col = mix(col, col * 0.32, blot * 0.8 * body)
        m = spots(rng, S, E, 240, (0.05, 1.0), (0.15, 1.0), 0.004, 1.0)
        col = mix(col, col * 0.45, np.clip(m * 1.4, 0, 1) * 0.7)
    elif kind == "bream":
        # Old bronze: the flank warms toward gold, the back goes lead-grey.
        col = mix(col, col * np.array([1.12, 1.0, 0.78], np.float32), smooth(-0.5, 0.2, E) * (1 - smooth(0.3, 0.7, E)) * 0.55)
    elif kind == "chub":
        col = mix(col, col * np.array([1.08, 1.02, 0.86], np.float32), smooth(-0.4, 0.1, E) * (1 - smooth(0.2, 0.6, E)) * 0.4)
    elif kind == "barbel":
        m = spots(rng, S, E, 320, (0.05, 1.0), (0.05, 1.0), 0.0035, 1.2)
        col = mix(col, col * 0.4, np.clip(m * 1.3, 0, 1) * 0.65)
        col = mix(col, col * np.array([1.1, 1.02, 0.8], np.float32), smooth(-0.5, 0.0, E) * (1 - smooth(0.1, 0.5, E)) * 0.4)
    elif kind == "eel":
        marble = fbm(nv, nu, 6, 40, rng, 5)
        col = mix(col, col * 0.62, smooth(0.45, 0.65, marble) * smooth(-0.1, 0.5, E) * 0.6)
        col = mix(col, col * np.array([1.1, 1.05, 0.7], np.float32), smooth(-0.9, -0.4, E) * 0.4)
    elif kind == "grass_carp":
        col = mix(col, col * np.array([1.06, 1.04, 0.84], np.float32), smooth(-0.5, 0.0, E) * (1 - smooth(0.1, 0.5, E)) * 0.45)
    elif kind == "silver_carp":
        col = mix(col, col * np.array([0.95, 1.02, 1.08], np.float32), smooth(-0.3, 0.4, E) * 0.35)
    elif kind == "brown_trout":
        # Black spots over the back and upper flank; red ones with pale haloes along the
        # lateral line.
        m = spots(rng, S, E, 260, (0.05, 0.98), (-0.1, 1.0), 0.0055, 1.0)
        col = mix(col, np.broadcast_to(rgb((0.07, 0.05, 0.04)), col.shape), np.clip(m * 1.6, 0, 1) * 0.85)
        centers = [(rng.uniform(0.2, 0.95), rng.uniform(-0.3, 0.3)) for _ in range(46)]
        halo = spots_from(S, E, centers, 0.011)
        red = spots_from(S, E, centers, 0.0055)
        col = mix(col, np.broadcast_to(rgb((0.9, 0.84, 0.7)), col.shape), np.clip(halo * 1.3, 0, 1) * 0.7 * body)
        col = mix(col, np.broadcast_to(rgb((0.72, 0.12, 0.06)), col.shape), np.clip(red * 1.8, 0, 1) * 0.9 * body)
    return col


def spots_from(S, E, centers, size, stretch=1.0):
    """Round spots at given (s, e) centres (spots() picks its own)."""
    mask = np.zeros_like(S)
    nv, nu = S.shape
    for s0, e0 in centers:
        i0 = max(int((s0 - size * stretch * 3) * nu), 0)
        i1 = min(int((s0 + size * stretch * 3) * nu) + 1, nu)
        th = math.asin(max(min(e0, 1.0), -1.0))
        for th0 in (th, math.pi - th):
            v0 = (th0 + math.pi * 0.5) / (2 * math.pi)
            j0 = max(int((v0 - size * 3) * nv), 0)
            j1 = min(int((v0 + size * 3) * nv) + 1, nv)
            if i1 <= i0 or j1 <= j0:
                continue
            ss = S[j0:j1, i0:i1]
            vv = (np.arange(j0, j1) / nv)[:, None]
            d = ((ss - s0) / stretch) ** 2 + (vv - v0) ** 2 * 0.25
            mask[j0:j1, i0:i1] = np.maximum(mask[j0:j1, i0:i1], np.exp(-d / (size * size) * 2.0))
    return mask


def scutes(S, nv, nu):
    """The sturgeon's five rows of bony plates (a mask 0..1, and the rows' angles):
    one along the back, one down each flank, two along the belly."""
    V = (np.arange(nv, dtype=np.float32) / nv)[:, None].repeat(nu, 1)
    TH = V * 2 * np.pi - np.pi * 0.5
    rows = [(math.pi * 0.5, 0.22, 0.26, 0.72, 13), (0.0, 0.11, 0.22, 0.98, 36), (math.pi, 0.11, 0.22, 0.98, 36),
            (-math.pi * 0.5 + 0.6, 0.12, 0.26, 0.64, 11), (-math.pi * 0.5 - 0.6, 0.12, 0.26, 0.64, 11)]
    out = np.zeros_like(S)
    for a, w, s_a, s_b, n in rows:
        d_th = np.abs(np.arctan2(np.sin(TH - a), np.cos(TH - a))) / w
        ph = (S - s_a) / (s_b - s_a) * n
        f = np.abs(np.mod(ph, 1.0) - 0.5) / 0.42
        inside = smooth(-0.02, 0.0, (S - s_a)) * (1.0 - smooth(0.0, 0.02, S - s_b))
        # A diamond with a raised keel down its middle.
        dist = f + d_th
        plate = (1.0 - smooth(0.7, 1.0, dist)) * inside
        keel = np.exp(-(d_th / 0.18) ** 2) * plate * 0.4
        out = np.maximum(out, plate * 0.8 + keel)
    return np.clip(out, 0.0, 1.0), rows


def cook(raw, S, E, rng, nv, nu):
    """The grilled skin: golden to dark brown, the scales still showing, char marks."""
    lum = raw.mean(axis=-1)
    lum = (lum - lum.mean()) / (lum.std() + 1e-5)
    n = fbm(nv, nu, 8, 20, rng, 5)
    roast = smooth(0.25, 0.95, n + 0.25 * smooth(0.3, 0.9, E) + 0.2 * smooth(0.85, 1.0, S) + 0.25 * (1 - smooth(0.0, 0.08, S)))
    golden = rgb((0.72, 0.5, 0.26))
    brown = rgb((0.36, 0.2, 0.09))
    col = mix(np.broadcast_to(golden, raw.shape), np.broadcast_to(brown, raw.shape), roast)
    col *= (1.0 + 0.1 * np.clip(lum, -2, 2))[..., None]
    # Grill bars across the flank.
    bars = np.mod(S * 7.0 + E * 0.35, 1.0)
    char = np.exp(-((bars - 0.5) / 0.022) ** 2) * smooth(-0.75, -0.2, E) * (1 - smooth(0.6, 0.9, E))
    char *= 0.6 + 0.4 * fbm(nv, nu, 10, 40, rng, 3)
    col = mix(col, np.broadcast_to(rgb((0.07, 0.045, 0.03)), raw.shape), np.clip(char, 0, 1) * 0.75)
    # Blistered, flaking skin.
    blister = smooth(0.62, 0.7, fbm(nv, nu, 14, 50, rng, 3))
    col = mix(col, col * 1.25, blister * 0.4)
    return col


def fin_texture(cfg, rng, kind, cooked=False, nu=512, nv=256):
    U = np.linspace(0.0, 1.0, nu, dtype=np.float32)[None, :].repeat(nv, 0)
    Vv = np.linspace(0.0, 1.0, nv, dtype=np.float32)[:, None].repeat(nu, 1)
    n = fbm(nv, nu, 4, 8, rng, 4)
    rays_n = {"caudal": 18, "dorsal": 14, "paired": 12, "spiny": 13}[kind] * cfg.get("ray_scale", 1)
    ray = np.exp(-((np.mod(U * rays_n, 1.0) - 0.5) / 0.1) ** 2)
    # Rays branch toward the edge: a second, finer set fades in.
    ray = np.maximum(ray, np.exp(-((np.mod(U * rays_n * 2 + 0.5, 1.0) - 0.5) / 0.12) ** 2) * smooth(0.45, 0.8, Vv))
    base = rgb(cfg["fin_base"])
    fin = rgb(cfg["fin_d"] if kind in ("dorsal", "caudal", "spiny") else cfg["fin"])
    if cfg["mark"] == "rudd":
        fin = rgb(cfg["fin"])
    col = mix(np.broadcast_to(base, (nv, nu, 3)), np.broadcast_to(fin, (nv, nu, 3)), smooth(0.0, 0.45, Vv))
    col *= (1.0 - 0.28 * ray)[..., None]
    # The membrane is thinner and lighter between the rays toward the edge.
    col *= (1.0 + 0.18 * (1 - ray) * smooth(0.3, 1.0, Vv))[..., None]
    col *= (1.0 - 0.3 * smooth(0.85, 1.0, Vv))[..., None]
    mark = cfg["mark"]
    if mark == "perch" and kind == "spiny":
        spot = np.exp(-(((U - 0.85) / 0.1) ** 2 + ((Vv - 0.45) / 0.3) ** 2))
        col = mix(col, np.broadcast_to(rgb((0.05, 0.05, 0.05)), col.shape), np.clip(spot * 1.5, 0, 1))
    if mark in ("trout", "zander", "pike", "brown_trout", "gudgeon") and kind in ("dorsal", "caudal", "spiny"):
        ss = spots(rng, U, (Vv - 0.5) * 1.6, 70 if mark == "trout" else 40, (0.0, 1.0), (-0.7, 0.7),
                   0.012 if mark == "trout" else 0.02)
        col = mix(col, col * 0.2, np.clip(ss * 1.5, 0, 1) * 0.8)
    col *= (0.9 + 0.2 * n)[..., None]
    height = ray * 0.6
    if cooked:
        crisp = smooth(0.2, 0.9, Vv + (n - 0.5) * 0.4)
        c2 = mix(np.broadcast_to(rgb((0.55, 0.36, 0.17)), col.shape), np.broadcast_to(rgb((0.12, 0.07, 0.04)), col.shape), crisp)
        col = c2 * (1.0 - 0.2 * ray)[..., None]
    return col, height


def build_fish(key, cfg):
    rng = np.random.default_rng(sum(ord(ch) * (i + 1) for i, ch in enumerate(key)))
    body = Body(cfg)
    albedo, height, cooked = body_texture(key, cfg, rng)
    nor = normal_from_height(height, 1.6 if cfg["scales"] else 1.0)
    albedo_img = save_image(key + "_body", albedo)
    cooked_img = save_image(key + "_cooked_body", cooked)
    nor_img = save_image(key + "_body_nor", nor, True)
    fins = {}
    for kind in ("dorsal", "caudal", "paired", "spiny"):
        c, h = fin_texture(cfg, rng, kind)
        cc, _ = fin_texture(cfg, rng, kind, cooked=True)
        fins[kind] = (save_image(key + "_" + kind, c), save_image(key + "_cooked_" + kind, cc),
                      save_image(key + "_" + kind + "_nor", normal_from_height(h, 2.0), True))
    slime = 0.22 if cfg["scales"] == 0 or cfg["mark"] == "tench" else 0.3
    for cooked_variant in (False, True):
        name = key + ("_cooked" if cooked_variant else "")
        mats = {
            "body": material(name + "_skin", image=cooked_img if cooked_variant else albedo_img, normal=nor_img,
                             rough=0.55 if cooked_variant else slime, spec=0.6, coat=0.0 if cooked_variant else 0.35),
            "iris": material(name + "_iris", color=(0.86, 0.84, 0.78) if cooked_variant else cfg["iris"],
                             rough=0.35 if cooked_variant else 0.08, spec=0.9),
            "pupil": material(name + "_pupil", color=(0.55, 0.53, 0.5) if cooked_variant else (0.01, 0.01, 0.012),
                              rough=0.3 if cooked_variant else 0.03, spec=1.0),
            "barbel": material(name + "_barbel", color=(0.35, 0.22, 0.1) if cooked_variant else cfg["flank"],
                               rough=0.4),
        }
        for kind, (img, cimg, nimg) in fins.items():
            mats[kind] = material(name + "_" + kind, image=cimg if cooked_variant else img, normal=nimg,
                                  rough=0.6 if cooked_variant else 0.35, double=True)
        b = Builder()
        body_mesh(b, body, mats["body"])
        for i, (s0, s1, hs, rake) in enumerate(cfg.get("dorsal", [])):
            spiny = i == 0 and len(cfg["dorsal"]) > 1
            ridge_fin(b, body, s0, s1, hs, rake, True, mats["spiny" if spiny else "dorsal"])
        for s0, s1, hs, rake in cfg.get("anal", []):
            ridge_fin(b, body, s0, s1, hs, rake, False, mats["paired"])
        if "adipose" in cfg:
            s0, s1, h = cfg["adipose"]
            ridge_fin(b, body, s0, s1, [(0, 0.3 * h), (0.5, h), (1, 0.6 * h)], 0.6, True, mats["body"], nu=6, nv=3)
        tail_fin(b, body, mats["caudal"])
        s, e, ln = cfg["pectoral"]
        paired_fin(b, body, s, e, ln, mats["paired"], 0.8, 1.0, 0.35)
        if cfg["pelvic"] is not None:
            s, e, ln = cfg["pelvic"]
            paired_fin(b, body, s, e, ln, mats["paired"], 0.6, 1.0, 0.9)
        eyes(b, body, cfg, mats["iris"], mats["pupil"])
        barbels(b, body, cfg, mats["barbel"])
        ob = b.to_object(name)
        if cooked_variant:
            # Cooked fish curl a little and the fins shrink back.
            for v in ob.data.vertices:
                x = v.co.x / (body.L * 0.5)
                v.co.y += 0.035 * body.L * x * x
        export(name, [ob])
        bpy.data.objects.remove(ob)


# --- Crayfish ------------------------------------------------------------------------------

def build_crayfish():
    rng = np.random.default_rng(77)
    nv, nu = 256, 512
    n = fbm(nv, nu, 6, 12, rng, 5)
    n2 = fbm(nv, nu, 16, 32, rng, 3)
    V = np.linspace(0, 1, nv, dtype=np.float32)[:, None].repeat(nu, 1)
    raw = mix(np.broadcast_to(rgb((0.36, 0.3, 0.18)), (nv, nu, 3)), np.broadcast_to(rgb((0.2, 0.16, 0.1)), (nv, nu, 3)),
              smooth(0.4, 0.7, n))
    raw = mix(raw, np.broadcast_to(rgb((0.56, 0.44, 0.26)), raw.shape), smooth(0.0, 0.35, 1 - V) * 0.5)
    raw *= (0.85 + 0.3 * n2)[..., None]
    cooked = mix(np.broadcast_to(rgb((0.86, 0.26, 0.08)), (nv, nu, 3)), np.broadcast_to(rgb((0.95, 0.52, 0.28)), (nv, nu, 3)),
                 smooth(0.45, 0.7, n))
    cooked *= (0.85 + 0.3 * n2)[..., None]
    nor = normal_from_height(n2 * 0.5 + smooth(0.6, 0.65, n) * 0.3, 3.0)
    imgs = (save_image("crayfish_shell", raw), save_image("crayfish_cooked_shell", cooked),
            save_image("crayfish_shell_nor", nor, True))
    for cooked_variant in (False, True):
        name = "fish_crayfish" + ("_cooked" if cooked_variant else "")
        shell = material(name + "_shell", image=imgs[1] if cooked_variant else imgs[0], normal=imgs[2],
                         rough=0.45 if cooked_variant else 0.3, coat=0.0 if cooked_variant else 0.4)
        eye = material(name + "_eye", color=(0.02, 0.02, 0.02), rough=0.05, spec=1.0)
        b = Builder()
        # Carapace and rostrum (head toward +X).
        b.sphere(Vector((0.02, 0, 0.0)), (0.034, 0.016, 0.016), shell, segs=20, rings=12)
        b.cone(Vector((0.05, 0, 0.004)), Vector((0.068, 0, 0.004)), 0.005, 0.0008, shell, segs=8)
        # Abdomen: six segments shrinking toward the tail fan, curving down a touch.
        for i in range(6):
            x = -0.014 - i * 0.0088
            r = 0.0145 - i * 0.0011
            b.sphere(Vector((x, 0, -0.001 - i * 0.0009)), (0.0072, r, r * 0.72), shell, segs=16, rings=8)
        # Tail fan: five plates.
        for k, ang in enumerate((-0.7, -0.35, 0.0, 0.35, 0.7)):
            rot = Matrix.Rotation(ang, 3, "Z")
            c = Vector((-0.064, 0, -0.006)) + rot @ Vector((-0.011, 0, 0))
            b.sphere(c, (0.012, 0.0055, 0.0015), shell, rot, segs=10, rings=6)
        # Claws: arm, forearm and the pincer (a fixed and a movable finger).
        for side in (1, -1):
            sh = Vector((0.035, side * 0.012, -0.004))
            el = Vector((0.05, side * 0.03, -0.002))
            wr = Vector((0.07, side * 0.036, 0.0))
            b.cone(sh, el, 0.003, 0.0035, shell, segs=8)
            b.cone(el, wr, 0.0035, 0.0045, shell, segs=8)
            rot = Matrix.Rotation(side * 0.25, 3, "Z")
            b.sphere(wr + rot @ Vector((0.018, 0, 0)), (0.022, 0.009, 0.005), shell, rot, segs=14, rings=8)
            b.sphere(wr + rot @ Vector((0.02, -side * 0.009, 0.0)), (0.017, 0.004, 0.0035), shell,
                     rot @ Matrix.Rotation(-side * 0.2, 3, "Z"), segs=10, rings=6)
            # Four walking legs.
            for k in range(4):
                root = Vector((0.03 - k * 0.009, side * 0.012, -0.008))
                knee = root + Vector((0.004 - k * 0.003, side * 0.016, 0.004))
                foot = knee + Vector((-0.002 - k * 0.002, side * 0.01, -0.016))
                b.cone(root, knee, 0.0014, 0.0012, shell, segs=6)
                b.cone(knee, foot, 0.0012, 0.0005, shell, segs=6)
            # Antennae sweeping back, and the eyes.
            a0 = Vector((0.052, side * 0.006, 0.006))
            a1 = a0 + Vector((0.03, side * 0.02, 0.004))
            a2 = a1 + Vector((0.005, side * 0.03, 0.0))
            a3 = a2 + Vector((-0.03, side * 0.025, -0.003))
            b.cone(a0, a1, 0.0009, 0.0006, shell, segs=5)
            b.cone(a1, a2, 0.0006, 0.0004, shell, segs=5)
            b.cone(a2, a3, 0.0004, 0.0002, shell, segs=5)
            b.sphere(Vector((0.05, side * 0.0065, 0.008)), (0.0022, 0.0022, 0.0022), eye, segs=8, rings=5)
        ob = b.to_object(name)
        export(name, [ob])
        bpy.data.objects.remove(ob)


# --- Rod and float ----------------------------------------------------------------------------

def cork_texture(rng, nv=256, nu=512):
    n = fbm(nv, nu, 16, 32, rng, 4)
    pits = smooth(0.62, 0.7, fbm(nv, nu, 40, 80, rng, 2))
    col = mix(np.broadcast_to(rgb((0.72, 0.56, 0.38)), (nv, nu, 3)), np.broadcast_to(rgb((0.5, 0.36, 0.22)), (nv, nu, 3)), n)
    col = mix(col, col * 0.45, pits)
    # Glued rings every 12 mm along the grip.
    rings = np.exp(-((np.mod(np.linspace(0, 20, nu)[None, :], 1.0) - 0.5) / 0.03) ** 2)
    col *= (1 - 0.18 * rings)[..., None]
    return col, pits * 0.5 + n * 0.3


def lathe(b, profile, mat, segs=20, axis_offset=Vector((0, 0, 0))):
    """Revolves [(z, r)] around Z; UV u around, v along."""
    pts = []
    zs = [p[0] for p in profile]
    for j in range(segs + 1):
        t = 2 * math.pi * j / segs
        row = []
        for z, r in profile:
            row.append(axis_offset + Vector((math.cos(t) * r, math.sin(t) * r, z)))
        pts.append(row)
    b.grid(pts, mat)
    return zs


def build_rod():
    rng = np.random.default_rng(9)
    cork_col, cork_h = cork_texture(rng)
    cork_img = save_image("rod_cork", cork_col)
    cork_nor = save_image("rod_cork_nor", normal_from_height(cork_h, 2.5), True)
    cork = material("rod_cork", image=cork_img, normal=cork_nor, rough=0.75)
    blank = material("rod_blank", color=(0.05, 0.07, 0.06), rough=0.18, metal=0.2, coat=0.6)
    rubber = material("rod_rubber", color=(0.04, 0.04, 0.04), rough=0.7)
    chrome = material("rod_chrome", color=(0.8, 0.8, 0.82), rough=0.12, metal=1.0)
    gunmetal = material("rod_gunmetal", color=(0.18, 0.19, 0.2), rough=0.3, metal=0.9)
    gold = material("rod_gold", color=(0.78, 0.6, 0.25), rough=0.25, metal=1.0)
    line = material("rod_line", color=(0.74, 0.78, 0.72), rough=0.35)
    wrap = material("rod_wrap", color=(0.35, 0.07, 0.05), rough=0.3, coat=0.8)
    b = Builder()
    lathe(b, [(-0.37, 0.0), (-0.37, 0.012), (-0.366, 0.0145), (-0.35, 0.0145), (-0.345, 0.0135)], rubber)
    lathe(b, [(-0.345, 0.0135), (-0.3, 0.0145), (-0.2, 0.0142), (-0.1, 0.013), (-0.065, 0.0125)], cork)
    lathe(b, [(-0.065, 0.0125), (-0.06, 0.0112), (-0.045, 0.011), (0.04, 0.011), (0.05, 0.0115), (0.055, 0.0118)], gunmetal)
    lathe(b, [(-0.058, 0.0116), (-0.054, 0.0122), (-0.05, 0.0116)], gold)
    lathe(b, [(0.055, 0.0118), (0.08, 0.0122), (0.16, 0.0108), (0.175, 0.0095)], cork)
    lathe(b, [(0.175, 0.0095), (0.182, 0.0068), (0.19, 0.0062)], gold)
    zs = np.linspace(0.19, 1.66, 40)
    lathe(b, [(float(z), float(0.0062 - (z - 0.19) / 1.47 * 0.0048)) for z in zs] + [(1.66, 0.0)], blank, segs=12)
    # Guides toward -X (the reel's side): a ring on two legs, whipped on with thread.
    guides = [(0.5, 0.012, 0.034), (0.76, 0.0085, 0.025), (0.98, 0.0066, 0.019), (1.17, 0.0054, 0.016),
              (1.33, 0.0046, 0.013), (1.46, 0.004, 0.011), (1.56, 0.0035, 0.009)]
    for z, rr, hgt in guides:
        rblank = 0.0062 - (z - 0.19) / 1.47 * 0.0048
        center = Vector((-(rblank + hgt), 0.0, z + 0.004))
        ring = []
        for k in range(17):
            t = 2 * math.pi * k / 16
            ring.append(center + Vector((math.cos(t) * rr, 0.0, math.sin(t) * rr)))
        b.tube(ring, [0.0009] * len(ring), chrome, segs=6)
        for dz in (-0.9, 0.9):
            foot = Vector((-rblank, 0.0, z + dz * hgt * 0.9))
            b.cone(foot, center + Vector((rr * 0.6, 0.0, dz * rr * 0.5)), 0.0007, 0.0007, chrome, segs=5)
            lathe(b, [(z + dz * hgt * 0.9 - 0.006, rblank + 0.0004), (z + dz * hgt * 0.9 + 0.006, rblank + 0.0004)], wrap, segs=10)
    tip = Vector((0.0, 0.0, 1.667))
    ring = [tip + Vector((math.cos(2 * math.pi * k / 12) * 0.0028, 0.0, math.sin(2 * math.pi * k / 12) * 0.0028))
            for k in range(13)]
    b.tube(ring, [0.0007] * len(ring), chrome, segs=5)
    # Spinning reel hanging under the seat (-X): stem, body, rotor, spool with line, bail and crank.
    b.cone(Vector((-0.011, 0, 0.0)), Vector((-0.05, 0, 0.0)), 0.004, 0.005, gunmetal, segs=10)
    b.sphere(Vector((-0.062, 0, -0.002)), (0.022, 0.017, 0.026), gunmetal, segs=18, rings=10)
    rot_c = Vector((-0.062, 0, 0.03))
    lathe(b, [(0.0, 0.0), (0.0, 0.018), (0.012, 0.019), (0.016, 0.016)], gunmetal, axis_offset=rot_c)
    lathe(b, [(0.016, 0.016), (0.018, 0.022), (0.021, 0.022), (0.022, 0.017), (0.036, 0.017), (0.037, 0.0215),
              (0.041, 0.021), (0.043, 0.006), (0.047, 0.0)], chrome, axis_offset=rot_c)
    lathe(b, [(0.022, 0.0172), (0.036, 0.0172)], line, segs=24, axis_offset=rot_c)
    bail = []
    for k in range(13):
        t = math.pi * k / 12
        bail.append(rot_c + Vector((math.cos(t) * 0.024, math.sin(t) * 0.024 * 0.9, 0.044 - 0.004 * math.sin(t))))
    b.tube(bail, [0.0011] * len(bail), chrome, segs=6)
    crank0 = Vector((-0.062, 0.017, -0.004))
    crank1 = crank0 + Vector((0.0, 0.035, 0.0))
    b.cone(Vector((-0.062, 0.01, -0.004)), crank0, 0.004, 0.004, gold, segs=10)
    b.cone(crank0, crank1 + Vector((0.0, 0.0, -0.022)), 0.0025, 0.0022, gunmetal, segs=8)
    knob = crank1 + Vector((0.0, 0.0, -0.022))
    b.cone(knob, knob + Vector((0.0, 0.013, 0.0)), 0.0036, 0.0032, rubber, segs=12)
    ob = b.to_object("fishing_rod")
    export("fishing_rod", [ob])
    bpy.data.objects.remove(ob)


def build_float():
    red = material("float_red", color=(0.85, 0.08, 0.04), rough=0.2, coat=0.6)
    white = material("float_white", color=(0.92, 0.92, 0.9), rough=0.25, coat=0.5)
    dark = material("float_band", color=(0.04, 0.04, 0.04), rough=0.3)
    tip = material("float_tip", color=(1.0, 0.45, 0.02), rough=0.3)
    b = Builder()
    w = 0.02
    lathe(b, [(-0.024 - w * 0, 0.0), (-0.022, 0.004), (-0.016, 0.008), (-0.008, 0.0105), (-0.002, 0.011)], white, segs=18)
    lathe(b, [(-0.002, 0.011), (0.0, 0.011)], dark, segs=18)
    lathe(b, [(0.0, 0.011), (0.006, 0.0102), (0.012, 0.0075), (0.017, 0.0035), (0.019, 0.0015)], red, segs=18)
    lathe(b, [(0.019, 0.0015), (0.04, 0.0012)], white, segs=8)
    lathe(b, [(0.04, 0.0012), (0.052, 0.0012), (0.053, 0.0)], tip, segs=8)
    eye = [Vector((math.cos(2 * math.pi * k / 10) * 0.0022, 0.0, -0.0265 + math.sin(2 * math.pi * k / 10) * 0.0022))
           for k in range(11)]
    b.tube(eye, [0.0005] * len(eye), dark, segs=5)
    ob = b.to_object("fishing_float")
    export("fishing_float", [ob])
    bpy.data.objects.remove(ob)


# --- More rods: the cane pole, the carbon spinning rod and the carp rod ------------------------

def eva_texture(rng, dark, nv=256, nu=512):
    """EVA foam: fine closed pores, a little mottling."""
    n = fbm(nv, nu, 12, 24, rng, 4)
    pores = smooth(0.6, 0.68, fbm(nv, nu, 60, 120, rng, 2))
    col = np.broadcast_to(rgb(dark), (nv, nu, 3)) * (0.9 + 0.2 * n)[..., None]
    col = mix(col, col * 0.55, pores * 0.8)
    return col, pores * 0.6 + n * 0.2


def spinning_reel(b, at, k, body_mat, spool_mat, line_mat, trim_mat, knob_mat, bail_mat, spool_r=0.017, spool_len=0.014):
    """A fixed-spool reel hanging under the seat toward -X, `k` times the standard reel's
    size: stem, body, rotor, spool with line, bail, crank and knob; the long-cast spool
    of a carp reel is wider (`spool_r`) and longer."""
    b.cone(at + Vector((-0.011 * k, 0, 0.0)), at + Vector((-0.05 * k, 0, 0.0)), 0.004 * k, 0.005 * k, body_mat, segs=10)
    b.sphere(at + Vector((-0.062 * k, 0, -0.002 * k)), (0.022 * k, 0.017 * k, 0.026 * k), body_mat, segs=18, rings=10)
    rc = at + Vector((-0.062 * k, 0, 0.03 * k))
    lathe(b, [(0.0, 0.0), (0.0, 0.018 * k), (0.012 * k, 0.019 * k), (0.016 * k, 0.016 * k)], body_mat, axis_offset=rc)
    z0 = 0.016 * k
    sr = spool_r * k
    sl = spool_len * k
    lathe(b, [(z0, 0.016 * k), (z0 + 0.002 * k, sr + 0.005 * k), (z0 + 0.005 * k, sr + 0.005 * k), (z0 + 0.006 * k, sr),
              (z0 + 0.006 * k + sl, sr), (z0 + 0.007 * k + sl, sr + 0.0045 * k), (z0 + 0.011 * k + sl, sr + 0.004 * k),
              (z0 + 0.013 * k + sl, 0.006 * k), (z0 + 0.017 * k + sl, 0.0)], spool_mat, axis_offset=rc)
    lathe(b, [(z0 + 0.006 * k, sr + 0.0003), (z0 + 0.006 * k + sl, sr + 0.0003)], line_mat, segs=24, axis_offset=rc)
    lathe(b, [(z0 + 0.0015 * k, sr + 0.0052 * k), (z0 + 0.0035 * k, sr + 0.0052 * k)], trim_mat, segs=24, axis_offset=rc)
    bail = []
    br = sr + 0.007 * k
    for i in range(13):
        t = math.pi * i / 12
        bail.append(rc + Vector((math.cos(t) * br, math.sin(t) * br * 0.9, z0 + 0.012 * k + sl - 0.004 * k * math.sin(t))))
    b.tube(bail, [0.0011 * k] * len(bail), bail_mat, segs=6)
    c0 = at + Vector((-0.062 * k, 0.017 * k, -0.004 * k))
    c1 = c0 + Vector((0.0, 0.035 * k, 0.0))
    b.cone(at + Vector((-0.062 * k, 0.01 * k, -0.004 * k)), c0, 0.004 * k, 0.004 * k, trim_mat, segs=10)
    b.cone(c0, c1 + Vector((0.0, 0.0, -0.022 * k)), 0.0025 * k, 0.0022 * k, body_mat, segs=8)
    knob = c1 + Vector((0.0, 0.0, -0.022 * k))
    b.cone(knob, knob + Vector((0.0, 0.014 * k, 0.0)), 0.0038 * k, 0.0034 * k, knob_mat, segs=12)


def rod_guides(b, guides, r_at, frame, insert, wrap, trim=None):
    """Guides toward -X: a ring on two legs, whipped on with thread (a trim band on the
    whipping when given)."""
    for z, rr, hgt in guides:
        rblank = r_at(z)
        center = Vector((-(rblank + hgt), 0.0, z + 0.004))
        ring = [center + Vector((math.cos(2 * math.pi * k / 16) * rr, 0.0, math.sin(2 * math.pi * k / 16) * rr))
                for k in range(17)]
        b.tube(ring, [max(0.0009, rr * 0.1)] * len(ring), insert, segs=6)
        outer = [center + Vector((math.cos(2 * math.pi * k / 16) * rr * 1.18, 0.0, math.sin(2 * math.pi * k / 16) * rr * 1.18))
                 for k in range(17)]
        b.tube(outer, [max(0.0007, rr * 0.06)] * len(outer), frame, segs=5)
        for dz in (-0.9, 0.9):
            foot = Vector((-rblank, 0.0, z + dz * hgt * 0.9))
            b.cone(foot, center + Vector((rr * 0.6, 0.0, dz * rr * 0.5)), 0.0008, 0.0008, frame, segs=5)
            zz = z + dz * hgt * 0.9
            lathe(b, [(zz - 0.007, rblank + 0.0004), (zz + 0.007, rblank + 0.0004)], wrap, segs=10)
            if trim is not None:
                lathe(b, [(zz + 0.007, rblank + 0.0005), (zz + 0.009, rblank + 0.0005)], trim, segs=10)


ROD_SPECS = {
    # Karbon spin oltası: 2.1 m of deep-blue carbon, split EVA grips, a bigger black and
    # silver reel with a blue spool, lined guides whipped in silver.
    "carbon_rod": {"len": 2.1, "butt": -0.4, "r0": 0.0068, "r1": 0.0013, "blank": (0.02, 0.05, 0.16),
                   "blank_rough": 0.14, "grip": (0.08, 0.08, 0.085), "wrap": (0.62, 0.64, 0.68), "trim": (0.1, 0.3, 0.85),
                   "reel": 1.12, "reel_body": (0.06, 0.06, 0.065), "spool": (0.12, 0.34, 0.8), "spool_r": 0.017,
                   "spool_len": 0.014, "line": (0.86, 0.9, 0.84), "split": True},
    # Sazan oltası: 2.6 m, thick and matt olive, a full rubber shrink grip, a big-pit reel
    # with a long-cast spool of green line and a wide butt ring.
    "carp_rod": {"len": 2.6, "butt": -0.55, "r0": 0.0092, "r1": 0.0019, "blank": (0.14, 0.16, 0.1),
                 "blank_rough": 0.42, "grip": (0.05, 0.05, 0.05), "wrap": (0.08, 0.08, 0.08), "trim": (0.72, 0.6, 0.3),
                 "reel": 1.38, "reel_body": (0.2, 0.21, 0.2), "spool": (0.66, 0.66, 0.68), "spool_r": 0.021,
                 "spool_len": 0.02, "line": (0.28, 0.4, 0.22), "split": False},
}


def build_modern_rod(name):
    sp = ROD_SPECS[name]
    rng = np.random.default_rng(len(name) * 31)
    L = sp["len"]
    grip_col, grip_h = eva_texture(rng, sp["grip"])
    grip_img = save_image(name + "_grip", grip_col)
    grip_nor = save_image(name + "_grip_nor", normal_from_height(grip_h, 2.0 if sp["split"] else 1.2), True)
    grip = material(name + "_grip", image=grip_img, normal=grip_nor, rough=0.8 if sp["split"] else 0.62)
    blank = material(name + "_blank", color=sp["blank"], rough=sp["blank_rough"], metal=0.15, coat=0.9 if sp["split"] else 0.2)
    rubber = material(name + "_rubber", color=(0.035, 0.035, 0.035), rough=0.7)
    seat = material(name + "_seat", color=(0.05, 0.05, 0.055), rough=0.32, metal=0.6)
    chrome = material(name + "_chrome", color=(0.8, 0.8, 0.82), rough=0.12, metal=1.0)
    insert = material(name + "_insert", color=(0.12, 0.12, 0.13), rough=0.08, metal=0.8)
    frame = material(name + "_frame", color=(0.06, 0.06, 0.065), rough=0.25, metal=0.9)
    wrap = material(name + "_wrap", color=sp["wrap"], rough=0.3, metal=0.5 if sp["split"] else 0.0, coat=0.8)
    trim = material(name + "_trim", color=sp["trim"], rough=0.25, metal=0.7, coat=0.6)
    reel_body = material(name + "_reel", color=sp["reel_body"], rough=0.3, metal=0.85)
    spool = material(name + "_spool", color=sp["spool"], rough=0.22, metal=1.0)
    line = material(name + "_line", color=sp["line"], rough=0.35)
    b = Builder()
    butt = sp["butt"]
    r0, r1 = sp["r0"], sp["r1"]
    top = 0.19 if sp["split"] else 0.3

    def r_at(z):
        return r0 - (z - top) / (L - top) * (r0 - r1)

    lathe(b, [(butt, 0.0), (butt, 0.013), (butt + 0.004, 0.0155), (butt + 0.02, 0.0155), (butt + 0.025, 0.0142)], rubber)
    if sp["split"]:
        # The rear grip, a bare stretch of blank, then the seat and the fore grip.
        lathe(b, [(butt + 0.025, 0.0142), (butt + 0.03, 0.0148), (butt + 0.13, 0.0146), (butt + 0.14, 0.0138)], grip)
        lathe(b, [(butt + 0.14, 0.0085), (-0.075, 0.0085)], blank, segs=14)
        lathe(b, [(-0.075, 0.0138), (-0.07, 0.0146), (-0.06, 0.0142)], grip)
    else:
        lathe(b, [(butt + 0.025, 0.0142), (butt + 0.03, 0.0152), (-0.2, 0.0148), (-0.07, 0.0142), (-0.06, 0.0138)], grip)
    # The screw reel seat, a trim ring each end.
    lathe(b, [(-0.06, 0.0132), (-0.055, 0.0122), (0.045, 0.0122), (0.05, 0.0126), (0.058, 0.0132)], seat)
    lathe(b, [(-0.064, 0.0138), (-0.058, 0.0138)], trim)
    lathe(b, [(0.058, 0.0134), (0.064, 0.0134)], trim)
    if sp["split"]:
        lathe(b, [(0.064, 0.0128), (0.075, 0.0132), (0.15, 0.0118), (0.17, 0.0098), (0.19, r0)], grip)
    else:
        lathe(b, [(0.064, 0.0132), (0.08, 0.0136), (0.26, 0.0122), (0.28, 0.0105), (0.3, r0)], grip)
    lathe(b, [(top, r0 + 0.0008), (top + 0.012, r0 + 0.0008)], wrap, segs=14)
    zs = np.linspace(top, L - 0.005, 48)
    lathe(b, [(float(z), float(r_at(z))) for z in zs] + [(L - 0.005, 0.0)], blank, segs=12)
    # Guides shrink toward the tip; the carp rod's butt ring is a wide 50 mm one.
    n_g = 8 if sp["split"] else 7
    first = 0.5 if sp["split"] else 0.62
    guides = []
    for i in range(n_g):
        t = i / (n_g - 1)
        z = first + (L - 0.12 - first) * (t ** 0.85)
        big = 0.018 if not sp["split"] and i == 0 else 0.0
        guides.append((z, max(0.012 - 0.0085 * t, 0.0033) + big, max(0.034 - 0.024 * t, 0.009) + big * 1.6))
    rod_guides(b, guides, r_at, frame, insert, wrap, trim)
    tip = Vector((0.0, 0.0, L))
    ring = [tip + Vector((math.cos(2 * math.pi * k / 12) * 0.0028, 0.0, math.sin(2 * math.pi * k / 12) * 0.0028))
            for k in range(13)]
    b.tube(ring, [0.0008] * len(ring), insert, segs=5)
    lathe(b, [(L - 0.012, r1 + 0.0005), (L - 0.003, r1 + 0.0005)], wrap, segs=10)
    spinning_reel(b, Vector((0.0, 0.0, 0.0)), sp["reel"], reel_body, spool, line, trim, rubber, chrome,
                  spool_r=sp["spool_r"], spool_len=sp["spool_len"])
    ob = b.to_object(name)
    export(name, [ob])
    bpy.data.objects.remove(ob)


CANE_LEN = 2.25


def bamboo_texture(rng, nodes, nv=128, nu=2048):
    """The cane's skin along its length (u along, v around): straw with fine fibres and
    brown flecks, darker rings at the nodes (at `nodes`, shares of the length)."""
    V = np.linspace(0, 1, nv, dtype=np.float32)[:, None].repeat(nu, 1)
    U = np.linspace(0, 1, nu, dtype=np.float32)[None, :].repeat(nv, 0)
    fib = value_noise(nv, nu, 64, 6, rng)
    n = fbm(nv, nu, 6, 40, rng, 4)
    col = mix(np.broadcast_to(rgb((0.8, 0.68, 0.42)), (nv, nu, 3)), np.broadcast_to(rgb((0.64, 0.5, 0.28)), (nv, nu, 3)), n)
    col *= (0.92 + 0.12 * fib)[..., None]
    fleck = smooth(0.66, 0.74, fbm(nv, nu, 10, 160, rng, 3))
    col = mix(col, col * np.array([0.72, 0.6, 0.46], np.float32), fleck * 0.3)
    height = fib * 0.3
    for u0 in nodes:
        band = np.exp(-((U - u0) / 0.003) ** 2)
        scar = np.exp(-((U - u0 - 0.004) / 0.004) ** 2) * 0.6
        col = mix(col, col * np.array([0.55, 0.42, 0.28], np.float32), np.clip(band + scar, 0, 1) * 0.8)
        height += band * 1.2
    # Toward the tip the cane is greener and lighter.
    col = mix(col, col * np.array([1.0, 1.05, 0.85], np.float32), smooth(0.6, 1.0, U) * 0.4)
    return col, height


def build_cane_rod():
    """Kamış olta: a bamboo pole with its line tied to the tip, no reel; the grip bound
    with twine, the spare line wound on a wooden winder lashed above the hand."""
    rng = np.random.default_rng(41)
    butt, L = -0.35, CANE_LEN
    node_z = [butt + 0.22]
    step = 0.3
    while node_z[-1] + step < L - 0.1:
        node_z.append(node_z[-1] + step)
        step *= 0.96
    nodes = [(z - butt) / (L - butt) for z in node_z]
    col, h = bamboo_texture(rng, nodes)
    img = save_image("cane_rod_skin", col.transpose(1, 0, 2))
    nor = save_image("cane_rod_skin_nor", normal_from_height(h, 2.0).transpose(1, 0, 2), True)
    cane = material("cane_rod_skin", image=img, normal=nor, rough=0.42, coat=0.25)
    hemp = material("cane_rod_twine", color=(0.62, 0.5, 0.32), rough=0.85)
    wood = material("cane_rod_winder", color=(0.45, 0.3, 0.17), rough=0.6)
    line = material("cane_rod_line", color=(0.9, 0.9, 0.86), rough=0.35)
    wire = material("cane_rod_wire", color=(0.55, 0.56, 0.58), rough=0.3, metal=1.0)
    b = Builder()

    def r_at(z):
        t = (z - butt) / (L - butt)
        r = 0.0145 - 0.0115 * t ** 0.9
        for zn in node_z:
            r *= 1.0 + 0.09 * math.exp(-((z - zn) / 0.006) ** 2)
        return r

    zs = list(np.linspace(butt, L, 420))
    # The lathe maps its profile rows to the texture's rows (around = u, along = v): the
    # texture was painted with u along the pole, so it is saved transposed.
    lathe(b, [(butt - 0.002, 0.0)] + [(float(z), float(r_at(z))) for z in zs] + [(L + 0.001, 0.0)], cane, segs=14)
    # Twine grip: turns of cord over the butt.
    for i in range(30):
        z = butt + 0.02 + i * 0.0095
        rr = r_at(z)
        lathe(b, [(z - 0.0045, rr), (z - 0.0035, rr + 0.0028), (z + 0.0035, rr + 0.0028), (z + 0.0045, rr)], hemp, segs=12)
    # The line winder: two pegs across a flat stick lashed on the -X side, line wound on it.
    zw0, zw1 = 0.12, 0.34
    rr = r_at((zw0 + zw1) * 0.5)
    b.cone(Vector((-(rr + 0.004), 0, zw0 - 0.02)), Vector((-(rr + 0.004), 0, zw1 + 0.02)), 0.0045, 0.0045, wood, segs=8)
    for zp in (zw0, zw1):
        b.cone(Vector((-(rr + 0.004), -0.018, zp)), Vector((-(rr + 0.004), 0.018, zp)), 0.0032, 0.0032, wood, segs=8)
        lathe(b, [(zp - 0.006, r_at(zp) + 0.0002), (zp + 0.006, r_at(zp) + 0.0002)], hemp, segs=10)
    for k in range(9):
        y = -0.012 + k * 0.003
        b.cone(Vector((-(rr + 0.0085), y, zw0 + 0.002)), Vector((-(rr + 0.0085), y, zw1 - 0.002)), 0.0009, 0.0009, line,
               segs=5)
    # The line runs up the pole from the winder to the tip, taped at a few points.
    pts = [Vector((-(r_at(z) + 0.0012), 0.0, z)) for z in np.linspace(zw1, L - 0.02, 30)]
    pts.append(Vector((0.0, 0.0, L)))
    b.tube(pts, [0.00055] * len(pts), line, segs=4)
    for zt in (0.8, 1.4, 1.95):
        lathe(b, [(zt - 0.005, r_at(zt) + 0.0012), (zt + 0.005, r_at(zt) + 0.0012)], hemp, segs=10)
    # A wire eye at the tip, whipped on.
    tip = Vector((0.0, 0.0, L + 0.004))
    ring = [tip + Vector((math.cos(2 * math.pi * k / 10) * 0.0024, 0.0, math.sin(2 * math.pi * k / 10) * 0.0024))
            for k in range(11)]
    b.tube(ring, [0.0006] * len(ring), wire, segs=5)
    lathe(b, [(L - 0.03, r_at(L - 0.03) + 0.0006), (L - 0.002, r_at(L - 0.002) + 0.0006)], hemp, segs=10)
    ob = b.to_object("cane_rod")
    export("cane_rod", [ob])
    bpy.data.objects.remove(ob)


# --- Bait sold at the market ---------------------------------------------------------------

def scatter(rng, n, radius, z, jitter=0.0):
    out = []
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        r = radius * math.sqrt(rng.uniform(0, 1))
        out.append(Vector((math.cos(a) * r, math.sin(a) * r, z + rng.uniform(-jitter, jitter))))
    return out


def tin_texture(rng, base, nv=128, nu=256):
    n = fbm(nv, nu, 8, 16, rng, 4)
    rust = smooth(0.62, 0.75, fbm(nv, nu, 6, 12, rng, 4))
    col = np.broadcast_to(rgb(base), (nv, nu, 3)) * (0.9 + 0.15 * n)[..., None]
    col = mix(col, np.broadcast_to(rgb((0.36, 0.2, 0.1)), col.shape), rust * 0.6)
    return col, rust


def build_maggot():
    """Kurtçuk: a round tin of bran with a wriggle of cream maggots on it, the lid beside."""
    rng = np.random.default_rng(3)
    col, rust = tin_texture(rng, (0.62, 0.64, 0.62))
    tin = material("maggot_tin", image=save_image("maggot_tin", col), rough=0.35, metal=0.9)
    bran = material("maggot_bran", image=save_image("maggot_bran", mix(
        np.broadcast_to(rgb((0.62, 0.48, 0.3)), (128, 128, 3)), np.broadcast_to(rgb((0.4, 0.28, 0.16)), (128, 128, 3)),
        fbm(128, 128, 24, 24, rng, 3))), rough=0.9)
    grub = material("maggot_grub", color=(0.93, 0.88, 0.74), rough=0.32, spec=0.6, coat=0.3)
    dark = material("maggot_tip", color=(0.18, 0.12, 0.08), rough=0.5)
    b = Builder()
    R, H = 0.045, 0.028
    lathe(b, [(0.0, 0.0), (0.0, R - 0.002), (0.001, R), (H - 0.003, R), (H - 0.002, R + 0.0015), (H, R + 0.0012),
              (H, R - 0.0008), (0.004, R - 0.0008), (0.004, 0.0)], tin, segs=36)
    lathe(b, [(H - 0.006, R - 0.0008), (H - 0.0055, 0.0)], bran, segs=36)
    for p in scatter(rng, 46, R * 0.85, H - 0.0045, 0.0012):
        yaw = rng.uniform(0, math.pi)
        bend = rng.uniform(-0.5, 0.5)
        rot = Matrix.Rotation(yaw, 3, "Z")
        d = rot @ Vector((1, 0, 0))
        n = rot @ Vector((0, 1, 0))
        for k in range(5):
            t = (k - 2) / 2
            c = p + d * t * 0.0044 + n * bend * 0.0014 * (1 - t * t)
            r = 0.0018 * (1.0 - 0.3 * abs(t))
            b.sphere(c, (0.0034, r, r * 0.9), grub, rot, segs=10, rings=6)
        b.sphere(p + d * 0.0105, (0.0008, 0.0007, 0.0007), dark, segs=6, rings=4)
    # The lid leaning against the tin.
    lid_rot = Matrix.Rotation(1.2, 3, "Y") @ Matrix.Rotation(0.0, 3, "Z")
    lid = Builder()
    lathe(lid, [(0.0, 0.0), (0.0, R + 0.0018), (0.006, R + 0.0018), (0.006, R + 0.0008), (0.0015, R + 0.0008),
                (0.0015, 0.0)], tin, segs=36)
    ob = b.to_object("maggot")
    lob = lid.to_object("maggot_lid")
    lob.matrix_world = Matrix.Translation(Vector((R + 0.02, 0.0, R * 0.95))) @ lid_rot.to_4x4()
    export("maggot", [ob, lob])
    bpy.data.objects.remove(ob)
    bpy.data.objects.remove(lob)


def build_corn():
    """Mısır: a small tin of sweetcorn, the lid peeled back, kernels heaped in the top."""
    rng = np.random.default_rng(5)
    nv, nu = 128, 512
    V = np.linspace(0, 1, nv, dtype=np.float32)[:, None].repeat(nu, 1)
    U = np.linspace(0, 1, nu, dtype=np.float32)[None, :].repeat(nv, 0)
    lab = np.broadcast_to(rgb((0.12, 0.36, 0.16)), (nv, nu, 3)).copy()
    lab = mix(lab, np.broadcast_to(rgb((0.96, 0.78, 0.18)), lab.shape), np.exp(-((V - 0.5) / 0.12) ** 2))
    cob = np.exp(-(((np.mod(U * 3, 1.0) - 0.5) / 0.08) ** 2 + ((V - 0.5) / 0.2) ** 2))
    dots = (np.sin(U * 3 * 2 * np.pi * 9) * np.sin(V * 2 * np.pi * 14) > 0.2) * cob
    lab = mix(lab, np.broadcast_to(rgb((0.98, 0.84, 0.3)), lab.shape), cob * 0.8)
    lab = mix(lab, lab * 0.8, dots * 0.5)
    leaf = np.exp(-(((np.mod(U * 3 + 0.08, 1.0) - 0.5) / 0.05) ** 2 + ((V - 0.36) / 0.14) ** 2))
    lab = mix(lab, np.broadcast_to(rgb((0.3, 0.6, 0.2)), lab.shape), leaf * 0.9)
    lab = mix(lab, np.broadcast_to(rgb((0.9, 0.9, 0.86)), lab.shape), smooth(0.9, 0.93, V) + (1 - smooth(0.07, 0.1, V)))
    lab *= (0.93 + 0.1 * fbm(nv, nu, 8, 32, rng, 3))[..., None]
    label = material("corn_label", image=save_image("corn_label", lab), rough=0.5)
    tin = material("corn_tin", color=(0.74, 0.74, 0.72), rough=0.25, metal=1.0)
    kernel = material("corn_kernel", color=(0.97, 0.74, 0.12), rough=0.22, spec=0.7, coat=0.5)
    b = Builder()
    R, H = 0.034, 0.068
    prof = [(0.0, 0.0), (0.0, R - 0.003), (0.002, R)]
    lathe(b, prof + [(0.006, R)], tin, segs=36)
    lathe(b, [(0.006, R + 0.0003), (H - 0.006, R + 0.0003)], label, segs=36)
    ribs = [(H - 0.006, R), (H - 0.002, R), (H, R + 0.0012), (H + 0.001, R + 0.0008), (H - 0.001, R - 0.0006),
            (H - 0.012, R - 0.0006), (H - 0.012, 0.0)]
    lathe(b, ribs, tin, segs=36)
    # Kernels heaped over the rim.
    for i in range(70):
        p = scatter(rng, 1, R * 0.92, H - 0.004)[0]
        top = 0.012 * (1.0 - (p.xy.length / R) ** 2)
        p.z += top * rng.uniform(0.3, 1.0)
        rot = Matrix.Rotation(rng.uniform(0, 6.28), 3, "Z") @ Matrix.Rotation(rng.uniform(-0.8, 0.8), 3, "X")
        b.sphere(p, (0.0046, 0.0038, 0.0026), kernel, rot, segs=8, rings=6)
    # A few spilt beside the tin.
    for p in scatter(rng, 6, 0.02, 0.0024):
        p.x += R + 0.015
        b.sphere(p, (0.0046, 0.0038, 0.0024), kernel, Matrix.Rotation(rng.uniform(0, 6.28), 3, "Z"), segs=8, rings=6)
    # The peeled lid, standing up off the back of the rim.
    lid = Builder()
    lathe(lid, [(0.0, 0.0), (0.0, R + 0.0006), (0.0012, R + 0.0006), (0.0012, 0.0)], tin, segs=36)
    ob = b.to_object("sweetcorn")
    lob = lid.to_object("corn_lid")
    lob.matrix_world = Matrix.Translation(Vector((-R * 0.95, 0.0, H + 0.001))) @ Matrix.Rotation(-1.9, 4, "Y") @ \
        Matrix.Translation(Vector((R, 0.0, 0.0)))
    export("sweetcorn", [ob, lob])
    bpy.data.objects.remove(ob)
    bpy.data.objects.remove(lob)


def build_cheese():
    """Peynir yemi: cubes of white cheese on a square of brown kraft paper."""
    rng = np.random.default_rng(7)
    n = fbm(128, 128, 16, 16, rng, 4)
    holes = smooth(0.66, 0.72, fbm(128, 128, 30, 30, rng, 2))
    ccol = np.broadcast_to(rgb((0.95, 0.93, 0.84)), (128, 128, 3)) * (0.94 + 0.08 * n)[..., None]
    ccol = mix(ccol, ccol * 0.82, holes)
    cheese = material("cheese_bait", image=save_image("cheese_bait", ccol),
                      normal=save_image("cheese_bait_nor", normal_from_height(n * 0.3 - holes * 0.5, 2.0), True),
                      rough=0.55, spec=0.5)
    paper = material("cheese_paper", color=(0.56, 0.4, 0.25), rough=0.55, coat=0.15, double=True)
    b = Builder()
    # The paper, crinkled a little.
    pts = []
    for i in range(13):
        row = []
        for j in range(13):
            x = (i / 12 - 0.5) * 0.095
            y = (j / 12 - 0.5) * 0.095
            z = 0.0015 + 0.0015 * math.sin(i * 1.7) * math.sin(j * 2.3) + 0.004 * max(abs(x), abs(y)) / 0.06 ** 1
            row.append(Vector((x, y, z * 0.5)))
        pts.append(row)
    b.grid(pts, paper)
    for k in range(9):
        before = set(b.bm.faces)
        a = rng.uniform(0, 6.28)
        r = rng.uniform(0.0, 0.03)
        c = Vector((math.cos(a) * r, math.sin(a) * r, 0.0))
        s = rng.uniform(0.011, 0.015)
        rot = Matrix.Rotation(rng.uniform(0, 6.28), 3, "Z")
        res = bmesh.ops.create_cube(b.bm, size=1.0, matrix=Matrix.Translation(c + Vector((0, 0, s * 0.5 + 0.002)))
                                    @ rot.to_4x4() @ Matrix.Diagonal((s, s * rng.uniform(0.85, 1.1), s * rng.uniform(0.8, 1.0), 1.0)),
                                    calc_uvs=True)
        edges = list({e for v in res["verts"] for e in v.link_edges})
        bmesh.ops.bevel(b.bm, geom=res["verts"] + edges, offset=s * 0.12, segments=2, affect="EDGES")
        idx = b.slot(cheese)
        for f in b.bm.faces:
            if f not in before:
                f.material_index = idx
    ob = b.to_object("cheese_bait")
    export("cheese_bait", [ob])
    bpy.data.objects.remove(ob)


def minnow_fish(b, at, yaw, mats, L=0.075, pitch=0.0):
    """A small live bait fish (a bleak's shape in plain materials) at `at`."""
    cfg = dict(FISH["fish_bleak"])
    cfg["L"] = L
    body = Body(cfg)
    sub = Builder()
    body_mesh(sub, body, mats[0], ns=24, nt=16)
    tail_fin(sub, body, mats[1], nu=8, nv=4)
    for s0, s1, hs, rake in cfg["dorsal"]:
        ridge_fin(sub, body, s0, s1, hs, rake, True, mats[1], nu=6, nv=3)
    eyes(sub, body, cfg, mats[2], mats[3])
    m = Matrix.Translation(at) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(pitch, 4, "Y")
    sub.bm.transform(m)
    # Merge into the bucket's builder (keeping the material slots).
    tmp = bpy.data.meshes.new("tmp_minnow")
    sub.bm.to_mesh(tmp)
    remap = [b.slot(mm) for mm in sub.mats]
    offset = len(b.bm.faces)
    b.bm.from_mesh(tmp)
    b.bm.faces.ensure_lookup_table()
    for f in b.bm.faces[offset:]:
        f.material_index = remap[f.material_index]
    sub.bm.free()
    bpy.data.meshes.remove(tmp)


def build_minnow():
    """Canlı yem: a galvanised bait bucket of water with little live fish in it."""
    rng = np.random.default_rng(11)
    col, _ = tin_texture(rng, (0.6, 0.62, 0.62))
    zinc = material("minnow_bucket", image=save_image("minnow_bucket", col), rough=0.42, metal=0.85)
    water = material("minnow_water", color=(0.22, 0.3, 0.26), rough=0.04, spec=0.8)
    water.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.55
    water.surface_render_method = "BLENDED"
    silver = material("minnow_skin", color=(0.78, 0.8, 0.8), rough=0.2, metal=0.5, coat=0.5)
    fin = material("minnow_fin", color=(0.6, 0.6, 0.56), rough=0.4, double=True)
    iris = material("minnow_iris", color=(0.85, 0.85, 0.8), rough=0.08, spec=0.9)
    pupil = material("minnow_pupil", color=(0.01, 0.01, 0.012), rough=0.03, spec=1.0)
    wire = material("minnow_wire", color=(0.5, 0.5, 0.5), rough=0.3, metal=1.0)
    b = Builder()
    r0, r1, H = 0.062, 0.078, 0.12
    lathe(b, [(0.0, 0.0), (0.0, r0 - 0.003), (0.003, r0), (0.02, r0 + 0.2 * (r1 - r0)), (0.021, r0 + 0.2 * (r1 - r0) + 0.0015),
              (0.023, r0 + 0.2 * (r1 - r0)), (H - 0.004, r1), (H, r1 + 0.003), (H + 0.002, r1 + 0.002),
              (H - 0.002, r1 - 0.0015), (0.006, r0 - 0.0015), (0.006, 0.0)], zinc, segs=40)
    wl = H - 0.022
    lathe(b, [(wl, r1 - 0.0022 - (H - wl) * (r1 - r0) / H), (wl, 0.0)], water, segs=40)
    mats = (silver, fin, iris, pupil)
    for i in range(4):
        a = i * 1.7 + 0.3
        rr = 0.03 + 0.012 * (i % 2)
        minnow_fish(b, Vector((math.cos(a) * rr, math.sin(a) * rr, wl - 0.012 - 0.01 * (i % 2))), a + 1.6, mats,
                    L=0.07 + 0.008 * (i % 3))
    # One at the top, nose up.
    minnow_fish(b, Vector((0.012, -0.018, wl - 0.004)), 0.4, mats, L=0.078, pitch=-0.25)
    # The wire bail and its wooden grip.
    bail = []
    for k in range(25):
        t = math.pi * k / 24
        bail.append(Vector((math.cos(t) * (r1 + 0.004), 0.0, H - 0.006 + math.sin(t) * 0.07)))
    b.tube(bail, [0.0016] * len(bail), wire, segs=6)
    ob = b.to_object("minnow")
    export("minnow", [ob])
    bpy.data.objects.remove(ob)


def build_spinner():
    """Döner kaşık: a spinner lure lying on its side: the eye, a willow blade on its
    clevis, brass body beads, a red bead and a treble hook with a red tag."""
    brass = material("spinner_brass", color=(0.8, 0.62, 0.3), rough=0.2, metal=1.0)
    blade_m = material("spinner_blade", color=(0.9, 0.9, 0.92), rough=0.08, metal=1.0, double=True)
    steel = material("spinner_wire", color=(0.62, 0.63, 0.65), rough=0.2, metal=1.0)
    red = material("spinner_red", color=(0.8, 0.06, 0.04), rough=0.3, coat=0.6)
    tag = material("spinner_tag", color=(0.75, 0.08, 0.06), rough=0.8, double=True)
    b = Builder()
    k = 1.6  # a touch larger than life, so it reads in the hand and the bag
    z = 0.004 * k
    b.cone(Vector((0.0, 0, z)), Vector((0.058 * k, 0, z)), 0.0005 * k, 0.0005 * k, steel, segs=6)
    eye = [Vector((0.058 * k + 0.004 * k + math.cos(2 * math.pi * i / 12) * 0.004 * k, 0.0,
                   z + math.sin(2 * math.pi * i / 12) * 0.004 * k)) for i in range(13)]
    b.tube(eye, [0.0005 * k] * len(eye), steel, segs=5)
    # The blade: a cupped willow leaf beside the shaft, tilted as if spinning.
    pts = []
    for i in range(13):
        u = i / 12
        row = []
        for j in range(7):
            v = j / 6 * 2 - 1
            w = 0.0062 * k * math.sin(math.pi * u) ** 0.8
            x = 0.05 * k - u * 0.026 * k
            # Swung out to the side of the shaft, cupped.
            y = 0.0075 * k + v * w
            zz = z + 0.0022 * k * (1 - v * v) * math.sin(math.pi * u)
            row.append(Vector((x, y, zz)))
        pts.append(row)
    blade = Builder()
    blade.grid(pts, blade_m)
    ob_blade = blade.to_object("spinner_blade")
    ob_blade.matrix_world = Matrix.Translation(Vector((0.0, 0, z))) @ Matrix.Rotation(0.7, 4, "X") @ \
        Matrix.Translation(Vector((0.0, 0, -z)))
    # The clevis: a bent wire from the shaft to the blade's front.
    b.cone(Vector((0.053 * k, 0, z)), Vector((0.051 * k, 0.0075 * k * math.cos(0.7), z + 0.0075 * k * math.sin(0.7))),
           0.0005 * k, 0.0005 * k, steel, segs=5)
    b.sphere(Vector((0.046 * k, 0, z)), (0.0018 * k, 0.0018 * k, 0.0018 * k), red, segs=10, rings=6)
    for i, (x, r) in enumerate([(0.041 * k, 0.0022), (0.036 * k, 0.0026), (0.031 * k, 0.003)]):
        b.sphere(Vector((x, 0, z)), (0.0024 * k, r * k, r * k), brass, segs=12, rings=8)
    b.cone(Vector((0.028 * k, 0, z)), Vector((0.016 * k, 0, z)), 0.0032 * k, 0.0012 * k, brass, segs=12)
    # Treble hook: three bends round the end of the shank, the tag of red wool over them.
    hx = 0.004 * k
    rb = 0.0032 * k
    for a in (0.0, 2.094, 4.189):
        d = Vector((0.0, math.cos(a), math.sin(a)))
        c = Vector((hx, 0.0, z)) + d * rb
        curve = []
        for i in range(10):
            ang = math.pi * i / 9
            curve.append(c + Vector((-math.sin(ang) * rb * 1.3, 0.0, 0.0)) - d * math.cos(ang) * rb)
        curve.append(curve[-1] + Vector((0.006 * k, 0.0, 0.0)) - d * 0.0008 * k)
        b.tube(curve, [0.00055 * k] * len(curve), steel, segs=5)
    for i in range(7):
        a = i * 0.9
        d = Vector((0.0, math.cos(a), math.sin(a)))
        b.cone(Vector((0.017 * k, 0, z)), Vector((0.004 * k, 0, z)) + d * 0.004 * k, 0.0012 * k, 0.0003 * k, tag, segs=5)
    ob = b.to_object("spinner")
    export("spinner", [ob, ob_blade])
    bpy.data.objects.remove(ob)
    bpy.data.objects.remove(ob_blade)


# --- The old boot ------------------------------------------------------------------------------

def build_boot():
    if not BOOTS or not os.path.exists(BOOTS):
        print("no --boots source; skipping the old boot")
        return
    bpy.ops.import_scene.gltf(filepath=BOOTS)
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    if len(obs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    # The pair are the two biggest pieces; keep the one on +X with whatever is attached.
    parts.sort(key=lambda o: -len(o.data.vertices))
    keep = parts[0]
    cx = sum((keep.matrix_world @ v.co).x for v in keep.data.vertices) / max(len(keep.data.vertices), 1)
    for o in parts[1:]:
        ox = sum((o.matrix_world @ v.co).x for v in o.data.vertices) / max(len(o.data.vertices), 1)
        if abs(ox - cx) > 0.08:
            bpy.data.objects.remove(o)
    parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    # The pond's version: the dirty textures, and lying on its side.
    tex_dir = os.path.join(os.path.dirname(BOOTS), "textures")
    for slot in ob.material_slots:
        m = slot.material
        if not m or not m.use_nodes:
            continue
        for node in m.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                name = os.path.basename(node.image.filepath)
                dirty = name.replace("rubber_boots_", "rubber_boots_dirty_")
                path = os.path.join(tex_dir, dirty)
                if dirty != name and os.path.exists(path):
                    img = bpy.data.images.load(path)
                    img.colorspace_settings.name = node.image.colorspace_settings.name
                    node.image = img
    bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    cx = sum(v.x for v in bb) / 8
    cy = sum(v.y for v in bb) / 8
    zmin = min(v.z for v in bb)
    ob.location -= Vector((cx, cy, zmin))
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    export("old_boot", [ob])


def main():
    os.makedirs(OUT, exist_ok=True)
    jobs = [(k, lambda k=k: build_fish(k, FISH[k])) for k in FISH]
    jobs += [("fish_crayfish", build_crayfish), ("rod", build_rod), ("float", build_float), ("boot", build_boot)]
    jobs += [(k, lambda k=k: build_modern_rod(k)) for k in ROD_SPECS]
    jobs += [("cane_rod", build_cane_rod), ("maggot", build_maggot), ("sweetcorn", build_corn), ("cheese_bait", build_cheese),
             ("minnow", build_minnow), ("spinner", build_spinner)]
    for key, job in jobs:
        if ONLY and key not in ONLY:
            continue
        reset()
        job()


main()
