"""Builds the fishing models: the pond's fish (raw and cooked), the crayfish, the fishing
rod, its float and the old rubber boot that comes up now and then.

    Blender -b --factory-startup --python tools/blender/make_fishing.py -- \
        --out art/models/fish [--boots <rubber_boots_1k.gltf>] [--only carp,rod]

(tools/fetch_fishing.py downloads the boot and runs this.)

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
    mouth = np.exp(-((E - (-0.08 - 0.9 * S)) / 0.035) ** 2) * (1.0 - smooth(0.035, 0.06, S))
    col *= (1.0 - 0.7 * mouth)[..., None]
    col = markings(cfg, rng, col, S, E, noise, nv, nu)
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
    return col


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
    rays_n = {"caudal": 18, "dorsal": 14, "paired": 12, "spiny": 13}[kind]
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
    if mark in ("trout", "zander", "pike") and kind in ("dorsal", "caudal", "spiny"):
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
    for key, job in jobs:
        if ONLY and key not in ONLY:
            continue
        reset()
        job()


main()
