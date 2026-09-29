"""Builds game trees from a Poly Haven tree model (see tools/fetch_trees.py, which runs it):

    Blender -b --factory-startup --python tools/blender/build_trees.py -- \
        --source <cache>/<asset>/<asset>_2k.gltf --asset <asset> --out art/models/trees

The source models are film assets: every needle and leaf is modelled (millions of
triangles). Each tree is turned into what a game can draw, keeping its real shape:

* Trunk and limbs: the real bark geometry, decimated into three levels of detail.
* Foliage: a "billboard cloud". The twigs and leaves are grouped into clusters
  (k-means on position and facing); each cluster becomes a card in the plane that
  fits it best (plus a crossing card where the cluster is thick), and the cluster's
  real geometry is rendered onto that card (colour + alpha and a normal map) into the
  tree's atlas. Three levels of detail: many small cards, fewer and bigger ones, few
  big ones. Seen from outside, the cards show the real tree.
* Crown shading: a leaf-density grid of the whole crown gives every point how much
  sky it sees ("openness"); it darkens the rendered foliage (self-shadowing deep in the
  crown) and goes to the cards' vertex colour for the game's shaders.
* Impostor: the whole tree rendered from 8 sides (colour + normals) for the far forest.

Writes to --out: <tree>.glb (objects trunk_lodN, branches_lodN, cards_lodN), the atlas
textures/<tree>_leaves(_nor).webp, the bark textures (textures/*.webp) and <tree>.json
(sizes and texture names); the impostor strips go to <cache>/_strips, and
`-- --compose <cache> --out <dir>` puts all trees' strips into textures/impostors(_nor).webp.
Blender units are metres, Z up (the glTF export turns them to Y up).
"""
import bmesh
import bpy
import hashlib
import json
import math
import os
import sys
import time

import numpy as np

# --- Per-source settings -------------------------------------------------------------
# nodes: glTF node -> game tree name. scale: uniform scale of the source. girth: trunk
# radius (m) the tree gets at 1.2 m height (the game's collision cylinder), or 0 to keep.
# card: target size of the finest cards (m). broad: deciduous (autumn, leaf fall).
SOURCES = {
    "fir_tree_01": {
        "nodes": {"fir_tree_01_a_LOD0": "fir_a", "fir_tree_01_b_LOD0": "fir_b", "fir_tree_01_c_LOD0": "fir_c"},
        "scale": 0.8, "girth": 0.3, "card": 0.75, "broad": False,
    },
    "pine_tree_01": {
        "nodes": {"pine_tree_01_a_LOD0": "pine_a", "pine_tree_01_b_LOD0": "pine_b", "pine_tree_01_c_LOD0": "pine_c"},
        "scale": 0.75, "girth": 0.3, "card": 0.75, "broad": False,
    },
    "tree_small_02": {
        "nodes": {"tree_small_02_LOD0": "broadleaf"},
        "scale": 1.7, "girth": 0.34, "card": 0.6, "broad": True,
    },
    "island_tree_01": {
        "nodes": {"island_tree_01_LOD0": "olive"},
        "scale": 1.35, "girth": 0.34, "card": 0.6, "broad": True,
    },
    "jacaranda_tree": {
        "nodes": {"jacaranda_tree_LOD0": "locust"},
        "scale": 0.55, "girth": 0.34, "card": 1.0, "broad": True,
    },
}

# Leaf-card atlas size (px): the smaller one unless it leaves the finest cards under
# MIN_DENSITY texels per metre. The normal map is half the size.
ATLAS_SIZES = (2048, 4096)
MIN_DENSITY = 110.0
PAD = 3                 # px of padding round each card in the atlas
LOD_DENSITY = [1.0, 0.55, 0.33]   # texel density of the card levels relative to LOD0
# Clusters per level relative to LOD0.
LOD_CLUSTERS = [1.0, 0.28, 0.1]
# Cards whose cluster is thicker than this (share of its width) get a crossing card.
CROSS_THICK = [0.32, 0.22, 0.0]
# Share of the limbs' surface kept per level of detail (biggest pieces first).
KEEP_AREA = [1.0, 0.55, 0.25]
# Biggest face (m^2) a limb keeps per level of detail (bigger ones are artefacts).
MAX_LIMB_FACE = [0.03, 0.06, 0.15]
# Wood triangles kept per level of detail.
WOOD_TRIS = {"trunk": [8000, 2000, 500], "branches": [9000, 2400, 200]}
# Source triangles per card render (memory: the biggest trees have 7 million).
BATCH_TRIS = 2500000
# The game's trees in impostor atlas order (NatureModels.TREES).
TREE_ORDER = ["fir_a", "fir_b", "fir_c", "pine_a", "pine_b", "pine_c", "broadleaf", "olive", "locust"]
IMP_VIEWS = 8
IMP_CELL = (256, 512)   # impostor frame (px), width x height: card height = 2 x width
IMP_SUPER = 2
SAMPLES = 16
OPEN_EXP = 0.85         # darkening of the rendered foliage: openness ^ OPEN_EXP


def log(*a):
    print("[trees]", *a, flush=True)


# --- Loading ---------------------------------------------------------------------------

def load_node(gltf_path, node_name):
    """Imports one node of the glTF (a filtered copy of the file, so the others are
    never built) and returns its mesh object, transforms applied."""
    with open(gltf_path) as f:
        g = json.load(f)
    node = [n for n in g["nodes"] if n.get("name") == node_name][0]
    node.pop("translation", None)
    node.pop("children", None)
    # Only this node (the importer builds every node of the file, in a scene or not).
    g["nodes"] = [node]
    g["scenes"] = [{"nodes": [0]}]
    g["scene"] = 0
    tmp = os.path.join(os.path.dirname(gltf_path), "_one_%s.gltf" % node_name)
    with open(tmp, "w") as f:
        json.dump(g, f)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _img_cache.clear()
    bpy.ops.import_scene.gltf(filepath=tmp)
    os.remove(tmp)
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    assert len(objs) == 1, [o.name for o in objs]
    return objs[0]


def material_info(mat, asset, tex_dir):
    """Textures of a source material: base colour, normal, ARM (and their UV map and
    mapping), and the cut-out map for leaves and twigs."""
    info = {"name": mat.name, "diff": None, "nor": None, "arm": None, "uv": None, "scale": (1.0, 1.0),
            "offset": (0.0, 0.0), "alpha": None, "vcol": False}
    nt = mat.node_tree
    for n in nt.nodes:
        if n.type == "TEX_IMAGE" and n.image:
            path = bpy.path.abspath(n.image.filepath)
            base = os.path.basename(path)
            if "_diff" in base:
                info["diff"] = path
            elif "_nor_gl" in base:
                info["nor"] = path
            elif "_arm" in base:
                info["arm"] = path
            # UV map and mapping in front of the image.
            vec = n.inputs["Vector"]
            if vec.is_linked:
                m = vec.links[0].from_node
                if m.type == "MAPPING":
                    s = m.inputs["Scale"].default_value
                    loc = m.inputs["Location"].default_value
                    info["scale"] = (s[0], s[1])
                    info["offset"] = (loc[0], loc[1])
                    if m.inputs["Vector"].is_linked:
                        uvn = m.inputs["Vector"].links[0].from_node
                        if uvn.type == "UVMAP":
                            info["uv"] = uvn.uv_map
                elif m.type == "UVMAP":
                    info["uv"] = m.uv_map
        if n.type == "VERTEX_COLOR" or (n.type == "ATTRIBUTE" and n.attribute_name.startswith("Col")):
            info["vcol"] = True
    low = mat.name.lower()
    if "twig" in low or "leaves" in low:
        key = "twig_alpha" if "twig" in low else "leaves_alpha"
        info["alpha"] = os.path.join(tex_dir, "%s_%s_2k.jpg" % (asset, key))
    return info


def classify(name):
    low = name.lower()
    if "twig" in low or "leaves" in low:
        return "foliage"
    if "trunk" in low or low.endswith(("island_tree_01", "island_tree_02", "island_tree_03")):
        return "trunk"
    if "dead" in low:
        return "branches"
    return "branches"


def mesh_arrays(obj):
    """Triangle soup data of an object: positions (V, 3), triangles (T, 3) vertex ids,
    triangle corners (T, 3) loop ids, material per triangle, UV layers per loop and the
    first colour attribute per loop (or None)."""
    me = obj.data
    me.calc_loop_triangles()
    nt = len(me.loop_triangles)
    tv = np.empty(nt * 3, np.int32)
    me.loop_triangles.foreach_get("vertices", tv)
    tl = np.empty(nt * 3, np.int32)
    me.loop_triangles.foreach_get("loops", tl)
    tp = np.empty(nt, np.int32)
    me.loop_triangles.foreach_get("polygon_index", tp)
    pm = np.empty(len(me.polygons), np.int32)
    me.polygons.foreach_get("material_index", pm)
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    uvs = {}
    for layer in me.uv_layers:
        uv = np.empty(len(me.loops) * 2, np.float32)
        layer.data.foreach_get("uv", uv)
        uvs[layer.name] = uv.reshape(-1, 2)
    col = None
    if len(me.color_attributes) > 0:
        ca = me.color_attributes[0]
        data = np.empty(len(ca.data) * 4, np.float32)
        ca.data.foreach_get("color", data)
        data = data.reshape(-1, 4)
        if ca.domain == "POINT":
            vl = np.empty(len(me.loops), np.int32)
            me.loops.foreach_get("vertex_index", vl)
            data = data[vl]
        col = data
    mats = [s.material for s in obj.material_slots]
    return co.reshape(-1, 3), tv.reshape(-1, 3), tl.reshape(-1, 3), pm[tp], uvs, col, mats


# --- Geometry helpers ------------------------------------------------------------------

def parts(faces, nv):
    """Connected piece of each triangle (label propagation with pointer jumping)."""
    lab = np.arange(nv)
    for _ in range(500):
        m = np.minimum(np.minimum(lab[faces[:, 0]], lab[faces[:, 1]]), lab[faces[:, 2]])
        new = lab.copy()
        for k in range(3):
            np.minimum.at(new, faces[:, k], m)
        new = new[new]
        new = new[new]
        if np.array_equal(new, lab):
            break
        lab = new
    _, part = np.unique(lab[faces[:, 0]], return_inverse=True)
    return part


def tri_normals(p):
    """Unit normals and areas of triangles p (T, 3, 3)."""
    n = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
    a = np.linalg.norm(n, axis=1)
    return n / np.maximum(a, 1e-12)[:, None], a * 0.5


def kmeans(x, w, k, iters=14, seed=1):
    """Weighted k-means on rows of x (subsampled); returns the centres."""
    rng = np.random.default_rng(seed)
    n = len(x)
    take = min(n, 120000)
    prob = w / w.sum()
    sub = x[rng.choice(n, take, replace=True, p=prob)]
    # k-means++ seeding on a smaller sample.
    seed_pts = sub[rng.choice(take, min(take, 20000), replace=False)]
    centers = [seed_pts[rng.integers(len(seed_pts))]]
    d2 = np.sum((seed_pts - centers[0]) ** 2, axis=1)
    for _ in range(1, k):
        c = seed_pts[rng.choice(len(seed_pts), p=d2 / d2.sum())]
        centers.append(c)
        d2 = np.minimum(d2, np.sum((seed_pts - c) ** 2, axis=1))
    centers = np.array(centers)
    for _ in range(iters):
        lab = assign(sub, centers)
        for j in range(k):
            m = lab == j
            if m.any():
                centers[j] = sub[m].mean(axis=0)
    return centers


def assign(x, centers, chunk=50000):
    out = np.empty(len(x), np.int32)
    cc = np.sum(centers ** 2, axis=1)
    for i in range(0, len(x), chunk):
        xs = x[i:i + chunk]
        d = cc[None, :] - 2.0 * xs @ centers.T
        out[i:i + chunk] = np.argmin(d, axis=1)
    return out


class Grid:
    """Leaf density of the crown on a voxel grid, and how much sky each point sees."""

    def __init__(self, lo, hi, h):
        self.lo = lo - h * 2
        self.h = h
        self.n = np.ceil((hi - self.lo) / h).astype(int) + 3
        self.dens = np.zeros(self.n, np.float32)

    def add(self, pts, amount):
        ijk = np.clip(((pts - self.lo) / self.h).astype(int), 0, self.n - 1)
        np.add.at(self.dens, (ijk[:, 0], ijk[:, 1], ijk[:, 2]), amount)

    def sample(self, grid, pts):
        """Trilinear sample of `grid` (same shape as dens) at pts."""
        f = (pts - self.lo) / self.h - 0.5
        i0 = np.clip(np.floor(f).astype(int), 0, self.n - 2)
        t = np.clip(f - i0, 0.0, 1.0)
        out = np.zeros(len(pts), np.float32)
        for dx in (0, 1):
            wx = t[:, 0] if dx else 1 - t[:, 0]
            for dy in (0, 1):
                wy = t[:, 1] if dy else 1 - t[:, 1]
                for dz in (0, 1):
                    wz = t[:, 2] if dz else 1 - t[:, 2]
                    out += wx * wy * wz * grid[i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz]
        return out

    def openness(self, extinction):
        """Share of the (upward weighted) sky seen from every voxel centre, through the
        leaf density (extinction per m^2 of leaf area per m^3)."""
        sigma = self.dens / (self.h ** 3) * extinction
        nd = 40
        i = np.arange(nd) + 0.5
        phi = np.arccos(1 - 2 * i / nd)
        theta = math.pi * (1 + 5 ** 0.5) * i
        dirs = np.stack([np.cos(theta) * np.sin(phi), np.sin(theta) * np.sin(phi), np.cos(phi)], axis=1)
        wts = np.maximum(0.12, 0.35 + 0.65 * dirs[:, 2])
        wts /= wts.sum()
        idx = np.stack(np.meshgrid(np.arange(self.n[0]), np.arange(self.n[1]), np.arange(self.n[2]), indexing="ij"), -1)
        centers = idx.reshape(-1, 3).astype(np.float32) + 0.5
        out = np.zeros(len(centers), np.float32)
        steps = int(np.max(self.n) * 1.8)
        chunk = 4000
        flat = sigma.ravel()
        nx, ny, nz = self.n
        for c0 in range(0, len(centers), chunk):
            c = centers[c0:c0 + chunk]
            acc = np.zeros((len(c), nd), np.float32)
            for s in range(1, steps):
                p = c[:, None, :] + dirs[None, :, :] * (s * 0.75)
                ii = p.astype(int)
                inside = (ii[..., 0] >= 0) & (ii[..., 0] < nx) & (ii[..., 1] >= 0) & (ii[..., 1] < ny) \
                    & (ii[..., 2] >= 0) & (ii[..., 2] < nz)
                if not inside.any():
                    break
                ii = np.where(inside[..., None], ii, 0)
                v = flat[(ii[..., 0] * ny + ii[..., 1]) * nz + ii[..., 2]]
                acc += np.where(inside, v, 0.0) * (0.75 * self.h)
            out[c0:c0 + chunk] = np.exp(-acc) @ wts
        return out.reshape(self.n)


# --- Mesh creation -----------------------------------------------------------------------

def new_mesh(name, verts, faces, loop_uvs=None, loop_cols=None, mat_index=None, smooth=False):
    """Mesh from numpy: verts (V, 3), faces (F, 3) vertex ids; per-corner uv layers
    {name: (F*3, 2)} and colour attributes {name: (F*3, 4)}."""
    me = bpy.data.meshes.new(name)
    nf = len(faces)
    me.vertices.add(len(verts))
    me.vertices.foreach_set("co", np.ascontiguousarray(verts, np.float32).ravel())
    me.loops.add(nf * 3)
    me.loops.foreach_set("vertex_index", np.ascontiguousarray(faces, np.int32).ravel())
    me.polygons.add(nf)
    me.polygons.foreach_set("loop_start", np.arange(0, nf * 3, 3, dtype=np.int32))
    if mat_index is not None:
        me.polygons.foreach_set("material_index", np.ascontiguousarray(mat_index, np.int32))
    me.polygons.foreach_set("use_smooth", np.full(nf, smooth, bool))
    for uname, uv in (loop_uvs or {}).items():
        layer = me.uv_layers.new(name=uname)
        layer.data.foreach_set("uv", np.ascontiguousarray(uv, np.float32).ravel())
    for cname, col in (loop_cols or {}).items():
        attr = me.color_attributes.new(cname, "FLOAT_COLOR", "CORNER")
        attr.data.foreach_set("color", np.ascontiguousarray(col, np.float32).ravel())
    me.update(calc_edges=True)
    return me


def link(name, me, mats=()):
    obj = bpy.data.objects.new(name, me)
    for m in mats:
        obj.data.materials.append(m)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# --- Render materials ---------------------------------------------------------------------

_img_cache = {}


def image(path, color=True):
    key = (path, color)
    if key not in _img_cache:
        img = bpy.data.images.load(path, check_existing=False)
        img.colorspace_settings.name = "sRGB" if color else "Non-Color"
        img.alpha_mode = "NONE"
        _img_cache[key] = img
    return _img_cache[key]


def render_material(info, mode, uv_name):
    """Unlit render of a source material. mode 'color': base colour x vertex colour x
    openness^OPEN_EXP, cut out; mode 'normal': the surface normal (with the texture's
    normal map) in camera space turned to face the camera, as a normal-map colour."""
    mat = bpy.data.materials.new("%s_%s" % (info["name"], mode))
    mat.use_nodes = True
    mat.surface_render_method = "DITHERED"
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    uvn = nt.nodes.new("ShaderNodeUVMap")
    uvn.uv_map = uv_name
    # The source's texture transform is already in the UVs (see foliage_uvs).
    alpha_socket = None
    if info["alpha"]:
        ta = nt.nodes.new("ShaderNodeTexImage")
        ta.image = image(info["alpha"], False)
        nt.links.new(uvn.outputs["UV"], ta.inputs["Vector"])
        alpha_socket = ta.outputs["Color"]
    emit = nt.nodes.new("ShaderNodeEmission")
    if mode == "color":
        td = nt.nodes.new("ShaderNodeTexImage")
        td.image = image(info["diff"], True)
        nt.links.new(uvn.outputs["UV"], td.inputs["Vector"])
        col = td.outputs["Color"]
        ao = nt.nodes.new("ShaderNodeAttribute")
        ao.attribute_name = "shade"
        mul = nt.nodes.new("ShaderNodeVectorMath")
        mul.operation = "MULTIPLY"
        nt.links.new(col, mul.inputs[0])
        nt.links.new(ao.outputs["Color"], mul.inputs[1])
        nt.links.new(mul.outputs[0], emit.inputs["Color"])
    else:
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.space = "TANGENT"
        nm.uv_map = uv_name
        if info["nor"]:
            tn = nt.nodes.new("ShaderNodeTexImage")
            tn.image = image(info["nor"], False)
            nt.links.new(uvn.outputs["UV"], tn.inputs["Vector"])
            nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
            nm.inputs["Strength"].default_value = 0.8
        vt = nt.nodes.new("ShaderNodeVectorTransform")
        vt.vector_type = "NORMAL"
        vt.convert_from = "WORLD"
        vt.convert_to = "CAMERA"
        nt.links.new(nm.outputs["Normal"], vt.inputs["Vector"])
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(vt.outputs["Vector"], sep.inputs["Vector"])
        # Blender's camera space looks down -Z: facing the camera is +Z.
        sgn = nt.nodes.new("ShaderNodeMath")
        sgn.operation = "SIGN"
        nt.links.new(sep.outputs["Z"], sgn.inputs[0])
        fix = nt.nodes.new("ShaderNodeMath")
        fix.operation = "ADD"
        fix.inputs[1].default_value = 0.001
        nt.links.new(sgn.outputs[0], fix.inputs[0])
        sgn2 = nt.nodes.new("ShaderNodeMath")
        sgn2.operation = "SIGN"
        nt.links.new(fix.outputs[0], sgn2.inputs[0])
        flip = nt.nodes.new("ShaderNodeVectorMath")
        flip.operation = "SCALE"
        nt.links.new(vt.outputs["Vector"], flip.inputs[0])
        nt.links.new(sgn2.outputs[0], flip.inputs["Scale"])
        norm = nt.nodes.new("ShaderNodeVectorMath")
        norm.operation = "NORMALIZE"
        nt.links.new(flip.outputs[0], norm.inputs[0])
        enc = nt.nodes.new("ShaderNodeVectorMath")
        enc.operation = "MULTIPLY_ADD"
        enc.inputs[1].default_value = (0.5, 0.5, 0.5)
        enc.inputs[2].default_value = (0.5, 0.5, 0.5)
        nt.links.new(norm.outputs[0], enc.inputs[0])
        nt.links.new(enc.outputs[0], emit.inputs["Color"])
    if alpha_socket is not None:
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(alpha_socket, mix.inputs["Fac"])
        nt.links.new(tr.outputs[0], mix.inputs[1])
        nt.links.new(emit.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])
    else:
        nt.links.new(emit.outputs[0], out.inputs["Surface"])
    return mat


def setup_render(w, h, mode):
    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE_NEXT"
    s.eevee.taa_render_samples = SAMPLES
    s.render.resolution_x = w
    s.render.resolution_y = h
    s.render.resolution_percentage = 100
    s.render.film_transparent = True
    s.render.filter_size = 0.9
    s.render.dither_intensity = 0.0
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"
    s.render.image_settings.color_depth = "8"
    s.view_settings.view_transform = "Standard" if mode == "color" else "Raw"
    s.view_settings.look = "None"
    s.view_settings.exposure = 0.0
    s.view_settings.gamma = 1.0
    s.display_settings.display_device = "sRGB"
    s.sequencer_colorspace_settings.name = "sRGB"
    if s.world is None:
        s.world = bpy.data.worlds.new("w")
    s.world.use_nodes = True
    bg = s.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Strength"].default_value = 0.0


def ortho_camera(loc, rot, scale, clip):
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = scale
    cam_data.clip_start = 0.01
    cam_data.clip_end = clip
    cam = bpy.data.objects.new("cam", cam_data)
    cam.location = loc
    cam.rotation_euler = rot
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def render_to(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def read_png(path):
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    # Blender's pixel rows start at the bottom.
    return px.reshape(h, w, 4)[::-1].copy()


def write_image(path, px, fmt="PNG", quality=90):
    """Saves px (rows from the top, RGBA floats 0..1, stored as they are)."""
    h, w = px.shape[:2]
    img = bpy.data.images.new("out", w, h, alpha=True, float_buffer=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.ascontiguousarray(px[::-1], np.float32).ravel())
    img.filepath_raw = path
    img.file_format = fmt
    s = bpy.context.scene
    s.render.image_settings.file_format = fmt
    s.render.image_settings.color_mode = "RGBA"
    s.render.image_settings.quality = quality
    if fmt == "WEBP":
        s.render.image_settings.color_depth = "8"
    img.save_render(path, scene=s)
    bpy.data.images.remove(img)


def dilate(px, steps=12):
    """Spreads the colour of opaque pixels into the transparent ones round them, so the
    mipmaps don't bleed black into the leaves' edges."""
    rgb = px[..., :3] * (px[..., 3:4] > 0.02)
    have = (px[..., 3] > 0.02).astype(np.float32)
    for _ in range(steps):
        acc = np.zeros_like(rgb)
        cnt = np.zeros_like(have)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            acc += np.roll(np.roll(rgb * have[..., None], dy, 0), dx, 1)
            cnt += np.roll(np.roll(have, dy, 0), dx, 1)
        fill = (have == 0) & (cnt > 0)
        rgb[fill] = acc[fill] / cnt[fill][:, None]
        have[fill] = 1.0
    out = px.copy()
    out[..., :3] = np.where(px[..., 3:4] > 0.02, px[..., :3], rgb)
    return out


# --- Cards -------------------------------------------------------------------------------

def pca_frame(pts, wts, face_n):
    c = (pts * wts[:, None]).sum(0) / wts.sum()
    d = pts - c
    cov = (d * wts[:, None]).T @ d / wts.sum()
    ev, evec = np.linalg.eigh(cov)
    u = evec[:, 2]
    n = evec[:, 0]
    if np.dot(n, face_n) < 0:
        n = -n
    v = np.cross(n, u)
    return c, u, v, n, np.sqrt(np.maximum(ev, 0.0))


def make_cards(fol_p, fol_n, fol_a, fol_id, wood_p, wood_id, level, count, crown, rng, thick):
    """Clusters the foliage triangles into `count` cards. Returns a list of cards:
    dict(o, u, v, n, ext=(u0, u1, v0, v1), tris=(foliage ids, wood ids), level)."""
    cen = fol_p.mean(axis=1)
    axis_c = np.array([0.0, 0.0])
    radial = cen.copy()
    radial[:, :2] -= axis_c
    radial[:, 2] = 0.3 * np.linalg.norm(radial[:, :2], axis=1) + 0.3
    out_dir = radial / np.maximum(np.linalg.norm(radial, axis=1), 1e-6)[:, None]
    nsign = np.where(np.sum(fol_n * out_dir, axis=1) < 0, -1.0, 1.0)
    nn = fol_n * nsign[:, None]
    scale = crown["size"] / max(count, 1) ** (1.0 / 3.0)
    feat = np.concatenate([cen / scale, nn * 0.42], axis=1).astype(np.float32)
    centers = kmeans(feat, fol_a, count, seed=level * 7 + 3)
    lab = assign(feat, centers)
    # Branch pieces inside a cluster's box go onto its cards too.
    wood_cen = wood_p.mean(axis=1) if len(wood_p) else np.zeros((0, 3))
    cards = []
    order = np.argsort(lab, kind="stable")
    bounds = np.searchsorted(lab[order], np.arange(count + 1))
    for j in range(count):
        ids = order[bounds[j]:bounds[j + 1]]
        if len(ids) < 8:
            continue
        pts = fol_p[ids].reshape(-1, 3)
        w = np.repeat(fol_a[ids], 3) + 1e-9
        face = (nn[ids] * fol_a[ids, None]).sum(0)
        c, u, v, n, sig = pca_frame(pts, w, face)
        if np.dot(n, c - np.array([0, 0, c[2]])) < -0.2 * np.linalg.norm(c[:2]):
            pass
        pu = (pts - c) @ u
        pv = (pts - c) @ v
        pn = (pts - c) @ n
        # Trim the few stray triangles that would blow the card up.
        u0, u1 = np.percentile(pu, [0.5, 99.5])
        v0, v1 = np.percentile(pv, [0.5, 99.5])
        t0, t1 = np.percentile(pn, [1, 99])
        wsel = np.zeros(0, np.int64)
        if len(wood_cen):
            d = wood_cen - c
            wu, wv, wn = d @ u, d @ v, d @ n
            m = (wu > u0) & (wu < u1) & (wv > v0) & (wv < v1) & (wn > t0 - 0.05) & (wn < t1 + 0.05)
            wsel = np.nonzero(m)[0]
        cards.append({"o": c, "u": u, "v": v, "n": n, "ext": (u0, u1, v0, v1), "fol": ids, "wood": wsel,
                      "level": level, "cluster": j})
        width = max(sig[1], 1e-3)
        if sig[0] / width > thick:
            # Crossing card through the cluster's long axis, facing along v.
            nb = v if np.dot(v, c - np.array([0, 0, c[2]])) >= 0 else -v
            ub = u
            vb = np.cross(nb, ub)
            qu = (pts - c) @ ub
            qv = (pts - c) @ vb
            b0, b1 = np.percentile(qu, [0.5, 99.5])
            e0, e1 = np.percentile(qv, [0.5, 99.5])
            cards.append({"o": c, "u": ub, "v": vb, "n": nb, "ext": (b0, b1, e0, e1), "fol": ids, "wood": wsel,
                          "level": level, "cluster": j, "cross": True})
    return cards


def pack(sizes, atlas):
    """Shelf packing of (w, h) px rects (padding included) into atlas x atlas. Returns
    positions or None if they don't fit."""
    order = sorted(range(len(sizes)), key=lambda i: -sizes[i][1])
    pos = [None] * len(sizes)
    x = y = shelf = 0
    for i in order:
        w, h = sizes[i]
        if w > atlas:
            return None
        if x + w > atlas:
            y += shelf
            x = 0
            shelf = 0
        if y + h > atlas:
            return None
        pos[i] = (x, y)
        x += w
        shelf = max(shelf, h)
    return pos


def octa(n):
    """Octahedral encoding of unit vectors (N, 3) into [0, 1]^2 (Y up, as in the game)."""
    n = n / np.sum(np.abs(n), axis=1, keepdims=True)
    x, y = n[:, 0].copy(), n[:, 2].copy()
    neg = n[:, 1] < 0
    ox = (1 - np.abs(y)) * np.sign(x + 1e-9)
    oy = (1 - np.abs(x)) * np.sign(y + 1e-9)
    x = np.where(neg, ox, x)
    y = np.where(neg, oy, y)
    return np.stack([x, y], axis=1) * 0.5 + 0.5


# --- Main build --------------------------------------------------------------------------

def build_tree(gltf, asset, node, tree, cfg, out_dir):
    t0 = time.time()
    tex_dir = os.path.join(os.path.dirname(gltf), "textures")
    obj = load_node(gltf, node)
    co, tv, tl, tmat, uvs, vcol, mats = mesh_arrays(obj)
    infos = [material_info(m, asset, tex_dir) for m in mats]
    roles = [classify(m.name) for m in mats]
    log(tree, "source", len(tv), "triangles", [(m.name, r) for m, r in zip(mats, roles)], "vcol", vcol is not None)

    # Stand the tree on the origin, scaled.
    trunk_tris = np.isin(tmat, [i for i, r in enumerate(roles) if r == "trunk"])
    tp = co[tv[trunk_tris].ravel()]
    base = tp[tp[:, 2] < tp[:, 2].min() + 0.6]
    off = np.array([base[:, 0].mean(), base[:, 1].mean(), 0.0], np.float32)
    co = (co - off) * cfg["scale"]
    # Trunk girth at 1.2 m to the game's collision radius, fading out up the trunk.
    if cfg["girth"] > 0:
        tp = co[np.unique(tv[trunk_tris].ravel())]
        band = tp[(tp[:, 2] > 1.0) & (tp[:, 2] < 1.4)]
        cxy = band[:, :2].mean(axis=0)
        r = np.median(np.linalg.norm(band[:, :2] - cxy, axis=1))
        f = float(np.clip(cfg["girth"] / max(r, 0.01), 0.6, 2.2))
        wood_v = np.unique(tv[~np.isin(tmat, [i for i, rr in enumerate(roles) if rr == "foliage"])].ravel())
        z = co[wood_v, 2]
        # A natural taper: full at the foot, none by 70 % of the height.
        top = float(co[:, 2].max()) * 0.7
        k = 1.0 + (f - 1.0) * (1.0 - np.clip((z - 1.2) / max(top - 1.2, 1.0), 0.0, 1.0)) ** 1.5
        d = co[wood_v, :2] - cxy
        dist = np.linalg.norm(d, axis=1)
        # Only the trunk column (not limbs far out) is scaled.
        near = np.clip(1.0 - (dist - r * 2.5) / (r * 2.0), 0.0, 1.0)
        kk = 1.0 + (k - 1.0) * near
        co[wood_v, :2] = cxy + d * kk[:, None]
        log(tree, "trunk radius %.3f -> x%.2f" % (r, f))

    fol_mask = np.isin(tmat, [i for i, r in enumerate(roles) if r == "foliage"])
    wood_mask = ~fol_mask
    height = float(co[:, 2].max())
    radius = float(np.linalg.norm(co[:, :2], axis=1).max())
    fol_pts = co[tv[fol_mask].ravel()]
    crown_lo = fol_pts.min(axis=0)
    crown_hi = fol_pts.max(axis=0)
    crown_c = (crown_lo + crown_hi) * 0.5
    crown_r = np.maximum((crown_hi - crown_lo) * 0.5, 0.5)
    crown = {"c": crown_c, "r": crown_r, "size": float(np.cbrt(np.prod(crown_hi - crown_lo)))}
    log(tree, "height %.2f radius %.2f crown %s" % (height, radius, np.round(crown_r, 2)))

    # UVs per corner with each material's texture transform (and its UV map).
    names = list(uvs.keys())
    loop_uv = np.zeros((len(tv), 3, 2), np.float32)
    for mi, info in enumerate(infos):
        sel = tmat == mi
        layer = uvs[info["uv"]] if info["uv"] in uvs else uvs[names[0]]
        uv = layer[tl[sel]]
        uv = uv * np.array(info["scale"], np.float32) + np.array(info["offset"], np.float32)
        loop_uv[sel] = uv
    loop_col = vcol[tl] if vcol is not None else None
    if loop_col is not None:
        log(tree, "vertex colour mean", np.round(loop_col.reshape(-1, 4).mean(0), 3), "min",
            np.round(loop_col.reshape(-1, 4).min(0), 3))

    # Openness of the crown.
    tri_p = co[tv]
    tri_n, tri_a = tri_normals(tri_p)
    h = max(0.18, min(0.35, height / 60.0))
    grid = Grid(co.min(axis=0), co.max(axis=0), h)
    cov = np.where(fol_mask, 0.55, 0.35).astype(np.float32)
    grid.add(tri_p.mean(axis=1), tri_a * cov)
    op_grid = grid.openness(0.5)
    vert_open = grid.sample(op_grid, co)
    log(tree, "openness grid", grid.n, "range %.2f..%.2f" % (vert_open.min(), vert_open.max()), "%.0fs" % (time.time() - t0))

    # Shade: openness ^ OPEN_EXP (x the source's vertex colour), per corner.
    shade = np.power(np.clip(vert_open[tv], 0.0, 1.0), OPEN_EXP)
    shade_rgba = np.repeat(shade[..., None], 4, axis=2)
    shade_rgba[..., 3] = 1.0
    if loop_col is not None:
        shade_rgba[..., :3] *= loop_col[..., :3]

    # --- Cards -------------------------------------------------------------------------
    rng = np.random.default_rng(5)
    fol_ids = np.nonzero(fol_mask)[0]
    # Only limbs, not the trunk, go onto the cards.
    branch_ids = np.nonzero(wood_mask & ~trunk_tris)[0]
    fp = tri_p[fol_ids]
    fnrm = tri_n[fol_ids]
    fa = tri_a[fol_ids]
    wp = tri_p[branch_ids]
    occupied = np.unique(np.floor(fp.mean(axis=1) / cfg["card"]).astype(int), axis=0)
    k0 = int(np.clip(len(occupied) * 1.1, 60, 520))
    all_cards = []
    for level in range(3):
        k = max(10, int(k0 * LOD_CLUSTERS[level]))
        cards = make_cards(fp, fnrm, fa, fol_ids, wp, branch_ids, level, k, crown, rng, CROSS_THICK[level]
                           if CROSS_THICK[level] > 0 else 1e-6)
        log(tree, "LOD%d: %d clusters -> %d cards" % (level, k, len(cards)))
        all_cards += cards

    # Pack: the biggest texel density that fits.
    def sizes_for(d0):
        out = []
        for c in all_cards:
            d = d0 * LOD_DENSITY[c["level"]]
            u0, u1, v0, v1 = c["ext"]
            out.append((int(math.ceil((u1 - u0) * d)) + PAD * 2, int(math.ceil((v1 - v0) * d)) + PAD * 2))
        return out
    for ATLAS in ATLAS_SIZES:
        lo_d, hi_d = 10.0, 2000.0
        for _ in range(22):
            mid = (lo_d + hi_d) * 0.5
            if pack(sizes_for(mid), ATLAS) is None:
                hi_d = mid
            else:
                lo_d = mid
        d0 = lo_d
        if d0 >= MIN_DENSITY:
            break
    sizes = sizes_for(d0)
    pos = pack(sizes, ATLAS)
    log(tree, "atlas %d, density %.0f px/m (LOD0)" % (ATLAS, d0))

    # --- Render the cards into the atlas ------------------------------------------------
    # The source object is kept (hidden) for the impostor renders: it gets the stood-up
    # positions, the UVs with the texture transforms and the shade per corner.
    me_src = obj.data
    me_src.vertices.foreach_set("co", co.ravel())
    lay_uv = me_src.uv_layers.new(name="UV")
    uv_loops = np.zeros((len(me_src.loops), 2), np.float32)
    uv_loops[tl.ravel()] = loop_uv.reshape(-1, 2)
    lay_uv.data.foreach_set("uv", uv_loops.ravel())
    sh_attr = me_src.color_attributes.new("shade", "FLOAT_COLOR", "CORNER")
    sh_loops = np.ones((len(me_src.loops), 4), np.float32)
    sh_loops[tl.ravel()] = shade_rgba.reshape(-1, 4)
    sh_attr.data.foreach_set("color", sh_loops.ravel())
    del uv_loops, sh_loops
    me_src.update()
    obj.hide_render = True
    del tri_n
    rmats_color = [render_material(i, "color", "UV") for i in infos]
    rmats_nor = [render_material(i, "normal", "UV") for i in infos]
    BU = 0.01   # blender units per atlas pixel
    color_acc = np.zeros((ATLAS, ATLAS, 4), np.float32)
    nor_acc = np.zeros((ATLAS, ATLAS, 4), np.float32)
    setup_render(ATLAS, ATLAS, "color")
    cam = ortho_camera((ATLAS * BU * 0.5, ATLAS * BU * 0.5, 500.0), (0, 0, 0), ATLAS * BU, 1000.0)
    tmp_dir = os.path.join(os.path.dirname(gltf), "_render")
    os.makedirs(tmp_dir, exist_ok=True)
    card_verts = {0: [], 1: [], 2: []}
    # Batches of cards of at most BATCH_TRIS source triangles per render (memory).
    batches = []
    for level in range(3):
        cur, count = [], 0
        for i, c in enumerate(all_cards):
            if c["level"] != level:
                continue
            n = len(c["fol"]) + len(c["wood"])
            if cur and count + n > BATCH_TRIS:
                batches.append((level, cur))
                cur, count = [], 0
            cur.append(i)
            count += n
        if cur:
            batches.append((level, cur))
    for bi, (level, idx_cards) in enumerate(batches):
        vs, fs, us, cs, ms = [], [], [], [], []
        base_v = 0
        for ci in idx_cards:
            c = all_cards[ci]
            d = d0 * LOD_DENSITY[level]
            x0, y0 = pos[ci]
            u0, u1, v0, v1 = c["ext"]
            tris = np.concatenate([fol_ids[c["fol"]], branch_ids[c["wood"]]])
            p = tri_p[tris].reshape(-1, 3) - c["o"]
            px_x = x0 + PAD + (p @ c["u"] - u0) * d
            px_y = y0 + PAD + (v1 - p @ c["v"]) * d
            px_z = (p @ c["n"]) * d
            vs.append(np.stack([px_x * BU, (ATLAS - px_y) * BU, px_z * BU], axis=1))
            n = len(tris)
            fs.append(np.arange(n * 3, dtype=np.int32).reshape(-1, 3) + base_v)
            base_v += n * 3
            us.append(loop_uv[tris].reshape(-1, 2))
            cs.append(shade_rgba[tris].reshape(-1, 4))
            ms.append(tmat[tris])
            # The card in the tree.
            w_px = (u1 - u0) * d
            h_px = (v1 - v0) * d
            corners = []
            for (a, b) in ((u0, v0), (u1, v0), (u1, v1), (u0, v1)):
                corners.append(c["o"] + c["u"] * a + c["v"] * b)
            uv_rect = ((x0 + PAD) / ATLAS, (y0 + PAD) / ATLAS, (x0 + PAD + w_px) / ATLAS, (y0 + PAD + h_px) / ATLAS)
            card_verts[level].append((np.array(corners), c["n"], c["u"], uv_rect, c))
        if not vs:
            continue
        me = new_mesh("layout%d" % bi, np.concatenate(vs), np.concatenate(fs), {"UV": np.concatenate(us)},
                      {"shade": np.concatenate(cs)}, np.concatenate(ms))
        del vs, fs, us, cs, ms
        lay = link("layout%d" % bi, me, rmats_color)
        for mode, acc in (("color", color_acc), ("normal", nor_acc)):
            setup_render(ATLAS, ATLAS, mode)
            # (Swapped in place: clearing the slots would reset the faces' material index.)
            for mi, m in enumerate(rmats_color if mode == "color" else rmats_nor):
                lay.data.materials[mi] = m
            path = os.path.join(tmp_dir, "%s_b%d_%s.png" % (tree, bi, mode))
            render_to(path)
            # The levels' cards are in separate places in the atlas.
            acc += read_png(path)
        bpy.data.objects.remove(lay)
        bpy.data.meshes.remove(me)
        log(tree, "rendered LOD%d cards, batch %d/%d (%.0fs)" % (level, bi + 1, len(batches), time.time() - t0))
    tex_out = os.path.join(out_dir, "textures")
    os.makedirs(tex_out, exist_ok=True)
    color_acc = dilate(color_acc)
    nor_acc[..., 3] = color_acc[..., 3]
    nor_fill = dilate(nor_acc)
    empty = nor_fill[..., 3] <= 0.02
    nor_fill[empty, :3] = (0.5, 0.5, 1.0)
    nor_fill[..., 3] = 1.0
    write_image(os.path.join(tex_out, "%s_leaves.webp" % tree), color_acc, "WEBP", 85)
    half = ATLAS // 2
    nor_half = nor_fill.reshape(half, 2, half, 2, 4).mean((1, 3))
    write_image(os.path.join(tex_out, "%s_leaves_nor.webp" % tree), nor_half, "WEBP", 90)
    del color_acc, nor_acc, nor_fill

    # --- Card meshes ------------------------------------------------------------------
    for level in range(3):
        verts, faces, uv0, uv1, cols = [], [], [], [], []
        for k, (corners, n, u, rect, c) in enumerate(card_verts[level]):
            b = len(verts) * 4
            op = grid.sample(op_grid, corners * 0.8 + c["o"] * 0.2)
            rnd = rng.random()
            rel = (corners - crown["c"]) / crown["r"]
            cn = rel / np.maximum(np.linalg.norm(rel, axis=1, keepdims=True), 1e-6)
            cn = cn / crown["r"]
            cn /= np.linalg.norm(cn, axis=1, keepdims=True)
            # Blender Z up -> the game's Y up for the encoded crown normal.
            cn_game = np.stack([cn[:, 0], cn[:, 2], -cn[:, 1]], axis=1)
            oc = octa(cn_game)
            bend = np.clip(corners[:, 2] / height, 0, 1) ** 2
            reach = np.clip(np.linalg.norm(corners[:, :2], axis=1) / max(radius, 0.5), 0, 1)
            verts.append(corners)
            faces += [(b, b + 1, b + 2), (b, b + 2, b + 3)]
            x0, y0, x1, y1 = rect
            # Blender UV v runs up; the atlas rows run down.
            uv0 += [(x0, 1 - y1), (x1, 1 - y1), (x1, 1 - y0), (x0, 1 - y0)]
            for q in range(4):
                # glTF flips v on export.
                uv1.append((oc[q][0], 1.0 - oc[q][1]))
                cols.append((op[q], bend[q], rnd, reach[q]))
        if not verts:
            continue
        V = np.concatenate(verts)
        F = np.array(faces, np.int32)
        loop_uv0 = np.array(uv0, np.float32)[F.ravel()]
        loop_uv1 = np.array(uv1, np.float32)[F.ravel()]
        loop_col = np.array(cols, np.float32)[F.ravel()]
        me = new_mesh("cards_lod%d" % level, V, F, {"UV": loop_uv0, "CROWN": loop_uv1}, {"Col": loop_col})
        link("cards_lod%d" % level, me)

    # --- Wood --------------------------------------------------------------------------
    wood_ids = np.nonzero(wood_mask)[0]
    wmats = {}
    for role in ("trunk", "branches"):
        sel = wood_ids[[roles[tmat[i]] == role for i in wood_ids]]
        if len(sel) == 0:
            continue
        # One material per role: the most used source material's textures.
        counts = np.bincount(tmat[sel], minlength=len(mats))
        main = int(np.argmax(counts))
        wmats[role] = infos[main]
        # Limbs: the coarser levels keep only the biggest pieces (the small twigs are on
        # the cards; collapsing them would leave thousands of slivers).
        part = parts(tv[sel], len(co)) if role == "branches" else np.zeros(len(sel), np.int64)
        area = np.bincount(part, weights=tri_a[sel])
        order = np.argsort(-area)
        cum = np.cumsum(area[order]) / max(area.sum(), 1e-9)
        for level in range(3):
            keep_parts = order[:int(np.searchsorted(cum, KEEP_AREA[level])) + 1]
            ks = sel[np.isin(part, keep_parts)]
            used = np.unique(tv[ks].ravel())
            remap = np.full(len(co), -1, np.int64)
            remap[used] = np.arange(len(used))
            V = co[used]
            F = remap[tv[ks]]
            luv = loop_uv[ks].reshape(-1, 2)
            vo = vert_open[used]
            bend = np.clip(V[:, 2] / height, 0, 1) ** 2
            reach = np.clip(np.linalg.norm(V[:, :2], axis=1) / max(radius, 0.5), 0, 1)
            col = np.stack([vo, bend, np.zeros_like(vo), reach], axis=1)[F.ravel()]
            me = new_mesh("%s_lod%d" % (role, level), V, F, {"UV": luv}, {"Col": col}, smooth=True)
            ob = link("%s_lod%d" % (role, level), me)
            total = len(F)
            target = min(total, WOOD_TRIS[role][level])
            if target < total:
                mod = ob.modifiers.new("dec", "DECIMATE")
                mod.decimate_type = "COLLAPSE"
                mod.ratio = target / total
                mod.use_collapse_triangulate = True
                bpy.context.view_layer.objects.active = ob
                with bpy.context.temp_override(object=ob, active_object=ob):
                    bpy.ops.object.modifier_apply(modifier="dec")
            if role == "branches":
                # Decimating thin limbs leaves the odd big flat face bridging them.
                bm = bmesh.new()
                bm.from_mesh(ob.data)
                big = [f for f in bm.faces if f.calc_area() > MAX_LIMB_FACE[level]]
                bmesh.ops.delete(bm, geom=big, context="FACES")
                bm.to_mesh(ob.data)
                bm.free()
            log(tree, "%s LOD%d: %d triangles" % (role, level, len(ob.data.polygons)))

    # --- Export --------------------------------------------------------------------------
    for o in bpy.data.objects:
        o.select_set(o.type == "MESH" and (o.name.startswith(("cards_", "trunk_lod", "branches_lod"))))
        if o.type == "MESH" and o.name.startswith(("cards_", "trunk_lod", "branches_lod")):
            ca = o.data.color_attributes.get("Col")
            if ca:
                o.data.color_attributes.active_color = ca
                o.data.attributes.default_color_name = "Col"
    glb = os.path.join(out_dir, "%s.glb" % tree)
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_apply=False,
                              export_texcoords=True, export_normals=True, export_tangents=False,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=True,
                              export_materials="NONE", export_yup=True, export_animations=False)
    log(tree, "wrote", glb, "%.1f MB" % (os.path.getsize(glb) / 1e6))

    # Bark textures (webp, 2k trunk, 1k limbs). The pines share some of the firs' maps:
    # a source file already written under another name is reused (hashes kept in the
    # cache).
    hash_path = os.path.join(os.path.dirname(os.path.dirname(gltf)), "_bark_hashes.json")
    hashes = json.load(open(hash_path)) if os.path.exists(hash_path) else {}
    tex_names = {}
    for role, info in wmats.items():
        tex_names[role] = {}
        for key in ("diff", "nor", "arm"):
            src_path = info[key]
            if not src_path:
                continue
            name = os.path.splitext(os.path.basename(src_path))[0].replace("_2k", "")
            with open(src_path, "rb") as fh:
                digest = hashlib.md5(fh.read()).hexdigest() + role
            if digest in hashes and os.path.exists(os.path.join(tex_out, hashes[digest] + ".webp")):
                name = hashes[digest]
            hashes[digest] = name
            dst = os.path.join(tex_out, name + ".webp")
            size = 2048 if role == "trunk" else 1024
            if not os.path.exists(dst):
                img = bpy.data.images.load(src_path, check_existing=False)
                img.colorspace_settings.name = "Non-Color"
                if img.size[0] > size:
                    img.scale(size, size)
                w, hh = img.size
                px = np.empty(w * hh * 4, np.float32)
                img.pixels.foreach_get(px)
                bpy.data.images.remove(img)
                write_image(dst, px.reshape(hh, w, 4)[::-1], "WEBP", 88)
            tex_names[role][key] = name + ".webp"
    with open(hash_path, "w") as fh:
        json.dump(hashes, fh)

    # --- Impostor ----------------------------------------------------------------------
    for o in list(bpy.data.objects):
        if o.type == "MESH":
            o.hide_render = True
    imp = obj
    imp.hide_render = False
    imp.data.uv_layers.active = imp.data.uv_layers["UV"]
    fw = 2.0 * radius * 1.02
    fh = height * 1.02
    if fh / fw < IMP_CELL[1] / IMP_CELL[0]:
        fh = fw * IMP_CELL[1] / IMP_CELL[0]
    else:
        fw = fh * IMP_CELL[0] / IMP_CELL[1]
    cw, ch = IMP_CELL[0] * IMP_SUPER, IMP_CELL[1] * IMP_SUPER
    strips = {}
    for mode in ("color", "normal"):
        for mi, m in enumerate(rmats_color if mode == "color" else rmats_nor):
            imp.data.materials[mi] = m
        setup_render(cw, ch, mode)
        strip = np.zeros((IMP_CELL[1], IMP_CELL[0] * IMP_VIEWS, 4), np.float32)
        for k in range(IMP_VIEWS):
            th = 2 * math.pi * k / IMP_VIEWS
            dist = 200.0
            loc = (math.cos(th) * dist, math.sin(th) * dist, fh * 0.5)
            cam = ortho_camera(loc, (math.pi * 0.5, 0.0, th + math.pi * 0.5), fh, 400.0)
            path = os.path.join(tmp_dir, "%s_imp_%s_%d.png" % (tree, mode, k))
            render_to(path)
            px = read_png(path)
            # Downsample (box) the supersampled frame; colour weighted by alpha.
            a = px[..., 3:4]
            s = IMP_SUPER
            ca = (px[..., :3] * a).reshape(IMP_CELL[1], s, IMP_CELL[0], s, 3).sum((1, 3))
            aa = a.reshape(IMP_CELL[1], s, IMP_CELL[0], s, 1).sum((1, 3))
            frame = np.concatenate([ca / np.maximum(aa, 1e-6), aa / (s * s)], axis=2)
            strip[:, k * IMP_CELL[0]:(k + 1) * IMP_CELL[0]] = frame
            bpy.data.objects.remove(cam)
        strips[mode] = strip
    strips["normal"][..., 3] = strips["color"][..., 3]
    col = dilate(strips["color"], 8)
    nor = dilate(strips["normal"], 8)
    nor[nor[..., 3] <= 0.02, :3] = (0.5, 0.5, 1.0)
    nor[..., 3] = 1.0
    # Strips of all trees are put together into one atlas by --compose.
    strip_dir = os.path.join(os.path.dirname(os.path.dirname(gltf)), "_strips")
    os.makedirs(strip_dir, exist_ok=True)
    write_image(os.path.join(strip_dir, "%s_imp.png" % tree), col, "PNG")
    write_image(os.path.join(strip_dir, "%s_imp_nor.png" % tree), nor, "PNG")

    meta = {
        "tree": tree, "source": asset, "broad": cfg["broad"], "height": height, "radius": radius,
        "crown": {"center": [float(crown_c[0]), float(crown_c[2]), float(-crown_c[1])],
                  "radius": [float(crown_r[0]), float(crown_r[2]), float(crown_r[1])]},
        "impostor": {"width": fw, "height": fh, "views": IMP_VIEWS},
        "atlas_density": d0, "bark": tex_names,
        "leaves": "%s_leaves.webp" % tree, "leaves_nor": "%s_leaves_nor.webp" % tree,
        "cards": [len(card_verts[i]) for i in range(3)],
    }
    with open(os.path.join(out_dir, "%s.json" % tree), "w") as f:
        json.dump(meta, f, indent=1)
    log(tree, "done in %.0fs" % (time.time() - t0))


def compose(cache, out_dir):
    """Puts the impostor strips of all trees (TREE_ORDER rows, IMP_VIEWS columns) into
    textures/impostors.webp and impostors_nor.webp."""
    strip_dir = os.path.join(cache, "_strips")
    for suffix in ("", "_nor"):
        rows = []
        for tree in TREE_ORDER:
            path = os.path.join(strip_dir, "%s_imp%s.png" % (tree, suffix))
            if not os.path.exists(path):
                log("WARNING: no impostor strip for", tree, "(build it): its row stays empty")
                rows.append(np.zeros((IMP_CELL[1], IMP_CELL[0] * IMP_VIEWS, 4), np.float32))
                continue
            rows.append(read_png(path))
        atlas = np.concatenate(rows, axis=0)
        if suffix == "_nor":
            atlas[..., 3] = 1.0
        write_image(os.path.join(out_dir, "textures", "impostors%s.webp" % suffix), atlas, "WEBP", 92)
    log("impostor atlas: %d trees x %d views" % (len(TREE_ORDER), IMP_VIEWS))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {}
    i = 0
    while i < len(argv):
        opts[argv[i].lstrip("-")] = argv[i + 1]
        i += 2
    if "compose" in opts:
        compose(os.path.abspath(opts["compose"]), os.path.abspath(opts["out"]))
        return
    asset = opts["asset"]
    cfg = SOURCES[asset]
    out_dir = os.path.abspath(opts["out"])
    os.makedirs(out_dir, exist_ok=True)
    only = opts.get("tree")
    for node, tree in cfg["nodes"].items():
        if only and tree != only:
            continue
        build_tree(os.path.abspath(opts["source"]), asset, node, tree, cfg, out_dir)


if __name__ == "__main__":
    main()
