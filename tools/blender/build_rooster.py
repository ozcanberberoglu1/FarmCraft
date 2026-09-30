"""Builds the rooster model from the hen (art/models/animals/source/chicken, CC-BY 4.0
"Chicken" by MAXDESIGN-3D) into art/models/animals/source/rooster/.

Run from the project root (headless Blender 4.x):
  /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_rooster.py [-- --preview=/abs/dir]

The rooster's glTF is the hen's own, patched (so its skeleton, rest pose, skin and clip
stay exactly hers and the game's PhotoRig drives both alike; Blender only works out the
changes, it does not export). What changes:
  - the comb grows tall and serrated, the wattles hang long (the hen's own comb and
    wattle vertices pushed out, so they keep her photo texture);
  - the plumage is repainted per body region, from the hen's feather detail: golden
    orange hackles on the head and neck, a mahogany saddle and wing bow, dark primaries,
    a black breast, thighs and tail (red skin, the eye, the beak and the legs keep theirs);
  - long arching sickle feathers and a few coverts rise from the tail (a new two-sided,
    alpha-cut feather material, painted here), skinned to the tail bone.
Its normal map is the hen's (referenced from her folder, not copied).
"""
import json
import struct
import math
import os
import sys

import bpy
import bmesh
import mathutils
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art/models/animals/source/chicken/scene.gltf")
OUT_DIR = os.path.join(ROOT, "art/models/animals/source/rooster")
TEX_DIR = os.path.join(OUT_DIR, "textures")
MESH = "Object_49"

# Plumage per region: mid-tone colour the feather detail is carried on.
HACKLE = (0.93, 0.52, 0.13)
SADDLE = (0.62, 0.17, 0.05)
BOW = (0.55, 0.14, 0.04)
PRIMARY = (0.2, 0.12, 0.07)
BLACK = (0.055, 0.058, 0.052)
TAIL = (0.035, 0.06, 0.045)
GROUPS = {
    "CHICKEN_-Head_05": "head", "CHICKEN_-Queue-de-cheval-1_06": "head",
    "CHICKEN_-Neck_02": "neck", "CHICKEN_-Neck1_03": "neck", "CHICKEN_-Neck2_04": "neck",
    "CHICKEN_-Pelvis_00": "body", "CHICKEN_-Spine_01": "body",
    "CHICKEN_-R-Clavicle_07": "bow", "CHICKEN_-L-Clavicle_011": "bow",
    "CHICKEN_-R-UpperArm_08": "bow", "CHICKEN_-L-UpperArm_012": "bow",
    "CHICKEN_-R-Forearm_09": "bow", "CHICKEN_-L-Forearm_013": "bow",
    "CHICKEN_-R-Hand_010": "primary", "CHICKEN_-L-Hand_014": "primary",
    "CHICKEN_-Tail_015": "tail",
    "CHICKEN_-R-Thigh_016": "thigh", "CHICKEN_-L-Thigh_028": "thigh",
    "CHICKEN_-R-Calf_017": "thigh", "CHICKEN_-L-Calf_029": "thigh",
}
REGIONS = ["keep", "head", "neck", "back", "breast", "bow", "primary", "tail", "thigh"]


def args():
    out = {}
    if "--" in sys.argv:
        for a in sys.argv[sys.argv.index("--") + 1:]:
            if a.startswith("--") and "=" in a:
                k, v = a[2:].split("=", 1)
                out[k] = v
    return out


def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    bpy.ops.import_scene.gltf(filepath=SRC)
    # The rest pose, parents unanimated: the frame the edits are worked out in.
    actions = {}
    for o in bpy.data.objects:
        if o.animation_data:
            actions[o.name] = o.animation_data.action
            o.animation_data.action = None
    for o in bpy.data.objects:
        if o.type == "ARMATURE":
            o.data.pose_position = "REST"
    bpy.context.view_layer.update()
    return actions


# --- Comb and wattles ------------------------------------------------------------------------
# World frame of the hen at rest: +X up, -Y forward (beak), Z across.

def sample_img(img):
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    return px


def texel(px, u, v):
    h, w = px.shape[:2]
    return px[int((v % 1.0) * (h - 1)), int((u % 1.0) * (w - 1))]


def reshape_head(obj, px):
    me = obj.data
    mw = obj.matrix_world
    inv = mw.inverted()
    uv = me.uv_layers.active.data
    red = set()
    for poly in me.polygons:
        for li in poly.loop_indices:
            r, g, b, _ = texel(px, *uv[li].uv)
            if r - g > 0.22 and r > 0.35:
                red.add(me.loops[li].vertex_index)
    head_g = obj.vertex_groups["CHICKEN_-Head_05"].index
    pos = {i: mw @ me.vertices[i].co for i in range(len(me.vertices))}
    # The comb: red on the crown (above the eye); the wattles: red under the beak.
    comb = [i for i in red if pos[i].x > 0.452]
    wattle = [i for i in red if pos[i].x < 0.405 and pos[i].y < -0.12]
    if comb:
        base = min(pos[i].x for i in comb)
        ys = [pos[i].y for i in comb]
        y0, y1 = min(ys), max(ys)
        yc = (y0 + y1) * 0.5
        for i in comb:
            p = pos[i].copy()
            h = p.x - base
            along = (p.y - y0) / max(y1 - y0, 1e-4)
            # Five points along the blade, the middle ones tallest; the blade leans back a little.
            teeth = 0.5 + 0.5 * math.cos(along * math.pi * 2.0 * 2.5) ** 2
            arch = 1.0 - 0.35 * (2.0 * along - 1.0) ** 2
            k = 1.0 + (1.6 + 1.1 * teeth) * arch * min(h / 0.02, 1.0)
            p.x = base + h * k
            p.y = yc + (p.y - yc) * 1.25 + h * 0.35
            me.vertices[i].co = inv @ p
    if wattle:
        top = max(pos[i].x for i in wattle)
        for i in wattle:
            p = pos[i].copy()
            d = top - p.x
            p.x = top - d * 2.1
            p.y -= d * 0.25
            me.vertices[i].co = inv @ p
    print("comb verts", len(comb), "wattle verts", len(wattle))
    return comb + wattle


# --- Plumage -------------------------------------------------------------------------------

def vertex_regions(obj):
    """Per vertex: weights over REGIONS (the body split into back and breast by its normal)."""
    me = obj.data
    names = {g.index: g.name for g in obj.vertex_groups}
    mw3 = obj.matrix_world.to_3x3()
    out = np.zeros((len(me.vertices), len(REGIONS)), dtype=np.float32)
    for v in me.vertices:
        n = (mw3 @ v.normal).normalized()
        for g in v.groups:
            reg = GROUPS.get(names[g.group], "keep")
            if reg == "body":
                up = min(max((n.x + 0.1) / 0.5, 0.0), 1.0)
                out[v.index, REGIONS.index("back")] += g.weight * up
                out[v.index, REGIONS.index("breast")] += g.weight * (1.0 - up)
            elif reg == "neck":
                # The throat under the hackles darkens toward the breast.
                front = min(max((-n.y - 0.2) / 0.6, 0.0), 1.0) * min(max((-n.x + 0.1) / 0.5, 0.0), 1.0)
                out[v.index, REGIONS.index("neck")] += g.weight * (1.0 - 0.6 * front)
                out[v.index, REGIONS.index("breast")] += g.weight * 0.6 * front
            else:
                out[v.index, REGIONS.index(reg)] += g.weight
        s = out[v.index].sum()
        out[v.index] = out[v.index] / s if s > 0 else np.eye(len(REGIONS))[0]
    return out


def raster_regions(obj, weights, size):
    """Region weights per texel: the triangles rasterised in UV space."""
    me = obj.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    grid = np.zeros((size, size, len(REGIONS)), dtype=np.float32)
    cover = np.zeros((size, size), dtype=np.float32)
    for tri in me.loop_triangles:
        p = np.array([uv[li].uv[:] for li in tri.loops], dtype=np.float64)
        # Tiled cards (the fluff round the legs and rump) map outside 0..1: wrap them in.
        p -= np.floor(p.min(axis=0))
        p *= size - 1
        w = weights[[me.loops[li].vertex_index for li in tri.loops]]
        x0, y0 = np.floor(p.min(axis=0)).astype(int)
        x1, y1 = np.ceil(p.max(axis=0)).astype(int)
        x0, y0 = max(x0 - 1, 0), max(y0 - 1, 0)
        x1, y1 = min(x1 + 1, size - 1), min(y1 + 1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(d) < 1e-9:
            continue
        a = ((p[1, 1] - p[2, 1]) * (xs - p[2, 0]) + (p[2, 0] - p[1, 0]) * (ys - p[2, 1])) / d
        b = ((p[2, 1] - p[0, 1]) * (xs - p[2, 0]) + (p[0, 0] - p[2, 0]) * (ys - p[2, 1])) / d
        c = 1.0 - a - b
        # A texel of slack round each triangle so seams get painted too.
        m = (a > -0.02) & (b > -0.02) & (c > -0.02)
        if not m.any():
            continue
        bc = np.stack([a, b, c], axis=-1).clip(0, 1)
        val = bc @ w
        grid[ys[m], xs[m]] += val[m]
        cover[ys[m], xs[m]] += 1.0
    hit = cover > 0
    grid[hit] /= cover[hit][:, None]
    grid[~hit, 0] = 1.0
    return grid


def repaint(px, grid):
    """Recolours the hen's texture per region, keeping its feather detail."""
    rgb = px[..., :3]
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    detail = np.clip(lum / 0.42, 0.0, 2.0) ** 1.15
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # Red skin (comb, wattles, face) and the orange iris keep their colour.
    skin = np.clip((r - g - 0.12) / 0.1, 0, 1) * (b > g * 0.72)
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    # The beak is grey, the eye white: low saturation on the head stays.
    grey = np.clip((0.22 - sat) / 0.1, 0, 1)
    cols = {"head": HACKLE, "neck": HACKLE, "back": SADDLE, "breast": BLACK, "bow": BOW,
            "primary": PRIMARY, "tail": TAIL, "thigh": BLACK}
    out = rgb * grid[..., 0:1]
    for k, reg in enumerate(REGIONS[1:], start=1):
        c = np.array(cols[reg], dtype=np.float32)
        w = grid[..., k:k + 1]
        tinted = c * detail[..., None]
        if reg == "head":
            keep = np.maximum(skin, grey)[..., None]
            tinted = tinted * (1 - keep) + rgb * keep
        else:
            keep = skin[..., None]
            tinted = tinted * (1 - keep) + rgb * keep
        out = out + tinted * w
    # Black plumage has a green sheen in its highlights.
    dark = grid[..., REGIONS.index("tail")] + grid[..., REGIONS.index("breast")] * 0.5
    sheen = np.clip(detail - 1.0, 0, 1) * dark
    out[..., 1] += sheen * 0.05
    out[..., 2] += sheen * 0.025
    # A cock's comb and wattles are a deeper, brighter red than a hen's.
    red = skin[..., None]
    out = out * (1 - red) + (out * np.array([1.08, 0.72, 0.74], dtype=np.float32)) * red
    res = px.copy()
    res[..., :3] = np.clip(out, 0, 1)
    return res


# --- Sickle feathers ----------------------------------------------------------------------

def feather_texture(path, w=128, h=512):
    """A long tail feather: a pale shaft, barbs angled toward the tip, a tapering
    vane cut out in alpha (slightly ragged), glossy black with a green cast."""
    rng = np.random.default_rng(3)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    v = ys / (h - 1)  # 0 base .. 1 tip
    u = (xs / (w - 1)) * 2.0 - 1.0
    half = 0.18 + 0.8 * np.sin(np.clip(v, 0, 1) * math.pi * 0.92) ** 0.6 * (1.0 - v ** 3)
    edge = half * (1.0 + 0.04 * np.sin(v * 180.0 + rng.random() * 6))
    alpha = np.clip((edge - np.abs(u)) / 0.06, 0, 1) * np.clip(v / 0.03, 0, 1)
    barbs = 0.5 + 0.5 * np.sin((v * 260.0 - np.abs(u) * 18.0))
    shade = 0.75 + 0.25 * barbs - 0.25 * np.abs(u)
    shaft = np.clip(1.0 - np.abs(u) / 0.035, 0, 1)
    col = np.zeros((h, w, 4), dtype=np.float32)
    base = np.array([0.03, 0.055, 0.04], dtype=np.float32)
    col[..., :3] = base * shade[..., None] * 1.3
    col[..., :3] += np.array([0.02, 0.06, 0.035]) * (np.clip(1 - np.abs(u) * 1.6, 0, 1) ** 2)[..., None]
    col[..., :3] = col[..., :3] * (1 - shaft[..., None] * 0.6) + np.array([0.16, 0.15, 0.13]) * shaft[..., None] * 0.6
    col[..., 3] = alpha
    img = bpy.data.images.new("rooster_feather", w, h, alpha=True)
    img.pixels = col.ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def add_feathers(obj, img):
    me = obj.data
    mw = obj.matrix_world
    inv = mw.inverted()
    mat = bpy.data.materials.new("rooster_feather")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.35
    mat.blend_method = "CLIP"
    mat.use_backface_culling = False
    me.materials.append(mat)
    slot = len(me.materials) - 1
    tail_g = obj.vertex_groups["CHICKEN_-Tail_015"]
    bm = bmesh.new()
    bm.from_mesh(me)
    uvl = bm.loops.layers.uv.active
    dl = bm.verts.layers.deform.active
    new_verts = []
    geo = {"pos": [], "uv": [], "quads": []}
    # Out of the middle of the hen's tail tuft (it sits a little off the body's centre line).
    tail = [mw @ v.co for v in me.vertices
            if any(g.group == tail_g.index and g.weight > 0.5 for g in v.groups)]
    lo = mathutils.Vector((min(q.x for q in tail), min(q.y for q in tail), min(q.z for q in tail)))
    hi = mathutils.Vector((max(q.x for q in tail), max(q.y for q in tail), max(q.z for q in tail)))
    zc = sum(q.z for q in tail) / len(tail)
    root = mathutils.Vector((lo.x + (hi.x - lo.x) * 0.72, lo.y + (hi.y - lo.y) * 0.3, zc))
    print("tail tuft", lo, hi, "root", root)
    # [lateral offset, length, start angle, end angle (deg, 90 = straight up, 0 = straight
    # back), lateral spread, width]: two long sickles, a middle one, then shorter coverts.
    plan = [(-0.01, 0.34, 76, -60, -0.05, 0.05), (0.01, 0.33, 74, -62, 0.05, 0.05),
            (0.0, 0.29, 70, -45, 0.0, 0.048),
            (-0.025, 0.23, 62, -35, -0.12, 0.045), (0.025, 0.22, 60, -38, 0.12, 0.045),
            (-0.018, 0.17, 55, -20, -0.08, 0.042), (0.018, 0.17, 52, -22, 0.08, 0.042),
            (-0.035, 0.14, 45, -15, -0.18, 0.04), (0.035, 0.14, 44, -12, 0.18, 0.04),
            (0.0, 0.13, 40, -5, 0.0, 0.04)]
    seg = 14
    for (dz, length, a0, a1, spread, width) in plan:
        p = root + mathutils.Vector((0, 0, dz))
        pts = [p.copy()]
        for k in range(1, seg + 1):
            t = (k - 0.5) / seg
            ang = math.radians(a0 + (a1 - a0) * t ** 1.3)
            p = p + mathutils.Vector((math.sin(ang), math.cos(ang), spread)) * (length / seg)
            pts.append(p.copy())
        ring = []
        for k, p in enumerate(pts):
            t = k / seg
            nxt = pts[min(k + 1, seg)] - pts[max(k - 1, 0)]
            nxt.normalize()
            side = nxt.cross(mathutils.Vector((1, 0, 0)))
            if side.length < 1e-4:
                side = mathutils.Vector((0, 0, 1))
            side.normalize()
            # The vane twists a little so it catches the light along its length.
            twist = mathutils.Quaternion(nxt, math.radians(25.0 * t))
            side = twist @ side
            a = bm.verts.new(inv @ (p - side * width * 0.5))
            b = bm.verts.new(inv @ (p + side * width * 0.5))
            ring.append((a, b, t))
            new_verts += [a, b]
            geo["pos"] += [tuple(a.co), tuple(b.co)]
            geo["uv"] += [(0.0, t), (1.0, t)]
        first = len(geo["pos"]) - 2 * (seg + 1)
        for k in range(seg):
            i0 = first + 2 * k
            geo["quads"].append((i0, i0 + 1, i0 + 3, i0 + 2))
            a0, b0, t0 = ring[k]
            a1, b1, t1 = ring[k + 1]
            f = bm.faces.new((a0, b0, b1, a1))
            f.material_index = slot
            f.smooth = True
            for loop, uvv in zip(f.loops, [(0.0, t0), (1.0, t0), (1.0, t1), (0.0, t1)]):
                loop[uvl].uv = uvv
    for v in new_verts:
        v[dl][tail_g.index] = 1.0
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.update()
    print("feathers", len(plan))
    return geo


# --- The patched glTF ------------------------------------------------------------------------
# Blender imports glTF (x, y, z) as (x, -z, y): the mesh's own coordinates go back as
# (x, z, -y), its UVs with v flipped.

def _gl(v):
    return (v[0], v[2], -v[1])


def _pad(buf):
    while len(buf) % 4:
        buf.append(0)


def _add_view(d, buf, data, target=None):
    _pad(buf)
    view = {"buffer": 0, "byteOffset": len(buf), "byteLength": len(data)}
    if target:
        view["target"] = target
    buf.extend(data)
    d["bufferViews"].append(view)
    return len(d["bufferViews"]) - 1


def _add_accessor(d, buf, arr, ctype, typ, target=34962, minmax=False):
    view = _add_view(d, buf, arr.tobytes(), target)
    acc = {"bufferView": view, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
    if minmax:
        acc["min"] = [float(x) for x in arr.min(axis=0)]
        acc["max"] = [float(x) for x in arr.max(axis=0)]
    d["accessors"].append(acc)
    return len(d["accessors"]) - 1


def write_gltf(obj, moved, geo):
    d = json.load(open(SRC))
    src_dir = os.path.dirname(SRC)
    buf = bytearray(open(os.path.join(src_dir, d["buffers"][0]["uri"]), "rb").read())
    me = obj.data
    me.update()
    prim = d["meshes"][0]["primitives"][0]
    # The comb and the wattles: their vertices moved, their normals worked out again.
    for attr, value in (("POSITION", lambda v: _gl(v.co)), ("NORMAL", lambda v: _gl(v.normal))):
        acc = d["accessors"][prim["attributes"][attr]]
        view = d["bufferViews"][acc["bufferView"]]
        stride = view.get("byteStride", 12)
        base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        for i in moved:
            struct.pack_into("<3f", buf, base + i * stride, *value(me.vertices[i]))
        if attr == "POSITION":
            pts = np.array([_gl(v.co) for v in me.vertices], dtype=np.float32)
            acc["min"] = [float(x) for x in pts.min(axis=0)]
            acc["max"] = [float(x) for x in pts.max(axis=0)]
    # The sickle feathers: a second primitive, all on the tail joint.
    skin = d["skins"][0]
    tail = [d["nodes"][j]["name"] for j in skin["joints"]].index("CHICKEN_-Tail_015")
    pos = np.array([_gl(p) for p in geo["pos"]], dtype=np.float32)
    uv = np.array([(u, 1.0 - v) for u, v in geo["uv"]], dtype=np.float32)
    tris = []
    for a, b, c, e in geo["quads"]:
        tris += [a, b, c, a, c, e]
    nrm = np.zeros_like(pos)
    for k in range(0, len(tris), 3):
        a, b, c = tris[k:k + 3]
        n = np.cross(pos[b] - pos[a], pos[c] - pos[a])
        nrm[[a, b, c]] += n
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-8)
    joints = np.tile(np.array([tail, 0, 0, 0], dtype=np.uint16), (len(pos), 1))
    weights = np.tile(np.array([1.0, 0.0, 0.0, 0.0], dtype=np.float32), (len(pos), 1))
    idx = np.array(tris, dtype=np.uint16)
    feather = {"attributes": {
        "POSITION": _add_accessor(d, buf, pos, 5126, "VEC3", minmax=True),
        "NORMAL": _add_accessor(d, buf, nrm.astype(np.float32), 5126, "VEC3"),
        "TEXCOORD_0": _add_accessor(d, buf, uv, 5126, "VEC2"),
        "JOINTS_0": _add_accessor(d, buf, joints, 5123, "VEC4"),
        "WEIGHTS_0": _add_accessor(d, buf, weights, 5126, "VEC4"),
    }, "indices": _add_accessor(d, buf, idx, 5123, "SCALAR", 34963), "material": 1, "mode": 4}
    d["meshes"][0]["primitives"].append(feather)
    _pad(buf)
    d["buffers"][0]["byteLength"] = len(buf)
    # Textures: the repainted body, the hen's own normal map, the feather.
    d["images"] = [{"uri": "textures/rooster_baseColor.png"}, {"uri": "../chicken/textures/01_-_Default_normal.png"},
            {"uri": "textures/rooster_feather.png"}]
    d["textures"].append({"sampler": 0, "source": 2})
    d["materials"][0]["name"] = "rooster_body"
    d["materials"].append({"name": "rooster_feather", "alphaMode": "MASK", "alphaCutoff": 0.4, "doubleSided": True,
            "pbrMetallicRoughness": {"baseColorTexture": {"index": len(d["textures"]) - 1}, "metallicFactor": 0.0,
            "roughnessFactor": 0.45}})
    # The buffer's hash: Godot reimports a model when its .gltf changes, not only its .bin.
    import hashlib
    d.setdefault("asset", {})["extras"] = {"note": "Patched from the hen by tools/blender/build_rooster.py",
            "bin_md5": hashlib.md5(bytes(buf)).hexdigest()}
    with open(os.path.join(OUT_DIR, "scene.bin"), "wb") as f:
        f.write(buf)
    with open(os.path.join(OUT_DIR, "scene.gltf"), "w") as f:
        json.dump(d, f, indent=1)


def main():
    a = args()
    os.makedirs(TEX_DIR, exist_ok=True)
    actions = load()
    obj = bpy.data.objects[MESH]
    mat = obj.data.materials[0]
    base_node = [n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and "base" in n.image.name.lower()][0]
    img = base_node.image
    px = sample_img(img)
    size = img.size[0]
    weights = vertex_regions(obj)
    grid = raster_regions(obj, weights, size)
    painted = repaint(px, grid)
    moved = reshape_head(obj, px)
    out = bpy.data.images.new("rooster_baseColor", size, size, alpha=True)
    out.pixels = painted.ravel()
    out.filepath_raw = os.path.join(TEX_DIR, "rooster_baseColor.png")
    out.file_format = "PNG"
    out.save()
    base_node.image = out
    mat.name = "rooster_body"
    geo = add_feathers(obj, feather_texture(os.path.join(TEX_DIR, "rooster_feather.png")))
    # The stray icosphere some importer versions leave behind.
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name != MESH:
            bpy.data.objects.remove(o)
    if "preview" in a:
        sys.path.append(os.path.dirname(__file__))
        preview(a["preview"])
    write_gltf(obj, moved, geo)
    print("ROOSTER EXPORTED")


def preview(d):
    import render_prev
    render_prev.shots(d)


if __name__ == "__main__":
    main()
